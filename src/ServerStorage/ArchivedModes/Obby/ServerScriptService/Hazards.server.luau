--!strict
-- Hazards: 태그(CollectionService)가 붙은 장애물을 동작시킨다. (서버에서만)
--   KillPart   : 닿으면 사망 (레이저)
--   Spinner    : Model 안의 HingeConstraint로 막대(Bar)를 회전. 속성 SpeedDeg(초당 각도)
--   Mover      : Model 안의 PrismaticConstraint로 발판(Platform)을 좌우 왕복.
--                속성 Range(이동 거리), Speed(초당 스터드), StartSign(1 또는 -1), Pause(끝에서 멈춤 초)
--   TimedDoor  : 파트가 열렸다 닫혔다 한다. 속성 Period(열림/닫힘 각각 초), Offset(시간 어긋남)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local function numAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

-- 서버가 물리를 직접 계산하게 해서 모든 플레이어에게 같은 위치로 보이게 한다
local function serverOwns(part: BasePart)
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
end

-- KillPart -------------------------------------------------------------
local function killIfCharacter(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character or not Players:GetPlayerFromCharacter(character) then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function setupKillPart(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Touched:Connect(killIfCharacter)
	end
end

-- Spinner --------------------------------------------------------------
local function setupSpinner(inst: Instance)
	local hinge = inst:FindFirstChildWhichIsA("HingeConstraint", true)
	local bar = inst:FindFirstChild("Bar")
	if not hinge or not bar or not bar:IsA("BasePart") then
		warn("[Hazards] Spinner 구성이 잘못됨:", inst:GetFullName())
		return
	end
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = 1e9
	hinge.MotorMaxAcceleration = 1e9
	hinge.AngularVelocity = math.rad(numAttr(inst, "SpeedDeg", 40))
	serverOwns(bar)
end

-- Mover ----------------------------------------------------------------
local function setupMover(inst: Instance)
	local prism = inst:FindFirstChildWhichIsA("PrismaticConstraint", true)
	local platform = inst:FindFirstChild("Platform")
	if not prism or not platform or not platform:IsA("BasePart") then
		warn("[Hazards] Mover 구성이 잘못됨:", inst:GetFullName())
		return
	end
	local range = numAttr(inst, "Range", 6)
	local pause = numAttr(inst, "Pause", 1)
	local sign = numAttr(inst, "StartSign", 1)
	prism.ActuatorType = Enum.ActuatorType.Servo
	prism.Speed = numAttr(inst, "Speed", 4)
	prism.ServoMaxForce = 1e8
	prism.TargetPosition = range * sign
	serverOwns(platform)
	task.spawn(function()
		while inst.Parent do
			task.wait(0.1)
			if math.abs(prism.CurrentPosition - prism.TargetPosition) < 0.1 then
				task.wait(pause)
				sign = -sign
				prism.TargetPosition = range * sign
			end
		end
	end)
end

-- 태그 연결 -------------------------------------------------------------
local function bindTag(tag: string, setup: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(setup, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
end

bindTag("KillPart", setupKillPart)
bindTag("Spinner", setupSpinner)
bindTag("Mover", setupMover)

-- TimedDoor: 모든 문을 하나의 시계로 돌린다 (서버 시간 기준이라 문끼리 박자가 맞음)
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		for _, door in CollectionService:GetTagged("TimedDoor") do
			if door:IsA("BasePart") then
				local period = numAttr(door, "Period", 3)
				local offset = numAttr(door, "Offset", 0)
				local open = math.floor((now + offset) / period) % 2 == 0
				door.CanCollide = not open
				door.Transparency = if open then 0.85 else 0
			end
		end
		task.wait(0.1)
	end
end)
