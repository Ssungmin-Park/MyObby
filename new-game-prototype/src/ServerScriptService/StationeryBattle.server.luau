--!strict
-- Studio 한 서버에 연습 경기 하나만 운영한다. 영구 저장·결제는 하지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or game.PlaceId ~= 123176209315432 or workspace:GetAttribute("PrototypeProject") ~= "StationeryCharacterLab" then return end
local Config = require(ReplicatedStorage.Modules.StationeryBattleConfig)
local Engine = require(script.Parent.StationeryBattleEngine)
local remotes = ReplicatedStorage:WaitForChild("StationeryBattleRemotes")
local action = remotes:WaitForChild("Action") :: RemoteEvent
local state = remotes:WaitForChild("State") :: RemoteEvent
local message = remotes:WaitForChild("Message") :: RemoteEvent
local owner: Player? = nil
local match: any = nil
local serial = 0
local last: { [Player]: number } = {}
local function send()
	if owner and match then state:FireClient(owner, match:snapshot()) end
end
local function close()
	if owner then
		owner:SetAttribute("StationeryPractice", false)
		state:FireClient(owner, { phase = "Closed" })
	end
	owner, match = nil, nil
	workspace:SetAttribute("StationeryPracticeOwner", nil)
end
action.OnServerEvent:Connect(function(player: Player, kind: any, id: any, arg: any, extra: any)
	if typeof(kind) ~= "string" then return end
	if os.clock() - (last[player] or -math.huge) < 0.1 then return end
	last[player] = os.clock()
	if kind == "Start" then
		if owner then message:FireClient(player, "다른 연습이 진행 중이에요"); return end
		local bot = if typeof(arg) == "string" and Config.Bots[arg] then arg else "Balanced"
		serial += 1
		match, owner = Engine.new(serial, bot), player
		player:SetAttribute("StationeryPractice", true)
		workspace:SetAttribute("StationeryPracticeOwner", player.UserId)
		local lab = workspace:FindFirstChild("CharacterLab")
		if lab then
			lab:SetAttribute("Auto", false); lab:SetAttribute("Linked", false); lab:SetAttribute("Approach", false)
		end
		send(); return
	end
	-- 클라이언트가 보낸 경기 번호까지 확인해 이전 판 요청과 다른 참가자를 거절한다.
	if player ~= owner or not match or typeof(id) ~= "number" or id ~= match.id then return end
	if kind == "Leave" then close(); return end
	if kind == "Restart" then
		if match.phase ~= "Result" then return end
		serial += 1; match = Engine.new(serial, match.botKind); send(); return
	end
	local ok, text = false, "지금 할 수 없는 행동이에요"
	if kind == "Buy" then ok, text = match:buy(1, arg, extra)
	elseif kind == "Refund" then ok, text = match:refund(1, arg, extra)
	elseif kind == "Ready" then ok = match:ready(); text = "전투 시작! 무료 병력이 곧 출발해요"
	elseif kind == "Deploy" then ok, text = match:deploy(1, arg, extra)
	elseif kind == "Skill" then ok, text = match:skill(1, arg)
	else return end
	message:FireClient(player, if ok then text else "안내: " .. text)
	send()
end)
Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
	if player == owner then close() end
end)
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += math.min(dt, 0.5)
	if accumulator < Config.Tick then return end
	while accumulator >= Config.Tick do
		accumulator -= Config.Tick
		if match then match:step(Config.Tick) end
	end
	send()
end)
