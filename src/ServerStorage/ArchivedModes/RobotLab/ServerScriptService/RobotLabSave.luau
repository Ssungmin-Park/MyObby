--!strict
-- RobotLabSave: 로봇 작업장 데이터를 DataStore에서 불러오고 저장한다. (서버 전용 모듈, RobotLab이 쓴다)
--
-- 저장 형식 (한 번 정했으니 바꾸지 말 것. 바꾸면 플레이어 진행이 사라진다)
--   DataStore 이름 : "RobotLab_v1"   (오비의 Progress_v1과 별개)
--   키            : "Player_<UserId>"
--   값            : { version = 1, data = Data, lastSeen = os.time(), lock = { job = 서버ID, at = os.time() } 또는 없음 }
--
-- 안전 원칙
--   1. 세션 잠금: 데이터를 쓰는 서버가 lock을 남긴다. 다른 서버의 lock이 살아 있으면 기다리고,
--      2분(LOCK_TIMEOUT) 넘게 갱신되지 않은 lock은 꺼진 서버의 것으로 보고 가져온다.
--   2. 불러오기에 실패하면 이번 접속은 저장하지 않는다. (빈 데이터로 덮어쓰기 방지)
--   3. 저장할 때 lock이 다른 서버로 넘어가 있으면 쓰지 않는다. (그 서버가 최신이다)
--   4. 알 수 없는 형식(표가 아닌 값, 더 새로운 version)은 덮어쓰지 않는다.
--   5. 불러온 값은 하나하나 검사해서 허용 범위로 정리한다.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RobotLabConfig"))

local STORE_NAME = "RobotLab_v1"
local VERSION = 1
local MAX_TRIES = 3 -- 요청 오류 시 시도 횟수
local LOCK_TIMEOUT = 120 -- 이 시간(초) 넘게 갱신되지 않은 lock은 만료
local AUTOSAVE_INTERVAL = 60 -- 자동 저장 간격(초). lock도 이때 갱신된다
local CLOSE_TIMEOUT = 25 -- 서버 종료 시 저장을 기다리는 최대 시간(초)

export type Repair = { robotId: string, finishAt: number } -- finishAt = os.time() 기준
export type Data = {
	parts: number,
	storage: number, -- 도우미 로봇이 모은 부품 (수거함에서 받는다)
	robots: { [string]: number }, -- 로봇 id → 레벨
	repairs: { Repair },
	upgrades: { [string]: number }, -- 업그레이드 id → 레벨 (1 = 기본)
	zones: { [string]: boolean }, -- 열린 구역
	tutorialDone: boolean,
}
export type LoadStatus = "new" | "ok" | "failed" | "locked"
export type SaveStatus = "ok" | "failed" | "lostLock"

local RobotLabSave = {}
RobotLabSave.lockWaitSeconds = 30 -- 다른 서버의 lock을 기다리는 최대 시간 (테스트에서 줄일 수 있음)
RobotLabSave.lockRetryInterval = 5

-- 이 서버를 구분하는 값. Studio에서는 JobId가 비어 있어 임의 값을 만든다.
local serverId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

-- 실제 DataStore. 테스트할 때는 setStoreForTest로 가짜 저장소를 넣는다.
local store: any = nil
local function getStore(): any
	if store == nil then
		store = DataStoreService:GetDataStore(STORE_NAME)
	end
	return store
end

function RobotLabSave.setStoreForTest(fakeStore: any, fakeServerId: string?)
	store = fakeStore
	if fakeServerId then
		serverId = fakeServerId
	end
end

function RobotLabSave.keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

function RobotLabSave.newData(): Data
	local upgrades = {}
	for _, id in Config.UpgradeOrder do
		upgrades[id] = 1
	end
	local zones = {}
	for _, id in Config.ZoneOrder do
		zones[id] = Config.Zones[id].unlockCost == 0
	end
	return { parts = 0, storage = 0, robots = {}, repairs = {}, upgrades = upgrades, zones = zones, tutorialDone = false }
end

local function number(value: any, min: number, max: number): number?
	if typeof(value) ~= "number" or value ~= value then -- value ~= value 는 NaN 검사
		return nil
	end
	return math.clamp(value, min, max)
end

-- 저장소에서 읽은 값을 허용 범위로 정리해서 항상 올바른 Data를 돌려준다.
function RobotLabSave.sanitize(raw: any): Data
	local data = RobotLabSave.newData()
	if typeof(raw) ~= "table" then
		return data
	end
	data.parts = math.floor(number(raw.parts, 0, 1e12) or 0)
	data.storage = number(raw.storage, 0, 1e12) or 0
	if typeof(raw.robots) == "table" then
		for id, level in raw.robots do
			local clamped = number(level, 1, Config.MaxRobotLevel)
			if typeof(id) == "string" and Config.getRobot(id) and clamped then
				data.robots[id] = math.floor(clamped)
			end
		end
	end
	if typeof(raw.upgrades) == "table" then
		for _, id in Config.UpgradeOrder do
			local level = number(raw.upgrades[id], 1, #Config.Upgrades[id].levels)
			if level then
				data.upgrades[id] = math.floor(level)
			end
		end
	end
	if typeof(raw.zones) == "table" then
		for _, id in Config.ZoneOrder do
			if raw.zones[id] == true then
				data.zones[id] = true
			end
		end
	end
	if typeof(raw.repairs) == "table" then
		local slots = Config.upgradeValue("RepairSlots", data.upgrades.RepairSlots)
		for _, repair in raw.repairs do
			if #data.repairs >= slots then
				break
			end
			if typeof(repair) == "table" and typeof(repair.robotId) == "string" and Config.getRobot(repair.robotId)
				and typeof(repair.finishAt) == "number" and repair.finishAt == repair.finishAt then
				table.insert(data.repairs, { robotId = repair.robotId, finishAt = repair.finishAt })
			end
		end
	end
	data.tutorialDone = raw.tutorialDone == true
	-- 저장 시점보다 보관함이 상한을 넘었으면 상한으로
	data.storage = math.min(data.storage, Config.storageCap(data.robots))
	return data
end

-- 저장용 사본 (게임 중 바뀌는 표를 그대로 넘기지 않는다)
local function snapshot(data: Data): Data
	local repairs = {}
	for _, repair in data.repairs do
		table.insert(repairs, { robotId = repair.robotId, finishAt = repair.finishAt })
	end
	return {
		parts = data.parts,
		storage = data.storage,
		robots = table.clone(data.robots),
		repairs = repairs,
		upgrades = table.clone(data.upgrades),
		zones = table.clone(data.zones),
		tutorialDone = data.tutorialDone,
	}
end

-- 떠나 있던 동안의 도우미 수입을 보관함에 더한다. 더한 양을 돌려준다.
function RobotLabSave.applyOffline(data: Data, lastSeen: number?, now: number): number
	if not lastSeen or lastSeen >= now then
		return 0
	end
	local cap = Config.storageCap(data.robots)
	local gained = Config.incomeRate(data.robots) * (now - lastSeen) / 60
	gained = math.max(0, math.min(gained, cap - data.storage))
	data.storage += gained
	return gained
end

local function lockIsForeign(record: any, now: number): boolean
	local lock = typeof(record) == "table" and record.lock
	return typeof(lock) == "table" and lock.job ~= serverId and typeof(lock.at) == "number" and now - lock.at < LOCK_TIMEOUT
end

-- 불러오기 + 이 서버의 lock 남기기.
-- 돌려주는 값: 상태, 데이터(실패·잠김이면 nil), 마지막 접속 시각
function RobotLabSave.loadAsync(userId: number): (LoadStatus, Data?, number?)
	local key = RobotLabSave.keyFor(userId)
	local waited = 0
	local errors = 0
	while true do
		local outcome: LoadStatus = "failed"
		local raw: any = nil
		local ok, err = pcall(function()
			getStore():UpdateAsync(key, function(old: any): any
				local now = os.time()
				raw = nil
				if old == nil then
					outcome = "new"
					return { version = VERSION, data = RobotLabSave.newData(), lastSeen = now, lock = { job = serverId, at = now } }
				end
				if typeof(old) ~= "table" or typeof(old.version) ~= "number" or old.version > VERSION then
					outcome = "failed" -- 알 수 없는 형식: 건드리지 않음
					return nil
				end
				if lockIsForeign(old, now) then
					outcome = "locked"
					return nil
				end
				outcome = "ok"
				raw = old
				old.lock = { job = serverId, at = now }
				return old
			end)
		end)
		if not ok then
			errors += 1
			warn(("[RobotLabSave] 불러오기 %d 실패 (%d/%d): %s"):format(userId, errors, MAX_TRIES, tostring(err)))
			if errors >= MAX_TRIES then
				return "failed", nil, nil
			end
			task.wait(errors)
		elseif outcome == "locked" then
			if waited >= RobotLabSave.lockWaitSeconds then
				warn(("[RobotLabSave] 다른 서버가 아직 %d의 데이터를 쓰는 중이라 이번 접속은 저장하지 않음"):format(userId))
				return "locked", nil, nil
			end
			task.wait(RobotLabSave.lockRetryInterval)
			waited += RobotLabSave.lockRetryInterval
		elseif outcome == "failed" then
			warn("[RobotLabSave] 저장값 형식을 알 수 없어 이번 접속은 저장하지 않음:", userId)
			return "failed", nil, nil
		elseif outcome == "new" then
			return "new", RobotLabSave.newData(), nil
		else
			local lastSeen = if typeof(raw.lastSeen) == "number" then raw.lastSeen else nil
			return "ok", RobotLabSave.sanitize(raw.data), lastSeen
		end
	end
end

-- 저장. release가 true면 lock을 지운다(퇴장·서버 종료).
function RobotLabSave.saveAsync(userId: number, data: Data, release: boolean): SaveStatus
	local key = RobotLabSave.keyFor(userId)
	local copy = snapshot(data)
	for attempt = 1, MAX_TRIES do
		local outcome: SaveStatus = "failed"
		local ok, err = pcall(function()
			getStore():UpdateAsync(key, function(old: any): any
				local now = os.time()
				if old ~= nil and (typeof(old) ~= "table" or typeof(old.version) ~= "number" or old.version > VERSION) then
					outcome = "failed"
					return nil
				end
				local lock = old and old.lock
				if typeof(lock) == "table" and lock.job ~= serverId then
					outcome = "lostLock" -- 다른 서버가 가져갔다. 그쪽이 최신이므로 쓰지 않는다
					return nil
				end
				outcome = "ok"
				return {
					version = VERSION,
					data = copy,
					lastSeen = now,
					lock = if release then nil else { job = serverId, at = now },
				}
			end)
		end)
		if ok then
			if outcome == "lostLock" then
				warn("[RobotLabSave] 다른 서버가 데이터를 가져가 이 서버는 더 저장하지 않음:", userId)
			elseif outcome == "failed" then
				warn("[RobotLabSave] 저장값 형식을 알 수 없어 저장하지 않음:", userId)
			end
			return outcome
		end
		warn(("[RobotLabSave] 저장 %d 실패 (%d/%d): %s"):format(userId, attempt, MAX_TRIES, tostring(err)))
		if attempt < MAX_TRIES then
			task.wait(attempt)
		end
	end
	return "failed"
end

-- 접속 중 저장 관리 ----------------------------------------------------------
type Tracked = { data: Data, saving: boolean }
local tracked: { [Player]: Tracked } = {}
local inFlight = 0 -- 진행 중인 저장 요청 수 (서버 종료 때 기다린다)

-- 불러오기에 성공한 플레이어만 등록한다.
function RobotLabSave.track(player: Player, data: Data)
	tracked[player] = { data = data, saving = false }
end

function RobotLabSave.isTracked(player: Player): boolean
	return tracked[player] ~= nil
end

local function saveTracked(player: Player, entry: Tracked, release: boolean)
	while entry.saving do
		task.wait(0.1)
	end
	entry.saving = true
	inFlight += 1
	local status = RobotLabSave.saveAsync(player.UserId, entry.data, release)
	inFlight -= 1
	entry.saving = false
	if status == "lostLock" and tracked[player] == entry then
		tracked[player] = nil
	end
end

local started = false

-- 자동 저장, 퇴장 저장, 서버 종료 저장을 켠다. RobotLab이 한 번 호출한다.
function RobotLabSave.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player: Player)
		local entry = tracked[player]
		if entry then
			tracked[player] = nil
			saveTracked(player, entry, true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, entry in tracked do
				if not entry.saving then
					task.spawn(saveTracked, player, entry, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		for player, entry in tracked do
			tracked[player] = nil
			task.spawn(saveTracked, player, entry, true)
		end
		local startTime = os.clock()
		task.wait() -- 위에서 시작한 저장이 inFlight를 올릴 시간
		while inFlight > 0 and os.clock() - startTime < CLOSE_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return RobotLabSave
