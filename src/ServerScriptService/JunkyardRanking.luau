--!strict
-- JunkyardRanking: 모든 서버를 합친 순위표 (서버 전용 모듈, Junkyard가 쓴다)
-- OrderedDataStore(숫자를 크기순으로 정렬해 주는 저장소)에 플레이어 점수를 올리고,
-- 상위 10명을 읽어 고물상 맵의 순위판(Workspace/Junkyard/Rankings)에 그린다.
--
-- 저장 형식 (한 번 정했으니 바꾸지 말 것)
--   "JunkyardRank_Rebirth_v1" : 키 "Player_<UserId>", 값 = 환생 단계 × 1e9 + min(누적 수입 ÷ 1000, 1e9 - 1)
--                               → 환생 단계가 같으면 많이 번 사람이 위
--   "JunkyardRank_Earned_v1"  : 키 "Player_<UserId>", 값 = 누적 수입(정수)
-- 진행 데이터(Junkyard_v1)와 따로 있어서, 순위 저장이 실패해도 진행 데이터에는 영향이 없다.
--
-- 안전 원칙
--   1. 점수는 늘어나기만 한다. UpdateAsync로 "저장된 값보다 클 때만" 쓴다.
--      (불러오기에 실패해 0부터 시작한 접속이 기록을 낮추지 않게)
--   2. 모든 저장소 호출은 pcall로 감싸고 재시도한다. 실패해도 게임은 계속된다.
--   3. Studio 테스트 플레이어(UserId 0 이하)는 올리지 않는다.
--   4. 바뀐 점수만 올린다 (저장소 요청 한도 절약).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("JunkyardConfig"))

local MAX_TRIES = 3
local REBIRTH_UNIT = 1e9
local EARNED_CAP = 1e15

export type Scores = { rebirth: number, earned: number }
export type Entry = { rank: number, userId: number, score: number }
export type Board = { id: string, storeName: string, title: string, format: (score: number) -> string }

local Ranking = {}
Ranking.Interval = 60 -- 점수 올리기·순위 읽기 간격(초)
Ranking.TopCount = 10

function Ranking.rebirthScore(rebirth: number, earned: number): number
	local level = math.clamp(math.floor(rebirth), 0, 1000)
	local tie = math.clamp(math.floor(earned / 1000), 0, REBIRTH_UNIT - 1)
	return level * REBIRTH_UNIT + tie
end

function Ranking.decodeRebirth(score: number): number
	return math.floor(score / REBIRTH_UNIT)
end

function Ranking.earnedScore(earned: number): number
	return math.clamp(math.floor(earned), 0, EARNED_CAP)
end

Ranking.Boards = {
	{
		id = "Rebirth",
		storeName = "JunkyardRank_Rebirth_v1",
		title = "⭐ 환생 순위",
		format = function(score: number): string
			return "환생 " .. Config.rebirthMark(Ranking.decodeRebirth(score))
		end,
	},
	{
		id = "Earned",
		storeName = "JunkyardRank_Earned_v1",
		title = "💰 누적 수입 순위",
		format = function(score: number): string
			return Config.formatMoney(score)
		end,
	},
} :: { Board }

local stores: { [string]: any } = {}
local function getStore(board: Board): any
	local store = stores[board.id]
	if store == nil then
		store = DataStoreService:GetOrderedDataStore(board.storeName)
		stores[board.id] = store
	end
	return store
end

-- 테스트용: 가짜 저장소를 넣는다 ({ Rebirth = 가짜, Earned = 가짜 })
function Ranking.setStoresForTest(fakeStores: { [string]: any })
	stores = fakeStores
end

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

-- 저장된 값보다 클 때만 쓴다. 성공(또는 이미 더 큼)이면 true
local function writeMax(board: Board, userId: number, score: number): boolean
	for attempt = 1, MAX_TRIES do
		local ok, err = pcall(function()
			getStore(board):UpdateAsync(keyFor(userId), function(old: any): any
				if typeof(old) == "number" and old >= score then
					return nil -- 그대로 둔다
				end
				return score
			end)
		end)
		if ok then
			return true
		end
		warn(("[JunkyardRanking] %s 점수 저장 %d 실패 (%d/%d): %s"):format(board.id, userId, attempt, MAX_TRIES, tostring(err)))
		if attempt < MAX_TRIES then
			task.wait(attempt)
		end
	end
	return false
end

local lastSent: { [number]: { [string]: number } } = {}

-- 한 플레이어의 점수를 올린다 (멈출 수 있음: 저장소 요청)
function Ranking.submit(userId: number, scores: Scores)
	if userId <= 0 then
		return
	end
	local values = {
		Rebirth = Ranking.rebirthScore(scores.rebirth, scores.earned),
		Earned = Ranking.earnedScore(scores.earned),
	}
	local sent = lastSent[userId]
	if not sent then
		sent = {}
		lastSent[userId] = sent
	end
	for _, board in Ranking.Boards do
		local value = values[board.id]
		if value and sent[board.id] ~= value and writeMax(board, userId, value) then
			sent[board.id] = value
		end
	end
end

-- 퇴장한 플레이어의 "마지막으로 보낸 값" 기록을 지운다
function Ranking.forget(userId: number)
	lastSent[userId] = nil
end

-- 상위 TopCount명. 실패하면 nil
function Ranking.fetchTop(board: Board): { Entry }?
	for attempt = 1, MAX_TRIES do
		local ok, result = pcall(function()
			return getStore(board):GetSortedAsync(false, Ranking.TopCount):GetCurrentPage()
		end)
		if ok then
			local entries: { Entry } = {}
			for _, item in result do
				local userId = tonumber(string.match(tostring(item.key), "^Player_(%d+)$"))
				if userId and typeof(item.value) == "number" then
					table.insert(entries, { rank = #entries + 1, userId = userId, score = item.value })
				end
			end
			return entries
		end
		warn(("[JunkyardRanking] %s 순위 읽기 실패 (%d/%d): %s"):format(board.id, attempt, MAX_TRIES, tostring(result)))
		if attempt < MAX_TRIES then
			task.wait(attempt)
		end
	end
	return nil
end

-- UserId → 이름 (한 번 찾으면 기억한다. 실패하면 임시 이름)
local names: { [number]: string } = {}
function Ranking.nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" then
		names[userId] = name
		return name
	end
	return "플레이어 " .. tostring(userId)
end

-- 순위판 화면 ---------------------------------------------------------------------
local ROW_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(215, 225, 235), Color3.fromRGB(225, 160, 110) }

local function textLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, align: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(247, 251, 255)
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = align
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

-- 순위판 파트에 SurfaceGui를 만든다 (앞면 = 파트의 LookVector 쪽). 이미 있으면 그대로 쓴다
local function ensureGui(part: BasePart, board: Board): SurfaceGui
	local existing = part:FindFirstChild("RankGui")
	if existing and existing:IsA("SurfaceGui") then
		return existing
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RankGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(28, 33, 41)
	background.BorderSizePixel = 0
	background.Parent = gui

	local title = textLabel(background, "Title", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 64), 46, Enum.TextXAlignment.Center)
	title.Text = board.title
	title.TextColor3 = Color3.fromRGB(255, 215, 90)

	for rank = 1, Ranking.TopCount do
		local y = 92 + (rank - 1) * 40
		local nameLabel = textLabel(background, "Name" .. rank, UDim2.fromOffset(30, y), UDim2.new(0.62, -30, 0, 38), 30, Enum.TextXAlignment.Left)
		local scoreLabel = textLabel(background, "Score" .. rank, UDim2.new(0.62, 0, 0, y), UDim2.new(0.38, -30, 0, 38), 30, Enum.TextXAlignment.Right)
		local color = ROW_COLORS[rank]
		if color then
			nameLabel.TextColor3 = color
			scoreLabel.TextColor3 = color
		end
	end

	local status = textLabel(background, "Status", UDim2.new(0, 0, 1, -44), UDim2.new(1, 0, 0, 36), 22, Enum.TextXAlignment.Center)
	status.TextColor3 = Color3.fromRGB(150, 165, 180)
	status.Text = "순위를 불러오는 중..."
	return gui
end

-- 순위판 글씨를 바꾼다. entries가 nil이면 불러오기 실패 (지난 순위를 그대로 둔다)
function Ranking.render(part: BasePart, board: Board, entries: { Entry }?)
	local gui = ensureGui(part, board)
	local background = gui:FindFirstChild("Background") :: Frame
	local status = background:FindFirstChild("Status") :: TextLabel
	if not entries then
		status.Text = "순위를 잠시 불러오지 못했어요"
		return
	end
	local lines: { [number]: { name: string, score: string } } = {}
	for _, entry in entries do
		lines[entry.rank] = { name = ("%d. %s"):format(entry.rank, Ranking.nameOf(entry.userId)), score = board.format(entry.score) }
	end
	for rank = 1, Ranking.TopCount do
		local line = lines[rank]
		local nameLabel = background:FindFirstChild("Name" .. rank) :: TextLabel
		local scoreLabel = background:FindFirstChild("Score" .. rank) :: TextLabel
		nameLabel.Text = if line then line.name else ("%d. -"):format(rank)
		scoreLabel.Text = if line then line.score else ""
	end
	status.Text = "모든 서버 합산 · 1분마다 갱신"
end

-- 시작 ------------------------------------------------------------------------------
-- boardParts: { Rebirth = 파트, Earned = 파트 }, getScores: 지금 올릴 플레이어 점수 (불러오기 성공한 사람만)
-- 같은 서버 플레이어의 지금 점수를 저장소 순위에 섞는다.
-- 저장소의 정렬 결과는 몇 초~1분 늦게 바뀌므로, 이 서버에서 방금 환생한 사람도 바로 보이게 한다
local function mergeLive(board: Board, entries: { Entry }, live: { [Player]: Scores }): { Entry }
	local list: { Entry } = {}
	local byUser: { [number]: Entry } = {}
	for _, entry in entries do
		local copy = { rank = 0, userId = entry.userId, score = entry.score }
		byUser[entry.userId] = copy
		table.insert(list, copy)
	end
	for player, scores in live do
		local userId = player.UserId
		if userId > 0 then
			local value = if board.id == "Rebirth" then Ranking.rebirthScore(scores.rebirth, scores.earned) else Ranking.earnedScore(scores.earned)
			local found = byUser[userId]
			if found then
				found.score = math.max(found.score, value)
			else
				table.insert(list, { rank = 0, userId = userId, score = value })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	local top: { Entry } = {}
	for index = 1, math.min(#list, Ranking.TopCount) do
		list[index].rank = index
		table.insert(top, list[index])
	end
	return top
end

-- 마지막으로 그린 순위 (CCTV가 1위를 알아낼 때 쓴다)
local latest: { [string]: { Entry } } = {}
function Ranking.topUserId(boardId: string): number?
	local entries = latest[boardId]
	return if entries and entries[1] then entries[1].userId else nil
end

-- 환생처럼 순위가 크게 바뀌면 다음 갱신을 기다리지 않고 바로 다시 그린다
local refreshRequested = false
function Ranking.refreshSoon()
	refreshRequested = true
end

local started = false
function Ranking.start(boardParts: { [string]: BasePart }, getScores: () -> { [Player]: Scores })
	if started then
		return
	end
	started = true
	for _, board in Ranking.Boards do
		local part = boardParts[board.id]
		if part then
			ensureGui(part, board)
		end
	end
	task.spawn(function()
		while true do
			refreshRequested = false
			local live = getScores()
			for player, scores in live do
				Ranking.submit(player.UserId, scores)
			end
			for _, board in Ranking.Boards do
				local part = boardParts[board.id]
				if part then
					local entries = Ranking.fetchTop(board)
					local merged = if entries then mergeLive(board, entries, live) else nil
					if merged then
						latest[board.id] = merged
					end
					Ranking.render(part, board, merged)
				end
			end
			-- Interval초 기다리되, refreshSoon이 불리면 바로 다시 돈다
			local waited = 0
			while waited < Ranking.Interval and not refreshRequested do
				waited += task.wait(1)
			end
		end
	end)
end

return Ranking
