--!strict
-- RobotLabConfig: 로봇 작업장의 밸런스 데이터. 서버(RobotLab)와 클라이언트(RobotLabHud)가 함께 읽는다.
-- 숫자를 바꿔 난이도를 조절할 수 있다. 스크립트 로직은 고치지 않아도 된다.
-- 주의: 로봇·업그레이드·구역의 id(영문 키)는 저장 데이터에 들어가므로 이름을 바꾸지 않는다.

export type Rarity = {
	name: string, -- 화면에 보이는 이름
	repairCost: number, -- 수리에 드는 부품
	repairTime: number, -- 수리 시간(초, 실제 시간)
	income: number, -- 수리한 로봇 1대가 버는 부품(분당, 레벨 1 기준)
	color: Color3,
}
export type Robot = { id: string, name: string, rarity: string }
export type Zone = {
	id: string,
	name: string,
	unlockCost: number, -- 0이면 처음부터 열림
	pileCount: number, -- 동시에 놓이는 부품 더미 수
	pileValue: number, -- 부품 더미 1개의 부품 수
	rarityWeights: { [string]: number }, -- 이 구역에서 나오는 로봇 등급 확률(가중치)
}
export type UpgradeLevel = { cost: number, value: number }
export type Upgrade = { id: string, name: string, unit: string, levels: { UpgradeLevel } }

local Config = {}

Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }
Config.Rarities = {
	Common = { name = "일반", repairCost = 8, repairTime = 45, income = 1, color = Color3.fromRGB(176, 186, 196) },
	Rare = { name = "희귀", repairCost = 25, repairTime = 240, income = 3, color = Color3.fromRGB(110, 170, 250) },
	Epic = { name = "에픽", repairCost = 80, repairTime = 1200, income = 8, color = Color3.fromRGB(190, 120, 245) },
	Legendary = { name = "전설", repairCost = 250, repairTime = 5400, income = 20, color = Color3.fromRGB(250, 196, 80) },
} :: { [string]: Rarity }

-- 도감 순서 = 이 목록 순서
Config.Robots = {
	{ id = "Pippi", name = "삐삐", rarity = "Common" },
	{ id = "Volt", name = "볼트", rarity = "Common" },
	{ id = "Nut", name = "너트", rarity = "Common" },
	{ id = "Sponge", name = "스펀지", rarity = "Common" },
	{ id = "Lumi", name = "루미", rarity = "Rare" },
	{ id = "Coil", name = "코일", rarity = "Rare" },
	{ id = "Spring", name = "스프링", rarity = "Rare" },
	{ id = "Radar", name = "레이더", rarity = "Rare" },
	{ id = "GearKing", name = "기어킹", rarity = "Epic" },
	{ id = "Holo", name = "홀로", rarity = "Epic" },
	{ id = "Nova", name = "노바", rarity = "Legendary" },
	{ id = "Atlas", name = "아틀라스", rarity = "Legendary" },
} :: { Robot }

Config.TutorialRobot = "Pippi" -- 처음 입장하면 연구실에 나타나는 로봇 (수리 무료, 짧게)
Config.TutorialRepairTime = 15
Config.MaxRobotLevel = 5 -- 같은 로봇을 또 수리하면 레벨이 오른다
Config.LevelIncomeBonus = 0.5 -- 레벨당 수입 +50%
-- 이미 가진 로봇을 또 수리(레벨업)할 때 수리비 배수 = 1 + 현재 레벨 × 이 값.
-- 예: 일반(8) 레벨 1→2는 16, 4→5는 40. 싼 로봇 중복 수리로 수입이 너무 빨리 오르는 것을 막는다.
Config.LevelCostStep = 1

Config.ZoneOrder = { "Warehouse", "Greenhouse", "Scrapyard" }
Config.Zones = {
	Warehouse = {
		id = "Warehouse", name = "부품 창고", unlockCost = 0, pileCount = 6, pileValue = 1,
		rarityWeights = { Common = 80, Rare = 20 },
	},
	Greenhouse = {
		id = "Greenhouse", name = "실험 온실", unlockCost = 40, pileCount = 6, pileValue = 2,
		rarityWeights = { Common = 55, Rare = 35, Epic = 10 },
	},
	Scrapyard = {
		id = "Scrapyard", name = "폐품 처리장", unlockCost = 250, pileCount = 6, pileValue = 4,
		rarityWeights = { Common = 35, Rare = 37, Epic = 22, Legendary = 6 },
	},
} :: { [string]: Zone }

Config.PileRespawn = 12 -- 주운 부품 더미가 다시 생기는 시간(초)
Config.SignalDelay = 8 -- 로봇을 맡긴 뒤 다음 신호까지(초)
Config.StorageCapMinutes = 240 -- 보관함은 최대 "분당 수입 × 4시간"까지 쌓인다 (접속하지 않은 동안 포함)
Config.StorageMinCap = 30
Config.CollectRange = 10 -- 서버가 허용하는 줍기 거리(스터드). 이동 중 위치 지연을 감안해 넉넉히
Config.PickUpRange = 10

-- levels[1]은 기본값(비용 0). 다음 레벨의 cost를 내면 value가 바뀐다.
Config.UpgradeOrder = { "Bag", "Detector", "RepairSlots", "RepairSpeed" }
Config.Upgrades = {
	Bag = {
		id = "Bag", name = "가방 확장", unit = "칸",
		levels = { { cost = 0, value = 15 }, { cost = 20, value = 30 }, { cost = 60, value = 50 }, { cost = 150, value = 80 }, { cost = 400, value = 120 } },
	},
	Detector = {
		id = "Detector", name = "탐지기 강화", unit = "스터드",
		levels = { { cost = 0, value = 30 }, { cost = 15, value = 45 }, { cost = 50, value = 60 }, { cost = 150, value = 80 } },
	},
	RepairSlots = {
		id = "RepairSlots", name = "수리대 추가", unit = "대",
		levels = { { cost = 0, value = 1 }, { cost = 40, value = 2 }, { cost = 200, value = 3 } },
	},
	RepairSpeed = {
		id = "RepairSpeed", name = "수리 속도", unit = "배 시간",
		levels = { { cost = 0, value = 1 }, { cost = 50, value = 0.85 }, { cost = 150, value = 0.7 }, { cost = 400, value = 0.55 } },
	},
} :: { [string]: Upgrade }

local robotById: { [string]: Robot } = {}
for _, robot in Config.Robots do
	robotById[robot.id] = robot
end

function Config.getRobot(id: string): Robot?
	return robotById[id]
end

-- 로봇 1대의 분당 수입
function Config.robotIncome(id: string, level: number): number
	local robot = robotById[id]
	if not robot or level <= 0 then
		return 0
	end
	return Config.Rarities[robot.rarity].income * (1 + Config.LevelIncomeBonus * (level - 1))
end

-- 가진 로봇 전체의 분당 수입
function Config.incomeRate(robots: { [string]: number }): number
	local total = 0
	for id, level in robots do
		total += Config.robotIncome(id, level)
	end
	return total
end

-- 보관함 상한
function Config.storageCap(robots: { [string]: number }): number
	return math.max(Config.StorageMinCap, Config.incomeRate(robots) * Config.StorageCapMinutes)
end

function Config.upgradeValue(id: string, level: number): number
	local upgrade = Config.Upgrades[id]
	local entry = upgrade.levels[math.clamp(level, 1, #upgrade.levels)]
	return entry.value
end

function Config.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return ("%d시간 %d분"):format(seconds // 3600, (seconds % 3600) // 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

return Config
