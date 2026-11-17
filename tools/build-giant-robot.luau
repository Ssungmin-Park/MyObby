--!strict
-- 협력 거대 로봇 맵 (2026-11-17, Claude Code)
-- Edit 모드에서 한 번 실행한다. Workspace/Junkyard/GiantRobot 모델을 만든다.
-- 위치: 벨트 끝(X 489) 동쪽 빈 통로, 서쪽(벨트 쪽)을 본다. 기지 7·8 입구 통로(Z 49~65, 135~151)를 피한다.
-- 파트 속성 Stage(1~5): 조립 단계 (다리 → 몸통 → 팔 → 머리 → 눈). 단계가 안 된 파트는 JunkyardGiantRobot이 반투명으로 둔다.
-- 로봇은 부딪히지 않는다(길을 막지 않게). 기부 단말기(Terminal)만 부딪힌다.
local runService = game:GetService("RunService")
assert(game.PlaceId == 77293997616106 and not runService:IsRunning(), "마이오비 편집 모드에서 실행하세요.")
local yard = workspace:WaitForChild("Junkyard")
assert(not yard:FindFirstChild("GiantRobot"), "이미 GiantRobot이 있습니다.")

local model = Instance.new("Model")
model.Name = "GiantRobot"
local count = 0
local X = 527 -- 로봇 중심
local FLOOR = 40.5 -- 고물상 바닥 윗면
local yellow = Color3.fromRGB(214, 160, 52)
local steel = Color3.fromRGB(70, 74, 80)
local dark = Color3.fromRGB(40, 44, 50)

local function part(name: string, stage: number?, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if stage then
		p:SetAttribute("Stage", stage)
		p.Transparency = 0.8
	end
	p.Parent = model
	count += 1
	return p
end

-- 1단계: 다리
for _, z in { 95, 105 } do
	part("Foot", 1, CFrame.new(X - 1, FLOOR + 1, z), Vector3.new(8, 2, 6), steel, Enum.Material.DiamondPlate)
	part("Leg", 1, CFrame.new(X, FLOOR + 2 + 5, z), Vector3.new(4, 10, 4), yellow, Enum.Material.Metal)
end
-- 2단계: 골반·몸통
part("Hip", 2, CFrame.new(X, FLOOR + 13, 100), Vector3.new(6, 2, 14), steel, Enum.Material.Metal)
part("Torso", 2, CFrame.new(X, FLOOR + 18.5, 100), Vector3.new(8, 9, 14), yellow, Enum.Material.Metal)
part("ChestPlate", 2, CFrame.new(X - 4.1, FLOOR + 19, 100), Vector3.new(0.4, 5, 8), dark, Enum.Material.DiamondPlate)
-- 3단계: 어깨·팔·손
for _, side in { -1, 1 } do
	local z = 100 + side * 9
	part("Shoulder", 3, CFrame.new(X, FLOOR + 21.5, z), Vector3.new(5, 4, 4), steel, Enum.Material.Metal)
	part("Arm", 3, CFrame.new(X, FLOOR + 15, z), Vector3.new(3, 10, 3), yellow, Enum.Material.Metal)
	part("Hand", 3, CFrame.new(X - 0.5, FLOOR + 8.5, z), Vector3.new(4, 3, 4), steel, Enum.Material.CorrodedMetal)
end
-- 4단계: 목·머리·안테나
part("Neck", 4, CFrame.new(X, FLOOR + 23.5, 100), Vector3.new(3, 1, 3), steel, Enum.Material.Metal)
local head = part("Head", 4, CFrame.new(X, FLOOR + 27, 100), Vector3.new(7, 6, 8), yellow, Enum.Material.Metal)
part("Antenna", 4, CFrame.new(X, FLOOR + 32, 100), Vector3.new(0.6, 4, 0.6), dark, Enum.Material.Metal)
-- 5단계: 눈 (완성되면 빛난다)
for _, z in { 98, 102 } do
	local eye = part("Eye", 5, CFrame.new(X - 3.6, FLOOR + 28, z), Vector3.new(0.4, 1.2, 2), dark, Enum.Material.Metal)
	eye:SetAttribute("Stage", 5)
end

-- 진행 표시 (머리 위)
local display = Instance.new("BillboardGui")
display.Name = "Display"
display.Size = UDim2.fromOffset(300, 110)
display.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
display.MaxDistance = 220
display.Parent = head
local label = Instance.new("TextLabel")
label.Name = "Label"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(28, 33, 41)
label.BackgroundTransparency = 0.15
label.TextColor3 = Color3.fromRGB(255, 224, 140)
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.Text = "🔧 거대 로봇"
label.Parent = display
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

-- 기부 단말기 (벨트 끝과 로봇 사이)
local terminal = part("Terminal", nil, CFrame.lookAt(Vector3.new(507, FLOOR + 2.5, 100), Vector3.new(500, FLOOR + 2.5, 100)), Vector3.new(3, 5, 2.5), dark, Enum.Material.Metal)
terminal.CanCollide = true
terminal.CanQuery = true
part("TerminalScreen", nil, terminal.CFrame * CFrame.new(0, 1, -1.3), Vector3.new(2.4, 1.6, 0.1), Color3.fromRGB(255, 200, 90), Enum.Material.Neon)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "DonatePrompt"
prompt.ObjectText = "거대 로봇"
prompt.ActionText = "부품 기부"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = terminal

model.Parent = yard
return ("거대 로봇 파트 %d개"):format(count)
