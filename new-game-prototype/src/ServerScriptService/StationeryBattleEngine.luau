--!strict
-- 서버의 순수 경기 계산. 실제 플레이와 빠른 자동 시험이 같은 판정을 사용한다.
local Config = require(game.ReplicatedStorage.Modules.StationeryBattleConfig)
local Engine = {}
Engine.__index = Engine
local function integer(value: any, lo: number, hi: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= lo and value <= hi
end
local function distance(a: any, b: any): number
	return (a.pos - b.pos).Magnitude
end

function Engine.new(id: number, botKind: string?): any
	local self: any = setmetatable({}, Engine)
	self.id, self.phase, self.time, self.battleTime = id, "Prepare", 0, 0
	self.entities, self.projectiles, self.effects = {}, {}, {}
	self.serial, self.winner, self.reason, self.firstContact = 0, 0, "", nil
	self.botKind = if Config.Bots[botKind or ""] then botKind else "Balanced"
	self.teams = {}
	for side = 1, 2 do
		self.teams[side] = { money = Config.Budget, reserve = { Jjondeuk = 0, Cheolkeok = 0 }, slots = { false, false, false, false }, skill = true, free = 0, deployed = 0 }
		self:add("HQ", side, Vector2.new(if side == 1 then -Config.HeadquartersX else Config.HeadquartersX, 0))
	end
	-- 봇 투자안은 사람의 구매 전에 고정한다.
	local bot = Config.Bots[self.botKind]
	for _ = 1, bot.Jjondeuk do self:buy(2, "Jjondeuk") end
	for _ = 1, bot.Cheolkeok do self:buy(2, "Cheolkeok") end
	for i = 1, bot.Towers do self:buy(2, "Tower", if bot.Towers == 2 and i == 2 then 3 else i) end
	return self
end

function Engine:add(kind: string, side: number, pos: Vector2): any
	self.serial += 1
	local health = if kind == "HQ" then Config.HeadquartersHealth else Config.Units[kind].Health
	local e = { id = self.serial, kind = kind, side = side, pos = pos, hp = health, maxHp = health, nextAttack = 0, shotAt = -100, hitAt = -100, slowUntil = 0, direction = if side == 1 then 1 else -1 }
	table.insert(self.entities, e)
	return e
end

function Engine:buy(side: number, kind: any, slot: any): (boolean, string)
	if self.phase ~= "Prepare" then return false, "구매는 준비 중에만 가능해요" end
	local spec = if typeof(kind) == "string" then Config.Units[kind] else nil
	if not spec then return false, "없는 상품이에요" end
	local team = self.teams[side]
	if team.money < spec.Price then return false, "돈이 부족해요" end
	if kind == "Tower" then
		if not integer(slot, 1, 4) or team.slots[slot] then return false, "빈 방어 슬롯을 골라 주세요" end
		team.slots[slot] = true
		local p = Config.Slots[slot]
		local e = self:add("Tower", side, Vector2.new(if side == 1 then p.X else -p.X, p.Y))
		e.slot = slot
	else
		if team.reserve.Jjondeuk + team.reserve.Cheolkeok + 2 >= Config.MaxTroops then return false, "병력 한도예요" end
		team.reserve[kind] += 1
	end
	team.money -= spec.Price
	return true, "구매했어요"
end

function Engine:refund(side: number, kind: any, slot: any): (boolean, string)
	if self.phase ~= "Prepare" then return false, "준비가 끝났어요" end
	local spec = if typeof(kind) == "string" then Config.Units[kind] else nil
	if not spec then return false, "없는 상품이에요" end
	local team = self.teams[side]
	if kind == "Tower" then
		if not integer(slot, 1, 4) or not team.slots[slot] then return false, "설치된 포탑이 없어요" end
		for _, e in self.entities do if e.side == side and e.kind == "Tower" and e.slot == slot and e.hp > 0 then e.hp = 0 end end
		team.slots[slot] = false
	else
		if team.reserve[kind] <= 0 then return false, "돌려줄 병력이 없어요" end
		team.reserve[kind] -= 1
	end
	team.money += spec.Price
	return true, "전액 돌려받았어요"
end

function Engine:ready(): boolean
	if self.phase ~= "Prepare" then return false end
	self.phase, self.battleTime = "Battle", 0
	self.botNext = 2
	return true
end

function Engine:deploy(side: number, kind: any, lane: any, free: boolean?): (boolean, string)
	if self.phase ~= "Battle" then return false, "전투 중에 투입해 주세요" end
	if (kind ~= "Jjondeuk" and kind ~= "Cheolkeok") or not integer(lane, 1, 3) then return false, "종류와 투입 구역을 확인해 주세요" end
	local team = self.teams[side]
	if not free then
		if team.reserve[kind] <= 0 then return false, "대기 병력이 없어요" end
		team.reserve[kind] -= 1
	end
	team.deployed += 1
	local offset = (team.deployed % 3 - 1) * 1.2
	self:add(kind, side, Vector2.new(if side == 1 then -Config.SpawnX else Config.SpawnX, Config.Lanes[lane] + offset))
	return true, "병력 출발!"
end

function Engine:skill(side: number, pos: any): (boolean, string)
	if self.phase ~= "Battle" or not self.teams[side].skill then return false, "종이바람을 사용할 수 없어요" end
	if typeof(pos) ~= "Vector2" or pos.X ~= pos.X or pos.Y ~= pos.Y or math.abs(pos.X) > 47 or math.abs(pos.Y) > 31 then return false, "전장 안을 골라 주세요" end
	local targets = {}
	for _, e in self.entities do
		if e.hp > 0 and e.side ~= side and (e.kind == "Jjondeuk" or e.kind == "Cheolkeok") and (e.pos - pos).Magnitude <= Config.Skill.Radius then table.insert(targets, e) end
	end
	if #targets == 0 then return false, "적 병력이 있는 곳을 골라 주세요" end
	self.teams[side].skill = false
	for _, e in targets do e.slowUntil = self.battleTime + Config.Skill.Duration end
	table.insert(self.effects, { pos = pos, untilAt = self.battleTime + Config.Skill.Duration, side = side })
	return true, "종이바람! 적 이동이 느려져요"
end

function Engine:target(actor: any): any
	local troop, troopDistance, building, buildingDistance = nil, math.huge, nil, math.huge
	local hq = nil
	for _, e in self.entities do
		if e.hp <= 0 or e.side == actor.side then continue end
		local d = distance(actor, e)
		if e.kind == "HQ" then hq = e
		elseif e.kind == "Tower" then
			if d < buildingDistance then building, buildingDistance = e, d end
		elseif d <= (if actor.kind == "Tower" then Config.Units.Tower.Range else Config.DetectRange) and d < troopDistance then
			troop, troopDistance = e, d
		end
	end
	return troop or (if actor.kind == "Tower" then nil else building or hq)
end

function Engine:finish(reason: string)
	if self.phase ~= "Battle" then return end
	local a, b = self.entities[1].hp, self.entities[2].hp
	self.winner = if a == b then 0 elseif a > b then 1 else 2
	self.phase, self.reason = "Result", reason
end

function Engine:step(dt: number)
	if self.phase == "Result" then return end
	self.time += dt
	if self.phase == "Prepare" then
		if self.time >= Config.PrepareSeconds then self:ready() end
		return
	end
	self.battleTime += dt
	local now = self.battleTime
	for side = 1, 2 do
		local team = self.teams[side]
		if team.free < 1 and now >= 0.5 then self:deploy(side, "Jjondeuk", 2, true); team.free = 1 end
		if team.free < 2 and now >= 1 then self:deploy(side, "Cheolkeok", 2, true); team.free = 2 end
	end
	if now >= self.botNext then
		self.botNext = now + 2
		local r = self.teams[2].reserve
		local kind = if r.Jjondeuk > 0 then "Jjondeuk" elseif r.Cheolkeok > 0 then "Cheolkeok" else nil
		if kind then self:deploy(2, kind, self.teams[2].deployed % 3 + 1) end
	end
	if now >= Config.Skill.BotAt and self.teams[2].skill then
		for _, e in self.entities do
			if e.side == 1 and e.hp > 0 and (e.kind == "Jjondeuk" or e.kind == "Cheolkeok") then self:skill(2, e.pos); break end
		end
	end
	-- 판정 시작 시점의 위치를 모두 읽은 후 이동을 적용해 진영 순서의 영향을 줄인다.
	local moves, damage = {}, {}
	for _, e in self.entities do
		if e.hp <= 0 or e.kind == "HQ" then continue end
		local target = self:target(e)
		if not target then continue end
		local spec = Config.Units[e.kind]
		local delta = target.pos - e.pos
		local d = delta.Magnitude
		if d > 0.001 then e.direction = if delta.X >= 0 then 1 else -1 end
		if d > spec.Range then
			local speed = spec.Speed * (if now < e.slowUntil then 1 - Config.Skill.Slow else 1)
			if speed > 0 and d > 0.001 then moves[e.id] = e.pos + delta.Unit * math.min(speed * dt, d - spec.Range) end
		elseif now >= e.nextAttack then
			e.nextAttack, e.shotAt = now + spec.Cooldown, now
			self.firstContact = self.firstContact or now
			local amount = if target.kind == "HQ" or target.kind == "Tower" then spec.BuildingDamage else spec.Damage
			if e.kind == "Jjondeuk" then
				damage[target.id] = (damage[target.id] or 0) + amount
			else
				table.insert(self.projectiles, { target = target.id, amount = amount, arrives = now + 0.45, fired = now, origin = e.pos, destination = target.pos, side = e.side })
			end
		end
	end
	for _, e in self.entities do if moves[e.id] then e.pos = moves[e.id] end end
	for i = #self.projectiles, 1, -1 do
		local p = self.projectiles[i]
		if now + 0.00001 >= p.arrives then
			damage[p.target] = (damage[p.target] or 0) + p.amount
			table.remove(self.projectiles, i)
		end
	end
	for _, e in self.entities do
		if e.hp > 0 and damage[e.id] then e.hp = math.max(0, e.hp - damage[e.id]); e.hitAt = now end
	end
	for i = #self.effects, 1, -1 do if now >= self.effects[i].untilAt then table.remove(self.effects, i) end end
	if self.entities[1].hp == 0 or self.entities[2].hp == 0 then self:finish("본부 파괴"); return end
	if now + 0.00001 >= Config.BattleSeconds then self:finish("시간 종료"); return end
	local potential = #self.projectiles > 0
	for _, team in self.teams do if team.free < 2 or team.reserve.Jjondeuk + team.reserve.Cheolkeok > 0 then potential = true end end
	for _, e in self.entities do if e.hp > 0 and (e.kind == "Jjondeuk" or e.kind == "Cheolkeok") then potential = true end end
	if not potential then self:finish("공격 병력 소진") end
end

function Engine:snapshot(): any
	local entities = {}
	for _, e in self.entities do
		if e.hp > 0 then table.insert(entities, { id = e.id, kind = e.kind, side = e.side, pos = e.pos, hp = e.hp, maxHp = e.maxHp, shotAt = e.shotAt, hitAt = e.hitAt, direction = e.direction, slowed = self.battleTime < e.slowUntil }) end
	end
	return { id = self.id, phase = self.phase, time = self.time, battleTime = self.battleTime, teams = self.teams, entities = entities, projectiles = self.projectiles, effects = self.effects, winner = self.winner, reason = self.reason, headquarters = { self.entities[1].hp, self.entities[2].hp }, botKind = self.botKind }
end
return Engine
