--!strict
-- build-cctv.luau: 순위판 위 CCTV 화면 (Studio Edit 모드에서 한 번 실행, 이미 있으면 아무것도 안 함)
-- Workspace/Junkyard/Rankings/CCTV 모델: Screen(화면, 앞면이 +X = 고물상 쪽) · Bezel(테두리) · Pole ×2 · Camera(지붕 위 카메라 장식)
-- 화면 내용(SurfaceGui "CCTVGui")은 서버 모듈 JunkyardCCTV가 실행 중에 만든다.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local rankings = workspace.Junkyard.Rankings
if rankings:FindFirstChild("CCTV") then
	print("[build-cctv] 이미 있음")
	return
end
local recording = ChangeHistoryService:TryBeginRecording("CCTV 화면")
local model = Instance.new("Model")
model.Name = "CCTV"

local FACING = CFrame.Angles(0, math.rad(-90), 0) -- 순위판과 같은 방향 (앞면이 +X)
local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = CFrame.new(position) * FACING
	object.Color = color
	object.Material = material
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = model
	return object
end

part("Bezel", Vector3.new(52, 20, 1), Vector3.new(296.4, 65, 100), Color3.fromRGB(38, 40, 44), Enum.Material.DiamondPlate)
-- 화면은 테두리보다 앞(+X, 고물상 쪽)에 있어야 글씨가 보인다 (2026-11-18 테두리 뒤에 있어 검게 보이던 문제 수정)
part("Screen", Vector3.new(50, 18, 0.4), Vector3.new(297.1, 65, 100), Color3.fromRGB(8, 10, 12), Enum.Material.SmoothPlastic)
for _, z in { 78, 122 } do
	part("Pole", Vector3.new(1.2, 16, 1.2), Vector3.new(296.2, 48.5, z), Color3.fromRGB(70, 66, 60), Enum.Material.CorrodedMetal)
end
-- 지붕 위 감시 카메라 장식
local cameraBody = part("Camera", Vector3.new(2, 1.6, 3.2), Vector3.new(296.2, 76, 100), Color3.fromRGB(225, 225, 220), Enum.Material.SmoothPlastic)
cameraBody.CFrame = CFrame.new(297.2, 76, 100) * CFrame.Angles(0, math.rad(90), math.rad(-15))
local lamp = part("CameraLamp", Vector3.new(0.4, 0.4, 0.4), Vector3.new(298.6, 75.6, 100), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
lamp.Shape = Enum.PartType.Ball

model.Parent = rankings
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[build-cctv] CCTV 화면을 만들었다")
