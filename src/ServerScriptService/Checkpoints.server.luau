--!strict
-- Checkpoints: 체크포인트를 밟으면 Stage를 올린다. (판정은 서버에서만)
-- Workspace/Checkpoints 안의 파트 이름이 곧 스테이지 번호다. 예: "3"
local Players = game:GetService("Players")

local checkpointsFolder = workspace:WaitForChild("Checkpoints")

local function getStageValue(player: Player): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local stage = leaderstats and leaderstats:FindFirstChild("Stage")
	if stage and stage:IsA("IntValue") then
		return stage
	end
	return nil
end

local function onCheckpointTouched(stageNumber: number, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	-- 죽은 캐릭터(쓰러지는 중)는 무시
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stageValue = getStageValue(player)
	if not stageValue then
		return
	end
	-- 바로 다음 스테이지만 인정: 뒤로 가지 않고, 건너뛰기(순간이동 핵 등)도 막는다
	if stageNumber == stageValue.Value + 1 then
		stageValue.Value = stageNumber
	end
end

local function setupCheckpoint(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local stageNumber = tonumber(part.Name)
	if not stageNumber then
		warn("[Checkpoints] 이름이 숫자가 아닌 체크포인트:", part:GetFullName())
		return
	end
	part.Touched:Connect(function(hit: BasePart)
		onCheckpointTouched(stageNumber, hit)
	end)
end

for _, part in checkpointsFolder:GetChildren() do
	setupCheckpoint(part)
end
checkpointsFolder.ChildAdded:Connect(setupCheckpoint)
