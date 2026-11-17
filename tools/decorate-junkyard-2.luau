--!strict
-- 고물상 맵 2차 꾸미기 (2026-11-17, Claude Code)
-- Edit 모드에서 한 번 실행한다. Workspace/Junkyard/Decor/Phase2 폴더를 만든다.
--   OuterGround: 맵 바깥의 흙바닥 (아래 회색 Baseplate가 안 보이게)
--   ScrapHills : 맵을 둘러싼 고물 산 두 겹 (빈 수평선을 가린다)
--   InnerScrap : 기지 사이 틈과 서쪽 구석의 상자·드럼통
--   Lamps      : 벨트 양쪽 통로의 가로등 6개 (따뜻한 불빛)
-- 그리고 기지 벽(이름 "Wall")의 색·재질만 바꾼다. 위치·크기·이름·속성은 그대로이고,
-- 원래 값은 각 벽의 속성 OrigColor·OrigMaterial에 남긴다.
-- 모든 장식은 부딪히지 않고(CanCollide·CanTouch·CanQuery = false) 그림자도 만들지 않는다.
local history = game:GetService("ChangeHistoryService")
local runService = game:GetService("RunService")
assert(game.PlaceId == 77293997616106 and not runService:IsRunning(), "마이오비 편집 모드에서 실행하세요.")

local yard = workspace:WaitForChild("Junkyard")
local decor = yard:WaitForChild("Decor")
local bases = yard:WaitForChild("Bases")
assert(not decor:FindFirstChild("Phase2"), "이미 2차 장식이 있습니다.")

local phase = Instance.new("Folder")
phase.Name = "Phase2"

local function group(name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = phase
	return folder
end

local outer = group("OuterGround")
local hills = group("ScrapHills")
local inner = group("InnerScrap")
local lamps = group("Lamps")

local rng = Random.new(20261117)
local count = 0
local GROUND_TOP = 39.5 -- 고물상 바닥(윗면 40.5)보다 1 낮게

-- 처음 색에서 60%로 어둡게 (2026-11-17 사용자 화면에서 분홍빛으로 떠 보여 낮춤)
local rustColors = {
	Color3.fromRGB(70, 38, 26),
	Color3.fromRGB(84, 49, 31),
	Color3.fromRGB(58, 42, 33),
	Color3.fromRGB(47, 44, 42),
	Color3.fromRGB(66, 59, 50),
}
local moundMaterials = { Enum.Material.CorrodedMetal, Enum.Material.Metal, Enum.Material.Slate, Enum.Material.CorrodedMetal }

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

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function tilt(maxDeg: number): CFrame
	return CFrame.Angles(math.rad(rng:NextNumber(-maxDeg, maxDeg)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-maxDeg, maxDeg)))
end

-- 1) 바깥 흙바닥 -------------------------------------------------------------------
block(outer, "DustGround", CFrame.new(420, GROUND_TOP - 0.5, 100), Vector3.new(1600, 1, 1600), Color3.fromRGB(122, 104, 82), Enum.Material.Ground)

-- 2) 고물 산 ----------------------------------------------------------------------
-- 큰 덩어리를 비스듬히 쌓고, 위에 고철 막대·판을 꽂는다
local function hill(x: number, z: number, radius: number, height: number)
	for _ = 1, 5 do
		local size = Vector3.new(rng:NextNumber(0.6, 1.1) * radius * 1.5, rng:NextNumber(0.45, 1) * height, rng:NextNumber(0.6, 1.1) * radius * 1.5)
		local offset = Vector3.new(rng:NextNumber(-0.4, 0.4) * radius, size.Y * 0.25 - 2, rng:NextNumber(-0.4, 0.4) * radius)
		block(hills, "ScrapMound", CFrame.new(x + offset.X, GROUND_TOP + offset.Y, z + offset.Z) * tilt(22), size, pick(rustColors), pick(moundMaterials))
	end
	for _ = 1, 2 do
		local size = Vector3.new(rng:NextNumber(1, 3), rng:NextNumber(10, 22), rng:NextNumber(1, 3))
		local top = GROUND_TOP + height * rng:NextNumber(0.55, 0.8)
		block(hills, "ScrapBar", CFrame.new(x + rng:NextNumber(-0.3, 0.3) * radius, top, z + rng:NextNumber(-0.3, 0.3) * radius) * tilt(40), size, pick(rustColors), Enum.Material.CorrodedMetal)
	end
end

-- 사각형 둘레를 따라 일정 간격으로 산을 놓는다 (기존 장식 바깥: X 252~588, Z -37~237)
local function ring(minX: number, maxX: number, minZ: number, maxZ: number, spacing: number, radius: NumberRange, height: NumberRange)
	local corners = { Vector2.new(minX, minZ), Vector2.new(maxX, minZ), Vector2.new(maxX, maxZ), Vector2.new(minX, maxZ) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local length = (b - a).Magnitude
		local steps = math.max(1, math.floor(length / spacing))
		for s = 0, steps - 1 do
			local p = a + (b - a) * (s / steps)
			local jitter = Vector2.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
			hill(p.X + jitter.X, p.Y + jitter.Y, rng:NextNumber(radius.Min, radius.Max), rng:NextNumber(height.Min, height.Max))
		end
	end
end
ring(225, 615, -70, 270, 42, NumberRange.new(16, 24), NumberRange.new(16, 30)) -- 안쪽 줄: 낮게
ring(160, 680, -140, 340, 64, NumberRange.new(26, 38), NumberRange.new(34, 60)) -- 바깥 줄: 높게

-- 3) 안쪽 고물: 기지 사이 틈(폭 16)과 서쪽 구석 -----------------------------------------
local crateColors = { Color3.fromRGB(150, 110, 60), Color3.fromRGB(120, 88, 50), Color3.fromRGB(90, 105, 95) }
local barrelColors = { Color3.fromRGB(170, 60, 40), Color3.fromRGB(60, 90, 140), Color3.fromRGB(200, 160, 50) }
local function crateStack(x: number, z: number)
	local base = block(inner, "Crate", CFrame.new(x, 40.5 + 2, z) * CFrame.Angles(0, math.rad(rng:NextNumber(-15, 15)), 0), Vector3.new(4, 4, 4), pick(crateColors), Enum.Material.WoodPlanks)
	if rng:NextNumber() < 0.6 then
		block(inner, "Crate", base.CFrame * CFrame.new(rng:NextNumber(-0.6, 0.6), 3.5, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0), Vector3.new(3, 3, 3), pick(crateColors), Enum.Material.WoodPlanks)
	end
end
local function barrel(x: number, z: number)
	local part = block(inner, "Barrel", CFrame.new(x, 40.5 + 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(4, 3, 3), pick(barrelColors), Enum.Material.Metal)
	part.Shape = Enum.PartType.Cylinder
end
for _, gapX in { 370, 430, 490 } do
	for _, zRange in { { 26, 54 }, { 146, 174 } } do
		for i = 0, 2 do
			local z = zRange[1] + i * 13 + rng:NextNumber(-1.5, 1.5)
			if i % 2 == 0 then
				crateStack(gapX + rng:NextNumber(-2, 2), z)
			else
				barrel(gapX + rng:NextNumber(-2.5, 2.5), z)
			end
		end
	end
end
-- 서쪽 구석(기지 1·4 왼쪽, 순위판과 떨어진 곳)
for _, z in { 12, 28, 44, 156, 172, 188 } do
	crateStack(303 + rng:NextNumber(-3, 3), z)
	barrel(311 + rng:NextNumber(-1, 1), z + 5)
end

-- 4) 가로등: 벨트 양쪽 통로, 기지 입구 통로를 피해 기지 사이 X에 둔다 --------------------
for _, x in { 370, 430, 490 } do
	for _, z in { 79, 121 } do
		local pole = block(lamps, "LampPole", CFrame.new(x, 40.5 + 7, z), Vector3.new(0.6, 14, 0.6), Color3.fromRGB(45, 48, 52), Enum.Material.Metal)
		local toward = if z < 100 then 1 else -1 -- 벨트 쪽으로 팔을 뻗는다
		block(lamps, "LampArm", pole.CFrame * CFrame.new(0, 6.7, toward * 1.5), Vector3.new(0.4, 0.4, 3.4), Color3.fromRGB(45, 48, 52), Enum.Material.Metal)
		local head = block(lamps, "LampHead", pole.CFrame * CFrame.new(0, 6.2, toward * 3), Vector3.new(1.6, 0.6, 1.6), Color3.fromRGB(255, 205, 130), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Range = 24
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = head
	end
end

-- 기록 시작 → 반영 ---------------------------------------------------------------
local recording = history:TryBeginRecording("DecorateJunkyard2", "고물상 2차 꾸미기")

-- 5) 기지 벽: 색·재질만 (원래 값 보관)
local wallCount = 0
for _, base in bases:GetChildren() do
	for _, child in base:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Wall" then
			if child:GetAttribute("OrigColor") == nil then
				child:SetAttribute("OrigColor", child.Color)
				child:SetAttribute("OrigMaterial", child.Material.Name)
			end
			child.Material = Enum.Material.CorrodedMetal
			child.Color = Color3.fromRGB(74, 68, 62) -- 어두운 쇠 색 (밝으면 녹 무늬가 분홍빛으로 보임)
			wallCount += 1
		end
	end
end

phase.Parent = decor
if recording then
	history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return ("2차 장식 파트 %d개, 바꾼 기지 벽 %d개"):format(count, wallCount)
