--!strict
-- Respawn: KillZone(떨어지면 닿는 바닥)에 닿으면 죽이고,
-- 다시 태어날 때 마지막으로 밟은 체크포인트 위로 옮긴다.
local Players = game:GetService("Players")

local checkpointsFolder = workspace:WaitForChild("Checkpoints")
local killZone = workspace:WaitForChild("KillZone") :: BasePart
local startPad = workspace:WaitForChild("SpawnLocation") :: BasePart

Players.RespawnTime = 1 -- 죽은 뒤 1초 만에 다시 태어남

-- 스테이지 번호 -> 리스폰할 파트 (0 또는 못 찾으면 시작 발판)
local function getRespawnPart(stage: number): BasePart
	local cp = checkpointsFolder:FindFirstChild(tostring(stage))
	if cp and cp:IsA("BasePart") then
		return cp
	end
	return startPad
end

killZone.Touched:Connect(function(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character or not Players:GetPlayerFromCharacter(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end)

local function onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	task.wait() -- 기본 스폰 위치 배치가 끝난 뒤에 옮긴다
	local leaderstats = player:WaitForChild("leaderstats", 5)
	local stageValue = leaderstats and leaderstats:FindFirstChild("Stage")
	local stage = if stageValue and stageValue:IsA("IntValue") then stageValue.Value else 0
	local part = getRespawnPart(stage)
	character:PivotTo(part.CFrame + Vector3.new(0, part.Size.Y / 2 + 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
