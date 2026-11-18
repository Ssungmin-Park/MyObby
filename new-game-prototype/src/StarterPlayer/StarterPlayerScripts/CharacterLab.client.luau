--!strict
-- 문방구 캐릭터의 외형 시험. 체력·발사 여부는 서버가 정하고 이 화면에서 움직여 그린다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

if not RunService:IsStudio() or workspace:GetAttribute("PrototypeProject") ~= "StationeryCharacterLab" then
	return
end
local player = Players.LocalPlayer
local lab = workspace:WaitForChild("CharacterLab")
local assets = ReplicatedStorage:WaitForChild("CharacterLabAssets")
local action = ReplicatedStorage:WaitForChild("CharacterLabRemotes"):WaitForChild("Action") :: RemoteEvent
local folder = Instance.new("Folder")
folder.Name = "CharacterLabLocal"
folder.Parent = workspace

local displays = lab:WaitForChild("Displays")
for _, object in displays:GetDescendants() do
	if object:IsA("BasePart") then
		object.LocalTransparencyModifier = 1
	end
end

type Piece = { part: BasePart, pose: CFrame, upper: boolean, transparency: number, size: Vector3 }
type Actor = { model: Model, kind: string, root: CFrame, scale: number, baseScale: number, height: number, pieces: { Piece }, hinge: CFrame }
local actors: { Actor } = {}

local function actor(kind: string, ground: Vector3)
	local template = assets:WaitForChild(kind) :: Model
	local model = template:Clone()
	model.Name = kind
	model.Parent = folder
	local pieces: { Piece } = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			table.insert(pieces, { part = object, pose = model:GetPivot():ToObjectSpace(object.CFrame), upper = object:GetAttribute("LabUpper") == true, transparency = object.Transparency, size = object.Size })
		end
	end
	local _, size = model:GetBoundingBox()
	local hinge = (template:GetAttribute("HingeLocal") or Vector3.new(0, 0, size.Z * 0.3)) :: Vector3
	table.insert(actors, { model = model, kind = kind, root = CFrame.new(ground), scale = 1, baseScale = model:GetScale(), height = size.Y, pieces = pieces, hinge = CFrame.new(hinge) })
end

local function rebuild()
	for _, entry in actors do
		entry.model:Destroy() -- 이 클라이언트가 만든 시험용 복제본만 정리한다.
	end
	actors = {}
	actor("Jjondeuk", Vector3.new(-9, 1.6, 1))
	actor("Cheolkeok", Vector3.new(9, 1.6, 1))
	if lab:GetAttribute("Crowd") == true then
		for row = 1, 3 do
			for column = 1, 5 do
				actor(if column % 2 == 0 then "Cheolkeok" else "Jjondeuk", Vector3.new((column - 3) * 6, 1, 11 + row * 7))
			end
		end
	end
end
rebuild()
lab:GetAttributeChangedSignal("Crowd"):Connect(rebuild)

local gui = Instance.new("ScreenGui")
gui.Name = "CharacterLabGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(parent: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = parent
end
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Position = UDim2.fromOffset(16, 16)
status.Size = UDim2.fromOffset(390, 88)
status.BackgroundColor3 = Color3.fromRGB(34, 45, 61)
status.BackgroundTransparency = 0.08
status.TextColor3 = Color3.fromRGB(249, 237, 220)
status.Font = Enum.Font.GothamBold
status.TextSize = 18
status.TextWrapped = true
status.Parent = gui
rounded(status)

local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.AnchorPoint = Vector2.new(0.5, 1)
controls.Position = UDim2.new(0.5, 0, 1, -18)
controls.Size = UDim2.fromOffset(750, 54)
controls.BackgroundTransparency = 1
controls.Parent = gui
local controlScale = Instance.new("UIScale")
controlScale.Parent = controls
local buttons: { [string]: TextButton } = {}
for index, spec in {
	{ "Hit", "쫀득 피격 [Q]" },
	{ "Fire", "철컥 발사 [E]" },
	{ "Reset", "처음으로 [R]" },
	{ "Auto", "자동 반복" },
	{ "Crowd", "여러 마리" },
} do
	local button = Instance.new("TextButton")
	button.Name = spec[1]
	button.Position = UDim2.fromOffset((index - 1) * 150, 0)
	button.Size = UDim2.fromOffset(140, 50)
	button.BackgroundColor3 = if index <= 2 then Color3.fromRGB(82, 104, 135) else Color3.fromRGB(58, 72, 94)
	button.TextColor3 = Color3.fromRGB(255, 247, 237)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.Text = spec[2]
	button.Parent = controls
	rounded(button)
	button.Activated:Connect(function()
		action:FireServer(spec[1])
	end)
	buttons[spec[1]] = button
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local kind = ({ [Enum.KeyCode.Q] = "Hit", [Enum.KeyCode.E] = "Fire", [Enum.KeyCode.R] = "Reset" })[input.KeyCode]
	if kind then
		action:FireServer(kind)
	end
end)

local metalSound = Instance.new("Sound")
metalSound.Name = "StaplerClick"
metalSound.SoundId = "rbxassetid://9116541944" -- Roblox 공식 효과음 라이브러리의 금속 부딪힘
metalSound.Volume = 0.25
metalSound.Parent = gui

local function projectile()
	local staple = Instance.new("Model")
	staple.Name = "StapleEffect"
	for index, offset in { Vector3.new(-0.25, -0.12, 0), Vector3.new(0.25, -0.12, 0), Vector3.new(0, 0.1, 0) } do
		local part = Instance.new("Part")
		part.Size = if index == 3 then Vector3.new(0.6, 0.12, 0.12) else Vector3.new(0.12, 0.45, 0.12)
		part.Position = Vector3.new(9, 4, -1) + offset
		part.Color = Color3.fromRGB(190, 200, 210)
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = staple
		TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = part.Position + Vector3.new(0, -1.5, -9), Transparency = 1 }):Play()
	end
	staple.Parent = folder
	Debris:AddItem(staple, 0.6)
end
lab:GetAttributeChangedSignal("ShotId"):Connect(function()
	metalSound:Play()
	projectile()
end)

local camera = workspace.CurrentCamera
local avatarParts: { BasePart } = {}
-- 기본 캐릭터 카메라가 초기화된 뒤에도 시험장 구도를 유지한다.
RunService:BindToRenderStep("CharacterLabCamera", Enum.RenderPriority.Camera.Value + 1, function()
	camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 48
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 11, -30), Vector3.new(0, 4, 1))
	end
	for _, part in avatarParts do
		part.LocalTransparencyModifier = 1
	end
	local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = false -- 고정 카메라 시험장에서 기본 이동 조이스틱을 숨긴다.
	end
end)
local function hideCharacter(character: Model)
	avatarParts = {}
	local function hide(object: Instance)
		if object:IsA("BasePart") then
			object.LocalTransparencyModifier = 1
			table.insert(avatarParts, object)
		end
	end
	for _, object in character:GetDescendants() do
		hide(object)
	end
	character.DescendantAdded:Connect(hide)
end
player.CharacterAdded:Connect(hideCharacter)
if player.Character then
	hideCharacter(player.Character)
end

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local health = lab:GetAttribute("Health") :: number
	local maximum = lab:GetAttribute("MaxHealth") :: number
	local fraction = math.clamp(health / math.max(maximum, 1), 0, 1)
	local shotAge = now - (lab:GetAttribute("LastShotAt") :: number)
	local hitAge = now - (lab:GetAttribute("LastHitAt") :: number)
	local recoil = if shotAge >= 0 and shotAge < 1 then math.sin(math.min(shotAge / 0.17, 1) * math.pi / 2) * math.exp(-shotAge * 5) else 0
	local close = if shotAge >= 0 and shotAge < 0.3 then -math.sin(shotAge / 0.3 * math.pi) * 0.25 else 0
	local shake = if hitAge >= 0 and hitAge < 0.5 then math.sin(hitAge * 60) * math.exp(-hitAge * 10) * 0.2 else 0
	for index, entry in actors do
		local breathe = math.sin(now * 2.5 + index * 0.2) * 0.025
		if entry.kind == "Jjondeuk" then
			local targetScale = 0.48 + fraction * 0.52
			entry.scale += (targetScale - entry.scale) * math.min(1, dt * 10)
			if math.abs(entry.model:GetScale() - entry.baseScale * entry.scale) > 0.0005 then
				entry.model:ScaleTo(entry.baseScale * entry.scale)
			end
			entry.model:PivotTo(entry.root * CFrame.new(shake, entry.height * entry.scale * 0.5 + math.abs(breathe), 0) * CFrame.Angles(0, 0, breathe))
			for _, piece in entry.pieces do
				piece.part.Transparency = if health <= 0 then 0.75 else piece.transparency
			end
		else
			local root = entry.root * CFrame.new(0, entry.height * 0.5, recoil * 0.85) * CFrame.Angles(-recoil * 0.22, 0, breathe)
			for _, piece in entry.pieces do
				local pose = piece.pose
				if piece.part.Name == "EyeWhite" then
					piece.part.Size = piece.size * Vector3.new(1 + recoil * 0.3, 1 + recoil * 0.3, 1)
				elseif piece.part.Name == "EyePupil" then
					pose *= CFrame.new(0, recoil * 0.18, 0)
				end
				if piece.upper then
					pose = entry.hinge * CFrame.Angles(close + recoil * 0.12, 0, 0) * entry.hinge:Inverse() * pose
				end
				piece.part.CFrame = root * pose
			end
		end
	end
	status.Text = ("쫀득 체력 %d / %d · 크기 %d%%\n철컥 발사 %d회 · 시험 캐릭터 %d마리"):format(health, maximum, math.round((0.48 + fraction * 0.52) * 100), lab:GetAttribute("ShotCount") :: number, #actors)
	buttons.Auto.Text = if lab:GetAttribute("Auto") == true then "자동 반복 끄기" else "자동 반복"
	buttons.Crowd.Text = if lab:GetAttribute("Crowd") == true then "두 마리만" else "여러 마리"
	if camera then
		controlScale.Scale = math.min(1.1, (camera.ViewportSize.X - 24) / 750)
		if camera.ViewportSize.Y < 500 then
			status.AnchorPoint = Vector2.new(0.5, 0)
			status.Position = UDim2.new(0.5, 0, 0, 6)
			status.Size = UDim2.fromOffset(math.min(360, camera.ViewportSize.X - 24), 48)
			status.TextSize = 14
		else
			status.AnchorPoint = Vector2.zero
			status.Position = UDim2.fromOffset(16, 16)
			status.Size = UDim2.fromOffset(390, 88)
			status.TextSize = 18
		end
	end
end)
