--!strict
-- 첫 연습 경기 화면. 클라이언트는 구매·투입 의사를 보내고 서버 결과를 표시한다.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
if not RunService:IsStudio() or game.PlaceId ~= 123176209315432 or workspace:GetAttribute("PrototypeProject") ~= "StationeryCharacterLab" then return end
local Config = require(RS:WaitForChild("Modules"):WaitForChild("StationeryBattleConfig"))
local View = require(RS.Modules.StationeryBattleView)
local remotes = RS:WaitForChild("StationeryBattleRemotes")
local action, state, message = remotes:WaitForChild("Action") :: RemoteEvent, remotes:WaitForChild("State") :: RemoteEvent, remotes:WaitForChild("Message") :: RemoteEvent
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "StationeryBattleGui", false, 20
gui.IgnoreGuiInset, gui.ScreenInsets = true, Enum.ScreenInsets.None
gui.Parent = player:WaitForChild("PlayerGui")
local snapshot: any = nil
local selected, lane, slot, botKind, skillMode = "Jjondeuk", 2, 1, "Balanced", false
local view = View.new()
local lastMatch = 0
local function active(): boolean return snapshot ~= nil and snapshot.phase ~= "Closed" end
local function send(kind: string, arg: any?, extra: any?)
	action:FireServer(kind, if snapshot then snapshot.id else nil, arg, extra)
end
local function round(p: Instance)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = p
end
local function label(name: string, size: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundColor3, t.BackgroundTransparency = name, size, Color3.fromRGB(34, 47, 63), 0.05
	t.TextColor3, t.Font, t.TextSize, t.TextWrapped = Color3.fromRGB(255, 245, 222), Enum.Font.GothamBold, 16, true
	t.Parent = gui; round(t); return t
end
local header = label("Header", UDim2.fromOffset(540, 70))
header.AnchorPoint, header.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 4)
header.Visible = false
local toast = label("Toast", UDim2.fromOffset(510, 30))
toast.AnchorPoint, toast.Position, toast.TextSize = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 80), 14
toast.Text, toast.Visible = "", false
local messageSerial = 0
local function notify(text: string)
	messageSerial += 1
	local serial = messageSerial
	toast.Text, toast.Visible = text, true
	task.delay(3.5, function() if messageSerial == serial then toast.Visible = false end end)
end
local function button(name: string, text: string, parent: Instance, callback: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Font, b.TextSize = name, text, Enum.Font.GothamBold, 14
	b.TextColor3, b.BackgroundColor3, b.AutoButtonColor = Color3.fromRGB(255, 249, 236), Color3.fromRGB(60, 91, 114), true
	b.Parent = parent; round(b); b.Activated:Connect(callback); return b
end
local launch = button("Launch", "연습 경기 시작", gui, function() send("Start", botKind) end)
launch.AnchorPoint, launch.Position, launch.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -90), UDim2.fromOffset(190, 46)
local bot = button("Bot", "연습 상대: 균형형", gui, function()
	botKind = if botKind == "Balanced" then "Attack" elseif botKind == "Attack" then "Defense" else "Balanced"
end)
bot.AnchorPoint, bot.Position, bot.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -144), UDim2.fromOffset(190, 38)
local panel = Instance.new("Frame")
panel.Name, panel.AnchorPoint, panel.Position = "Controls", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8)
panel.BackgroundColor3, panel.BackgroundTransparency, panel.Visible = Color3.fromRGB(31, 44, 57), 0.05, false
panel.Parent = gui; round(panel)
local buttons: { TextButton } = {}
local function control(name: string, text: string, callback: () -> ()): TextButton
	local b = button(name, text, panel, callback); table.insert(buttons, b); return b
end
local choose = control("Choose", "쫀득 선택", function() selected = if selected == "Jjondeuk" then "Cheolkeok" else "Jjondeuk"; skillMode = false end)
local buy = control("Buy", "병력 구매", function() send("Buy", selected) end)
local refund = control("Refund", "병력 환불", function() send("Refund", selected) end)
local selectSlot = control("Slot", "방어 슬롯 1", function() slot = slot % 4 + 1 end)
local tower = control("Tower", "포탑 250원", function() send("Buy", "Tower", slot) end)
local sellTower = control("SellTower", "포탑 환불", function() send("Refund", "Tower", slot) end)
local selectLane = control("Lane", "투입: 가운데", function() lane = lane % 3 + 1 end)
local deploy = control("Deploy", "선택 병력 투입", function() send("Deploy", selected, lane) end)
local wind = control("Wind", "종이바람 1회", function()
	if snapshot and snapshot.phase == "Battle" then skillMode = not skillMode; notify(if skillMode then "전장의 적 병력이 있는 곳을 누르세요 · 한 판 1회" else "종이바람 선택 취소") end
end)
local ready = control("Ready", "준비 완료", function() send(if snapshot and snapshot.phase == "Result" then "Restart" else "Ready") end)
local leave = control("Leave", "시험장으로", function() send("Leave") end)
local help = control("Help", "도움말", function()
	notify(if snapshot and snapshot.phase == "Prepare" then "무료 쫀득·철컥 각 1명! 병력 구매 또는 슬롯을 골라 포탑을 설치하세요" else "종류와 위·중앙·아래 구역 선택 → 투입. 종이바람은 적 위치를 눌러 사용해요")
end)
local highlights: { Part } = {}
for i = 1, 2 do
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = "PracticeSelection", true, false, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, Color3.fromRGB(255, 228, 114), 0.6
	p.Parent = view.folder; highlights[i] = p
end
local function marker(i: number, pos: Vector2, size: Vector3, enabled: boolean)
	local p = highlights[i]
	if not p or not p.Parent then
		p = Instance.new("Part"); p.Name = "PracticeSelection"; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
		p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 228, 114); p.Parent = view.folder; highlights[i] = p
	end
	p.Size, p.Position, p.Transparency = size, Config.Center + Vector3.new(pos.X, 0.06, pos.Y), if enabled then 0.5 else 1
end
state.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then return end
	if data.phase == "Closed" then snapshot = nil; view:clear(); skillMode = false; toast.Visible = false; return end
	if typeof(data.id) ~= "number" or data.id < lastMatch then return end
	local previous = if snapshot then snapshot.phase else nil
	if data.id ~= lastMatch then
		view:clear(); selected, lane, slot, skillMode = "Jjondeuk", 2, 1, false
		notify("같은 1,000원으로 병력을 구매하거나 방어 슬롯에 포탑을 설치하세요")
	elseif previous ~= data.phase and data.phase == "Battle" then
		notify("무료 병력 출발! 종류·구역을 골라 추가 병력을 투입하세요")
	end
	lastMatch, snapshot = data.id, data
	view:update(data)
end)
message.OnClientEvent:Connect(notify)
UIS.InputBegan:Connect(function(input, processed)
	if processed or not active() or not skillMode or snapshot.phase ~= "Battle" then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	if math.abs(ray.Direction.Y) < 0.001 then return end
	local t = (Config.Center.Y - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then return end
	local point = ray.Origin + ray.Direction * t - Config.Center
	send("Skill", Vector2.new(point.X, point.Z)); skillMode = false
end)
local function enabled(b: TextButton, yes: boolean)
	b.Active, b.AutoButtonColor = yes, yes
	b.BackgroundColor3 = if yes then Color3.fromRGB(60, 91, 114) else Color3.fromRGB(66, 71, 79)
	b.TextTransparency = if yes then 0 else 0.45
end
RunService:BindToRenderStep("StationeryBattleCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local on = active()
	local old = player.PlayerGui:FindFirstChild("CharacterLabGui")
	if old and old:IsA("ScreenGui") then old.Enabled = not on end
	launch.Visible, bot.Visible, header.Visible, panel.Visible = not on, not on, on, on
	bot.Text = "연습 상대: " .. Config.Bots[botKind].Name
	if not on then return end
	local touch = player.PlayerGui:FindFirstChild("TouchGui")
	if touch and touch:IsA("ScreenGui") then touch.Enabled = false end
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 52
	local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
	local compact = camera.ViewportSize.Y < 500
	local headerHeight = if compact then 48 else 70
	local panelHeight = if snapshot.phase == "Prepare" then 106 else 56
	local usableTop, usableBottom = headerHeight + 14, camera.ViewportSize.Y - panelHeight - 18
	local usableHeight = math.max(60, usableBottom - usableTop)
	local zoom = math.max(1, 1.45 / aspect, camera.ViewportSize.Y * 0.6 / usableHeight)
	local pose = CFrame.lookAt(Config.Center + Vector3.new(0, 86 * zoom, 58 * zoom), Config.Center + Vector3.new(0, 0, -2))
	local shift = (camera.ViewportSize.Y * 0.5 - (usableTop + usableBottom) * 0.5) / camera.ViewportSize.Y * 2 * 104 * zoom * math.tan(math.rad(26))
	camera.CFrame = pose * CFrame.new(0, shift, 0)
	view:render(dt)
	local s, team = snapshot, snapshot.teams[1]
	local preparing, fighting = s.phase == "Prepare", s.phase == "Battle"
	local remaining = math.ceil(math.max(0, if preparing then Config.PrepareSeconds - s.time else Config.BattleSeconds - s.battleTime))
	local phase = if preparing then "준비" elseif fighting then "동시 공방" else (if s.winner == 1 then "승리!" elseif s.winner == 2 then "봇 승리" else "무승부")
	header.Text = ("%s · %s%s\n내 필통 %d / 600    봇 필통 %d / 600\n남은 돈 %d · 대기 쫀득 %d / 철컥 %d · 무료 각 1명"):format(phase, Config.Bots[s.botKind].Name, if s.phase == "Result" then " · " .. s.reason else " · " .. remaining .. "초", s.headquarters[1], s.headquarters[2], team.money, team.reserve.Jjondeuk, team.reserve.Cheolkeok)
	choose.Text = Config.Units[selected].Name .. " 선택됨"
	buy.Text = "구매 " .. Config.Units[selected].Price .. "원"
	selectSlot.Text = "방어 슬롯 " .. slot .. (if team.slots[slot] then " ●" else " ○")
	selectLane.Text = "투입: " .. ({ "위쪽", "가운데", "아래쪽" })[lane]
	wind.Text = if skillMode then "적 위치 선택 중" elseif team.skill then "종이바람 1회" else "종이바람 사용함"
	ready.Text = if s.phase == "Result" then "다시 경기" else "준비 완료"
	enabled(choose, preparing or fighting); enabled(buy, preparing); enabled(refund, preparing); enabled(selectSlot, preparing); enabled(tower, preparing); enabled(sellTower, preparing)
	enabled(selectLane, fighting); enabled(deploy, fighting and team.reserve[selected] > 0); enabled(wind, fighting and team.skill); enabled(ready, not fighting)
	marker(1, Config.Slots[slot], Vector3.new(4.6, 0.06, 4.6), preparing)
	marker(2, Vector2.new(-Config.SpawnX, Config.Lanes[lane]), Vector3.new(6.6, 0.06, 7.6), fighting)
	local w = math.min(960, camera.ViewportSize.X - 24)
	panel.Size = UDim2.fromOffset(w, panelHeight)
	for _, b in buttons do b.Visible = false end
	local shown = if preparing then { choose, buy, refund, selectSlot, tower, sellTower, ready, leave, help } elseif fighting then { choose, selectLane, deploy, wind, leave, help } else { ready, leave, help }
	local columns = math.min(6, #shown)
	for i, b in shown do
		b.Visible = true
		local col, row = (i - 1) % columns, math.floor((i - 1) / columns)
		b.Position = UDim2.fromOffset(6 + col * ((w - 12) / columns), 5 + row * 49)
		b.Size, b.TextSize = UDim2.fromOffset((w - 12) / columns - 5, 44), if w < 800 then 12 else 14
	end
	header.Size = UDim2.fromOffset(math.min(540, w), headerHeight)
	header.TextSize = if compact then 12 elseif w < 800 then 13 else 16
	toast.Position = UDim2.new(0.5, 0, 0, headerHeight + 10)
	toast.Size = UDim2.fromOffset(math.min(620, w), 30)
end)
