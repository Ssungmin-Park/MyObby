--!strict
-- 로봇 고물상 서버 대회의 일정, 참가자, 점수와 보상 순위를 관리한다.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local rules = Config.Contest

type Entry = {
	player: Player,
	income: number,
	rawScore: number,
	units: number,
	order: number,
}
type Callbacks = {
	getPlayers: () -> { Player },
	incomeOf: (Player) -> number,
	grant: (Player, number, number) -> (),
	setTitle: (Player, string?) -> (),
	notifyAll: (string) -> (),
}
type Round = {
	kind: string,
	endsAt: number,
	entries: { [Player]: Entry },
	sequence: number,
	dirty: boolean,
}

local Contest = {}
local active: Round? = nil
local winners: { [Player]: boolean } = {}

local function standings(round: Round): { Entry }
	local ranked: { Entry } = {}
	for _, entry in round.entries do
		if entry.units > 0 then
			table.insert(ranked, entry)
		end
	end
	table.sort(ranked, function(a, b)
		if a.units == b.units then
			return a.order < b.order
		end
		return a.units > b.units
	end)
	return ranked
end

local function publish(round: Round)
	local top = {}
	for rank, entry in standings(round) do
		entry.player:SetAttribute("ContestRank", rank)
		if rank <= 3 then
			table.insert(top, { name = entry.player.DisplayName, score = entry.units / 100 })
		end
	end
	workspace:SetAttribute("ContestTop", HttpService:JSONEncode(top))
	round.dirty = false
end

function Contest.record(player: Player, kind: string, amount: number)
	local round = active
	if not round or round.kind ~= kind or amount <= 0 or workspace:GetServerTimeNow() >= round.endsAt then
		return
	end
	local entry = round.entries[player]
	if not entry then
		return
	end
	-- 수입왕: 대회가 시작한 뒤 새로 늘어난 초당 수입만 센다 (시작할 때 수입 대비라 부자가 아니어도 이길 수 있다)
	entry.rawScore += if kind == "Income" then math.max(0, amount - entry.income) / math.max(entry.income, 1) else amount
	-- 점수판에 표시하는 소수 둘째 자리까지 비교한다.
	local units = math.round(entry.rawScore * 100)
	if units ~= entry.units then
		round.sequence += 1
		entry.units = units
		entry.order = round.sequence
		round.dirty = true
		player:SetAttribute("ContestScore", units / 100)
	end
end

local function beginRound(callbacks: Callbacks, kind: string, participants: { Player }, duration: number)
	local round: Round = {
		kind = kind,
		endsAt = workspace:GetServerTimeNow() + duration,
		entries = {},
		sequence = 0,
		dirty = true,
	}
	for _, player in participants do
		round.entries[player] = { player = player, income = callbacks.incomeOf(player), rawScore = 0, units = 0, order = 0 }
		player:SetAttribute("ContestScore", 0)
		player:SetAttribute("ContestRank", 0)
	end
	active = round
	workspace:SetAttribute("ContestEndsAt", round.endsAt)
	workspace:SetAttribute("ContestTop", "[]")
	workspace:SetAttribute("ContestType", kind)
	callbacks.notifyAll(("%s 대회가 시작됐어요!"):format(rules.Types[kind].name))
end

local function finishRound(callbacks: Callbacks, round: Round)
	active = nil
	for player in winners do
		callbacks.setTitle(player, nil)
	end
	table.clear(winners)

	local results = {}
	for rank, entry in standings(round) do
		local player = entry.player
		local tier = rules.Rewards[rank]
		local money = if tier then math.max(entry.income * tier.seconds, tier.minimum)
			else entry.income * rules.ParticipationSeconds
		callbacks.grant(player, rank, math.floor(money))
		if rank <= 3 then
			table.insert(results, ("%d위 %s · %g점"):format(rank, player.DisplayName, entry.units / 100))
		end
		if rank == 1 then
			winners[player] = true
			callbacks.setTitle(player, "👑 " .. rules.Types[round.kind].name)
		end
	end
	for player in round.entries do
		player:SetAttribute("ContestRank", nil)
		player:SetAttribute("ContestScore", nil)
	end
	workspace:SetAttribute("ContestType", "")
	workspace:SetAttribute("ContestEndsAt", 0)
	workspace:SetAttribute("ContestTop", "[]")
	local name = rules.Types[round.kind].name
	callbacks.notifyAll(if #results > 0 then name .. " 결과  " .. table.concat(results, " / ") else name .. " 대회가 득점 없이 끝났어요.")
end

function Contest.start(callbacks: Callbacks)
	local nextAt = workspace:GetServerTimeNow() + rules.Interval
	local nextIndex = 1
	local warned = false
	workspace:SetAttribute("ContestType", "")
	workspace:SetAttribute("ContestEndsAt", 0)
	workspace:SetAttribute("ContestTop", "[]")
	workspace:SetAttribute("NextContestAt", nextAt)
	Players.PlayerRemoving:Connect(function(player)
		winners[player] = nil
		local round = active
		if round and round.entries[player] then
			round.entries[player] = nil
			round.dirty = true
		end
	end)
	task.spawn(function()
		local studio = game:GetService("RunService"):IsStudio()
		while true do
			local now = workspace:GetServerTimeNow()
			local debugKind = if studio then workspace:GetAttribute("DebugContestNow") else nil
			local debugDuration = if studio then workspace:GetAttribute("DebugContestDuration") else nil
			if debugKind ~= nil then
				workspace:SetAttribute("DebugContestNow", nil)
				workspace:SetAttribute("DebugContestDuration", nil)
			end
			local round = active
			if round then
				if now >= round.endsAt then
					finishRound(callbacks, round)
				elseif round.dirty then
					publish(round)
				end
			else
				local kind = rules.Order[nextIndex]
				if typeof(debugKind) == "string" and rules.Types[debugKind] then
					local participants = callbacks.getPlayers()
					if #participants > 0 then
						local duration = if typeof(debugDuration) == "number" and debugDuration >= 1
							and debugDuration <= rules.Duration then debugDuration else rules.Duration
						beginRound(callbacks, debugKind, participants, duration)
					end
				elseif now >= nextAt then
					local participants = callbacks.getPlayers()
					if #participants >= rules.MinPlayers then
						beginRound(callbacks, kind, participants, rules.Duration)
						nextIndex = nextIndex % #rules.Order + 1
					else
						callbacks.notifyAll("대회를 시작하려면 다른 플레이어가 한 명 더 필요해요.")
					end
					nextAt += rules.Interval
					workspace:SetAttribute("NextContestAt", nextAt)
					warned = false
				elseif not warned and now >= nextAt - rules.Warning then
					callbacks.notifyAll(("1분 뒤 %s 대회가 시작돼요!"):format(rules.Types[kind].name))
					warned = true
				end
			end
			task.wait(1)
		end
	end)
end

return Contest
