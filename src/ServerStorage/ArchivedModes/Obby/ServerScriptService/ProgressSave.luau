--!strict
-- ProgressSave: 플레이어 진행(Stage)을 DataStore에서 불러오고 저장한다. (서버 전용 모듈)
-- Leaderstats 스크립트가 require해서 쓴다.
--
-- 저장 형식 (한 번 정했으니 바꾸지 말 것. 바꾸면 플레이어 진행이 사라진다)
--   DataStore 이름 : "Progress_v1"
--   키            : "Player_<UserId>"
--   값            : { Stage = 0 이상 마지막 체크포인트 번호 이하의 정수 }
--
-- 안전 원칙
--   1. 불러오기에 실패한 플레이어는 이번 접속 동안 저장하지 않는다. (빈 값으로 덮어쓰기 방지)
--   2. 저장할 때는 기존 값과 비교해 더 높을 때만 쓴다. (늦게 꺼지는 서버가 진행을 낮추지 못하게)
--   3. 알 수 없는 형식의 기존 값은 덮어쓰지 않는다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "Progress_v1"
local MAX_TRIES = 3 -- 실패 시 최대 시도 횟수
local AUTOSAVE_INTERVAL = 60 -- 자동 저장 간격(초)
local CLOSE_TIMEOUT = 25 -- 서버 종료 시 저장을 기다리는 최대 시간(초)

local ProgressSave = {}

-- 허용하는 최대 Stage = Workspace/Checkpoints에서 가장 큰 번호 (현재 11 = EXIT)
local function findMaxStage(): number
	local maxStage = 0
	local folder = workspace:FindFirstChild("Checkpoints")
	if folder then
		for _, cp in folder:GetChildren() do
			local n = tonumber(cp.Name)
			if n and n > maxStage then
				maxStage = n
			end
		end
	end
	return if maxStage > 0 then maxStage else 11
end
local maxStage = findMaxStage()

-- 실제 DataStore. 테스트할 때는 setStoreForTest로 가짜 저장소를 넣을 수 있다.
local store: any = nil
local function getStore(): any
	if store == nil then
		store = DataStoreService:GetDataStore(STORE_NAME)
	end
	return store
end

function ProgressSave.setStoreForTest(fakeStore: any)
	store = fakeStore
end

function ProgressSave.keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

-- 저장된 값이 올바른 형식이면 Stage 숫자를, 아니면 nil을 돌려준다.
function ProgressSave.sanitize(value: any): number?
	if typeof(value) ~= "table" then
		return nil
	end
	local stage = value.Stage
	if typeof(stage) ~= "number" or stage ~= math.floor(stage) or stage < 0 or stage > maxStage then
		return nil
	end
	return stage
end

-- 실패하면 1초, 2초 기다렸다가 다시 시도한다.
local function withRetry(label: string, fn: () -> any): (boolean, any)
	local lastError: any = nil
	for attempt = 1, MAX_TRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[ProgressSave] %s 실패 (%d/%d): %s"):format(label, attempt, MAX_TRIES, tostring(result)))
		if attempt < MAX_TRIES then
			task.wait(attempt)
		end
	end
	return false, lastError
end

-- 불러오기. 성공하면 Stage(처음 온 플레이어는 0), 실패하거나 형식이 이상하면 nil.
function ProgressSave.loadAsync(userId: number): number?
	local ok, data = withRetry("불러오기 " .. userId, function()
		return getStore():GetAsync(ProgressSave.keyFor(userId))
	end)
	if not ok then
		return nil
	end
	if data == nil then
		return 0
	end
	local stage = ProgressSave.sanitize(data)
	if stage == nil then
		warn("[ProgressSave] 저장값 형식이 올바르지 않아 이번 접속은 저장하지 않음:", userId)
	end
	return stage
end

-- 저장. 기존 값보다 높을 때만 쓴다. 요청이 성공하면 true.
function ProgressSave.saveAsync(userId: number, stage: number): boolean
	local ok = withRetry("저장 " .. userId, function()
		return getStore():UpdateAsync(ProgressSave.keyFor(userId), function(old: any): any
			local oldStage = ProgressSave.sanitize(old)
			if old ~= nil and oldStage == nil then
				return nil -- 알 수 없는 형식: 덮어쓰지 않음 (nil을 돌려주면 쓰기 취소)
			end
			if oldStage ~= nil and oldStage >= stage then
				return nil -- 이미 같거나 더 높은 진행이 저장되어 있음
			end
			return { Stage = stage }
		end)
	end)
	return ok
end

-- 접속 중인 플레이어의 저장 상태 -------------------------------------------
type Session = {
	stageValue: IntValue,
	savedStage: number, -- 저장소에 확실히 들어 있는 Stage
	saving: boolean, -- 저장 요청이 진행 중인지 (같은 플레이어 동시 저장 방지)
}
local sessions: { [Player]: Session } = {}

-- 불러오기에 성공한 플레이어만 등록한다. (실패한 플레이어는 저장 대상이 아님)
function ProgressSave.track(player: Player, stageValue: IntValue, loadedStage: number)
	sessions[player] = { stageValue = stageValue, savedStage = loadedStage, saving = false }
end

local function saveSession(player: Player, session: Session)
	if session.saving then
		return
	end
	local stage = session.stageValue.Value
	if stage <= session.savedStage then
		return -- 바뀐 진행이 없음
	end
	session.saving = true
	if ProgressSave.saveAsync(player.UserId, stage) then
		session.savedStage = math.max(session.savedStage, stage)
	end
	session.saving = false
end

-- 진행 중인 저장이 끝나길 기다린 뒤 마지막 값을 한 번 더 저장한다.
local function flush(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	while session.saving do
		task.wait(0.1)
	end
	saveSession(player, session)
end

local started = false

-- 자동 저장, 퇴장 저장, 서버 종료 저장을 켠다. Leaderstats가 한 번 호출한다.
function ProgressSave.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player: Player)
		flush(player)
		sessions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				task.spawn(saveSession, player, session)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				flush(player)
				pending -= 1
			end)
		end
		local startTime = os.clock()
		while pending > 0 and os.clock() - startTime < CLOSE_TIMEOUT do
			task.wait(0.1)
		end
	end)
end

return ProgressSave
