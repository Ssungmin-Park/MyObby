--!strict
-- build-expansion.luau: 기지 확장(구역 사기)용 지도 준비 (Studio Edit 모드에서 한 번 실행, 다시 실행해도 안전)
-- 1) 기지마다 확장 받침대 Pad15~Pad32를 Pad1을 복제해 만든다 (단계마다 6개, 처음에는 숨김)
-- 2) 벽에 역할(WallRole = Back/Side/Front)을, 바닥·방어막·뒷벽·옆벽에 원래 위치·크기(OrigPosition/OrigSize)를 적는다
--    서버(Junkyard)가 주인의 확장 단계에 맞춰 뒷벽을 뒤로 밀고 옆벽·바닥·방어막을 늘린다
-- 숫자는 JunkyardConfig.Expansion(Depth 7, PadsPerLevel 6, 3단계)과 같아야 한다.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DEPTH = 7
local LEVELS = 3
local PADS_PER_LEVEL = 6
local PAD_X = { -17.5, -10.5, -3.5, 3.5, 10.5, 17.5 }
local FIRST_NEW_PAD = 15

local recording = ChangeHistoryService:TryBeginRecording("기지 확장 지도 준비")
local made = 0
for _, base in workspace.Junkyard.Bases:GetChildren() do
	if not base:IsA("Model") then
		continue
	end
	local floor = base:FindFirstChild("Floor") :: BasePart
	local padsFolder = base:FindFirstChild("Pads") :: Folder
	local front = base:GetAttribute("Front") :: number
	local center = floor.Position
	-- 원래 위치·크기 기록 (이미 있으면 그대로 둔다 → 다시 실행해도 원래 값 유지)
	local function remember(part: BasePart)
		if part:GetAttribute("OrigPosition") == nil then
			part:SetAttribute("OrigPosition", part.Position)
			part:SetAttribute("OrigSize", part.Size)
		end
	end
	remember(floor)
	remember(base:FindFirstChild("Shield") :: BasePart)
	for _, child in base:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Wall" then
			local role = if child.Size.X > 30 then "Back" elseif child.Size.Z > 30 then "Side" else "Front"
			child:SetAttribute("WallRole", role)
			if role ~= "Front" then
				remember(child)
			end
		end
	end
	-- 원래 받침대는 확장 0단계
	local pad1: BasePart? = nil
	for _, pad in padsFolder:GetChildren() do
		if pad:IsA("BasePart") then
			if pad:GetAttribute("ExpandLevel") == nil then
				pad:SetAttribute("ExpandLevel", 0)
			end
			if pad:GetAttribute("PadIndex") == 1 then
				pad1 = pad
			end
		end
	end
	assert(pad1, base.Name .. ": Pad1 없음")
	-- 확장 받침대
	local back = center.Z - front * 17 -- 원래 뒷벽 Z
	local index = FIRST_NEW_PAD
	for level = 1, LEVELS do
		local rowZ = back - front * (DEPTH * level - DEPTH / 2)
		for _, dx in PAD_X do
			if not padsFolder:FindFirstChild("Pad" .. index) then
				local pad = (pad1 :: BasePart):Clone()
				pad.Name = "Pad" .. index
				pad:SetAttribute("PadIndex", index)
				pad:SetAttribute("ExpandLevel", level)
				pad.Position = Vector3.new(center.X + dx, (pad1 :: BasePart).Position.Y, rowZ)
				pad.Transparency = 1
				pad.CanCollide = false
				local prompt = pad:FindFirstChild("RobotPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = false
				end
				pad.Parent = padsFolder
				made += 1
			end
			index += 1
		end
	end
	assert(index - 1 == FIRST_NEW_PAD - 1 + LEVELS * PADS_PER_LEVEL)
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print(("[build-expansion] 새 받침대 %d개"):format(made))
