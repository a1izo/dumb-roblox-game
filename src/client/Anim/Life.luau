--!strict
-- Life: what a body does when nobody animates it (2026-11-07, the user: "make all the cutscenes and animations 100x
-- better ... so that movements dont look stiff"). A last pass over a posed R6 body, after every clip and the planted
-- feet (PoseController, for a character with the attribute DGLife: how much, 0 to 1; ShotPlayer gives it to every
-- actor of a cutscene), adding what a held key never has:
--   breath      a slow breath through the chest, the head kept level against it, the arms easing out a little
--   weight      the weight drifting from foot to foot, very slowly, the soles left where they stand
--   attention   the head glancing about in small quick moves between holds, as eyes would
--   lag         the head and the arms trailing the body: on a turn the head lags then catches up past and settles;
--               on a stop the arms swing on and the chest tips forward a little, and settle; on a start they trail
-- Each joint the clip itself is moving fast keeps its own motion (the pass fades out on it), so a strike or a reach
-- lands exactly where it was acted; the breath stays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClipPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("ClipPlayer"))

local Life = {}

Life.ATTRIBUTE = "DGLife"

-- Degrees, seconds, and how quickly each lag settles.
local BREATH_PERIOD = { 3.4, 4.6 } -- seconds a breath takes (each body its own)
local BREATH_CHEST = 0.7 -- the chest's lean back on the breath in
local BREATH_ARMS = 0.9 -- the arms' ease outward on it
local SWAY_ROLL = 0.75 -- the weight's drift, side to side
local SWAY_YAW = 0.6
local SWAY_PERIOD = 9.0
local GLANCE_YAW = 2.6 -- the head's glances
local GLANCE_PITCH = 1.3
local GLANCE_EVERY = { 1.4, 3.2 } -- seconds between them
local GLANCE_MOVE = 0.22 -- seconds a glance takes
local HEAD_LAG = 0.085 -- seconds of the body's turn the head trails by (degrees of lag = turn speed x this)
local HEAD_LAG_MAX = 14
local ARM_LAG = 0.05 -- degrees of swing per stud/s^2 of the body's change of speed
local ARM_LAG_MAX = 9
local CHEST_LAG = 0.022 -- degrees the chest pitches per stud/s^2 (forward as the body stops, back as it sets off)
local CHEST_LAG_MAX = 3.5
local SPRING_W = 11 -- rad/s: the lags' springs
local SPRING_Z = 0.55 -- their damping (a soft settle)
local BUSY_FROM = 25 -- degrees a second a joint of the clip moves at before the pass gives way on it
local BUSY_SPAN = 70

type Spring = { x: number, v: number }

type State = {
	seed: number,
	breath: number,
	sway: number,
	glanceAt: number,
	glanceFrom: Vector2,
	glanceTo: Vector2,
	glanceStart: number,
	yaw: number?,
	pos: Vector3?,
	vel: Vector3?,
	head: Spring,
	chest: Spring,
	armR: Spring,
	armL: Spring,
	prev: { [string]: CFrame },
}

local states: { [any]: State } = setmetatable({}, { __mode = "k" }) :: any

local function hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local made = 0 -- bodies given a life so far (each its own seed, so no two breathe in step)

local function stateOf(rig: any): State
	local state = states[rig]
	if state then
		return state
	end
	made += 1
	local seed = hash(rig.character.Name .. "#" .. made)
	local random = Random.new(seed)
	state = {
		seed = seed,
		breath = random:NextNumber(BREATH_PERIOD[1], BREATH_PERIOD[2]),
		sway = SWAY_PERIOD * random:NextNumber(0.8, 1.25),
		glanceAt = os.clock() + random:NextNumber(0.3, 1.5),
		glanceFrom = Vector2.zero,
		glanceTo = Vector2.zero,
		glanceStart = -math.huge,
		head = { x = 0, v = 0 },
		chest = { x = 0, v = 0 },
		armR = { x = 0, v = 0 },
		armL = { x = 0, v = 0 },
		prev = {},
	}
	states[rig] = state
	return state
end

local function spring(s: Spring, target: number, dt: number)
	-- (a few small steps: stable at any frame time)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		local a = SPRING_W * SPRING_W * (target - s.x) - 2 * SPRING_Z * SPRING_W * s.v
		s.v += a * h
		s.x += s.v * h
	end
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- How freely the pass may move a joint this frame: 1 while the clip holds it still, 0 while it moves it fast.
local function free(state: State, joint: string, transform: CFrame, dt: number): number
	local before = state.prev[joint]
	state.prev[joint] = transform
	if not before or dt <= 0 then
		return 1
	end
	local _, angle = (before:Inverse() * transform):ToAxisAngle()
	local speed = math.deg(math.abs(angle)) / dt
	return 1 - smooth((speed - BUSY_FROM) / BUSY_SPAN)
end

-- A rotation in the joint's parent frame (degrees about the parent's x, y and z), laid on the joint's pose.
local function add(rig: any, joint: string, x: number, y: number, z: number)
	local motor = rig.motors[joint]
	local basis = rig.basis[joint]
	if not motor or not basis or (x == 0 and y == 0 and z == 0) then
		return
	end
	local delta = CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
	motor.Transform = ClipPlayer.transform(basis, delta, nil, rig.inverse[joint]) * motor.Transform
end

-- The body's turn about the vertical (radians) and where it is, from its root part.
local function bodyOf(rig: any): (number?, Vector3?)
	local root = rig.character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, nil
	end
	local look = root.CFrame.LookVector
	return math.atan2(-look.X, -look.Z), root.Position
end

function Life.apply(rig: any, amount: number, dt: number, now: number)
	if dt <= 0 then
		return
	end
	local state = stateOf(rig)
	local k = math.clamp(amount, 0, 1)
	-- (a body lying down, fallen or dead, neither breathes nor glances: the pass fades as the torso tips over)
	local torso = rig.character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		k *= 1 - smooth((0.65 - torso.CFrame.UpVector.Y) / 0.35)
	end
	if k <= 0 then
		return
	end
	local motors = rig.motors
	-- How much of each joint is the pass's to move (the clip's own fast motion keeps it).
	local neckFree = if motors.neck then free(state, "neck", motors.neck.Transform, dt) else 0
	local rFree = if motors.rShoulder then free(state, "rShoulder", motors.rShoulder.Transform, dt) else 0
	local lFree = if motors.lShoulder then free(state, "lShoulder", motors.lShoulder.Transform, dt) else 0
	local phase = (state.seed % 1000) / 1000 * math.pi * 2

	-- The breath: in over two fifths of it, out over the rest (a breath is not a sine).
	local u = ((now / state.breath) + phase) % 1
	local breath = if u < 0.4 then smooth(u / 0.4) else 1 - smooth((u - 0.4) / 0.6)
	breath = breath * 2 - 1
	-- The weight's slow drift (two slow waves, never quite repeating).
	local s1 = math.sin(now * math.pi * 2 / state.sway + phase) * 0.7
		+ math.sin(now * math.pi * 2 / (state.sway * 0.61) + phase * 1.7) * 0.3
	local s2 = math.sin(now * math.pi * 2 / (state.sway * 1.37) + phase * 0.6)

	-- Glances: a new small target every so often, reached in a quick eased move, then held.
	if now >= state.glanceAt then
		local random = Random.new(state.seed + math.floor(now * 10))
		state.glanceFrom = state.glanceTo
		state.glanceTo = Vector2.new(random:NextNumber(-1, 1) * GLANCE_YAW, random:NextNumber(-1, 0.6) * GLANCE_PITCH)
		state.glanceStart = now
		state.glanceAt = now + random:NextNumber(GLANCE_EVERY[1], GLANCE_EVERY[2])
	end
	local glance = state.glanceFrom:Lerp(state.glanceTo, smooth((now - state.glanceStart) / GLANCE_MOVE))

	-- The lags, from how the body itself turns and changes speed.
	local yaw, pos = bodyOf(rig)
	local turnRate, forwardAccel = 0, 0
	if yaw and pos then
		if state.yaw then
			local d = (yaw - state.yaw + math.pi) % (2 * math.pi) - math.pi
			turnRate = math.deg(d) / dt
		end
		if state.pos then
			local vel = (pos - state.pos) / dt
			if state.vel then
				local accel = (vel - state.vel) / dt
				local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
				forwardAccel = accel:Dot(forward)
			end
			state.vel = vel
		end
		state.yaw, state.pos = yaw, pos
	end
	spring(state.head, math.clamp(-turnRate * HEAD_LAG, -HEAD_LAG_MAX, HEAD_LAG_MAX), dt)
	local swing = math.clamp(-forwardAccel * ARM_LAG, -ARM_LAG_MAX, ARM_LAG_MAX)
	spring(state.armR, swing, dt)
	spring(state.armL, swing, dt)
	-- (the chest: carried on by its weight as the body stops, left behind as it sets off; root pitch + leans back)
	spring(state.chest, math.clamp(forwardAccel * CHEST_LAG, -CHEST_LAG_MAX, CHEST_LAG_MAX), dt)

	-- Laid on the pose: the chest and the weight on the body, the legs turned back against the weight's roll so the
	-- soles stay put, the head kept level against the breath plus its glances and lag, the arms' breath and lag.
	add(rig, "root", (BREATH_CHEST * breath + state.chest.x) * k, SWAY_YAW * s2 * k, SWAY_ROLL * s1 * k)
	add(rig, "rHip", 0, 0, -SWAY_ROLL * s1 * k)
	add(rig, "lHip", 0, 0, -SWAY_ROLL * s1 * k)
	add(
		rig,
		"neck",
		(-BREATH_CHEST * 0.8 * breath + glance.Y * neckFree) * k,
		(-SWAY_YAW * s2 + glance.X * neckFree + state.head.x) * k,
		-SWAY_ROLL * 0.5 * s1 * k
	)
	add(rig, "rShoulder", state.armR.x * rFree * k, 0, BREATH_ARMS * (breath + 1) * 0.5 * k)
	add(rig, "lShoulder", state.armL.x * lFree * k, 0, -BREATH_ARMS * (breath + 1) * 0.5 * k)
end

-- Forgets a body's life (it left, or its scene ended).
function Life.forget(rig: any)
	states[rig] = nil
end

return Life
