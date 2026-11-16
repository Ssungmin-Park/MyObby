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

local robotById: { [string]: Robot } = {}
for _, robot in Config.Robots do
	robotById[robot.id] = robot
end

function Config.getRobot(id: string): Robot?
	return robotById[id]
end

function Config.rarityOf(id: string): Rarity?
	local robot = robotById[id]
	return if robot then Config.Rarities[robot.rarity] else nil
end

-- 도감(모은 로봇 id 집합)으로 수입 배수를 계산한다. 1 + 완성한 등급들의 setBonus 합.
-- 두 번째 값: 완성한 가장 높은 등급 id (칭호용)
function Config.catalogMultiplier(catalog: { [string]: boolean }): (number, string?)
	local multiplier = 1
	local best: string? = nil
	for _, rarityId in Config.RarityOrder do
		local complete = true
		for _, robot in Config.Robots do
			if robot.rarity == rarityId and not catalog[robot.id] then
				complete = false
				break
			end
		end
		if complete then
			multiplier += Config.Rarities[rarityId].setBonus
			best = rarityId
		end
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

return Config
