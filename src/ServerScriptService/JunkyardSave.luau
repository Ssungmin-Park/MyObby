--!strict
-- JunkyardSave: 로봇 고물상 데이터를 DataStore에서 불러오고 저장한다. (서버 전용 모듈, Junkyard가 쓴다)
-- 로봇 작업장 RobotLabSave와 같은 안전 방식(세션 잠금)을 쓴다.
--
-- 저장 형식 (한 번 정했으니 바꾸지 말 것. 바꾸면 플레이어 진행이 사라진다)
--   DataStore 이름 : "Junkyard_v1"   (오비 Progress_v1, 작업장 RobotLab_v1과 별개)
--   키            : "Player_<UserId>"
--   값            : { version = 1, data = Data, lastSeen = os.time(), lock = { job = 서버ID, at = os.time() } 또는 없음 }
--   Data          : { money = 정수, catalog = { [로봇 id] = true }, pads = { ["받침대 번호"] = 로봇 id },
--                     upgrades = { [업그레이드 id] = 단계 }, empCharges = 정수 }
--                   ← upgrades는 3-1, empCharges(Robux로 산 무료 EMP)는 3-2에서 추가 (옛 데이터는 0으로 읽힘)
--                   ← rebirth(환생 단계), variantCatalog({ ["Pippi@Gold"] = true })는 4단계에서 추가. 받침대 값은 변종 키도 허용
--
-- 안전 원칙
--   1. 세션 잠금: 데이터를 쓰는 서버가 lock을 남긴다. 다른 서버의 lock이 살아 있으면 기다리고,
--      2분 넘게 갱신되지 않은 lock은 꺼진 서버의 것으로 보고 가져온다.
--   2. 불러오기에 실패하면 이번 접속은 저장하지 않는다. (빈 데이터로 덮어쓰기 방지)
--   3. 저장할 때 lock이 다른 서버로 넘어가 있으면 쓰지 않는다.
--   4. 알 수 없는 형식(표가 아닌 값, 더 새로운 version)은 덮어쓰지 않는다.
--   5. 불러온 값은 하나하나 검사해서 허용 범위로 정리한다.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))

local STORE_NAME = "Junkyard_v1"
local VERSION = 1
local MAX_TRIES = 3 -- 요청 오류 시 시도 횟수
local LOCK_TIMEOUT = 120 -- 이 시간(초) 넘게 갱신되지 않은 lock은 만료
local AUTOSAVE_INTERVAL = 60 -- 자동 저장 간격(초). lock도 이때 갱신된다
local CLOSE_TIMEOUT = 25 -- 서버 종료 시 저장을 기다리는 최대 시간(초)
local MAX_MONEY = 1e15

export type Data = {
	money: number,
	catalog: { [string]: boolean },
	pads: { [string]: string }, -- 받침대 번호(문자열) → 로봇 id
	upgrades: { [string]: number }, -- 업그레이드 id → 단계 (0 = 기본)
	empCharges: number, -- Robux 상품으로 받은 무료 EMP 남은 횟수
	rebirth: number, -- 환생 단계
	variantCatalog: { [string]: boolean }, -- 모은 변종 키
}
export type LoadStatus = "new" | "ok" | "failed" | "locked"
export type SaveStatus = "ok" | "failed" | "lostLock"

local JunkyardSave = {}
JunkyardSave.lockWaitSeconds = 30 -- 다른 서버의 lock을 기다리는 최대 시간 (테스트에서 줄일 수 있음)
JunkyardSave.lockRetryInterval = 5

-- 이 서버를 구분하는 값. Studio에서는 JobId가 비어 있어 임의 값을 만든다.
local serverId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local store: any = nil
local function getStore(): any
	if store == nil then
		store = DataStoreService:GetDataStore(STORE_NAME)
	end
	return store
end

-- 테스트용: 가짜 저장소와 서버 ID를 넣는다
function JunkyardSave.setStoreForTest(fakeStore: any, fakeServerId: string?)
	store = fakeStore
	if fakeServerId then
		serverId = fakeServerId
	end
end

function JunkyardSave.keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local function defaultUpgrades(): { [string]: number }
	local upgrades = {}
	for _, id in Config.UpgradeOrder do
		upgrades[id] = 0
	end
	return upgrades
end

function JunkyardSave.newData(): Data
	return { money = Config.StartMoney, catalog = {}, pads = {}, upgrades = defaultUpgrades(), empCharges = 0, rebirth = 0, variantCatalog = {} }
end

-- 저장소에서 읽은 값을 허용 범위로 정리해서 항상 올바른 Data를 돌려준다.
function JunkyardSave.sanitize(raw: any): Data
	local data: Data = { money = 0, catalog = {}, pads = {}, upgrades = defaultUpgrades(), empCharges = 0, rebirth = 0, variantCatalog = {} }
	if typeof(raw) ~= "table" then
		return JunkyardSave.newData()
	end
	local money = raw.money
	if typeof(money) == "number" and money == money then -- money == money 는 NaN 검사
		data.money = math.floor(math.clamp(money, 0, MAX_MONEY))
	end
	if typeof(raw.catalog) == "table" then
		for _, robot in Config.Robots do
			if raw.catalog[robot.id] == true then
				data.catalog[robot.id] = true
			end
		end
	end
	if typeof(raw.pads) == "table" then
		for key, robotId in raw.pads do
			local index = tonumber(key)
			if index and index == math.floor(index) and index >= 1 and index <= Config.MaxPads
				and typeof(robotId) == "string" and Config.isValidKey(robotId) then
				data.pads[tostring(index)] = robotId
				-- 받침대에 있는 로봇은 도감에도 있어야 한다 (변종이면 변종 도감에도)
				local baseId, variantId = Config.splitKey(robotId)
				data.catalog[baseId] = true
				if variantId then
					data.variantCatalog[robotId] = true
				end
			end
		end
	end
	local rebirth = raw.rebirth
	if typeof(rebirth) == "number" and rebirth == rebirth then
		data.rebirth = math.floor(math.clamp(rebirth, 0, 1000))
	end
	if typeof(raw.variantCatalog) == "table" then
		for key, owned in raw.variantCatalog do
			if owned == true and typeof(key) == "string" and Config.isValidKey(key) and Config.variantOf(key) then
				data.variantCatalog[key] = true
			end
		end
	end
	local charges = raw.empCharges
	if typeof(charges) == "number" and charges == charges then
		data.empCharges = math.floor(math.clamp(charges, 0, 999))
	end
	if typeof(raw.upgrades) == "table" then
		for _, id in Config.UpgradeOrder do
			local level = raw.upgrades[id]
			if typeof(level) == "number" and level == level then
				data.upgrades[id] = math.floor(math.clamp(level, 0, #Config.Upgrades[id].costs))
			end
		end
	end
	return data
end

-- 저장용 사본
local function snapshot(data: Data): Data
	return {
		money = math.floor(data.money),
		catalog = table.clone(data.catalog),
		pads = table.clone(data.pads),
		upgrades = table.clone(data.upgrades),
		empCharges = math.floor(data.empCharges),
		rebirth = math.floor(data.rebirth),
		variantCatalog = table.clone(data.variantCatalog),
	}
end

local function lockIsForeign(record: any, now: number): boolean
	local lock = typeof(record) == "table" and record.lock
	return typeof(lock) == "table" and lock.job ~= serverId and typeof(lock.at) == "number" and now - lock.at < LOCK_TIMEOUT
end

-- 불러오기 + 이 서버의 lock 남기기. 돌려주는 값: 상태, 데이터(실패·잠김이면 nil), 마지막 접속 시각
function JunkyardSave.loadAsync(userId: number): (LoadStatus, Data?, number?)
	local key = JunkyardSave.keyFor(userId)
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
					return { version = VERSION, data = JunkyardSave.newData(), lastSeen = now, lock = { job = serverId, at = now } }
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
			warn(("[JunkyardSave] 불러오기 %d 실패 (%d/%d): %s"):format(userId, errors, MAX_TRIES, tostring(err)))
			if errors >= MAX_TRIES then
				return "failed", nil, nil
			end
			task.wait(errors)
		elseif outcome == "locked" then
			if waited >= JunkyardSave.lockWaitSeconds then
				warn(("[JunkyardSave] 다른 서버가 아직 %d의 데이터를 쓰는 중이라 이번 접속은 저장하지 않음"):format(userId))
				return "locked", nil, nil
			end
			task.wait(JunkyardSave.lockRetryInterval)
			waited += JunkyardSave.lockRetryInterval
		elseif outcome == "failed" then
			warn("[JunkyardSave] 저장값 형식을 알 수 없어 이번 접속은 저장하지 않음:", userId)
			return "failed", nil, nil
		elseif outcome == "new" then
			return "new", JunkyardSave.newData(), nil
		else
			local lastSeen = if typeof(raw.lastSeen) == "number" then raw.lastSeen else nil
			return "ok", JunkyardSave.sanitize(raw.data), lastSeen
		end
	end
end

-- 저장. release가 true면 lock을 지운다(퇴장·서버 종료).
function JunkyardSave.saveAsync(userId: number, data: Data, release: boolean): SaveStatus
	local key = JunkyardSave.keyFor(userId)
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
				warn("[JunkyardSave] 다른 서버가 데이터를 가져가 이 서버는 더 저장하지 않음:", userId)
			elseif outcome == "failed" then
				warn("[JunkyardSave] 저장값 형식을 알 수 없어 저장하지 않음:", userId)
			end
			return outcome
		end
		warn(("[JunkyardSave] 저장 %d 실패 (%d/%d): %s"):format(userId, attempt, MAX_TRIES, tostring(err)))
		if attempt < MAX_TRIES then
			task.wait(attempt)
		end
	end
	return "failed"
end

-- 떠나 있던 동안의 수입: 초당 수입 × 비율 × 경과 시간(최대 OfflineMaxHours)
-- rate·hours를 주지 않으면 기본값(Config.OfflineRate, OfflineMaxHours). 오프라인 수입 강화 게임패스는 더 큰 값을 준다
function JunkyardSave.offlineEarnings(incomePerSecond: number, lastSeen: number?, now: number, rate: number?, hours: number?): number
	if not lastSeen or lastSeen >= now or incomePerSecond <= 0 then
		return 0
	end
	local seconds = math.min(now - lastSeen, (hours or Config.OfflineMaxHours) * 3600)
	return math.floor(incomePerSecond * (rate or Config.OfflineRate) * seconds)
end

-- 접속 중 저장 관리 ----------------------------------------------------------
-- 고물상 데이터는 돈·도감·기지에 흩어져 있으므로, 저장할 때마다 getData로 지금 값을 모은다.
type Tracked = { getData: () -> Data, saving: boolean }
local tracked: { [Player]: Tracked } = {}
local inFlight = 0 -- 진행 중인 저장 요청 수 (서버 종료 때 기다린다)

-- 불러오기에 성공한 플레이어만 등록한다.
function JunkyardSave.track(player: Player, getData: () -> Data)
	tracked[player] = { getData = getData, saving = false }
end

local function saveTracked(player: Player, entry: Tracked, data: Data, release: boolean)
	while entry.saving do
		task.wait(0.1)
	end
	entry.saving = true
	inFlight += 1
	local status = JunkyardSave.saveAsync(player.UserId, data, release)
	inFlight -= 1
	entry.saving = false
	if status == "lostLock" and tracked[player] == entry then
		tracked[player] = nil
	end
end

-- 퇴장할 때 Junkyard가 기지를 비우기 **전에** 부른다. 지금 값을 바로 모아 두고(멈추지 않음),
-- 저장은 따로 진행한다(lock 해제). 그래서 부른 쪽은 곧바로 기지를 비울 수 있다.
function JunkyardSave.finish(player: Player)
	local entry = tracked[player]
	if not entry then
		return
	end
	tracked[player] = nil
	local data = entry.getData()
	task.spawn(saveTracked, player, entry, data, true)
end

-- 결제 직후처럼 바로 저장해야 할 때 부른다 (lock 유지, 멈추지 않음)
function JunkyardSave.saveNow(player: Player)
	local entry = tracked[player]
	if entry then
		task.spawn(saveTracked, player, entry, entry.getData(), false)
	end
end

local started = false

-- 자동 저장과 서버 종료 저장을 켠다. Junkyard가 한 번 호출한다.
function JunkyardSave.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, entry in tracked do
				if not entry.saving then
					task.spawn(saveTracked, player, entry, entry.getData(), false)
				end
			end
		end
	end)

	game:BindToClose(function()
		for player, entry in tracked do
			tracked[player] = nil
			task.spawn(saveTracked, player, entry, entry.getData(), true)
		end
		local startTime = os.clock()
		task.wait() -- 위에서 시작한 저장이 inFlight를 올릴 시간
		while inFlight > 0 and os.clock() - startTime < CLOSE_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return JunkyardSave
