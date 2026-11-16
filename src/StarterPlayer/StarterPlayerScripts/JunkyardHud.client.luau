--!strict
-- JunkyardHud: 로봇 고물상 화면 표시. (표시와 요청만 담당, 판정은 서버 Junkyard)
--   - 컨베이어 벨트 위 로봇을 이 화면에서 직접 움직여 그린다(서버와 같은 공식). 구매 버튼 → 서버에 요청.
--   - 돈·초당 수입·방어막·들고 있는 로봇·도감·알림을 보여 준다.
--   - 받침대 버튼 문구를 내 기지면 "팔기", 남의 기지면 "훔치기"로 바꿔 보여 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local beltRemote = remotes:WaitForChild("JunkyardBelt") :: RemoteEvent
local actionRemote = remotes:WaitForChild("JunkyardAction") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("JunkyardNotify") :: RemoteEvent
local junkyard = workspace:WaitForChild("Junkyard")
local beltPart = junkyard:WaitForChild("Belt")
local basesFolder = junkyard:WaitForChild("Bases")

local player = Players.LocalPlayer
local white = Color3.fromRGB(244, 248, 255)
local muted = Color3.fromRGB(180, 196, 209)
local dark = Color3.fromRGB(20, 26, 32)

-- 화면 ------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "JunkyardHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local object = Instance.new("UICorner")
	object.CornerRadius = UDim.new(0, radius)
	object.Parent = parent
end

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local object = Instance.new("TextLabel")
	object.Position = position
	object.Size = size
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.GothamBold
	object.TextSize = textSize
	object.TextColor3 = color
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextWrapped = true
	object.Parent = parent
	return object
end

local function button(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local object = Instance.new("TextButton")
	object.Position = position
	object.Size = size
	object.BackgroundColor3 = color
	object.TextColor3 = white
	object.Font = Enum.Font.GothamBold
	object.TextSize = 14
	object.Text = text
	object.AutoButtonColor = true
	object.Parent = parent
	corner(object, 8)
	return object
end

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(12, 10)
panel.Size = UDim2.fromOffset(250, 150)
panel.BackgroundColor3 = dark
panel.BackgroundTransparency = 0.12
panel.Parent = gui
corner(panel, 10)

local moneyLabel = label(panel, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 30), 24, Color3.fromRGB(255, 220, 100))
local incomeLabel = label(panel, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 18), 13, white)
local carryLabel = label(panel, UDim2.fromOffset(12, 56), UDim2.new(1, -24, 0, 30), 12, muted)
local lockButton = button(panel, "방어막", UDim2.fromOffset(12, 92), UDim2.fromOffset(90, 32), Color3.fromRGB(60, 120, 170))
local shopButton = button(panel, "🛒 상점", UDim2.fromOffset(106, 92), UDim2.fromOffset(68, 32), Color3.fromRGB(170, 120, 40))
local catalogButton = button(panel, "도감", UDim2.fromOffset(178, 92), UDim2.fromOffset(60, 32), Color3.fromRGB(70, 82, 96))
local trainLabel = label(panel, UDim2.fromOffset(12, 128), UDim2.new(1, -24, 0, 18), 12, Color3.fromRGB(255, 210, 120))
-- 저장 상태 (오른쪽 위 작은 글씨): 불러오는 중 / 저장 안 됨
local saveLabel = label(panel, UDim2.new(1, -112, 0, 6), UDim2.fromOffset(100, 18), 12, Color3.fromRGB(255, 150, 150))
saveLabel.TextXAlignment = Enum.TextXAlignment.Right

-- 도감 창
local catalog = Instance.new("Frame")
catalog.AnchorPoint = Vector2.new(0.5, 0.5)
catalog.Position = UDim2.fromScale(0.5, 0.5)
catalog.Size = UDim2.new(0.92, 0, 0, 420)
catalog.BackgroundColor3 = dark
catalog.BackgroundTransparency = 0.05
catalog.Visible = false
catalog.Parent = gui
corner(catalog, 12)
local catalogMax = Instance.new("UISizeConstraint")
catalogMax.MaxSize = Vector2.new(420, 420)
catalogMax.Parent = catalog
local catalogTitle = label(catalog, UDim2.fromOffset(14, 8), UDim2.new(1, -70, 0, 26), 18, white)
local closeButton = button(catalog, "X", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(36, 30), Color3.fromRGB(120, 60, 60))
local catalogRows: { TextLabel } = {}
for i in Config.Robots do
	local column = (i - 1) % 3
	local row = (i - 1) // 3
	catalogRows[i] = label(catalog, UDim2.new(column / 3, 12, 0, 42 + row * 44), UDim2.new(1 / 3, -14, 0, 40), 13, muted)
end
local bonusLabel = label(catalog, UDim2.fromOffset(14, 312), UDim2.new(1, -28, 0, 100), 12, muted)
catalogButton.Activated:Connect(function()
	catalog.Visible = not catalog.Visible
end)
closeButton.Activated:Connect(function()
	catalog.Visible = false
end)
lockButton.Activated:Connect(function()
	actionRemote:FireServer("Lock")
end)

-- 상점 창 (탭: 방해 / 방어 / 도움) --------------------------------------------------
local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.Size = UDim2.new(0.92, 0, 0, 400)
shop.BackgroundColor3 = dark
shop.BackgroundTransparency = 0.05
shop.Visible = false
shop.Parent = gui
corner(shop, 12)
local shopMax = Instance.new("UISizeConstraint")
shopMax.MaxSize = Vector2.new(440, 400)
shopMax.Parent = shop
label(shop, UDim2.fromOffset(14, 8), UDim2.new(1, -70, 0, 26), 18, white).Text = "🛒 상점"
local shopClose = button(shop, "X", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(36, 30), Color3.fromRGB(120, 60, 60))

type ShopEntry = { kind: string, id: string, category: string, row: Frame, info: TextLabel, buy: TextButton }
local shopEntries: { ShopEntry } = {}
local shopTab = "Attack"
local tabs = { { id = "Attack", text = "⚡ 방해" }, { id = "Defense", text = "🛡 방어" }, { id = "Help", text = "💪 도움" } }
local tabButtons: { [string]: TextButton } = {}
for i, tab in tabs do
	local tabButton = button(shop, tab.text, UDim2.new((i - 1) / 3, 10, 0, 42), UDim2.new(1 / 3, -14, 0, 32), Color3.fromRGB(52, 64, 76))
	tabButtons[tab.id] = tabButton
	tabButton.Activated:Connect(function()
		shopTab = tab.id
	end)
end
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 82)
list.Size = UDim2.new(1, -20, 1, -92)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = list

local function addEntry(kind: string, id: string, category: string, name: string, desc: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 70)
	row.BackgroundColor3 = Color3.fromRGB(36, 44, 54)
	row.Parent = list
	corner(row, 8)
	label(row, UDim2.fromOffset(10, 4), UDim2.new(1, -130, 0, 20), 15, white).Text = name
	local descLabel = label(row, UDim2.fromOffset(10, 24), UDim2.new(1, -130, 0, 28), 11, muted)
	descLabel.Text = desc
	local info = label(row, UDim2.fromOffset(10, 50), UDim2.new(1, -130, 0, 16), 11, Color3.fromRGB(150, 230, 255))
	local buy = button(row, "", UDim2.new(1, -114, 0.5, -20), UDim2.fromOffset(106, 40), Color3.fromRGB(60, 140, 80))
	buy.Activated:Connect(function()
		actionRemote:FireServer(if kind == "Item" then "Item" else "Upgrade", id)
	end)
	table.insert(shopEntries, { kind = kind, id = id, category = category, row = row, info = info, buy = buy })
end
for _, id in Config.ItemOrder do
	local item = Config.Items[id]
	addEntry("Item", id, item.category, item.name, item.desc)
end
for _, id in Config.UpgradeOrder do
	local upgrade = Config.Upgrades[id]
	addEntry("Upgrade", id, upgrade.category, upgrade.name, upgrade.desc)
end
shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
	catalog.Visible = false
end)
shopClose.Activated:Connect(function()
	shop.Visible = false
end)

local function decodeUpgrades(): { [string]: number }
	local ok, value = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("Upgrades") or "{}") :: string)
	end)
	return if ok and typeof(value) == "table" then value else {}
end

local function renderShop()
	if not shop.Visible then
		return
	end
	local t = workspace:GetServerTimeNow()
	local money = (player:GetAttribute("Money") or 0) :: number
	local income = (player:GetAttribute("Income") or 0) :: number
	local upgrades = decodeUpgrades()
	for id, tabButton in tabButtons do
		tabButton.BackgroundColor3 = if id == shopTab then Color3.fromRGB(90, 110, 130) else Color3.fromRGB(52, 64, 76)
	end
	for _, entry in shopEntries do
		entry.row.Visible = entry.category == shopTab
		local price: number? = nil
		if entry.kind == "Item" then
			price = Config.itemPrice(entry.id, income)
			if entry.id == "EMP" then
				local ready = ((player:GetAttribute("EmpReadyAt") or 0) :: number) - t
				entry.info.Text = if ready > 0 then ("충전 중 %d초"):format(math.ceil(ready)) else "사면 바로 터져요 · 가격은 내 수입에 따라 올라요"
				if ready > 0 then
					price = nil
				end
			else
				local left = ((player:GetAttribute("GlovesUntil") or 0) :: number) - t
				entry.info.Text = if left > 0 then ("착용 중 %d:%02d"):format(left // 60, math.floor(left) % 60) else "가격은 내 수입에 따라 올라요"
				if left > 0 then
					price = nil
				end
			end
		else
			local level = upgrades[entry.id] or 0
			local current = Config.upgradeValue(entry.id, level)
			price = Config.upgradeCost(entry.id, level)
			local isToggle = #Config.Upgrades[entry.id].values == 2 and Config.Upgrades[entry.id].values[1] == 0
			if isToggle then
				entry.info.Text = if current > 0 then "보유 중" else "아직 없음"
			else
				entry.info.Text = if price
					then ("현재 %s → 다음 %s"):format(tostring(current), tostring(Config.upgradeValue(entry.id, level + 1)))
					else ("최고 단계 (%s)"):format(tostring(current))
			end
		end
		if price then
			entry.buy.Text = "💰 " .. Config.formatMoney(price)
			entry.buy.BackgroundColor3 = if money >= price then Color3.fromRGB(60, 140, 80) else Color3.fromRGB(90, 70, 70)
			entry.buy.Active = true
		else
			entry.buy.Text = if entry.kind == "Item" then "사용 중" else "완료"
			entry.buy.BackgroundColor3 = Color3.fromRGB(70, 82, 96)
			entry.buy.Active = false
		end
	end
end

-- 경보기: 침입자를 잠깐 빨갛게 표시한다
local function highlightIntruder(userId: number)
	local intruder = Players:GetPlayerByUserId(userId)
	local character = intruder and intruder.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- 벽 너머로도 보이게
	highlight.Parent = character
	task.delay(6, function()
		highlight:Destroy()
	end)
end

-- 알림 (위쪽 가운데에 잠깐 떴다 사라짐)
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
toastArea.Position = UDim2.new(0.5, 0, 0, 60)
toastArea.Size = UDim2.new(0.8, 0, 0, 200)
toastArea.BackgroundTransparency = 1
toastArea.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastArea

local toastColors = {
	Info = Color3.fromRGB(40, 60, 80),
	Alert = Color3.fromRGB(150, 50, 50),
	Global = Color3.fromRGB(150, 110, 20),
	Money = Color3.fromRGB(40, 120, 60),
}
local function toast(kind: string, text: string)
	local box = Instance.new("TextLabel")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.BackgroundColor3 = toastColors[kind] or toastColors.Info
	box.BackgroundTransparency = 0.1
	box.TextColor3 = white
	box.Font = Enum.Font.GothamBold
	box.TextSize = 15
	box.TextWrapped = true
	box.Text = text
	box.Parent = toastArea
	corner(box, 8)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(460, 30)
	constraint.Parent = box
	-- 너무 많이 쌓이면 오래된 것부터 지운다
	local count = 0
	for _, child in toastArea:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in toastArea:GetChildren() do
			if child:IsA("TextLabel") and child ~= box then
				child:Destroy()
				break
			end
		end
	end
	task.delay(if kind == "Money" then 1.5 else 3.5, function()
		if box.Parent then
			TweenService:Create(box, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(0.45, function()
				box:Destroy()
			end)
		end
	end)
end
notifyRemote.OnClientEvent:Connect(function(kind: unknown, text: unknown, userId: unknown)
	if typeof(kind) == "string" and typeof(text) == "string" then
		toast(if kind == "Alarm" then "Alert" else kind, text)
		if kind == "Alarm" and typeof(userId) == "number" then
			highlightIntruder(userId)
		end
	end
end)

-- 컨베이어 벨트 (이 화면에서 움직여 그린다) ------------------------------------------
local startPos = beltPart:GetAttribute("StartPos") :: Vector3
local endPos = beltPart:GetAttribute("EndPos") :: Vector3
local direction = (endPos - startPos).Unit
local beltFolder = Instance.new("Folder")
beltFolder.Name = "JunkyardBeltLocal"
beltFolder.Parent = workspace

type BeltVisual = { model: Model, spawnTime: number, height: number }
local beltVisuals: { [number]: BeltVisual } = {}

local function makeBeltRobot(id: number, robotId: string): Model
	local robot = Config.getRobot(robotId)
	local rarity = Config.rarityOf(robotId)
	local size = if rarity then rarity.size else 1
	local color = if rarity then rarity.color else white
	local model = Instance.new("Model")
	model.Name = "BeltRobot"
	local function piece(name: string, partSize: Vector3, offset: Vector3, pieceColor: Color3): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Size = partSize * size
		object.CFrame = CFrame.new(offset * size)
		object.Color = pieceColor
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.Parent = model
		return object
	end
	local body = piece("Body", Vector3.new(2.2, 2, 1.7), Vector3.zero, color)
	local head = piece("Head", Vector3.new(2.4, 1.5, 1.9), Vector3.new(0, 1.75, 0), color)
	head.Orientation = Vector3.new(0, 0, 15) -- 고장 나서 기운 머리
	for _, dx in { -0.5, 0.5 } do
		piece("Eye", Vector3.new(0.3, 0.3, 0.1), Vector3.new(dx, 1.85, -0.98), dark)
	end
	model.PrimaryPart = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = if robot and rarity then ("%s [%s] · 초당 %s"):format(robot.name, rarity.name, Config.formatMoney(rarity.income)) else robotId
	prompt.ActionText = if rarity then ("구매 %s"):format(Config.formatMoney(rarity.price)) else "구매"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		actionRemote:FireServer("Buy", id)
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.3 * size, 0)
	billboard.MaxDistance = 70
	billboard.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = color
	text.Text = if robot and rarity then ("%s [%s]\n💰 %s"):format(robot.name, rarity.name, Config.formatMoney(rarity.price)) else robotId
	text.Parent = billboard
	model.Parent = beltFolder
	return model
end

local function addBeltItem(item: any)
	if typeof(item) ~= "table" or beltVisuals[item.id] then
		return
	end
	local rarity = Config.rarityOf(item.robotId)
	beltVisuals[item.id] = {
		model = makeBeltRobot(item.id, item.robotId),
		spawnTime = item.spawnTime,
		height = if rarity then rarity.size else 1,
	}
end

local function removeBeltItem(id: number)
	local visual = beltVisuals[id]
	if visual then
		visual.model:Destroy()
		beltVisuals[id] = nil
	end
end

beltRemote.OnClientEvent:Connect(function(kind: unknown, payload: any)
	if kind == "Add" then
		addBeltItem(payload)
	elseif kind == "Remove" and typeof(payload) == "number" then
		removeBeltItem(payload)
	elseif kind == "Snapshot" and typeof(payload) == "table" then
		for _, item in payload do
			addBeltItem(item)
		end
	end
end)
beltRemote:FireServer("Sync")

local facing = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)) -- 북쪽 기지 쪽을 보게
RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, visual in beltVisuals do
		local position = startPos + direction * Config.BeltSpeed * (now - visual.spawnTime)
		visual.model:PivotTo(CFrame.new(position + Vector3.new(0, visual.height, 0)) * facing)
	end
end)

-- 받침대 버튼 문구: 내 기지면 팔기, 남의 기지면 훔치기 -----------------------------------
local function syncPadPrompts()
	for _, base in basesFolder:GetChildren() do
		local mine = base:GetAttribute("OwnerUserId") == player.UserId
		local pads = base:FindFirstChild("Pads")
		if pads then
			for _, pad in pads:GetChildren() do
				local prompt = pad:FindFirstChild("RobotPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					if mine then
						local robotId: string? = nil
						for _, robot in Config.Robots do
							if robot.name == prompt.ObjectText then
								robotId = robot.id
							end
						end
						local rarity = if robotId then Config.rarityOf(robotId) else nil
						prompt.ActionText = if rarity then ("팔기 +%s"):format(Config.formatMoney(rarity.price * Config.SellRate)) else "팔기"
					else
						prompt.ActionText = "훔치기"
					end
					-- 도둑 장갑을 끼면 남의 받침대를 짧게 눌러도 된다 (서버도 같은 시간으로 확인)
					local gloves = workspace:GetServerTimeNow() < ((player:GetAttribute("GlovesUntil") or 0) :: number)
					prompt.HoldDuration = if not mine and gloves then Config.GlovesHold else Config.StealHold
				end
			end
		end
	end
end

-- 화면 갱신 ----------------------------------------------------------------------
local function render()
	gui.Enabled = player:GetAttribute("Mode") == "Junkyard"
	local money = (player:GetAttribute("Money") or 0) :: number
	local income = (player:GetAttribute("Income") or 0) :: number
	local multiplier = (player:GetAttribute("Multiplier") or 1) :: number
	moneyLabel.Text = "💰 " .. Config.formatMoney(money)
	incomeLabel.Text = ("초당 +%s   (도감 보너스 x%.2f)"):format(Config.formatMoney(income), multiplier)
	saveLabel.Text = if player:GetAttribute("Loading") == true then "⏳ 불러오는 중"
		elseif player:GetAttribute("SaveOff") == true then "⚠ 저장 안 됨"
		else ""

	local carrying = player:GetAttribute("Carrying")
	local stunned = ((player:GetAttribute("StunnedUntil") or 0) :: number) - workspace:GetServerTimeNow()
	if stunned > 0 then
		carryLabel.Text = ("⚡ EMP에 맞아 멈춤! %d초"):format(math.ceil(stunned))
		carryLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	elseif typeof(carrying) == "string" and carrying ~= "" then
		local robot = Config.getRobot(carrying)
		local stolen = player:GetAttribute("CarryStolen") == true
		carryLabel.Text = ("%s %s 운반 중 → 내 기지의 빈 받침대로"):format(if stolen then "🦹 훔친" else "📦", if robot then robot.name else carrying)
		carryLabel.TextColor3 = if stolen then Color3.fromRGB(255, 140, 140) else white
	else
		carryLabel.Text = "벨트에서 로봇을 사서 기지에 놓으면 돈을 벌어요. 금고를 밟아 돈을 받으세요."
		carryLabel.TextColor3 = muted
	end

	local t = workspace:GetServerTimeNow()
	local trainUntil = (workspace:GetAttribute("TrainUntil") or 0) :: number
	local nextTrain = (workspace:GetAttribute("NextTrainAt") or 0) :: number
	if t < trainUntil then
		trainLabel.Text = ("🚂 희귀 로봇 열차 운행 중! %d초"):format(math.ceil(trainUntil - t))
	elseif nextTrain > t then
		local left = math.ceil(nextTrain - t)
		trainLabel.Text = ("🚂 다음 희귀 로봇 열차 %d:%02d"):format(left // 60, left % 60)
	else
		trainLabel.Text = ""
	end
	local lockedUntil = (player:GetAttribute("LockedUntil") or 0) :: number
	local cooldownUntil = (player:GetAttribute("LockCooldownUntil") or 0) :: number
	if t < lockedUntil then
		lockButton.Text = ("🛡 방어 중 %d초"):format(math.ceil(lockedUntil - t))
		lockButton.BackgroundColor3 = Color3.fromRGB(40, 150, 200)
	elseif t < cooldownUntil then
		lockButton.Text = ("충전 중 %d초"):format(math.ceil(cooldownUntil - t))
		lockButton.BackgroundColor3 = Color3.fromRGB(70, 82, 96)
	else
		lockButton.Text = "🛡 방어막 켜기"
		lockButton.BackgroundColor3 = Color3.fromRGB(60, 120, 170)
	end

	-- 도감
	local owned: { [string]: boolean } = {}
	local ok, list = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("Catalog") or "[]") :: string)
	end)
	local count = 0
	if ok and typeof(list) == "table" then
		for _, id in list do
			owned[id] = true
			count += 1
		end
	end
	catalogTitle.Text = ("로봇 도감 %d/%d"):format(count, #Config.Robots)
	for i, robot in Config.Robots do
		local rarity = Config.Rarities[robot.rarity]
		local row = catalogRows[i]
		if owned[robot.id] then
			row.Text = ("✓ %s\n[%s] 초당 %s"):format(robot.name, rarity.name, Config.formatMoney(rarity.income))
			row.TextColor3 = rarity.color
		else
			row.Text = ("○ ???\n[%s]"):format(rarity.name)
			row.TextColor3 = muted
		end
	end
	local lines = { "세트 보너스 (등급의 로봇 3종을 모두 모으면 수입 증가):" }
	for _, rarityId in Config.RarityOrder do
		local rarity = Config.Rarities[rarityId]
		local have = 0
		for _, robot in Config.Robots do
			if robot.rarity == rarityId and owned[robot.id] then
				have += 1
			end
		end
		table.insert(lines, ("%s %s %d/3 → +%d%%"):format(if have >= 3 then "✓" else "·", rarity.name, have, math.floor(rarity.setBonus * 100)))
	end
	bonusLabel.Text = table.concat(lines, "   ")
end

-- 방어막 남은 시간: 모든 기지 위에 크게 띄운다 (누구 기지가 잠겼는지 멀리서도 보이게)
local shieldLabels: { [Instance]: TextLabel } = {}
local function syncShieldTimers()
	local t = workspace:GetServerTimeNow()
	for _, base in basesFolder:GetChildren() do
		local floor = base:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local text = shieldLabels[base]
			if not text then
				local board = Instance.new("BillboardGui")
				board.Name = "ShieldTimer"
				board.Size = UDim2.fromOffset(240, 44)
				board.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
				board.AlwaysOnTop = true
				board.MaxDistance = 300
				board.Parent = floor
				local newText = Instance.new("TextLabel")
				newText.Size = UDim2.fromScale(1, 1)
				newText.BackgroundColor3 = Color3.fromRGB(20, 60, 90)
				newText.BackgroundTransparency = 0.2
				newText.TextColor3 = Color3.fromRGB(150, 230, 255)
				newText.Font = Enum.Font.GothamBold
				newText.TextSize = 24
				newText.Parent = board
				corner(newText, 8)
				shieldLabels[base] = newText
				text = newText
			end
			local remaining = ((base:GetAttribute("LockedUntil") or 0) :: number) - t
			local label = text :: TextLabel
			label.Visible = remaining > 0
			if remaining > 0 then
				label.Text = ("🛡 방어막 %d초"):format(math.ceil(remaining))
			end
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	render()
	syncShieldTimers()
	renderShop()
end)
task.spawn(function()
	while true do
		syncPadPrompts()
		task.wait(1)
	end
end)
render()
