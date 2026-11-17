--!strict
-- Junkyard: 로봇 고물상 타이쿤 서버 로직 (멀티플레이). 모든 판정은 서버에서 한다.
-- 흐름:
--   벨트에서 로봇 구매(돈) → 머리 위에 들고 내 기지로 → 빈 받침대에 자동 배치 → 초당 수입이 금고에 쌓임
--   → 금고를 밟아 돈 받기 → 더 비싼 로봇 구매 → 도감 등급 세트 완성 시 수입 배수·칭호
-- 멀티플레이:
--   다른 사람 기지의 로봇을 "훔치기"(1.5초 누르기) → 들고 내 기지로 가면 내 것. 주인이 가까이 오면 떨어뜨려 되돌아간다.
--   기지 주인은 방어막(60초, 쿨타임 60초)으로 막을 수 있다. 잠긴 기지 안의 다른 사람은 밖으로 밀려난다.
-- 화면 표시는 클라이언트(JunkyardHud), 숫자는 ReplicatedStorage/Modules/JunkyardConfig.
-- 저장: JunkyardSave(돈·도감·받침대 로봇). 나가면 기지는 비워지지만 다시 들어오면 그대로 채워진다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local Belt = require(script.Parent:WaitForChild("JunkyardBelt"))
local JunkyardSave = require(script.Parent:WaitForChild("JunkyardSave"))
local JunkyardStore = require(script.Parent:WaitForChild("JunkyardStore"))
local JunkyardRanking = require(script.Parent:WaitForChild("JunkyardRanking"))
local JunkyardContest = require(script.Parent:WaitForChild("JunkyardContest"))

local junkyard = workspace:WaitForChild("Junkyard")
local basesFolder = junkyard:WaitForChild("Bases")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local beltRemote = remotes:WaitForChild("JunkyardBelt") :: RemoteEvent
local actionRemote = remotes:WaitForChild("JunkyardAction") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("JunkyardNotify") :: RemoteEvent

type Base = {
	model: Model,
	index: number,
	front: number, -- 벨트 쪽 방향 (+1 또는 −1, Z축)
	center: Vector3,
	pads: { BasePart },
	robots: { [number]: string }, -- 받침대 번호 → 로봇 id
	padModels: { [number]: Model },
	reserved: { [number]: boolean }, -- 도둑이 들고 가는 중인 자리 (되돌아올 수 있게 비워 둠)
	owner: Player?,
	vault: number,
	lockedUntil: number, -- 서버 시간(GetServerTimeNow) 기준
	lockCooldownUntil: number,
	intruders: { [Player]: boolean }, -- 지금 기지 안에 있는 다른 사람 (경보기·울타리용)
	alarmAt: { [Player]: number }, -- 침입자별 마지막 경보 시각
}
type Carry = {
	robotId: string,
	fromBase: Base?, -- 있으면 훔친 로봇
	fromPad: number?,
	model: Model?,
}
type State = {
	player: Player,
	money: number,
	base: Base?,
	carry: Carry?,
	catalog: { [string]: boolean },
	variantCatalog: { [string]: boolean }, -- 모은 변종 ("Pippi@Gold" 등, 저장됨)
	rebirth: number, -- 환생 단계 (저장됨)
	rebirthValue: IntValue?, -- 리더보드 "환생"
	multiplier: number,
	moneyValue: IntValue?,
	incomeValue: IntValue?,
	lastFullNotice: number,
	lastAction: number,
	loading: boolean, -- 저장된 데이터를 불러오는 중 (구매·훔치기 잠시 막음)
	upgrades: { [string]: number }, -- 영구 업그레이드 단계 (저장됨)
	stunnedUntil: number, -- EMP에 맞아 못 움직이는 시각까지 (서버 시간)
	slowedUntil: number, -- 레이저 울타리로 느려진 시각까지
	glovesUntil: number, -- 도둑 장갑 효과 끝나는 시각
	empReadyAt: number, -- EMP 다시 쓸 수 있는 시각
	holdStart: { [ProximityPrompt]: number }, -- 받침대 버튼을 누르기 시작한 시각 (누르는 시간 검증)
	passes: { [string]: boolean }, -- 가진 게임패스 (접속할 때 확인)
	empCharges: number, -- Robux로 산 무료 EMP 남은 횟수 (저장됨)
	totalEarned: number, -- 로봇이 벌어 준 누적 수입 (저장됨, 환생해도 유지, 전체 서버 순위표)
	tutorial: number, -- 첫 접속 안내 단계 (1~5, 0 = 끝남, 저장됨)
}

local bases: { Base } = {}
local states: { [Player]: State } = {}

local FALL_Y = 30 -- 고물상 바닥(윗면 Y 40.5)보다 이만큼 아래로 떨어지면 기지로 돌려보낸다

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, kind: string, text: string)
	notifyRemote:FireClient(player, kind, text)
end

local function notifyAll(text: string)
	notifyRemote:FireAllClients("Global", text)
end

local function robotLabel(robotId: string): string
	local rarity = Config.rarityOf(robotId)
	return if rarity then ("%s %s"):format(rarity.name, Config.robotName(robotId)) else robotId
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function insideBase(base: Base, position: Vector3): boolean
	local offset = position - base.center
	return math.abs(offset.X) <= 22 and math.abs(offset.Z) <= 17 and offset.Y > -3 and offset.Y < 20
end

-- 로봇 모형 (회색 상자 몸통 + 머리, 등급 색과 크기) --------------------------------
local function makeRobotModel(robotId: string, anchored: boolean): Model
	local robot = Config.getRobot(robotId)
	local rarity = Config.rarityOf(robotId)
	local size = if rarity then rarity.size else 1
	local variant = Config.variantOf(robotId) -- 변종이면 변종 색과 반짝이
	local color = if variant then variant.color elseif rarity then rarity.color else Color3.new(1, 1, 1)
	local model = Instance.new("Model")
	model.Name = "Robot_" .. robotId
	local function piece(name: string, partSize: Vector3, offset: Vector3, pieceColor: Color3): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Size = partSize * size
		object.CFrame = CFrame.new(offset * size)
		object.Color = pieceColor
		object.Anchored = anchored
		object.CanCollide = false
		object.CanQuery = false
		object.CanTouch = false
		object.Massless = true
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = model
		return object
	end
	local body = piece("Body", Vector3.new(2.2, 2, 1.7), Vector3.new(0, 1, 0), color)
	piece("Head", Vector3.new(2.4, 1.5, 1.9), Vector3.new(0, 2.75, 0), color)
	for _, dx in { -0.5, 0.5 } do
		piece("Eye", Vector3.new(0.3, 0.3, 0.1), Vector3.new(dx, 2.85, -0.98), Color3.fromRGB(30, 34, 40))
	end
	model.PrimaryPart = body
	if variant then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = variant.color
		sparkles.Parent = body
	end
	if not anchored then
		for _, object in model:GetChildren() do
			if object ~= body and object:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = object
				weld.Parent = object
			end
		end
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(170, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.3 * size, 0)
	billboard.MaxDistance = 60
	billboard.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = color
	label.Text = if robot and rarity then ("%s [%s]\n초당 %s"):format(Config.robotName(robotId), rarity.name, Config.formatMoney(Config.robotIncome(robotId))) else robotId
	label.Parent = billboard
	return model
end

-- 업그레이드·속도 ----------------------------------------------------------------
local function upgradeValue(state: State, id: string): number
	return Config.upgradeValue(id, state.upgrades[id] or 0)
end

-- 이 기지에서 쓸 수 있는 받침대 수 (주인의 "받침대 추가" 단계)
local function padLimit(base: Base): number
	local owner = base.owner
	local state = owner and states[owner]
	return if state then upgradeValue(state, "Pads") else Config.PadsPerBase
end

-- 아직 열리지 않은 받침대는 어둡고 반투명하게
local function setPadLocks(base: Base)
	local limit = padLimit(base)
	for index, pad in base.pads do
		local locked = index > limit
		pad.Transparency = if locked then 0.7 else 0
		pad.Color = if locked then Color3.fromRGB(40, 44, 50) else Color3.fromRGB(70, 78, 88)
	end
end

-- 걷기 속도·점프: 기절(EMP) > 느려짐(울타리) > 운반 중 > 터보 신발
local function applySpeed(state: State)
	local character = state.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local t = workspace:GetServerTimeNow()
	local speed = upgradeValue(state, "Shoes")
	if t < state.stunnedUntil then
		speed = 0
	elseif t < state.slowedUntil then
		speed = Config.FenceSpeed
	elseif state.carry then
		speed = Config.CarrySpeed + (speed - 16) * 0.5 -- 신발 효과는 운반 중에 절반만
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = if t < state.stunnedUntil then 0 else 7.2
end

-- 클라이언트 표시용 속성
local function syncUpgradeAttributes(state: State)
	state.player:SetAttribute("Upgrades", HttpService:JSONEncode(state.upgrades))
	state.player:SetAttribute("GlovesUntil", state.glovesUntil)
	state.player:SetAttribute("EmpReadyAt", state.empReadyAt)
	state.player:SetAttribute("StunnedUntil", state.stunnedUntil)
end

-- 돈·수입 ---------------------------------------------------------------------
local function setMoney(state: State, value: number)
	state.money = math.max(0, math.floor(value))
	state.player:SetAttribute("Money", state.money)
	if state.moneyValue then
		state.moneyValue.Value = state.money
	end
end

local function baseIncome(base: Base, state: State?): number
	local total = 0
	for _, robotId in base.robots do
		total += Config.robotIncome(robotId) -- 변종이면 배수 포함
	end
	if not state then
		return total
	end
	-- 도감 배수 × 환생 배수 × 수입 2배 게임패스
	return total * state.multiplier * Config.rebirthMultiplier(state.rebirth)
		* (if state.passes.DoubleIncome then Config.IncomePassMultiplier else 1)
end

local function refreshIncome(state: State)
	local income = if state.base then baseIncome(state.base, state) else 0
	state.player:SetAttribute("Income", income)
	if state.incomeValue then
		state.incomeValue.Value = math.floor(income)
	end
end

-- 도감 ------------------------------------------------------------------------
local function applyTitle(state: State)
	local character = state.player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local _, best = Config.catalogMultiplier(state.catalog)
	local vip = state.passes.VipBase == true
	local contestTitle = state.player:GetAttribute("ContestTitle")
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not best and not vip and state.rebirth <= 0 and typeof(contestTitle) ~= "string" then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local newTag = Instance.new("BillboardGui")
		newTag.Name = "TitleTag"
		newTag.Size = UDim2.fromOffset(160, 24)
		newTag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		newTag.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextStrokeTransparency = 0.3
		label.Parent = newTag
		newTag.Parent = head
		tag = newTag
	end
	local rarity = if best then Config.Rarities[best] else nil
	local label = (tag :: BillboardGui):FindFirstChild("Label") :: TextLabel
	local words = {}
	if typeof(contestTitle) == "string" then
		table.insert(words, contestTitle)
	end
	if state.rebirth > 0 then
		table.insert(words, Config.rebirthMark(state.rebirth))
	end
	if vip then
		table.insert(words, "[👑 VIP]")
	end
	if rarity then
		table.insert(words, ("[%s 수집가]"):format(rarity.name))
	end
	label.Text = table.concat(words, " ")
	label.TextColor3 = if rarity then rarity.color else Color3.fromRGB(255, 215, 90)
end

-- 도감 배수 = 기본 도감 세트 보너스 + 변종 도감 페이지 보너스
local function recomputeMultiplier(state: State)
	state.multiplier = Config.catalogMultiplier(state.catalog) + Config.variantPageBonus(state.variantCatalog)
	state.player:SetAttribute("Multiplier", state.multiplier)
	local keys = {}
	for key in state.variantCatalog do
		table.insert(keys, key)
	end
	state.player:SetAttribute("VariantCatalog", HttpService:JSONEncode(keys))
end

local function addToCatalog(state: State, robotKey: string)
	-- 변종이면 변종 도감에 먼저 등록하고, 기본 로봇도 아래에서 함께 등록한다
	local robotId, variantId = Config.splitKey(robotKey)
	if variantId and not state.variantCatalog[robotKey] then
		local beforeBonus = Config.variantPageBonus(state.variantCatalog)
		state.variantCatalog[robotKey] = true
		notify(state.player, "Info", ("변종 도감 등록: %s"):format(robotLabel(robotKey)))
		if Config.variantPageBonus(state.variantCatalog) > beforeBonus then
			notifyAll(("%s님이 %s 변종 도감을 완성했어요!"):format(state.player.DisplayName, Config.Variants[variantId].name))
		end
		recomputeMultiplier(state)
		refreshIncome(state)
	end
	if state.catalog[robotId] then
		return
	end
	local before, beforeBest = Config.catalogMultiplier(state.catalog)
	state.catalog[robotId] = true
	local after, best = Config.catalogMultiplier(state.catalog)
	local ids = {}
	for id in state.catalog do
		table.insert(ids, id)
	end
	state.player:SetAttribute("Catalog", HttpService:JSONEncode(ids))
	recomputeMultiplier(state)
	notify(state.player, "Info", ("도감 등록: %s"):format(robotLabel(robotId)))
	if after > before then
		local completed = if best and best ~= beforeBest then Config.Rarities[best].name else "등급"
		notify(state.player, "Info", ("%s 세트 완성! 수입 x%.2f"):format(completed, after))
		notifyAll(("%s님이 %s 로봇 도감을 완성했어요!"):format(state.player.DisplayName, completed))
		applyTitle(state)
	end
	refreshIncome(state)
end

-- 받침대 ----------------------------------------------------------------------
local function setPadRobot(base: Base, padIndex: number, robotId: string?)
	local oldModel = base.padModels[padIndex]
	if oldModel then
		oldModel:Destroy()
		base.padModels[padIndex] = nil
	end
	local pad = base.pads[padIndex]
	local prompt = pad:FindFirstChild("RobotPrompt") :: ProximityPrompt
	base.robots[padIndex] = robotId
	if robotId then
		local model = makeRobotModel(robotId, true)
		-- 몸통 중심 = 받침대 윗면 + 몸통 절반 높이. 얼굴은 벨트 쪽을 본다
		local rarity = Config.rarityOf(robotId)
		local position = pad.Position + Vector3.new(0, 0.2 + (if rarity then rarity.size else 1), 0)
		model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, base.front)))
		model.Parent = base.model
		base.padModels[padIndex] = model
		local robot = Config.getRobot(robotId)
		prompt.ObjectText = if robot then Config.robotName(robotId) else robotId
		pad:SetAttribute("RobotKey", robotId) -- 클라이언트가 판매 가격을 계산할 때 쓴다
		prompt.Enabled = true
	else
		prompt.Enabled = false
		pad:SetAttribute("RobotKey", nil)
	end
end

local function freePad(base: Base): number?
	for index = 1, math.min(#base.pads, padLimit(base)) do
		if not base.robots[index] and not base.reserved[index] then
			return index
		end
	end
	return nil
end

-- 들고 다니기 -------------------------------------------------------------------
local function attachCarryModel(state: State)
	local carry = state.carry
	local root = rootOf(state.player)
	if not carry or not root then
		return
	end
	if carry.model then
		carry.model:Destroy()
	end
	local model = makeRobotModel(carry.robotId, false)
	local rarity = Config.rarityOf(carry.robotId)
	model:PivotTo(root.CFrame * CFrame.new(0, 2.2 + (if rarity then rarity.size else 1), 0)) -- 머리 위로 들기
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = state.player.Character
	carry.model = model
	applySpeed(state)
end

local function syncCarryAttributes(state: State)
	local carry = state.carry
	state.player:SetAttribute("Carrying", if carry then carry.robotId else "")
	state.player:SetAttribute("CarryStolen", carry ~= nil and carry.fromBase ~= nil)
end

local function startCarry(state: State, robotId: string, fromBase: Base?, fromPad: number?)
	state.carry = { robotId = robotId, fromBase = fromBase, fromPad = fromPad, model = nil }
	attachCarryModel(state)
	syncCarryAttributes(state)
end

local function endCarry(state: State)
	local carry = state.carry
	if carry and carry.model then
		carry.model:Destroy()
	end
	state.carry = nil
	applySpeed(state)
	syncCarryAttributes(state)
end

-- 훔친 로봇을 원래 주인 받침대로 돌려보낸다
local function returnStolen(state: State, reason: string)
	local carry = state.carry
	if not carry or not carry.fromBase or not carry.fromPad then
		return
	end
	local base = carry.fromBase
	base.reserved[carry.fromPad] = nil
	setPadRobot(base, carry.fromPad, carry.robotId)
	endCarry(state)
	if base.owner and states[base.owner] then
		refreshIncome(states[base.owner])
		notify(base.owner, "Info", ("%s을(를) 되찾았어요! (%s)"):format(robotLabel(carry.robotId), reason))
	end
	notify(state.player, "Alert", ("훔친 로봇을 놓쳤어요. (%s)"):format(reason))
end

-- 기지 배정·해제 ------------------------------------------------------------------
local function setSign(base: Base, text: string)
	-- 이름판은 뒷벽(Wall 중 Sign이 붙은 것)에 있다
	for _, child in base.model:GetChildren() do
		local sign = child.Name == "Wall" and child:FindFirstChild("Sign")
		local label = sign and sign:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

local function assignBase(state: State): Base?
	for _, base in bases do
		if not base.owner then
			base.owner = state.player
			base.vault = 0
			base.model:SetAttribute("OwnerUserId", state.player.UserId)
			base.model:SetAttribute("OwnerName", state.player.DisplayName)
			base.model:SetAttribute("Vault", 0)
			setSign(base, state.player.DisplayName .. "의 기지")
			state.base = base
			state.player:SetAttribute("BaseIndex", base.index)
			setPadLocks(base)
			return base
		end
	end
	return nil
end

local function releaseBase(base: Base)
	-- 이 기지에서 훔쳐 가던 로봇은 도둑 것이 된다 (주인이 없으므로)
	for _, other in states do
		if other.carry and other.carry.fromBase == base then
			other.carry.fromBase = nil
			other.carry.fromPad = nil
			syncCarryAttributes(other)
		end
	end
	for index = 1, #base.pads do
		setPadRobot(base, index, nil)
	end
	base.reserved = {}
	base.owner = nil
	base.vault = 0
	base.lockedUntil = 0
	base.lockCooldownUntil = 0
	base.model:SetAttribute("OwnerUserId", 0)
	base.model:SetAttribute("OwnerName", "")
	base.model:SetAttribute("Vault", 0)
	base.model:SetAttribute("LockedUntil", 0)
	base.intruders = {}
	base.alarmAt = {}
	setSign(base, "빈 기지")
	setPadLocks(base)
end

local function spawnCFrame(base: Base): CFrame
	local spawn = base.model:FindFirstChild("Spawn") :: BasePart
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

-- 저장할 값 모으기 ------------------------------------------------------------------
-- 금고에 남은 돈은 돈에 합친다. 들고 있던 산 로봇은 빈 받침대에 넣고, 자리가 없으면 산 값을 돌려준다.
-- 도둑이 들고 가는 중인 자리(예약석)는 넣지 않는다 (주인이 나가면 도둑 것이 되므로 중복 방지).
local function snapshot(state: State): JunkyardSave.Data
	local money = state.money
	local pads: { [string]: string } = {}
	local base = state.base
	if base then
		money += math.floor(base.vault)
		for index, robotId in base.robots do
			pads[tostring(index)] = robotId
		end
	end
	local carry = state.carry
	if carry and not carry.fromBase then
		local placed = false
		if base then
			for index = 1, #base.pads do
				if not base.robots[index] and not base.reserved[index] and not pads[tostring(index)] then
					pads[tostring(index)] = carry.robotId
					placed = true
					break
				end
			end
		end
		if not placed then
			money += Config.robotValue(carry.robotId)
		end
	end
	return { money = money, catalog = table.clone(state.catalog), pads = pads, upgrades = table.clone(state.upgrades), empCharges = state.empCharges, rebirth = state.rebirth, variantCatalog = table.clone(state.variantCatalog), totalEarned = math.floor(state.totalEarned), tutorial = state.tutorial }
end

-- 첫 접속 안내 (튜토리얼) ------------------------------------------------------------
-- 단계: 1 벨트에서 사기 → 2 받침대에 놓기 → 3 금고 받기(보상) → 4 상점 열기 → 5 도감 열기. 0 = 끝남(저장됨)
-- 1~3단계는 서버가 실제 행동을 보고 넘긴다. 4~5단계는 화면을 연 것이라 클라이언트가 알려 주고, 보상은 없다.
local TUTORIAL_STEPS = { "Buy", "Place", "Collect", "Shop", "Catalog" }
local TUTORIAL_REWARD = 100 -- 3단계(첫 금고 받기) 보상. 단계는 앞으로만 가고 저장되므로 한 번만 받는다

local function setTutorial(state: State, step: number)
	state.tutorial = step
	state.player:SetAttribute("TutorialStep", step)
end

local function advanceTutorial(state: State, stepName: string)
	if state.tutorial == 0 or TUTORIAL_STEPS[state.tutorial] ~= stepName then
		return
	end
	if stepName == "Collect" then
		setMoney(state, state.money + TUTORIAL_REWARD)
		notify(state.player, "Money", ("🎉 첫 수입 성공! 안내 보상 +%s"):format(Config.formatMoney(TUTORIAL_REWARD)))
	end
	local nextStep = state.tutorial + 1
	if nextStep > #TUTORIAL_STEPS then
		nextStep = 0
		notify(state.player, "Info", "안내 끝! 로봇을 모으고, 지키고, 훔쳐서 순위판에 이름을 올려 보세요.")
	end
	setTutorial(state, nextStep)
	if stepName == "Collect" or nextStep == 0 then
		JunkyardSave.saveNow(state.player) -- 보상을 받은 단계는 바로 저장 (다시 받지 않게)
	end
end

-- 행동 ----------------------------------------------------------------------------
local function buy(state: State, itemId: number)
	if state.loading then
		notify(state.player, "Alert", "저장된 기지를 불러오는 중이에요. 잠시만요!")
		return
	end
	if state.carry then
		notify(state.player, "Alert", "이미 로봇을 들고 있어요. 먼저 기지에 두세요.")
		return
	end
	if not state.base then
		notify(state.player, "Alert", "기지가 없어서 살 수 없어요. (서버의 기지가 모두 찼어요)")
		return
	end
	local item = Belt.get(itemId)
	local root = rootOf(state.player)
	if not item then
		notify(state.player, "Alert", "놓쳤어요! 이미 팔렸거나 벨트에서 사라졌어요.")
		return
	end
	if not root then
		return
	end
	if (Belt.position(item, now()) - root.Position).Magnitude > Config.BeltBuyRange then
		return
	end
	local rarity = Config.rarityOf(item.robotId)
	if not rarity then
		return
	end
	if state.money < rarity.price then
		notify(state.player, "Alert", ("돈이 %s 부족해요."):format(Config.formatMoney(rarity.price - state.money)))
		return
	end
	if not Belt.take(itemId) then
		notify(state.player, "Alert", "아쉬워요! 다른 사람이 먼저 샀어요.")
		return
	end
	setMoney(state, state.money - rarity.price)
	-- 환생한 사람은 살 때 변종(금색·다이아·무지개)이 나올 수 있다. 벨트에 보이는 로봇은 모두에게 같다
	local variantId = Config.rollVariant(state.rebirth)
	local robotKey = if variantId then item.robotId .. "@" .. variantId else item.robotId
	startCarry(state, robotKey, nil, nil)
	if variantId then
		notify(state.player, "Info", ("%s 변종이 나왔어요! %s"):format(Config.Variants[variantId].mark, robotLabel(robotKey)))
	end
	notify(state.player, "Info", ("%s 구매! 기지로 가져가세요."):format(robotLabel(item.robotId)))
	advanceTutorial(state, "Buy")
	local robot = Config.getRobot(item.robotId)
	if robot then
		JunkyardContest.record(state.player, "Collect", Config.Contest.RarityPoints[robot.rarity])
	end
end

-- 방어막 시간·충전 시간 (방어막 강화 단계 + VIP 게임패스)
local function shieldDuration(state: State): number
	return upgradeValue(state, "ShieldTime") + (if state.passes.VipBase then Config.VipShieldBonus else 0)
end

local function shieldCooldown(state: State): number
	return Config.LockCooldown * (if state.passes.VipBase then Config.VipCooldownRate else 1)
end

-- 방어막을 untilTime(서버 시간)까지 켠다
local function setShield(state: State, base: Base, untilTime: number)
	base.lockedUntil = untilTime
	base.lockCooldownUntil = untilTime + shieldCooldown(state)
	base.model:SetAttribute("LockedUntil", base.lockedUntil)
	state.player:SetAttribute("LockedUntil", base.lockedUntil)
	state.player:SetAttribute("LockCooldownUntil", base.lockCooldownUntil)
	local shield = base.model:FindFirstChild("Shield") :: BasePart
	shield.Transparency = 0.5
end

local function lockBase(state: State)
	local base = state.base
	if not base then
		return
	end
	local t = now()
	if t < base.lockedUntil then
		notify(state.player, "Info", "이미 방어막이 켜져 있어요.")
		return
	end
	if t < base.lockCooldownUntil then
		notify(state.player, "Alert", ("방어막 충전 중이에요. %d초 뒤에 다시 쓸 수 있어요."):format(math.ceil(base.lockCooldownUntil - t)))
		return
	end
	local duration = shieldDuration(state) -- 방어막 강화 단계(60~150초) + VIP 30초
	setShield(state, base, t + duration)
	notify(state.player, "Info", ("방어막 작동! %d초 동안 아무도 훔칠 수 없어요."):format(duration))
end

local function sell(state: State, base: Base, padIndex: number)
	local robotId = base.robots[padIndex]
	local rarity = robotId and Config.rarityOf(robotId)
	if not robotId or not rarity then
		return
	end
	setPadRobot(base, padIndex, nil)
	local gain = math.floor(Config.robotValue(robotId) * Config.SellRate)
	setMoney(state, state.money + gain)
	refreshIncome(state)
	notify(state.player, "Info", ("%s 판매 +%s"):format(robotLabel(robotId), Config.formatMoney(gain)))
end

local function steal(state: State, base: Base, padIndex: number)
	local robotId = base.robots[padIndex]
	if not robotId or not base.owner or base.owner == state.player then
		return
	end
	if not state.base or state.loading then
		notify(state.player, "Alert", "기지가 준비되지 않아 훔칠 수 없어요.")
		return
	end
	if state.carry then
		notify(state.player, "Alert", "이미 로봇을 들고 있어요.")
		return
	end
	-- 초보 보호: 환생 단계가 ProtectionGap 이상 낮은 사람의 로봇은 훔칠 수 없다
	local victim = states[base.owner]
	if victim and state.rebirth - victim.rebirth >= Config.ProtectionGap then
		notify(state.player, "Alert", ("초보 보호: 환생 단계가 %d 이상 낮은 사람의 로봇은 훔칠 수 없어요."):format(Config.ProtectionGap))
		return
	end
	if now() < base.lockedUntil then
		notify(state.player, "Alert", "방어막이 켜진 기지예요.")
		return
	end
	setPadRobot(base, padIndex, nil)
	base.reserved[padIndex] = true
	startCarry(state, robotId, base, padIndex)
	if states[base.owner] then
		refreshIncome(states[base.owner])
	end
	notify(state.player, "Info", ("%s을(를) 훔쳤어요! 주인에게 잡히기 전에 내 기지로!"):format(robotLabel(robotId)))
	notify(base.owner, "Alert", ("⚠ %s님이 내 %s을(를) 훔쳐 가요! 쫓아가서 붙잡으세요!"):format(state.player.DisplayName, robotLabel(robotId)))
end

-- 상점 ------------------------------------------------------------------------
local function buyUpgrade(state: State, id: string)
	local upgrade = Config.Upgrades[id]
	if not upgrade or state.loading then
		return
	end
	local level = state.upgrades[id] or 0
	local cost = Config.upgradeCost(id, level)
	if not cost then
		notify(state.player, "Info", upgrade.name .. "은(는) 최고 단계예요.")
		return
	end
	if state.money < cost then
		notify(state.player, "Alert", ("%s: 돈이 %s 부족해요."):format(upgrade.name, Config.formatMoney(cost - state.money)))
		return
	end
	setMoney(state, state.money - cost)
	state.upgrades[id] = level + 1
	syncUpgradeAttributes(state)
	if id == "Pads" and state.base then
		setPadLocks(state.base)
	elseif id == "Shoes" then
		applySpeed(state)
	end
	notify(state.player, "Info", ("%s %d단계 완료!"):format(upgrade.name, level + 1))
end

-- EMP가 터지는 모습 (잠깐 보이는 빛나는 구)
local function empBurst(position: Vector3)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * (Config.EmpRange * 2)
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.fromRGB(120, 200, 255)
	sphere.Transparency = 0.6
	sphere.Parent = workspace
	Debris:AddItem(sphere, 0.4)
end

local function useItem(state: State, id: string)
	local item = Config.Items[id]
	if not item or state.loading or state.player:GetAttribute("Mode") ~= "Junkyard" then
		return
	end
	local t = now()
	if id == "EMP" and t < state.empReadyAt then
		notify(state.player, "Alert", ("EMP 충전 중이에요. %d초 남았어요."):format(math.ceil(state.empReadyAt - t)))
		return
	end
	if id == "Gloves" and t < state.glovesUntil then
		notify(state.player, "Info", "이미 도둑 장갑을 끼고 있어요.")
		return
	end
	local root = rootOf(state.player)
	if not root then
		return
	end
	-- Robux로 산 무료 EMP가 있으면 돈 대신 그것을 쓴다
	local free = id == "EMP" and state.empCharges > 0
	local price = if free then 0 else Config.itemPrice(id, (state.player:GetAttribute("Income") or 0) :: number)
	if state.money < price then
		notify(state.player, "Alert", ("%s: 돈이 %s 부족해요."):format(item.name, Config.formatMoney(price - state.money)))
		return
	end
	if free then
		state.empCharges -= 1
		state.player:SetAttribute("EmpCharges", state.empCharges)
	else
		setMoney(state, state.money - price)
	end
	if id == "EMP" then
		state.empReadyAt = t + Config.EmpCooldown
		empBurst(root.Position)
		local hit = 0
		for other, otherState in states do
			local otherRoot = rootOf(other)
			if other ~= state.player and otherRoot and other:GetAttribute("Mode") == "Junkyard"
				and (otherRoot.Position - root.Position).Magnitude <= Config.EmpRange then
				hit += 1
				otherState.stunnedUntil = t + Config.EmpStun
				applySpeed(otherState)
				syncUpgradeAttributes(otherState)
				if otherState.carry and otherState.carry.fromBase then
					returnStolen(otherState, "EMP에 맞음")
				end
				notify(other, "Alert", ("⚡ %s님의 EMP에 맞았어요! %d초 동안 못 움직여요."):format(state.player.DisplayName, Config.EmpStun))
			end
		end
		notify(state.player, "Info", ("⚡ EMP 발사! %d명을 멈췄어요."):format(hit))
	else
		state.glovesUntil = t + Config.GlovesDuration
		notify(state.player, "Info", ("🧤 도둑 장갑 착용! %d분 동안 훔치기가 빨라져요."):format(Config.GlovesDuration // 60))
	end
	syncUpgradeAttributes(state)
end

-- 환생 ------------------------------------------------------------------------
local function syncRebirth(state: State)
	state.player:SetAttribute("Rebirth", state.rebirth)
	if state.rebirthValue then
		state.rebirthValue.Value = state.rebirth
	end
end

local function hasRequiredRarity(state: State): boolean
	for _, robot in Config.Robots do
		if robot.rarity == Config.RebirthRequiresRarity and state.catalog[robot.id] then
			return true
		end
	end
	return false
end

-- 환생: 돈·받침대 로봇·금고·업그레이드는 처음으로. 도감·변종 도감·무료 EMP·Robux 혜택은 유지
local function rebirth(state: State)
	local base = state.base
	if not base or state.loading then
		return
	end
	if state.carry then
		notify(state.player, "Alert", "들고 있는 로봇을 먼저 기지에 놓고 환생하세요.")
		return
	end
	local cost = Config.rebirthCost(state.rebirth)
	if state.money < cost then
		notify(state.player, "Alert", ("환생하려면 돈이 %s 더 필요해요."):format(Config.formatMoney(cost - state.money)))
		return
	end
	if not hasRequiredRarity(state) then
		notify(state.player, "Alert", ("환생하려면 도감에 %s 로봇이 1종 이상 있어야 해요."):format(Config.Rarities[Config.RebirthRequiresRarity].name))
		return
	end
	for index = 1, #base.pads do
		if base.robots[index] then
			setPadRobot(base, index, nil)
		end
	end
	base.vault = 0
	base.model:SetAttribute("Vault", 0)
	for _, id in Config.UpgradeOrder do
		state.upgrades[id] = 0
	end
	syncUpgradeAttributes(state)
	setPadLocks(base)
	applySpeed(state)
	setMoney(state, Config.StartMoney)
	state.rebirth += 1
	syncRebirth(state)
	refreshIncome(state)
	applyTitle(state)
	local unlock = ""
	for _, variantId in Config.VariantOrder do
		local variant = Config.Variants[variantId]
		if variant.minRebirth == state.rebirth then
			unlock = (" 이제 %s %s 변종이 나와요!"):format(variant.mark, variant.name)
		end
	end
	notifyAll(("⭐ %s님이 %d번째 환생을 했어요!"):format(state.player.DisplayName, state.rebirth))
	notify(state.player, "Info", ("환생 완료! 수입 x%.1f.%s"):format(Config.rebirthMultiplier(state.rebirth), unlock))
	JunkyardSave.saveNow(state.player)
end

-- 들고 있는 로봇이 내 기지 안에 들어오면 빈 받침대에 놓는다
local function tryPlace(state: State)
	local carry = state.carry
	local base = state.base
	local root = rootOf(state.player)
	if not carry or not base or not root or not insideBase(base, root.Position) then
		return
	end
	local padIndex = freePad(base)
	if not padIndex then
		if os.clock() - state.lastFullNotice > 4 then
			state.lastFullNotice = os.clock()
			notify(state.player, "Alert", "받침대가 꽉 찼어요. 로봇을 팔아 자리를 만드세요.")
		end
		return
	end
	local robotId = carry.robotId
	local victimBase = carry.fromBase
	if victimBase and carry.fromPad then
		victimBase.reserved[carry.fromPad] = nil
		if victimBase.owner then
			notify(victimBase.owner, "Alert", ("%s님이 내 %s을(를) 가져가 버렸어요."):format(state.player.DisplayName, robotLabel(robotId)))
		end
	end
	endCarry(state)
	setPadRobot(base, padIndex, robotId)
	addToCatalog(state, robotId)
	refreshIncome(state)
	notify(state.player, "Info", ("%s을(를) 받침대에 놓았어요."):format(robotLabel(robotId)))
	advanceTutorial(state, "Place")
end

-- 연결 ----------------------------------------------------------------------------
for _, model in basesFolder:GetChildren() do
	if not model:IsA("Model") then
		continue
	end
	local padsFolder = model:FindFirstChild("Pads")
	local pads: { BasePart } = {}
	for _, pad in (padsFolder :: Folder):GetChildren() do
		if pad:IsA("BasePart") then
			pads[pad:GetAttribute("PadIndex") :: number] = pad
		end
	end
	local base: Base = {
		model = model,
		index = model:GetAttribute("Index") :: number,
		front = model:GetAttribute("Front") :: number,
		center = model:GetAttribute("Center") :: Vector3,
		pads = pads,
		robots = {},
		padModels = {},
		reserved = {},
		owner = nil,
		vault = 0,
		lockedUntil = 0,
		lockCooldownUntil = 0,
		intruders = {},
		alarmAt = {},
	}
	bases[base.index] = base

	for padIndex, pad in pads do
		local prompt = pad:FindFirstChild("RobotPrompt") :: ProximityPrompt
		prompt.HoldDuration = Config.StealHold
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			local state = states[player]
			if state then
				state.holdStart[prompt] = os.clock()
			end
		end)
		prompt.Triggered:Connect(function(player: Player)
			local state = states[player]
			local root = rootOf(player)
			if not state or not root or (root.Position - pad.Position).Magnitude > prompt.MaxActivationDistance + 3 then
				return
			end
			-- 실제로 누르고 있었는지 확인 (도둑 장갑이면 짧게). 누르지 않고 바로 보낸 요청은 무시
			local began = state.holdStart[prompt]
			state.holdStart[prompt] = nil
			local required = if base.owner ~= player and now() < state.glovesUntil then Config.GlovesHold else Config.StealHold
			if not began or os.clock() - began < required - 0.25 then
				return
			end
			if base.owner == player then
				sell(state, base, padIndex)
			else
				steal(state, base, padIndex)
			end
		end)
	end
	local lockPrompt = (model:FindFirstChild("LockButton") :: BasePart):FindFirstChild("LockPrompt") :: ProximityPrompt
	lockPrompt.Triggered:Connect(function(player: Player)
		local state = states[player]
		if state and base.owner == player then
			lockBase(state)
		end
	end)
	local vault = model:FindFirstChild("Vault") :: BasePart
	vault.Touched:Connect(function(hit: BasePart)
		local owner = base.owner
		if not owner or not owner.Character or not hit:IsDescendantOf(owner.Character) or base.vault < 1 then
			return
		end
		local state = states[owner]
		if not state then
			return
		end
		local amount = math.floor(base.vault)
		base.vault -= amount
		base.model:SetAttribute("Vault", math.floor(base.vault))
		setMoney(state, state.money + amount)
		notify(owner, "Money", "+" .. Config.formatMoney(amount))
		advanceTutorial(state, "Collect")
	end)
end

actionRemote.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
	local state = states[player]
	if not state or typeof(action) ~= "string" or os.clock() - state.lastAction < 0.15 then
		return
	end
	state.lastAction = os.clock()
	if action == "Buy" and typeof(arg) == "number" then
		buy(state, arg)
	elseif action == "Lock" then
		lockBase(state)
	elseif action == "Upgrade" and typeof(arg) == "string" then
		buyUpgrade(state, arg)
	elseif action == "Item" and typeof(arg) == "string" then
		useItem(state, arg)
	elseif action == "Rebirth" then
		rebirth(state)
	elseif action == "Tutorial" and (arg == "Shop" or arg == "Catalog") then
		advanceTutorial(state, arg :: string) -- 화면을 연 단계만 (보상 없음, 순서가 맞을 때만)
	elseif action == "TutorialSkip" and state.tutorial ~= 0 then
		setTutorial(state, 0)
		JunkyardSave.saveNow(state.player)
	end
end)

Belt.start(beltRemote, function(robotId: string)
	notifyAll(("✨ %s 로봇이 컨베이어에 나타났어요!"):format(robotLabel(robotId)))
end)
JunkyardSave.start()

-- 전체 서버 순위표: 저장을 불러온 플레이어만 점수를 올린다 (불러오기 실패·기지 없음은 제외)
do
	local rankings = workspace:FindFirstChild("Junkyard") and workspace.Junkyard:FindFirstChild("Rankings")
	local boardParts: { [string]: BasePart } = {}
	if rankings then
		for id, name in { Rebirth = "RebirthBoard", Earned = "EarnedBoard" } do
			local part = rankings:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				boardParts[id] = part
			end
		end
	end
	JunkyardRanking.start(boardParts, function()
		local scores: { [Player]: JunkyardRanking.Scores } = {}
		for player, state in states do
			if not state.loading and player:GetAttribute("SaveOff") == false then
				scores[player] = { rebirth = state.rebirth, earned = state.totalEarned }
			end
		end
		return scores
	end)
end

-- Robux 상품 (3-2) -------------------------------------------------------------
local function syncPasses(state: State)
	local owned = {}
	for key in state.passes do
		table.insert(owned, key)
	end
	state.player:SetAttribute("Passes", HttpService:JSONEncode(owned))
	state.player:SetAttribute("EmpCharges", state.empCharges)
end

JunkyardContest.start({
	getPlayers = function()
		local participants = {}
		for player, state in states do
			if state.base and not state.loading and player:GetAttribute("SaveOff") == false then
				table.insert(participants, player)
			end
		end
		return participants
	end,
	incomeOf = function(player)
		local state = states[player]
		return if state.base then baseIncome(state.base, state) else 0
	end,
	grant = function(player, rank, money)
		local state = states[player]
		if not state then
			return
		end
		if money > 0 then
			setMoney(state, state.money + money)
		end
		if rank == 1 then
			state.empCharges += 1
			syncPasses(state)
		end
		if money > 0 or rank == 1 then
			JunkyardSave.saveNow(player)
		end
		local reward = ("대회 %d위 · 보상 %s 돈"):format(rank, Config.formatMoney(money))
		notify(player, "Info", if rank == 1 then reward .. " + 무료 EMP 1개" else reward)
	end,
	setTitle = function(player, title)
		local state = states[player]
		if state then
			player:SetAttribute("ContestTitle", title)
			applyTitle(state)
		end
	end,
	notifyAll = notifyAll,
})

-- 희귀 로봇 비 확정 선물: 희귀 이상 등급 중에서 원래 가중치 비율로 뽑는다 (확률은 상점에 공개)
local function rollRainGift(): string
	local total = 0
	for _, id in Config.RarityOrder do
		if Config.RainRarities[id] then
			total += Config.Rarities[id].weight
		end
	end
	local roll = math.random() * total
	local rarity = "Rare"
	for _, id in Config.RarityOrder do
		if Config.RainRarities[id] then
			roll -= Config.Rarities[id].weight
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

-- 개발자 상품 지급 (JunkyardStore가 영수증 중복을 막은 뒤 부른다). 지급하면 true
local function grantProduct(player: Player, key: string): boolean
	local state = states[player]
	if not state or state.loading then
		return false -- 준비가 끝나면 Roblox가 영수증을 다시 보낸다
	end
	if key == "EmpPack" then
		state.empCharges += Config.EmpPackCharges
		notify(player, "Info", ("⚡ 무료 EMP %d개를 받았어요! (남은 %d개)"):format(Config.EmpPackCharges, state.empCharges))
	elseif key == "InstantShield" then
		local base = state.base
		if not base then
			return false
		end
		local t = now()
		setShield(state, base, math.max(base.lockedUntil, t) + shieldDuration(state)) -- 켜져 있으면 이어 붙인다
		notify(player, "Info", ("🛡 즉시 방어막! %d초 동안 아무도 훔칠 수 없어요."):format(math.ceil(base.lockedUntil - t)))
	elseif key == "RareRain" then
		local untilTime = Belt.startRain(Config.RainDuration)
		workspace:SetAttribute("RainUntil", untilTime)
		notifyAll(("✨ %s님이 희귀 로봇 비를 내렸어요! %d초 동안 모두의 벨트에 희귀 로봇이 %d배!"):format(player.DisplayName, Config.RainDuration, Config.RainMultiplier))
		-- 산 사람에게는 희귀 이상 로봇 1개를 바로 기지에 준다. 받침대가 꽉 차면 그 로봇 가격만큼 돈으로 준다
		local giftBase = rollRainGift()
		local giftVariant = Config.rollVariant(state.rebirth) -- 환생했으면 선물도 변종일 수 있다
		local giftId = if giftVariant then giftBase .. "@" .. giftVariant else giftBase
		local base = state.base
		local padIndex = if base then freePad(base) else nil
		if base and padIndex then
			setPadRobot(base, padIndex, giftId)
			addToCatalog(state, giftId)
			refreshIncome(state)
			notify(player, "Info", ("🎁 희귀 로봇 비 선물: %s이(가) 기지에 도착했어요!"):format(robotLabel(giftId)))
		else
			local value = Config.robotValue(giftId)
			setMoney(state, state.money + value)
			notify(player, "Info", ("🎁 받침대가 꽉 차서 %s 대신 %s 돈을 드렸어요."):format(robotLabel(giftId), Config.formatMoney(value)))
		end
	else
		return false
	end
	syncPasses(state)
	JunkyardSave.saveNow(player) -- 결제 결과는 바로 저장
	return true
end

-- 게임 안에서 게임패스를 새로 샀을 때
local function onPassOwned(player: Player, key: string)
	local state = states[player]
	if not state then
		return
	end
	state.passes[key] = true
	syncPasses(state)
	refreshIncome(state)
	applyTitle(state)
	notify(player, "Info", ("%s 구매 고마워요! 바로 적용됐어요."):format(Config.GamePasses[key].name))
end

JunkyardStore.start({ grantProduct = grantProduct, onPassOwned = onPassOwned })

-- 저장된 기지 불러오기 ------------------------------------------------------------
local function setCatalog(state: State, catalog: { [string]: boolean }, variantCatalog: { [string]: boolean })
	state.catalog = catalog
	state.variantCatalog = variantCatalog
	local ids = {}
	for id in catalog do
		table.insert(ids, id)
	end
	state.player:SetAttribute("Catalog", HttpService:JSONEncode(ids))
	recomputeMultiplier(state)
	applyTitle(state)
end

local function loadPlayer(state: State)
	local player = state.player
	local base = state.base
	local status, data, lastSeen = JunkyardSave.loadAsync(player.UserId)
	if player.Parent == nil or states[player] ~= state or not base then
		if data then
			JunkyardSave.saveAsync(player.UserId, data, true) -- 불러오는 사이에 나갔다: lock만 푼다
		end
		return
	end
	if data then
		setMoney(state, data.money)
		state.totalEarned = data.totalEarned
		setTutorial(state, data.tutorial)
		state.rebirth = data.rebirth
		syncRebirth(state)
		setCatalog(state, data.catalog, data.variantCatalog)
		state.upgrades = data.upgrades
		syncUpgradeAttributes(state)
		state.empCharges = data.empCharges
		state.passes = JunkyardStore.checkPasses(player)
		syncPasses(state)
		applyTitle(state)
		setPadLocks(base)
		applySpeed(state)
		for key, robotId in data.pads do
			local index = tonumber(key)
			if index and base.pads[index] then
				setPadRobot(base, index, robotId)
			end
		end
		refreshIncome(state)
		local boost = state.passes.OfflineBoost == true -- 오프라인 수입 강화 게임패스
		local gained = JunkyardSave.offlineEarnings(baseIncome(base, state), lastSeen, os.time(),
			if boost then Config.OfflineBoostRate else nil, if boost then Config.OfflineBoostHours else nil)
		if gained > 0 then
			base.vault += gained
			state.totalEarned += gained
			base.model:SetAttribute("Vault", math.floor(base.vault))
			notify(player, "Money", ("떠나 있는 동안 금고에 +%s"):format(Config.formatMoney(gained)))
		end
		JunkyardSave.track(player, function()
			return snapshot(state)
		end)
		player:SetAttribute("SaveOff", false)
	else
		player:SetAttribute("SaveOff", true)
		notify(player, "Alert", if status == "locked"
			then "다른 서버에서 아직 저장 중이라 이번 접속은 저장되지 않아요."
			else "저장된 기지를 불러오지 못해 이번 접속은 저장되지 않아요.")
	end
	state.loading = false
	player:SetAttribute("Loading", false)
end

-- 플레이어 ----------------------------------------------------------------------
local function onCharacterAdded(state: State, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	task.wait() -- 기본 스폰 배치가 끝난 뒤에 옮긴다
	if state.player:GetAttribute("Mode") == "Junkyard" and state.base then
		character:PivotTo(spawnCFrame(state.base))
	end
	if state.carry then
		attachCarryModel(state) -- 산 로봇은 다시 태어나도 계속 들고 있다
	end
	applySpeed(state)
	character:WaitForChild("Head", 5)
	applyTitle(state)
end

local function onPlayerAdded(player: Player)
	local state: State = {
		player = player,
		money = 0,
		base = nil,
		carry = nil,
		catalog = {},
		multiplier = 1,
		moneyValue = nil,
		incomeValue = nil,
		lastFullNotice = 0,
		lastAction = 0,
		loading = true,
		upgrades = {},
		stunnedUntil = 0,
		slowedUntil = 0,
		glovesUntil = 0,
		empReadyAt = 0,
		holdStart = {},
		passes = {},
		empCharges = 0,
		variantCatalog = {},
		rebirth = 0,
		rebirthValue = nil,
		totalEarned = 0,
		tutorial = 0,
	}
	for _, id in Config.UpgradeOrder do
		state.upgrades[id] = 0
	end
	states[player] = state
	syncUpgradeAttributes(state)
	player:SetAttribute("Mode", "Junkyard") -- 들어오면 고물상에서 시작 (Respawn 스크립트가 이 값을 본다)
	player:SetAttribute("Catalog", "[]")
	player:SetAttribute("Multiplier", 1)
	player:SetAttribute("Loading", true)
	syncCarryAttributes(state)
	setMoney(state, Config.StartMoney)
	if assignBase(state) then
		task.spawn(loadPlayer, state) -- 저장된 돈·도감·받침대 로봇을 불러온다
	else
		player:SetAttribute("Mode", "Spectator") -- 기지 없음: 구경만 (HUD 숨김)
		player:SetAttribute("SaveOff", true)
		state.loading = false
		player:SetAttribute("Loading", false)
		notify(player, "Alert", "이 서버의 기지가 모두 찼어요. 구경은 할 수 있지만 진행은 저장되지 않아요. 다른 서버로 다시 들어와 주세요!")
	end
	refreshIncome(state)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(state, character)
	end)
	player.CharacterRemoving:Connect(function()
		if state.carry and state.carry.fromBase then
			returnStolen(state, "도둑이 쓰러짐")
		elseif state.carry then
			state.carry.model = nil -- 산 로봇은 새 캐릭터에 다시 붙인다
		end
	end)
	if player.Character then
		task.spawn(onCharacterAdded, state, player.Character)
	end

	-- 리더보드 (2026-11-17 오비 보관 뒤로는 이 스크립트가 leaderstats를 직접 만든다)
	do
		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			stats = Instance.new("Folder")
			stats.Name = "leaderstats" -- 이 이름이어야 화면 오른쪽 위 리더보드에 표시된다
			stats.Parent = player
		end
		local moneyValue = Instance.new("IntValue")
		moneyValue.Name = "돈"
		moneyValue.Value = state.money
		moneyValue.Parent = stats
		local incomeValue = Instance.new("IntValue")
		incomeValue.Name = "초당"
		incomeValue.Parent = stats
		local rebirthValue = Instance.new("IntValue")
		rebirthValue.Name = "환생"
		rebirthValue.Value = state.rebirth
		rebirthValue.Parent = stats
		state.rebirthValue = rebirthValue
		state.moneyValue = moneyValue
		state.incomeValue = incomeValue
		refreshIncome(state)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player)
	local state = states[player]
	if not state then
		return
	end
	if state.carry and state.carry.fromBase then
		returnStolen(state, "도둑이 나감")
	end
	-- 나가기 전 마지막 점수를 순위표에 올린다 (저장을 불러온 사람만)
	if not state.loading and player:GetAttribute("SaveOff") == false then
		local userId = player.UserId
		local scores = { rebirth = state.rebirth, earned = state.totalEarned }
		task.spawn(function()
			JunkyardRanking.submit(userId, scores)
			JunkyardRanking.forget(userId)
		end)
	end
	JunkyardSave.finish(player) -- 기지를 비우기 전에 지금 값을 모아 저장 (금고·들고 있던 로봇 포함)
	if state.base then
		releaseBase(state.base)
	end
	for _, base in bases do
		base.intruders[player] = nil
		base.alarmAt[player] = nil
	end
	states[player] = nil
end)

-- Studio 서버에서만 테스트 자금을 지급한다. 클라이언트 속성 변경은 서버에 복제되지 않는다.
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("DebugGiveMoney"):Connect(function()
		local amount = workspace:GetAttribute("DebugGiveMoney")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugGiveMoney", nil)
		if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > 1000000
			or amount ~= math.floor(amount) or typeof(userId) ~= "number" then
			return
		end
		for player, state in states do
			if player.UserId == userId and not state.loading then
				setMoney(state, state.money + amount)
			end
		end
	end)
	-- Studio 전용: Robux 없이 상품·게임패스 효과 시험 (DebugMoneyUserId 대상에게)
	workspace:GetAttributeChangedSignal("DebugGrantProduct"):Connect(function()
		local key = workspace:GetAttribute("DebugGrantProduct")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugGrantProduct", nil)
		local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if player and typeof(key) == "string" and Config.Products[key] then
			grantProduct(player, key)
		end
	end)
	workspace:GetAttributeChangedSignal("DebugGivePass"):Connect(function()
		local key = workspace:GetAttribute("DebugGivePass")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugGivePass", nil)
		local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if player and typeof(key) == "string" and Config.GamePasses[key] then
			onPassOwned(player, key)
		end
	end)
	-- 환생·변종 테스트용 지급은 로컬 서버의 테스트 플레이어에게만 허용한다.
	workspace:GetAttributeChangedSignal("DebugGiveRobot"):Connect(function()
		local key = workspace:GetAttribute("DebugGiveRobot")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugGiveRobot", nil)
		if typeof(userId) ~= "number" or userId >= 0 or typeof(key) ~= "string" or not Config.isValidKey(key) then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local state = player and states[player]
		local base = state and state.base
		if not state or state.loading or not base then
			return
		end
		local slot = freePad(base)
		if slot then
			setPadRobot(base, slot, key)
			addToCatalog(state, key)
			refreshIncome(state)
		end
	end)
	workspace:GetAttributeChangedSignal("DebugSetRebirth"):Connect(function()
		local level = workspace:GetAttribute("DebugSetRebirth")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugSetRebirth", nil)
		if typeof(userId) ~= "number" or userId >= 0 or typeof(level) ~= "number"
			or level < 0 or level > 20 or level ~= math.floor(level) then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local state = player and states[player]
		if state and not state.loading then
			state.rebirth = level
			syncRebirth(state)
			recomputeMultiplier(state)
			refreshIncome(state)
		end
	end)
	-- 첫 접속 안내 시험: 안내 단계를 정한다 (0~5). Studio에서만, DebugMoneyUserId 대상
	workspace:GetAttributeChangedSignal("DebugSetTutorial"):Connect(function()
		local step = workspace:GetAttribute("DebugSetTutorial")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugSetTutorial", nil)
		if typeof(userId) ~= "number" or typeof(step) ~= "number" or step < 0 or step > 5 or step ~= math.floor(step) then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local state = player and states[player]
		if state and not state.loading then
			setTutorial(state, step)
		end
	end)
end

-- 0.2초마다: 배치, 붙잡기, 방어막 / 1초마다: 수입 -------------------------------------
task.spawn(function()
	local incomeTimer = 0
	while true do
		local dt = task.wait(0.2)
		local t = now()
		for _, state in states do
			if state.carry then
				-- 훔친 로봇: 주인이 가까이 오면 떨어뜨린다
				local carry = state.carry
				local victim = carry.fromBase and carry.fromBase.owner
				local thiefRoot = rootOf(state.player)
				local ownerRoot = victim and rootOf(victim)
				if thiefRoot and ownerRoot and (thiefRoot.Position - ownerRoot.Position).Magnitude <= Config.CatchRange then
					returnStolen(state, "주인에게 붙잡힘")
				else
					tryPlace(state)
				end
			end
		end
		for _, base in bases do
			local shield = base.model:FindFirstChild("Shield") :: BasePart
			if base.owner and t < base.lockedUntil then
				-- 잠긴 기지 안의 다른 사람은 입구 밖으로
				for player, state in states do
					local root = rootOf(player)
					local character = player.Character
					if player ~= base.owner and root and character and insideBase(base, root.Position) then
						local outside = base.center + Vector3.new(0, 3, base.front * 24)
						character:PivotTo(CFrame.lookAt(outside, outside + Vector3.new(0, 0, base.front)))
						notify(player, "Alert", "방어막이 켜진 기지예요.")
					end
				end
			elseif shield.Transparency < 1 then
				shield.Transparency = 1
				base.model:SetAttribute("LockedUntil", 0)
			end
		end
		-- 고물상 바닥 밖으로 떨어지면 자기 기지로 돌려보낸다 (훔친 로봇은 먼저 주인에게 돌아간다)
		for player, state in states do
			local root = rootOf(player)
			local base = state.base
			if root and base and root.Position.Y < FALL_Y and player:GetAttribute("Mode") == "Junkyard" then
				if state.carry and state.carry.fromBase then
					returnStolen(state, "도둑이 떨어짐")
				end
				local character = player.Character
				if character then
					character:PivotTo(spawnCFrame(base))
				end
			end
		end
		-- 기절·느려짐이 끝나면 속도를 되돌린다
		for _, state in states do
			if (state.stunnedUntil > 0 and t >= state.stunnedUntil) or (state.slowedUntil > 0 and t >= state.slowedUntil) then
				if t >= state.stunnedUntil then
					state.stunnedUntil = 0
				end
				if t >= state.slowedUntil then
					state.slowedUntil = 0
				end
				applySpeed(state)
				syncUpgradeAttributes(state)
			end
		end
		-- 경보기·레이저 울타리: 다른 사람이 기지에 "새로" 들어온 순간
		for _, base in bases do
			local owner = base.owner
			local ownerState = owner and states[owner]
			if owner and ownerState then
				for player, state in states do
					if player ~= owner then
						local root = rootOf(player)
						local inside = root ~= nil and player:GetAttribute("Mode") == "Junkyard" and insideBase(base, root.Position)
						if inside and not base.intruders[player] then
							if upgradeValue(ownerState, "Fence") > 0 then
								state.slowedUntil = t + Config.FenceSlow
								applySpeed(state)
								notify(player, "Alert", "⚡ 레이저 울타리에 걸려 느려졌어요!")
							end
							if upgradeValue(ownerState, "Alarm") > 0 and t - (base.alarmAt[player] or 0) >= Config.AlarmCooldown then
								base.alarmAt[player] = t
								notifyRemote:FireClient(owner, "Alarm", ("🚨 %s님이 내 기지에 들어왔어요!"):format(player.DisplayName), player.UserId)
							end
						end
						base.intruders[player] = if inside then true else nil
					end
				end
			end
		end
		incomeTimer += dt
		if incomeTimer >= 1 then
			incomeTimer -= 1
			for _, base in bases do
				local owner = base.owner
				if owner and states[owner] then
					local income = baseIncome(base, states[owner])
					JunkyardContest.record(owner, "Income", income)
					base.vault += income
					states[owner].totalEarned += income
					local amount = math.floor(base.vault)
					base.model:SetAttribute("Vault", amount)
					local vault = base.model:FindFirstChild("Vault")
					local amountGui = vault and vault:FindFirstChild("Amount")
					local label = amountGui and amountGui:FindFirstChild("Label")
					if label and label:IsA("TextLabel") then
						label.Text = "금고 " .. Config.formatMoney(amount)
					end
				end
			end
		end
	end
end)
