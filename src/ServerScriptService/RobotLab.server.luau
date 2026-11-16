--!strict
-- RobotLab: 로봇 작업장(꼬마 로봇 연구소) 서버 로직. 모든 판정은 서버에서 한다.
-- 반복 루프:
--   구역에서 부품 더미 줍기(가방) → 수거함에 넣기(부품)
--   → 고장 난 로봇 신호를 찾아 줍기 → 수리대에 맡기기(부품 + 실제 시간)
--   → 수리한 로봇이 계속 부품을 벌어 보관함에 쌓음 → 업그레이드·새 구역 열기
-- 클라이언트(RobotLabHud)는 화면 표시와 요청("Collect", "PickUp")만 한다.
-- 밸런스 숫자는 ReplicatedStorage/Modules/RobotLabConfig에 있다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RobotLabConfig"))

local lab = workspace:WaitForChild("RobotLab")
local interactions = lab:WaitForChild("Interactions")
local spawnPoints = lab:WaitForChild("SpawnPoints")
local arrival = lab:WaitForChild("Arrival") :: BasePart
local obbySpawn = workspace:WaitForChild("SpawnLocation") :: BasePart
local checkpoints = workspace:WaitForChild("Checkpoints")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild("RobotLabState") :: RemoteEvent
local actionRemote = remotes:WaitForChild("RobotLabAction") :: RemoteEvent

-- 저장 대상 데이터 (3단계에서 DataStore에 저장할 예정. 필드 이름을 함부로 바꾸지 않는다)
type Repair = { robotId: string, finishAt: number } -- finishAt = os.time() 기준
type Data = {
	parts: number,
	storage: number, -- 도우미 로봇이 모은 부품 (수거함에서 받는다)
	robots: { [string]: number }, -- 로봇 id → 레벨
	repairs: { Repair },
	upgrades: { [string]: number }, -- 업그레이드 id → 레벨 (1 = 기본)
	zones: { [string]: boolean }, -- 열린 구역
	tutorialDone: boolean,
}
-- 접속 중에만 쓰는 상태
type Pile = { id: number, zone: string, point: BasePart, value: number }
type Signal = { robotId: string, zone: string, point: BasePart }
type Session = {
	data: Data,
	active: boolean, -- 연구소 안에 있는지
	bag: number,
	carrying: string?,
	signal: Signal?,
	signalAt: number, -- 다음 신호가 나타날 시각 (os.clock)
	piles: { [number]: Pile },
	respawns: { { zone: string, at: number } },
	nextPileId: number,
	message: string,
	lastPrompt: number,
	actionCount: number, -- 원격 요청 횟수 제한용
	actionWindow: number,
}
local sessions: { [Player]: Session } = {}

local function newData(): Data
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

local function upgradeValue(session: Session, id: string): number
	return Config.upgradeValue(id, session.data.upgrades[id] or 1)
end

-- 분당 수입 합계
local function incomeRate(data: Data): number
	local total = 0
	for robotId, level in data.robots do
		total += Config.robotIncome(robotId, level)
	end
	return total
end

local function storageCap(data: Data): number
	return math.max(Config.StorageMinCap, incomeRate(data) * Config.StorageCapMinutes)
end

local function zonePoints(zone: string): { BasePart }
	local folder = spawnPoints:FindFirstChild(zone)
	local list = {}
	if folder then
		for _, point in folder:GetChildren() do
			if point:IsA("BasePart") then
				table.insert(list, point)
			end
		end
	end
	return list
end

-- 부품 더미나 신호가 없는 빈 지점을 고른다
local function freePoint(session: Session, zone: string): BasePart?
	local used: { [BasePart]: boolean } = {}
	for _, pile in session.piles do
		used[pile.point] = true
	end
	if session.signal then
		used[session.signal.point] = true
	end
	local candidates = {}
	for _, point in zonePoints(zone) do
		if not used[point] then
			table.insert(candidates, point)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(#candidates)]
end

local function spawnPile(session: Session, zone: string)
	local point = freePoint(session, zone)
	if not point then
		table.insert(session.respawns, { zone = zone, at = os.clock() + Config.PileRespawn })
		return
	end
	session.nextPileId += 1
	session.piles[session.nextPileId] = { id = session.nextPileId, zone = zone, point = point, value = Config.Zones[zone].pileValue }
end

local function fillZone(session: Session, zone: string)
	for _ = 1, Config.Zones[zone].pileCount do
		spawnPile(session, zone)
	end
end

local function rollRobot(zone: string): string
	local weights = Config.Zones[zone].rarityWeights
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = math.random() * total
	local rarity = "Common"
	for _, id in Config.RarityOrder do
		local weight = weights[id]
		if weight then
			roll -= weight
			if roll <= 0 then
				rarity = id
				break
			end
		end
	end
	local candidates = {}
	for _, robot in Config.Robots do
		if robot.rarity == rarity then
			table.insert(candidates, robot.id)
		end
	end
	return candidates[math.random(#candidates)]
end

local function spawnSignal(session: Session)
	if not session.data.tutorialDone then
		local point = zonePoints("Lab")[1]
		if point then
			session.signal = { robotId = Config.TutorialRobot, zone = "Lab", point = point }
		end
		return
	end
	local open = {}
	for _, zone in Config.ZoneOrder do
		if session.data.zones[zone] then
			table.insert(open, zone)
		end
	end
	if #open == 0 then
		return
	end
	local zone = open[math.random(#open)]
	local point = freePoint(session, zone)
	if point then
		session.signal = { robotId = rollRobot(zone), zone = zone, point = point }
	end
end

local function repairCost(session: Session, robotId: string): number
	if robotId == Config.TutorialRobot and next(session.data.robots) == nil then
		return 0 -- 첫 로봇은 무료
	end
	local robot = Config.getRobot(robotId)
	return if robot then Config.Rarities[robot.rarity].repairCost else 0
end

local function repairDuration(session: Session, robotId: string): number
	if robotId == Config.TutorialRobot and next(session.data.robots) == nil then
		return Config.TutorialRepairTime
	end
	local robot = Config.getRobot(robotId)
	local base = if robot then Config.Rarities[robot.rarity].repairTime else 60
	return math.ceil(base * upgradeValue(session, "RepairSpeed"))
end

-- 클라이언트에 보낼 상태 묶음 -----------------------------------------------
local function sendState(player: Player, session: Session)
	if not session.active then
		stateRemote:FireClient(player, { active = false })
		return
	end
	local now = os.time()
	local piles = {}
	for _, pile in session.piles do
		table.insert(piles, { id = pile.id, position = pile.point.Position, value = pile.value, zone = pile.zone })
	end
	local repairs = {}
	for _, repair in session.data.repairs do
		table.insert(repairs, { robotId = repair.robotId, remaining = math.max(0, repair.finishAt - now) })
	end
	local signal = session.signal
	stateRemote:FireClient(player, {
		active = true,
		parts = math.floor(session.data.parts),
		storage = math.floor(session.data.storage),
		storageCap = math.floor(storageCap(session.data)),
		rate = incomeRate(session.data),
		bag = session.bag,
		bagMax = upgradeValue(session, "Bag"),
		detector = upgradeValue(session, "Detector"),
		slots = upgradeValue(session, "RepairSlots"),
		carrying = session.carrying,
		carryCost = if session.carrying then repairCost(session, session.carrying) else nil,
		signal = if signal then { robotId = signal.robotId, zone = signal.zone, position = signal.point.Position } else nil,
		piles = piles,
		robots = session.data.robots,
		repairs = repairs,
		upgrades = session.data.upgrades,
		zones = session.data.zones,
		tutorialDone = session.data.tutorialDone,
		message = session.message,
	})
end

local function say(session: Session, message: string)
	session.message = message
end

-- 행동 ----------------------------------------------------------------------
local function deposit(session: Session)
	local fromBag = session.bag
	local fromStorage = math.floor(session.data.storage)
	if fromBag == 0 and fromStorage == 0 then
		say(session, "넣을 부품이 없어요. 구역에서 부품 더미를 주워 오세요.")
		return
	end
	session.bag = 0
	session.data.storage -= fromStorage
	session.data.parts += fromBag + fromStorage
	say(session, ("부품 +%d (가방 %d, 보관함 %d)"):format(fromBag + fromStorage, fromBag, fromStorage))
end

local function startRepair(session: Session)
	local robotId = session.carrying
	if not robotId then
		if #session.data.repairs > 0 then
			say(session, "수리 중인 로봇이 있어요. 시간이 지나면 자동으로 완료돼요.")
		else
			say(session, "고장 난 로봇을 찾아서 가져오세요.")
		end
		return
	end
	if #session.data.repairs >= upgradeValue(session, "RepairSlots") then
		say(session, "수리대가 모두 사용 중이에요. 업그레이드로 수리대를 늘릴 수 있어요.")
		return
	end
	local cost = repairCost(session, robotId)
	if session.data.parts < cost then
		say(session, ("수리하려면 부품이 %d개 더 필요해요."):format(cost - math.floor(session.data.parts)))
		return
	end
	session.data.parts -= cost
	table.insert(session.data.repairs, { robotId = robotId, finishAt = os.time() + repairDuration(session, robotId) })
	session.carrying = nil
	session.signalAt = os.clock() + Config.SignalDelay
	local robot = Config.getRobot(robotId)
	say(session, ("%s 수리 시작! (%s)"):format(robot and robot.name or robotId, Config.formatTime(repairDuration(session, robotId))))
end

local function buyUpgrade(session: Session, id: string)
	local upgrade = Config.Upgrades[id]
	if not upgrade then
		return
	end
	local level = session.data.upgrades[id] or 1
	local nextLevel = upgrade.levels[level + 1]
	if not nextLevel then
		say(session, upgrade.name .. "은(는) 최고 단계예요.")
		return
	end
	if session.data.parts < nextLevel.cost then
		say(session, ("%s: 부품이 %d개 더 필요해요."):format(upgrade.name, nextLevel.cost - math.floor(session.data.parts)))
		return
	end
	session.data.parts -= nextLevel.cost
	session.data.upgrades[id] = level + 1
	say(session, ("%s %d단계 완료!"):format(upgrade.name, level + 1))
end

local function unlockZone(session: Session, zone: string)
	local info = Config.Zones[zone]
	if not info then
		return
	end
	if session.data.zones[zone] then
		say(session, info.name .. "은(는) 이미 열려 있어요.")
		return
	end
	if session.data.parts < info.unlockCost then
		say(session, ("%s을(를) 열려면 부품이 %d개 더 필요해요."):format(info.name, info.unlockCost - math.floor(session.data.parts)))
		return
	end
	session.data.parts -= info.unlockCost
	session.data.zones[zone] = true
	fillZone(session, zone)
	say(session, info.name .. "이(가) 열렸어요! 더 좋은 부품과 로봇이 나와요.")
end

local function returnToObby(player: Player, session: Session, character: Model, root: BasePart)
	session.active = false
	local stats = player:FindFirstChild("leaderstats")
	local stage = stats and stats:FindFirstChild("Stage")
	local checkpoint = if stage and stage:IsA("IntValue") then checkpoints:FindFirstChild(tostring(stage.Value)) else nil
	local destination = if checkpoint and checkpoint:IsA("BasePart") then checkpoint else obbySpawn
	character:PivotTo(destination.CFrame + Vector3.new(0, destination.Size.Y / 2 + 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

-- 캐릭터 확인: 살아 있고 지정한 위치에서 range 안에 있으면 루트 파트를 돌려준다
local function rootNear(player: Player, position: Vector3, range: number): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	if (root.Position - position).Magnitude > range then
		return nil
	end
	return root
end

-- 장치(ProximityPrompt) ------------------------------------------------------
local function handlePrompt(player: Player, prompt: ProximityPrompt)
	local point = prompt.Parent
	if not prompt.Enabled or not point or not point:IsA("BasePart") then
		return
	end
	local root = rootNear(player, point.Position, prompt.MaxActivationDistance + 2)
	local character = player.Character
	if not root or not character then
		return
	end
	local session = sessions[player]
	if not session then
		return
	end

	local action = point.Name
	if action == "Enter" or action == "EnterAtExit" then
		-- 기존 오비의 첫 리스폰 처리와 입장이 겹치지 않게 leaderstats가 생긴 뒤에만 입장한다
		if not player:FindFirstChild("leaderstats") or session.active then
			return
		end
		session.active = true
		character:PivotTo(arrival.CFrame)
		root.AssemblyLinearVelocity = Vector3.zero
		say(session, "로봇 작업장에 오신 것을 환영해요.")
		sendState(player, session)
		return
	end
	if not session.active or os.clock() - session.lastPrompt < 0.25 then
		return
	end
	session.lastPrompt = os.clock()

	if action == "Return" then
		returnToObby(player, session, character, root)
	elseif action == "Deposit" then
		deposit(session)
	elseif action == "Repair" then
		startRepair(session)
	else
		local upgradeId = string.match(action, "^Upgrade_(.+)$")
		local zoneId = string.match(action, "^Unlock_(.+)$")
		if upgradeId then
			buyUpgrade(session, upgradeId)
		elseif zoneId then
			unlockZone(session, zoneId)
		else
			return
		end
	end
	sendState(player, session)
end

for _, point in interactions:GetChildren() do
	local prompt = point:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			handlePrompt(player, prompt)
		end)
	end
end

-- 클라이언트 요청 (값은 반드시 검증) ------------------------------------------
actionRemote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local session = sessions[player]
	if not session or not session.active or typeof(action) ~= "string" then
		return
	end
	-- 1초에 20번 넘게 보내면 무시
	local now = os.clock()
	if now - session.actionWindow > 1 then
		session.actionWindow = now
		session.actionCount = 0
	end
	session.actionCount += 1
	if session.actionCount > 20 then
		return
	end

	if action == "Collect" then
		if typeof(arg) ~= "number" then
			return
		end
		local pile = session.piles[arg]
		if not pile or not rootNear(player, pile.point.Position, Config.CollectRange) then
			return
		end
		local bagMax = upgradeValue(session, "Bag")
		if session.bag >= bagMax then
			say(session, "가방이 가득 찼어요. 연구실 수거함에 부품을 넣으세요.")
		else
			session.bag = math.min(bagMax, session.bag + pile.value)
			session.piles[arg] = nil
			table.insert(session.respawns, { zone = pile.zone, at = now + Config.PileRespawn })
		end
	elseif action == "PickUp" then
		local signal = session.signal
		if not signal or session.carrying or not rootNear(player, signal.point.Position, Config.PickUpRange) then
			return
		end
		session.carrying = signal.robotId
		session.signal = nil
		session.data.tutorialDone = true
		local robot = Config.getRobot(signal.robotId)
		local rarity = robot and Config.Rarities[robot.rarity]
		say(session, ("%s 로봇 %s을(를) 찾았어요! 연구실 수리대로 가져가세요."):format(rarity and rarity.name or "", robot and robot.name or ""))
	else
		return
	end
	sendState(player, session)
end)

-- 1초마다: 수리 완료, 도우미 수입, 부품 더미·신호 재생성 ----------------------
local function completeRepairs(session: Session): boolean
	local now = os.time()
	local changed = false
	local remaining = {}
	for _, repair in session.data.repairs do
		if repair.finishAt <= now then
			changed = true
			local robot = Config.getRobot(repair.robotId)
			local name = robot and robot.name or repair.robotId
			local level = session.data.robots[repair.robotId] or 0
			if level == 0 then
				session.data.robots[repair.robotId] = 1
				say(session, ("%s 수리 완료! 도감에 등록하고 부품을 벌기 시작해요."):format(name))
			elseif level < Config.MaxRobotLevel then
				session.data.robots[repair.robotId] = level + 1
				say(session, ("%s 레벨 %d! 수입이 늘었어요."):format(name, level + 1))
			else
				-- 최고 레벨이면 수리비만큼 부품으로 돌려준다
				local refund = if robot then Config.Rarities[robot.rarity].repairCost else 0
				session.data.parts += refund
				say(session, ("%s은(는) 이미 최고 레벨이라 부품 %d개로 바꿨어요."):format(name, refund))
			end
		else
			table.insert(remaining, repair)
		end
	end
	session.data.repairs = remaining
	return changed
end

local function tick(player: Player, session: Session, dt: number)
	completeRepairs(session)

	local rate = incomeRate(session.data)
	if rate > 0 then
		session.data.storage = math.min(storageCap(session.data), session.data.storage + rate * dt / 60)
	end

	local now = os.clock()
	local waiting = {}
	for _, entry in session.respawns do
		if now >= entry.at and session.data.zones[entry.zone] then
			spawnPile(session, entry.zone)
		else
			table.insert(waiting, entry)
		end
	end
	session.respawns = waiting

	if not session.signal and not session.carrying and now >= session.signalAt then
		spawnSignal(session)
	end

	if session.active then
		sendState(player, session)
	end
end

local function onPlayerAdded(player: Player)
	local session: Session = {
		data = newData(),
		active = false,
		bag = 0,
		carrying = nil,
		signal = nil,
		signalAt = 0,
		piles = {},
		respawns = {},
		nextPileId = 0,
		message = "",
		lastPrompt = 0,
		actionCount = 0,
		actionWindow = 0,
	}
	for _, zone in Config.ZoneOrder do
		if session.data.zones[zone] then
			fillZone(session, zone)
		end
	end
	sessions[player] = session
	player.CharacterRemoving:Connect(function()
		-- 죽거나 캐릭터가 바뀌면 Respawn 스크립트가 오비 체크포인트로 보낸다
		if session.active then
			session.active = false
			sendState(player, session)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		local dt = now - last
		last = now
		for player, session in sessions do
			tick(player, session, dt)
		end
	end
end)
