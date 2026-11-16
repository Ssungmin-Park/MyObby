--!strict
-- 로봇 작업장 확장 (2026-11-16, Claude Code)
-- build-robot-lab.luau로 만든 RobotLab 모델에 이어서 적용한다. Studio Edit에서 ChangeHistoryService 기록 안에서 호출한다.
--   1. v1 고정 로봇 3대와 상점 장치 2개를 backup 폴더로 옮긴다 (삭제하지 않음)
--   2. 폐품 처리장 구역을 남쪽에 붙인다
--   3. 부품 더미·로봇 신호가 나타날 SpawnPoints를 만든다
--   4. 수거함, 업그레이드 4종, 구역 열기 2종 장치를 만든다
local function expandRobotLab(model: Model, backup: Instance)
	local interactions = model:FindFirstChild("Interactions") :: Folder
	assert(interactions, "RobotLab/Interactions 없음")
	assert(not model:FindFirstChild("SpawnPoints"), "이미 확장됨")

	local wall = Color3.fromRGB(78, 87, 99)
	local frame = Color3.fromRGB(36, 43, 52)
	local mint = Color3.fromRGB(126, 225, 195)
	local amber = Color3.fromRGB(244, 196, 117)
	local rust = Color3.fromRGB(128, 104, 88)

	local function part(parent: Instance, name: string, position: Vector3, size: Vector3, color: Color3): Part
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.Position = position
		object.Color = color
		object.Anchored = true
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = parent
		return object
	end

	local function sign(parent: BasePart, text: string, height: number, range: number)
		local display = Instance.new("BillboardGui")
		display.Size = UDim2.fromOffset(185, 32)
		display.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		display.MaxDistance = range
		display.Parent = parent
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = frame
		label.TextColor3 = Color3.fromRGB(247, 251, 255)
		label.Text = text
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = display
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = label
	end

	local function station(id: string, position: Vector3, size: Vector3, color: Color3, item: string, action: string): Part
		local stand = part(interactions, id, position, size, color)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Interact"
		prompt.ObjectText = item
		prompt.ActionText = action
		prompt.MaxActivationDistance = 7
		prompt.Parent = stand
		return stand
	end

	-- 1. v1 장치 백업 -------------------------------------------------------
	for _, name in { "Battery", "Range", "Robot1", "Robot2", "Robot3" } do
		local object = interactions:FindFirstChild(name)
		if object then
			object.Parent = backup
		end
	end
	for _, object in model:GetChildren() do
		if string.match(object.Name, "^RobotHead") or object.Name == "RobotEye" then
			object.Parent = backup
		end
	end

	-- 2. 폐품 처리장 (z 92 ~ 126) ------------------------------------------
	for _, object in model:GetChildren() do
		if object.Name == "EndWall" and object:IsA("BasePart") and object.Position.Z > 50 then
			object.Position = Vector3.new(object.Position.X, object.Position.Y, 126)
		end
	end
	part(model, "ScrapyardFloor", Vector3.new(150, 40, 109), Vector3.new(60, 1, 34), Color3.fromRGB(112, 108, 100))
	for _, x in { 120, 180 } do
		part(model, "SideWall", Vector3.new(x, 43.5, 109), Vector3.new(1, 6, 34), wall)
	end
	for _, x in { 132, 168 } do
		part(model, "Divider", Vector3.new(x, 44.5, 92), Vector3.new(24, 8, 1), wall)
	end
	local beam = part(model, "DoorFrame", Vector3.new(150, 47.5, 92), Vector3.new(12, 2, 1.5), frame)
	sign(beam, "폐품 처리장", 1.4, 50)
	for _, heap in {
		{ Vector3.new(140, 42, 104), Vector3.new(6, 3, 6) },
		{ Vector3.new(163, 42.5, 117), Vector3.new(8, 4, 5) },
		{ Vector3.new(172, 42, 101), Vector3.new(5, 3, 4) },
	} do
		part(model, "ScrapHeap", heap[1], heap[2], rust)
	end

	-- 3. 스폰 지점 (보이지 않는 표식) --------------------------------------
	local spawnPoints = Instance.new("Folder")
	spawnPoints.Name = "SpawnPoints"
	spawnPoints.Parent = model
	local pointSets = {
		Lab = { Vector3.new(150, 41.7, 6) }, -- 튜토리얼 로봇 자리 (v1 삐삐 자리)
		Warehouse = {
			Vector3.new(128, 41.5, 33), Vector3.new(145, 41.5, 33), Vector3.new(172, 41.5, 33),
			Vector3.new(128, 41.5, 42), Vector3.new(147, 41.5, 44), Vector3.new(174, 41.5, 40),
			Vector3.new(128, 41.5, 55), Vector3.new(150, 41.5, 55), Vector3.new(160, 41.5, 56),
			Vector3.new(175, 41.5, 55),
		},
		Greenhouse = {
			Vector3.new(127, 41.5, 64), Vector3.new(145, 41.5, 65), Vector3.new(160, 41.5, 66),
			Vector3.new(175, 41.5, 66), Vector3.new(126, 41.5, 78), Vector3.new(142, 41.5, 84),
			Vector3.new(158, 41.5, 73), Vector3.new(175, 41.5, 75), Vector3.new(128, 41.5, 88),
			Vector3.new(150, 41.5, 88),
		},
		Scrapyard = {
			Vector3.new(127, 41.5, 97), Vector3.new(150, 41.5, 98), Vector3.new(162, 41.5, 97),
			Vector3.new(128, 41.5, 108), Vector3.new(150, 41.5, 110), Vector3.new(173, 41.5, 110),
			Vector3.new(126, 41.5, 121), Vector3.new(145, 41.5, 121), Vector3.new(152, 41.5, 117),
			Vector3.new(174, 41.5, 122),
		},
	}
	for zoneId, positions in pointSets do
		local folder = Instance.new("Folder")
		folder.Name = zoneId
		folder.Parent = spawnPoints
		for i, position in positions do
			local point = part(folder, "Point" .. i, position, Vector3.one, frame)
			point.Transparency = 1
			point.CanCollide = false
			point.CanTouch = false
			point.CanQuery = false
		end
	end

	-- 4. 장치 ---------------------------------------------------------------
	local deposit = station("Deposit", Vector3.new(160, 42, 0), Vector3.new(4, 3, 3), amber, "부품 수거함", "부품 넣기 · 보관함 받기")
	sign(deposit, "부품 수거함", 3, 28)

	local repair = interactions:FindFirstChild("Repair")
	local repairPrompt = repair and repair:FindFirstChildOfClass("ProximityPrompt")
	if repairPrompt then
		repairPrompt.ObjectText = "로봇 수리대"
		repairPrompt.ActionText = "로봇 맡기기"
	end

	local shop = model:FindFirstChild("ShopCounter")
	local shopSign = shop and shop:FindFirstChildOfClass("BillboardGui")
	local shopLabel = shopSign and shopSign:FindFirstChildOfClass("TextLabel")
	if shopLabel then
		shopLabel.Text = "작업장 업그레이드"
	end
	local upgrades = {
		{ id = "Upgrade_Bag", z = 4, name = "가방 확장" },
		{ id = "Upgrade_Detector", z = 10, name = "탐지기 강화" },
		{ id = "Upgrade_RepairSlots", z = 16, name = "수리대 추가" },
		{ id = "Upgrade_RepairSpeed", z = 22, name = "수리 속도" },
	}
	for _, entry in upgrades do
		local stand = station(entry.id, Vector3.new(169, 42, entry.z), Vector3.new(2, 3, 3), mint, entry.name, "업그레이드")
		-- 장치가 6스터드 간격이라 범위가 7이면 옆 장치의 안내가 대신 뜬다. 바로 앞에서만 뜨게 줄인다.
		(stand:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt).MaxActivationDistance = 4.5
	end

	local unlockGreenhouse = station("Unlock_Greenhouse", Vector3.new(141, 42, 57), Vector3.new(3, 3, 2), amber, "실험 온실", "구역 열기")
	sign(unlockGreenhouse, "온실 열기", 3, 30)
	local unlockScrapyard = station("Unlock_Scrapyard", Vector3.new(141, 42, 89), Vector3.new(3, 3, 2), amber, "폐품 처리장", "구역 열기")
	sign(unlockScrapyard, "처리장 열기", 3, 30)
end
