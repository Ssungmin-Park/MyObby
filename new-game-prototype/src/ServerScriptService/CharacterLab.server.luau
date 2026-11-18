--!strict
-- 이 스크립트는 저장 기능 없이 Studio 캐릭터 시험 상태만 관리한다.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not RunService:IsStudio() or workspace:GetAttribute("PrototypeProject") ~= "StationeryCharacterLab" then
	return
end

local lab = workspace:WaitForChild("CharacterLab")
local action = ReplicatedStorage:WaitForChild("CharacterLabRemotes"):WaitForChild("Action") :: RemoteEvent
local lastAction: { [Player]: number } = {}
local nextHit = 0
local nextShot = 0
local deadUntil = 0
local cycle = 0 -- 초기화·모드 변경 전에 발사한 철심의 늦은 피해를 취소한다.
lab:SetAttribute("Linked", false)
lab:SetAttribute("FlightSeconds", 0.65)
local shotRemote = ReplicatedStorage.CharacterLabRemotes:WaitForChild("Shot") :: RemoteEvent

local function time(): number
	return workspace:GetServerTimeNow()
end

local function reset()
	cycle += 1
	lab:SetAttribute("Health", lab:GetAttribute("MaxHealth"))
	lab:SetAttribute("ShotCount", 0)
	lab:SetAttribute("LastShotAt", 0)
	lab:SetAttribute("LastHitAt", 0)
	lab:SetAttribute("Cycle", (lab:GetAttribute("Cycle") :: number) + 1)
	deadUntil = 0
end

local function hit()
	local health = lab:GetAttribute("Health") :: number
	if health <= 0 then
		return
	end
	local damage = math.clamp(lab:GetAttribute("HitDamage") :: number, 1, 100)
	local remaining = math.max(0, health - damage)
	lab:SetAttribute("Health", remaining)
	lab:SetAttribute("LastHitAt", time())
	if remaining == 0 then
		deadUntil = time() + 1.5
	end
end

local function fire()
	if time() < nextShot then
		return
	end
	local linked = lab:GetAttribute("Linked") == true
	local health = lab:GetAttribute("Health") :: number
	if linked and health <= 0 then
		return
	end
	nextShot = time() + 0.7
	local firedAt = time()
	lab:SetAttribute("LastShotAt", firedAt)
	lab:SetAttribute("ShotId", (lab:GetAttribute("ShotId") :: number) + 1)
	lab:SetAttribute("ShotCount", (lab:GetAttribute("ShotCount") :: number) + 1)
	local fraction = health / math.max(lab:GetAttribute("MaxHealth") :: number, 1)
	local visualScale = 0.48 + fraction * 0.52
	local flight = if linked then math.clamp(lab:GetAttribute("FlightSeconds") :: number, 0.2, 2) else 0.45
	local origin = if linked then Vector3.new(6.7, 4.2, 1) else Vector3.new(9, 4, -1)
	local target = if linked then Vector3.new(-9 + 2 * visualScale, 1.6 + 5.8 * visualScale * 0.65, 1) else Vector3.new(9, 2.5, -10)
	shotRemote:FireAllClients({ id = lab:GetAttribute("ShotId"), origin = origin, target = target, firedAt = firedAt, hitAt = firedAt + flight, linked = linked })
	if linked then
		local shotCycle = cycle
		task.delay(flight, function()
			if cycle == shotCycle and lab:GetAttribute("Linked") == true then
				hit()
			end
		end)
	end
end

action.OnServerEvent:Connect(function(player: Player, kind: unknown)
	if typeof(kind) ~= "string" or os.clock() - (lastAction[player] or 0) < 0.15 then
		return
	end
	lastAction[player] = os.clock()
	if kind == "Hit" then
		hit()
	elseif kind == "Fire" then
		fire()
	elseif kind == "Reset" then
		reset()
	elseif kind == "Auto" then
		cycle += 1
		lab:SetAttribute("Linked", false)
		lab:SetAttribute("Auto", lab:GetAttribute("Auto") ~= true)
		nextHit = time() + 0.5
		nextShot = time() + 0.6
	elseif kind == "Crowd" then
		lab:SetAttribute("Crowd", lab:GetAttribute("Crowd") ~= true)
	elseif kind == "Linked" then
		cycle += 1
		lab:SetAttribute("Linked", lab:GetAttribute("Linked") ~= true)
		lab:SetAttribute("Auto", false)
		nextShot = time() + 0.5
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAction[player] = nil
end)

task.spawn(function()
	while true do
		local now = time()
		if lab:GetAttribute("Auto") == true or lab:GetAttribute("Linked") == true then
			if deadUntil > 0 and now >= deadUntil then
				reset()
			end
			if lab:GetAttribute("Auto") == true and now >= nextHit then
				nextHit = now + 0.9
				hit()
			end
			if now >= nextShot then
				fire()
				nextShot = now + 1.5
			end
		end
		task.wait(0.1)
	end
end)
