--!strict
-- 문방구 캐릭터의 외형 시험. 체력·발사 여부는 서버가 정하고 이 화면에서 움직여 그린다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

if not RunService:IsStudio() or workspace:GetAttribute("PrototypeProject") ~= "StationeryCharacterLab" then
	return
end
local player = Players.LocalPlayer
-- 시험 버튼을 가리는 기본 참가자 목록은 이 시험 화면에서만 숨긴다.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
local lab = workspace:WaitForChild("CharacterLab")
local assets = ReplicatedStorage:WaitForChild("CharacterLabAssets")
local action = ReplicatedStorage:WaitForChild("CharacterLabRemotes"):WaitForChild("Action") :: RemoteEvent
local shotRemote = ReplicatedStorage.CharacterLabRemotes:WaitForChild("Shot") :: RemoteEvent
local folder = Instance.new("Folder")
folder.Name = "CharacterLabLocal"
folder.Parent = workspace

local displays = lab:WaitForChild("Displays")
local function hidePreview(object: Instance)
	if object:IsA("BasePart") then
		object.LocalTransparencyModifier = 1
		object.Transparency = 1
		object.CastShadow = false
	end
end
-- 모델 부품이 클라이언트 초기화 뒤에 복제되는 경우에도 미리보기를 숨긴다.
displays.DescendantAdded:Connect(hidePreview)
for _, object in displays:GetDescendants() do
	hidePreview(object)
end

type Piece = { part: BasePart, pose: CFrame, upper: boolean, transparency: number, size: Vector3 }
type Actor = { model: Model, kind: string, root: CFrame, scale: number, baseScale: number, height: number, pieces: { Piece }, hinge: CFrame }
local actors: { Actor } = {}
type Projectile = { model: Model, parts: { BasePart }, origin: Vector3, target: Vector3, firedAt: number, hitAt: number, linked: boolean }
local projectiles: { Projectile } = {}
local turn = 0
local attackerX = 9

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
status.Position = UDim2.fromOffset(16, 64)
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
local linkedButton = Instance.new("TextButton")
linkedButton.Name = "Linked"
linkedButton.AnchorPoint = Vector2.new(1, 0)
linkedButton.Position = UDim2.new(1, -16, 0, 16)
linkedButton.Size = UDim2.fromOffset(140, 44)
linkedButton.BackgroundColor3 = Color3.fromRGB(149, 76, 92)
linkedButton.TextColor3 = Color3.fromRGB(255, 247, 237)
linkedButton.Font = Enum.Font.GothamBold
linkedButton.TextSize = 15
linkedButton.Text = "연결 시험 [T]"
linkedButton.Parent = gui
rounded(linkedButton)
linkedButton.Activated:Connect(function()
	action:FireServer("Linked")
end)
local approachButton = linkedButton:Clone()
approachButton.Name = "Approach"
approachButton.Position = UDim2.new(1, -16, 0, 68)
approachButton.BackgroundColor3 = Color3.fromRGB(62, 116, 110)
approachButton.Text = "접근 시험 [Y]"
approachButton.Parent = gui
approachButton.Activated:Connect(function()
	action:FireServer("Approach")
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local kind = ({ [Enum.KeyCode.Q] = "Hit", [Enum.KeyCode.E] = "Fire", [Enum.KeyCode.R] = "Reset", [Enum.KeyCode.T] = "Linked", [Enum.KeyCode.Y] = "Approach" })[input.KeyCode]
	if kind then
		action:FireServer(kind)
	end
end)

local metalSound = Instance.new("Sound")
metalSound.Name = "StaplerClick"
metalSound.SoundId = "rbxassetid://9116541944" -- Roblox 공식 효과음 라이브러리의 금속 부딪힘
metalSound.Volume = 0.25
metalSound.Parent = gui

local stapleOffsets = { Vector3.new(-0.4, -0.12, 0), Vector3.new(0.4, -0.12, 0), Vector3.new(0, 0.18, 0) }
local function projectile(payload: any)
	local staple = Instance.new("Model")
	staple.Name = "StapleEffect"
	local parts: { BasePart } = {}
	for index, offset in stapleOffsets do
		local part = Instance.new("Part")
		part.Size = if index == 3 then Vector3.new(0.95, 0.14, 0.14) else Vector3.new(0.14, 0.7, 0.14)
		part.Position = payload.origin + offset
		part.Color = Color3.fromRGB(190, 200, 210)
		part.Material = Enum.Material.Metal
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Parent = staple
		table.insert(parts, part)
	end
	staple.Parent = folder
	table.insert(projectiles, { model = staple, parts = parts, origin = payload.origin, target = payload.target, firedAt = payload.firedAt, hitAt = payload.hitAt, linked = payload.linked })
end
local lastVisualShot = 0
shotRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.id) ~= "number" or payload.id <= lastVisualShot then
		return
	end
	lastVisualShot = payload.id
	metalSound:Play()
	projectile(payload)
end)
local function clearProjectiles()
	for _, entry in projectiles do
		entry.model:Destroy()
	end
	table.clear(projectiles)
end
lab:GetAttributeChangedSignal("Cycle"):Connect(clearProjectiles)
lab:GetAttributeChangedSignal("Cycle"):Connect(function()
	attackerX = (lab:GetAttribute("AttackerX") or 9) :: number
end)
lab:GetAttributeChangedSignal("Linked"):Connect(clearProjectiles)

local random = Random.new()
lab:GetAttributeChangedSignal("LastHitAt"):Connect(function()
	if (lab:GetAttribute("LastHitAt") :: number) <= 0 then
		return
	end
	local eraser = actors[1]
	local origin = Vector3.new(-9, 1.6 + eraser.height * eraser.scale * 0.65, 1)
	for _ = 1, 6 do
		local crumb = Instance.new("Part")
		crumb.Name = "EraserCrumb"
		local size = random:NextNumber(0.12, 0.25)
		crumb.Size = Vector3.new(size, size * 0.65, size)
		crumb.CFrame = CFrame.new(origin) * CFrame.Angles(random:NextNumber(), random:NextNumber(), 0)
		crumb.Color = Color3.fromRGB(245, 139, 189)
		crumb.Material = Enum.Material.SmoothPlastic
		crumb.Anchored = true
		crumb.CanCollide = false
		crumb.CanTouch = false
		crumb.CanQuery = false
		crumb.CastShadow = false
		crumb.Parent = folder
		TweenService:Create(crumb, TweenInfo.new(0.6), { Position = Vector3.new(-9 + random:NextNumber(-1.5, 1.5), 1.65, 1 + random:NextNumber(-1.5, 1.5)), Transparency = 1 }):Play()
		Debris:AddItem(crumb, 0.7)
	end
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
	turn += ((if lab:GetAttribute("Linked") == true then 1 else 0) - turn) * math.min(1, dt * 8)
	local approaching = lab:GetAttribute("Approach") == true
	local range = (lab:GetAttribute("AttackRange") or 12) :: number
	attackerX += (((lab:GetAttribute("AttackerX") or 9) :: number) - attackerX) * math.min(1, dt * 14)
	local walking = approaching and health > 0 and attackerX + 9 > range + 0.03
	for index, entry in actors do
		local breathe = math.sin(now * 2.5 + index * 0.2) * 0.025
		local facing = if entry.kind == "Jjondeuk" then -math.pi / 2 else math.pi / 2
		local ground = if index == 2 then CFrame.new(attackerX, 1.6, 1) else entry.root
		local base = ground * CFrame.Angles(0, facing * turn, 0)
		if entry.kind == "Jjondeuk" then
			local targetScale = 0.48 + fraction * 0.52
			entry.scale += (targetScale - entry.scale) * math.min(1, dt * 10)
			if math.abs(entry.model:GetScale() - entry.baseScale * entry.scale) > 0.0005 then
				entry.model:ScaleTo(entry.baseScale * entry.scale)
			end
			entry.model:PivotTo(base * CFrame.new(shake, entry.height * entry.scale * 0.5 + math.abs(breathe), 0) * CFrame.Angles(0, 0, breathe))
			for _, piece in entry.pieces do
				piece.part.Transparency = if health <= 0 then 0.75 else piece.transparency
			end
		else
			local step = if index == 2 and walking then math.sin(now * 13) else 0
			local root = base * CFrame.new(0, entry.height * 0.5 + math.abs(step) * 0.09, recoil * 0.85) * CFrame.Angles(-recoil * 0.22, 0, breathe + step * 0.035)
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
	for index = #projectiles, 1, -1 do
		local entry = projectiles[index]
		local alpha = math.clamp((now - entry.firedAt) / (entry.hitAt - entry.firedAt), 0, 1)
		if alpha >= 1 then
			entry.model:Destroy()
			table.remove(projectiles, index)
		else
			local position = entry.origin:Lerp(entry.target, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * (if entry.linked then 1.5 else 0.3), 0)
			local pose = CFrame.lookAt(position, entry.target)
			for pieceIndex, part in entry.parts do
				part.CFrame = pose * CFrame.new(stapleOffsets[pieceIndex])
			end
		end
	end
	status.Text = ("쫀득 체력 %d / %d · 크기 %d%%\n철컥 발사 %d회 · 시험 캐릭터 %d마리"):format(health, maximum, math.round((0.48 + fraction * 0.52) * 100), lab:GetAttribute("ShotCount") :: number, #actors)
	if approaching then
		local phase = if health <= 0 then "복원 대기" elseif walking then "접근 중" else "사거리 도착 · 사격"
		status.Text = ("쫀득 체력 %d / %d · 철컥 발사 %d회\n%s · 거리 %.1f / 사거리 %.0f"):format(health, maximum, lab:GetAttribute("ShotCount") :: number, phase, attackerX + 9, range)
	end
	buttons.Auto.Text = if lab:GetAttribute("Auto") == true then "자동 반복 끄기" else "자동 반복"
	buttons.Crowd.Text = if lab:GetAttribute("Crowd") == true then "두 마리만" else "여러 마리"
	linkedButton.Text = if lab:GetAttribute("Linked") == true then "연결 시험 중지" else "연결 시험 [T]"
	approachButton.Text = if approaching then "접근 시험 중지" else "접근 시험 [Y]"
	if camera then
		controlScale.Scale = math.min(1.1, (camera.ViewportSize.X - 24) / 750)
		if camera.ViewportSize.Y < 500 then
			status.AnchorPoint = Vector2.new(0.5, 0)
			status.Position = UDim2.new(0.5, 0, 0, 6)
			status.Size = UDim2.fromOffset(math.min(360, camera.ViewportSize.X - 24), 48)
			status.TextSize = 14
		else
			status.AnchorPoint = Vector2.zero
			status.Position = UDim2.fromOffset(16, 64)
			status.Size = UDim2.fromOffset(390, 88)
			status.TextSize = 18
		end
	end
end)
