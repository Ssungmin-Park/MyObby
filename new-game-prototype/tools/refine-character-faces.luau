--!strict
-- 생성 메시의 작은 표정과 부위 분리 오류를 시험용 복제본에서 보완한다.
assert(game.PlaceId ~= 77293997616106 and workspace:GetAttribute("PrototypeProject") == "StationeryCharacterLab")
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("RefineStationeryCharacters", "철컥 표정과 팔다리 다듬기")
assert(recording or history:IsRecordingInProgress())

local assets = game.ReplicatedStorage:WaitForChild("CharacterLabAssets")
local displays = workspace.CharacterLab:WaitForChild("Displays")
for _, container in { assets, displays } do
	local model = container:FindFirstChild("Cheolkeok") :: Model
	local pivot = model:GetPivot()
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") and table.find({ "MetalJaw_geom", "LeftArm_geom", "RightArm_geom", "LeftFoot_geom", "RightFoot_geom" }, object.Name) then
			object.Transparency = 1
			object.CastShadow = false
		end
	end
	local function piece(name: string, size: Vector3, position: Vector3, color: Color3, ball: boolean, upper: boolean, roll: number?): Part
		local existing = model:FindFirstChild(name)
		local part = if existing then existing :: Part else Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = pivot * CFrame.new(position) * CFrame.Angles(0, 0, roll or 0)
		part.Shape = Enum.PartType.Block
		if ball and not part:FindFirstChildOfClass("SpecialMesh") then
			local sphere = Instance.new("SpecialMesh")
			sphere.MeshType = Enum.MeshType.Sphere
			sphere.Parent = part
		end
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part:SetAttribute("LabUpper", upper)
		part.Parent = model
		return part
	end
	local dark = Color3.fromRGB(51, 34, 31)
	local red = Color3.fromRGB(235, 79, 78)
	piece("EyeWhite", Vector3.new(1.02, 1.14, 0.32), Vector3.new(-0.46, 1.35, -2.65), Color3.fromRGB(255, 250, 240), true, true)
	piece("EyePupil", Vector3.new(0.43, 0.52, 0.2), Vector3.new(-0.3, 1.28, -2.84), dark, true, true)
	piece("EyeShine", Vector3.new(0.13, 0.16, 0.07), Vector3.new(-0.36, 1.4, -2.95), Color3.new(1, 1, 1), true, true)
	piece("LeftBrow", Vector3.new(0.85, 0.13, 0.14), Vector3.new(-0.46, 2.13, -2.6), dark, false, true, math.rad(-15))
	piece("WinkUpper", Vector3.new(0.58, 0.12, 0.15), Vector3.new(0.53, 1.42, -2.72), dark, false, true, math.rad(28))
	piece("WinkLower", Vector3.new(0.58, 0.12, 0.15), Vector3.new(0.53, 1.18, -2.72), dark, false, true, math.rad(-28))
	piece("RightBrow", Vector3.new(0.62, 0.13, 0.14), Vector3.new(0.5, 1.99, -2.6), dark, false, true, math.rad(25))
	local plate = piece("CleanMetalJaw", Vector3.new(2, 0.3, 3.75), Vector3.new(0, 0.18, -0.12), Color3.fromRGB(191, 202, 214), false, false)
	plate.Material = Enum.Material.Metal
	for _, side in { -1, 1 } do
		piece("Hand" .. tostring(side), Vector3.new(0.7, 0.8, 0.7), Vector3.new(side * 1.38, -0.5, -1.05), red, true, false)
		piece("Leg" .. tostring(side), Vector3.new(0.4, 0.8, 0.4), Vector3.new(side * 0.65, -1.15, -0.1), Color3.fromRGB(68, 75, 89), true, false)
		piece("Foot" .. tostring(side), Vector3.new(1.1, 0.85, 1.55), Vector3.new(side * 0.65, -1.94, -0.1), Color3.fromRGB(68, 75, 89), true, false)
	end
	model:SetAttribute("HingeLocal", Vector3.new(0, 0.1, 1.9))
end
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	for _, item in spawn:GetDescendants() do
		if item:IsA("Decal") or item:IsA("Texture") then
			item.Transparency = 1
		end
	end
end
if recording then
	history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "철컥 표정과 팔다리 보완 완료"
