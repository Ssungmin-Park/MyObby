--!strict
-- Studio Edit에서 Script Source 설치와 같은 실행 취소 기록 안에서 호출한다.
-- 반환한 모델을 Workspace에 붙이면 연구소 지형과 상호작용 장치가 설치된다.
local function buildRobotLab(): Model
	local model = Instance.new("Model")
	model.Name = "RobotLab"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local interactions = Instance.new("Folder")
	interactions.Name = "Interactions"
	interactions.Parent = model

	local floor = Color3.fromRGB(133, 143, 152)
	local wall = Color3.fromRGB(78, 87, 99)
	local frame = Color3.fromRGB(36, 43, 52)
	local mint = Color3.fromRGB(126, 225, 195)
	local amber = Color3.fromRGB(244, 196, 117)

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

	local spawnPad = workspace:FindFirstChild("SpawnLocation")
	local checkpoints = workspace:FindFirstChild("Checkpoints")
	local exit = checkpoints and checkpoints:FindFirstChild("11")
	assert(spawnPad and spawnPad:IsA("BasePart") and exit and exit:IsA("BasePart"), "오비 시작 또는 EXIT 없음")
	local function portal(id: string, pad: BasePart)
		local position = pad.Position + Vector3.new(pad.Size.X / 2 - 1.3, pad.Size.Y / 2 + 1.4, -pad.Size.Z / 4)
		local gate = station(id, position, Vector3.new(1.2, 2.8, 2.1), mint, "꼬마 로봇 연구소", "입장")
		gate.CanCollide = false
		sign(gate, "꼬마 로봇 연구소", 2.3, 35)
	end
	portal("Enter", spawnPad)
	portal("EnterAtExit", exit)

	local arrival = part(model, "Arrival", Vector3.new(150, 43.5, -5), Vector3.one, frame)
	arrival.CFrame = CFrame.lookAt(arrival.Position, arrival.Position + Vector3.zAxis)
	arrival.Transparency = 1
	arrival.CanCollide = false
	arrival.CanTouch = false
	arrival.CanQuery = false

	part(model, "LabFloor", Vector3.new(150, 40, 9), Vector3.new(60, 1, 38), floor)
	part(model, "WarehouseFloor", Vector3.new(150, 40, 44), Vector3.new(60, 1, 32), Color3.fromRGB(120, 131, 139))
	part(model, "GreenhouseFloor", Vector3.new(150, 40, 76), Vector3.new(60, 1, 32), Color3.fromRGB(121, 142, 131))
	for _, x in {120, 180} do
		part(model, "SideWall", Vector3.new(x, 43.5, 41), Vector3.new(1, 6, 102), wall)
	end
	for _, z in {-10, 92} do
		part(model, "EndWall", Vector3.new(150, 43.5, z), Vector3.new(60, 6, 1), wall)
	end
	for _, zone in {{ z = 28, title = "부품 창고" }, { z = 60, title = "실험 온실" }} do
		for _, x in {132, 168} do
			part(model, "Divider", Vector3.new(x, 44.5, zone.z), Vector3.new(24, 8, 1), wall)
		end
		local beam = part(model, "DoorFrame", Vector3.new(150, 47.5, zone.z), Vector3.new(12, 2, 1.5), frame)
		sign(beam, zone.title, 1.4, 50)
	end

	local repair = station("Repair", Vector3.new(137, 42, 9), Vector3.new(7, 3, 3), mint, "연구실 수리대", "로봇 수리")
	sign(repair, "로봇 수리대", 3, 28)
	local returnGate = station("Return", Vector3.new(126, 42, -4), Vector3.new(2, 3, 2), wall, "실험실 탈출 코스", "오비로 돌아가기")
	sign(returnGate, "오비 출구", 3, 28)

	local shop = part(model, "ShopCounter", Vector3.new(171, 41.5, 12), Vector3.new(3, 2, 21), frame)
	sign(shop, "부품 상점", 4.5, 42)
	station("Battery", Vector3.new(169, 42, 7), Vector3.new(2, 3, 3), amber, "고출력 배터리 · 루미 구조", "부품 5개로 구매")
	station("Range", Vector3.new(169, 42, 19), Vector3.new(2, 3, 3), mint, "신호 증폭기 · 탐지 범위 증가", "부품 3개로 구매")

	for _, position in {Vector3.new(156, 43, 38), Vector3.new(166, 43, 46), Vector3.new(137, 43, 49)} do
		part(model, "Crate", position, Vector3.new(7, 5, 7), Color3.fromRGB(111, 104, 91))
	end
	for _, position in {Vector3.new(134, 42, 70), Vector3.new(150, 42, 77), Vector3.new(165, 42, 82)} do
		part(model, "Planter", position, Vector3.new(8, 3, 5), Color3.fromRGB(76, 102, 87))
	end

	local robots = {
		{ name = "삐삐", position = Vector3.new(150, 41.7, 6), color = mint },
		{ name = "볼트", position = Vector3.new(166, 41.7, 52), color = amber },
		{ name = "루미", position = Vector3.new(165, 41.7, 87), color = Color3.fromRGB(163, 181, 248) },
	}
	for i, robot in robots do
		local body = station("Robot" .. i, robot.position, Vector3.new(2.2, 2, 1.7), robot.color, "고장 난 " .. robot.name, "로봇 발견")
		body:SetAttribute("RobotIndex", i)
		local head = part(model, "RobotHead" .. i, robot.position + Vector3.new(0, 1.7, 0), Vector3.new(2.4, 1.5, 1.9), robot.color)
		head.CanCollide = false
		for _, x in {-0.5, 0.5} do
			local eye = part(model, "RobotEye", head.Position + Vector3.new(x, 0, -0.98), Vector3.new(0.3, 0.3, 0.08), frame)
			eye.CanCollide = false
		end
	end
	return model
end
