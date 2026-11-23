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
local RobotModel = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardRobotModel"))
local Belt = require(script.Parent:WaitForChild("JunkyardBelt"))
local JunkyardSave = require(script.Parent:WaitForChild("JunkyardSave"))
local JunkyardStore = require(script.Parent:WaitForChild("JunkyardStore"))
local JunkyardRanking = require(script.Parent:WaitForChild("JunkyardRanking"))
local JunkyardCCTV = require(script.Parent:WaitForChild("JunkyardCCTV"))
local JunkyardContest = require(script.Parent:WaitForChild("JunkyardContest"))
local JunkyardGiantRobot = require(script.Parent:WaitForChild("JunkyardGiantRobot"))
local JunkyardReferral = require(script.Parent:WaitForChild("JunkyardReferral"))

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
	expand: number, -- 지금 펼쳐진 확장 단계 (주인의 단계, 빈 기지는 0)
	owner: Player?,
	vault: number,
	lockedUntil: number, -- 서버 시간(GetServerTimeNow) 기준
	lockCooldownUntil: number,
	intruders: { [Player]: boolean }, -- 지금 기지 안에 있는 다른 사람 (경보기·울타리용)
	alarmAt: { [Player]: number }, -- 침입자별 마지막 경보 시각
}
type Carry = {
	robotId: string,
	fromBase: Base?, -- 있으면 받침대에서 훔친 로봇
	fromPad: number?,
	model: Model?,
	snatchedFrom: Player?, -- 있으면 이 사람이 들고 가던 로봇을 빼앗은 것 (그 사람이 따라잡으면 되찾는다)
	protectUntil: number?, -- 이 시각까지는 다시 빼앗기·되찾기 불가
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
	expand: number, -- 기지 확장 단계 (저장됨, 환생해도 유지)
	titles: { [string]: boolean }, -- 영구 획득한 칭호
	selectedTitle: string, -- 표시할 칭호
	batLevel: number, -- 방망이 성장 단계 (저장됨)
	batXp: number, -- 방망이 경험치 (저장됨)
	batSkin: string, -- 고른 방망이 꾸미기 (저장됨, "" = 단계 모양)
	batXpAt: { [Player]: number }, -- 도둑별 마지막 경험치 시각 (주고받기 방지)
	referredBy: number, -- 나를 초대한 사람 UserId (저장됨, 0 = 없음)
	referralPaid: boolean, -- 초대한 사람에게 보상을 보냈는지 (저장됨)
	playTime: number, -- 초대받은 사람이 논 시간(초, 저장됨)
	invites: number, -- 인정된 친구 초대 수 (저장됨)
	referralBusy: boolean, -- 초대 보상을 가져오는 중 (겹쳐서 가져가지 않게)
	dailyStep: number, -- 마지막으로 받은 매일 보상 날짜 1~7 (저장됨)
	dailyLast: number, -- 마지막으로 받은 날 번호 (저장됨)
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
	local forward = offset.Z * base.front -- 벨트 쪽이 +, 뒤쪽(확장 구역)이 −
	local depth = Config.Expansion.Depth * base.expand
	return math.abs(offset.X) <= 22 and forward <= 17 and forward >= -17 - depth and offset.Y > -3 and offset.Y < 20
end

-- 로봇 모형 (모양은 공용 모듈 JunkyardRobotModel, 여기서는 이름표만 붙인다) ----------------
local function makeRobotModel(robotId: string, anchored: boolean): Model
	local robot = Config.getRobot(robotId)
	local rarity = Config.rarityOf(robotId)
	local size = if rarity then rarity.size else 1
	local variant = Config.variantOf(robotId) -- 변종이면 변종 색과 반짝이
	local color = if variant then variant.color elseif rarity then rarity.color else Color3.new(1, 1, 1)
	-- 로봇마다 다른 생김새·표정 (등급 크기, 변종 색) — 받침대·들고 가기·CCTV 모두 같은 모양
	local model = RobotModel.build(robotId, anchored)
	local body = model.PrimaryPart :: BasePart
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(170, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.6 * size, 0) -- 새 모형은 더 높아서 이름표를 조금 올림
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
		local hidden = ((pad:GetAttribute("ExpandLevel") or 0) :: number) > base.expand -- 아직 넓히지 않은 구역
		local locked = index > limit
		pad.Transparency = if hidden then 1 elseif locked then 0.7 else 0
		pad.CanCollide = not hidden
		pad.Color = if locked then Color3.fromRGB(40, 44, 50) else Color3.fromRGB(70, 78, 88)
		local prompt = pad:FindFirstChild("RobotPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = not hidden and base.robots[index] ~= nil -- 빈 받침대에는 팔기·훔치기 버튼을 띄우지 않는다
		end
	end
end

-- 기지를 확장 단계만큼 펼친다: 뒷벽을 뒤로 밀고, 옆벽·바닥·방어막을 늘리고, 그 구역 받침대를 보인다
-- (지도의 OrigPosition/OrigSize 속성 기준, tools/build-expansion.luau)
local function applyExpansion(base: Base, level: number)
	base.expand = level
	base.model:SetAttribute("Expand", level)
	local grow = Config.Expansion.Depth * level
	local shift = Vector3.new(0, 0, -base.front * grow) -- 뒤쪽으로
	for _, child in base.model:GetChildren() do
		local origPosition = child:GetAttribute("OrigPosition")
		local origSize = child:GetAttribute("OrigSize")
		if child:IsA("BasePart") and typeof(origPosition) == "Vector3" and typeof(origSize) == "Vector3" then
			if child:GetAttribute("WallRole") == "Back" then
				child.Position = origPosition + shift
			else -- 옆벽·바닥·방어막
				child.Size = origSize + Vector3.new(0, 0, grow)
				child.Position = origPosition + shift / 2
			end
		end
	end
	setPadLocks(base)
end

-- 로봇이 놓인 받침대 수 (등급 상관없이)
local function filledPads(state: State): number
	local count = 0
	if state.base then
		for _ in state.base.robots do
			count += 1
		end
	end
	return count
end

-- 걷기 속도·점프: 기절(EMP) > 느려짐(울타리) > 신발 + 받침대 − 로봇 무게
local function applySpeed(state: State)
	local character = state.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local t = workspace:GetServerTimeNow()
	local speed = Config.walkSpeed(upgradeValue(state, "Shoes"), filledPads(state), if state.carry then state.carry.robotId else nil)
	if t < state.stunnedUntil then
		speed = 0
	elseif t < state.slowedUntil then
		speed = Config.FenceSpeed
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
	-- 도감 배수 × 환생 배수 × 수입 2배 게임패스 × 거대 로봇 가동 중 서버 2배
	return total * state.multiplier * Config.rebirthMultiplier(state.rebirth)
		* (if state.passes.DoubleIncome then Config.IncomePassMultiplier else 1)
		* JunkyardGiantRobot.incomeBoost()
end

local function refreshIncome(state: State)
	local income = if state.base then baseIncome(state.base, state) else 0
	state.player:SetAttribute("Income", income)
	if state.incomeValue then
		state.incomeValue.Value = math.floor(income)
	end
	applySpeed(state) -- 받침대 수가 바뀌면 속도도 바뀐다
end

-- 도감 ------------------------------------------------------------------------
local function applyTitle(state: State)
	local character = state.player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local chosen = Config.TitleNames[state.selectedTitle]
	local vip = state.passes.VipBase == true
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not chosen and not vip and state.rebirth <= 0 then
		if tag then
			tag:Destroy()
		end
		return
	end
	if not tag then
		local newTag = Instance.new("BillboardGui")
		newTag.Name = "TitleTag"
		newTag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		newTag.MaxDistance = 80
		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 16
		text.TextWrapped = true
		text.TextStrokeTransparency = 0.3
		text.TextColor3 = Color3.fromRGB(255, 215, 90)
		text.Parent = newTag
		newTag.Parent = head
		tag = newTag
	end
	local words = {}
	if state.rebirth > 0 then
		table.insert(words, Config.rebirthMark(state.rebirth))
	end
	if vip then
		table.insert(words, "[👑 VIP]")
	end
	if chosen then
		table.insert(words, chosen)
	end
	tag.Size = UDim2.fromOffset(240, 42)
	local text = tag:FindFirstChild("Label") :: TextLabel
	text.Text = table.concat(words, " ")
end

-- 도감 배수에는 기본 도감과 변종 도감 보너스를 각각 한 번 더한다.
local function recomputeMultiplier(state: State)
	-- 기존 플레이어도 완성한 도감에 해당하는 칭호를 접속 즉시 받는다.
	for _, rarityId in Config.RarityOrder do
		if Config.isCatalogComplete(state.catalog, rarityId) then
			state.titles["Set_" .. rarityId] = true
		end
	end
	if Config.isCatalogComplete(state.catalog) then
		state.titles.FullCatalog = true
	end
	for _, variantId in Config.VariantOrder do
		if Config.isVariantPageComplete(state.variantCatalog, variantId) then
			state.titles["Page_" .. variantId] = true
		end
	end
	local titles = {}
	for _, id in Config.TitleOrder do
		if state.titles[id] then
			table.insert(titles, id)
		end
	end
	if state.selectedTitle == "" and #titles > 0 then
		state.selectedTitle = titles[#titles]
	end
	state.player:SetAttribute("OwnedTitles", HttpService:JSONEncode(titles))
	state.player:SetAttribute("SelectedTitle", state.selectedTitle)
	state.player:SetAttribute("TitleBonus", Config.titleBonus(state.titles))
	state.multiplier = Config.catalogMultiplier(state.catalog) + Config.variantPageBonus(state.variantCatalog) + Config.titleBonus(state.titles)
	state.player:SetAttribute("Multiplier", state.multiplier)
	local keys = {}
	for key in state.variantCatalog do
		table.insert(keys, key)
	end
	state.player:SetAttribute("VariantCatalog", HttpService:JSONEncode(keys))
end

local function grantTitle(state: State, id: string)
	if state.titles[id] then
		return
	end
	state.titles[id] = true
	recomputeMultiplier(state)
	refreshIncome(state)
	applyTitle(state)
	notify(state.player, "Info", ("🏅 칭호 획득 · %s! 영구 수입 +1%%"):format(Config.TitleNames[id]))
	JunkyardSave.saveNow(state.player)
end

local function addToCatalog(state: State, robotKey: string)
	local robotId, variantId = Config.splitKey(robotKey)
	local milestones: { string } = {}
	local addedVariant = variantId ~= nil and not state.variantCatalog[robotKey]
	local addedRobot = not state.catalog[robotId]
	if not addedRobot and not addedVariant then
		return
	end
	-- 한 로봇으로 여러 도감을 완성할 수 있다. 축하 알림은 한 번으로 묶는다.
	if variantId and not state.variantCatalog[robotKey] then
		state.variantCatalog[robotKey] = true
		if Config.isVariantPageComplete(state.variantCatalog, variantId) then
			table.insert(milestones, Config.VariantPageTitles[variantId])
		end
	end
	if addedRobot then
		state.catalog[robotId] = true
		local ids = {}
		for id in state.catalog do
			table.insert(ids, id)
		end
		state.player:SetAttribute("Catalog", HttpService:JSONEncode(ids))
		local robot = Config.getRobot(robotId)
		if robot and Config.isCatalogComplete(state.catalog, robot.rarity) then
			local rarity = Config.Rarities[robot.rarity]
			table.insert(milestones, rarity.name .. " 세트")
			-- 세트 완성 즉시 보상 (도감은 환생해도 남으므로 한 번만 받는다)
			setMoney(state, state.money + rarity.setReward)
			notify(state.player, "Money", ("🎁 %s 세트 완성 보상 +%s"):format(rarity.name, Config.formatMoney(rarity.setReward)))
		end
		if Config.isCatalogComplete(state.catalog) then
			table.insert(milestones, Config.FullCatalogTitle)
		end
	end
	recomputeMultiplier(state)
	refreshIncome(state)
	if #milestones > 0 then
		applyTitle(state)
		notifyAll(("🎉 %s님 달성 · %s"):format(state.player.DisplayName, table.concat(milestones, " · ")))
		local root = rootOf(state.player)
		if root then
			local effect = Instance.new("Sparkles")
			effect.Name = "CatalogCelebration"
			effect.SparkleColor = Color3.fromRGB(255, 215, 90)
			effect.Parent = root
			Debris:AddItem(effect, 3)
		end
	else
		notify(state.player, "Info", ("%s도감 등록 · %s"):format(if addedVariant then "변종 " else "", robotLabel(robotKey)))
	end
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
-- "빼앗기" 버튼 처리 (아래 빼앗기 부분에서 채운다)
local snatchHandler: (Player, State, ProximityPrompt) -> () = function() end

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
	-- 들고 가는 로봇 버튼: 벨트에서 산 로봇은 누구나 길게 눌러 "빼앗기", 훔친 로봇은 주인만 "되찾기"
	-- (누가 누를 수 있는지는 프롬프트 속성 OwnerUserId·VictimUserId로 화면이 정하고, 서버가 다시 확인한다)
	if model.PrimaryPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SnatchPrompt"
		prompt.ActionText = "빼앗기"
		prompt.ObjectText = Config.robotName(carry.robotId)
		prompt.HoldDuration = Config.StealHold
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		local owner = carry.fromBase and carry.fromBase.owner
		prompt:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
		prompt:SetAttribute("VictimUserId", if carry.snatchedFrom then carry.snatchedFrom.UserId else 0)
		prompt.Parent = model.PrimaryPart
		prompt.PromptButtonHoldBegan:Connect(function(player: Player)
			local holder = states[player]
			if holder then
				holder.holdStart[prompt] = os.clock()
			end
		end)
		prompt.Triggered:Connect(function(player: Player)
			snatchHandler(player, state, prompt)
		end)
	end
	applySpeed(state)
end

local function syncCarryAttributes(state: State)
	local carry = state.carry
	state.player:SetAttribute("Carrying", if carry then carry.robotId else "")
	state.player:SetAttribute("CarryStolen", carry ~= nil and (carry.fromBase ~= nil or carry.snatchedFrom ~= nil))
	-- 들고 가는 로봇 버튼의 주인·원래 사람 표시도 맞춘다
	local prompt = carry and carry.model and carry.model.PrimaryPart and carry.model.PrimaryPart:FindFirstChild("SnatchPrompt")
	if carry and prompt then
		local owner = carry.fromBase and carry.fromBase.owner
		prompt:SetAttribute("OwnerUserId", if owner then owner.UserId else 0)
		prompt:SetAttribute("VictimUserId", if carry.snatchedFrom then carry.snatchedFrom.UserId else 0)
	end
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

-- 빼앗은 로봇을 원래 들고 가던 사람에게 돌려준다. 그 사람이 다른 로봇을 들고 있으면 못 돌려준다(false)
local function returnSnatched(state: State, reason: string): boolean
	local carry = state.carry
	local victim = carry and carry.snatchedFrom
	local victimState = if victim then states[victim] else nil
	if not carry or not victim or not victimState or victimState.carry or victimState.loading then
		return false
	end
	local robotId = carry.robotId
	endCarry(state)
	startCarry(victimState, robotId, nil, nil)
	local back = victimState.carry
	if back then
		back.protectUntil = now() + Config.SnatchProtect
	end
	notify(victim, "Info", ("%s을(를) 되찾았어요! (%s)"):format(robotLabel(robotId), reason))
	notify(state.player, "Alert", ("빼앗은 로봇을 놓쳤어요. (%s)"):format(reason))
	return true
end

-- 새싹 보호: 막 시작한 사람(환생 0번, 누적 수입이 적음)은 훔치기·빼앗기·EMP를 당하지 않는다
local function isNewbie(state: State): boolean
	return state.rebirth <= 0 and state.totalEarned < Config.NewbieProtectEarned
end

-- 변종 로봇은 그 변종이 열린(환생 단계가 충분한) 사람만 가질 수 있다. 훔치기·빼앗기로 환생을 건너뛰지 못하게
local function variantLock(state: State, key: string): string?
	local variant = Config.variantOf(key)
	if variant and state.rebirth < variant.minRebirth then
		return ("%s %s 로봇은 환생 %d번 이상만 가질 수 있어요."):format(variant.mark, variant.name, variant.minRebirth)
	end
	return nil
end

-- 되찾을 때 방망이를 휘두르는 모습: 오른손에 방망이를 잠깐 쥐고, 팔을 머리 위에서 앞으로 내리친다 (R15 팔 동작, R6는 방망이만)
-- 캐릭터 기본 동작(Animate 안의 animName, 없으면 fallback 번호)을 서버에서 재생한다 (모두에게 보임)
local function playCharacterAnim(character: Model, animName: string, fallback: string, looped: boolean): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local animate = character:FindFirstChild("Animate")
	local value = animate and animate:FindFirstChild(animName)
	local source = value and value:FindFirstChildOfClass("Animation")
	local animation = Instance.new("Animation")
	animation.AnimationId = if source then source.AnimationId else fallback
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = looped
	track:Play(0.1)
	return track
end

-- 방망이: [2](또는 화면 버튼)로 들고 [1]로 내린다. 든 동안에만 도둑맞은 로봇을 되찾을 수 있다 (플레이어 속성 BatOut)
-- 모양: 꾸미기(Robux 게임패스)를 골랐으면 그 모양, 아니면 성장 단계 모양(나무→쇠→금→네온→무지개)
local batTracks: { [Player]: AnimationTrack } = {}

local function batLevelOf(state: State): Config.BatLevel
	return Config.BatLevels[state.batLevel] or Config.BatLevels[1]
end

-- 화면 표시용 속성 (방망이 창)
local function syncBat(state: State)
	state.player:SetAttribute("BatLevel", state.batLevel)
	state.player:SetAttribute("BatXp", state.batXp)
	state.player:SetAttribute("BatSkin", state.batSkin)
end

-- 방망이 조각 하나를 손잡이에 붙인다 (offset = 손잡이 가운데 기준, 아래쪽(-Y)이 방망이 끝)
local function addBatPiece(handle: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name = "BatPiece"
	piece.Size = size
	if shape then
		piece.Shape = shape
	end
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	piece.CastShadow = false
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
	piece.Parent = handle
	return piece
end

-- 방망이 모형을 만들어 손에 붙인다 (손잡이 이름 JunkyardBat, 조각·효과는 그 안에)
local function buildBat(state: State, character: Model, hand: BasePart)
	local level = batLevelOf(state)
	local skinKey = state.batSkin
	local skin = if skinKey ~= "" and state.passes[skinKey] == true then Config.BatSkins[skinKey] else nil
	local color = if skin then skin.color else level.color
	local accent = if skin then skin.accent else level.color
	local material = if skin then skin.material else level.material
	local handle = Instance.new("Part")
	handle.Name = "JunkyardBat"
	handle.Size = Vector3.new(0.3, 1.6, 0.3)
	handle.Color = color
	handle.Material = material
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CastShadow = false
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	-- 쥐는 법: 손잡이가 주먹 가운데를 지나고 방망이 머리는 위로.
	-- 도구를 든 자세(팔을 앞으로)에서 손의 -Z가 위쪽이라, 손잡이의 -Y(방망이 끝 쪽)를 손의 -Z에 맞춘다 (X축 90도).
	-- 마지막 0.2는 손잡이를 아래로 조금 내려 몸통이 주먹 바로 위에서 시작하게 한다
	local gripY = if string.find(hand.Name, "Hand", 1, true) then 0 else -hand.Size.Y / 2 + 0.3 -- R6 팔은 아래 끝을 쥔다
	weld.C0 = CFrame.new(0, gripY, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, 0.2, 0)
	weld.Parent = handle
	local tip: Part
	if skin and skinKey == "BatWrench" then
		addBatPiece(handle, Vector3.new(0.3, 2.4, 0.2), CFrame.new(0, -1.9, 0), color, material)
		addBatPiece(handle, Vector3.new(1, 0.3, 0.25), CFrame.new(0, -3.1, 0), color, material)
		addBatPiece(handle, Vector3.new(0.25, 0.7, 0.25), CFrame.new(-0.38, -3.5, 0), color, material)
		tip = addBatPiece(handle, Vector3.new(0.25, 0.7, 0.25), CFrame.new(0.38, -3.5, 0), color, material)
	elseif skin and skinKey == "BatCandy" then
		-- 롤리팝: 하얀 막대 끝에 납작하고 둥근 사탕. 색 동심원이 앞뒤로 보인다 (작은 고리일수록 조금 두꺼워 튀어나옴)
		local white = Color3.fromRGB(252, 252, 252)
		handle.Color = white
		handle.Material = Enum.Material.SmoothPlastic
		addBatPiece(handle, Vector3.new(0.22, 2.3, 0.22), CFrame.new(0, -1.9, 0), white, Enum.Material.SmoothPlastic)
		local face = CFrame.Angles(0, math.rad(90), 0) -- 원기둥 축(X)을 앞뒤(Z)로 돌려 사탕 면이 앞뒤를 본다
		local rings = {
			{ size = 2, thick = 0.3, color = skin.accent },
			{ size = 1.6, thick = 0.34, color = white },
			{ size = 1.2, thick = 0.38, color = Color3.fromRGB(255, 205, 60) },
			{ size = 0.8, thick = 0.42, color = Color3.fromRGB(110, 200, 255) },
			{ size = 0.36, thick = 0.46, color = white },
		}
		for index, ring in rings do
			local piece = addBatPiece(handle, Vector3.new(ring.thick, ring.size, ring.size), CFrame.new(0, -4, 0) * face, ring.color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			if index == 1 then
				tip = piece
			end
		end
	elseif skin and skinKey == "BatGuitar" then
		-- 기타: 쥐는 곳이 넥, 손 아래로 헤드(줄감개), 위로 둥근 몸통 두 덩어리. 줄 4개는 앞뒤 모두 보이게
		local black = Color3.fromRGB(25, 25, 28)
		local silver = Color3.fromRGB(230, 230, 236)
		local face = CFrame.Angles(0, math.rad(90), 0)
		addBatPiece(handle, Vector3.new(0.5, 0.6, 0.18), CFrame.new(0, 1.05, 0), black, Enum.Material.SmoothPlastic) -- 헤드
		for _, y in { 0.9, 1.2 } do
			for _, x in { -0.3, 0.3 } do
				addBatPiece(handle, Vector3.new(0.14, 0.09, 0.09), CFrame.new(x, y, 0), silver, Enum.Material.Metal) -- 줄감개
			end
		end
		addBatPiece(handle, Vector3.new(0.32, 1.9, 0.3), CFrame.new(0, -1.7, 0), color, material) -- 넥
		addBatPiece(handle, Vector3.new(0.36, 1.15, 1.15), CFrame.new(0, -2.85, 0) * face, skin.accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) -- 윗 몸통
		tip = addBatPiece(handle, Vector3.new(0.36, 1.5, 1.5), CFrame.new(0, -3.55, 0) * face, skin.accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) -- 아랫 몸통
		addBatPiece(handle, Vector3.new(0.38, 0.42, 0.42), CFrame.new(0, -2.9, 0) * face, black, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder) -- 소리 구멍
		for _, side in { 1, -1 } do
			addBatPiece(handle, Vector3.new(0.6, 0.12, 0.08), CFrame.new(0, -3.75, 0.2 * side), black, Enum.Material.SmoothPlastic) -- 줄 받침
			for _, x in { -0.11, -0.037, 0.037, 0.11 } do
				addBatPiece(handle, Vector3.new(0.04, 3, 0.04), CFrame.new(x, -2.25, 0.22 * side), silver, Enum.Material.Neon) -- 줄
			end
		end
	elseif skin and skinKey == "BatLightning" then
		addBatPiece(handle, Vector3.new(0.5, 2.3, 0.5), CFrame.new(0, -1.9, 0), color, material)
		addBatPiece(handle, Vector3.new(0.25, 1, 0.25), CFrame.new(0.35, -1.6, 0) * CFrame.Angles(0, 0, math.rad(35)), skin.accent, Enum.Material.Neon)
		tip = addBatPiece(handle, Vector3.new(0.25, 1, 0.25), CFrame.new(-0.35, -2.6, 0) * CFrame.Angles(0, 0, math.rad(-35)), skin.accent, Enum.Material.Neon)
	else
		-- 기본 방망이: 가는 손잡이 + 굵은 몸통 + 둥근 끝
		addBatPiece(handle, Vector3.new(0.55, 2.2, 0.55), CFrame.new(0, -1.8, 0), color, material)
		tip = addBatPiece(handle, Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, -2.9, 0), color, material, Enum.PartType.Ball)
	end
	-- 휘두를 때 끝에서 터지는 불꽃 (swingBat이 Emit)
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Rate = 0
	burst.Color = ColorSequence.new(accent)
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Lifetime = NumberRange.new(0.3, 0.6)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Parent = tip
	-- 꼬리 빛: 금 방망이부터, 꾸미기는 모두
	if skin or level.trail then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, -1, 0)
		top.Parent = handle
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -3, 0)
		bottom.Parent = handle
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.25
		trail.Color = ColorSequence.new(accent)
		trail.Transparency = NumberSequence.new(0.4, 1)
		trail.LightEmission = 0.6
		trail.Parent = handle
	end
	if (skin and skin.glow) or (not skin and level.glow) then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = tip
	end
	handle.Parent = character
	-- 무지개 방망이: 색이 계속 바뀐다 (방망이를 내리면 멈춤)
	if not skin and level.rainbow then
		task.spawn(function()
			while handle.Parent do
				local hue = Color3.fromHSV((os.clock() * 0.25) % 1, 0.75, 1)
				handle.Color = hue
				for _, child in handle:GetChildren() do
					if child:IsA("BasePart") then
						child.Color = hue
					end
				end
				task.wait(0.15)
			end
		end)
	end
end

-- 장갑(기본, [1]): 로봇 가져가기(벨트 구매·훔치기·빼앗기)는 장갑을 낀 동안에만 된다.
-- 장갑 모양은 늘 같고, 효과(반짝이·빛·가져갈 때 불꽃)만 방망이 단계·꾸미기를 따라 바뀐다
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 240, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})
-- 장갑 모양: 단계(나무→쇠→금→네온→무지개)와 꾸미기마다 장갑·손목 띠 색과 재질이 다르다
type GloveLook = { color: Color3, material: Enum.Material, cuff: Color3, cuffMaterial: Enum.Material }
local GLOVE_LEVELS: { GloveLook } = {
	{ color = Color3.fromRGB(205, 170, 105), material = Enum.Material.Fabric, cuff = Color3.fromRGB(120, 85, 50), cuffMaterial = Enum.Material.Fabric }, -- 작업 장갑
	{ color = Color3.fromRGB(150, 156, 166), material = Enum.Material.DiamondPlate, cuff = Color3.fromRGB(80, 86, 96), cuffMaterial = Enum.Material.Metal }, -- 쇠 장갑
	{ color = Color3.fromRGB(255, 196, 60), material = Enum.Material.Metal, cuff = Color3.fromRGB(190, 120, 30), cuffMaterial = Enum.Material.Metal }, -- 금 장갑
	{ color = Color3.fromRGB(35, 45, 65), material = Enum.Material.SmoothPlastic, cuff = Color3.fromRGB(80, 230, 255), cuffMaterial = Enum.Material.Neon }, -- 네온 장갑
	{ color = Color3.fromRGB(255, 255, 255), material = Enum.Material.Neon, cuff = Color3.fromRGB(255, 120, 200), cuffMaterial = Enum.Material.Neon }, -- 무지개 장갑 (색은 계속 바뀜)
}
local GLOVE_SKINS: { [string]: GloveLook } = {
	BatWrench = { color = Color3.fromRGB(255, 140, 40), material = Enum.Material.SmoothPlastic, cuff = Color3.fromRGB(150, 158, 170), cuffMaterial = Enum.Material.DiamondPlate }, -- 주황 고무장갑
	BatCandy = { color = Color3.fromRGB(255, 160, 205), material = Enum.Material.SmoothPlastic, cuff = Color3.fromRGB(255, 255, 255), cuffMaterial = Enum.Material.SmoothPlastic }, -- 분홍 사탕 장갑
	BatGuitar = { color = Color3.fromRGB(28, 28, 32), material = Enum.Material.Fabric, cuff = Color3.fromRGB(220, 40, 50), cuffMaterial = Enum.Material.SmoothPlastic }, -- 검정 가죽 장갑
	BatLightning = { color = Color3.fromRGB(255, 230, 60), material = Enum.Material.SmoothPlastic, cuff = Color3.fromRGB(140, 220, 255), cuffMaterial = Enum.Material.Neon }, -- 번개 장갑
}
local function buildGloves(state: State, character: Model)
	local level = batLevelOf(state)
	local skin = if state.batSkin ~= "" and state.passes[state.batSkin] == true then Config.BatSkins[state.batSkin] else nil
	local accent = if skin then skin.accent else level.color
	local colors = if not skin and level.rainbow then RAINBOW else ColorSequence.new(accent)
	local sparkle = skin ~= nil or state.batLevel >= 2 -- 쇠 단계부터 반짝이
	local glow = if skin then skin.glow else level.glow -- 네온 단계부터(꾸미기는 번개만) 빛
	local look = (if skin then GLOVE_SKINS[state.batSkin] else GLOVE_LEVELS[state.batLevel]) or GLOVE_LEVELS[1]
	local rainbow = not skin and level.rainbow
	for _, side in { "Left", "Right" } do
		local hand = character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")
		if hand and hand:IsA("BasePart") then
			local r15 = string.find(hand.Name, "Hand", 1, true) ~= nil
			local glove = Instance.new("Part")
			glove.Name = "JunkyardGlove"
			-- 손에 얇게 씌운다 (두꺼우면 손에 상자를 끼운 것처럼 보인다)
			glove.Size = if r15 then hand.Size + Vector3.new(0.04, 0.02, 0.04) else Vector3.new(hand.Size.X + 0.04, 0.7, hand.Size.Z + 0.04)
			glove.Color = look.color
			glove.Material = look.material
			glove.CanCollide = false
			glove.CanQuery = false
			glove.CanTouch = false
			glove.Massless = true
			glove.CastShadow = false
			local weld = Instance.new("Weld")
			weld.Part0 = hand
			weld.Part1 = glove
			weld.C0 = if r15 then CFrame.new() else CFrame.new(0, -hand.Size.Y / 2 + 0.3, 0)
			weld.Parent = glove
			-- 로봇을 가져갈 때 터지는 불꽃 (gloveBurst가 Emit)
			local burst = Instance.new("ParticleEmitter")
			burst.Name = "Burst"
			burst.Rate = 0
			burst.Color = colors
			burst.LightEmission = 1
			burst.Size = NumberSequence.new(0.35, 0)
			burst.Lifetime = NumberRange.new(0.3, 0.5)
			burst.Speed = NumberRange.new(4, 8)
			burst.SpreadAngle = Vector2.new(180, 180)
			burst.Parent = glove
			if sparkle then
				local aura = Instance.new("ParticleEmitter")
				aura.Name = "Aura"
				aura.Rate = if skin or state.batLevel >= 4 then 6 else 3
				aura.Color = colors
				aura.LightEmission = 1
				aura.Size = NumberSequence.new(0.22, 0)
				aura.Lifetime = NumberRange.new(0.5, 0.9)
				aura.Speed = NumberRange.new(0.5, 1.5)
				aura.SpreadAngle = Vector2.new(180, 180)
				aura.Parent = glove
			end
			if glow then
				local light = Instance.new("PointLight")
				light.Color = accent
				light.Range = 6
				light.Brightness = 1.2
				light.Parent = glove
			end
			-- 손목 띠 (손목 쪽 = 손의 +Y)
			local cuffY = glove.Size.Y / 2 - 0.07
			addBatPiece(glove, Vector3.new(glove.Size.X + 0.06, 0.14, glove.Size.Z + 0.06), CFrame.new(0, cuffY, 0), look.cuff, look.cuffMaterial)
			glove.Parent = character
			-- 무지개 단계: 장갑·손목 띠 색이 계속 바뀐다
			if rainbow then
				task.spawn(function()
					while glove.Parent do
						local hue = (os.clock() * 0.25) % 1
						glove.Color = Color3.fromHSV(hue, 0.55, 1)
						for _, child in glove:GetChildren() do
							if child:IsA("BasePart") then
								child.Color = Color3.fromHSV((hue + 0.5) % 1, 0.8, 1)
							end
						end
						task.wait(0.15)
					end
				end)
			end
		end
	end
end

-- 로봇을 가져간 순간 장갑에서 불꽃
local function gloveBurst(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		local burst = child.Name == "JunkyardGlove" and child:FindFirstChild("Burst")
		if burst and burst:IsA("ParticleEmitter") then
			burst:Emit(15)
		end
	end
end

-- 방망이를 들고 있으면 로봇을 가져갈 수 없다 (true = 막힘, 알림을 보냄)
local function needGloves(state: State): boolean
	if state.player:GetAttribute("BatOut") == true then
		notify(state.player, "Alert", "🧤 장갑을 껴야 로봇을 가져갈 수 있어요! ([1] 키 또는 🧤 버튼)")
		return true
	end
	return false
end

-- on = true면 방망이, false면 장갑. 둘 중 하나만 손에 있다
local function setBat(player: Player, on: boolean)
	local track = batTracks[player]
	if track then
		track:Stop(0.1)
		batTracks[player] = nil
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child.Name == "JunkyardBat" or child.Name == "JunkyardGlove" then
				child:Destroy()
			end
		end
	end
	local state = states[player]
	if not state or not character then
		player:SetAttribute("BatOut", false)
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not on or not hand or not hand:IsA("BasePart") then
		buildGloves(state, character)
		player:SetAttribute("BatOut", false)
		return
	end
	buildBat(state, character, hand)
	-- 도구를 든 자세 (toolnone)
	local hold = playCharacterAnim(character, "toolnone", "rbxassetid://507768375", true)
	if hold then
		batTracks[player] = hold
	end
	player:SetAttribute("BatOut", true)
end

-- 단계·꾸미기가 바뀌면 손에 든 방망이 또는 장갑을 다시 만든다
local function refreshBat(state: State)
	setBat(state.player, state.player:GetAttribute("BatOut") == true)
end

-- 되찾을 때: 방망이를 휘두르는 동작 (toolslash) + 끝에서 불꽃
local function swingBat(player: Player)
	local character = player.Character
	if character then
		playCharacterAnim(character, "toolslash", "rbxassetid://522635514", false)
		local bat = character:FindFirstChild("JunkyardBat")
		local burst = bat and bat:FindFirstChild("Burst", true)
		if burst and burst:IsA("ParticleEmitter") then
			task.delay(0.2, function()
				if burst.Parent then
					burst:Emit(30)
				end
			end)
		end
	end
end

-- 되찾기에 성공했을 때: 단계에 따라 도둑이 잠깐 멈추고, 방망이 경험치를 얻는다 (단계가 오르면 알림)
local function onBatReclaim(state: State, thief: State)
	local level = batLevelOf(state)
	if level.stun > 0 then
		thief.stunnedUntil = math.max(thief.stunnedUntil, now() + level.stun)
		syncUpgradeAttributes(thief)
		applySpeed(thief)
	end
	if state.loading or os.clock() - (state.batXpAt[thief.player] or -math.huge) < Config.BatXpCooldown then
		return -- 같은 도둑에게서는 잠시 경험치 없음 (친구끼리 주고받기 방지)
	end
	state.batXpAt[thief.player] = os.clock()
	local gain = Config.BatXpPerReclaim * (if state.passes.BatGrowth then Config.BatGrowthXpMultiplier else 1)
	state.batXp = math.min(state.batXp + gain, 1000000)
	local before = state.batLevel
	while Config.BatLevels[state.batLevel + 1] and state.batXp >= Config.BatLevels[state.batLevel + 1].xp do
		state.batLevel += 1
	end
	syncBat(state)
	if state.batLevel > before then
		notify(state.player, "Info", ("🏏 방망이가 %s(으)로 자랐어요!"):format(batLevelOf(state).name))
		refreshBat(state)
		JunkyardSave.saveNow(state.player)
	end
end

-- 게임 돈으로 방망이 다음 단계 (성장 2배 게임패스면 반값)
local function buyBatLevel(state: State)
	local nextLevel = Config.BatLevels[state.batLevel + 1]
	if not nextLevel then
		notify(state.player, "Alert", "이미 최고 단계 방망이예요.")
		return
	end
	local cost = math.floor(nextLevel.cost * (if state.passes.BatGrowth then Config.BatGrowthCostRate else 1))
	if state.money < cost then
		notify(state.player, "Alert", ("돈이 부족해요. (%s 필요)"):format(Config.formatMoney(cost)))
		return
	end
	setMoney(state, state.money - cost)
	state.batLevel += 1
	state.batXp = math.max(state.batXp, nextLevel.xp) -- 경험치 막대도 그 단계부터
	syncBat(state)
	notify(state.player, "Info", ("🏏 %s(으)로 강화했어요!"):format(nextLevel.name))
	refreshBat(state)
	JunkyardSave.saveNow(state.player)
end

-- 꾸미기 고르기 ("" = 성장 단계 모양). 가진 게임패스만
local function setBatSkin(state: State, key: string)
	if key ~= "" and (Config.BatSkins[key] == nil or state.passes[key] ~= true) then
		return
	end
	state.batSkin = key
	syncBat(state)
	refreshBat(state)
	JunkyardSave.saveNow(state.player)
end

-- 들고 가는 로봇 버튼: 주인·빼앗긴 사람은 한 번 눌러 "되찾기"(방망이), 다른 사람은 길게 눌러 "빼앗기"
snatchHandler = function(player: Player, target: State, prompt: ProximityPrompt)
	local state = states[player]
	if not state or state == target then
		return
	end
	local began = state.holdStart[prompt]
	state.holdStart[prompt] = nil
	local carry = target.carry
	local root = rootOf(player)
	local targetRoot = rootOf(target.player)
	-- 되찾기(주인·빼앗긴 사람)는 방망이 단계만큼 조금 더 멀리서도 된다
	local reclaiming = carry ~= nil and ((carry.fromBase ~= nil and carry.fromBase.owner == player) or carry.snatchedFrom == player)
	local reach = Config.SnatchRange + (if reclaiming then batLevelOf(state).range else 0)
	if not carry or not root or not targetRoot or (root.Position - targetRoot.Position).Magnitude > reach then
		return
	end
	-- 내 받침대에서 훔쳐 가는 로봇: 주인이 한 번 눌러 방망이로 되찾는다 (받침대로 돌아간다)
	if carry.fromBase then
		if carry.fromBase.owner == player then
			if player:GetAttribute("BatOut") ~= true then
				notify(player, "Alert", "🏏 방망이를 들어야 되찾을 수 있어요! ([2] 키 또는 🏏 버튼)")
				return
			end
			swingBat(player)
			returnStolen(target, "방망이로 되찾음")
			onBatReclaim(state, target)
		else
			notify(player, "Alert", "받침대에서 훔친 로봇은 주인만 되찾을 수 있어요.")
		end
		return
	end
	-- 나에게서 빼앗아 간 로봇: 한 번 눌러 방망이로 되찾는다 (빼앗긴 직후 잠깐은 불가)
	if carry.snatchedFrom == player then
		if now() < (carry.protectUntil or 0) then
			notify(player, "Alert", "잠깐! 조금 뒤에 되찾을 수 있어요.")
		elseif state.carry then
			notify(player, "Alert", "이미 로봇을 들고 있어요.")
		elseif player:GetAttribute("BatOut") ~= true then
			notify(player, "Alert", "🏏 방망이를 들어야 되찾을 수 있어요! ([2] 키 또는 🏏 버튼)")
		else
			swingBat(player)
			if returnSnatched(target, "방망이로 되찾음") then
				onBatReclaim(state, target)
			end
		end
		return
	end
	-- 빼앗기는 실제로 길게 눌렀는지 확인 (도둑 장갑이면 짧게)
	local required = if now() < state.glovesUntil then Config.GlovesHold else Config.StealHold
	if not began or os.clock() - began < required - 0.25 then
		return
	end
	if needGloves(state) then
		return
	end
	if not state.base or state.loading or player:GetAttribute("Mode") ~= "Junkyard" or now() < state.stunnedUntil then
		notify(player, "Alert", "지금은 빼앗을 수 없어요.")
		return
	end
	if state.carry then
		notify(player, "Alert", "이미 로봇을 들고 있어요.")
		return
	end
	if now() < (carry.protectUntil or 0) then
		notify(player, "Alert", "방금 주인이 바뀐 로봇이라 잠시 빼앗을 수 없어요.")
		return
	end
	if target.base and insideBase(target.base, targetRoot.Position) then
		notify(player, "Alert", "자기 기지 안에 있는 사람의 로봇은 빼앗을 수 없어요.")
		return
	end
	if state.rebirth - target.rebirth >= Config.ProtectionGap then
		notify(player, "Alert", ("초보 보호: 환생 단계가 %d 이상 낮은 사람의 로봇은 빼앗을 수 없어요."):format(Config.ProtectionGap))
		return
	end
	if isNewbie(target) then
		notify(player, "Alert", "🌱 새싹 보호 중인 사람의 로봇은 빼앗을 수 없어요.")
		return
	end
	local locked = variantLock(state, carry.robotId)
	if locked then
		notify(player, "Alert", locked)
		return
	end
	local robotId = carry.robotId
	endCarry(target)
	startCarry(state, robotId, nil, nil)
	gloveBurst(player)
	local taken = state.carry
	if taken then
		taken.snatchedFrom = target.player
		taken.protectUntil = now() + Config.SnatchProtect
	end
	syncCarryAttributes(state)
	notify(player, "Info", ("%s을(를) 빼앗았어요! 되찾기 전에 내 기지로!"):format(robotLabel(robotId)))
	notify(target.player, "Stolen", ("⚠ %s님이 들고 가던 %s을(를) 빼앗았어요! 쫓아가서 눌러서 되찾으세요!"):format(player.DisplayName, robotLabel(robotId)))
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
			applyExpansion(base, state.expand)
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
	applyExpansion(base, 0)
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
	return { money = money, catalog = table.clone(state.catalog), pads = pads, upgrades = table.clone(state.upgrades), empCharges = state.empCharges, rebirth = state.rebirth, variantCatalog = table.clone(state.variantCatalog), totalEarned = math.floor(state.totalEarned), tutorial = state.tutorial, expand = state.expand, titles = table.clone(state.titles), selectedTitle = state.selectedTitle, batLevel = state.batLevel, batXp = state.batXp, batSkin = state.batSkin, referredBy = state.referredBy, referralPaid = state.referralPaid, playTime = state.playTime, invites = state.invites, dailyStep = state.dailyStep, dailyLast = state.dailyLast }
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
	if needGloves(state) then
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
	local price = Config.robotValue(item.robotId) -- 로봇마다 가격이 다르다 (벨트 로봇은 변종이 아니다)
	if state.money < price then
		notify(state.player, "Alert", ("돈이 %s 부족해요."):format(Config.formatMoney(price - state.money)))
		return
	end
	if not Belt.take(itemId) then
		notify(state.player, "Alert", "아쉬워요! 다른 사람이 먼저 샀어요.")
		return
	end
	setMoney(state, state.money - price)
	-- 환생한 사람은 살 때 변종(금색·다이아·무지개)이 나올 수 있다. 벨트에 보이는 로봇은 모두에게 같다
	local variantId = Config.rollVariant(state.rebirth)
	local robotKey = if variantId then item.robotId .. "@" .. variantId else item.robotId
	startCarry(state, robotKey, nil, nil)
	gloveBurst(state.player)
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
	if needGloves(state) then
		return
	end
	-- 초보 보호: 환생 단계가 ProtectionGap 이상 낮은 사람의 로봇은 훔칠 수 없다
	local victim = states[base.owner]
	if victim and state.rebirth - victim.rebirth >= Config.ProtectionGap then
		notify(state.player, "Alert", ("초보 보호: 환생 단계가 %d 이상 낮은 사람의 로봇은 훔칠 수 없어요."):format(Config.ProtectionGap))
		return
	end
	if victim and isNewbie(victim) then
		notify(state.player, "Alert", "🌱 새싹 보호 중인 사람의 로봇은 훔칠 수 없어요.")
		return
	end
	if now() < base.lockedUntil then
		notify(state.player, "Alert", "방어막이 켜진 기지예요.")
		return
	end
	local locked = variantLock(state, robotId)
	if locked then
		notify(state.player, "Alert", locked)
		return
	end
	setPadRobot(base, padIndex, nil)
	base.reserved[padIndex] = true
	startCarry(state, robotId, base, padIndex)
	gloveBurst(state.player)
	if states[base.owner] then
		refreshIncome(states[base.owner])
	end
	notify(state.player, "Info", ("%s을(를) 훔쳤어요! 주인에게 잡히기 전에 내 기지로!"):format(robotLabel(robotId)))
	-- "Stolen": 화면에서는 빨간 알림 + 경보음 (경보기 업그레이드 없이도 도둑맞는 순간엔 울린다)
	notify(base.owner, "Stolen", ("⚠ %s님이 내 %s을(를) 훔쳐 가요! 쫓아가서 로봇을 눌러 되찾으세요!"):format(state.player.DisplayName, robotLabel(robotId)))
end

-- 상점 ------------------------------------------------------------------------
local function buyUpgrade(state: State, id: string)
	local upgrade = Config.Upgrades[id]
	if not upgrade or state.loading then
		return
	end
	local level = state.upgrades[id] or 0
	local cost = Config.upgradeCost(id, level, state.rebirth)
	if not cost then
		notify(state.player, "Info", upgrade.name .. "은(는) 최고 단계예요.")
		return
	end
	if level >= Config.upgradeCap(id, state.expand) then
		notify(state.player, "Alert", ("%s을(를) 더 올리려면 🏗 구역 확장 %d단계가 필요해요."):format(upgrade.name, state.expand + 1))
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

-- 구역 확장: 기지가 뒤로 넓어지고 받침대 자리가 생긴다 (환생해도 유지되므로 바로 저장)
local function buyExpand(state: State)
	local base = state.base
	if state.loading or not base then
		return
	end
	local cost = Config.Expansion.Costs[state.expand + 1]
	if not cost then
		notify(state.player, "Info", "이미 가장 넓은 기지예요.")
		return
	end
	if state.money < cost then
		notify(state.player, "Alert", ("구역 확장: 돈이 %s 부족해요."):format(Config.formatMoney(cost - state.money)))
		return
	end
	setMoney(state, state.money - cost)
	state.expand += 1
	state.player:SetAttribute("Expand", state.expand)
	applyExpansion(base, state.expand)
	notify(state.player, "Info", ("🏗 구역 확장 %d단계 완료! 받침대 자리 +%d · 받침대 추가·터보 신발 단계가 더 열렸어요"):format(state.expand, Config.Expansion.PadsPerLevel))
	if state.player:GetAttribute("SaveOff") == false then
		JunkyardSave.saveNow(state.player)
	end
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
	-- EMP는 방어막이 켜진 남의 기지 가까이에서만 (가장 가까운 기지 하나). 없으면 돈을 쓰지 않고 거절
	local empTarget: Base? = nil
	if id == "EMP" then
		local nearest = Config.EmpRange
		for _, base in bases do
			local owner = base.owner
			if owner and owner ~= state.player and t < base.lockedUntil then
				local offset = root.Position - base.center
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance <= nearest then
					nearest = distance
					empTarget = base
				end
			end
		end
		if not empTarget then
			notify(state.player, "Alert", "⚡ EMP는 방어막이 켜진 남의 기지 가까이에서 써야 해요.")
			return
		end
		local ownerState = if empTarget.owner then states[empTarget.owner] else nil
		if ownerState and isNewbie(ownerState) then
			notify(state.player, "Alert", "🌱 새싹 보호 중인 사람의 기지에는 EMP를 쓸 수 없어요.")
			return
		end
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
	if id == "EMP" and empTarget then
		-- 방어막 남은 시간을 줄인다 (다시 켤 수 있는 시각도 같은 만큼 당긴다)
		state.empReadyAt = t + Config.EmpCooldown
		empBurst(root.Position)
		local left = empTarget.lockedUntil - t
		local cut = left * (1 - Config.EmpShieldCut)
		empTarget.lockedUntil -= cut
		empTarget.lockCooldownUntil -= cut
		empTarget.model:SetAttribute("LockedUntil", empTarget.lockedUntil)
		local owner = empTarget.owner
		if owner then
			owner:SetAttribute("LockedUntil", empTarget.lockedUntil)
			owner:SetAttribute("LockCooldownUntil", empTarget.lockCooldownUntil)
			notify(owner, "Stolen", ("⚡ %s님의 EMP! 방어막이 절반으로 줄었어요 (남은 %d초)"):format(state.player.DisplayName, math.ceil(left - cut)))
		end
		notify(state.player, "Info", ("⚡ EMP 명중! %s님의 방어막이 %d초 → %d초"):format(if owner then owner.DisplayName else "?", math.ceil(left), math.ceil(left - cut)))
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
	JunkyardRanking.refreshSoon() -- 순위판에 환생을 바로 반영
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
	if carry.snatchedFrom then
		notify(carry.snatchedFrom, "Alert", ("%s님이 빼앗은 %s을(를) 가져가 버렸어요."):format(state.player.DisplayName, robotLabel(robotId)))
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
		expand = 0,
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

-- 기지 안 로봇 재배치: 두 받침대의 로봇을 맞바꾼다 (빈 받침대면 그냥 옮긴다). 내 기지 안에서만
local function swapPads(state: State, from: unknown, to: unknown)
	local base = state.base
	local root = rootOf(state.player)
	if not base or state.loading or not root or typeof(from) ~= "number" or typeof(to) ~= "number" then
		return
	end
	local limit = math.min(#base.pads, padLimit(base))
	if from ~= math.floor(from) or to ~= math.floor(to) or from == to or from < 1 or to < 1 or from > limit or to > limit then
		return
	end
	if not insideBase(base, root.Position) then
		notify(state.player, "Alert", "내 기지 안에서만 로봇을 옮길 수 있어요.")
		return
	end
	if base.reserved[from] or base.reserved[to] then
		notify(state.player, "Alert", "도둑이 들고 가는 중인 자리는 옮길 수 없어요.")
		return
	end
	local robotFrom = base.robots[from]
	if not robotFrom then
		return
	end
	local robotTo = base.robots[to]
	setPadRobot(base, from, robotTo)
	setPadRobot(base, to, robotFrom)
	refreshIncome(state)
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
	elseif action == "Expand" then
		buyExpand(state)
	elseif action == "Bat" and typeof(arg) == "boolean" then
		setBat(player, arg)
	elseif action == "BatLevel" and not state.loading then
		buyBatLevel(state)
	elseif action == "BatSkin" and typeof(arg) == "string" and not state.loading then
		setBatSkin(state, arg)
	elseif action == "Swap" and typeof(arg) == "table" then
		local request = arg :: any
		swapPads(state, request.from, request.to)
	elseif action == "Item" and typeof(arg) == "string" then
		useItem(state, arg)
	elseif action == "Rebirth" then
		rebirth(state)
	elseif action == "Tutorial" and (arg == "Shop" or arg == "Catalog") then
		advanceTutorial(state, arg :: string) -- 화면을 연 단계만 (보상 없음, 순서가 맞을 때만)
	elseif action == "Title" and typeof(arg) == "string" and not state.loading then
		if arg == "None" or state.titles[arg] == true then
			state.selectedTitle = arg
			player:SetAttribute("SelectedTitle", arg)
			applyTitle(state)
			JunkyardSave.saveNow(player)
		end
	elseif action == "Donate" then
		JunkyardGiantRobot.donate(player, arg) -- 버튼 번호만 받고 금액·거리·돈은 모듈이 검사
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
	-- 순위판 위 CCTV: 전체 서버 환생 1위의 기지 생중계
	local cctv = rankings and rankings:FindFirstChild("CCTV")
	local screen = cctv and cctv:FindFirstChild("Screen")
	if screen and screen:IsA("BasePart") then
		JunkyardCCTV.start(screen, {
			liveLayout = function(userId: number): JunkyardCCTV.Layout?
				for player, state in states do
					if player.UserId == userId and state.base and not state.loading then
						local pads: { [number]: string } = {}
						for index, robotId in state.base.robots do
							pads[index] = robotId
						end
						return { userId = userId, name = player.DisplayName, rebirth = state.rebirth, expand = state.expand, pads = pads, live = true }
					end
				end
				return nil
			end,
			makeRobot = function(key: string): Model
				return makeRobotModel(key, true)
			end,
		})
	end
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
			for _, kind in { "Income", "Collect" } do
				if title == Config.TitleNames["Contest_" .. kind] then
					grantTitle(state, "Contest_" .. kind)
				end
			end
		end
	end,
	notifyAll = notifyAll,
})

-- 협력 거대 로봇 ------------------------------------------------------------------
JunkyardGiantRobot.start({
	getPlayers = function()
		local list = {}
		for player, state in states do
			if state.base and not state.loading then
				table.insert(list, player)
			end
		end
		return list
	end,
	incomeOf = function(player)
		local state = states[player]
		return if state and state.base then baseIncome(state.base, state) else 0
	end,
	takeMoney = function(player, amount)
		local state = states[player]
		if not state or state.loading or state.money < amount then
			return false
		end
		setMoney(state, state.money - amount)
		return true
	end,
	notify = notify,
	notifyAll = notifyAll,
	setTitle = function(player, title)
		local state = states[player]
		if state then
			player:SetAttribute("RobotTitle", title)
			if title then
				grantTitle(state, "Mechanic")
			end
		end
	end,
	onBoostChanged = function()
		for _, state in states do
			refreshIncome(state)
		end
	end,
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
	return Config.pickRobot(rarity)
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
	if Config.BatSkins[key] and not state.loading then
		setBatSkin(state, key) -- 새로 산 방망이 꾸미기는 바로 착용
	end
	notify(player, "Info", ("%s 구매 고마워요! 바로 적용됐어요."):format(Config.GamePasses[key].name))
end

JunkyardStore.start({ grantProduct = grantProduct, onPassOwned = onPassOwned })

-- 친구 초대 보상 (B-50) ------------------------------------------------------------
-- 초대받아 처음 들어온 사람: 환영 선물(고급 로봇). 그 사람이 Config.Referral.PlaySeconds초 놀면 초대한 사람에게 희귀 로봇.
-- 부계정 악용 방지: 처음 하는 계정만, 초대한 사람 1명당 하루 DailyLimit명까지. 기록은 JunkyardReferral(Referrals_v1)

-- 선물 로봇을 빈 받침대에 둔다. 받침대가 꽉 차면 그 로봇 가격만큼 돈으로 준다
local function giveGiftRobot(state: State, robotId: string, reason: string)
	local base = state.base
	local padIndex = if base then freePad(base) else nil
	if base and padIndex then
		setPadRobot(base, padIndex, robotId)
		addToCatalog(state, robotId)
		refreshIncome(state)
		notify(state.player, "Info", ("🎁 %s: %s이(가) 기지에 도착했어요!"):format(reason, robotLabel(robotId)))
	else
		local value = Config.robotValue(robotId)
		setMoney(state, state.money + value)
		notify(state.player, "Info", ("🎁 %s: 받침대가 꽉 차서 %s 대신 %s 돈을 드렸어요."):format(reason, robotLabel(robotId), Config.formatMoney(value)))
	end
end

-- 나를 초대한 사람 (Roblox 초대로 들어왔을 때만 있다)
local function referrerOf(player: Player): number?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local id = if ok and typeof(joinData) == "table" then joinData.ReferredByPlayerId else nil
	if typeof(id) == "number" and id > 0 and id == math.floor(id) and id ~= player.UserId then
		return id
	end
	return nil
end

-- 초대한 사람: 쌓인 보상을 받는다 (접속할 때, 2분마다, 같은 서버의 친구가 조건을 채웠을 때)
local function claimReferrals(state: State)
	local player = state.player
	if state.referralBusy or state.loading or player:GetAttribute("SaveOff") ~= false then
		return
	end
	state.referralBusy = true
	local count, total = JunkyardReferral.claim(player.UserId)
	state.referralBusy = false
	if states[player] ~= state then
		if count > 0 then
			warn(("[Junkyard] %d님이 초대 보상 %d개를 받기 전에 나갔어요"):format(player.UserId, count))
		end
		return
	end
	local invites = math.max(state.invites + count, total or 0)
	if count <= 0 and invites == state.invites then
		return
	end
	state.invites = invites
	player:SetAttribute("Invites", invites)
	if count > 0 then
		notify(player, "Info", ("👥 초대한 친구가 %d분 넘게 놀았어요! 고마워요 (지금까지 %d명)"):format(Config.Referral.PlaySeconds // 60, invites))
		for _ = 1, count do
			giveGiftRobot(state, Config.pickRobot(Config.Referral.RewardRarity), "친구 초대 선물")
		end
	end
	if invites >= Config.Referral.TitleInvites then
		grantTitle(state, "Inviter")
	end
	JunkyardSave.saveNow(player)
end

-- 초대받은 사람이 조건 시간을 채웠다: 초대한 사람에게 보상을 쌓는다 (한 번만)
local function payReferral(state: State)
	state.referralPaid = true -- 결과가 나올 때까지 다시 부르지 않게
	task.spawn(function()
		local outcome = JunkyardReferral.credit(state.referredBy, JunkyardReferral.today())
		if states[state.player] ~= state then
			return
		end
		if outcome == "failed" then
			state.referralPaid = false
			state.playTime = math.max(0, Config.Referral.PlaySeconds - 60) -- 1분 뒤 다시 시도
			return
		end
		JunkyardSave.saveNow(state.player)
		if outcome == "ok" then
			notify(state.player, "Info", "🎉 초대해 준 친구에게 고마움의 선물이 갔어요!")
			local inviter = Players:GetPlayerByUserId(state.referredBy)
			local inviterState = inviter and states[inviter]
			if inviterState then
				claimReferrals(inviterState)
			end
		end
	end)
end

-- 매일 접속 보상 (B-51) ------------------------------------------------------------
-- 하루(한국 시간 자정 기준)에 한 번 "Daily" 요청으로 받는다. 어제 받았으면 다음 날짜, 아니면 1일부터. 7일 다음은 다시 1일.
local function dailyToday(): number
	return (os.time() + Config.Daily.UtcOffset) // 86400
end

local function syncDaily(state: State)
	state.player:SetAttribute("DailyStep", state.dailyStep)
	state.player:SetAttribute("DailyLast", state.dailyLast)
end

local function claimDaily(state: State)
	local player = state.player
	local base = state.base
	if state.loading or not base then
		return
	end
	if player:GetAttribute("SaveOff") ~= false then
		notify(player, "Alert", "이번 접속은 저장이 꺼져 있어서 매일 보상을 받을 수 없어요.")
		return
	end
	local today = dailyToday()
	if state.dailyLast == today then
		notify(player, "Alert", "오늘 보상은 이미 받았어요. 내일 또 와요!")
		return
	end
	local rewards = Config.Daily.Rewards
	local step = if state.dailyLast == today - 1 then state.dailyStep % #rewards + 1 else 1
	local reward = rewards[step]
	state.dailyStep = step
	state.dailyLast = today
	syncDaily(state)
	if reward.kind == "Money" then
		local amount = math.max(reward.min or 0, math.floor(baseIncome(base, state) * 60 * (reward.minutes or 0)))
		setMoney(state, state.money + amount)
		notify(player, "Money", ("📅 %d일째 보상: +%s"):format(step, Config.formatMoney(amount)))
	elseif reward.kind == "Emp" then
		state.empCharges += reward.count or 1
		syncPasses(state)
		notify(player, "Info", ("📅 %d일째 보상: 무료 EMP %d개! (남은 %d개)"):format(step, reward.count or 1, state.empCharges))
	else
		giveGiftRobot(state, Config.pickRobot(reward.rarity or "Rare"), ("📅 %d일째 보상"):format(step))
	end
	JunkyardSave.saveNow(player)
end

local dailyRequestAt: { [Player]: number } = {}
actionRemote.OnServerEvent:Connect(function(player: Player, action: unknown)
	if action ~= "Daily" then
		return
	end
	local state = states[player]
	if not state or os.clock() - (dailyRequestAt[player] or -math.huge) < 1 then
		return
	end
	dailyRequestAt[player] = os.clock()
	claimDaily(state)
end)
Players.PlayerRemoving:Connect(function(player)
	dailyRequestAt[player] = nil
end)

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
		state.titles = data.titles
		state.selectedTitle = data.selectedTitle
		state.batLevel = data.batLevel
		state.batXp = data.batXp
		state.batSkin = data.batSkin
		state.referredBy = data.referredBy
		state.referralPaid = data.referralPaid
		state.playTime = data.playTime
		state.invites = data.invites
		player:SetAttribute("Invites", state.invites)
		state.dailyStep = data.dailyStep
		state.dailyLast = data.dailyLast
		syncDaily(state)
		syncBat(state)
		setMoney(state, data.money)
		state.totalEarned = data.totalEarned
		player:SetAttribute("Newbie", isNewbie(state))
		setTutorial(state, data.tutorial)
		state.rebirth = data.rebirth
		syncRebirth(state)
		setCatalog(state, data.catalog, data.variantCatalog)
		state.upgrades = data.upgrades
		syncUpgradeAttributes(state)
		state.empCharges = data.empCharges
		state.expand = data.expand
		player:SetAttribute("Expand", state.expand)
		applyExpansion(base, state.expand) -- 받침대를 채우기 전에 구역을 펼친다
		state.passes = JunkyardStore.checkPasses(player)
		syncPasses(state)
		refreshBat(state) -- 단계·꾸미기(게임패스)에 맞는 장갑 효과
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
		-- 친구 초대로 처음 온 사람: 초대한 사람을 기억하고 환영 선물을 준다
		if status == "new" then
			local referrer = referrerOf(player)
			if referrer then
				state.referredBy = referrer
				giveGiftRobot(state, Config.pickRobot(Config.Referral.WelcomeRarity), "친구 초대 환영 선물")
				notify(player, "Info", ("👥 %d분 넘게 놀면 초대해 준 친구도 선물을 받아요!"):format(Config.Referral.PlaySeconds // 60))
			end
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
	if data then
		task.spawn(claimReferrals, state) -- 꺼져 있는 동안 쌓인 친구 초대 보상
	end
end

-- 플레이어 ----------------------------------------------------------------------
local function onCharacterAdded(state: State, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	setBat(state.player, false) -- 다시 태어나면 장갑
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
		expand = 0,
		titles = {},
		selectedTitle = "",
		batLevel = 1,
		batXp = 0,
		batSkin = "",
		batXpAt = {},
		referredBy = 0,
		referralPaid = false,
		playTime = 0,
		invites = 0,
		referralBusy = false,
		dailyStep = 0,
		dailyLast = 0,
	}
	player:SetAttribute("Expand", 0)
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
		elseif state.carry and state.carry.snatchedFrom and returnSnatched(state, "도둑이 쓰러짐") then
			-- 빼앗은 로봇은 원래 사람에게 돌아갔다
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
	batTracks[player] = nil
	if state.carry and state.carry.fromBase then
		returnStolen(state, "도둑이 나감")
	elseif state.carry and state.carry.snatchedFrom then
		returnSnatched(state, "도둑이 나감")
	end
	-- 나간 사람에게서 빼앗아 가던 로봇은 빼앗은 사람 것이 된다
	for _, other in states do
		if other.carry and other.carry.snatchedFrom == player then
			other.carry.snatchedFrom = nil
			syncCarryAttributes(other)
		end
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

-- 친구 초대 보상 확인: 2분마다 (초대한 사람이 다른 서버에 있었거나 꺼져 있었을 때 쌓인 것)
task.spawn(function()
	while true do
		task.wait(120)
		local list = {}
		for _, state in states do
			table.insert(list, state)
		end
		for _, state in list do
			task.spawn(claimReferrals, state)
			task.wait(1)
		end
	end
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
	-- 친구 초대 시험: 대상(음수 계정)을 "음수 계정 DebugReferral이 초대해서 처음 온 사람"으로 만들고 남은 시간을 5초로 (환영 선물도 준다)
	workspace:GetAttributeChangedSignal("DebugReferral"):Connect(function()
		local inviterId = workspace:GetAttribute("DebugReferral")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugReferral", nil)
		if typeof(userId) ~= "number" or userId >= 0 or typeof(inviterId) ~= "number" or inviterId >= 0 or inviterId == userId then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local state = player and states[player]
		if state and not state.loading then
			state.referredBy = inviterId
			state.referralPaid = false
			state.playTime = Config.Referral.PlaySeconds - 5
			giveGiftRobot(state, Config.pickRobot(Config.Referral.WelcomeRarity), "친구 초대 환영 선물")
		end
	end)
	-- 매일 보상 시험: 대상(음수 계정)의 마지막으로 받은 날을 n일 앞당긴다 (1 = 어제 받은 것처럼 → 다음 날짜, 2 이상 = 하루 빠뜨림 → 1일부터)
	workspace:GetAttributeChangedSignal("DebugDailyBack"):Connect(function()
		local days = workspace:GetAttribute("DebugDailyBack")
		local userId = workspace:GetAttribute("DebugMoneyUserId")
		workspace:SetAttribute("DebugDailyBack", nil)
		if typeof(userId) ~= "number" or userId >= 0 or typeof(days) ~= "number" or days < 1 or days > 30 or days ~= math.floor(days) then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local state = player and states[player]
		if state and not state.loading and state.dailyLast > 0 then
			state.dailyLast -= days
			syncDaily(state)
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
	-- 거대 로봇 시험: 진행률(0~1, 1이면 완성) / 가동·쉬는 시간을 n초로 줄이기
	workspace:GetAttributeChangedSignal("DebugGiantProgress"):Connect(function()
		local fraction = workspace:GetAttribute("DebugGiantProgress")
		workspace:SetAttribute("DebugGiantProgress", nil)
		if typeof(fraction) == "number" then
			JunkyardGiantRobot.debugSetProgress(fraction)
		end
	end)
	workspace:GetAttributeChangedSignal("DebugGiantSkip"):Connect(function()
		local seconds = workspace:GetAttribute("DebugGiantSkip")
		workspace:SetAttribute("DebugGiantSkip", nil)
		if typeof(seconds) == "number" and seconds >= 0 then
			JunkyardGiantRobot.debugSkip(seconds)
		end
	end)
end

-- 0.2초마다: 배치, 방어막 / 1초마다: 수입 (되찾기는 이제 길게 누르기) ---------------------------
task.spawn(function()
	local incomeTimer = 0
	while true do
		local dt = task.wait(0.2)
		local t = now()
		for _, state in states do
			if state.carry then
				tryPlace(state) -- 들고 있는 로봇이 내 기지 안에 들어오면 놓는다
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
				elseif state.carry and state.carry.snatchedFrom then
					returnSnatched(state, "도둑이 떨어짐")
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
			-- 친구 초대: 초대받은 사람이 논 시간 (Config.Referral.PlaySeconds가 되면 초대한 사람에게 보상, 한 번만)
			for player, state in states do
				if state.referredBy ~= 0 and not state.referralPaid and not state.loading and player:GetAttribute("SaveOff") == false then
					state.playTime += 1
					if state.playTime >= Config.Referral.PlaySeconds then
						payReferral(state)
					end
				end
			end
			for _, base in bases do
				local owner = base.owner
				if owner and states[owner] then
					local income = baseIncome(base, states[owner])
					JunkyardContest.record(owner, "Income", income)
					base.vault += income
					states[owner].totalEarned += income
					-- 새싹 보호가 끝나는 순간 알린다
					local ownerState = states[owner]
					if not ownerState.loading then
						local newbie = isNewbie(ownerState)
						if owner:GetAttribute("Newbie") ~= newbie then
							if owner:GetAttribute("Newbie") == true and not newbie then
								notify(owner, "Alert", "🌱 새싹 보호가 끝났어요! 이제 로봇을 도둑맞을 수 있으니 방어막을 잘 쓰세요.")
							end
							owner:SetAttribute("Newbie", newbie)
						end
					end
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
