--!strict
-- 로봇 고물상 맵 생성 (2026-11-17, Claude Code)
-- Studio Edit에서 ChangeHistoryService 기록 안에서 실행한다. Workspace/Junkyard 모델을 만들고,
-- 오비 시작 발판에 "로봇 고물상" 입구를 붙인다.
-- 배치: 가운데(X 290~510, Z 0~200, 바닥 윗면 Y 40.5)에 동→서 컨베이어 벨트(Z 100),
--       북쪽 기지 3개(Z 23~57)와 남쪽 기지 3개(Z 143~177). 기지 입구는 벨트 쪽.
local function buildJunkyard(): Model
	assert(not workspace:FindFirstChild("Junkyard"), "이미 Junkyard가 있음")
	local model = Instance.new("Model")
	model.Name = "Junkyard"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

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

	local function billboard(parent: BasePart, name: string, text: string, height: number, range: number): TextLabel
		local display = Instance.new("BillboardGui")
		display.Name = name
		display.Size = UDim2.fromOffset(200, 34)
		display.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
		display.MaxDistance = range
		display.Parent = parent
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(36, 43, 52)
		label.BackgroundTransparency = 0.15
		label.TextColor3 = Color3.fromRGB(247, 251, 255)
		label.Text = text
		label.TextSize = 16
		label.Font = Enum.Font.GothamBold
		label.Parent = display
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		return label
	end

	local function prompt(parent: BasePart, objectText: string, actionText: string, hold: number, range: number): ProximityPrompt
		local object = Instance.new("ProximityPrompt")
		object.ObjectText = objectText
		object.ActionText = actionText
		object.HoldDuration = hold
		object.MaxActivationDistance = range
		object.RequiresLineOfSight = false
		object.Parent = parent
		return object
	end

	local ground = Color3.fromRGB(118, 112, 104)
	local wall = Color3.fromRGB(78, 87, 99)
	local dark = Color3.fromRGB(45, 48, 54)

	part(model, "Floor", Vector3.new(400, 40, 100), Vector3.new(220, 1, 200), ground)

	-- 컨베이어 벨트 ------------------------------------------------------------
	local belt = part(model, "Belt", Vector3.new(400, 41, 100), Vector3.new(170, 1, 8), dark)
	belt:SetAttribute("StartPos", Vector3.new(315, 41.5, 100)) -- 벨트 윗면의 시작점
	belt:SetAttribute("EndPos", Vector3.new(485, 41.5, 100))
	for _, z in { 95.7, 104.3 } do
		part(model, "BeltRail", Vector3.new(400, 41.75, z), Vector3.new(170, 1.5, 0.6), Color3.fromRGB(200, 170, 60))
	end
	local chute = part(model, "BeltStart", Vector3.new(311, 43.5, 100), Vector3.new(6, 6, 10), wall)
	billboard(chute, "Sign", "고물 투입구", 4.5, 120)
	part(model, "BeltEnd", Vector3.new(489, 43.5, 100), Vector3.new(6, 6, 10), wall)

	-- 기지 6개 ------------------------------------------------------------------
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = model
	for index = 1, 6 do
		local column = (index - 1) % 3
		local north = index <= 3
		local bx = 340 + column * 60
		local bz = if north then 40 else 160
		local front = if north then 1 else -1 -- 벨트(Z 100) 쪽 방향

		local base = Instance.new("Model")
		base.Name = "Base" .. index
		base:SetAttribute("Index", index)
		base:SetAttribute("Front", front)
		base:SetAttribute("Center", Vector3.new(bx, 40.5, bz))
		base:SetAttribute("OwnerUserId", 0)
		base:SetAttribute("OwnerName", "")
		base:SetAttribute("Vault", 0)
		base:SetAttribute("LockedUntil", 0)
		base.Parent = bases

		part(base, "Floor", Vector3.new(bx, 40.7, bz), Vector3.new(44, 0.4, 34), Color3.fromRGB(150, 156, 162))
		-- 벽 높이 12: 기본 점프(약 7.2)로 넘을 수 없어 입구로만 드나든다
		local back = part(base, "Wall", Vector3.new(bx, 46.7, bz - front * 17), Vector3.new(44, 12, 1), wall)
		for _, dx in { -22, 22 } do
			part(base, "Wall", Vector3.new(bx + dx, 46.7, bz), Vector3.new(1, 12, 34), wall)
		end
		for _, dx in { -14, 14 } do
			part(base, "Wall", Vector3.new(bx + dx, 46.7, bz + front * 17), Vector3.new(16, 12, 1), wall)
		end
		billboard(back, "Sign", "빈 기지", 8, 150)

		-- 방어막: 기지 전체를 덮는 상자. 평소엔 투명, 잠기면 반투명 ForceField로 멀리서도 보인다
		local shield = part(base, "Shield", Vector3.new(bx, 46.7, bz), Vector3.new(44.6, 12.2, 34.6), Color3.fromRGB(90, 200, 255))
		shield.Transparency = 1
		shield.CanCollide = false
		shield.CanQuery = false
		shield.CanTouch = false
		shield.Material = Enum.Material.ForceField

		local pads = Instance.new("Folder")
		pads.Name = "Pads"
		pads.Parent = base
		local padIndex = 0
		for _, row in { -9, -1 } do
			for _, dx in { -16, -8, 0, 8, 16 } do
				padIndex += 1
				local pad = part(pads, "Pad" .. padIndex, Vector3.new(bx + dx, 41.1, bz + front * row), Vector3.new(5, 0.4, 5), Color3.fromRGB(70, 78, 88))
				pad:SetAttribute("PadIndex", padIndex)
				local robotPrompt = prompt(pad, "로봇", "훔치기", 1.5, 8)
				robotPrompt.Name = "RobotPrompt"
				robotPrompt.Enabled = false
			end
		end
		-- 받침대 11~14: "받침대 추가" 업그레이드로 열리는 자리 (입구 쪽 셋째 줄)
		for _, dx in { -12, -4, 4, 12 } do
			padIndex += 1
			local pad = part(pads, "Pad" .. padIndex, Vector3.new(bx + dx, 41.1, bz + front * 5), Vector3.new(5, 0.4, 5), Color3.fromRGB(70, 78, 88))
			pad:SetAttribute("PadIndex", padIndex)
			local robotPrompt = prompt(pad, "로봇", "훔치기", 1.5, 8)
			robotPrompt.Name = "RobotPrompt"
			robotPrompt.Enabled = false
		end

		local vault = part(base, "Vault", Vector3.new(bx - 16, 41.5, bz + front * 10), Vector3.new(4, 1.2, 4), Color3.fromRGB(240, 200, 80))
		billboard(vault, "Amount", "금고 0", 3, 60)
		local lock = part(base, "LockButton", Vector3.new(bx + 16, 42, bz + front * 10), Vector3.new(2, 2, 2), Color3.fromRGB(220, 80, 80))
		local lockPrompt = prompt(lock, "기지 방어막", "잠그기", 0, 7)
		lockPrompt.Name = "LockPrompt"

		local spawn = part(base, "Spawn", Vector3.new(bx, 41, bz + front * 9), Vector3.one, dark)
		spawn.CFrame = CFrame.lookAt(spawn.Position, spawn.Position + Vector3.new(0, 0, front))
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CanTouch = false
	end

	-- 오비로 가는 입구 ------------------------------------------------------------
	local toObby = part(model, "ObbyPortal", Vector3.new(298, 42.5, 100), Vector3.new(2, 4, 4), Color3.fromRGB(126, 225, 195))
	toObby.CanCollide = false
	billboard(toObby, "Sign", "실험실 탈출 코스", 3.5, 60)
	local obbyPrompt = prompt(toObby, "실험실 탈출 코스", "이동", 0, 7)
	obbyPrompt.Name = "PortalPrompt"

	-- 오비 시작 발판의 고물상 입구 (연구소 입구 반대쪽)
	local spawnPad = workspace:FindFirstChild("SpawnLocation")
	assert(spawnPad and spawnPad:IsA("BasePart"), "SpawnLocation 없음")
	local back = part(model, "JunkyardPortal",
		spawnPad.Position + Vector3.new(-(spawnPad.Size.X / 2 - 1.3), spawnPad.Size.Y / 2 + 1.4, -spawnPad.Size.Z / 4),
		Vector3.new(1.2, 2.8, 2.1), Color3.fromRGB(240, 200, 80))
	back.CanCollide = false
	billboard(back, "Sign", "로봇 고물상", 2.3, 35)
	local backPrompt = prompt(back, "로봇 고물상", "이동", 0, 7)
	backPrompt.Name = "PortalPrompt"

	return model
end
