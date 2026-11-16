--!strict
-- EscapeMessage: 서버가 Escaped 이벤트를 보내면 화면 가운데에 "탈출 성공!"을 4초 동안 띄운다. (표시만 담당)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local escaped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Escaped") :: RemoteEvent
local player = Players.LocalPlayer

escaped.OnClientEvent:Connect(function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EscapeMessage"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.6, 0.15)
	label.BackgroundTransparency = 0.3
	label.TextScaled = true
	label.Text = "탈출 성공!"
	label.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	task.delay(4, function()
		gui:Destroy()
	end)
end)
