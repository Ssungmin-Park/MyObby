--!strict
-- JunkyardConfig: 로봇 고물상 타이쿤의 밸런스 데이터. 서버(Junkyard)와 클라이언트(JunkyardHud)가 함께 읽는다.
-- 숫자만 바꿔 난이도를 조절한다. 로봇 id(영문 키)는 저장 데이터에 들어갈 예정이므로 바꾸지 않는다.

export type Rarity = {
	name: string,
	weight: number, -- 벨트에 나올 확률(가중치)
	price: number, -- 벨트에서 살 때 가격
	income: number, -- 초당 수입
	size: number, -- 모형 크기 배수 (희귀할수록 크게)
	color: Color3,
	setBonus: number, -- 이 등급 로봇을 도감에 모두 모으면 수입 +비율 (0.1 = +10%)
}
export type Robot = { id: string, name: string, rarity: string }

local Config = {}

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
Config.Rarities = {
	Common = { name = "일반", weight = 600, price = 25, income = 1, size = 1, color = Color3.fromRGB(176, 186, 196), setBonus = 0.05 },
	Uncommon = { name = "고급", weight = 250, price = 100, income = 4, size = 1.1, color = Color3.fromRGB(120, 210, 120), setBonus = 0.1 },
	Rare = { name = "희귀", weight = 100, price = 500, income = 15, size = 1.2, color = Color3.fromRGB(100, 165, 250), setBonus = 0.15 },
	Epic = { name = "에픽", weight = 40, price = 2500, income = 60, size = 1.35, color = Color3.fromRGB(190, 120, 245), setBonus = 0.25 },
	Legendary = { name = "전설", weight = 9, price = 15000, income = 300, size = 1.5, color = Color3.fromRGB(250, 196, 80), setBonus = 0.4 },
	Mythic = { name = "신화", weight = 1, price = 100000, income = 1500, size = 1.7, color = Color3.fromRGB(255, 90, 120), setBonus = 1 },
} :: { [string]: Rarity }

-- 도감 순서 = 이 목록 순서. 등급마다 3종.
Config.Robots = {
	{ id = "Pippi", name = "삐삐", rarity = "Common" },
	{ id = "Nut", name = "너트", rarity = "Common" },
	{ id = "Sponge", name = "스펀지", rarity = "Common" },
	{ id = "Volt", name = "볼트", rarity = "Uncommon" },
	{ id = "Coil", name = "코일", rarity = "Uncommon" },
	{ id = "Wiper", name = "와이퍼", rarity = "Uncommon" },
	{ id = "Lumi", name = "루미", rarity = "Rare" },
	{ id = "Spring", name = "스프링", rarity = "Rare" },
	{ id = "Radar", name = "레이더", rarity = "Rare" },
	{ id = "GearKing", name = "기어킹", rarity = "Epic" },
	{ id = "Holo", name = "홀로", rarity = "Epic" },
	{ id = "Press", name = "프레스", rarity = "Epic" },
	{ id = "Nova", name = "노바", rarity = "Legendary" },
	{ id = "Atlas", name = "아틀라스", rarity = "Legendary" },
	{ id = "Titan", name = "타이탄", rarity = "Legendary" },
	{ id = "Omega", name = "오메가", rarity = "Mythic" },
	{ id = "Zenith", name = "제니스", rarity = "Mythic" },
	{ id = "Quasar", name = "퀘이사", rarity = "Mythic" },
} :: { Robot }

Config.StartMoney = 50

-- 컨베이어 벨트
Config.BeltInterval = 2.5 -- 새 로봇이 나오는 간격(초)
Config.BeltSpeed = 4 -- 초당 스터드
Config.BeltBuyRange = 14 -- 서버가 허용하는 구매 거리
Config.AnnounceRarities = { Legendary = true, Mythic = true } -- 나오면 서버 전체에 알림

-- 기지
Config.PadsPerBase = 10
Config.SellRate = 0.5 -- 팔 때 받는 비율
Config.CarrySpeed = 11 -- 로봇을 들고 있을 때 걷기 속도 (기본 16)
Config.StealHold = 1.5 -- 훔치기·팔기 버튼을 누르고 있어야 하는 시간(초)
Config.CatchRange = 6 -- 주인이 이 거리 안에 들어오면 도둑이 로봇을 떨어뜨린다
Config.LockDuration = 60 -- 기지 잠금 시간(초)
Config.LockCooldown = 60 -- 잠금이 끝난 뒤 다시 잠글 수 있기까지(초)

-- 떠나 있던 동안의 수입 (다시 들어오면 금고에 쌓여 있다)
Config.OfflineRate = 0.5 -- 평소 수입의 50%
Config.OfflineMaxHours = 3 -- 최대 3시간치

-- 상점 (3-1) ------------------------------------------------------------------
-- 영구 업그레이드: level 0 = 기본(values[1]). 다음 단계 비용 = costs[level + 1]. 저장된다.
export type Upgrade = { name: string, desc: string, category: string, costs: { number }, values: { number } }
Config.MaxPads = 14 -- 받침대 업그레이드 최대 (기본 PadsPerBase 10, 맵에는 받침대 14개가 있다)
Config.UpgradeOrder = { "Pads", "Shoes", "ShieldTime", "Alarm", "Fence" }
Config.Upgrades = {
	Pads = { name = "받침대 추가", desc = "받침대가 2칸 늘어요", category = "Help", costs = { 5000, 50000 }, values = { 10, 12, 14 } },
	Shoes = { name = "터보 신발", desc = "걷기 속도가 빨라져요", category = "Help", costs = { 3000, 30000 }, values = { 16, 19, 22 } },
	ShieldTime = { name = "방어막 강화", desc = "방어막이 더 오래 가요(초)", category = "Defense", costs = { 1000, 10000, 100000 }, values = { 60, 90, 120, 150 } },
	Alarm = { name = "경보기", desc = "누가 내 기지에 들어오면 알리고 그 사람을 빨갛게 표시해요", category = "Defense", costs = { 5000 }, values = { 0, 1 } },
	Fence = { name = "레이저 울타리", desc = "내 기지에 들어온 사람이 3초 동안 느려져요", category = "Defense", costs = { 20000 }, values = { 0, 1 } },
} :: { [string]: Upgrade }

-- 소모 아이템: 가격 = max(minPrice, 내 초당 수입 × incomeSeconds). 부자일수록 비싸진다. 저장되지 않는다.
export type Item = { name: string, desc: string, category: string, minPrice: number, incomeSeconds: number }
Config.ItemOrder = { "EMP", "Gloves" }
Config.Items = {
	EMP = { name = "EMP", desc = "주변 10스터드의 다른 사람을 3초 동안 멈추고, 훔쳐 가던 로봇을 떨어뜨리게 해요", category = "Attack", minPrice = 500, incomeSeconds = 60 },
	Gloves = { name = "도둑 장갑", desc = "5분 동안 훔치기가 1.5초 → 0.6초로 빨라져요", category = "Attack", minPrice = 1000, incomeSeconds = 90 },
} :: { [string]: Item }
Config.EmpRange = 10
Config.EmpStun = 3 -- 초
Config.EmpCooldown = 30
Config.GlovesDuration = 300
Config.GlovesHold = 0.6
Config.FenceSlow = 3 -- 초
Config.FenceSpeed = 8
Config.AlarmCooldown = 10 -- 같은 침입자 알림 간격(초)

-- 희귀 로봇 열차: TrainEvery초마다 TrainDuration초 동안 희귀 이상만, TrainInterval초 간격으로 나온다
Config.TrainEvery = 600
Config.TrainDuration = 30
Config.TrainInterval = 1
Config.TrainRarities = { Rare = true, Epic = true, Legendary = true, Mythic = true }

-- 서버 대회. 보상 시간은 참가자 자신의 시작 시점 초당 수입에 곱한다.
Config.Contest = {
	Interval = 900,
	Duration = 300,
	Warning = 60,
	MinPlayers = 2,
	Order = { "Income", "Collect" },
	Types = {
		Income = { name = "수입왕", mark = "💰" },
		Collect = { name = "수집왕", mark = "🛒" },
	} :: { [string]: { name: string, mark: string } },
	RarityPoints = { Common = 1, Uncommon = 2, Rare = 4, Epic = 7, Legendary = 10, Mythic = 15 } :: { [string]: number },
	Rewards = {
		{ seconds = 120, minimum = 500 },
		{ seconds = 60, minimum = 250 },
		{ seconds = 30, minimum = 100 },
	},
	ParticipationSeconds = 10,
}

-- Robux 상품 (3-2) -------------------------------------------------------------
-- id는 사용자가 Creator Dashboard에서 상품을 만든 뒤 넣는다. 0이면 아직 없음 → 상점에 "준비 중".
-- robux는 화면 표시용 예상 가격이다. 실제 가격은 Creator Dashboard에서 정한 값이 결제창에 나온다.
export type RobuxOffer = { name: string, desc: string, id: number, robux: number }
Config.PassOrder = { "DoubleIncome", "VipBase", "OfflineBoost" }
Config.GamePasses = {
	DoubleIncome = { name = "💰 수입 2배", desc = "모든 로봇 수입이 영구로 2배", id = 0, robux = 399 },
	VipBase = { name = "👑 VIP 기지", desc = "방어막 +30초, 방어막 충전 시간 절반, 머리 위 VIP 표시", id = 0, robux = 249 },
	OfflineBoost = { name = "🌙 오프라인 수입 강화", desc = "떠나 있는 동안 수입 50% → 100%, 최대 3시간 → 8시간", id = 0, robux = 149 },
} :: { [string]: RobuxOffer }
Config.ProductOrder = { "EmpPack", "InstantShield", "RareRain" }
Config.Products = {
	EmpPack = { name = "⚡ EMP 5개", desc = "돈 없이 쓰는 EMP 5번 (충전 시간은 같아요, 저장돼요)", id = 3732684191, robux = 49 },
	InstantShield = { name = "🛡 즉시 방어막", desc = "충전 중이어도 바로 방어막을 켜요", id = 3732684298, robux = 25 },
	RareRain = { name = "✨ 희귀 로봇 비 (서버 전체)", desc = "60초 동안 모두의 벨트에 희귀 이상 5배 + 나에게는 희귀 이상 로봇 1개 확정 선물", id = 3732684420, robux = 99 },
} :: { [string]: RobuxOffer }
Config.EmpPackCharges = 5
Config.VipShieldBonus = 30 -- 초
Config.VipCooldownRate = 0.5
Config.OfflineBoostRate = 1
Config.OfflineBoostHours = 8
Config.IncomePassMultiplier = 2
Config.RainDuration = 60
Config.RainMultiplier = 5
Config.RainRarities = { Rare = true, Epic = true, Legendary = true, Mythic = true }

-- 희귀 로봇 비를 산 사람에게 주는 확정 선물 로봇의 등급 확률(%) (RainRarities 안에서 원래 가중치 비율)
function Config.rainGiftOdds(): { [string]: number }
	local total = 0
	for _, id in Config.RarityOrder do
		if Config.RainRarities[id] then
			total += Config.Rarities[id].weight
		end
	end
	local odds = {}
	for _, id in Config.RarityOrder do
		if Config.RainRarities[id] then
			odds[id] = Config.Rarities[id].weight / total * 100
		end
	end
	return odds
end

-- 확률 공개용: 등급별 벨트 등장 확률(%). rain이면 희귀 로봇 비가 내리는 중
function Config.rarityOdds(rain: boolean): { [string]: number }
	local total = 0
	local weights: { [string]: number } = {}
	for _, id in Config.RarityOrder do
		local weight = Config.Rarities[id].weight * (if rain and Config.RainRarities[id] then Config.RainMultiplier else 1)
		weights[id] = weight
		total += weight
	end
	local odds = {}
	for id, weight in weights do
		odds[id] = weight / total * 100
	end
	return odds
end

function Config.upgradeValue(id: string, level: number): number
	local upgrade = Config.Upgrades[id]
	return upgrade.values[math.clamp(level + 1, 1, #upgrade.values)]
end

-- 다음 단계 비용 (최고 단계면 nil)
function Config.upgradeCost(id: string, level: number): number?
	return Config.Upgrades[id].costs[level + 1]
end

function Config.itemPrice(id: string, incomePerSecond: number): number
	local item = Config.Items[id]
	return math.max(item.minPrice, math.floor(incomePerSecond * item.incomeSeconds))
end

local robotById: { [string]: Robot } = {}
for _, robot in Config.Robots do
	robotById[robot.id] = robot
end

-- 환생과 변종 (4단계) -----------------------------------------------------------
-- 로봇 키: 기본 로봇은 "Pippi", 변종은 "Pippi@Gold". 받침대·운반·저장에 이 키를 쓴다.
-- 벨트에는 기본 로봇만 흐른다(모두에게 같음). 환생한 사람이 살 때 서버가 변종을 정한다.
Config.RebirthBaseCost = 1000000 -- 첫 환생에 필요한 돈
Config.RebirthCostGrowth = 3 -- 환생할 때마다 필요한 돈 ×3
Config.RebirthRequiresRarity = "Mythic" -- 도감에 이 등급 로봇이 1종 이상 있어야 환생 가능
Config.RebirthIncomeBonus = 0.5 -- 환생 1번마다 수입 +50% (영구)
Config.ProtectionGap = 2 -- 환생 단계가 이만큼 이상 높은 사람은 내 로봇을 훔칠 수 없다 (초보 보호)
export type Variant = { name: string, mark: string, minRebirth: number, chance: number, income: number, color: Color3, pageBonus: number }
Config.VariantOrder = { "Gold", "Diamond", "Rainbow" }
Config.Variants = {
	Gold = { name = "금색", mark = "✨", minRebirth = 1, chance = 0.15, income = 3, color = Color3.fromRGB(255, 205, 60), pageBonus = 0.25 },
	Diamond = { name = "다이아", mark = "💎", minRebirth = 3, chance = 0.05, income = 10, color = Color3.fromRGB(120, 230, 255), pageBonus = 0.5 },
	Rainbow = { name = "무지개", mark = "🌈", minRebirth = 5, chance = 0.01, income = 30, color = Color3.fromRGB(255, 120, 220), pageBonus = 1 },
} :: { [string]: Variant }

-- "Pippi@Gold" → "Pippi", "Gold" / "Pippi" → "Pippi", nil
function Config.splitKey(key: string): (string, string?)
	local id, variant = string.match(key, "^([^@]+)@(.+)$")
	if id then
		return id, variant
	end
	return key, nil
end

function Config.getRobot(key: string): Robot?
	local id = Config.splitKey(key)
	return robotById[id]
end

function Config.rarityOf(key: string): Rarity?
	local robot = Config.getRobot(key)
	return if robot then Config.Rarities[robot.rarity] else nil
end

function Config.variantOf(key: string): Variant?
	local _, variant = Config.splitKey(key)
	return if variant then Config.Variants[variant] else nil
end

-- 저장된 키가 올바른지 (있는 로봇 + 있는 변종)
function Config.isValidKey(key: string): boolean
	local id, variant = Config.splitKey(key)
	return robotById[id] ~= nil and (variant == nil or Config.Variants[variant] ~= nil)
end

-- 초당 수입 (변종이면 배수)
function Config.robotIncome(key: string): number
	local rarity = Config.rarityOf(key)
	local variant = Config.variantOf(key)
	return (if rarity then rarity.income else 0) * (if variant then variant.income else 1)
end

-- 가치 (판매·환급 기준). 변종이면 수입 배수만큼 비싸다
function Config.robotValue(key: string): number
	local rarity = Config.rarityOf(key)
	local variant = Config.variantOf(key)
	return (if rarity then rarity.price else 0) * (if variant then variant.income else 1)
end

-- 화면에 보이는 이름: "✨ 금색 삐삐" / "삐삐"
function Config.robotName(key: string): string
	local robot = Config.getRobot(key)
	local variant = Config.variantOf(key)
	local name = if robot then robot.name else key
	return if variant then ("%s %s %s"):format(variant.mark, variant.name, name) else name
end

function Config.rebirthCost(level: number): number
	return Config.RebirthBaseCost * Config.RebirthCostGrowth ^ level
end

function Config.rebirthMultiplier(level: number): number
	return 1 + Config.RebirthIncomeBonus * level
end

-- 머리 위 환생 표시
function Config.rebirthMark(level: number): string
	if level >= 10 then
		return ("🌈%d"):format(level)
	elseif level >= 5 then
		return ("💎%d"):format(level)
	end
	return ("⭐%d"):format(level)
end

-- 살 때 변종 뽑기 (희귀한 것부터 확인). 서버에서만 부른다
function Config.rollVariant(rebirth: number): string?
	for i = #Config.VariantOrder, 1, -1 do
		local id = Config.VariantOrder[i]
		local variant = Config.Variants[id]
		if rebirth >= variant.minRebirth and math.random() < variant.chance then
			return id
		end
	end
	return nil
end

Config.FullCatalogBonus = 0.30
Config.FullCatalogTitle = "🏆 고물왕"
Config.VariantPageTitles = {
	Gold = "✨ 금빛 수집왕",
	Diamond = "💎 다이아 수집왕",
	Rainbow = "🌈 무지개 수집왕",
} :: { [string]: string }

function Config.isCatalogComplete(catalog: { [string]: boolean }, rarityId: string?): boolean
	for _, robot in Config.Robots do
		if (rarityId == nil or robot.rarity == rarityId) and catalog[robot.id] ~= true then
			return false
		end
	end
	return true
end

function Config.isVariantPageComplete(variantCatalog: { [string]: boolean }, variantId: string): boolean
	for _, robot in Config.Robots do
		if variantCatalog[robot.id .. "@" .. variantId] ~= true then
			return false
		end
	end
	return true
end

function Config.highestVariantPage(variantCatalog: { [string]: boolean }): string?
	for index = #Config.VariantOrder, 1, -1 do
		local variantId = Config.VariantOrder[index]
		if Config.isVariantPageComplete(variantCatalog, variantId) then
			return variantId
		end
	end
	return nil
end

-- 변종 도감 페이지(18종)를 다 모으면 주는 수입 보너스 합
function Config.variantPageBonus(variantCatalog: { [string]: boolean }): number
	local bonus = 0
	for _, variantId in Config.VariantOrder do
		if Config.isVariantPageComplete(variantCatalog, variantId) then
			bonus += Config.Variants[variantId].pageBonus
		end
	end
	return bonus
end

-- 기본 도감 수입 배수에 등급 세트와 전체 완성 보너스를 더한다.
-- 두 번째 값: 완성한 가장 높은 등급 id (칭호용)
function Config.catalogMultiplier(catalog: { [string]: boolean }): (number, string?)
	local multiplier = 1
	local best: string? = nil
	for _, rarityId in Config.RarityOrder do
		if Config.isCatalogComplete(catalog, rarityId) then
			multiplier += Config.Rarities[rarityId].setBonus
			best = rarityId
		end
	end
	if Config.isCatalogComplete(catalog) then
		multiplier += Config.FullCatalogBonus
	end
	return multiplier, best
end

-- 1234 → "1.2K", 3400000 → "3.4M"
function Config.formatMoney(value: number): string
	value = math.floor(value)
	if value >= 1e9 then
		return ("%.1fB"):format(value / 1e9)
	elseif value >= 1e6 then
		return ("%.1fM"):format(value / 1e6)
	elseif value >= 1e4 then
		return ("%.1fK"):format(value / 1e3)
	end
	return tostring(value)
end

-- 협력 거대 로봇 (2026-11-17): 서버 사람들이 돈을 기부해 완성하면 서버 전체 수입이 잠시 2배
Config.GiantRobot = {
	GoalSeconds = 600, -- 목표 = 접속한 사람들 초당 수입 합 × 이 초 (최소 MinGoal)
	MinGoal = 5000,
	Tiers = { -- 기부 버튼: 내 초당 수입 × seconds (최소 min)
		{ name = "소", seconds = 30, min = 50 },
		{ name = "중", seconds = 120, min = 200 },
		{ name = "대", seconds = 600, min = 1000 },
	},
	BoostMultiplier = 2,
	BoostSeconds = 600, -- 완성 뒤 수입 2배 시간
	RestSeconds = 300, -- 2배가 끝나고 다시 조립을 시작하기까지
	DonateRange = 12, -- 기부 단말기에서 이 거리 안에서만 기부
	TopTitle = "🔧 정비왕", -- 최고 기부자 칭호 (다음 완성 때까지)
}

-- 소리 (2026-11-17): Roblox 공식 라이브러리(Pro Sound Effects 효과음, APM Music 음악)만 쓴다.
-- 바꾸고 싶으면 asset 번호만 바꾼다. volume은 0~1. loop = 계속 반복
Config.Sounds = {
	Music = { asset = 1837768600, volume = 0.18, loop = true }, -- APM "Gnomes (b)"
	Belt = { asset = 9113910362, volume = 0.35, loop = true }, -- 컨베이어 벨트 기계음 (벨트 근처에서만 들림)
	Buy = { asset = 9113704038, volume = 0.6 }, -- 동전 넣는 소리
	Place = { asset = 9116541944, volume = 0.5 }, -- 쇠 부딪히는 소리
	Collect = { asset = 9113849492, volume = 0.6 }, -- 동전 짤랑
	Alarm = { asset = 9113085764, volume = 0.7 }, -- 경보 부저
	Shield = { asset = 9042544754, volume = 0.45 }, -- 짧은 전자음 (APM "Do Me A Solid - Tag2")
	Fanfare = { asset = 9047102381, volume = 0.55 }, -- 짧은 승리 연주 (APM "Game Day Warrior Sting 1")
}

return Config
