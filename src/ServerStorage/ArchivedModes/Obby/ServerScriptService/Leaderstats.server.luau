--!strict
-- Leaderstats: 플레이어가 들어오면 리더보드(leaderstats)에 현재 스테이지(Stage)를 만든다.
-- 다른 스크립트(Checkpoints, Respawn, Finish)는 이 Stage 값을 읽고 쓴다.
-- 저장된 진행은 ProgressSave 모듈로 불러와서, 리더보드를 붙이기 전에 Stage에 넣는다.
local Players = game:GetService("Players")

local ProgressSave = require(script.Parent:WaitForChild("ProgressSave"))
ProgressSave.start()

local loading: { [Player]: boolean } = {} -- 불러오는 중인 플레이어 (중복 실행 방지)

local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") or loading[player] then
		return
	end
	loading[player] = true

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats" -- 이 이름이어야 화면 오른쪽 위 리더보드에 표시된다

	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Value = 0 -- 0 = 시작 발판
	stage.Parent = leaderstats

	-- 저장된 진행 불러오기. 값을 먼저 넣고 리더보드를 붙여야
	-- Finish가 "Stage가 11로 바뀜 = 방금 탈출"로 착각하지 않는다.
	local loadedStage = ProgressSave.loadAsync(player.UserId)
	loading[player] = nil
	if player.Parent == nil then
		return -- 불러오는 사이에 나감
	end
	if loadedStage then
		stage.Value = loadedStage
		ProgressSave.track(player, stage, loadedStage)
	else
		warn("[Leaderstats] 진행을 불러오지 못해 이번 접속은 저장하지 않음:", player.Name)
	end

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
