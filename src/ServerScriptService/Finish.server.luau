--!strict
-- Finish: 골인 체크포인트(속성 IsFinish = true)에 도달하면 그 플레이어 화면에 "탈출 성공!"을 띄우라고 알린다.
-- 스테이지 진행 판정 자체는 Checkpoints 스크립트가 하고, 여기서는 Stage 값이 골인 번호가 됐는지만 본다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local escaped = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Escaped") :: RemoteEvent
local checkpointsFolder = workspace:WaitForChild("Checkpoints")

local function getFinishStage(): number?
	for _, cp in checkpointsFolder:GetChildren() do
		if cp:GetAttribute("IsFinish") == true then
			return tonumber(cp.Name)
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local stage = leaderstats and leaderstats:WaitForChild("Stage", 10)
	if not stage or not stage:IsA("IntValue") then
		warn("[Finish] leaderstats.Stage를 찾지 못함:", player.Name)
		return
	end
	stage.Changed:Connect(function(value: number)
		local finishStage = getFinishStage()
		if finishStage and value == finishStage then
			print(("[Finish] %s 탈출 성공"):format(player.Name))
			escaped:FireClient(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
