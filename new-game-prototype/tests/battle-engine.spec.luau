--!strict
-- 실제 서버 계산 모듈을 짧은 시간 간격으로 실행하는 회귀 시험이다.
assert(game.PlaceId == 123176209315432 and game:GetService("RunService"):IsStudio(), "문방구 Studio에서만 시험하세요")
-- 편집 중 require 캐시에 남은 이전 코드를 쓰지 않도록 현재 원문의 복제본을 읽는다.
local module = game.ServerScriptService.StationeryBattleEngine:Clone()
local E = require(module)
module:Destroy()
local C = require(game.ReplicatedStorage.Modules.StationeryBattleConfig)
local checks = 0
local function check(yes: any, reason: string)
	assert(yes, reason); checks += 1
end
local function isolated(): any
	local m = E.new(999, "Attack")
	m.entities = { m.entities[1], m.entities[2] }
	for _, t in m.teams do t.reserve = { Jjondeuk = 0, Cheolkeok = 0 }; t.free = 2 end
	m:ready(); m.botNext = math.huge
	return m
end
local m = E.new(1)
check(m.teams[1].money == 1000 and m.teams[2].money == 0, "동일 예산과 봇 지출")
for _, invalid in { 0, 5, 1.5, math.huge, 0 / 0, "1" } do check(not m:buy(1, "Tower", invalid), "잘못된 슬롯 거절") end
check(not m:buy(1, {}), "잘못된 종류 타입")
check(not m:buy(1, "Unknown"), "없는 종류")
for i = 1, 4 do check(m:buy(1, "Tower", i), "전액 수비 구매") end
check(m.teams[1].money == 0 and not m:buy(1, "Jjondeuk"), "초과 지출 거절")
check(not m:buy(1, "Tower", 1), "중복 슬롯 거절")
check(m:refund(1, "Tower", 3), "환불")
check(not m:refund(1, "Tower", 3) and m.teams[1].money == 250, "중복 환불 차단")
check(m:buy(1, "Jjondeuk"), "병력 구매")
check(m:refund(1, "Jjondeuk"), "병력 환불")
check(m.teams[1].money == 250 and m.teams[1].reserve.Jjondeuk == 0, "정확한 전액 환불")
check(#m.teams[1].slots == 4 and m.teams[1].slots[3] == false, "희소 배열 없는 슬롯 전송")
check(not m:deploy(1, "Jjondeuk", 2), "준비 중 투입 거절")
check(m:ready() and not m:ready(), "전투 전환 한 번")
check(not m:buy(1, "Cheolkeok") and not m:refund(1, "Tower", 1), "준비 후 거래 잠금")
check(not m:deploy(1, "Jjondeuk", 2), "대기 병력 없이 투입 불가")
m = E.new(2)
for _ = 1, 10 do check(m:buy(1, "Jjondeuk"), "전액 공격 구매") end
check(m.teams[1].money == 0 and m.teams[1].reserve.Jjondeuk == 10, "전액 공격 예산")
m:ready()
check(not m:deploy(1, "Jjondeuk", 0 / 0), "비정상 투입 좌표")
check(m:deploy(1, "Jjondeuk", 1), "유효 투입")
check(not m:skill(1, Vector2.new(math.huge, 0)), "무한 스킬 위치")
check(not m:skill(1, Vector2.new(0 / 0, 0)), "NaN 스킬 위치")
check(not m:skill(1, Vector2.new(0, 0)) and m.teams[1].skill, "빈 곳에서 스킬 소비 안 함")
local enemy = m:add("Jjondeuk", 2, Vector2.new(0, 0))
check(m:skill(1, Vector2.new(0, 0)) and enemy.slowUntil == 4, "적에게 둔화 적용")
check(not m:skill(1, Vector2.new(0, 0)), "스킬 중복 사용 차단")
m = isolated()
local a = m:add("Cheolkeok", 1, Vector2.new(0, 0))
m:add("Tower", 2, Vector2.new(13, 0))
m:step(0.1)
check(a.shotAt < 0, "사거리 밖 공격 차단")
for _ = 1, 6 do m:step(0.1) end
check(a.shotAt > 0, "접근 후 공격")
local shot = m.projectiles[1]
check(shot and (shot.destination - shot.origin).Magnitude <= C.Units.Cheolkeok.Range + 0.001, "발사 시 실제 사거리")
local victim = m.entities[4]
-- 표적 사망 뒤 이미 날아간 공격이 다른 표적으로 옮겨가지 않는다.
local untouched = m.entities[2].hp
victim.hp = 0
for _ = 1, 7 do m:step(0.1) end
check(m.entities[2].hp == untouched, "사망 표적 공격의 재지정 없음")
m = isolated()
table.insert(m.projectiles, { target = 1, amount = 600, arrives = 0.1 })
table.insert(m.projectiles, { target = 2, amount = 600, arrives = 0.1 })
m:step(0.1)
check(m.phase == "Result" and m.winner == 0 and m.reason == "본부 파괴", "동시 본부 파괴 무승부")
local finishTime = m.time; m:step(1)
check(m.time == finishTime, "종료 결과 한 번만 확정")
m = isolated(); m.teams[1].reserve.Jjondeuk = 1
m.battleTime = 89.9; m.entities[1].hp = 500; m.entities[2].hp = 400; m:step(0.1)
check(m.reason == "시간 종료" and m.winner == 1, "시간 종료 피해율 승패")
m = isolated(); m:step(0.1)
check(m.phase == "Result" and m.reason == "공격 병력 소진" and m.winner == 0, "공격 수단 소진 조기 종료")
m = E.new(3); for _ = 1, 450 do m:step(0.1) end
check(m.phase == "Battle", "준비 시간 자동 종료")

local comparison = {}
for _, ours in { "Attack", "Balanced", "Defense" } do
	for _, theirs in { "Attack", "Balanced", "Defense" } do
		m = E.new(100, theirs)
		local plan = C.Bots[ours]
		for _ = 1, plan.Jjondeuk do check(m:buy(1, "Jjondeuk"), "비교용 쫀득 구매") end
		for _ = 1, plan.Cheolkeok do check(m:buy(1, "Cheolkeok"), "비교용 철컥 구매") end
		for i = 1, plan.Towers do check(m:buy(1, "Tower", if plan.Towers == 2 and i == 2 then 3 else i), "비교용 포탑 구매") end
		check(m.teams[1].money == 0, "비교 투자 1000원")
		m:ready(); local nextDeploy = 2
		for step = 1, 901 do
			if m.battleTime >= nextDeploy then
				nextDeploy = m.battleTime + 2
				local r = m.teams[1].reserve
				if r.Jjondeuk > 0 then m:deploy(1, "Jjondeuk", m.teams[1].deployed % 3 + 1)
				elseif r.Cheolkeok > 0 then m:deploy(1, "Cheolkeok", m.teams[1].deployed % 3 + 1) end
			end
			if m.battleTime >= 25 and m.teams[1].skill then
				for _, e in m.entities do if e.side == 2 and e.hp > 0 and (e.kind == "Jjondeuk" or e.kind == "Cheolkeok") then m:skill(1, e.pos); break end end
			end
			m:step(0.1)
			if m.phase == "Result" then break end
			if step % 100 == 0 then task.wait() end
		end
		check(m.phase == "Result", "모든 경기 종료")
		table.insert(comparison, { ours = ours, bot = theirs, winner = m.winner, reason = m.reason, seconds = m.battleTime, hp = { m.entities[1].hp, m.entities[2].hp }, firstContact = m.firstContact })
	end
end
return { checks = checks, comparison = comparison }
