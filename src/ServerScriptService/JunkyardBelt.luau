--!strict
-- JunkyardBelt: 가운데 컨베이어 벨트에 고장 난 로봇을 흘려보낸다. (서버 전용 모듈, Junkyard가 쓴다)
-- 서버는 "어떤 로봇이 언제 나왔는지"만 기록하고, 움직임은 각 클라이언트가 같은 공식으로 그린다.
--   위치 = 시작점 + 방향 × 속도 × (지금 서버 시간 − 나온 시간)
-- 파트 위치를 매 프레임 복제하지 않아서 렉이 적다. 구매할 때 서버가 같은 공식으로 거리를 확인한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))

local beltPart = workspace:WaitForChild("Junkyard"):WaitForChild("Belt")
local startPos = beltPart:GetAttribute("StartPos") :: Vector3
local endPos = beltPart:GetAttribute("EndPos") :: Vector3
local direction = (endPos - startPos).Unit
local lifetime = (endPos - startPos).Magnitude / Config.BeltSpeed -- 벨트 끝까지 걸리는 시간

export type Item = { id: number, robotId: string, spawnTime: number }

local Belt = {}
local items: { [number]: Item } = {}
local nextId = 0
local remote: RemoteEvent? = nil
local lastSync: { [Player]: number } = {}

-- 지금(서버 시간 now) 이 로봇이 벨트 위 어디에 있는지
function Belt.position(item: Item, now: number): Vector3
	return startPos + direction * Config.BeltSpeed * (now - item.spawnTime)
end

function Belt.get(id: number): Item?
	return items[id]
end

-- 벨트에서 뺀다(구매). 모든 클라이언트에 지우라고 알린다.
function Belt.take(id: number): Item?
	local item = items[id]
	if not item then
		return nil
	end
	items[id] = nil
	if remote then
		remote:FireAllClients("Remove", id)
	end
	return item
end

local function snapshot(): { Item }
	local list = {}
	for _, item in items do
		table.insert(list, item)
	end
	return list
end

-- 희귀 로봇 열차 (JunkyardEvents가 켠다): 이 시각까지 희귀 이상만, 더 자주 나온다
local trainUntil = 0

function Belt.startTrain(duration: number)
	trainUntil = workspace:GetServerTimeNow() + duration
end

function Belt.trainActive(): boolean
	return workspace:GetServerTimeNow() < trainUntil
end

-- 희귀 로봇 비 (Robux 상품, 서버 전체): 이 시각까지 희귀 이상 확률 RainMultiplier배. 여러 번 사면 시간이 이어 붙는다
local rainUntil = 0

function Belt.startRain(duration: number): number
	rainUntil = math.max(rainUntil, workspace:GetServerTimeNow()) + duration
	return rainUntil
end

function Belt.rainActive(): boolean
	return workspace:GetServerTimeNow() < rainUntil
end

local function rollRobot(forceMythic: boolean): string
	local train = Belt.trainActive()
	local rain = Belt.rainActive()
	local function allowed(id: string): boolean
		return not train or Config.TrainRarities[id] == true
	end
	local function weightOf(id: string): number
		return Config.Rarities[id].weight * (if rain and Config.RainRarities[id] then Config.RainMultiplier else 1)
	end
	local total = 0
	for _, id in Config.RarityOrder do
		if allowed(id) then
			total += weightOf(id)
		end
	end
	local roll = math.random() * total
	local rarity = if train then "Rare" else Config.RarityOrder[1]
	for _, id in Config.RarityOrder do
		if forceMythic then
			rarity = "Mythic" -- 신화 보장 시간이 다 됐다
			break
		end
		if allowed(id) then
			roll -= weightOf(id)
			if roll <= 0 then
				rarity = id
				break
			end
		end
	end
	return Config.pickRobot(rarity) -- 같은 등급 안에서는 수입이 높은 로봇일수록 드물다
end

-- 벨트를 돌린다. announce는 희귀 로봇이 나왔을 때 서버 전체 알림을 보내는 함수.
function Belt.start(beltRemote: RemoteEvent, announce: (robotId: string) -> ())
	remote = beltRemote
	-- 클라이언트가 처음 들어오면 현재 벨트 목록을 달라고 요청한다 (2초에 한 번까지)
	beltRemote.OnServerEvent:Connect(function(player: Player, kind: unknown)
		if kind ~= "Sync" then
			return
		end
		local now = os.clock()
		if lastSync[player] and now - lastSync[player] < 2 then
			return
		end
		lastSync[player] = now
		beltRemote:FireClient(player, "Snapshot", snapshot())
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSync[player] = nil
	end)

	-- 신화 보장 시각: 신화가 나올 때마다 뒤로 미룬다. 클라이언트는 이 속성으로 예보를 띄운다
	local mythicDueAt = workspace:GetServerTimeNow() + Config.MythicPitySeconds
	workspace:SetAttribute("MythicDueAt", mythicDueAt)

	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			for id, item in items do
				if now - item.spawnTime > lifetime then
					items[id] = nil
					beltRemote:FireAllClients("Remove", id)
				end
			end
			nextId += 1
			local item = { id = nextId, robotId = rollRobot(now >= mythicDueAt), spawnTime = now }
			items[nextId] = item
			beltRemote:FireAllClients("Add", item)
			local robot = Config.getRobot(item.robotId)
			if robot and robot.rarity == "Mythic" then
				mythicDueAt = now + Config.MythicPitySeconds
				workspace:SetAttribute("MythicDueAt", mythicDueAt)
			end
			if robot and Config.AnnounceRarities[robot.rarity] then
				announce(item.robotId)
			end
			task.wait(if Belt.trainActive() then Config.TrainInterval else Config.BeltInterval)
		end
	end)
end

return Belt
