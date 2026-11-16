--!strict
-- JunkyardEvents: 로봇 고물상 서버 이벤트.
--   희귀 로봇 열차: TrainEvery초마다 TrainDuration초 동안 벨트에 희귀 이상 로봇만 자주 나온다.
--   모두가 벨트로 몰리는 순간이라 기지가 비어 도둑질 기회도 생긴다.
-- workspace 속성 NextTrainAt / TrainUntil(서버 시간)을 클라이언트(JunkyardHud)가 읽어 남은 시간을 보여 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local Belt = require(script.Parent:WaitForChild("JunkyardBelt"))
local notifyRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("JunkyardNotify") :: RemoteEvent

workspace:SetAttribute("TrainUntil", 0)
while true do
	local nextAt = workspace:GetServerTimeNow() + Config.TrainEvery
	workspace:SetAttribute("NextTrainAt", nextAt)
	-- 테스트용: 서버에서 workspace 속성 DebugTrainNow를 true로 바꾸면 바로 출발한다 (클라이언트는 못 바꿈)
	while workspace:GetServerTimeNow() < nextAt and workspace:GetAttribute("DebugTrainNow") ~= true do
		task.wait(1)
	end
	workspace:SetAttribute("DebugTrainNow", nil)
	if #Players:GetPlayers() > 0 then
		Belt.startTrain(Config.TrainDuration)
		workspace:SetAttribute("TrainUntil", workspace:GetServerTimeNow() + Config.TrainDuration)
		notifyRemote:FireAllClients("Global", ("🚂 희귀 로봇 열차 도착! %d초 동안 희귀 이상 로봇만 나와요!"):format(Config.TrainDuration))
		task.wait(Config.TrainDuration)
		notifyRemote:FireAllClients("Info", "🚂 열차가 떠났어요. 다음 열차를 기다리세요.")
	end
end
