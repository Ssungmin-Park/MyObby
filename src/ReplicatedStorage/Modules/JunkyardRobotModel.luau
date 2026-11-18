--!strict
-- JunkyardRobotModel: 로봇 모형을 만든다. 서버(받침대·들고 가기·CCTV)와 클라이언트(벨트)가 같이 쓴다.
--
-- 모양 규칙
--   - 발이 y = 0, 얼굴이 -Z(앞). 크기는 등급 size 배수로 키운다 (모든 크기·위치에 곱함).
--   - PrimaryPart = 보이지 않는 "Body"(2.2 × 2 × 1.7, 가운데 y = 1). 예전 모형과 같은 상자라
--     받침대·머리 위에 놓는 위치 계산(PivotTo)과 버튼 위치가 그대로 맞는다.
--   - 로봇마다 이름에 맞는 생김새(DESIGNS)와 얼굴 표정. 몸 주색은 변종이면 변종 색으로 바뀐다.
--   - 등급은 빛나는 띠(trim) 색으로 보여 준다 (일반 등급은 띠 없음). 눈 부품 이름은 "Eye", 도는 부품은 "Spin".
local Config = require(script.Parent:WaitForChild("JunkyardConfig"))

local RobotModel = {}

type Ctx = { model: Model, s: number, main: Color3, trim: Color3? }
local ctx: Ctx = nil :: any

local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥(축 X)을 세운다
local FWD = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 면이 앞(-Z)을 본다
local NEON, METAL, GLASS = Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Glass
local SMOOTH = Enum.Material.SmoothPlastic
local DARK = Color3.fromRGB(28, 32, 40)
local WHITE = Color3.fromRGB(245, 248, 255)
local STEEL = Color3.fromRGB(150, 156, 166)
local JOINT = Color3.fromRGB(70, 74, 82)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- 부품 하나 (크기·위치에 등급 배수를 곱한다)
local function P(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local s = ctx.s
	local part = Instance.new("Part")
	part.Name = name or "Piece"
	part.Shape = shape
	part.Size = size * s
	part.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
	part.Color = color
	part.Material = material or SMOOTH
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = ctx.model
	return part
end
local function box(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	return P(BLOCK, size, cf, color, material, name)
end
local function ball(d: number, pos: Vector3, color: Color3, material: Enum.Material?, name: string?): Part
	return P(BALL, Vector3.new(d, d, d), CFrame.new(pos), color, material, name)
end
-- 원기둥: len = 길이(축 방향), d = 지름, cf에 UP/FWD를 곱해 방향을 정한다
local function cyl(len: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	return P(CYL, Vector3.new(len, d, d), cf, color, material, name)
end

-- 등급 띠 (일반 등급은 없음)
local function trim(size: Vector3, cf: CFrame)
	if ctx.trim then
		box(size, cf, ctx.trim, NEON, "Trim")
	end
end
local function trimRing(y: number, d: number)
	if ctx.trim then
		cyl(0.1, d, at(0, y, 0) * UP, ctx.trim, NEON, "Trim")
	end
end

-- 작은 공을 원 모양으로 늘어놓는다 (후광·궤도 고리)
local function ring(center: CFrame, radius: number, count: number, d: number, color: Color3, material: Enum.Material?)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		ball(d, (center * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius)).Position, color, material, "Spin")
	end
end

-- 짧은 다리 두 개 + 발
local function legs(x: number, len: number, foot: Color3)
	for _, sx in { -1, 1 } do
		cyl(len, 0.35, at(sx * x, len / 2, 0) * UP, JOINT, METAL)
		box(Vector3.new(0.6, 0.25, 0.8), at(sx * x, 0.12, -0.1), foot, METAL)
	end
end
-- 양팔 (어깨 x, 높이 y, 길이 len), 끝에 둥근 손
local function arms(x: number, y: number, len: number, color: Color3)
	for _, sx in { -1, 1 } do
		cyl(len, 0.3, at(sx * x, y - len / 2, 0) * UP, JOINT, METAL)
		ball(0.45, Vector3.new(sx * x, y - len - 0.1, 0), color, METAL)
	end
end
local function bolt(pos: Vector3)
	cyl(0.08, 0.2, CFrame.new(pos) * FWD, rgb(200, 205, 215), METAL)
end
-- 톱니바퀴 (앞을 보는 원판 + 이빨 8개)
local function gear(cf: CFrame, d: number, color: Color3)
	cyl(0.2, d, cf * FWD, color, METAL)
	for i = 0, 7 do
		box(Vector3.new(0.18, d * 0.28, 0.2), cf * CFrame.Angles(0, 0, math.rad(i * 45)) * CFrame.new(0, d / 2, 0), color, METAL)
	end
	cyl(0.24, d * 0.3, cf * FWD, DARK, METAL)
end

-- 얼굴: 어두운 유리 화면 + 빛나는 눈(표정). cf = 화면 가운데, w·h = 화면 크기
local function face(cf: CFrame, w: number, h: number, eye: Color3, mood: string)
	box(Vector3.new(w, h, 0.12), cf, DARK, GLASS, "Screen")
	local front = cf * CFrame.new(0, h * 0.08, -0.07)
	local function roundEye(x: number, d: number)
		cyl(0.05, d, front * CFrame.new(x, 0, 0) * FWD, eye, NEON, "Eye")
		ball(d * 0.3, (front * CFrame.new(x + d * 0.15, d * 0.18, -0.04)).Position, WHITE, NEON, "Eye")
	end
	local function mouth(width: number)
		box(Vector3.new(width, 0.07, 0.05), cf * CFrame.new(0, -h * 0.28, -0.07), eye, NEON)
	end
	if mood == "one" then
		cyl(0.05, h * 0.62, front * FWD, eye, NEON, "Eye")
		cyl(0.07, h * 0.26, front * CFrame.new(0.05, 0.05, -0.02) * FWD, DARK, NEON, "Eye")
		return
	elseif mood == "visor" then
		box(Vector3.new(w * 0.78, h * 0.24, 0.05), front, eye, NEON, "Eye")
		return
	elseif mood == "odd" then
		roundEye(-w * 0.24, h * 0.42)
		roundEye(w * 0.26, h * 0.2)
		mouth(w * 0.18)
		return
	end
	for _, sx in { -1, 1 } do
		local e = front * CFrame.new(sx * w * 0.24, 0, 0)
		if mood == "happy" then -- ^ ^
			box(Vector3.new(w * 0.15, 0.08, 0.05), e * CFrame.new(-w * 0.05, 0, 0) * CFrame.Angles(0, 0, math.rad(35)), eye, NEON, "Eye")
			box(Vector3.new(w * 0.15, 0.08, 0.05), e * CFrame.new(w * 0.05, 0, 0) * CFrame.Angles(0, 0, math.rad(-35)), eye, NEON, "Eye")
		elseif mood == "angry" then
			cyl(0.05, h * 0.3, e * FWD, eye, NEON, "Eye")
			box(Vector3.new(w * 0.26, 0.08, 0.05), e * CFrame.new(0, h * 0.22, -0.02) * CFrame.Angles(0, 0, math.rad(sx * 20)), eye, NEON)
		elseif mood == "sleepy" then -- — —
			box(Vector3.new(w * 0.22, 0.08, 0.05), e, eye, NEON, "Eye")
		elseif mood == "dizzy" then -- X X
			box(Vector3.new(w * 0.22, 0.07, 0.05), e * CFrame.Angles(0, 0, math.rad(45)), eye, NEON, "Eye")
			box(Vector3.new(w * 0.22, 0.07, 0.05), e * CFrame.Angles(0, 0, math.rad(-45)), eye, NEON, "Eye")
		else -- round
			roundEye(sx * w * 0.24, h * 0.34)
		end
	end
	if mood ~= "angry" then
		mouth(w * 0.22)
	end
end

-- 로봇별 생김새 ---------------------------------------------------------------------
local DESIGNS: { [string]: () -> () } = {}

-- 일반 -----------------------------------------------------------------------------
DESIGNS.Pippi = function() -- 동그란 몸, 큰 외눈, 빨간 불빛 안테나
	legs(0.45, 0.6, rgb(240, 180, 60))
	ball(2.4, Vector3.new(0, 1.8, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 1.95, -1.08), 1.45, 1.15, rgb(120, 230, 255), "one")
	cyl(0.8, 0.12, at(0.3, 3.3, 0) * UP, DARK, METAL)
	ball(0.38, Vector3.new(0.3, 3.75, 0), rgb(255, 80, 80), NEON)
end
DESIGNS.Nut = function() -- 머리가 커다란 육각 너트, 꼭대기에 볼트
	legs(0.5, 0.6, STEEL)
	box(Vector3.new(1.8, 1.3, 1.4), at(0, 1.25, 0), ctx.main, METAL, "Main")
	bolt(Vector3.new(-0.55, 1.4, -0.72))
	bolt(Vector3.new(0.55, 1.4, -0.72))
	cyl(0.9, 2.3, at(0, 2.9, 0) * FWD, rgb(195, 200, 210), METAL)
	face(at(0, 2.9, -0.48), 1.25, 0.95, rgb(120, 230, 255), "round")
	cyl(0.7, 0.4, at(0, 4.2, 0) * UP, STEEL, METAL)
	cyl(0.15, 0.7, at(0, 4.55, 0) * UP, STEEL, METAL)
end
DESIGNS.Sponge = function() -- 구멍 숭숭 노란 스펀지 + 초록 수세미 머리
	legs(0.55, 0.5, rgb(90, 170, 80))
	box(Vector3.new(2.3, 2.3, 1.6), at(0, 1.65, 0), ctx.main, Enum.Material.Fabric, "Main")
	box(Vector3.new(2.35, 0.55, 1.65), at(0, 3.05, 0), rgb(90, 170, 80), Enum.Material.Fabric)
	for _, p in { { -0.8, 1.0 }, { 0.75, 0.85 }, { -0.3, 0.75 }, { 0.85, 2.45 }, { -0.85, 2.5 } } do
		ball(0.28, Vector3.new(p[1], p[2], -0.78), rgb(200, 160, 50))
	end
	face(at(0, 1.85, -0.83), 1.55, 0.95, WHITE, "happy")
end
DESIGNS.Tin = function() -- 통조림 몸통 + 빨간 라벨 + 비스듬한 뚜껑, 따개 귀
	legs(0.5, 0.5, STEEL)
	cyl(2.6, 2.1, at(0, 1.8, 0) * UP, rgb(190, 196, 206), METAL)
	cyl(1.1, 2.14, at(0, 1.5, 0) * UP, ctx.main, SMOOTH, "Main")
	face(at(0, 2.5, -1.02), 1.4, 0.85, rgb(255, 230, 120), "happy")
	cyl(0.12, 2.2, at(0, 3.2, 0) * UP * CFrame.Angles(math.rad(12), 0, 0), rgb(205, 210, 218), METAL)
	box(Vector3.new(0.5, 0.08, 0.3), at(1.15, 3.35, 0) * CFrame.Angles(0, 0, math.rad(30)), rgb(205, 210, 218), METAL)
end
DESIGNS.Clip = function() -- 날씬한 몸 + 머리에 꽂힌 커다란 클립
	legs(0.4, 0.7, rgb(80, 110, 180))
	box(Vector3.new(1.4, 1.5, 1.2), at(0, 1.45, 0), ctx.main, SMOOTH, "Main")
	box(Vector3.new(1.9, 1.35, 1.4), at(0, 2.9, 0), rgb(220, 230, 250))
	face(at(0, 2.9, -0.71), 1.6, 1.05, rgb(255, 210, 90), "happy")
	local c = rgb(210, 214, 222)
	box(Vector3.new(0.09, 1.3, 0.09), at(-0.35, 4.15, 0), c, METAL)
	box(Vector3.new(0.09, 1.1, 0.09), at(0.35, 4.05, 0), c, METAL)
	box(Vector3.new(0.79, 0.09, 0.09), at(0, 4.8, 0), c, METAL)
	box(Vector3.new(0.09, 0.9, 0.09), at(-0.12, 3.95, 0), c, METAL)
	box(Vector3.new(0.56, 0.09, 0.09), at(0.11, 3.5, 0), c, METAL)
end
DESIGNS.Bucket = function() -- 녹슨 몸 + 거꾸로 쓴 파란 양동이 머리, 손잡이
	legs(0.5, 0.6, rgb(110, 90, 70))
	box(Vector3.new(1.9, 1.5, 1.4), at(0, 1.35, 0), rgb(150, 110, 80), Enum.Material.CorrodedMetal)
	bolt(Vector3.new(-0.7, 1.75, -0.72))
	bolt(Vector3.new(0.7, 1.75, -0.72))
	cyl(1.6, 2.0, at(0, 2.9, 0) * UP, ctx.main, METAL, "Main")
	cyl(0.2, 2.2, at(0, 2.15, 0) * UP, ctx.main:Lerp(Color3.new(), 0.2), METAL)
	face(at(0, 2.9, -0.97), 1.25, 0.85, rgb(140, 255, 160), "round")
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.09, 0.9, 0.09), at(sx * 1.0, 3.75, 0) * CFrame.Angles(0, 0, math.rad(-sx * 25)), JOINT, METAL)
	end
	box(Vector3.new(1.3, 0.09, 0.09), at(0, 4.15, 0), JOINT, METAL)
end
DESIGNS.Rusty = function() -- 녹슨 몸, 비뚤어진 머리, 어지러운 X 눈, 덧댄 판
	legs(0.5, 0.6, rgb(120, 80, 60))
	box(Vector3.new(2, 1.6, 1.5), at(0, 1.4, 0), ctx.main, Enum.Material.CorrodedMetal, "Main")
	box(Vector3.new(0.6, 0.5, 0.05), at(0.5, 1.6, -0.77) * CFrame.Angles(0, 0, math.rad(10)), STEEL, METAL)
	bolt(Vector3.new(0.25, 1.8, -0.8))
	local head = at(0.15, 3.0, 0) * CFrame.Angles(0, 0, math.rad(-12))
	box(Vector3.new(2, 1.4, 1.6), head, rgb(170, 110, 70), Enum.Material.CorrodedMetal)
	face(head * CFrame.new(0, 0, -0.81), 1.5, 0.95, rgb(255, 170, 80), "dizzy")
	cyl(0.6, 0.12, head * CFrame.new(-0.5, 0.95, 0) * CFrame.Angles(0, 0, math.rad(20)) * UP, JOINT, METAL)
end
DESIGNS.Scrappy = function() -- 짝짝이 부품: 큰 팔·작은 팔, 다른 색 머리, 짝눈
	legs(0.5, 0.6, rgb(90, 90, 90))
	box(Vector3.new(1.9, 1.5, 1.5), at(0, 1.35, 0), ctx.main, METAL, "Main")
	cyl(1.1, 0.55, at(-1.25, 1.4, 0) * UP, rgb(200, 150, 90), METAL)
	ball(0.8, Vector3.new(-1.25, 0.75, 0), rgb(200, 150, 90), METAL)
	cyl(0.8, 0.25, at(1.1, 1.55, 0) * UP, JOINT, METAL)
	box(Vector3.new(1.8, 1.3, 1.5), at(0, 2.85, 0), rgb(200, 150, 90), METAL)
	face(at(0, 2.85, -0.76), 1.5, 1.0, WHITE, "odd")
	cyl(0.6, 0.1, at(0.4, 3.75, 0) * UP, JOINT, METAL)
	cyl(0.5, 0.1, at(0.6, 4.1, 0) * CFrame.Angles(0, 0, math.rad(50)) * UP, JOINT, METAL)
	ball(0.25, Vector3.new(0.8, 4.25, 0), rgb(120, 255, 120), NEON)
end

-- 고급 -----------------------------------------------------------------------------
DESIGNS.Volt = function() -- 번개 안테나, 등에 건전지
	legs(0.5, 0.6, rgb(40, 70, 140))
	box(Vector3.new(1.9, 1.7, 1.5), at(0, 1.45, 0), rgb(40, 70, 140), METAL)
	box(Vector3.new(1.2, 1.2, 0.6), at(0, 1.5, 0.95), rgb(60, 200, 90))
	box(Vector3.new(0.5, 0.25, 0.3), at(0, 2.2, 0.95), rgb(230, 230, 235), METAL)
	trim(Vector3.new(1.95, 0.12, 1.55), at(0, 0.65, 0))
	box(Vector3.new(2.1, 1.45, 1.7), at(0, 3.0, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.0, -0.86), 1.7, 1.1, rgb(120, 230, 255), "happy")
	box(Vector3.new(0.28, 0.65, 0.22), at(0.12, 4.0, 0) * CFrame.Angles(0, 0, math.rad(25)), rgb(255, 230, 60), NEON)
	box(Vector3.new(0.28, 0.65, 0.22), at(-0.05, 4.45, 0) * CFrame.Angles(0, 0, math.rad(-25)), rgb(255, 230, 60), NEON)
	box(Vector3.new(0.28, 0.6, 0.22), at(0.12, 4.9, 0) * CFrame.Angles(0, 0, math.rad(25)), rgb(255, 230, 60), NEON)
end
DESIGNS.Coil = function() -- 용수철 몸 위에 둥근 머리
	legs(0.45, 0.45, rgb(200, 120, 60))
	cyl(1.5, 1.2, at(0, 1.3, 0) * UP, DARK, METAL)
	for i = 0, 4 do
		cyl(0.18, 1.8, at(0, 0.7 + i * 0.3, 0) * UP, rgb(205, 125, 60), METAL)
	end
	trimRing(2.2, 1.6)
	ball(2.1, Vector3.new(0, 3.1, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.15, -0.9), 1.3, 0.85, rgb(255, 255, 255), "round")
end
DESIGNS.Wiper = function() -- 앞유리 같은 얼굴에 와이퍼 팔
	legs(0.5, 0.6, rgb(60, 70, 90))
	box(Vector3.new(2, 1.6, 1.5), at(0, 1.4, 0), rgb(220, 225, 235))
	trim(Vector3.new(2.05, 0.12, 1.55), at(0, 0.65, 0))
	box(Vector3.new(2.3, 1.45, 1.6), at(0, 2.95, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 2.95, -0.81), 1.95, 1.15, rgb(255, 90, 90), "visor")
	box(Vector3.new(1.4, 0.09, 0.06), at(0.25, 3.0, -0.92) * CFrame.Angles(0, 0, math.rad(35)), DARK, METAL)
	ball(0.2, Vector3.new(-0.3, 2.6, -0.92), DARK, METAL)
end
DESIGNS.Magnet = function() -- 머리 위 말굽자석
	legs(0.5, 0.6, rgb(150, 30, 30))
	box(Vector3.new(1.9, 1.6, 1.5), at(0, 1.4, 0), ctx.main, SMOOTH, "Main")
	trim(Vector3.new(1.95, 0.12, 1.55), at(0, 0.65, 0))
	box(Vector3.new(2, 1.35, 1.5), at(0, 2.9, 0), rgb(230, 230, 235))
	face(at(0, 2.9, -0.76), 1.65, 1.05, rgb(90, 160, 255), "round")
	local red = rgb(220, 50, 50)
	box(Vector3.new(0.45, 1.1, 0.45), at(-0.55, 4.1, 0), red)
	box(Vector3.new(0.45, 1.1, 0.45), at(0.55, 4.1, 0), red)
	box(Vector3.new(1.55, 0.45, 0.45), at(0, 3.75, 0), red)
	box(Vector3.new(0.47, 0.3, 0.47), at(-0.55, 4.75, 0), STEEL, METAL)
	box(Vector3.new(0.47, 0.3, 0.47), at(0.55, 4.75, 0), STEEL, METAL)
end
DESIGNS.Fan = function() -- 머리 위 선풍기 날개, 배에 통풍구
	legs(0.55, 0.6, rgb(90, 160, 110))
	box(Vector3.new(2, 1.6, 1.5), at(0, 1.45, 0), rgb(235, 240, 235))
	cyl(0.12, 0.7, at(0, 1.55, -0.76) * FWD, DARK)
	trim(Vector3.new(2.25, 0.12, 1.75), at(0, 2.25, 0))
	box(Vector3.new(2.2, 1.5, 1.7), at(0, 3.0, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.0, -0.86), 1.8, 1.15, WHITE, "round")
	cyl(0.5, 0.25, at(0, 4.0, 0) * UP, DARK, METAL)
	for i = 0, 2 do
		box(Vector3.new(1.6, 0.06, 0.5), at(0, 4.25, 0) * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0.8, 0, 0) * CFrame.Angles(math.rad(15), 0, 0), rgb(150, 230, 255), SMOOTH, "Spin")
	end
end
DESIGNS.Drill = function() -- 노란 안전모 + 오른팔 드릴
	legs(0.5, 0.6, rgb(90, 90, 90))
	box(Vector3.new(1.9, 1.6, 1.5), at(0, 1.4, 0), ctx.main, SMOOTH, "Main")
	trim(Vector3.new(1.95, 0.12, 1.55), at(0, 0.65, 0))
	cyl(0.8, 0.6, at(1.3, 1.6, 0), STEEL, METAL)
	cyl(0.3, 0.5, at(1.85, 1.6, 0), rgb(200, 205, 215), METAL)
	cyl(0.3, 0.35, at(2.15, 1.6, 0), rgb(200, 205, 215), METAL)
	cyl(0.3, 0.2, at(2.45, 1.6, 0), rgb(200, 205, 215), METAL)
	box(Vector3.new(2, 1.35, 1.6), at(0, 2.9, 0), rgb(120, 125, 135), METAL)
	face(at(0, 2.9, -0.81), 1.65, 1.0, rgb(255, 200, 80), "angry")
	cyl(0.55, 2.1, at(0, 3.85, 0) * UP, rgb(250, 200, 40))
	box(Vector3.new(2.5, 0.1, 2.0), at(0, 3.6, -0.1), rgb(250, 200, 40))
end
DESIGNS.Hopper = function() -- 개구리처럼 머리 위 눈, 용수철 다리
	for _, sx in { -1, 1 } do
		for i = 0, 3 do
			cyl(0.1, 0.5, at(sx * 0.6, 0.15 + i * 0.18, 0) * UP, STEEL, METAL)
		end
		box(Vector3.new(0.8, 0.2, 1.0), at(sx * 0.6, 0.08, -0.15), rgb(60, 130, 60))
	end
	ball(2.2, Vector3.new(0, 1.8, 0), ctx.main, SMOOTH, "Main")
	trimRing(1.1, 1.7)
	for _, sx in { -1, 1 } do
		ball(0.85, Vector3.new(sx * 0.48, 2.9, -0.2), WHITE)
		ball(0.38, Vector3.new(sx * 0.48, 2.95, -0.56), DARK, NEON, "Eye")
	end
	box(Vector3.new(1.0, 0.1, 0.06), at(0, 1.9, -1.08), DARK)
end

-- 희귀 -----------------------------------------------------------------------------
DESIGNS.Lumi = function() -- 전구 머리 (빛남), 얼굴은 가슴 화면
	legs(0.45, 0.6, rgb(200, 200, 210))
	box(Vector3.new(1.7, 1.5, 1.3), at(0, 1.35, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 1.4, -0.66), 1.4, 0.95, rgb(255, 220, 120), "happy")
	trim(Vector3.new(1.75, 0.12, 1.35), at(0, 0.65, 0))
	for i = 0, 2 do
		cyl(0.14, 1.15 - i * 0.05, at(0, 2.2 + i * 0.14, 0) * UP, STEEL, METAL)
	end
	local bulb = ball(2.2, Vector3.new(0, 3.45, 0), rgb(255, 245, 200), GLASS)
	bulb.Transparency = 0.35
	ball(0.8, Vector3.new(0, 3.4, 0), rgb(255, 225, 130), NEON)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 225, 150)
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = bulb
end
DESIGNS.Spring = function() -- 상자에서 튀어나온 용수철 머리
	legs(0.55, 0.5, rgb(160, 50, 50))
	box(Vector3.new(2.1, 1.6, 1.7), at(0, 1.3, 0), rgb(240, 90, 90))
	box(Vector3.new(2.2, 0.15, 1.8), at(0, 2.1, 0), rgb(255, 210, 80))
	trim(Vector3.new(2.15, 0.12, 1.75), at(0, 0.6, 0))
	for i = 0, 4 do
		cyl(0.12, 0.9, at(0, 2.3 + i * 0.18, 0) * UP, STEEL, METAL)
	end
	box(Vector3.new(1.9, 1.4, 1.5), at(0, 3.85, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.85, -0.76), 1.6, 1.05, rgb(255, 120, 200), "happy")
end
DESIGNS.Radar = function() -- 머리 위 접시 안테나
	legs(0.5, 0.6, rgb(60, 80, 110))
	box(Vector3.new(2, 1.6, 1.5), at(0, 1.4, 0), ctx.main, METAL, "Main")
	trim(Vector3.new(2.05, 0.12, 1.55), at(0, 0.65, 0))
	box(Vector3.new(2, 1.35, 1.5), at(0, 2.9, 0), rgb(200, 210, 220))
	face(at(0, 2.9, -0.76), 1.7, 1.05, rgb(120, 255, 160), "visor")
	cyl(0.7, 0.2, at(0, 3.85, 0) * UP, JOINT, METAL)
	local dish = at(0, 4.35, 0.1) * CFrame.Angles(math.rad(-35), 0, 0)
	cyl(0.15, 2.0, dish * UP, rgb(235, 238, 245), METAL, "Spin")
	box(Vector3.new(0.08, 0.6, 0.08), dish * CFrame.new(0, 0.35, 0), JOINT, METAL, "Spin")
	ball(0.2, (dish * CFrame.new(0, 0.7, 0)).Position, rgb(255, 80, 80), NEON, "Spin")
end
DESIGNS.Prism = function() -- 유리 결정 머리, 얼굴은 가슴 화면
	legs(0.45, 0.6, rgb(50, 50, 70))
	box(Vector3.new(1.8, 1.6, 1.4), at(0, 1.4, 0), rgb(60, 60, 80), METAL)
	face(at(0, 1.45, -0.71), 1.5, 1.0, rgb(255, 140, 230), "round")
	trim(Vector3.new(1.85, 0.12, 1.45), at(0, 0.65, 0))
	local crystal = box(Vector3.new(1.5, 1.5, 1.5), at(0, 3.35, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35)), ctx.main, GLASS, "Main")
	crystal.Transparency = 0.15
	box(Vector3.new(0.6, 0.6, 0.6), at(0, 3.35, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35)), rgb(255, 255, 255), NEON)
end
DESIGNS.Turbo = function() -- 다리 대신 바퀴, 고글, 뒤에 스포일러
	for _, sx in { -1, 1 } do
		cyl(0.45, 1.0, at(sx * 0.8, 0.5, 0), DARK)
		cyl(0.5, 0.45, at(sx * 0.8, 0.5, 0), STEEL, METAL)
	end
	box(Vector3.new(2.2, 1.2, 1.8), at(0, 1.4, 0), ctx.main, SMOOTH, "Main")
	box(Vector3.new(0.4, 1.22, 1.82), at(0, 1.4, 0), WHITE)
	trim(Vector3.new(2.25, 0.1, 1.85), at(0, 0.85, 0))
	box(Vector3.new(1.8, 1.15, 1.5), at(0, 2.6, 0), WHITE)
	face(at(0, 2.6, -0.76), 1.55, 0.9, rgb(255, 220, 60), "visor")
	box(Vector3.new(2.5, 0.12, 0.6), at(0, 2.45, 1.15), DARK)
	box(Vector3.new(0.12, 0.5, 0.12), at(-0.8, 2.2, 1.1), DARK)
	box(Vector3.new(0.12, 0.5, 0.12), at(0.8, 2.2, 1.1), DARK)
end
DESIGNS.Sonar = function() -- 노란 잠수함 몸, 둥근 창 얼굴, 잠망경
	legs(0.5, 0.5, rgb(200, 160, 40))
	ball(2.5, Vector3.new(0, 1.85, 0), ctx.main, SMOOTH, "Main")
	cyl(0.2, 1.6, at(0, 1.95, -1.08) * FWD, rgb(200, 150, 70), METAL)
	face(at(0, 1.95, -1.2), 1.05, 1.05, rgb(120, 230, 255), "round")
	trimRing(1.0, 2.0)
	cyl(1.0, 0.3, at(0.45, 3.5, 0) * UP, STEEL, METAL)
	box(Vector3.new(0.3, 0.3, 0.6), at(0.45, 4.05, -0.15), STEEL, METAL)
	box(Vector3.new(0.12, 0.6, 0.6), at(0, 2.0, 1.2), ctx.main)
end

-- 에픽 -----------------------------------------------------------------------------
DESIGNS.GearKing = function() -- 톱니바퀴 왕관, 가슴 톱니
	legs(0.55, 0.7, rgb(60, 60, 75))
	box(Vector3.new(2.2, 1.8, 1.6), at(0, 1.6, 0), rgb(70, 70, 90), METAL)
	gear(at(0, 1.65, -0.85), 1.0, rgb(220, 180, 70))
	trim(Vector3.new(2.25, 0.12, 1.65), at(0, 0.75, 0))
	box(Vector3.new(2.0, 1.4, 1.6), at(0, 3.2, 0), ctx.main, METAL, "Main")
	face(at(0, 3.2, -0.81), 1.65, 1.05, rgb(255, 220, 90), "round")
	gear(at(-0.65, 4.25, 0), 0.8, rgb(230, 190, 70))
	gear(at(0, 4.45, 0), 1.0, rgb(230, 190, 70))
	gear(at(0.65, 4.25, 0), 0.8, rgb(230, 190, 70))
end
DESIGNS.Holo = function() -- 반투명 홀로그램 몸, 떠 있는 머리, 아래 영사기
	cyl(0.3, 1.8, at(0, 0.15, 0) * UP, DARK, METAL)
	trimRing(0.32, 1.85)
	local body = box(Vector3.new(1.8, 1.6, 1.4), at(0, 1.4, 0), ctx.main, NEON, "Main")
	body.Transparency = 0.45
	for i = 0, 3 do
		box(Vector3.new(1.82, 0.05, 1.42), at(0, 0.8 + i * 0.4, 0), WHITE, NEON).Transparency = 0.5
	end
	local head = box(Vector3.new(1.8, 1.3, 1.4), at(0, 3.0, 0), ctx.main, NEON)
	head.Transparency = 0.35
	face(at(0, 3.0, -0.71), 1.5, 0.95, WHITE, "happy")
end
DESIGNS.Press = function() -- 머리 위 유압 프레스 판
	legs(0.6, 0.6, rgb(60, 60, 70))
	box(Vector3.new(2.4, 1.8, 1.8), at(0, 1.5, 0), rgb(90, 90, 100), Enum.Material.DiamondPlate)
	trim(Vector3.new(2.45, 0.12, 1.85), at(0, 0.65, 0))
	box(Vector3.new(2.0, 1.25, 1.6), at(0, 3.05, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.05, -0.81), 1.7, 0.95, rgb(255, 150, 60), "angry")
	cyl(0.8, 0.3, at(-0.8, 4.05, 0) * UP, STEEL, METAL)
	cyl(0.8, 0.3, at(0.8, 4.05, 0) * UP, STEEL, METAL)
	box(Vector3.new(2.5, 0.4, 1.8), at(0, 4.6, 0), DARK, METAL)
	for i = -2, 2 do
		box(Vector3.new(0.18, 0.42, 1.82), at(i * 0.5, 4.6, 0) * CFrame.Angles(0, 0, math.rad(30)), rgb(250, 200, 40))
	end
end
DESIGNS.Forge = function() -- 불타는 용광로 배, 굴뚝, 망치 팔
	legs(0.55, 0.6, rgb(50, 45, 45))
	box(Vector3.new(2.2, 1.8, 1.7), at(0, 1.5, 0), rgb(60, 55, 55), METAL)
	box(Vector3.new(1.2, 0.8, 0.1), at(0, 1.4, -0.86), rgb(255, 120, 30), NEON)
	for i = -1, 1 do
		box(Vector3.new(0.08, 0.82, 0.12), at(i * 0.35, 1.4, -0.9), DARK, METAL)
	end
	trim(Vector3.new(2.25, 0.12, 1.75), at(0, 0.65, 0))
	box(Vector3.new(1.9, 1.3, 1.6), at(0, 3.05, 0), ctx.main, METAL, "Main")
	face(at(0, 3.05, -0.81), 1.6, 0.95, rgb(255, 140, 40), "angry")
	cyl(1.0, 0.6, at(0.5, 4.2, 0.2) * UP, DARK, METAL)
	cyl(1.0, 0.25, at(-1.4, 1.9, 0) * UP, rgb(120, 80, 50))
	box(Vector3.new(0.9, 0.5, 0.5), at(-1.4, 2.45, 0), STEEL, METAL)
end
DESIGNS.Rocket = function() -- 흰 몸통, 둥근 머리, 양옆 부스터 불꽃
	legs(0.55, 0.7, rgb(150, 90, 200))
	cyl(2.6, 2.1, at(0, 2.0, 0) * UP, WHITE)
	trimRing(1.0, 2.15)
	ball(2.1, Vector3.new(0, 3.35, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 2.4, -1.05), 1.5, 0.95, rgb(255, 120, 230), "angry")
	for _, sx in { -1, 1 } do
		cyl(1.8, 0.75, at(sx * 1.1, 2.0, 0.6) * UP, rgb(120, 125, 140), METAL)
		ball(0.65, Vector3.new(sx * 1.1, 0.85, 0.6), rgb(255, 150, 40), NEON)
	end
end

-- 전설 -----------------------------------------------------------------------------
DESIGNS.Nova = function() -- 별빛 가시 왕관, 가슴의 빛나는 핵
	legs(0.5, 0.6, rgb(220, 200, 150))
	ball(2.3, Vector3.new(0, 1.8, 0), WHITE)
	ball(0.7, Vector3.new(0, 1.85, -1.0), rgb(255, 230, 120), NEON)
	trimRing(1.0, 1.9)
	box(Vector3.new(1.9, 1.4, 1.6), at(0, 3.3, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.3, -0.81), 1.6, 1.0, rgb(255, 240, 150), "happy")
	for i = -2, 2 do
		box(Vector3.new(0.3, 0.9, 0.3), at(0, 3.95, 0) * CFrame.Angles(0, 0, math.rad(i * 28)) * CFrame.new(0, 0.6, 0), rgb(255, 225, 90), NEON)
	end
end
DESIGNS.Atlas = function() -- 넓은 어깨, 머리 위로 든 지구
	legs(0.65, 0.7, rgb(70, 80, 100))
	box(Vector3.new(2.4, 1.9, 1.7), at(0, 1.65, 0), ctx.main, METAL, "Main")
	trim(Vector3.new(2.45, 0.12, 1.75), at(0, 0.75, 0))
	for _, sx in { -1, 1 } do
		ball(1.1, Vector3.new(sx * 1.35, 2.45, 0), rgb(180, 190, 210), METAL)
		cyl(1.6, 0.35, at(sx * 1.1, 3.4, 0.2) * CFrame.Angles(0, 0, math.rad(sx * -20)) * UP, JOINT, METAL)
	end
	box(Vector3.new(1.6, 1.2, 1.4), at(0, 3.2, 0), rgb(180, 190, 210), METAL)
	face(at(0, 3.2, -0.71), 1.35, 0.85, rgb(120, 230, 255), "round")
	ball(2.2, Vector3.new(0, 4.9, 0.3), rgb(70, 140, 230))
	box(Vector3.new(0.9, 0.6, 0.3), at(-0.35, 5.1, -0.75), rgb(90, 190, 90))
	box(Vector3.new(0.7, 0.5, 0.3), at(0.45, 4.6, -0.75), rgb(90, 190, 90))
end
DESIGNS.Titan = function() -- 기사 갑옷: 투구 바이저, 뿔, 방패
	legs(0.65, 0.8, rgb(90, 90, 105))
	box(Vector3.new(2.6, 2.0, 1.9), at(0, 1.8, 0), rgb(110, 110, 125), METAL)
	for _, sx in { -1, 1 } do
		box(Vector3.new(1.0, 0.6, 1.6), at(sx * 1.6, 2.65, 0), ctx.main, METAL, "Main")
	end
	trim(Vector3.new(2.65, 0.14, 1.95), at(0, 0.85, 0))
	box(Vector3.new(0.25, 1.7, 1.4), at(-1.75, 1.6, -0.3), ctx.main, METAL)
	box(Vector3.new(1.9, 1.6, 1.7), at(0, 3.65, 0), rgb(150, 150, 165), METAL)
	face(at(0, 3.55, -0.86), 1.6, 0.9, rgb(255, 80, 80), "visor")
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.3, 1.0, 0.3), at(sx * 0.9, 4.6, 0) * CFrame.Angles(0, 0, math.rad(-sx * 25)), ctx.main, METAL)
	end
end
DESIGNS.Orion = function() -- 우주 헬멧 유리, 별 세 개 허리띠, 망토
	legs(0.5, 0.7, rgb(30, 40, 90))
	box(Vector3.new(2.0, 1.8, 1.5), at(0, 1.6, 0), rgb(30, 40, 90), METAL)
	for i = -1, 1 do
		ball(0.3, Vector3.new(i * 0.45, 1.25 + i * 0.12, -0.78), rgb(200, 230, 255), NEON)
	end
	trim(Vector3.new(2.05, 0.12, 1.55), at(0, 0.8, 0))
	box(Vector3.new(2.0, 2.4, 0.1), at(0, 1.9, 0.85), ctx.main, Enum.Material.Fabric, "Main")
	box(Vector3.new(1.5, 1.2, 1.4), at(0, 3.25, 0), WHITE)
	face(at(0, 3.25, -0.71), 1.3, 0.85, rgb(120, 230, 255), "round")
	local dome = ball(2.4, Vector3.new(0, 3.3, 0), rgb(200, 230, 255), GLASS)
	dome.Transparency = 0.6
end

-- 신화 -----------------------------------------------------------------------------
DESIGNS.Omega = function() -- 검은 큰 몸, 가슴 코어, 어깨 장갑, 빛나는 후광
	legs(0.75, 0.9, rgb(40, 40, 50))
	box(Vector3.new(2.8, 2.2, 1.8), at(0, 2.1, 0), rgb(40, 42, 54), METAL)
	ball(0.9, Vector3.new(0, 2.2, -0.82), ctx.main, NEON, "Main")
	for _, sx in { -1, 1 } do
		ball(1.3, Vector3.new(sx * 1.6, 3.0, 0), rgb(30, 30, 38), METAL)
		trim(Vector3.new(0.08, 2.0, 1.6), at(sx * 1.42, 2.1, 0))
	end
	box(Vector3.new(2.3, 1.6, 1.8), at(0, 3.95, 0), rgb(50, 52, 66), METAL)
	face(at(0, 3.95, -0.91), 1.95, 1.15, ctx.main, "angry")
	ring(at(0, 5.2, 0), 1.0, 14, 0.25, ctx.trim or ctx.main, NEON)
end
DESIGNS.Zenith = function() -- 하얀 천사: 날개, 후광, 등 뒤 햇살 원반
	legs(0.6, 0.8, rgb(230, 200, 120))
	box(Vector3.new(2.0, 2.0, 1.6), at(0, 1.8, 0), WHITE)
	trim(Vector3.new(2.05, 0.14, 1.65), at(0, 0.9, 0))
	for _, sx in { -1, 1 } do
		box(Vector3.new(0.15, 2.2, 1.4), at(sx * 1.45, 2.7, 0.6) * CFrame.Angles(0, math.rad(sx * 25), math.rad(sx * -25)), WHITE)
		box(Vector3.new(0.17, 2.2, 0.15), at(sx * 1.45, 2.7, 0.0) * CFrame.Angles(0, math.rad(sx * 25), math.rad(sx * -25)), rgb(255, 220, 120), NEON)
	end
	local sun = cyl(0.1, 3.0, at(0, 3.6, 0.95) * FWD, rgb(255, 210, 110), NEON)
	sun.Transparency = 0.35
	box(Vector3.new(1.8, 1.5, 1.5), at(0, 3.6, 0), ctx.main, SMOOTH, "Main")
	face(at(0, 3.6, -0.76), 1.55, 1.0, rgb(255, 210, 90), "happy")
	ring(at(0, 4.85, 0), 0.8, 12, 0.22, rgb(255, 220, 100), NEON)
end
DESIGNS.Quasar = function() -- 우주 구슬 몸, 빛나는 핵, 기울어진 궤도 고리 두 개
	legs(0.6, 0.6, rgb(40, 20, 70))
	ball(2.6, Vector3.new(0, 2.1, 0), rgb(25, 12, 45), METAL)
	face(at(0, 2.4, -1.3), 1.5, 0.95, ctx.main, "round")
	ball(0.6, Vector3.new(0, 1.35, -1.05), ctx.main, NEON, "Main")
	ring(at(0, 2.1, 0) * CFrame.Angles(math.rad(25), 0, math.rad(15)), 1.75, 16, 0.22, ctx.trim or ctx.main, NEON)
	ring(at(0, 2.1, 0) * CFrame.Angles(math.rad(-20), 0, math.rad(-30)), 1.95, 16, 0.18, rgb(140, 220, 255), NEON)
	ball(0.3, Vector3.new(0, 3.55, 0), WHITE, NEON)
end

-- 로봇별 기본 주색 (변종이면 변종 색으로 바뀐다)
local MAIN: { [string]: Color3 } = {
	Pippi = rgb(255, 196, 70), Nut = rgb(200, 120, 60), Sponge = rgb(250, 220, 90), Tin = rgb(230, 70, 60),
	Clip = rgb(120, 160, 230), Bucket = rgb(80, 140, 210), Rusty = rgb(150, 90, 60), Scrappy = rgb(110, 130, 100),
	Volt = rgb(250, 210, 60), Coil = rgb(120, 210, 190), Wiper = rgb(60, 70, 90), Magnet = rgb(210, 50, 50),
	Fan = rgb(120, 200, 140), Drill = rgb(240, 140, 40), Hopper = rgb(110, 200, 90),
	Lumi = rgb(230, 230, 240), Spring = rgb(250, 230, 90), Radar = rgb(80, 110, 150), Prism = rgb(170, 220, 255),
	Turbo = rgb(220, 40, 40), Sonar = rgb(240, 200, 60),
	GearKing = rgb(200, 160, 60), Holo = rgb(90, 220, 255), Press = rgb(240, 190, 40), Forge = rgb(110, 60, 40), Rocket = rgb(170, 100, 230),
	Nova = rgb(255, 220, 120), Atlas = rgb(90, 100, 130), Titan = rgb(220, 180, 70), Orion = rgb(200, 40, 60),
	Omega = rgb(255, 90, 160), Zenith = rgb(255, 230, 150), Quasar = rgb(200, 100, 255),
}

-- 예전 모양(상자 두 개)으로 그리기: DESIGNS에 없는 로봇이 생겨도 깨지지 않게
local function fallback()
	legs(0.5, 0.6, STEEL)
	box(Vector3.new(2, 1.6, 1.5), at(0, 1.4, 0), ctx.main, SMOOTH, "Main")
	box(Vector3.new(2.2, 1.4, 1.7), at(0, 2.95, 0), ctx.main, SMOOTH)
	face(at(0, 2.95, -0.86), 1.8, 1.05, WHITE, "round")
end

-- robotKey("id" 또는 "id@변종")의 모형을 만든다. anchored = false면 부품을 Body에 붙인다(들고 가기)
function RobotModel.build(robotKey: string, anchored: boolean): Model
	local baseId = Config.splitKey(robotKey)
	local rarity = Config.rarityOf(robotKey)
	local variant = Config.variantOf(robotKey)
	local s = if rarity then rarity.size else 1
	local model = Instance.new("Model")
	model.Name = "Robot_" .. robotKey
	local main = if variant then variant.color else (MAIN[baseId] or (if rarity then rarity.color else WHITE))
	local trimColor = if rarity and rarity ~= Config.Rarities.Common then rarity.color else nil
	ctx = { model = model, s = s, main = main, trim = trimColor }
	-- 기준 몸통 (보이지 않음): 예전 모형과 같은 크기·위치
	local body = P(BLOCK, Vector3.new(2.2, 2, 1.7), at(0, 1, 0), WHITE, SMOOTH, "Body")
	body.Transparency = 1
	local design = DESIGNS[baseId] or fallback
	design()
	-- 화면(JunkyardHud)이 돌릴 부품의 속도(라디안/초). Body의 세로축을 중심으로 돈다
	local spinSpeed = if baseId == "Fan" then 9 elseif baseId == "Radar" then 1.5 else 1.2
	for _, object in model:GetChildren() do
		if object.Name == "Spin" then
			object:SetAttribute("SpinSpeed", spinSpeed)
		end
	end
	if variant then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = variant.color
		sparkles.Parent = body
		-- 변종 표시: 머리 위에 빛나는 보석 (화면에서 제자리로 천천히 돈다)
		local top = 0
		for _, object in model:GetChildren() do
			if object:IsA("BasePart") and object ~= body then
				top = math.max(top, object.Position.Y + object.Size.Y / 2)
			end
		end
		local gem = box(Vector3.new(0.8, 0.8, 0.8), at(0, top / s + 0.95, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), variant.color, NEON, "Spin")
		gem:SetAttribute("SpinSpeed", 2)
	end
	model.PrimaryPart = body
	for _, object in model:GetChildren() do
		if object:IsA("BasePart") then
			object.Anchored = anchored
			if not anchored then
				object.Massless = true
				if object ~= body then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = object
					weld.Parent = object
				end
			end
		end
	end
	ctx = nil :: any
	return model
end

return RobotModel
