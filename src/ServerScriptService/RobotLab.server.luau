--!strict
-- 연구소의 발견, 수리, 보상과 부품 상점 구매를 서버에서 처리한다.
local Players = game:GetService("Players")

local lab = workspace:WaitForChild("RobotLab")
local interactions = lab:WaitForChild("Interactions")
local arrival = lab:WaitForChild("Arrival") :: BasePart
local obbySpawn = workspace:WaitForChild("SpawnLocation") :: BasePart
local checkpoints = workspace:WaitForChild("Checkpoints")

local robots = {
	{ name = "삐삐", reward = 4 },
	{ name = "볼트", reward = 6 },
	{ name = "루미", reward = 8 },
}
local products = {
	Battery = { name = "고출력 배터리", price = 5 },
	Range = { name = "신호 증폭기", price = 3 },
}

type Session = {
	active: boolean,
	parts: number,
	repaired: number,
	found: boolean,
	items: { [string]: boolean },
	lastAction: number,
}
local sessions: { [Player]: Session } = {}

local function publish(player: Player, session: Session, message: string)
	player:SetAttribute("RobotLabParts", session.parts)
	player:SetAttribute("RobotLabRepaired", session.repaired)
	player:SetAttribute("RobotLabFound", session.found)
	player:SetAttribute("RobotLabBattery", session.items.Battery == true)
	player:SetAttribute("RobotLabRange", session.items.Range == true)
	player:SetAttribute("RobotLabMessage", message)
	player:SetAttribute("RobotLabActive", session.active)
end

local function findRobot(session: Session, index: number): string
	local robot = robots[index]
	if index <= session.repaired then
		return robot.name .. "는 이미 도감에 등록했어요."
	end
	if index ~= session.repaired + 1 then
		return "앞의 로봇을 수리하면 이 신호를 해독할 수 있어요."
	end
	if index == 3 and not session.items.Battery then
		return "루미를 데려오려면 상점의 고출력 배터리가 필요해요."
	end
	if session.found then
		return robot.name .. "를 연구실 수리대로 데려가세요."
	end
	session.found = true
	return robot.name .. "를 발견했어요! 연구실 수리대로 돌아가세요."
end

local function repairRobot(session: Session): string
	if not session.found then
		return "먼저 지도에서 고장 난 로봇을 찾으세요."
	end
	session.repaired += 1
	session.found = false
	local robot = robots[session.repaired]
	session.parts += robot.reward
	return ("%s 수리 완료! 부품 +%d"):format(robot.name, robot.reward)
end

local function buyItem(session: Session, item: string, name: string, price: number): string
	if session.items[item] then
		return name .. "는 이미 가지고 있어요."
	end
	if session.parts < price then
		return ("부품이 %d개 부족해요. 로봇을 수리하면 얻을 수 있어요."):format(price - session.parts)
	end
	session.parts -= price
	session.items[item] = true
	return ("%s 구매 완료! 부품 −%d"):format(name, price)
end

local function handlePrompt(player: Player, prompt: ProximityPrompt)
	local point = prompt.Parent
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not prompt.Enabled or not point or not point:IsA("BasePart") or not character
		or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - point.Position).Magnitude > prompt.MaxActivationDistance then
		return
	end

	local action = point.Name
	local session = sessions[player]
	if action == "Enter" or action == "EnterAtExit" then
		-- 기존 오비의 첫 리스폰 처리와 입장이 겹치지 않게 한다.
		if not player:FindFirstChild("leaderstats") or (session and session.active) then
			return
		end
		if not session then
			session = { active = false, parts = 0, repaired = 0, found = false, items = {}, lastAction = 0 }
			sessions[player] = session
			player.CharacterRemoving:Connect(function()
				session.active = false
				player:SetAttribute("RobotLabActive", false)
			end)
		end
		session.active = true
		session.lastAction = os.clock()
		character:PivotTo(arrival.CFrame)
		root.AssemblyLinearVelocity = Vector3.zero
		publish(player, session, "꼬마 로봇 연구소에 오신 것을 환영해요.")
		return
	end
	if not session or not session.active or os.clock() - session.lastAction < 0.25 then
		return
	end
	session.lastAction = os.clock()

	local message: string
	if action == "Return" then
		session.active = false
		local stats = player:FindFirstChild("leaderstats")
		local stage = stats and stats:FindFirstChild("Stage")
		local checkpoint = stage and stage:IsA("IntValue")
			and checkpoints:FindFirstChild(tostring(stage.Value))
		local destination = if checkpoint and checkpoint:IsA("BasePart") then checkpoint else obbySpawn
		character:PivotTo(destination.CFrame + Vector3.new(0, destination.Size.Y / 2 + 3, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		message = ""
	elseif action == "Repair" then
		message = repairRobot(session)
	elseif action == "Battery" or action == "Range" then
		local product = products[action]
		message = buyItem(session, action, product.name, product.price)
	else
		local index = point:GetAttribute("RobotIndex")
		if typeof(index) ~= "number" or not robots[index] then
			return
		end
		message = findRobot(session, index)
	end
	publish(player, session, message)
end

for _, point in interactions:GetChildren() do
	local prompt = point:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			handlePrompt(player, prompt)
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
