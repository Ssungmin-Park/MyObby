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

local function time(): number
	return workspace:GetServerTimeNow()
end

local function reset()
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
	nextShot = time() + 0.7
	lab:SetAttribute("LastShotAt", time())
	lab:SetAttribute("ShotId", (lab:GetAttribute("ShotId") :: number) + 1)
	lab:SetAttribute("ShotCount", (lab:GetAttribute("ShotCount") :: number) + 1)
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
		lab:SetAttribute("Auto", lab:GetAttribute("Auto") ~= true)
		nextHit = time() + 0.5
		nextShot = time() + 0.6
	elseif kind == "Crowd" then
		lab:SetAttribute("Crowd", lab:GetAttribute("Crowd") ~= true)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAction[player] = nil
end)

task.spawn(function()
	while true do
		local now = time()
		if lab:GetAttribute("Auto") == true then
			if deadUntil > 0 and now >= deadUntil then
				reset()
			end
			if now >= nextHit then
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
