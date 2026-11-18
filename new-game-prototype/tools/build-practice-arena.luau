--!strict
-- 별도 연결 전장. 기존 캐릭터 시험장·원본 모델은 유지한다.
assert(game.PlaceId == 123176209315432 and workspace:GetAttribute("PrototypeProject") == "StationeryCharacterLab")
assert(not game:GetService("RunService"):IsRunning(), "편집 모드에서 실행하세요")
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("StationeryPracticeArena", "문방구 연습 전장 만들기")
assert(recording or history:IsRecordingInProgress())
if not workspace:FindFirstChild("StationeryArena") then
	local arena = Instance.new("Model")
	arena.Name = "StationeryArena"
	local function part(name: string, size: Vector3, pos: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color = name, size, Vector3.new(120, 0, 0) + pos, color
		p.Anchored, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = arena
		return p
	end
	part("Notebook", Vector3.new(100, 1, 68), Vector3.new(0, 0.5, 0), Color3.fromRGB(247, 238, 218))
	for z = -28, 28, 4 do part("Rule", Vector3.new(96, 0.015, 0.06), Vector3.new(0, 1.012, z), Color3.fromRGB(187, 205, 212)) end
	part("Margin", Vector3.new(0.12, 0.02, 64), Vector3.new(-43, 1.02, 0), Color3.fromRGB(223, 156, 149))
	part("CenterLine", Vector3.new(0.15, 0.02, 64), Vector3.new(0, 1.02, 0), Color3.fromRGB(180, 170, 147))
	for side = 1, 2 do
		local sign = if side == 1 then -1 else 1
		local color = if side == 1 then Color3.fromRGB(110, 181, 203) else Color3.fromRGB(226, 139, 137)
		for lane, z in { -16, 0, 16 } do
			part("Deploy" .. side .. "_" .. lane, Vector3.new(6, 0.03, 7), Vector3.new(sign * 30, 1.03, z), color)
		end
		for i, pos in { Vector2.new(29, -9), Vector2.new(34, -18), Vector2.new(29, 9), Vector2.new(34, 18) } do
			part("Slot" .. side .. "_" .. i, Vector3.new(4, 0.04, 4), Vector3.new(sign * pos.X, 1.04, pos.Y), color:Lerp(Color3.new(1, 1, 1), 0.4))
		end
	end
	for _, z in { -34, 34 } do part("Binding", Vector3.new(100, 0.7, 0.8), Vector3.new(0, 0.7, z), Color3.fromRGB(51, 65, 79)) end
	arena.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	arena.Parent = workspace
end
local rs = game.ReplicatedStorage
local remotes = rs:FindFirstChild("StationeryBattleRemotes")
if not remotes then remotes = Instance.new("Folder"); remotes.Name = "StationeryBattleRemotes"; remotes.Parent = rs end
for _, name in { "Action", "State", "Message" } do
	if not remotes:FindFirstChild(name) then local r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotes end
end
if recording then history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end
return "문방구 연결 전장과 리모트 준비 완료"
