--!strict
-- 서버가 복제한 연구소 상태로 목표, 도감 진행과 탐지기 신호를 표시한다.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local lab = workspace:WaitForChild("RobotLab")
local interactions = lab:WaitForChild("Interactions")

local gui = Instance.new("ScreenGui")
gui.Name = "RobotLabHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(12, 10)
panel.Size = UDim2.new(0.88, 0, 0, 154)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 32)
panel.BackgroundTransparency = 0.09
panel.BorderSizePixel = 0
panel.Parent = gui

local maxSize = Instance.new("UISizeConstraint")
maxSize.MaxSize = Vector2.new(340, 154)
maxSize.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local function makeLabel(y: number, height: number, fontSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(12, y)
	label.Size = UDim2.new(1, -24, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = fontSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = panel
	return label
end

local white = Color3.fromRGB(244, 248, 255)
local muted = Color3.fromRGB(180, 196, 209)
local title = makeLabel(7, 25, 17, white)
title.Font = Enum.Font.GothamBold
title.Text = "꼬마 로봇 연구소"
local catalog = makeLabel(31, 22, 13, muted)
local objective = makeLabel(56, 40, 14, white)
local signal = makeLabel(97, 19, 13, Color3.fromRGB(143, 235, 210))
local feedback = makeLabel(118, 34, 12, muted)

local targets = {
	{ name = "삐삐", hint = "연구실 입구 옆에서 삐삐를 찾으세요." },
	{ name = "볼트", hint = "창고로 걸어가서 볼트의 신호를 찾으세요." },
	{ name = "루미", hint = "온실의 재배대 사이에서 루미를 찾으세요." },
}

local function render()
	local active = player:GetAttribute("RobotLabActive") == true
	gui.Enabled = active
	if not active then
		return
	end
	local repaired = player:GetAttribute("RobotLabRepaired") :: number
	local parts = player:GetAttribute("RobotLabParts") :: number
	local message = player:GetAttribute("RobotLabMessage")
	local stamps = {}
	for i, target in targets do
		stamps[i] = (if i <= repaired then "✓ " else "○ ") .. target.name
	end
	catalog.Text = ("부품 %d    |    도감 %d/3    %s"):format(parts, repaired, table.concat(stamps, "  "))
	feedback.Text = if typeof(message) == "string" then message else ""
	signal.Text = ""

	local target = targets[repaired + 1]
	if not target then
		objective.Text = "도감 완성! 연구실 출구에서 오비로 돌아갈 수 있어요."
		return
	end
	if player:GetAttribute("RobotLabFound") == true then
		objective.Text = target.name .. "를 연구실 수리대로 데려가세요."
		return
	end
	if repaired == 2 and player:GetAttribute("RobotLabBattery") ~= true then
		objective.Text = "상점에서 고출력 배터리(부품 5개)를 사면 루미를 데려올 수 있어요."
		return
	end
	objective.Text = target.hint
	if repaired == 0 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local point = interactions:FindFirstChild("Robot" .. tostring(repaired + 1))
	if root and root:IsA("BasePart") and point and point:IsA("BasePart") then
		local range = if player:GetAttribute("RobotLabRange") == true then 55 else 30
		local distance = (root.Position - point.Position).Magnitude
		signal.Text = if distance <= range then ("탐지기 · 신호까지 %d 스터드"):format(math.round(distance))
			else "탐지기 · 감지 범위 밖"
	end
end

for _, name in { "Active", "Parts", "Repaired", "Found", "Battery", "Range", "Message" } do
	player:GetAttributeChangedSignal("RobotLab" .. name):Connect(render)
end

task.spawn(function()
	while gui.Parent do
		render()
		task.wait(0.3)
	end
end)
