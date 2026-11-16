--!strict
-- Leaderstats: 플레이어가 들어오면 리더보드(leaderstats)에 현재 스테이지(Stage)를 만든다.
-- 다른 스크립트(Checkpoints, Respawn)는 이 Stage 값을 읽고 쓴다.
local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" -- 이 이름이어야 화면 오른쪽 위 리더보드에 표시된다

	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = 0 -- 0 = 시작 발판
	stage.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
