--!strict
-- JunkyardReferral: 친구 초대 보상 기록 (B-50)
-- DataStore "Referrals_v1", 키 "Inviter_<초대한 사람 UserId>"
-- 값: { pending = 아직 안 받은 보상 수, total = 지금까지 인정된 초대 수, day = 날짜 번호(UTC 기준 os.time() // 86400), dayCount = 그날 인정된 수 }
-- 흐름: 초대받은 사람이 있는 서버가 credit으로 1을 올리고, 초대한 사람이 있는 서버가 claim으로 가져간다.
--      초대한 사람이 다른 서버에 있거나 꺼져 있어도 다음 확인(접속할 때·2분마다)에 받는다.
-- 형식은 바꾸지 않는다. 필드를 더할 때는 clean에 기본값을 넣는다.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))

local STORE_NAME = "Referrals_v1"
local MAX_TRIES = 3 -- 요청 오류 시 시도 횟수

export type Record = { pending: number, total: number, day: number, dayCount: number }

local Referral = {}

local store: any = nil
local function getStore(): any
	if store == nil then
		store = DataStoreService:GetDataStore(STORE_NAME)
	end
	return store
end

-- 테스트용: 가짜 저장소를 넣는다
function Referral.setStoreForTest(fakeStore: any)
	store = fakeStore
end

-- 저장소에서 읽은 값을 허용 범위로 정리한다 (옛 값·잘못된 값도 안전하게)
function Referral.clean(raw: any): Record
	local record: Record = { pending = 0, total = 0, day = 0, dayCount = 0 }
	if typeof(raw) == "table" then
		for _, key in { "pending", "total", "day", "dayCount" } do
			local value = raw[key]
			if typeof(value) == "number" and value == value then
				(record :: any)[key] = math.floor(math.clamp(value, 0, 1e9))
			end
		end
	end
	return record
end

local function keyOf(inviterId: number): string
	return "Inviter_" .. tostring(inviterId)
end

-- UpdateAsync를 재시도와 함께 부른다. 성공하면 true
local function update(key: string, transform: (any) -> any): boolean
	for attempt = 1, MAX_TRIES do
		local ok, err = pcall(function()
			getStore():UpdateAsync(key, transform)
		end)
		if ok then
			return true
		end
		warn(("[JunkyardReferral] %s 저장 실패 (%d/%d): %s"):format(key, attempt, MAX_TRIES, tostring(err)))
		if attempt < MAX_TRIES then
			task.wait(attempt * 2)
		end
	end
	return false
end

-- 오늘 날짜 번호 (하루 한도용, UTC)
function Referral.today(): number
	return os.time() // 86400
end

-- 초대 1건을 인정한다. "ok" = 보상 1개 쌓임, "limit" = 오늘 한도(Config.Referral.DailyLimit) 초과, "failed" = 저장 실패
function Referral.credit(inviterId: number, today: number): string
	local outcome = "failed"
	local ok = update(keyOf(inviterId), function(raw: any): any
		local record = Referral.clean(raw)
		if record.day ~= today then
			record.day = today
			record.dayCount = 0
		end
		if record.dayCount >= Config.Referral.DailyLimit then
			outcome = "limit"
			return nil -- 쓰지 않는다
		end
		record.dayCount += 1
		record.pending += 1
		record.total += 1
		outcome = "ok"
		return record
	end)
	return if ok then outcome else "failed"
end

-- 쌓인 보상을 모두 가져간다. (가져간 수, 인정된 전체 초대 수). 실패하면 (0, nil)
function Referral.claim(inviterId: number): (number, number?)
	local claimed, total = 0, 0
	local ok = update(keyOf(inviterId), function(raw: any): any
		local record = Referral.clean(raw)
		claimed = record.pending
		total = record.total
		if record.pending == 0 then
			return nil -- 받을 것이 없으면 쓰지 않는다
		end
		record.pending = 0
		return record
	end)
	if not ok then
		return 0, nil
	end
	return claimed, total
end

return Referral
