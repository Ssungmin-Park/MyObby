--!strict
-- RobotLabHud: 로봇 작업장 화면 표시. (표시와 요청만 담당, 판정은 서버 RobotLab)
--   - 서버가 보낸 상태로 부품·가방·보관함·수리 현황·목표·도감을 보여 준다.
--   - 부품 더미와 로봇 신호는 이 플레이어 화면에만 만든다(다른 사람과 겹치지 않게).
--   - 부품 더미 가까이 걸어가면 자동으로 줍기 요청을 보낸다. 서버가 거리를 다시 확인한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RobotLabConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("RobotLabState") :: RemoteEvent
local actionRemote = remotes:WaitForChild("RobotLabAction") :: RemoteEvent
local interactions = workspace:WaitForChild("RobotLab"):WaitForChild("Interactions")

local player = Players.LocalPlayer
local state: any = { active = false }
local stateTime = os.clock() -- 상태를 받은 시각 (수리 남은 시간 계산용)

-- 화면 ------------------------------------------------------------------------
local white = Color3.fromRGB(244, 248, 255)
local muted = Color3.fromRGB(180, 196, 209)
local accent = Color3.fromRGB(143, 235, 210)
local dark = Color3.fromRGB(20, 26, 32)

local gui = Instance.new("ScreenGui")
gui.Name = "RobotLabHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(12, 10)
panel.Size = UDim2.new(0.88, 0, 0, 196)
panel.BackgroundColor3 = dark
panel.BackgroundTransparency = 0.09
panel.BorderSizePixel = 0
panel.Parent = gui
local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(360, 196)
maxSize.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local function makeLabel(parent: Instance, y: number, height: number, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local title = makeLabel(panel, 6, 22, 16, white)
title.Font = Enum.Font.GothamBold
title.Text = "로봇 작업장"
local stats = makeLabel(panel, 28, 20, 13, white)
local income = makeLabel(panel, 47, 18, 12, muted)
local repairsLabel = makeLabel(panel, 66, 34, 12, muted)
local objective = makeLabel(panel, 101, 36, 14, white)
local signalLabel = makeLabel(panel, 138, 18, 12, accent)
local feedback = makeLabel(panel, 157, 34, 12, muted)

-- 도감 버튼과 도감 창 (터치하기 쉽게 크게)
local catalogButton = Instance.new("TextButton")
catalogButton.AnchorPoint = Vector2.new(1, 0)
catalogButton.Position = UDim2.new(1, -8, 0, 6)
catalogButton.Size = UDim2.fromOffset(64, 30)
catalogButton.BackgroundColor3 = Color3.fromRGB(52, 64, 76)
catalogButton.TextColor3 = white
catalogButton.Font = Enum.Font.GothamBold
catalogButton.TextSize = 14
catalogButton.Text = "도감"
catalogButton.Parent = panel
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = catalogButton

local catalog = Instance.new("Frame")
catalog.AnchorPoint = Vector2.new(0.5, 0.5)
catalog.Position = UDim2.fromScale(0.5, 0.55)
catalog.Size = UDim2.new(0.9, 0, 0, 300)
catalog.BackgroundColor3 = dark
catalog.BackgroundTransparency = 0.05
catalog.Visible = false
catalog.Parent = gui
local catalogMax = Instance.new("UISizeConstraint")
catalogMax.MaxSize = Vector2.new(380, 300)
catalogMax.Parent = catalog
local catalogCorner = Instance.new("UICorner")
catalogCorner.CornerRadius = UDim.new(0, 10)
catalogCorner.Parent = catalog
local catalogTitle = makeLabel(catalog, 8, 22, 16, white)
catalogTitle.Font = Enum.Font.GothamBold
local catalogRows: { TextLabel } = {}
for i in Config.Robots do
	local row = makeLabel(catalog, 34 + (i - 1) * 21, 20, 13, muted)
	catalogRows[i] = row
end
catalogButton.Activated:Connect(function()
	catalog.Visible = not catalog.Visible
end)

-- 이 플레이어에게만 보이는 부품 더미와 로봇 ------------------------------------
local localFolder = Instance.new("Folder")
localFolder.Name = "RobotLabLocal"
localFolder.Parent = workspace

local pileParts: { [number]: BasePart } = {}
local pendingCollect: { [number]: number } = {} -- 보낸 시각 (중복 요청 방지)
local zoneColors = {
	Warehouse = Color3.fromRGB(160, 168, 176),
	Greenhouse = Color3.fromRGB(120, 200, 140),
	Scrapyard = Color3.fromRGB(230, 150, 90),
}

local function robotName(id: string?): string
	local robot = if id then Config.getRobot(id) else nil
	return if robot then robot.name else "?"
end

local function rarityOf(id: string?): Config.Rarity?
	local robot = if id then Config.getRobot(id) else nil
	return if robot then Config.Rarities[robot.rarity] else nil
end

local function syncPiles()
	local alive: { [number]: boolean } = {}
	for _, pile in (state.piles or {}) :: { any } do
		alive[pile.id] = true
		if not pileParts[pile.id] then
			local part = Instance.new("Part")
			part.Name = "Pile"
			part.Size = Vector3.new(1.6, 1.2, 1.6)
			part.Position = pile.position
			part.Color = zoneColors[pile.zone] or white
			part.Material = Enum.Material.Metal
			part.Anchored = true
			part.CanCollide = false
			part.Parent = localFolder
			pileParts[pile.id] = part
		end
	end
	for id, part in pileParts do
		if not alive[id] then
			part:Destroy()
			pileParts[id] = nil
			pendingCollect[id] = nil
		end
	end
end

local robotModel: Model? = nil
local robotSignalKey = ""
local robotBillboard: BillboardGui? = nil

local function syncSignal()
	local signal = state.signal
	local key = if signal then signal.robotId .. tostring(signal.position) else ""
	if key == robotSignalKey then
		return
	end
	robotSignalKey = key
	if robotModel then
		robotModel:Destroy()
		robotModel = nil
		robotBillboard = nil
	end
	if not signal then
		return
	end
	local rarity = rarityOf(signal.robotId)
	local color = if rarity then rarity.color else white
	local model = Instance.new("Model")
	model.Name = "BrokenRobot"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 2, 1.7)
	body.Position = signal.position + Vector3.new(0, 0.2, 0)
	body.Color = color
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 1.5, 1.9)
	head.Position = body.Position + Vector3.new(0, 1.7, 0)
	head.Orientation = Vector3.new(0, 0, 18) -- 고장 나서 고개가 기울어짐
	head.Color = color
	head.Anchored = true
	head.CanCollide = false
	head.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = ("고장 난 %s · %s"):format(robotName(signal.robotId), if rarity then rarity.name else "")
	prompt.ActionText = "로봇 줍기"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		actionRemote:FireServer("PickUp")
	end)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 28)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = dark
	text.BackgroundTransparency = 0.2
	text.TextColor3 = color
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.Text = "📡 로봇 신호"
	text.Parent = billboard
	model.Parent = localFolder
	robotModel = model
	robotBillboard = billboard
end

-- 장치 안내문에 이 플레이어의 비용을 표시한다 (클라이언트에서만 바뀜)
local function syncPromptTexts()
	for _, id in Config.UpgradeOrder do
		local station = interactions:FindFirstChild("Upgrade_" .. id)
		local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local upgrade = Config.Upgrades[id]
			local level = (state.upgrades and state.upgrades[id]) or 1
			local nextLevel = upgrade.levels[level + 1]
			prompt.ObjectText = ("%s (현재 %s%s)"):format(upgrade.name, tostring(upgrade.levels[level].value), upgrade.unit)
			prompt.ActionText = if nextLevel then ("부품 %d개로 업그레이드"):format(nextLevel.cost) else "최고 단계"
		end
	end
	for _, zone in Config.ZoneOrder do
		local station = interactions:FindFirstChild("Unlock_" .. zone)
		local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local opened = state.zones and state.zones[zone]
			prompt.ActionText = if opened then "열림" else ("부품 %d개로 열기"):format(Config.Zones[zone].unlockCost)
		end
	end
	local repair = interactions:FindFirstChild("Repair")
	local repairPrompt = repair and repair:FindFirstChildOfClass("ProximityPrompt")
	if repairPrompt then
		repairPrompt.ActionText = if state.carrying
			then ("%s 맡기기 (부품 %d개)"):format(robotName(state.carrying), state.carryCost or 0)
			else "수리 현황"
	end
end

local function render()
	gui.Enabled = state.active == true
	localFolder.Parent = if state.active then workspace else nil
	if not state.active then
		catalog.Visible = false
		return
	end
	local elapsed = os.clock() - stateTime
	-- 불러오기에 실패한 접속이면 진행이 저장되지 않는다는 것을 항상 보여 준다
	title.Text = if state.saving == false then "로봇 작업장  ⚠ 저장 안 됨" else "로봇 작업장"

	local owned = 0
	for _ in (state.robots or {}) :: { [string]: number } do
		owned += 1
	end
	stats.Text = ("부품 %d   ·   가방 %d/%d   ·   보관함 %d"):format(state.parts, state.bag, state.bagMax, state.storage)
	income.Text = ("도감 %d/%d   ·   도우미 수입 분당 %.1f (보관함 최대 %d)"):format(owned, #Config.Robots, state.rate, state.storageCap)

	local lines = {}
	for _, repair in (state.repairs or {}) :: { any } do
		table.insert(lines, ("🔧 %s %s"):format(robotName(repair.robotId), Config.formatTime(repair.remaining - elapsed)))
	end
	local slots = state.slots or 1
	if #lines < slots then
		table.insert(lines, ("빈 수리대 %d개"):format(slots - #lines))
	end
	repairsLabel.Text = table.concat(lines, "   ")

	-- 지금 할 일
	local signal = state.signal
	if state.carrying then
		local need = (state.carryCost or 0) - state.parts
		objective.Text = if need > 0
			then ("%s를 고치려면 부품 %d개가 더 필요해요. 부품을 주워 수거함에 넣으세요."):format(robotName(state.carrying), need)
			else ("%s를 연구실 수리대로 가져가세요."):format(robotName(state.carrying))
	elseif state.bag >= state.bagMax then
		objective.Text = "가방이 가득 찼어요. 연구실 수거함에 부품을 넣으세요."
	elseif not state.tutorialDone and signal then
		objective.Text = "바로 앞의 고장 난 로봇에게 다가가서 주우세요."
	elseif signal then
		local rarity = rarityOf(signal.robotId)
		local zone = Config.Zones[signal.zone]
		objective.Text = ("%s에서 %s 로봇 신호를 찾으세요."):format(if zone then zone.name else "연구실", if rarity then rarity.name else "")
	elseif state.storage > 0 and state.bag == 0 then
		objective.Text = "수거함에서 도우미 로봇이 모은 부품을 받으세요."
	else
		objective.Text = "부품을 모아 업그레이드하거나 새 구역을 여세요."
		-- 다음 구역을 열 부품이 모였으면 알려 준다
		for _, zoneId in Config.ZoneOrder do
			local zone = Config.Zones[zoneId]
			if not (state.zones and state.zones[zoneId]) then
				if state.parts >= zone.unlockCost then
					objective.Text = ("부품이 모였어요! %s 입구에서 구역을 열어 보세요."):format(zone.name)
				end
				break
			end
		end
	end

	-- 탐지기: 신호까지 거리
	signalLabel.Text = ""
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if signal and root and root:IsA("BasePart") then
		local distance = (root.Position - signal.position).Magnitude
		local inRange = distance <= state.detector
		signalLabel.Text = if inRange
			then ("탐지기 · 신호까지 %d 스터드"):format(math.round(distance))
			else ("탐지기 · 범위(%d) 밖"):format(state.detector)
		if robotBillboard then
			robotBillboard.Enabled = inRange
		end
	end
	feedback.Text = state.message or ""

	-- 도감
	catalogTitle.Text = ("로봇 도감 %d/%d"):format(owned, #Config.Robots)
	for i, robot in Config.Robots do
		local rarity = Config.Rarities[robot.rarity]
		local level = state.robots and state.robots[robot.id]
		local row = catalogRows[i]
		if level then
			row.Text = ("✓ %s  [%s]  Lv.%d  · 분당 %.1f"):format(robot.name, rarity.name, level, Config.robotIncome(robot.id, level))
			row.TextColor3 = rarity.color
		else
			row.Text = ("○ ???  [%s]"):format(rarity.name)
			row.TextColor3 = muted
		end
	end
end

-- 연구실 전시대: 수리한 로봇이 서 있는 모습으로 성장이 눈에 보이게 한다 (이 플레이어 화면에만) ------
-- 아직 없는 로봇은 반투명 "???"로 보여서 모을 목표가 된다. 자리는 연구실 뒤쪽 빈 공간(2줄 × 6칸).
local DISPLAY_X = { 126, 132, 138, 144, 150, 156 }
local DISPLAY_Z = { 18, 24 }
type DisplaySlot = { parts: { BasePart }, label: TextLabel }
local displaySlots: { DisplaySlot } = {}
do
	local displayFolder = Instance.new("Folder")
	displayFolder.Name = "Display"
	displayFolder.Parent = localFolder
	local function localPart(name: string, position: Vector3, size: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Position = position
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = displayFolder
		return part
	end
	for i in Config.Robots do
		local x = DISPLAY_X[(i - 1) % #DISPLAY_X + 1]
		local z = DISPLAY_Z[(i - 1) // #DISPLAY_X + 1]
		localPart("Pedestal", Vector3.new(x, 40.7, z), Vector3.new(3, 0.4, 3), Color3.fromRGB(52, 60, 70))
		local body = localPart("Body", Vector3.new(x, 41.9, z), Vector3.new(2.2, 2, 1.7), muted)
		local head = localPart("Head", Vector3.new(x, 43.65, z), Vector3.new(2.4, 1.5, 1.9), muted)
		local eyes = {}
		for _, dx in { -0.5, 0.5 } do -- 연구실 입구(−Z) 쪽을 바라본다
			table.insert(eyes, localPart("Eye", Vector3.new(x + dx, 43.75, z - 0.98), Vector3.new(0.3, 0.3, 0.08), dark))
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(120, 22)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
		billboard.MaxDistance = 35
		billboard.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		displaySlots[i] = { parts = { body, head, eyes[1], eyes[2] }, label = label }
	end
end

local function syncDisplay()
	for i, robot in Config.Robots do
		local slot = displaySlots[i]
		local rarity = Config.Rarities[robot.rarity]
		local level = state.robots and state.robots[robot.id]
		for index, part in slot.parts do
			part.Transparency = if level then 0 else 0.8
			if index <= 2 then -- 몸통과 머리만 등급 색 (눈은 그대로)
				part.Color = if level then rarity.color else muted
			end
		end
		slot.label.Text = if level then ("%s Lv.%d"):format(robot.name, level) else ("??? · %s"):format(rarity.name)
		slot.label.TextColor3 = if level then rarity.color else muted
	end
end

-- 안내선: 지금 가야 할 곳까지 빛나는 선을 그린다 (이 플레이어 화면에만) ---------------------------
-- 운반 중이면 수리대, 가방이 차면 수거함, 탐지기 범위 안의 신호면 로봇. 자유 탐색 중에는 그리지 않는다.
local guideTarget = Instance.new("Part")
guideTarget.Name = "GuideTarget"
guideTarget.Size = Vector3.new(0.2, 0.2, 0.2)
guideTarget.Transparency = 1
guideTarget.Anchored = true
guideTarget.CanCollide = false
guideTarget.CanQuery = false
guideTarget.CanTouch = false
guideTarget.Parent = localFolder
local guideEnd = Instance.new("Attachment")
guideEnd.Parent = guideTarget
local guideBeam = Instance.new("Beam")
guideBeam.Attachment1 = guideEnd
guideBeam.Width0 = 0.35
guideBeam.Width1 = 0.35
guideBeam.FaceCamera = true
guideBeam.LightEmission = 1
guideBeam.Color = ColorSequence.new(accent)
guideBeam.Transparency = NumberSequence.new(0.35)
guideBeam.Enabled = false
guideBeam.Parent = guideTarget

local function stationPosition(name: string): Vector3?
	local station = interactions:FindFirstChild(name)
	return if station and station:IsA("BasePart") then station.Position else nil
end

local function nearestPile(from: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, part in pileParts do
		local distance = (part.Position - from).Magnitude
		if distance < bestDistance then
			best = part.Position
			bestDistance = distance
		end
	end
	return best
end

local function guideDestination(root: BasePart): Vector3?
	local carryCost = state.carryCost or 0
	if state.carrying and state.parts >= carryCost then
		return stationPosition("Repair")
	end
	if state.bag >= state.bagMax then
		return stationPosition("Deposit")
	end
	if state.carrying then
		-- 수리비가 모자라면: 가방 부품으로 충분하면 수거함, 아니면 가까운 부품 더미
		return if state.parts + state.bag >= carryCost then stationPosition("Deposit") else nearestPile(root.Position)
	end
	local signal = state.signal
	if signal and (not state.tutorialDone or (root.Position - signal.position).Magnitude <= state.detector) then
		return signal.position
	end
	return nil
end

local function updateGuide()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local destination = if state.active and root and root:IsA("BasePart") then guideDestination(root) else nil
	if not destination or not root or not root:IsA("BasePart") or (root.Position - destination).Magnitude < 5 then
		guideBeam.Enabled = false
		return
	end
	local start = root:FindFirstChild("RobotLabGuide")
	if not start then
		start = Instance.new("Attachment")
		start.Name = "RobotLabGuide"
		start.Position = Vector3.new(0, -1.5, 0) -- 발 근처에서 시작
		start.Parent = root
	end
	guideBeam.Attachment0 = start :: Attachment
	guideTarget.Position = destination + Vector3.new(0, 1, 0)
	guideBeam.Enabled = true
end

stateRemote.OnClientEvent:Connect(function(newState: any)
	if typeof(newState) ~= "table" then
		return
	end
	state = newState
	stateTime = os.clock()
	syncPiles()
	syncSignal()
	syncPromptTexts()
	syncDisplay()
	render()
end)

-- 부품 더미 자동 줍기 + 화면 갱신 (0.1초마다)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	if not state.active then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and state.bag < state.bagMax then
		local now = os.clock()
		for id, part in pileParts do
			local offset = part.Position - root.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < 4.5 and math.abs(offset.Y) < 6 then
				local sent = pendingCollect[id]
				if not sent or now - sent > 0.3 then -- 서버 위치가 늦게 따라와 거절되면 곧 다시 보낸다
					pendingCollect[id] = now
					actionRemote:FireServer("Collect", id)
				end
			end
		end
	end
	updateGuide()
	render()
end)
