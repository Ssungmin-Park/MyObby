--!strict
-- JunkyardHud: 로봇 고물상 화면 표시. (표시와 요청만 담당, 판정은 서버 Junkyard)
--   - 컨베이어 벨트 위 로봇을 이 화면에서 직접 움직여 그린다(서버와 같은 공식). 구매 버튼 → 서버에 요청.
--   - 돈·초당 수입·방어막·들고 있는 로봇·도감·알림을 보여 준다.
--   - 받침대 버튼 문구를 내 기지면 "팔기", 남의 기지면 "훔치기"로 바꿔 보여 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local beltRemote = remotes:WaitForChild("JunkyardBelt") :: RemoteEvent
local actionRemote = remotes:WaitForChild("JunkyardAction") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("JunkyardNotify") :: RemoteEvent
local junkyard = workspace:WaitForChild("Junkyard")
local beltPart = junkyard:WaitForChild("Belt")
local basesFolder = junkyard:WaitForChild("Bases")

local player = Players.LocalPlayer
local white = Color3.fromRGB(244, 248, 255)
local muted = Color3.fromRGB(180, 196, 209)
local dark = Color3.fromRGB(20, 26, 32)

-- 화면 ------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "JunkyardHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local object = Instance.new("UICorner")
	object.CornerRadius = UDim.new(0, radius)
	object.Parent = parent
end

-- 화면 크기에 맞춰 함께 커지는 HUD 조각들 (fitWindows가 배율을 정한다)
local hudScales: { UIScale } = {}
local function hudScale(parent: Instance)
	local object = Instance.new("UIScale")
	object.Parent = parent
	table.insert(hudScales, object)
end

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local object = Instance.new("TextLabel")
	object.Position = position
	object.Size = size
	object.BackgroundTransparency = 1
	object.Font = Enum.Font.GothamBold
	object.TextSize = textSize
	object.TextColor3 = color
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextWrapped = true
	object.Parent = parent
	return object
end

local function button(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local object = Instance.new("TextButton")
	object.Position = position
	object.Size = size
	object.BackgroundColor3 = color
	object.TextColor3 = white
	object.Font = Enum.Font.GothamBold
	object.TextSize = 14
	object.Text = text
	object.AutoButtonColor = true
	object.Parent = parent
	corner(object, 8)
	return object
end

-- 오른쪽 위 패널. 기본 리더보드가 같은 자리를 쓰므로 끈다 (돈·초당·환생은 이 패널과 맵의 순위판에서 본다)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 10)
panel.Size = UDim2.fromOffset(250, 150)
panel.BackgroundColor3 = dark
panel.BackgroundTransparency = 0.04 -- 뒤의 간판·장식이 비쳐 글씨가 안 읽히지 않게 진하게
panel.Parent = gui
corner(panel, 10)
hudScale(panel)

local moneyLabel = label(panel, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 30), 24, Color3.fromRGB(255, 220, 100))
local incomeLabel = label(panel, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 18), 13, white)
local carryLabel = label(panel, UDim2.fromOffset(12, 56), UDim2.new(1, -24, 0, 30), 12, muted)
local lockButton = button(panel, "방어막", UDim2.fromOffset(12, 92), UDim2.fromOffset(74, 32), Color3.fromRGB(60, 120, 170))
local shopButton = button(panel, "🛒 상점", UDim2.fromOffset(90, 92), UDim2.fromOffset(80, 32), Color3.fromRGB(170, 120, 40))
shopButton.TextSize = 15
local catalogButton = button(panel, "도감", UDim2.fromOffset(174, 92), UDim2.fromOffset(64, 32), Color3.fromRGB(70, 82, 96))
local trainLabel = label(panel, UDim2.fromOffset(12, 128), UDim2.new(1, -24, 0, 18), 12, Color3.fromRGB(255, 210, 120))
-- 신화 타이머: 화면 위쪽 가운데에 신화 보장까지 남은 시간을 늘 보여 준다.
-- 마지막 1분은 커지면서 매초 튀고, 마지막 10초는 더 크고 빨개진다
local mythicBanner = Instance.new("TextLabel")
mythicBanner.Name = "MythicBanner"
mythicBanner.AnchorPoint = Vector2.new(0.5, 0)
mythicBanner.Position = UDim2.new(0.5, 0, 0, 8)
mythicBanner.Size = UDim2.fromOffset(300, 40)
mythicBanner.BackgroundColor3 = Color3.fromRGB(90, 20, 40)
mythicBanner.BackgroundTransparency = 0.1
mythicBanner.Font = Enum.Font.GothamBlack
mythicBanner.TextScaled = true
mythicBanner.TextColor3 = Color3.fromRGB(255, 200, 215)
mythicBanner.TextStrokeTransparency = 0.3
mythicBanner.Visible = false
mythicBanner.Parent = gui
corner(mythicBanner, 12)
local mythicScale = Instance.new("UIScale")
mythicScale.Parent = mythicBanner
local mythicLastSecond = -1
local mythicBannerStroke = Instance.new("UIStroke")
mythicBannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mythicBannerStroke.Color = Color3.fromRGB(255, 90, 120)
mythicBannerStroke.Thickness = 3
mythicBannerStroke.Parent = mythicBanner
local mythicBannerPadding = Instance.new("UIPadding")
mythicBannerPadding.PaddingTop = UDim.new(0, 6)
mythicBannerPadding.PaddingBottom = UDim.new(0, 6)
mythicBannerPadding.PaddingLeft = UDim.new(0, 12)
mythicBannerPadding.PaddingRight = UDim.new(0, 12)
mythicBannerPadding.Parent = mythicBanner
local contestPanel = Instance.new("Frame")
contestPanel.Name = "ContestPanel"
contestPanel.AnchorPoint = Vector2.new(1, 0)
contestPanel.Position = UDim2.new(1, -12, 0, 166) -- 세로 위치는 fitWindows가 패널 배율에 맞춰 고친다
contestPanel.Size = UDim2.fromOffset(250, 30)
contestPanel.BackgroundColor3 = dark
contestPanel.BackgroundTransparency = 0.04
contestPanel.Parent = gui
corner(contestPanel, 10)
hudScale(contestPanel)
local contestHeader = label(contestPanel, UDim2.fromOffset(12, 4), UDim2.new(1, -24, 0, 22), 13, Color3.fromRGB(255, 210, 120))
local contestTop = label(contestPanel, UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 54), 12, white)
contestTop.TextYAlignment = Enum.TextYAlignment.Top
local contestOwn = label(contestPanel, UDim2.fromOffset(12, 80), UDim2.new(1, -24, 0, 22), 12, muted)
local lastContestTop: string? = nil

local function renderContest(t: number)
	local kind = workspace:GetAttribute("ContestType")
	local endsAt = (workspace:GetAttribute("ContestEndsAt") or 0) :: number
	local contest = if typeof(kind) == "string" then Config.Contest.Types[kind] else nil
	local running = contest ~= nil and endsAt > t
	contestTop.Visible = running
	contestOwn.Visible = running
	contestPanel.Size = UDim2.fromOffset(250, if running then 108 else 30)
	if not contest or not running then
		local left = math.max(0, math.ceil(((workspace:GetAttribute("NextContestAt") or 0) :: number) - t))
		contestHeader.Text = ("🏆 다음 서버 대회 %d:%02d"):format(left // 60, left % 60)
		return
	end

	local left = math.ceil(endsAt - t)
	contestHeader.Text = ("%s %s · %d:%02d 남음"):format(contest.mark, contest.name, left // 60, left % 60)
	local encoded = (workspace:GetAttribute("ContestTop") or "[]") :: string
	if encoded ~= lastContestTop then
		lastContestTop = encoded
		local entries = HttpService:JSONDecode(encoded) :: { { name: string, score: number } }
		local lines = {}
		for rank, entry in entries do
			table.insert(lines, ("%d. %s · %g점"):format(rank, entry.name, entry.score))
		end
		contestTop.Text = if #lines > 0 then table.concat(lines, "\n") else "아직 득점한 사람이 없어요."
	end
	local rank = player:GetAttribute("ContestRank")
	local score = (player:GetAttribute("ContestScore") or 0) :: number
	contestOwn.Text = if typeof(rank) ~= "number" then "다음 대회부터 참가할 수 있어요."
		elseif rank > 0 then ("나 · %d위 · %g점"):format(rank, score)
		else ("나 · %g점"):format(score)
end
-- 저장 상태 (오른쪽 위 작은 글씨): 불러오는 중 / 저장 안 됨
local saveLabel = label(panel, UDim2.new(1, -150, 0, 6), UDim2.fromOffset(100, 18), 12, Color3.fromRGB(255, 150, 150)) -- 오른쪽 끝은 🔊 버튼 자리
saveLabel.TextXAlignment = Enum.TextXAlignment.Right

-- 도감 창
local catalog = Instance.new("Frame")
catalog.AnchorPoint = Vector2.new(0.5, 0.5)
catalog.Position = UDim2.fromScale(0.5, 0.5)
catalog.Size = UDim2.new(0.92, 0, 0, 420)
catalog.BackgroundColor3 = dark
catalog.BackgroundTransparency = 0.05
catalog.Visible = false
catalog.Parent = gui
-- 기본 리더보드가 좁은 화면에서 도감 버튼을 가리지 않게 한다.
local previousPlayerListEnabled: boolean? = nil
local function syncPlayerList()
	local playerList = Enum.CoreGuiType.PlayerList
	if catalog.Visible and gui.Enabled then
		if previousPlayerListEnabled == nil then
			previousPlayerListEnabled = StarterGui:GetCoreGuiEnabled(playerList)
			StarterGui:SetCoreGuiEnabled(playerList, false)
		end
	elseif previousPlayerListEnabled ~= nil then
		StarterGui:SetCoreGuiEnabled(playerList, previousPlayerListEnabled)
		previousPlayerListEnabled = nil
	end
end
catalog:GetPropertyChangedSignal("Visible"):Connect(syncPlayerList)
gui:GetPropertyChangedSignal("Enabled"):Connect(syncPlayerList)
corner(catalog, 12)
local catalogMax = Instance.new("UISizeConstraint")
catalogMax.MaxSize = Vector2.new(420, 420)
catalogMax.Parent = catalog
local catalogScale = Instance.new("UIScale") -- 작은 화면(휴대폰 가로)에서 창 전체를 줄인다
catalogScale.Parent = catalog
local catalogTitle = label(catalog, UDim2.fromOffset(14, 8), UDim2.new(1, -170, 0, 26), 18, white)
local closeButton = button(catalog, "X", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(36, 30), Color3.fromRGB(120, 60, 60))
local catalogPage = 0 -- 0 = 기본 도감, 1~3 = 변종 도감 (금색·다이아·무지개)
local pageButton = button(catalog, "기본 ▶", UDim2.new(1, -150, 0, 8), UDim2.fromOffset(98, 30), Color3.fromRGB(70, 82, 96))
pageButton.Activated:Connect(function()
	catalogPage = (catalogPage + 1) % (#Config.VariantOrder + 1)
end)
-- 로봇 칸은 스크롤 영역에 3열로 (종류가 많아서)
local catalogGrid = Instance.new("ScrollingFrame")
catalogGrid.Position = UDim2.fromOffset(0, 42)
catalogGrid.Size = UDim2.new(1, 0, 0, 264)
catalogGrid.BackgroundTransparency = 1
catalogGrid.BorderSizePixel = 0
catalogGrid.ScrollBarThickness = 6
catalogGrid.CanvasSize = UDim2.fromOffset(0, math.ceil(#Config.Robots / 3) * 44 + 4)
catalogGrid.Parent = catalog
local catalogRows: { TextLabel } = {}
for i in Config.Robots do
	local column = (i - 1) % 3
	local row = (i - 1) // 3
	catalogRows[i] = label(catalogGrid, UDim2.new(column / 3, 12, 0, row * 44), UDim2.new(1 / 3, -16, 0, 40), 13, muted)
end
local bonusLabel = label(catalog, UDim2.fromOffset(14, 312), UDim2.new(1, -28, 0, 100), 12, muted)
catalogButton.Activated:Connect(function()
	catalog.Visible = not catalog.Visible
	if catalog.Visible and player:GetAttribute("TutorialStep") == 5 then
		actionRemote:FireServer("Tutorial", "Catalog")
	end
end)
closeButton.Activated:Connect(function()
	catalog.Visible = false
end)
lockButton.Activated:Connect(function()
	actionRemote:FireServer("Lock")
end)

-- 상점 창 (탭: 방해 / 방어 / 도움) --------------------------------------------------
local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.Size = UDim2.new(0.92, 0, 0, 400)
shop.BackgroundColor3 = dark
shop.BackgroundTransparency = 0.05
shop.Visible = false
shop.Parent = gui
corner(shop, 12)
local shopMax = Instance.new("UISizeConstraint")
shopMax.MaxSize = Vector2.new(440, 400)
shopMax.Parent = shop
local shopScale = Instance.new("UIScale")
shopScale.Parent = shop
label(shop, UDim2.fromOffset(14, 8), UDim2.new(1, -70, 0, 26), 18, white).Text = "🛒 상점"
local shopClose = button(shop, "X", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(36, 30), Color3.fromRGB(120, 60, 60))

type ShopEntry = { kind: string, id: string, category: string, row: Frame, info: TextLabel, buy: TextButton }
local shopEntries: { ShopEntry } = {}
local shopTab = "Attack"
local rebirthConfirmAt = 0 -- 환생은 실수로 누르지 않게 4초 안에 두 번 눌러야 한다
local tabs = { { id = "Attack", text = "⚡ 방해" }, { id = "Defense", text = "🛡 방어" }, { id = "Help", text = "💪 도움" }, { id = "Rebirth", text = "⭐ 환생" }, { id = "Robux", text = "💎 Robux" } }
local tabButtons: { [string]: TextButton } = {}
for i, tab in tabs do
	local tabButton = button(shop, tab.text, UDim2.new((i - 1) / #tabs, 8, 0, 42), UDim2.new(1 / #tabs, -10, 0, 32), Color3.fromRGB(52, 64, 76))
	tabButtons[tab.id] = tabButton
	tabButton.Activated:Connect(function()
		shopTab = tab.id
	end)
end
local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 82)
list.Size = UDim2.new(1, -20, 1, -92)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = list

local function addEntry(kind: string, id: string, category: string, name: string, desc: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 96)
	row.BackgroundColor3 = Color3.fromRGB(36, 44, 54)
	row.Parent = list
	corner(row, 8)
	label(row, UDim2.fromOffset(10, 4), UDim2.new(1, -130, 0, 20), 15, white).Text = name
	local descLabel = label(row, UDim2.fromOffset(10, 24), UDim2.new(1, -130, 0, 28), 11, muted)
	descLabel.Text = desc
	local info = label(row, UDim2.fromOffset(10, 50), UDim2.new(1, -130, 0, 42), 11, Color3.fromRGB(150, 230, 255))
	local buy = button(row, "", UDim2.new(1, -114, 0.5, -20), UDim2.fromOffset(106, 40), Color3.fromRGB(60, 140, 80))
	buy.Activated:Connect(function()
		if kind == "Rebirth" then
			if os.clock() - rebirthConfirmAt < 4 then
				rebirthConfirmAt = 0
				actionRemote:FireServer("Rebirth")
			else
				rebirthConfirmAt = os.clock()
			end
			return
		end
		if kind == "Pass" or kind == "Product" then
			-- Robux 결제창은 클라이언트에서 띄운다. 지급은 서버(JunkyardStore)가 영수증을 확인한 뒤에만 한다
			local offer = if kind == "Pass" then Config.GamePasses[id] else Config.Products[id]
			if offer.id == 0 then
				return
			end
			if kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, offer.id)
			else
				MarketplaceService:PromptProductPurchase(player, offer.id)
			end
			return
		end
		if kind == "Expand" then
			actionRemote:FireServer("Expand")
			return
		end
		actionRemote:FireServer(if kind == "Item" then "Item" else "Upgrade", id)
	end)
	table.insert(shopEntries, { kind = kind, id = id, category = category, row = row, info = info, buy = buy })
end
for _, id in Config.ItemOrder do
	local item = Config.Items[id]
	addEntry("Item", id, item.category, item.name, item.desc)
end
addEntry("Expand", "Expand", "Help", "🏗 구역 확장", "기지가 뒤쪽으로 넓어지고 받침대 자리 6개가 생겨요. 받침대 추가·터보 신발을 더 올릴 수 있어요. 환생해도 그대로예요")
for _, id in Config.UpgradeOrder do
	local upgrade = Config.Upgrades[id]
	addEntry("Upgrade", id, upgrade.category, upgrade.name, upgrade.desc)
end
for _, id in Config.PassOrder do
	local offer = Config.GamePasses[id]
	addEntry("Pass", id, "Robux", offer.name .. " (게임패스)", offer.desc)
end
for _, id in Config.ProductOrder do
	local offer = Config.Products[id]
	addEntry("Product", id, "Robux", offer.name, offer.desc)
end

addEntry("Rebirth", "Rebirth", "Rebirth", "⭐ 환생", "돈·받침대 로봇·업그레이드가 처음으로 돌아가고 영구 수입 보너스와 변종 로봇을 얻어요. 도감·무료 EMP·Robux 혜택은 그대로예요")

-- 희귀 로봇 비 확률 공개 (평소 → 비 내릴 때, 등급별 %)
local oddsText: string
do
	local normal = Config.rarityOdds(false)
	local rain = Config.rarityOdds(true)
	local parts = {}
	for _, rarityId in Config.RarityOrder do
		table.insert(parts, ("%s %.1f→%.1f%%"):format(Config.Rarities[rarityId].name, normal[rarityId], rain[rarityId]))
	end
	local gift = Config.rainGiftOdds()
	local giftParts = {}
	for _, rarityId in Config.RarityOrder do
		if gift[rarityId] then
			table.insert(giftParts, ("%s %.1f%%"):format(Config.Rarities[rarityId].name, gift[rarityId]))
		end
	end
	oddsText = "확률 공개(평소→비): " .. table.concat(parts, " · ") .. "\n확정 선물: " .. table.concat(giftParts, " · ")
end
shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
	catalog.Visible = false
	if shop.Visible and player:GetAttribute("TutorialStep") == 4 then
		actionRemote:FireServer("Tutorial", "Shop")
	end
end)
shopClose.Activated:Connect(function()
	shop.Visible = false
end)

local function decodeUpgrades(): { [string]: number }
	local ok, value = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("Upgrades") or "{}") :: string)
	end)
	return if ok and typeof(value) == "table" then value else {}
end

local function renderShop()
	if not shop.Visible then
		return
	end
	local t = workspace:GetServerTimeNow()
	local money = (player:GetAttribute("Money") or 0) :: number
	local income = (player:GetAttribute("Income") or 0) :: number
	local upgrades = decodeUpgrades()
	for id, tabButton in tabButtons do
		tabButton.BackgroundColor3 = if id == shopTab then Color3.fromRGB(90, 110, 130) else Color3.fromRGB(52, 64, 76)
	end
	local passes: { [string]: boolean } = {}
	local okPasses, passList = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("Passes") or "[]") :: string)
	end)
	if okPasses and typeof(passList) == "table" then
		for _, key in passList do
			passes[key] = true
		end
	end
	local empCharges = (player:GetAttribute("EmpCharges") or 0) :: number
	for _, entry in shopEntries do
		entry.row.Visible = entry.category == shopTab
		if entry.kind == "Rebirth" then
			local level = (player:GetAttribute("Rebirth") or 0) :: number
			local cost = Config.rebirthCost(level)
			local unlock = ""
			for _, variantId in Config.VariantOrder do
				local variant = Config.Variants[variantId]
				if variant.minRebirth == level + 1 then
					unlock = (" · %s %s 변종 해금"):format(variant.mark, variant.name)
				end
			end
			entry.info.Text = ("현재 ⭐%d · 필요: 돈 %s + 도감에 %s 로봇 1종\n보상: 수입 x%.1f%s"):format(level, Config.formatMoney(cost), Config.Rarities[Config.RebirthRequiresRarity].name, Config.rebirthMultiplier(level + 1), unlock)
			local confirming = os.clock() - rebirthConfirmAt < 4
			entry.buy.Text = if confirming then "정말 환생?\n한 번 더!" else "환생하기"
			entry.buy.BackgroundColor3 = if confirming then Color3.fromRGB(200, 120, 40) elseif money >= cost then Color3.fromRGB(60, 140, 80) else Color3.fromRGB(90, 70, 70)
			entry.buy.Active = true
			continue
		end
		if entry.kind == "Pass" or entry.kind == "Product" then
			local offer = if entry.kind == "Pass" then Config.GamePasses[entry.id] else Config.Products[entry.id]
			local owned = entry.kind == "Pass" and passes[entry.id] == true
			if entry.id == "RareRain" then
				entry.info.Text = oddsText
			elseif entry.id == "EmpPack" then
				entry.info.Text = ("무료 EMP 보유 %d개"):format(empCharges)
			else
				entry.info.Text = if owned then "보유 중 · 적용됨" else ""
			end
			local available = offer.id ~= 0 and not owned
			entry.buy.Active = available
			entry.buy.Text = if owned then "보유 중" elseif offer.id == 0 then "준비 중" else ("R$ %d"):format(offer.robux)
			entry.buy.BackgroundColor3 = if available then Color3.fromRGB(40, 160, 90) else Color3.fromRGB(70, 82, 96)
			continue
		end
		local price: number? = nil
		local expand = (player:GetAttribute("Expand") or 0) :: number
		local needExpand = false -- 구역 확장을 해야 더 올릴 수 있음
		if entry.kind == "Expand" then
			price = Config.Expansion.Costs[expand + 1]
			entry.info.Text = if price
				then ("지금 %d단계 → %d단계 · 받침대 최대 %d칸"):format(expand, expand + 1, 14 + Config.Expansion.PadsPerLevel * (expand + 1))
				else ("최고 단계 (%d단계 · 받침대 최대 %d칸)"):format(expand, 14 + Config.Expansion.PadsPerLevel * expand)
		elseif entry.kind == "Item" then
			price = Config.itemPrice(entry.id, income)
			if entry.id == "EMP" then
				local ready = ((player:GetAttribute("EmpReadyAt") or 0) :: number) - t
				entry.info.Text = if ready > 0 then ("충전 중 %d초"):format(math.ceil(ready))
					elseif empCharges > 0 then ("무료 EMP %d개 남음 · 누르면 무료로 사용"):format(empCharges)
					else "사면 바로 터져요 · 가격은 내 수입에 따라 올라요"
				if ready > 0 then
					price = nil
				elseif empCharges > 0 then
					price = 0
				end
			else
				local left = ((player:GetAttribute("GlovesUntil") or 0) :: number) - t
				entry.info.Text = if left > 0 then ("착용 중 %d:%02d"):format(left // 60, math.floor(left) % 60) else "가격은 내 수입에 따라 올라요"
				if left > 0 then
					price = nil
				end
			end
		else
			local level = upgrades[entry.id] or 0
			local current = Config.upgradeValue(entry.id, level)
			price = Config.upgradeCost(entry.id, level)
			local isToggle = #Config.Upgrades[entry.id].values == 2 and Config.Upgrades[entry.id].values[1] == 0
			if isToggle then
				entry.info.Text = if current > 0 then "보유 중" else "아직 없음"
			else
				entry.info.Text = if price
					then ("현재 %s → 다음 %s"):format(tostring(current), tostring(Config.upgradeValue(entry.id, level + 1)))
					else ("최고 단계 (%s)"):format(tostring(current))
			end
			if price and level >= Config.upgradeCap(entry.id, expand) then
				needExpand = true
				price = nil
				entry.info.Text = ("현재 %s · 더 올리려면 🏗 구역 확장 %d단계 필요"):format(tostring(current), expand + 1)
			end
		end
		if price == 0 then
			entry.buy.Text = "⚡ 무료 사용"
			entry.buy.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
			entry.buy.Active = true
		elseif price then
			entry.buy.Text = "💰 " .. Config.formatMoney(price)
			entry.buy.BackgroundColor3 = if money >= price then Color3.fromRGB(60, 140, 80) else Color3.fromRGB(90, 70, 70)
			entry.buy.Active = true
		else
			entry.buy.Text = if entry.kind == "Item" then "사용 중" elseif needExpand then "🔒 확장 필요" else "완료"
			entry.buy.BackgroundColor3 = Color3.fromRGB(70, 82, 96)
			entry.buy.Active = false
		end
	end
end

-- 경보기: 침입자를 잠깐 빨갛게 표시한다
local function highlightIntruder(userId: number)
	local intruder = Players:GetPlayerByUserId(userId)
	local character = intruder and intruder.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- 벽 너머로도 보이게
	highlight.Parent = character
	task.delay(6, function()
		highlight:Destroy()
	end)
end

-- 알림 (위쪽 가운데에 잠깐 떴다 사라짐)
local toastArea = Instance.new("Frame")
toastArea.AnchorPoint = Vector2.new(0.5, 0)
-- 오른쪽 위 패널의 왼쪽 영역 가운데, 신화 타이머 아래. 위치·폭은 fitWindows가 패널 배율에 맞춰 고친다
toastArea.Position = UDim2.new(0.5, -131, 0, 96)
toastArea.Size = UDim2.new(1, -286, 0, 200)
toastArea.BackgroundTransparency = 1
toastArea.Parent = gui
local toastLayout = Instance.new("UIListLayout")
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastArea

local toastColors = {
	Info = Color3.fromRGB(40, 60, 80),
	Alert = Color3.fromRGB(150, 50, 50),
	Global = Color3.fromRGB(150, 110, 20),
	Money = Color3.fromRGB(40, 120, 60),
}
local function toast(kind: string, text: string)
	local box = Instance.new("TextLabel")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.BackgroundColor3 = toastColors[kind] or toastColors.Info
	box.BackgroundTransparency = 0.1
	box.TextColor3 = white
	box.Font = Enum.Font.GothamBold
	box.TextSize = 15
	box.TextWrapped = true
	box.Text = text
	box.Parent = toastArea
	corner(box, 8)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(460, 30)
	constraint.Parent = box
	-- 너무 많이 쌓이면 오래된 것부터 지운다
	local count = 0
	for _, child in toastArea:GetChildren() do
		if child:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in toastArea:GetChildren() do
			if child:IsA("TextLabel") and child ~= box then
				child:Destroy()
				break
			end
		end
	end
	task.delay(if kind == "Money" then 1.5 else 3.5, function()
		if box.Parent then
			TweenService:Create(box, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(0.45, function()
				box:Destroy()
			end)
		end
	end)
end
-- 기부 큰 연출: 화면 가운데 위쪽에 크게 띄웠다가 사라진다 (계속 기부하면 다시 커진다)
local donateBurst = Instance.new("TextLabel")
donateBurst.Name = "DonateBurst"
donateBurst.AnchorPoint = Vector2.new(0.5, 0.5)
donateBurst.Position = UDim2.fromScale(0.5, 0.26)
donateBurst.Size = UDim2.fromScale(0.6, 0.2)
donateBurst.BackgroundColor3 = Color3.fromRGB(40, 28, 12)
donateBurst.BackgroundTransparency = 0.15
donateBurst.Font = Enum.Font.GothamBlack
donateBurst.TextScaled = true
donateBurst.TextColor3 = Color3.fromRGB(255, 214, 90)
donateBurst.TextStrokeColor3 = Color3.fromRGB(28, 18, 10)
donateBurst.TextStrokeTransparency = 0
donateBurst.ZIndex = 50
donateBurst.Visible = false
donateBurst.Parent = gui
corner(donateBurst, 18)
local burstStroke = Instance.new("UIStroke")
burstStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
burstStroke.Color = Color3.fromRGB(255, 190, 60)
burstStroke.Thickness = 4
burstStroke.Parent = donateBurst
local burstPadding = Instance.new("UIPadding")
burstPadding.PaddingTop = UDim.new(0, 10)
burstPadding.PaddingBottom = UDim.new(0, 10)
burstPadding.PaddingLeft = UDim.new(0, 16)
burstPadding.PaddingRight = UDim.new(0, 16)
burstPadding.Parent = donateBurst
local burstScale = Instance.new("UIScale")
burstScale.Parent = donateBurst
local burstToken = 0
local function showDonateBurst(text: string)
	burstToken += 1
	local token = burstToken
	donateBurst.Text = text
	donateBurst.BackgroundTransparency = 0.15
	donateBurst.TextTransparency = 0
	donateBurst.TextStrokeTransparency = 0
	burstStroke.Transparency = 0
	donateBurst.Visible = true
	burstScale.Scale = 0.4
	TweenService:Create(burstScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		if token ~= burstToken then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(donateBurst, fade, { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(burstStroke, fade, { Transparency = 1 }):Play()
		task.delay(0.45, function()
			if token == burstToken then
				donateBurst.Visible = false
			end
		end)
	end)
end

notifyRemote.OnClientEvent:Connect(function(kind: unknown, text: unknown, userId: unknown)
	if typeof(kind) == "string" and typeof(text) == "string" then
		if kind == "Donate" then
			showDonateBurst(text)
		else
			toast(if kind == "Alarm" or kind == "Stolen" then "Alert" else kind, text)
		end
		if kind == "Alarm" and typeof(userId) == "number" then
			highlightIntruder(userId)
		end
	end
end)

-- 컨베이어 벨트 (이 화면에서 움직여 그린다) ------------------------------------------
local startPos = beltPart:GetAttribute("StartPos") :: Vector3
local endPos = beltPart:GetAttribute("EndPos") :: Vector3
local direction = (endPos - startPos).Unit
local beltFolder = Instance.new("Folder")
beltFolder.Name = "JunkyardBeltLocal"
beltFolder.Parent = workspace

type BeltVisual = { model: Model, spawnTime: number, height: number }
local beltVisuals: { [number]: BeltVisual } = {}

local function makeBeltRobot(id: number, robotId: string): Model
	local robot = Config.getRobot(robotId)
	local rarity = Config.rarityOf(robotId)
	local size = if rarity then rarity.size else 1
	local color = if rarity then rarity.color else white
	local model = Instance.new("Model")
	model.Name = "BeltRobot"
	local function piece(name: string, partSize: Vector3, offset: Vector3, pieceColor: Color3): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Size = partSize * size
		object.CFrame = CFrame.new(offset * size)
		object.Color = pieceColor
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.Parent = model
		return object
	end
	local body = piece("Body", Vector3.new(2.2, 2, 1.7), Vector3.zero, color)
	local head = piece("Head", Vector3.new(2.4, 1.5, 1.9), Vector3.new(0, 1.75, 0), color)
	head.Orientation = Vector3.new(0, 0, 15) -- 고장 나서 기운 머리
	for _, dx in { -0.5, 0.5 } do
		piece("Eye", Vector3.new(0.3, 0.3, 0.1), Vector3.new(dx, 1.85, -0.98), dark)
	end
	-- 로봇마다 다른 머리 장식 (기운 머리를 따라 기운다)
	local style = if robot and robot.style then Config.RobotStyles[robot.style] else nil
	if style then
		for _, spec in style do
			local part = piece(spec.name, spec.size, Vector3.zero, color:Lerp(Color3.new(0, 0, 0), 0.35))
			part.CFrame = head.CFrame * CFrame.new(spec.offset * size)
		end
	end
	model.PrimaryPart = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = if robot and rarity then ("%s [%s] · 초당 %s"):format(robot.name, rarity.name, Config.formatMoney(Config.robotIncome(robotId))) else robotId
	prompt.ActionText = if rarity then ("구매 %s"):format(Config.formatMoney(Config.robotValue(robotId))) else "구매"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function()
		actionRemote:FireServer("Buy", id)
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.3 * size, 0)
	billboard.MaxDistance = 70
	billboard.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 14
	text.TextStrokeTransparency = 0.3
	text.TextColor3 = color
	text.Text = if robot and rarity then ("%s [%s] 초당 %s\n💰 %s"):format(robot.name, rarity.name, Config.formatMoney(Config.robotIncome(robotId)), Config.formatMoney(Config.robotValue(robotId))) else robotId
	text.Parent = billboard
	model.Parent = beltFolder
	return model
end

local function addBeltItem(item: any)
	if typeof(item) ~= "table" or beltVisuals[item.id] then
		return
	end
	local rarity = Config.rarityOf(item.robotId)
	beltVisuals[item.id] = {
		model = makeBeltRobot(item.id, item.robotId),
		spawnTime = item.spawnTime,
		height = if rarity then rarity.size else 1,
	}
end

local function removeBeltItem(id: number)
	local visual = beltVisuals[id]
	if visual then
		visual.model:Destroy()
		beltVisuals[id] = nil
	end
end

beltRemote.OnClientEvent:Connect(function(kind: unknown, payload: any)
	if kind == "Add" then
		addBeltItem(payload)
	elseif kind == "Remove" and typeof(payload) == "number" then
		removeBeltItem(payload)
	elseif kind == "Snapshot" and typeof(payload) == "table" then
		for _, item in payload do
			addBeltItem(item)
		end
	end
end)
beltRemote:FireServer("Sync")

local facing = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, 1)) -- 북쪽 기지 쪽을 보게
RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, visual in beltVisuals do
		local position = startPos + direction * Config.BeltSpeed * (now - visual.spawnTime)
		visual.model:PivotTo(CFrame.new(position + Vector3.new(0, visual.height, 0)) * facing)
	end
end)

-- 받침대 버튼 문구: 내 기지면 팔기, 남의 기지면 훔치기 -----------------------------------
local function syncPadPrompts()
	for _, base in basesFolder:GetChildren() do
		local mine = base:GetAttribute("OwnerUserId") == player.UserId
		local pads = base:FindFirstChild("Pads")
		if pads then
			for _, pad in pads:GetChildren() do
				local prompt = pad:FindFirstChild("RobotPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					if mine then
						local key = pad:GetAttribute("RobotKey") -- 서버가 받침대에 적어 둔 로봇 키 (변종 포함)
						prompt.ActionText = if typeof(key) == "string" and Config.isValidKey(key)
							then ("팔기 +%s"):format(Config.formatMoney(Config.robotValue(key) * Config.SellRate))
							else "팔기"
					else
						prompt.ActionText = "훔치기"
					end
					-- 도둑 장갑을 끼면 남의 받침대를 짧게 눌러도 된다 (서버도 같은 시간으로 확인)
					local gloves = workspace:GetServerTimeNow() < ((player:GetAttribute("GlovesUntil") or 0) :: number)
					prompt.HoldDuration = if not mine and gloves then Config.GlovesHold else Config.StealHold
				end
			end
		end
	end
end

-- 화면 갱신 ----------------------------------------------------------------------
local function render()
	gui.Enabled = player:GetAttribute("Mode") == "Junkyard"
	contestPanel.Visible = not shop.Visible and not catalog.Visible
	renderContest(workspace:GetServerTimeNow())
	local money = (player:GetAttribute("Money") or 0) :: number
	local income = (player:GetAttribute("Income") or 0) :: number
	local multiplier = (player:GetAttribute("Multiplier") or 1) :: number
	moneyLabel.Text = "💰 " .. Config.formatMoney(money)
	incomeLabel.Text = ("초당 +%s  (도감 x%.2f · 환생 %s)"):format(Config.formatMoney(income), multiplier, Config.rebirthMark((player:GetAttribute("Rebirth") or 0) :: number))
	saveLabel.Text = if player:GetAttribute("Loading") == true then "⏳ 불러오는 중"
		elseif player:GetAttribute("SaveOff") == true then "⚠ 저장 안 됨"
		else ""

	local carrying = player:GetAttribute("Carrying")
	local stunned = ((player:GetAttribute("StunnedUntil") or 0) :: number) - workspace:GetServerTimeNow()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local speedText = if humanoid then ("🏃 속도 %.1f"):format(humanoid.WalkSpeed) else "" -- 서버가 정한 현재 걷기 속도
	if stunned > 0 then
		carryLabel.Text = ("⚡ EMP에 맞아 멈춤! %d초"):format(math.ceil(stunned))
		carryLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	elseif typeof(carrying) == "string" and carrying ~= "" then
		local robot = Config.getRobot(carrying)
		local stolen = player:GetAttribute("CarryStolen") == true
		carryLabel.Text = ("%s %s 운반 중 → 빈 받침대로\n무게 −%d · %s"):format(if stolen then "🦹 훔친" else "📦", if robot then robot.name else carrying, Config.carrySlow(carrying), speedText)
		carryLabel.TextColor3 = if stolen then Color3.fromRGB(255, 140, 140) else white
	else
		carryLabel.Text = "로봇을 기지에 놓으면 돈을 벌어요.\n" .. speedText .. " · 받침대를 채울수록 빨라져요"
		carryLabel.TextColor3 = muted
	end

	local t = workspace:GetServerTimeNow()
	local mythicDue = workspace:GetAttribute("MythicDueAt")
	local mythicLeft = (if typeof(mythicDue) == "number" then mythicDue else 0) - t
	if typeof(mythicDue) ~= "number" then
		mythicBanner.Visible = false
	elseif mythicLeft > 0 then
		local left = math.ceil(mythicLeft)
		local warn = left <= Config.MythicWarnSeconds
		local final = left <= 10
		mythicBanner.Text = if warn
			then ("⚠ 신화 로봇 등장까지 %d:%02d · 벨트로!"):format(left // 60, left % 60)
			else ("💎 신화 보장까지 %d:%02d"):format(left // 60, left % 60)
		mythicBanner.Visible = true
		mythicBanner.BackgroundColor3 = if final then Color3.fromRGB(150, 20, 40) elseif warn then Color3.fromRGB(90, 20, 40) else Color3.fromRGB(30, 34, 44)
		mythicBannerStroke.Transparency = if warn and left % 2 == 0 then 0 elseif warn then 0.5 else 0.7
		local size = if final then 1.8 elseif warn then 1.4 else 1
		if warn and left ~= mythicLastSecond then
			-- 매초 톡 튀었다가 제자리로
			mythicScale.Scale = size * 1.15
			TweenService:Create(mythicScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size }):Play()
		elseif not warn then
			mythicScale.Scale = size
		end
		mythicLastSecond = left
	elseif mythicLeft > -4 then
		mythicBanner.Text = "🔥 신화 로봇 등장!"
		mythicBanner.Visible = true
		mythicScale.Scale = 1.8
	else
		mythicBanner.Visible = false
	end
	local trainUntil = (workspace:GetAttribute("TrainUntil") or 0) :: number
	local nextTrain = (workspace:GetAttribute("NextTrainAt") or 0) :: number
	local rainUntil = (workspace:GetAttribute("RainUntil") or 0) :: number
	local giantUntil = (workspace:GetAttribute("GiantBoostUntil") or 0) :: number
	if t < giantUntil then
		local left = math.ceil(giantUntil - t)
		trainLabel.Text = ("🤖 거대 로봇 가동! 수입 x%d · %d:%02d"):format(Config.GiantRobot.BoostMultiplier, left // 60, left % 60)
	elseif t < rainUntil then
		trainLabel.Text = ("✨ 희귀 로봇 비! %d초"):format(math.ceil(rainUntil - t))
	elseif t < trainUntil then
		trainLabel.Text = ("🚂 희귀 로봇 열차 운행 중! %d초"):format(math.ceil(trainUntil - t))
	elseif nextTrain > t then
		local left = math.ceil(nextTrain - t)
		trainLabel.Text = ("🚂 다음 희귀 로봇 열차 %d:%02d"):format(left // 60, left % 60)
	else
		trainLabel.Text = ""
	end
	local lockedUntil = (player:GetAttribute("LockedUntil") or 0) :: number
	local cooldownUntil = (player:GetAttribute("LockCooldownUntil") or 0) :: number
	if t < lockedUntil then
		lockButton.Text = ("🛡 방어 중 %d초"):format(math.ceil(lockedUntil - t))
		lockButton.BackgroundColor3 = Color3.fromRGB(40, 150, 200)
	elseif t < cooldownUntil then
		lockButton.Text = ("충전 중 %d초"):format(math.ceil(cooldownUntil - t))
		lockButton.BackgroundColor3 = Color3.fromRGB(70, 82, 96)
	else
		lockButton.Text = "🛡 방어막 켜기"
		lockButton.BackgroundColor3 = Color3.fromRGB(60, 120, 170)
	end

	-- 도감
	local owned: { [string]: boolean } = {}
	local ok, list = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("Catalog") or "[]") :: string)
	end)
	local count = 0
	if ok and typeof(list) == "table" then
		for _, id in list do
			owned[id] = true
			count += 1
		end
	end
	local variantId = if catalogPage > 0 then Config.VariantOrder[catalogPage] else nil
	local variant = if variantId then Config.Variants[variantId] else nil
	local variantOwned: { [string]: boolean } = {}
	local okVariants, variantList = pcall(function()
		return HttpService:JSONDecode((player:GetAttribute("VariantCatalog") or "[]") :: string)
	end)
	if okVariants and typeof(variantList) == "table" then
		for _, key in variantList do
			variantOwned[key] = true
		end
	end
	pageButton.Text = if variant then ("%s %s ▶"):format(variant.mark, variant.name) else "기본 ▶"
	local pageCount = 0
	for i, robot in Config.Robots do
		local rarity = Config.Rarities[robot.rarity]
		local row = catalogRows[i]
		local key = if variantId then robot.id .. "@" .. variantId else robot.id
		local has = if variantId then variantOwned[key] == true else owned[robot.id] == true
		if has then
			pageCount += 1
			row.Text = ("✓ %s\n[%s] 초당 %s"):format(Config.robotName(key), rarity.name, Config.formatMoney(Config.robotIncome(key)))
			row.TextColor3 = if variant then variant.color else rarity.color
		else
			row.Text = ("○ ???\n[%s]"):format(rarity.name)
			row.TextColor3 = muted
		end
	end
	local level = (player:GetAttribute("Rebirth") or 0) :: number
	catalogTitle.Text = if variant
		then ("%s %s 도감 %d/%d%s"):format(variant.mark, variant.name, pageCount, #Config.Robots,
			if level < variant.minRebirth then (" (환생 %d번부터)"):format(variant.minRebirth) else "")
		else ("로봇 도감 %d/%d"):format(count, #Config.Robots)
	local lines = { "세트 (등급의 로봇을 모두 모으면 수입 증가 + 즉시 보상):" }
	for _, rarityId in Config.RarityOrder do
		local rarity = Config.Rarities[rarityId]
		local have = 0
		for _, robot in Config.Robots do
			if robot.rarity == rarityId and owned[robot.id] then
				have += 1
			end
		end
		local total = Config.robotCount(rarityId)
		table.insert(lines, ("%s %s %d/%d → +%d%% · 🎁%s"):format(if have >= total then "✓" else "·", rarity.name, have, total, math.floor(rarity.setBonus * 100), Config.formatMoney(rarity.setReward)))
	end
	if variant and variantId then
		table.insert(lines, ("%s %s · +%d%%"):format(if pageCount == #Config.Robots then "✓ 획득" else "완성 보상",
			Config.VariantPageTitles[variantId], math.round(variant.pageBonus * 100)))
	else
		table.insert(lines, ("%s %s · +%d%%"):format(if count == #Config.Robots then "✓ 획득" else ("%d종 완성"):format(#Config.Robots),
			Config.FullCatalogTitle, math.round(Config.FullCatalogBonus * 100)))
	end
	bonusLabel.Text = table.concat(lines, "   ")
end

-- 첫 접속 안내 (튜토리얼) --------------------------------------------------------------
-- 서버가 정한 단계(플레이어 속성 TutorialStep 1~5, 0 = 끝)를 보여 주기만 한다
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local tutorialTexts = {
	"🛒 가운데 벨트의 로봇에 다가가서 " .. (if touch then "구매 버튼을 누르세요" else "[E]를 눌러 사세요") .. " (싼 일반 로봇부터!)",
	"📦 로봇을 든 채로 내 기지(화살표) 안에 들어가면 받침대에 놓여요",
	"💰 로봇이 금고에 돈을 쌓아요. 금고(노란 상자)를 밟아 돈을 받으세요",
	"🛒 왼쪽 위 [상점]을 열어 방해·방어·도움 아이템을 구경해 보세요",
	"📖 [도감]을 열어 앞으로 모을 로봇을 확인해 보세요",
}
local tutorialBar = Instance.new("Frame")
-- 화면 아래 가운데 (위쪽은 채팅창·패널·신화 타이머 자리)
tutorialBar.AnchorPoint = Vector2.new(0.5, 1)
tutorialBar.Position = UDim2.new(0.5, 0, 1, -16)
tutorialBar.Size = UDim2.fromOffset(520, 52)
tutorialBar.BackgroundColor3 = Color3.fromRGB(150, 110, 20)
tutorialBar.BackgroundTransparency = 0.08
tutorialBar.Visible = false
tutorialBar.Parent = gui
corner(tutorialBar, 10)
hudScale(tutorialBar)
local tutorialMax = Instance.new("UISizeConstraint")
tutorialMax.MaxSize = Vector2.new(560, 52)
tutorialMax.Parent = tutorialBar
local tutorialLabel = label(tutorialBar, UDim2.fromOffset(12, 4), UDim2.new(1, -96, 1, -8), 13, white)
local skipButton = button(tutorialBar, "건너뛰기", UDim2.new(1, -80, 0.5, -18), UDim2.fromOffset(72, 36), Color3.fromRGB(90, 70, 20))
skipButton.TextSize = 12
skipButton.Activated:Connect(function()
	actionRemote:FireServer("TutorialSkip")
end)
-- 해야 할 곳 위에 뜨는 화살표 (내 화면에만 보임)
local arrow = Instance.new("BillboardGui")
arrow.Name = "TutorialArrow"
arrow.Size = UDim2.fromOffset(70, 70)
arrow.AlwaysOnTop = true
arrow.Enabled = false
arrow.ResetOnSpawn = false
arrow.Parent = gui.Parent -- BillboardGui는 ScreenGui 안에서는 보이지 않아 PlayerGui에 둔다
local arrowText = Instance.new("TextLabel")
arrowText.Size = UDim2.fromScale(1, 1)
arrowText.BackgroundTransparency = 1
arrowText.Text = "⬇"
arrowText.TextScaled = true
arrowText.TextColor3 = Color3.fromRGB(255, 220, 90)
arrowText.TextStrokeTransparency = 0.2
arrowText.Parent = arrow
local highlightStroke = Instance.new("UIStroke") -- 4·5단계에 상점·도감 버튼 테두리를 반짝인다
highlightStroke.Color = Color3.fromRGB(255, 220, 90)
highlightStroke.Thickness = 3
highlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function myBase(): Instance?
	for _, base in basesFolder:GetChildren() do
		if base:GetAttribute("OwnerUserId") == player.UserId then
			return base
		end
	end
	return nil
end

local function renderTutorial()
	local step = (player:GetAttribute("TutorialStep") or 0) :: number
	local text = tutorialTexts[step]
	tutorialBar.Visible = text ~= nil
	if not text then
		arrow.Enabled = false
		highlightStroke.Parent = nil
		return
	end
	tutorialLabel.Text = ("안내 %d/%d  %s"):format(step, #tutorialTexts, text)
	local base = myBase()
	local target: Instance? = nil
	local height = 6
	if step == 1 then
		target = beltPart
	elseif step == 2 then
		target = base and base:FindFirstChild("Floor")
		height = 10
	elseif step == 3 then
		target = base and base:FindFirstChild("Vault")
		height = 4
	end
	arrow.Adornee = target
	arrow.StudsOffsetWorldSpace = Vector3.new(0, height + math.sin(os.clock() * 4) * 0.6, 0)
	arrow.Enabled = target ~= nil
	highlightStroke.Parent = if step == 4 then shopButton elseif step == 5 then catalogButton else nil
end

-- 작은 화면(휴대폰)에서 상점·도감 창이 화면 밖으로 나가지 않게 줄인다
local function fitWindows()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.clamp(math.min((size.Y - 70) / 420, (size.X - 20) / 440), 0.55, 1.6)
	catalogScale.Scale = scale
	-- 패널·대회·안내·기부 창: 큰 화면에서 글씨가 작지 않게 키운다 (휴대폰은 0.85까지 줄임)
	local hud = math.clamp(math.min(size.X / 760, size.Y / 540), 0.85, 1.45)
	for _, object in hudScales do
		object.Scale = hud
	end
	local panelWidth = 250 * hud
	contestPanel.Position = UDim2.new(1, -12, 0, 10 + 150 * hud + 6)
	toastArea.Position = UDim2.new(0.5, -(panelWidth + 24) / 2, 0, 96)
	mythicBanner.Position = UDim2.new(0.5, -(panelWidth + 24) / 2, 0, 8) -- 커져도 오른쪽 패널에 닿지 않게
	toastArea.Size = UDim2.new(1, -(panelWidth + 36), 0, 200)
	-- 상점은 큰 화면에서 최대 2배까지 키운다 (기본 440×400)
	shopScale.Scale = math.clamp(math.min((size.Y - 80) / 400, (size.X - 40) / 440), 0.55, 2)
end

-- 방어막 남은 시간: 모든 기지 위에 크게 띄운다 (누구 기지가 잠겼는지 멀리서도 보이게)
local shieldLabels: { [Instance]: TextLabel } = {}
local function syncShieldTimers()
	local t = workspace:GetServerTimeNow()
	for _, base in basesFolder:GetChildren() do
		local floor = base:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local text = shieldLabels[base]
			if not text then
				local board = Instance.new("BillboardGui")
				board.Name = "ShieldTimer"
				board.Size = UDim2.fromOffset(240, 44)
				board.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
				board.AlwaysOnTop = true
				board.MaxDistance = 300
				board.Parent = floor
				local newText = Instance.new("TextLabel")
				newText.Size = UDim2.fromScale(1, 1)
				newText.BackgroundColor3 = Color3.fromRGB(20, 60, 90)
				newText.BackgroundTransparency = 0.2
				newText.TextColor3 = Color3.fromRGB(150, 230, 255)
				newText.Font = Enum.Font.GothamBold
				newText.TextSize = 24
				newText.Parent = board
				corner(newText, 8)
				shieldLabels[base] = newText
				text = newText
			end
			local remaining = ((base:GetAttribute("LockedUntil") or 0) :: number) - t
			local label = text :: TextLabel
			label.Visible = remaining > 0
			if remaining > 0 then
				label.Text = ("🛡 방어막 %d초"):format(math.ceil(remaining))
			end
		end
	end
end

-- 거대 로봇 기부 창 (2026-11-17) --------------------------------------------------------
-- 단말기 버튼을 누르면 열린다. 금액은 화면에 보여 주기만 하고, 실제 금액은 서버가 같은 식으로 다시 계산한다
local donateWindow = Instance.new("Frame")
donateWindow.Name = "DonateWindow"
donateWindow.AnchorPoint = Vector2.new(0.5, 0.5)
donateWindow.Position = UDim2.fromScale(0.5, 0.55)
donateWindow.Size = UDim2.fromOffset(320, 190)
donateWindow.BackgroundColor3 = dark
donateWindow.BackgroundTransparency = 0.04
donateWindow.Visible = false
donateWindow.Parent = gui
corner(donateWindow, 12)
hudScale(donateWindow)
local donateTitle = label(donateWindow, UDim2.fromOffset(14, 8), UDim2.new(1, -64, 0, 24), 16, white)
donateTitle.Text = "🔧 거대 로봇 부품 기부"
local donateInfo = label(donateWindow, UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 36), 12, muted)
local donateClose = button(donateWindow, "X", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(36, 30), Color3.fromRGB(120, 60, 60))
donateClose.Activated:Connect(function()
	donateWindow.Visible = false
end)
local donateButtons: { TextButton } = {}
for tier, info in Config.GiantRobot.Tiers do
	local tierButton = button(donateWindow, info.name, UDim2.new((tier - 1) / 3, 10, 0, 78), UDim2.new(1 / 3, -14, 0, 96), Color3.fromRGB(170, 120, 40))
	tierButton.TextSize = 13
	tierButton.TextWrapped = true
	tierButton.Activated:Connect(function()
		actionRemote:FireServer("Donate", tier)
	end)
	donateButtons[tier] = tierButton
end
local function renderDonate()
	if not donateWindow.Visible then
		return
	end
	local income = (player:GetAttribute("Income") or 0) :: number
	for tier, info in Config.GiantRobot.Tiers do
		local amount = math.max(info.min, math.floor(income * info.seconds))
		donateButtons[tier].Text = ("%s\n초당 수입 %d초어치\n💰 %s"):format(info.name, info.seconds, Config.formatMoney(amount))
	end
	local goal = (workspace:GetAttribute("GiantGoal") or 0) :: number
	local progress = (workspace:GetAttribute("GiantProgress") or 0) :: number
	local state = workspace:GetAttribute("GiantState")
	donateInfo.Text = if state == "Building" and goal > 0
		then ("조립 %d%% (%s / %s) · 완성하면 서버 전체 수입 x%d!"):format(math.floor(progress / goal * 100), Config.formatMoney(progress), Config.formatMoney(goal), Config.GiantRobot.BoostMultiplier)
		else "지금은 조립 중이 아니에요. 로봇 머리 위 안내를 보세요."
end
task.spawn(function()
	local robot = junkyard:WaitForChild("GiantRobot", 30)
	local terminal = robot and robot:WaitForChild("Terminal", 10)
	local prompt = terminal and terminal:WaitForChild("DonatePrompt", 10)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function()
			donateWindow.Visible = true
			shop.Visible = false
			catalog.Visible = false
			renderDonate()
		end)
	end
end)

-- 소리 (2026-11-17) ----------------------------------------------------------------
-- 소리는 이 화면에서만 재생한다(서버는 알림·속성만 보낸다). 오디오 번호는 JunkyardConfig.Sounds.
-- 🔊 버튼: 모두 켬 → 음악 끔 → 모두 끔 (이번 접속 동안만 기억)
local SoundService = game:GetService("SoundService")
local soundMode = 0 -- 0 모두 켬, 1 음악 끔, 2 모두 끔
local soundFolder = Instance.new("Folder")
soundFolder.Name = "JunkyardSounds"
soundFolder.Parent = SoundService
local function makeSound(id: string, parent: Instance): Sound
	local info = Config.Sounds[id]
	local sound = Instance.new("Sound")
	sound.Name = id
	sound.SoundId = "rbxassetid://" .. tostring(info.asset)
	sound.Volume = info.volume
	sound.Looped = info.loop == true
	sound.Parent = parent
	return sound
end
local effects: { [string]: Sound } = {}
for _, id in { "Buy", "Place", "Collect", "Alarm", "Shield", "Fanfare" } do
	effects[id] = makeSound(id, soundFolder)
end
local music = makeSound("Music", soundFolder)
-- 벨트 소리는 벨트 파트에 붙여 가까이 갈수록 커지게 한다
local beltSound = makeSound("Belt", beltPart)
beltSound.RollOffMode = Enum.RollOffMode.InverseTapered
beltSound.RollOffMinDistance = 12
beltSound.RollOffMaxDistance = 90

local function play(id: string)
	local sound = effects[id]
	if sound and soundMode < 2 then
		sound:Play()
	end
end
local function applySoundMode()
	local effectsOn = soundMode < 2
	local musicOn = soundMode == 0
	if musicOn and gui.Enabled then
		if not music.IsPlaying then
			music:Play()
		end
	else
		music:Stop()
	end
	if effectsOn and gui.Enabled then
		if not beltSound.IsPlaying then
			beltSound:Play()
		end
	else
		beltSound:Stop()
	end
end

local muteButton = button(panel, "🔊", UDim2.new(1, -42, 0, 6), UDim2.fromOffset(34, 28), Color3.fromRGB(52, 64, 76))
muteButton.TextSize = 16
local muteTexts = { "🔊", "🎵✕", "🔇" }
muteButton.Activated:Connect(function()
	soundMode = (soundMode + 1) % 3
	muteButton.Text = muteTexts[soundMode + 1]
	applySoundMode()
end)
gui:GetPropertyChangedSignal("Enabled"):Connect(applySoundMode)

-- 알림 종류로 고르는 소리: 돈 받기 → 동전, 경보 → 경보음
notifyRemote.OnClientEvent:Connect(function(kind: unknown)
	if kind == "Money" then
		play("Collect")
	elseif kind == "Alarm" or kind == "Stolen" then
		play("Alarm") -- 경보기(침입)와 도둑맞은 순간
	elseif kind == "Donate" then
		play("Collect")
	end
end)
-- 속성 변화로 고르는 소리 (접속 직후 불러오기 중에는 내지 않는다)
local soundReadyAt = os.clock() + 6
local function ready(): boolean
	return os.clock() > soundReadyAt and player:GetAttribute("Loading") ~= true
end
local lastCarry = player:GetAttribute("Carrying")
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	local carrying = player:GetAttribute("Carrying")
	local was = lastCarry
	lastCarry = carrying
	if not ready() then
		return
	end
	if typeof(carrying) == "string" and carrying ~= "" and (was == nil or was == "") and player:GetAttribute("CarryStolen") ~= true then
		play("Buy") -- 벨트에서 샀다
	elseif (carrying == nil or carrying == "") and typeof(was) == "string" and was ~= "" then
		play("Place") -- 내려놓았다 (받침대 배치)
	end
end)
local lastLocked = (player:GetAttribute("LockedUntil") or 0) :: number
player:GetAttributeChangedSignal("LockedUntil"):Connect(function()
	local value = (player:GetAttribute("LockedUntil") or 0) :: number
	if ready() and value > lastLocked + 1 and value > workspace:GetServerTimeNow() then
		play("Shield")
	end
	lastLocked = value
end)
local lastRebirth = (player:GetAttribute("Rebirth") or 0) :: number
player:GetAttributeChangedSignal("Rebirth"):Connect(function()
	local value = (player:GetAttribute("Rebirth") or 0) :: number
	if ready() and value > lastRebirth then
		play("Fanfare")
	end
	lastRebirth = value
end)
workspace:GetAttributeChangedSignal("ContestType"):Connect(function()
	local kind = workspace:GetAttribute("ContestType")
	if ready() and typeof(kind) == "string" and kind ~= "" then
		play("Fanfare") -- 서버 대회 시작
	end
end)
workspace:GetAttributeChangedSignal("GiantState"):Connect(function()
	if ready() and workspace:GetAttribute("GiantState") == "Active" then
		play("Fanfare") -- 거대 로봇 완성
	end
end)
task.delay(2, applySoundMode)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	render()
	syncShieldTimers()
	renderShop()
	renderTutorial()
	fitWindows()
	renderDonate()
end)
-- 들고 가는 로봇의 "빼앗기" 버튼: 내 로봇 것은 숨기고, 도둑 장갑이면 짧게 (서버도 같은 시간으로 확인)
local function syncSnatchPrompts()
	local gloves = workspace:GetServerTimeNow() < ((player:GetAttribute("GlovesUntil") or 0) :: number)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character then
			for _, object in character:GetDescendants() do
				if object:IsA("ProximityPrompt") and object.Name == "SnatchPrompt" then
					object.Enabled = other ~= player
					object.HoldDuration = if gloves then Config.GlovesHold else Config.StealHold
				end
			end
		end
	end
end
local function watchOwnCharacter(character: Model)
	character.DescendantAdded:Connect(function(object)
		if object:IsA("ProximityPrompt") and object.Name == "SnatchPrompt" then
			object.Enabled = false -- 내가 들고 있는 로봇은 내가 빼앗을 수 없다
		end
	end)
end
if player.Character then
	watchOwnCharacter(player.Character)
end
player.CharacterAdded:Connect(watchOwnCharacter)
task.spawn(function()
	while true do
		syncPadPrompts()
		syncSnatchPrompts()
		task.wait(1)
	end
end)
render()
