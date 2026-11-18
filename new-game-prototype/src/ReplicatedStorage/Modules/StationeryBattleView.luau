--!strict
-- 서버 스냅샷의 외형만 그린다. 표시 크기·반동으로 전투 판정을 바꾸지 않는다.
local Config = require(script.Parent.StationeryBattleConfig)
local View = {}
View.__index = View
local palette = { Color3.fromRGB(66, 159, 190), Color3.fromRGB(222, 100, 109) }
local function part(model: Model, name: string, size: Vector3, pose: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, pose, color
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end
function View.new(): any
	local self: any = setmetatable({}, View)
	self.folder = Instance.new("Folder"); self.folder.Name = "StationeryBattleLocal"; self.folder.Parent = workspace
	self.actors, self.trails, self.winds = {}, {}, {}
	self.gui = Instance.new("ScreenGui")
	self.gui.Name, self.gui.ResetOnSpawn, self.gui.IgnoreGuiInset = "StationeryBattleHealth", false, true
	self.gui.ScreenInsets, self.gui.DisplayOrder = Enum.ScreenInsets.None, 10
	self.gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	self.sound = Instance.new("Sound")
	self.sound.Name, self.sound.SoundId, self.sound.Volume = "PracticeStapler", "rbxassetid://9116541944", 0.08
	self.sound.Parent = game:GetService("SoundService")
	self.lastSound = 0
	return self
end
function View:clear()
	self.folder:ClearAllChildren() -- 이 표시 모듈이 만든 로컬 복제본만 정리한다.
	self.gui:ClearAllChildren()
	self.sound:Stop()
	table.clear(self.actors); table.clear(self.trails); table.clear(self.winds)
end
function View:create(e: any): any
	local model: Model
	if e.kind == "Jjondeuk" or e.kind == "Cheolkeok" then
		model = game.ReplicatedStorage.CharacterLabAssets[e.kind]:Clone()
		model:ScaleTo(model:GetScale() * 0.65)
	else
		model = Instance.new("Model")
		if e.kind == "HQ" then
			part(model, "PencilCase", Vector3.new(6, 2.4, 8), CFrame.new(0, 1.2, 0), palette[e.side])
			part(model, "Lid", Vector3.new(6.3, 0.5, 8.3), CFrame.new(0, 2.65, 0), palette[e.side]:Lerp(Color3.new(1, 1, 1), 0.3))
			part(model, "Zip", Vector3.new(6.4, 0.14, 0.3), CFrame.new(0, 2.4, -4.2), Color3.fromRGB(242, 215, 119))
		else
			part(model, "Foot", Vector3.new(3, 0.5, 3), CFrame.new(0, 0.25, 0), palette[e.side])
			local pencil = part(model, "Pencil", Vector3.new(3.5, 1.4, 1.4), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(243, 192, 73))
			pencil.Shape = Enum.PartType.Cylinder
			part(model, "Nib", Vector3.new(0.9, 0.8, 0.9), CFrame.new(0, 4.2, 0), Color3.fromRGB(53, 62, 71))
		end
	end
	model.Name = tostring(e.id)
	if e.kind == "HQ" or e.kind == "Tower" then model.WorldPivot = CFrame.new() end
	local pivot = model:GetPivot()
	model.WorldPivot = pivot
	local _, bounds = model:GetBoundingBox()
	local pieces = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
			table.insert(pieces, { p = p, pose = pivot:ToObjectSpace(p.CFrame), size = p.Size, upper = p:GetAttribute("LabUpper") == true })
		end
	end
	model.Parent = self.folder
	local marker = part(model, "StatusAnchor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), palette[e.side]); marker.Transparency = 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(if e.kind == "HQ" then 100 else 48, 18)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundColor3, label.BackgroundTransparency = palette[e.side]:Lerp(Color3.new(), 0.5), 0.15
	label.TextColor3, label.TextSize, label.Font = Color3.new(1, 1, 1), 11, Enum.Font.GothamBold
	label.BorderSizePixel = 0
	label.Parent = self.gui
	local fill = Instance.new("Frame")
	fill.BorderSizePixel, fill.BackgroundColor3 = 0, palette[e.side]
	fill.AnchorPoint, fill.Position, fill.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 3)
	fill.Parent = label
	local a = { model = model, pieces = pieces, pos = e.pos, scale = 1, baseScale = model:GetScale(), height = bounds.Y, marker = marker, label = label, fill = fill, e = e }
	self.actors[e.id] = a
	return a
end
function View:update(snapshot: any)
	-- 승패 확정 뒤의 스냅샷에 남은 비행·둔화 효과는 결과 화면에서 정리한다.
	if snapshot.phase == "Result" then snapshot.projectiles = {}; snapshot.effects = {} end
	local alive = {}
	for _, e in snapshot.entities do
		alive[e.id] = true
		local a = self.actors[e.id] or self:create(e)
		if a.e.shotAt ~= e.shotAt and e.kind == "Cheolkeok" and os.clock() - self.lastSound > 0.15 then self.sound:Play(); self.lastSound = os.clock() end
		a.e = e
	end
	for id, a in self.actors do if not alive[id] then a.label:Destroy(); a.model:Destroy(); self.actors[id] = nil end end
	self.snapshot, self.received = snapshot, os.clock()
end
function View:render(dt: number)
	local s = self.snapshot
	if not s then return end
	local now = s.battleTime + (if s.phase == "Battle" then math.min(os.clock() - self.received, 0.15) else 0)
	for _, a in self.actors do
		local e = a.e
		a.pos = a.pos:Lerp(e.pos, math.min(1, dt * 15))
		local moving = (a.pos - e.pos).Magnitude > 0.02
		local age = if s.phase == "Result" then 100 else now - e.shotAt
		local recoil = if age >= 0 and age < 0.8 then math.sin(math.min(age / 0.15, 1) * math.pi / 2) * math.exp(-age * 5) else 0
		local hitAge = if s.phase == "Result" then 100 else now - e.hitAt
		local shake = if hitAge >= 0 and hitAge < 0.4 then math.sin(hitAge * 60) * math.exp(-hitAge * 10) * 0.1 else 0
		local p = Config.Center + Vector3.new(a.pos.X, 0, a.pos.Y)
		if e.kind == "Jjondeuk" then
			a.scale += (0.48 + e.hp / e.maxHp * 0.52 - a.scale) * math.min(1, dt * 10)
			a.model:ScaleTo(a.baseScale * a.scale)
			a.model:PivotTo(CFrame.new(p + Vector3.new(shake, a.height * a.scale * 0.5, 0)) * CFrame.Angles(0, -e.direction * math.pi / 2, 0))
		elseif e.kind == "Cheolkeok" then
			local step = if moving then math.sin(now * 13 + e.id) else 0
			local root = CFrame.new(p + Vector3.new(0, a.height * 0.5 + math.abs(step) * 0.05, 0)) * CFrame.Angles(0, -e.direction * math.pi / 2, 0) * CFrame.new(0, 0, recoil * 0.45)
			for _, piece in a.pieces do
				local pose = piece.pose
				if piece.upper then pose *= CFrame.Angles(-recoil * 0.14, 0, 0) end
				if piece.p.Name == "EyeWhite" then piece.p.Size = piece.size * (1 + recoil * 0.25) end
				piece.p.CFrame = root * CFrame.Angles(-recoil * 0.15, 0, step * 0.025) * pose
			end
		else
			for _, piece in a.pieces do piece.p.CFrame = CFrame.new(p) * piece.pose end
		end
		a.marker.Position = p + Vector3.new(0, (if e.kind == "Jjondeuk" then a.height * a.scale else a.height) + 0.8, 0)
		a.label.Text = (if e.kind == "HQ" then (if e.side == 1 then "내 필통 " else "봇 필통 ") else "") .. tostring(e.hp) .. (if e.slowed then " ❄" else "")
		local compact = workspace.CurrentCamera.ViewportSize.Y < 500 and e.kind ~= "HQ"
		if compact then a.label.Text = "" end
		a.label.Size = UDim2.fromOffset(if e.kind == "HQ" then 100 elseif compact then 24 else 44, if compact then 5 else 18)
		a.fill.Size = UDim2.new(e.hp / e.maxHp, 0, 0, if compact then 5 else 3)
		a.fill.BackgroundColor3 = if e.slowed then Color3.fromRGB(157, 235, 233) else palette[e.side]
		local screen, visible = workspace.CurrentCamera:WorldToViewportPoint(a.marker.Position)
		a.label.Position, a.label.Visible = UDim2.fromOffset(screen.X, screen.Y), visible
	end
	for i, p in s.projectiles do
		local trail = self.trails[i]
		if not trail then
			local m = Instance.new("Model"); m.Name = "Staple"; m.Parent = self.folder
			trail = { model = m, parts = {} }
			for j = 1, 3 do table.insert(trail.parts, part(m, "Iron", if j == 1 then Vector3.new(0.55, 0.1, 0.1) else Vector3.new(0.1, 0.35, 0.1), CFrame.new(), Color3.fromRGB(82, 97, 108))) end
			self.trails[i] = trail
		end
		local alpha = math.clamp((now - p.fired) / (p.arrives - p.fired), 0, 1)
		local point = p.origin:Lerp(p.destination, alpha)
		local pose = CFrame.new(Config.Center + Vector3.new(point.X, 2 + math.sin(alpha * math.pi), point.Y))
		for j, piece in trail.parts do piece.CFrame = pose * CFrame.new(if j == 1 then 0 else (if j == 2 then -0.23 else 0.23), if j == 1 then 0.15 else 0, 0) end
	end
	for i, trail in self.trails do if i > #s.projectiles then trail.model:Destroy(); self.trails[i] = nil end end
	for i, effect in s.effects do
		local ring = self.winds[i]
		if not ring then
			local m = Instance.new("Model"); m.Name = "PaperWind"; m.Parent = self.folder
			ring = { model = m, parts = {} }
			for j = 1, 16 do table.insert(ring.parts, part(m, "Paper", Vector3.new(0.6, 0.1, 0.4), CFrame.new(), Color3.fromRGB(147, 224, 227))) end
			self.winds[i] = ring
		end
		for j, piece in ring.parts do
			local angle = j * math.pi / 8 + now * 2
			piece.Position = Config.Center + Vector3.new(effect.pos.X + math.cos(angle) * Config.Skill.Radius, 0.3, effect.pos.Y + math.sin(angle) * Config.Skill.Radius)
		end
	end
	for i, ring in self.winds do if i > #s.effects then ring.model:Destroy(); self.winds[i] = nil end end
end
return View
