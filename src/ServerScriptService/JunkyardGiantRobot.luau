--!strict
-- JunkyardGiantRobot: 서버 협력 거대 로봇 (서버 전용 모듈, Junkyard가 쓴다)
-- 흐름: Building(기부 받는 중) → 목표 달성 → Active(서버 전체 수입 x2, BoostSeconds) → Resting(쉬는 시간) → 다시 Building
-- 기부 금액은 서버가 정한다(클라이언트는 1·2·3 중 몇 번 버튼인지만 보낸다). 단말기 가까이에서만, 돈이 있어야 한다.
-- 저장하지 않는다: 이 서버 안에서만 진행되는 이벤트다. (기부한 돈은 이미 쓴 돈이라 서버가 닫혀도 문제없다)
-- 공개 속성(workspace): GiantState, GiantGoal, GiantProgress, GiantStage(0~5), GiantBoostUntil, GiantNextAt (서버 시간)
-- 맵: Workspace/Junkyard/GiantRobot — 파트 속성 Stage(1~5)로 조립 단계, Eye = 눈, Terminal = 기부 단말기, Head/Display = 진행 표시
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))
local G = Config.GiantRobot

export type Callbacks = {
	getPlayers: () -> { Player }, -- 목표 계산에 넣을 사람 (저장을 불러온 기지 주인)
	incomeOf: (Player) -> number, -- 지금 초당 수입
	takeMoney: (Player, number) -> boolean, -- 돈이 충분하면 빼고 true
	notify: (Player, string, string) -> (),
	notifyAll: (string) -> (),
	setTitle: (Player, string?) -> (), -- 머리 위 칭호 (nil이면 지움)
	onBoostChanged: () -> (), -- 수입 2배가 켜지거나 꺼질 때 모두의 수입 표시를 다시 계산
}

local Robot = {}
local cb: Callbacks? = nil
local model: Model? = nil
local status = "Building"
local goal = G.MinGoal
local progress = 0
local boostUntil = 0
local nextAt = 0
local donors: { [number]: { name: string, amount: number } } = {}
local lastDonate: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function Robot.incomeBoost(): number
	return if status == "Active" and now() < boostUntil then G.BoostMultiplier else 1
end

-- 기부 버튼 하나의 금액 (화면 표시와 서버가 같은 식을 쓴다)
function Robot.tierAmount(income: number, tier: number): number
	local info = G.Tiers[tier]
	return math.max(info.min, math.floor(income * info.seconds))
end

local function stage(): number
	if status ~= "Building" then
		return 5
	end
	return math.clamp(math.floor(progress / goal * 5), 0, 5)
end

local function topDonors(): { { name: string, amount: number } }
	local list = {}
	for _, entry in donors do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.amount > b.amount
	end)
	return list
end

-- 맵 표시: 단계에 따라 파트를 채우고, 진행 글씨를 바꾼다
local function render()
	workspace:SetAttribute("GiantState", status)
	workspace:SetAttribute("GiantGoal", goal)
	workspace:SetAttribute("GiantProgress", progress)
	workspace:SetAttribute("GiantStage", stage())
	workspace:SetAttribute("GiantBoostUntil", if status == "Active" then boostUntil else 0)
	workspace:SetAttribute("GiantNextAt", if status == "Resting" then nextAt else 0)
	local m = model
	if not m then
		return
	end
	local current = stage()
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			local partStage = part:GetAttribute("Stage")
			if typeof(partStage) == "number" then
				part.Transparency = if partStage <= current then 0 else 0.8
			end
			if part.Name == "Eye" then
				part.Material = if status == "Active" then Enum.Material.Neon else Enum.Material.Metal
				part.Color = if status == "Active" then Color3.fromRGB(90, 230, 255) else Color3.fromRGB(40, 44, 50)
			end
		end
	end
	local head = m:FindFirstChild("Head")
	local display = head and head:FindFirstChild("Display")
	local label = display and display:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		local lines = {}
		if status == "Building" then
			table.insert(lines, ("🔧 거대 로봇 조립 %d%%  (%s / %s)"):format(math.floor(progress / goal * 100), Config.formatMoney(progress), Config.formatMoney(goal)))
			table.insert(lines, "단말기에서 부품을 기부하면 완성 때 서버 전체 수입 x" .. G.BoostMultiplier .. "!")
		elseif status == "Active" then
			local left = math.max(0, math.ceil(boostUntil - now()))
			table.insert(lines, ("🤖 거대 로봇 가동 중! 서버 수입 x%d · %d:%02d"):format(G.BoostMultiplier, left // 60, left % 60))
		else
			local left = math.max(0, math.ceil(nextAt - now()))
			table.insert(lines, ("💤 거대 로봇 정비 중 · 다음 조립 %d:%02d"):format(left // 60, left % 60))
		end
		for rank, entry in topDonors() do
			if rank > 3 then
				break
			end
			table.insert(lines, ("%d. %s  %s"):format(rank, entry.name, Config.formatMoney(entry.amount)))
		end
		label.Text = table.concat(lines, "\n")
	end
end

local function computeGoal(): number
	local callbacks = cb :: Callbacks
	local total = 0
	for _, player in callbacks.getPlayers() do
		total += callbacks.incomeOf(player)
	end
	return math.max(G.MinGoal, math.floor(total * G.GoalSeconds))
end

local function startRound()
	status = "Building"
	progress = 0
	donors = {}
	goal = computeGoal()
	render()
end

local function complete(finisher: Player?)
	local callbacks = cb :: Callbacks
	status = "Active"
	boostUntil = now() + G.BoostSeconds
	local list = topDonors()
	local top = list[1]
	if finisher then
		callbacks.setTitle(finisher, G.TopTitle)
	end
	local finishedBy = if finisher then (" %s님이 마지막 부품을 조립해 %s 칭호 획득!"):format(finisher.DisplayName, G.TopTitle) else ""
	local topText = if top then (" 최고 기부자 %s님, 감사합니다!"):format(top.name) else ""
	callbacks.notifyAll(("🤖 거대 로봇이 깨어났어요! %d분 동안 서버 전체 수입 x%d!%s%s"):format(
		math.floor(G.BoostSeconds / 60), G.BoostMultiplier, finishedBy, topText))
	callbacks.onBoostChanged()
	render()
end

-- 기부 요청 처리. tier = 1·2·3 (화면 버튼 번호)
function Robot.donate(player: Player, tier: unknown)
	local callbacks = cb
	local m = model
	if not callbacks or not m or typeof(tier) ~= "number" or not G.Tiers[tier] then
		return
	end
	if status ~= "Building" then
		callbacks.notify(player, "Info", "거대 로봇이 지금은 조립 중이 아니에요.")
		return
	end
	if os.clock() - (lastDonate[player] or 0) < 0.5 then
		return
	end
	lastDonate[player] = os.clock()
	local terminal = m:FindFirstChild("Terminal")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not terminal or not terminal:IsA("BasePart") or not root or not root:IsA("BasePart")
		or (root.Position - terminal.Position).Magnitude > G.DonateRange then
		callbacks.notify(player, "Alert", "기부 단말기 가까이에서 기부할 수 있어요.")
		return
	end
	local amount = math.min(Robot.tierAmount(callbacks.incomeOf(player), tier), math.max(1, goal - progress))
	if not callbacks.takeMoney(player, amount) then
		callbacks.notify(player, "Alert", ("돈이 부족해요. (%s 필요)"):format(Config.formatMoney(amount)))
		return
	end
	progress += amount
	local entry = donors[player.UserId]
	if not entry then
		entry = { name = player.DisplayName, amount = 0 }
		donors[player.UserId] = entry
	end
	entry.amount += amount
	-- "Donate" 알림은 화면 가운데에 크게 뜬다 (JunkyardHud)
	local percent = math.min(100, math.floor(progress / goal * 100))
	callbacks.notify(player, "Donate", ("🔧 +%s 기부!\n거대 로봇 조립 %d%%"):format(Config.formatMoney(amount), percent))
	-- 다른 사람들에게도 누가 얼마 기부했는지 알린다 (기부한 사람은 위의 큰 연출을 본다)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			callbacks.notify(other, "Donate", ("🔧 %s님이 %s 기부!\n거대 로봇 조립 %d%%"):format(player.DisplayName, Config.formatMoney(amount), percent))
		end
	end
	if progress >= goal then
		complete(player)
	else
		render()
	end
end

-- 시험용 (Studio 훅에서만 부른다): 진행률을 정한다 (0~1). 1이면 바로 완성
function Robot.debugSetProgress(fraction: number)
	if status ~= "Building" then
		startRound()
	end
	progress = math.floor(goal * math.clamp(fraction, 0, 1))
	if progress >= goal then
		complete()
	else
		render()
	end
end

-- 시험용: 남은 가동·쉬는 시간을 줄인다
function Robot.debugSkip(seconds: number)
	if status == "Active" then
		boostUntil = now() + seconds
	elseif status == "Resting" then
		nextAt = now() + seconds
	end
	render()
end

local started = false
function Robot.start(callbacks: Callbacks)
	if started then
		return
	end
	started = true
	cb = callbacks
	local yard = workspace:FindFirstChild("Junkyard")
	local found = yard and yard:FindFirstChild("GiantRobot")
	model = if found and found:IsA("Model") then found else nil
	if not model then
		warn("[JunkyardGiantRobot] Workspace/Junkyard/GiantRobot 모델이 없어 거대 로봇을 끕니다")
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		lastDonate[player] = nil
	end)
	startRound()
	task.spawn(function()
		while true do
			task.wait(1)
			local t = now()
			if status == "Building" and progress == 0 then
				goal = computeGoal() -- 아직 아무도 기부하지 않았으면 들어온 사람에 맞춰 목표를 다시 잡는다
			elseif status == "Active" and t >= boostUntil then
				status = "Resting"
				nextAt = t + G.RestSeconds
				callbacks.notifyAll(("🤖 거대 로봇이 멈췄어요. %d분 뒤 다시 조립을 시작해요."):format(math.floor(G.RestSeconds / 60)))
				callbacks.onBoostChanged()
			elseif status == "Resting" and t >= nextAt then
				startRound()
				callbacks.notifyAll("🔧 거대 로봇 조립이 다시 시작됐어요! 단말기에서 부품을 기부하세요.")
			end
			render()
		end
	end)
end

return Robot
