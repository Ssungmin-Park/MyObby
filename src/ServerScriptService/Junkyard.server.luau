--!strict
-- Junkyard: 로봇 고물상 타이쿤 서버 로직 (멀티플레이). 모든 판정은 서버에서 한다.
-- 흐름:
--   벨트에서 로봇 구매(돈) → 머리 위에 들고 내 기지로 → 빈 받침대에 자동 배치 → 초당 수입이 금고에 쌓임
--   → 금고를 밟아 돈 받기 → 더 비싼 로봇 구매 → 도감 등급 세트 완성 시 수입 배수·칭호
-- 멀티플레이:
--   다른 사람 기지의 로봇을 "훔치기"(1.5초 누르기) → 들고 내 기지로 가면 내 것. 주인이 가까이 오면 떨어뜨려 되돌아간다.
--   기지 주인은 방어막(60초, 쿨타임 60초)으로 막을 수 있다. 잠긴 기지 안의 다른 사람은 밖으로 밀려난다.
-- 화면 표시는 클라이언트(JunkyardHud), 숫자는 ReplicatedStorage/Modules/JunkyardConfig.
-- 아직 저장하지 않는다(2단계). 나가면 기지가 비워진다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local Belt = require(script.Parent:WaitForChild("JunkyardBelt"))

local junkyard = workspace:WaitForChild("Junkyard")
local basesFolder = junkyard:WaitForChild("Bases")
local checkpoints = workspace:WaitForChild("Checkpoints")
local obbySpawn = workspace:WaitForChild("SpawnLocation") :: BasePart
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
	multiplier: number,
	moneyValue: IntValue?,
	incomeValue: IntValue?,
	lastFullNotice: number,
	lastAction: number,
}

local bases: { Base } = {}
local states: { [Player]: State } = {}

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
	local robot = Config.getRobot(robotId)
	local rarity = Config.rarityOf(robotId)
	return if robot and rarity then ("%s %s"):format(rarity.name, robot.name) else robotId
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
	local color = if rarity then rarity.color else Color3.new(1, 1, 1)
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
	label.Text = if robot and rarity then ("%s [%s]\n초당 %s"):format(robot.name, rarity.name, Config.formatMoney(rarity.income)) else robotId
	label.Parent = billboard
	return model
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
		local rarity = Config.rarityOf(robotId)
		if rarity then
			total += rarity.income
		end
	end
	return total * (if state then state.multiplier else 1)
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
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not best then
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
	local rarity = Config.Rarities[best]
	local label = (tag :: BillboardGui):FindFirstChild("Label") :: TextLabel
	label.Text = ("[%s 수집가]"):format(rarity.name)
	label.TextColor3 = rarity.color
end

local function addToCatalog(state: State, robotId: string)
	if state.catalog[robotId] then
		return
	end
	local before, beforeBest = Config.catalogMultiplier(state.catalog)
	state.catalog[robotId] = true
	local after, best = Config.catalogMultiplier(state.catalog)
	state.multiplier = after
	local ids = {}
	for id in state.catalog do
		table.insert(ids, id)
	end
	state.player:SetAttribute("Catalog", HttpService:JSONEncode(ids))
	state.player:SetAttribute("Multiplier", after)
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
		prompt.ObjectText = if robot then robot.name else robotId
		prompt.Enabled = true
	else
		prompt.Enabled = false
	end
end

local function freePad(base: Base): number?
	for index = 1, #base.pads do
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
	local humanoid = (state.player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.CarrySpeed
	end
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
	local character = state.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
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
	setSign(base, "빈 기지")
end

local function spawnCFrame(base: Base): CFrame
	local spawn = base.model:FindFirstChild("Spawn") :: BasePart
	return spawn.CFrame + Vector3.new(0, 3, 0)
end

-- 행동 ----------------------------------------------------------------------------
local function buy(state: State, itemId: number)
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
	startCarry(state, item.robotId, nil, nil)
	notify(state.player, "Info", ("%s 구매! 기지로 가져가세요."):format(robotLabel(item.robotId)))
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
	base.lockedUntil = t + Config.LockDuration
	base.lockCooldownUntil = base.lockedUntil + Config.LockCooldown
	base.model:SetAttribute("LockedUntil", base.lockedUntil)
	state.player:SetAttribute("LockedUntil", base.lockedUntil)
	state.player:SetAttribute("LockCooldownUntil", base.lockCooldownUntil)
	local shield = base.model:FindFirstChild("Shield") :: BasePart
	shield.Transparency = 0.5
	notify(state.player, "Info", ("방어막 작동! %d초 동안 아무도 훔칠 수 없어요."):format(Config.LockDuration))
end

local function sell(state: State, base: Base, padIndex: number)
	local robotId = base.robots[padIndex]
	local rarity = robotId and Config.rarityOf(robotId)
	if not robotId or not rarity then
		return
	end
	setPadRobot(base, padIndex, nil)
	local gain = math.floor(rarity.price * Config.SellRate)
	setMoney(state, state.money + gain)
	refreshIncome(state)
	notify(state.player, "Info", ("%s 판매 +%s"):format(robotLabel(robotId), Config.formatMoney(gain)))
end

local function steal(state: State, base: Base, padIndex: number)
	local robotId = base.robots[padIndex]
	if not robotId or not base.owner or base.owner == state.player then
		return
	end
	if not state.base then
		notify(state.player, "Alert", "기지가 없어서 훔칠 수 없어요.")
		return
	end
	if state.carry then
		notify(state.player, "Alert", "이미 로봇을 들고 있어요.")
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
end

-- 오비 ↔ 고물상 이동
local function goToObby(state: State)
	if state.carry then
		notify(state.player, "Alert", "로봇을 들고는 갈 수 없어요. 먼저 기지에 두세요.")
		return
	end
	local character = state.player.Character
	if not character then
		return
	end
	state.player:SetAttribute("Mode", "Obby")
	local stats = state.player:FindFirstChild("leaderstats")
	local stage = stats and stats:FindFirstChild("Stage")
	local checkpoint = if stage and stage:IsA("IntValue") then checkpoints:FindFirstChild(tostring(stage.Value)) else nil
	local destination = if checkpoint and checkpoint:IsA("BasePart") then checkpoint else obbySpawn
	character:PivotTo(destination.CFrame + Vector3.new(0, destination.Size.Y / 2 + 3, 0))
end

local function goToJunkyard(state: State)
	local character = state.player.Character
	if not character or not state.base then
		return
	end
	state.player:SetAttribute("Mode", "Junkyard")
	character:PivotTo(spawnCFrame(state.base))
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
	}
	bases[base.index] = base

	for padIndex, pad in pads do
		local prompt = pad:FindFirstChild("RobotPrompt") :: ProximityPrompt
		prompt.HoldDuration = Config.StealHold
		prompt.Triggered:Connect(function(player: Player)
			local state = states[player]
			local root = rootOf(player)
			if not state or not root or (root.Position - pad.Position).Magnitude > prompt.MaxActivationDistance + 3 then
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
	end)
end

local function portal(name: string, handler: (State) -> ())
	local part = junkyard:FindFirstChild(name)
	local prompt = part and part:FindFirstChild("PortalPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			local state = states[player]
			if state then
				handler(state)
			end
		end)
	end
end
portal("ObbyPortal", goToObby)
portal("JunkyardPortal", goToJunkyard)

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
	end
end)

Belt.start(beltRemote, function(robotId: string)
	notifyAll(("✨ %s 로봇이 컨베이어에 나타났어요!"):format(robotLabel(robotId)))
end)

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
	}
	states[player] = state
	player:SetAttribute("Mode", "Junkyard") -- 들어오면 고물상에서 시작 (Respawn 스크립트가 이 값을 본다)
	player:SetAttribute("Catalog", "[]")
	player:SetAttribute("Multiplier", 1)
	syncCarryAttributes(state)
	if not assignBase(state) then
		player:SetAttribute("Mode", "Obby")
		notify(player, "Alert", "이 서버의 기지 6개가 모두 찼어요. 오비를 즐겨 주세요!")
	end
	setMoney(state, Config.StartMoney)
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

	-- 리더보드: Leaderstats가 저장된 진행을 불러온 뒤 leaderstats를 만든다
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 60)
		if not stats or not states[player] then
			return
		end
		local moneyValue = Instance.new("IntValue")
		moneyValue.Name = "돈"
		moneyValue.Value = state.money
		moneyValue.Parent = stats
		local incomeValue = Instance.new("IntValue")
		incomeValue.Name = "초당"
		incomeValue.Parent = stats
		state.moneyValue = moneyValue
		state.incomeValue = incomeValue
		refreshIncome(state)
	end)
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
	if state.base then
		releaseBase(state.base)
	end
	states[player] = nil
end)

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
		incomeTimer += dt
		if incomeTimer >= 1 then
			incomeTimer -= 1
			for _, base in bases do
				local owner = base.owner
				if owner and states[owner] then
					base.vault += baseIncome(base, states[owner])
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
