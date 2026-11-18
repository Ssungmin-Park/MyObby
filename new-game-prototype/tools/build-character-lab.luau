--!strict
-- 새 문방구 Studio 전용 시험장. 기존 고물상에는 실행하지 않는다.
assert(game.PlaceId ~= 77293997616106, "고물상에서는 실행할 수 없습니다")
assert(workspace:GetAttribute("PrototypeProject") == "StationeryCharacterLab", "문방구 시험장 식별이 필요합니다")
assert(not game:GetService("RunService"):IsRunning(), "편집 모드에서 실행하세요")

local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("BuildStationeryLab", "문방구 캐릭터 시험장 만들기")
assert(recording or history:IsRecordingInProgress())

local lab = workspace:FindFirstChild("CharacterLab")
if not lab then
	lab = Instance.new("Model")
	lab.Name = "CharacterLab"
	lab.Parent = workspace
	local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.Position = position
		object.Color = color
		object.Material = material
		object.Anchored = true
		object.Parent = lab
		return object
	end
	part("Stage", Vector3.new(44, 1, 30), Vector3.new(0, 0.5, 0), Color3.fromRGB(236, 224, 204), Enum.Material.SmoothPlastic)
	for _, spec in { { "JjondeukStand", -9, Color3.fromRGB(198, 220, 235) }, { "CheolkeokStand", 9, Color3.fromRGB(242, 197, 181) } } do
		local stand = part(spec[1] :: string, Vector3.new(12, 0.6, 10), Vector3.new(spec[2] :: number, 1.3, 1), spec[3] :: Color3, Enum.Material.SmoothPlastic)
		stand.CanTouch = false
	end
	local panel = part("Title", Vector3.new(36, 3, 0.3), Vector3.new(0, 10, 11), Color3.fromRGB(40, 54, 70), Enum.Material.SmoothPlastic)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 35
	surface.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = "문방구 캐릭터 시험장"
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(249, 239, 216)
	title.TextScaled = true
	title.Parent = surface
	local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		spawn.Position = Vector3.new(0, 1.6, -11)
		spawn.Transparency = 1
		spawn.Neutral = true
	end
	lab:SetAttribute("Health", 100)
	lab:SetAttribute("MaxHealth", 100)
	lab:SetAttribute("HitDamage", 20)
	lab:SetAttribute("ShotId", 0)
	lab:SetAttribute("ShotCount", 0)
	lab:SetAttribute("LastShotAt", 0)
	lab:SetAttribute("LastHitAt", 0)
	lab:SetAttribute("Cycle", 0)
	lab:SetAttribute("Auto", false)
	lab:SetAttribute("Crowd", false)
end

local replicated = game:GetService("ReplicatedStorage")
local assets = replicated:FindFirstChild("CharacterLabAssets")
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "CharacterLabAssets"
	assets.Parent = replicated
end
local remotes = replicated:FindFirstChild("CharacterLabRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "CharacterLabRemotes"
	remotes.Parent = replicated
end
if not remotes:FindFirstChild("Action") then
	local action = Instance.new("RemoteEvent")
	action.Name = "Action"
	action.Parent = remotes
end
if not remotes:FindFirstChild("Shot") then
	local shot = Instance.new("RemoteEvent")
	shot.Name = "Shot"
	shot.Parent = remotes
end

local lighting = game:GetService("Lighting")
lighting.ClockTime = 14
lighting.Brightness = 2.3
lighting.Ambient = Color3.fromRGB(138, 138, 147)
lighting.OutdoorAmbient = Color3.fromRGB(170, 170, 181)
lighting.ExposureCompensation = 0.15
local camera = workspace.CurrentCamera
if camera then
	camera.FieldOfView = 48
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 11, -30), Vector3.new(0, 4, 1))
end
if recording then
	history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return "문방구 시험장 구성 완료"
