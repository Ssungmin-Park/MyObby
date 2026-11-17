--!strict
-- JunkyardCCTV: 순위판 위 CCTV 화면에 전체 서버 환생 1위의 기지를 작은 모형으로 "생중계"한다 (서버 전용, Junkyard가 시작).
-- 1위가 이 서버에 있으면 지금 기지를, 다른 서버에 있으면 저장 데이터(1분마다 자동 저장 → 최대 1~2분 전)를 보여 준다.
-- 남의 저장 데이터는 JunkyardSave.peekAsync로 읽기만 한다 (쓰기·잠금 없음).
-- 화면: Workspace/Junkyard/Rankings/CCTV/Screen 의 SurfaceGui "CCTVGui"
--   View(ViewportFrame: 기지 모형, 속성 Focus·Radius) · Scan(줄무늬) · Title · Live · Clock · Info · NoSignal
-- 카메라 회전·LIVE 깜빡임·시계는 클라이언트(JunkyardHud)가 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local JunkyardRanking = require(script.Parent:WaitForChild("JunkyardRanking"))
local JunkyardSave = require(script.Parent:WaitForChild("JunkyardSave"))

export type Layout = { userId: number, name: string, rebirth: number, expand: number, pads: { [number]: string }, live: boolean }
export type Callbacks = {
	liveLayout: (userId: number) -> Layout?, -- 그 사람이 이 서버에 있으면 지금 기지
	makeRobot: (key: string) -> Model, -- 받침대 로봇과 같은 모형
}

local CCTV = {}
CCTV.Interval = 20 -- 화면을 다시 확인하는 간격(초)
CCTV.SavedRefresh = 60 -- 다른 서버 1위의 저장 데이터를 다시 읽는 간격(초)

-- 기지 모양 본: Base1 바닥 중심 기준 받침대 위치 (벨트 쪽이 +Z가 되게 맞춘다)
type PadSpot = { offset: Vector3, level: number }
local padSpots: { [number]: PadSpot } = {}
local floorColor = Color3.fromRGB(70, 78, 88)
local wallColor = Color3.fromRGB(74, 68, 62)

local function readTemplate()
	local base = workspace:WaitForChild("Junkyard"):WaitForChild("Bases"):WaitForChild("Base1")
	local floor = base:WaitForChild("Floor") :: BasePart
	local center = floor:GetAttribute("OrigPosition")
	local front = (base:GetAttribute("Front") or 1) :: number
	if typeof(center) ~= "Vector3" then
		center = floor.Position
	end
	floorColor = floor.Color
	for _, child in base:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Wall" then
			wallColor = child.Color
			break
		end
	end
	local pads = base:WaitForChild("Pads")
	for _, pad in pads:GetChildren() do
		local index = pad:GetAttribute("PadIndex")
		if pad:IsA("BasePart") and typeof(index) == "number" then
			local offset = pad.Position - (center :: Vector3)
			padSpots[index] = { offset = Vector3.new(offset.X, 0, offset.Z * front), level = (pad:GetAttribute("ExpandLevel") or 0) :: number }
		end
	end
end

local function block(parent: Instance, size: Vector3, position: Vector3, color: Color3): Part
	local object = Instance.new("Part")
	object.Size = size
	object.CFrame = CFrame.new(position)
	object.Color = color
	object.Anchored = true
	object.CanCollide = false
	object.CanQuery = false
	object.CanTouch = false
	object.Parent = parent
	return object
end

-- 화면 틀 (한 번만 만든다)
type Screen = { view: ViewportFrame, camera: Camera, title: TextLabel, info: TextLabel, noSignal: TextLabel }
local function ensureGui(screenPart: BasePart): Screen
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CCTVGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local view = Instance.new("ViewportFrame")
	view.Name = "View"
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundColor3 = Color3.fromRGB(12, 16, 20)
	view.Ambient = Color3.fromRGB(170, 170, 170)
	view.LightColor = Color3.fromRGB(255, 245, 230)
	view.LightDirection = Vector3.new(-0.5, -1, -0.4)
	view.Parent = gui
	local camera = Instance.new("Camera")
	camera.FieldOfView = 45
	camera.Parent = view
	view.CurrentCamera = camera
	-- CCTV 줄무늬 (가로줄)
	local scan = Instance.new("Frame")
	scan.Name = "Scan"
	scan.Size = UDim2.fromScale(1, 1)
	scan.BackgroundTransparency = 1
	scan.ZIndex = 2
	scan.Parent = gui
	for i = 0, 59 do
		local line = Instance.new("Frame")
		line.Position = UDim2.new(0, 0, i / 60, 0)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.75
		line.BorderSizePixel = 0
		line.ZIndex = 2
		line.Parent = scan
	end
	local function text(name: string, position: UDim2, size: UDim2, color: Color3, align: Enum.TextXAlignment): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = position
		label.Size = size
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.TextXAlignment = align
		label.ZIndex = 3
		label.Text = ""
		label.Parent = gui
		return label
	end
	local title = text("Title", UDim2.fromOffset(24, 14), UDim2.new(0.75, -24, 0, 46), Color3.fromRGB(255, 225, 120), Enum.TextXAlignment.Left)
	local live = text("Live", UDim2.new(1, -184, 0, 14), UDim2.fromOffset(160, 46), Color3.fromRGB(255, 70, 70), Enum.TextXAlignment.Right)
	live.Text = "● LIVE"
	text("Clock", UDim2.new(0, 24, 1, -56), UDim2.new(0.45, 0, 0, 40), Color3.fromRGB(200, 230, 200), Enum.TextXAlignment.Left)
	local info = text("Info", UDim2.new(0.45, 0, 1, -56), UDim2.new(0.55, -24, 0, 40), Color3.fromRGB(220, 230, 240), Enum.TextXAlignment.Right)
	local noSignal = text("NoSignal", UDim2.fromScale(0.2, 0.4), UDim2.fromScale(0.6, 0.2), Color3.fromRGB(200, 200, 200), Enum.TextXAlignment.Center)
	noSignal.Text = "📡 신호 찾는 중..."
	gui.Parent = screenPart
	return { view = view, camera = camera, title = title, info = info, noSignal = noSignal }
end

-- 기지 모형을 다시 만든다
local function build(screen: Screen, layout: Layout, makeRobot: (key: string) -> Model)
	for _, child in screen.view:GetChildren() do
		if not child:IsA("Camera") then
			child:Destroy()
		end
	end
	local scene = Instance.new("Model")
	scene.Name = "Scene"
	local depth = Config.Expansion.Depth * layout.expand
	local length = 34 + depth
	local middle = -depth / 2 -- 바닥 중심 Z (뒤쪽으로 늘어난 만큼)
	block(scene, Vector3.new(44, 0.4, length), Vector3.new(0, 0, middle), floorColor)
	block(scene, Vector3.new(44, 6, 1), Vector3.new(0, 3, -17 - depth), wallColor) -- 뒷벽
	for _, x in { -22, 22 } do
		block(scene, Vector3.new(1, 6, length), Vector3.new(x, 3, middle), wallColor) -- 옆벽
	end
	for _, x in { -14, 14 } do
		block(scene, Vector3.new(16, 6, 1), Vector3.new(x, 3, 17), wallColor) -- 앞벽 (가운데가 입구)
	end
	local count = 0
	for index, spot in padSpots do
		if spot.level <= layout.expand then
			local padPosition = spot.offset + Vector3.new(0, 0.4, 0)
			block(scene, Vector3.new(5, 0.4, 5), padPosition, Color3.fromRGB(70, 78, 88))
			local key = layout.pads[index]
			if key and Config.isValidKey(key) then
				local robot = makeRobot(key)
				for _, object in robot:GetDescendants() do
					if object:IsA("BillboardGui") or object:IsA("Sparkles") then
						object:Destroy()
					end
				end
				local rarity = Config.rarityOf(key)
				local position = padPosition + Vector3.new(0, 0.2 + (if rarity then rarity.size else 1), 0)
				robot:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
				robot.Parent = scene
				count += 1
			end
		end
	end
	scene.Parent = screen.view
	local focus = Vector3.new(0, 0, middle)
	local radius = math.max(44, length) * 1.05
	screen.view:SetAttribute("Focus", focus)
	screen.view:SetAttribute("Radius", radius)
	screen.camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, radius * 0.55, radius), focus)
	screen.title.Text = ("📹 전체 서버 1위 · %s"):format(layout.name)
	screen.info.Text = ("환생 %s · 확장 %d단계 · 로봇 %d대%s"):format(Config.rebirthMark(layout.rebirth), layout.expand, count, if layout.live then "" else " · 저장 기록")
	screen.noSignal.Visible = false
end

-- 다른 서버 1위: 저장 데이터를 읽기만 한다 (SavedRefresh초마다 한 번)
local savedCache: { userId: number, at: number, layout: Layout? }? = nil
local function savedLayout(userId: number): Layout?
	local cache = savedCache
	if cache and cache.userId == userId and os.clock() - cache.at < CCTV.SavedRefresh then
		return cache.layout
	end
	local data = JunkyardSave.peekAsync(userId)
	local layout: Layout? = nil
	if data then
		local pads: { [number]: string } = {}
		for key, robotId in data.pads do
			local index = tonumber(key)
			if index then
				pads[index] = robotId
			end
		end
		layout = { userId = userId, name = JunkyardRanking.nameOf(userId), rebirth = data.rebirth, expand = data.expand, pads = pads, live = false }
	end
	savedCache = { userId = userId, at = os.clock(), layout = layout }
	return layout
end

-- 바뀌었는지 비교용 글자 (받침대 번호 순서대로)
local function signatureOf(layout: Layout): string
	local parts = { tostring(layout.userId), layout.name, tostring(layout.rebirth), tostring(layout.expand), tostring(layout.live) }
	for index = 1, Config.MaxPads do
		table.insert(parts, layout.pads[index] or "-")
	end
	return table.concat(parts, "|")
end

local started = false
function CCTV.start(screenPart: BasePart, callbacks: Callbacks)
	if started then
		return
	end
	started = true
	readTemplate()
	local screen = ensureGui(screenPart)
	local lastSignature = ""
	task.spawn(function()
		while true do
			local userId = JunkyardRanking.topUserId("Rebirth")
			local layout: Layout? = nil
			if userId then
				layout = callbacks.liveLayout(userId) or savedLayout(userId)
			end
			if layout then
				local signature = signatureOf(layout)
				if signature ~= lastSignature then
					lastSignature = signature
					local ok, err = pcall(build, screen, layout, callbacks.makeRobot)
					if not ok then
						warn("[JunkyardCCTV] 화면 그리기 실패: " .. tostring(err))
					end
				end
			end
			task.wait(if layout then CCTV.Interval else 5) -- 아직 1위를 모르면 자주 확인
		end
	end)
end

return CCTV
