--!strict
-- 생성된 원본은 ServerStorage에 보관하고 동작 시험용 복제본을 준비한다.
assert(game.PlaceId ~= 77293997616106 and workspace:GetAttribute("PrototypeProject") == "StationeryCharacterLab")
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("PrepareStationeryCharacters", "캐릭터 모델 방향과 부위 준비")
assert(recording or history:IsRecordingInProgress())

local storage = game:GetService("ServerStorage")
local backup = storage:FindFirstChild("CharacterLabSources")
if not backup then
	backup = Instance.new("Folder")
	backup.Name = "CharacterLabSources"
	backup.Parent = storage
end
local assets = game:GetService("ReplicatedStorage"):WaitForChild("CharacterLabAssets")
local lab = workspace:WaitForChild("CharacterLab")
local displays = lab:FindFirstChild("Displays")
if not displays then
	displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = lab
end

for _, spec in {
	{ name = "Jjondeuk", tag = "Assistant-af3eeb42-2e3e-493f-a956-5cfaa9499797", asset = 124308299115203, height = 5.8, x = -9 },
	{ name = "Cheolkeok", tag = "Assistant-b37c4fac-0a82-4ad6-a4af-dbdbaa056fba", asset = 139594764218049, height = 4.8, x = 9 },
} do
	if not assets:FindFirstChild(spec.name) then
		local tagged = game:GetService("CollectionService"):GetTagged(spec.tag)
		local source = assert(tagged[1], spec.name .. " 생성 원본이 필요합니다")
		assert(source:IsA("Model"))
		for _, object in source:GetDescendants() do
			assert(not object:IsA("LuaSourceContainer"), "원본에 스크립트가 포함돼 있습니다")
		end
		source.Parent = backup
		source.Name = spec.name .. "Source"
		local model = source:Clone()
		model.Name = spec.name
		model.PrimaryPart = nil
		local hiddenRoot = model:FindFirstChild("RootPart", true)
		if hiddenRoot and hiddenRoot:IsA("BasePart") then
			hiddenRoot.Transparency = 1
			hiddenRoot.Size = Vector3.new(0.05, 0.05, 0.05)
		end
		for _, object in model:GetDescendants() do
			if object:IsA("BasePart") then
				object.Anchored = true
				object.CanCollide = false
				object.CanTouch = false
				object.CanQuery = false
				object.CastShadow = true
				object:SetAttribute("LabUpper", object.Name == "UpperShell_geom")
			end
		end
		local center, size = model:GetBoundingBox()
		if hiddenRoot and hiddenRoot:IsA("BasePart") then
			hiddenRoot.CFrame = center
		end
		model.WorldPivot = center
		-- 생성 원본은 +Z가 앞이므로 화면·투사체 기준인 -Z로 맞춘다.
		model:PivotTo(CFrame.Angles(0, math.pi, 0))
		model:ScaleTo(model:GetScale() * spec.height / size.Y)
		local _, scaled = model:GetBoundingBox()
		model:SetAttribute("HingeLocal", Vector3.new(0, -scaled.Y * 0.1, scaled.Z * 0.32))
		model:SetAttribute("GeneratedAssetId", spec.asset)
		model.Parent = assets
	end
	if not displays:FindFirstChild(spec.name) then
		local template = assets:FindFirstChild(spec.name) :: Model
		local display = template:Clone()
		display.Name = spec.name
		local _, size = display:GetBoundingBox()
		display:PivotTo(CFrame.new(spec.x, 1.6 + size.Y * 0.5, 1))
		display.Parent = displays
	end
end
if recording then
	history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "캐릭터 원본 보관과 시험용 모델 준비 완료"
