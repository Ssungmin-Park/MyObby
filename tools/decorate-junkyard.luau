--!strict
-- 마이오비 편집 모드에서 노을빛 고물상을 생성한다.
-- 기존 장식이 있으면 중단한다. 다시 만들려면 기존 장식을 먼저 보관한다.
local history = game:GetService("ChangeHistoryService")
local lighting = game:GetService("Lighting")
local runService = game:GetService("RunService")
assert(game.PlaceId == 77293997616106 and not runService:IsRunning(), "마이오비 편집 모드에서 실행하세요.")

local yard = workspace:WaitForChild("Junkyard")
local floor = yard:WaitForChild("Floor") :: BasePart
local bases = yard:WaitForChild("Bases")
local belt = yard:WaitForChild("Belt") :: BasePart
assert(not yard:FindFirstChild("Decor") and not lighting:FindFirstChild("JunkyardGrade"), "기존 장식과 조명이 있습니다.")

local decor = Instance.new("Folder")
decor.Name = "Decor"

local function group(name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = decor
	return folder
end

local boundary = group("Perimeter")
local stock = group("ScrapAndContainers")
local cranes = group("MagnetCrane")
local lanes = group("YardMarkings")
local machines = group("BeltTrim")
local signs = group("BaseAndYardSigns")

local steel = Color3.fromRGB(55, 64, 67)
local darkSteel = Color3.fromRGB(38, 45, 46)
local cleanSteel = Color3.fromRGB(99, 108, 102)
local warmGray = Color3.fromRGB(111, 102, 88)
local rust = Color3.fromRGB(117, 64, 43)
local rustLight = Color3.fromRGB(153, 87, 53)
local amber = Color3.fromRGB(230, 158, 58)
local cream = Color3.fromRGB(245, 228, 187)
local ground = Color3.fromRGB(124, 111, 91)
local metal = Enum.Material.Metal
local plate = Enum.Material.DiamondPlate
local corroded = Enum.Material.CorrodedMetal
local paint = Enum.Material.SmoothPlastic
local random = Random.new(772939)
local count = 0

local function block(parent: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	count += 1
	return part
end

local function beam(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material)
	block(parent, name, CFrame.lookAt((from + to) / 2, to), Vector3.new(width, width, (from - to).Magnitude), color, material)
end

local function signFace(parent: Instance, name: string, cf: CFrame, width: number, height: number, color: Color3, title: string, subtitle: string)
	local body = block(parent, name, cf, Vector3.new(width, height, 0.32), color, metal)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(640, 200)
	surface.LightInfluence = 0.35
	surface.MaxDistance = 190
	surface.Parent = body
	local function textRow(text: string, y: number, h: number, textColor: Color3)
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(0.94, h)
		row.Position = UDim2.fromScale(0.03, y)
		row.TextColor3 = textColor
		row.TextScaled = true
		row.Text = text
		row.Font = Enum.Font.GothamBlack
		row.Parent = surface
	end
	textRow(title, 0.08, 0.52, cream)
	textRow(subtitle, 0.66, 0.22, Color3.fromRGB(244, 202, 128))
end

-- 외벽과 철망은 바닥 경계 밖에 둔다. 아래가 뚫려 보이지 않도록 외벽을 내려 그린다.
local function fenceRun(origin: CFrame, length: number, sections: number)
	local bay = length / sections
	for index = 0, sections - 1 do
		local x = -length / 2 + bay * (index + 0.5)
		local color = if index % 3 == 1 then rust else steel
		block(boundary, "Sheathing", origin * CFrame.new(x, -7, 0), Vector3.new(bay + 0.14, 25, 0.8), color, corroded)
		block(boundary, "FencePost", origin * CFrame.new(x - bay / 2, 8.2, 0), Vector3.new(0.7, 9.2, 0.65), darkSteel, metal)
		block(boundary, "TopRail", origin * CFrame.new(x, 12.5, 0), Vector3.new(bay, 0.35, 0.32), cleanSteel, metal)
		local rise = index % 2 == 0
		local from = origin:PointToWorldSpace(Vector3.new(x - bay / 2, if rise then 5.5 else 12.5, 0))
		local to = origin:PointToWorldSpace(Vector3.new(x + bay / 2, if rise then 12.5 else 5.5, 0))
		beam(boundary, "FenceBrace", from, to, 0.16, cleanSteel, metal)
	end
	block(boundary, "EndPost", origin * CFrame.new(length / 2, 8.2, 0), Vector3.new(0.7, 9.2, 0.65), darkSteel, metal)
end

fenceRun(CFrame.new(420, 40.5, -3), 264, 10)
fenceRun(CFrame.new(420, 40.5, 203), 264, 10)
fenceRun(CFrame.new(287, 40.5, 100) * CFrame.Angles(0, math.pi / 2, 0), 206, 8)
fenceRun(CFrame.new(553, 40.5, 100) * CFrame.Angles(0, math.pi / 2, 0), 206, 8)
for _, z in { -20, 220 } do
	block(stock, "OuterStockGround", CFrame.new(420, 39.4, z), Vector3.new(286, 1, 35), ground, Enum.Material.Concrete)
end
for _, x in { 270, 570 } do
	block(stock, "OuterStockGround", CFrame.new(x, 39.4, 100), Vector3.new(36, 1, 200), ground, Enum.Material.Concrete)
end

local stockColors = { rust, rustLight, cleanSteel, steel, Color3.fromRGB(79, 88, 75), warmGray }
local function scrapPile(x: number, z: number, width: number)
	for index = 1, 8 do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(0, width / 2)
		local cf = CFrame.new(x + math.cos(angle) * radius, 41.4 + (1 - radius / width) * (index % 4) * 1.4, z + math.sin(angle) * radius)
			* CFrame.Angles(random:NextNumber(-0.42, 0.42), angle, random:NextNumber(-0.75, 0.75))
		local size = Vector3.new(random:NextNumber(2, 7), random:NextNumber(0.45, 2), random:NextNumber(2, 6))
		block(stock, "DiscardedFrame", cf, size, stockColors[random:NextInteger(1, #stockColors)], if index % 5 == 0 then plate else corroded)
	end
end

for _, position in {
	Vector3.new(317, 0, -16), Vector3.new(372, 0, -21), Vector3.new(424, 0, -15), Vector3.new(475, 0, -23),
	Vector3.new(522, 0, -16), Vector3.new(328, 0, 217), Vector3.new(389, 0, 224), Vector3.new(448, 0, 217),
	Vector3.new(516, 0, 223), Vector3.new(566, 0, 47), Vector3.new(569, 0, 156), Vector3.new(274, 0, 171),
} do
	scrapPile(position.X, position.Z, 20)
end

local function container(cf: CFrame, color: Color3)
	block(stock, "ContainerShell", cf, Vector3.new(22, 8, 9), color, corroded)
	for index = -4, 4, 2 do
		for _, side in { -1, 1 } do
			block(stock, "ContainerRib", cf * CFrame.new(index * 2.25, 0, side * 4.54), Vector3.new(0.24, 7.5, 0.23), color:Lerp(darkSteel, 0.27), metal)
		end
	end
	block(stock, "ContainerTop", cf * CFrame.new(0, 4.1, 0), Vector3.new(22.2, 0.25, 9.2), cleanSteel, corroded)
end
container(CFrame.new(348, 44, -20), Color3.fromRGB(92, 111, 104))
container(CFrame.new(498, 44, -23), rust)
container(CFrame.new(498, 52.3, -23), warmGray)
container(CFrame.new(360, 44, 220), Color3.fromRGB(83, 100, 98))
container(CFrame.new(480, 44, 222), rustLight)
container(CFrame.new(271, 44, 33) * CFrame.Angles(0, math.pi / 2, 0), warmGray)

local function wreck(cf: CFrame, color: Color3)
	block(stock, "WreckUndercarriage", cf, Vector3.new(10, 2, 5), color, corroded)
	block(stock, "WreckCabin", cf * CFrame.new(-0.8, 1.75, 0), Vector3.new(4.4, 1.8, 4.4), steel, metal)
	for _, side in { -1, 1 } do
		for _, x in { -3, 3 } do
			local wheel = block(stock, "WreckWheel", cf * CFrame.new(x, -0.65, side * 2.55) * CFrame.Angles(0, math.pi / 2, 0),
				Vector3.new(1, 2.3, 2.3), darkSteel, Enum.Material.Rubber)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	block(stock, "WreckBumper", cf * CFrame.new(5, -0.5, 0), Vector3.new(0.5, 0.5, 4.9), cleanSteel, metal)
end
wreck(CFrame.new(404, 41.6, -22) * CFrame.Angles(0, 0.35, 0), rustLight)
wreck(CFrame.new(414, 42.8, -24) * CFrame.Angles(0.18, -0.18, 0.25), warmGray)
wreck(CFrame.new(408, 41.6, 223) * CFrame.Angles(0, -0.52, 0), Color3.fromRGB(63, 96, 95))
wreck(CFrame.new(562, 41.6, 138) * CFrame.Angles(0, 1.35, 0), rustLight)

-- 동쪽 자석 크레인. 붐과 자석을 모두 플레이 바닥 바깥에 배치한다.
local craneX, craneZ = 568, 105
block(cranes, "CraneFoot", CFrame.new(craneX, 41, craneZ), Vector3.new(14, 2.4, 14), darkSteel, plate)
for _, x in { -2.5, 2.5 } do
	for _, z in { -2.5, 2.5 } do
		block(cranes, "TowerLeg", CFrame.new(craneX + x, 67, craneZ + z), Vector3.new(0.95, 50, 0.95), amber, metal)
	end
end
for index = 0, 7 do
	local low = 43 + index * 6
	local high = low + 6
	for _, side in { -1, 1 } do
		local z = craneZ + side * 2.5
		beam(cranes, "TowerBrace", Vector3.new(craneX - 2.5, low, z), Vector3.new(craneX + 2.5, high, z), 0.55, amber, metal)
		local x = craneX + side * 2.5
		beam(cranes, "TowerBrace", Vector3.new(x, low, craneZ - 2.5), Vector3.new(x, high, craneZ + 2.5), 0.55, amber, metal)
	end
end
block(cranes, "Cab", CFrame.new(565, 93, 105), Vector3.new(7, 4, 6), steel, plate)
block(cranes, "CabGlass", CFrame.new(564, 93.5, 101.9), Vector3.new(4.5, 1.9, 0.2), Color3.fromRGB(159, 195, 180), metal)
for _, x in { 566, 570 } do
	for _, y in { 94, 98 } do
		block(cranes, "BoomRail", CFrame.new(x, y, 102), Vector3.new(0.65, 0.65, 65), amber, metal)
	end
	for z = 74, 128, 6 do
		beam(cranes, "BoomBrace", Vector3.new(x, 94, z), Vector3.new(x, 98, z + 6), 0.55, amber, metal)
	end
end
block(cranes, "Counterweight", CFrame.new(568, 92.5, 130), Vector3.new(8, 4, 9), rust, corroded)
block(cranes, "Hoist", CFrame.new(568, 92.7, 79), Vector3.new(5, 2, 4), darkSteel, metal)
beam(cranes, "HoistCable", Vector3.new(568, 92, 79), Vector3.new(568, 64, 79), 0.2, darkSteel, metal)
local magnet = block(cranes, "ScrapMagnet", CFrame.new(568, 63.4, 79) * CFrame.Angles(0, 0, math.pi / 2),
	Vector3.new(1.1, 8, 8), rust, plate)
magnet.Shape = Enum.PartType.Cylinder
block(cranes, "MagnetLoad", CFrame.new(568, 61.9, 79) * CFrame.Angles(0.12, 0.6, 0.25),
	Vector3.new(5, 2, 4), warmGray, corroded)

-- 기지 번호와 고유 색은 입구 쪽 벽 날개 앞에 붙인다.
local baseColors = {
	Color3.fromRGB(168, 88, 45), Color3.fromRGB(57, 112, 110), Color3.fromRGB(70, 97, 140), Color3.fromRGB(136, 82, 91),
	Color3.fromRGB(113, 114, 69), Color3.fromRGB(117, 82, 141), Color3.fromRGB(146, 114, 48), Color3.fromRGB(65, 119, 85),
}
for _, model in bases:GetChildren() do
	local index = model:GetAttribute("Index") :: number
	local center = model:GetAttribute("Center") :: Vector3
	local front = model:GetAttribute("Front") :: number
	local color = assert(baseColors[index], "기지 번호 확인 필요")
	local z = center.Z + front * 17.68
	local face = Vector3.new(0, 0, front)
	local board = Vector3.new(center.X - 14, 49.15, z)
	signFace(signs, ("Base%02dSign"):format(index), CFrame.lookAt(board, board + face), 11.7, 4.7, color, ("%02d 기지"):format(index), "ROBOT SALVAGE")
	for _, side in { -1, 1 } do
		local wingX = center.X + side * 14
		block(signs, "WingCladding", CFrame.new(wingX, 44, z), Vector3.new(14.8, 4.8, 0.24), steel, corroded)
		block(signs, "WingColor", CFrame.new(wingX, 47, z + front * 0.16), Vector3.new(14.8, 0.62, 0.24), color, paint)
		block(signs, "WingCap", CFrame.new(wingX, 52.52, z), Vector3.new(14.8, 0.24, 0.38), cleanSteel, metal)
		block(lanes, "EntryEdge", CFrame.new(center.X + side * 7.2, 40.523, center.Z + front * 24),
			Vector3.new(0.45, 0.04, 10), color:Lerp(cream, 0.27), paint)
	end
end

-- 기존 순위판, 시작 지점, 벨트와 단말기의 표시는 가리지 않는다.
signFace(signs, "YardGateSign", CFrame.lookAt(Vector3.new(286, 56, 100), Vector3.new(300, 56, 100)), 26, 7, darkSteel,
	"로봇 고물상", "SALVAGE YARD  /  01")
for _, z in { 90, 110 } do
	for x = 325, 535, 15 do
		block(lanes, "LaneDash", CFrame.new(x, 40.523, z), Vector3.new(5.8, 0.04, 0.32), Color3.fromRGB(211, 174, 102), paint)
	end
end
for _, z in { 2.3, 197.7 } do
	block(lanes, "SafetyBoundary", CFrame.new(420, 40.523, z), Vector3.new(248, 0.04, 0.38), amber, paint)
end
for _, x in { 292.2, 547.8 } do
	block(lanes, "SafetyBoundary", CFrame.new(x, 40.523, 100), Vector3.new(0.38, 0.04, 188), amber, paint)
end

-- 벨트의 실제 파트는 그대로 두고 측면에 외장과 반복 무늬만 붙인다.
for _, side in { -1, 1 } do
	local z = belt.Position.Z + side * 4.67
	block(machines, "BeltSideShell", CFrame.new(belt.Position.X, 41.32, z), Vector3.new(169.2, 0.73, 0.16), darkSteel, metal)
	for x = 319, 481, 10 do
		block(machines, "BeltChevron", CFrame.new(x, 41.34, z + side * 0.105) * CFrame.Angles(0, 0, -side * 0.6),
			Vector3.new(0.47, 0.96, 0.07), amber, paint)
	end
end
for _, x in { 311, 489 } do
	local text = if x < 400 then "고철 투입구" else "선별 출구"
	signFace(machines, "BeltStationSign", CFrame.lookAt(Vector3.new(x, 48.0, 100), Vector3.new(x, 48.0, 86)), 8, 2.3, darkSteel, text, "CONVEYOR")
end

assert(count <= 650, ("장식 파트 예산 초과: %d"):format(count))
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "JunkyardGrade"
grade.Brightness = 0.035
grade.Contrast = 0.055
grade.Saturation = -0.09
grade.TintColor = Color3.fromRGB(255, 239, 218)

local recording = history:TryBeginRecording("DecorateJunkyard", "노을빛 고물상 장식")
assert(recording or history:IsRecordingInProgress(), "Studio 실행 취소 기록을 시작할 수 없습니다.")
-- 재질 교체 전 바닥의 실제 물리값을 보존한다.
floor.CustomPhysicalProperties = floor.CurrentPhysicalProperties
floor.Material = Enum.Material.Concrete
floor.Color = Color3.fromRGB(143, 132, 109)
lighting.ClockTime = 16.6
lighting.GeographicLatitude = 22
lighting.Brightness = 2.65
lighting.ExposureCompensation = 0.1
lighting.Ambient = Color3.fromRGB(128, 119, 109)
lighting.OutdoorAmbient = Color3.fromRGB(152, 146, 134)
local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Color = Color3.fromRGB(230, 209, 178)
	atmosphere.Decay = Color3.fromRGB(158, 131, 117)
	atmosphere.Density = 0.24
	atmosphere.Haze = 1.25
	atmosphere.Glare = 0.11
end
local sky = lighting:FindFirstChildOfClass("Sky")
if sky then
	sky.SunAngularSize = 19
end
local depth = lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if depth then
	depth.Enabled = false
end
grade.Parent = lighting
decor.Parent = yard
if recording then
	history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return count
