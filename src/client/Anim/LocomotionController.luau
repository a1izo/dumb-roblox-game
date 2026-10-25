-- Movement animation for every R6 character, worked out on each client from what everyone can see (how fast a
-- body moves and which way, whether it is on the ground, whether it sits or flies). The movement set is built
-- in art/scripts/locomotion.py; Roblox's default Animate script is removed (by the server, and here for this
-- player's own body), so these are the only movement animations.
--   standing   two idles, at ease in the lobby and guarded in a case (crossfaded), and now and then a fidget
--              from the mood's own pool, never the same twice running; the soles stay planted under whatever
--              the body does (the after-pass, Locomotion/Feet), and turning on the spot the feet step round
--   moving     a walk and a run for each way a body can go (forward, back, left, right), blended by the
--              direction it moves in its own frame and by its speed, on one shared phase that advances by
--              the distance covered (each leg sampled where its foot comes down with the others', so the
--              soles hold); the body leans into curves and tips into its first step, and stopping from a
--              run plays a stop on the foot that is down
--   in the air the take-off when it jumped, the hang at the top, the fall, and a long fall's wilder shape;
--              landing lays a light, normal or heavy landing over whatever comes next, by how hard it hit,
--              and never slows the body
--   seated     the seated idle; flying (a Deathsinger or a spectator) a hover that leans into a glide, a rise
--              and a dive by its velocity
-- A stroll (the server's "Stroll" attribute: an emote of the shop) puts its own clips in the place of the idle
-- and of the forward walk and run while it lasts, so moving does not end it. A body with a stance (the
-- "Stance" attribute) that stands still for a while settles into it (Settled fires), as an emote that moving
-- ends. Each time a stride plants a foot, Footfall fires (the snow's footprints use it). Nothing here depends
-- on a player's role.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Gait = require(Anim:WaitForChild("Gait"))
local Joints = require(Anim:WaitForChild("Joints"))
local Seating = require(Shared:WaitForChild("Seating"))
local Signal = require(Shared:WaitForChild("Signal"))

local PoseController = require(script.Parent.PoseController)
local Pose = require(script.Parent.Locomotion.Pose)
local Feet = require(script.Parent.Locomotion.Feet)
local Characters = require(script.Parent.Parent.Characters)
local ClientState = require(script.Parent.Parent.ClientState)

local LocomotionController = {}

-- Fired with (character) when a walking or running character's foot comes down on the ground.
LocomotionController.Footfall = Signal.new()

-- Fired with (character, clip) when a still body settles into its stance, and Unsettled when that ends.
LocomotionController.Settled = Signal.new()
LocomotionController.Unsettled = Signal.new()

-- Seconds of standing still before a body settles into its stance.
local STANCE_AFTER = 6
-- Seconds a stroll's own clips take to fade in, and out when it ends.
local STROLL_FADE = 0.4
-- Seconds a body takes to settle into its chair at the war table, or to get up out of it (Shared/Seating).
local SEAT_FADE = 0.45

-- Speeds (studs/s): below MOVE_FULL a body is still easing out of its idle; the walk is at its own speed at
-- the bottom of the band and the run takes over towards the top (both clips say their own stride).
local MOVE_FULL = 1.5
local RUN_FROM, RUN_FULL = 5, 13
-- Seconds the cycle (and the feet letting go of their marks) takes to come in when a body sets off: a humanoid is
-- at full speed a frame after it starts, and the speed alone would bring the whole stride in that one frame.
local MOVE_IN = 0.16

local GROUND_REACH = 0.6 -- studs below the soles a body still counts as on the ground
local NEAR = 80 -- studs from the camera within which a body is checked for the ground every frame
local FAR = 110 -- studs beyond which a body is posed every second frame
local LAND_AFTER = 0.08 -- seconds in the air before a landing can play
local LAND_IN = 0.06 -- seconds a landing's dip takes to come in
-- The direction weights (the eight cycles by which way the body moves) follow the velocity on a critically damped
-- spring this stiff (rad/s): a sudden change of direction starts the new side-step gently, never at its fastest
-- in the first frame, and settles in about a fifth of a second.
local DIR_OMEGA = 14

-- The mood of a standing body: in a case guarded, else at ease (crossfaded over MOOD_TIME seconds).
local MOOD_TIME = 1.5
local STANCES = { 0.05, 0.12 } -- how far the soles stand apart beyond the hips, at ease and guarded
local LOBBY_FIDGETS = { "idleLook", "idleWatch", "idleTie", "idleNeck", "idleSleeve", "idleHandsBack" }
local CASE_FIDGETS = { "idleLook", "idleWatch", "idleGlance", "idleArmsCross", "idleHand", "idleRoom" }
local FIDGET_EVERY = { 8, 20 }

local LEAN_MAX = 8 -- degrees a running body banks into a curve at most
local TURN_AFTER = 25 -- degrees the root may turn away from a standing body before it comes round
local CAMERA_TURN = 160 -- degrees a second: a standing turn this fast is the camera's (shift lock), not a step

local DIRECTIONS = Gait.DIRECTIONS
local CYCLE = {
	walk = { F = "walk", B = "walkBack", L = "walkLeft", R = "walkRight" },
	run = { F = "run", B = "runBack", L = "runLeft", R = "runRight" },
}
local REQUIRED = {
	"idle",
	"idleGuarded",
	"walk",
	"walkBack",
	"walkLeft",
	"walkRight",
	"run",
	"runBack",
	"runLeft",
	"runRight",
	"jump",
	"jumpApex",
	"fall",
	"fallLong",
	"landLight",
	"landNormal",
	"landHeavy",
	"startStep",
	"stopRight",
	"stopLeft",
	"sit",
	"flyHover",
	"flyGlide",
	"flyRise",
	"flyDive",
}

type Layer = { clip: ClipPlayer.Prepared, time: number, weight: number, lift: number, ending: boolean }

type State = {
	random: Random,
	phase: number,
	idleTime: number,
	legScale: number?,
	blendSpeed: number,
	moveIn: number, -- 0..1: how far the cycle has come in (eased: `moving`)
	lastSpeed: number,
	lastPosition: Vector3?,
	stride: number,
	directions: { [string]: number },
	directionSpeeds: { [string]: number }, -- the direction weights' own speeds, on their spring
	airUp: number, -- the air pose's make-up (rising, falling, a long fall), held from the landing
	airDown: number,
	airLong: number,
	mood: number,
	moodAt: number,
	guarded: boolean,
	-- the air
	grounded: boolean,
	lastCheck: number,
	airTime: number,
	airClock: number,
	airWeight: number,
	jumped: boolean,
	lowest: number,
	-- layers over the base
	land: Layer?,
	start: Layer?,
	stop: Layer?,
	moving: number,
	plant: number,
	-- turning
	lastYaw: number?,
	body: number,
	turning: boolean,
	lean: number,
	tip: number,
	feet: Feet.Feet,
	-- standing extras
	fidgetAt: number,
	bag: Gait.Bag,
	still: number,
	settled: boolean,
	stanceClip: string?,
	farCheck: number,
	-- a stroll, faded in and out (the last one kept while it fades)
	strollWeight: number,
	strollClip: string?,
	-- sitting in a chair at the war table, faded in and out (the last seat kept while it fades)
	seatWeight: number,
	seatClip: string?,
}

local states: { [Model]: State } = {}
-- Bodies this client moves itself (the Tokyo crowd): anchored, so they have no velocity to read and are told
-- how fast they walk (always forward).
local adopted: { [Model]: number } = {}
local clips: { [string]: ClipPlayer.Prepared } = {}

-- Reused buffers (one body is posed at a time).
local P = {
	out = Pose.new(),
	idle = Pose.new(),
	guarded = Pose.new(),
	cycle = Pose.new(),
	walk = Pose.new(),
	run = Pose.new(),
	stride = Pose.new(),
	air = Pose.new(),
	part = Pose.new(),
	extra = Pose.new(),
	seat = Pose.new(),
}

local IDENTITY = CFrame.identity

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function smoothstep(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function approach(value: number, target: number, rate: number, dt: number): number
	return value + (target - value) * math.min(1, dt * rate)
end

local function stateFor(character: Model): State
	local state = states[character]
	if not state then
		local random = Random.new()
		state = {
			random = random,
			phase = random:NextNumber(),
			idleTime = random:NextNumber(0, 24),
			blendSpeed = 0,
			moveIn = 0,
			lastSpeed = 0,
			stride = 10,
			directions = { F = 1, B = 0, L = 0, R = 0 },
			directionSpeeds = { F = 0, B = 0, L = 0, R = 0 },
			airUp = 0,
			airDown = 0,
			airLong = 0,
			mood = 0,
			moodAt = 0,
			guarded = false,
			grounded = true,
			lastCheck = 0,
			airTime = 0,
			airClock = 0,
			airWeight = 0,
			jumped = false,
			lowest = 0,
			moving = 0,
			plant = 1,
			body = 0,
			turning = false,
			lean = 0,
			tip = 0,
			feet = Feet.new(),
			fidgetAt = os.clock() + random:NextNumber(FIDGET_EVERY[1], FIDGET_EVERY[2]),
			bag = Gait.bag(),
			still = 0,
			settled = false,
			farCheck = 0,
			strollWeight = 0,
			seatWeight = 0,
		}
		states[character] = state
		character.Destroying:Once(function()
			states[character] = nil
		end)
	end
	return state
end

-- How long this avatar's legs are compared with the rig the clips were made on.
local function legLength(character: Model): number
	local leg = character:FindFirstChild("Right Leg")
	return if leg and leg:IsA("BasePart") then leg.Size.Y else 2
end

local function legScale(character: Model, reference: number?): number
	if not reference then
		return 1
	end
	local length = legLength(character)
	return if length > 0.2 then math.clamp(length / reference, 0.4, 3) else 1
end

-- R6 legs are the part that stands on the ground (HipHeight is 0), so the floor is half the root plus a leg
-- below the root's middle.
local function floorDepth(character: Model, root: BasePart, humanoid: Humanoid): number
	return humanoid.HipHeight + root.Size.Y / 2 + legLength(character)
end

local function onGround(character: Model, root: BasePart, humanoid: Humanoid): boolean
	rayParams.FilterDescendantsInstances = { character }
	local reach = floorDepth(character, root, humanoid) + GROUND_REACH
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams) ~= nil
end

-- A body in a running case stands guarded; anyone else (the lobby, a spectator, a stage double) at ease.
local function isGuarded(character: Model): boolean
	if not ClientState.public.active or character:GetAttribute("Away") or character:GetAttribute("Spectator") then
		return false
	end
	local player = Players:GetPlayerFromCharacter(character)
	local userId = if player then player.UserId else character:GetAttribute("BotUserId")
	if type(userId) ~= "number" then
		return false
	end
	for _, entry in ipairs(ClientState.public.players or {}) do
		if entry.userId == userId then
			return entry.alive == true
		end
	end
	return false
end

local function yawOf(root: BasePart): number
	local look = root.CFrame.LookVector
	return math.deg(math.atan2(-look.X, -look.Z))
end

local function wrap(degrees: number): number
	return (degrees + 180) % 360 - 180
end

local function startLayer(id: string, lift: number): Layer?
	local clip = clips[id]
	if not clip then
		return nil
	end
	return { clip = clip, time = 0, weight = 0, lift = lift, ending = false }
end

-- Advances a layer that fades in over `fadeIn`, plays to its end and fades out over `fadeOut` (sooner when
-- told to end); nil once it has finished.
local function advance(layer: Layer?, dt: number, fadeIn: number, fadeOut: number): Layer?
	if not layer then
		return nil
	end
	layer.time += dt
	local length = layer.clip.length
	if layer.ending then
		layer.weight -= dt / math.max(fadeOut, 1e-3)
	else
		local into = if fadeIn > 0 then layer.time / fadeIn else 1
		local out = if fadeOut > 0 then (length - layer.time) / fadeOut else 1
		layer.weight = math.clamp(math.min(into, out), 0, 1)
	end
	if layer.time >= length or layer.weight <= 0 and layer.time > fadeIn then
		return nil
	end
	return layer
end

-- Flying (a Deathsinger, a spectator): a hover easing into a glide with horizontal speed, and into a rise or a
-- dive with vertical speed.
local function flying(state: State, root: BasePart, dt: number): ({ [string]: CFrame }, Vector3)
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local glide = smoothstep(flat / 22)
	local rise = smoothstep((velocity.Y - 2) / 14)
	local dive = smoothstep((-velocity.Y - 2) / 14)
	local out = P.out
	Pose.sample(clips.flyHover, state.idleTime, out)
	Pose.sample(clips.flyGlide, state.idleTime, P.part)
	Pose.blend(out, P.part, glide * (1 - math.max(rise, dive)))
	if rise > 0 then
		Pose.sample(clips.flyRise, state.idleTime, P.part)
		Pose.blend(out, P.part, rise)
	end
	if dive > 0 then
		Pose.sample(clips.flyDive, state.idleTime, P.part)
		Pose.blend(out, P.part, dive)
	end
	-- a bank into the way it drifts sideways
	local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
	state.lean = approach(state.lean, math.clamp(-localVelocity.X / 26, -1, 1) * 10, 4, dt)
	out.joints.root = CFrame.Angles(0, 0, math.rad(state.lean)) * (out.joints.root or IDENTITY)
	state.plant = 0
	state.airWeight, state.airTime = 0, 0
	return out.joints, out.offset
end

-- The base pose for one character this frame.
local function provide(character: Model, dt: number): ({ [string]: CFrame }?, Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return nil, nil
	end
	local state = stateFor(character)
	state.idleTime += dt
	local now = os.clock()

	-- The mood, looked up now and then (a case starting or ending), crossfaded.
	if now - state.moodAt > 1 then
		state.moodAt = now
		state.guarded = isGuarded(character)
	end
	state.mood = math.clamp(state.mood + (if state.guarded then dt else -dt) / MOOD_TIME, 0, 1)

	-- Far off: posed every second frame (the crowd sets its own).
	if adopted[character] == nil and now - state.farCheck > 0.5 then
		state.farCheck = now
		local camera = workspace.CurrentCamera
		local far = camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude > FAR
		PoseController.setEvery(character, if far then 2 else 1)
	end

	-- Flying and sitting take the whole body.
	if character:GetAttribute("Specter") or character:GetAttribute("Spectator") then
		Feet.reset(state.feet)
		-- (a Deathsinger's emote ends when it moves off, as anyone's does)
		local drift = root.AssemblyLinearVelocity
		if Vector3.new(drift.X, 0, drift.Z).Magnitude > MOVE_FULL * 2 then
			PoseController.stopEmotes(character)
		end
		return flying(state, root, dt)
	end
	if humanoid.Sit then
		Feet.reset(state.feet)
		state.plant, state.airWeight, state.airTime = 0, 0, 0
		Pose.sample(clips.sit, state.idleTime, P.out)
		return P.out.joints, P.out.offset
	end
	-- Sitting in a chair at the war table (Shared/Seating): the seat clip the server names is the whole body's base
	-- (an emote plays over it from the waist up), faded in and out over SEAT_FADE so sitting down and getting up are
	-- never a jump.
	local seatName = character:GetAttribute(Seating.ATTRIBUTE)
	local seating = type(seatName) == "string" and ClipPlayer.get(seatName) ~= nil
	if seating then
		state.seatClip = seatName :: string
	end
	state.seatWeight = math.clamp(state.seatWeight + (if seating then dt else -dt) / SEAT_FADE, 0, 1)
	local seatClip = if state.seatWeight > 0 and state.seatClip then ClipPlayer.get(state.seatClip) else nil
	if not seatClip then
		state.seatClip = nil
	elseif state.seatWeight >= 1 then
		Feet.reset(state.feet)
		state.plant, state.airWeight, state.airTime = 0, 0, 0
		Pose.sample(seatClip, state.idleTime, P.out)
		return P.out.joints, P.out.offset
	end

	-- A stroll's own clips in the place of the idle and the forward cycles, faded in and out over STROLL_FADE
	-- (the last stroll kept while it fades out).
	local idle, guarded = clips.idle, clips.idleGuarded
	local strolling = false
	local stroll = character:GetAttribute("Stroll")
	if type(stroll) == "string" and ClipPlayer.get(stroll) and ClipPlayer.get(stroll .. "Walk") then
		state.strollClip = stroll
		strolling = true
	end
	state.strollWeight = math.clamp(state.strollWeight + (if strolling then dt else -dt) / STROLL_FADE, 0, 1)
	local strollStand: ClipPlayer.Prepared?, strollWalk: ClipPlayer.Prepared? = nil, nil
	local strollClip = state.strollClip
	if state.strollWeight > 0 and strollClip then
		strollStand, strollWalk = ClipPlayer.get(strollClip), ClipPlayer.get(strollClip .. "Walk")
	elseif state.strollWeight <= 0 then
		state.strollClip = nil
	end
	local strollW = if strollStand and strollWalk then smoothstep(state.strollWeight) else 0

	-- How fast, and which way in the body's own frame (an adopted walker only goes forward).
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local localVelocity = root.CFrame:VectorToObjectSpace(Vector3.new(velocity.X, 0, velocity.Z))
	if root.Anchored then
		speed = adopted[character] or 0
		localVelocity = Vector3.new(0, 0, -speed)
		velocity = Vector3.zero
	end
	local accel = (speed - state.lastSpeed) / math.max(dt, 1e-3)
	state.lastSpeed = speed

	-- The ground: every frame near the camera, now and then far off.
	local camera = workspace.CurrentCamera
	local near = camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude < NEAR
	if near or now - state.lastCheck > 0.1 then
		state.lastCheck = now
		local grounded = root.Anchored or onGround(character, root, humanoid)
		if grounded and not state.grounded and state.airTime > LAND_AFTER then
			-- Landed: as hard as it hit.
			local id = Gait.landing(-state.lowest, workspace.Gravity)
			if id then
				state.land = startLayer(id, 1)
			end
		elseif not grounded and state.grounded then
			state.jumped = velocity.Y > 2
			state.airClock = 0
			state.lowest = 0
		end
		state.grounded = grounded
	end
	if state.grounded then
		state.airTime = 0
	else
		state.airTime += dt
		state.lowest = math.min(state.lowest, velocity.Y)
	end
	state.airWeight = if state.grounded
		then math.max(0, state.airWeight - dt * 12)
		else math.min(1, state.airWeight + dt * 14)
	if state.airWeight > 0 then
		state.airClock += dt
	end
	-- (applied eased in and out: the fall's pose never starts to leave, or to come, at its fastest)
	local airW = smoothstep(state.airWeight)

	-- Standing still a while with a stance: settle into it (an emote, so moving ends it).
	local stance = character:GetAttribute("Stance")
	local hasStance = type(stance) == "string" and not strolling
	if hasStance and speed < 0.3 and state.grounded then
		state.still += dt
		if state.still >= STANCE_AFTER and not state.settled and not PoseController.busy(character) then
			state.settled = true
			state.stanceClip = stance
			if ClipPlayer.exists(stance) then
				PoseController.play(character, stance, {
					emote = true,
					fadeIn = 0.8,
					fadeOut = 0.4,
					onEnd = function()
						LocomotionController.Unsettled:Fire(character, stance)
					end,
				})
				LocomotionController.Settled:Fire(character, stance)
			end
		end
	else
		state.still = 0
		state.settled = false
		-- A stance taken off while the body stands in it ends at once.
		if state.stanceClip and not hasStance then
			PoseController.stop(character, state.stanceClip, 0.4)
		end
		state.stanceClip = nil
	end

	-- A fidget now and then, when standing still with nothing else to do (not with a stance or a stroll),
	-- from the mood's own pool.
	if speed < 0.3 and state.grounded and not hasStance and not strolling and now >= state.fidgetAt then
		state.fidgetAt = now + state.random:NextNumber(FIDGET_EVERY[1], FIDGET_EVERY[2])
		if not PoseController.busy(character) then
			local pool = if state.mood > 0.5 then CASE_FIDGETS else LOBBY_FIDGETS
			local id = Gait.draw(state.bag, pool, state.random)
			if id and ClipPlayer.exists(id) then
				PoseController.play(
					character,
					id,
					{ fadeIn = 0.4, fadeOut = 0.5, duration = ClipPlayer.length(id), emote = true }
				)
			end
		end
	end

	-- Moving stops emotes.
	if speed > MOVE_FULL * 2 or not state.grounded then
		PoseController.stopEmotes(character)
	end

	-- Standing: the two idles by mood.
	local out = P.out
	Pose.sample(idle, state.idleTime, P.idle)
	if state.mood > 0 and guarded ~= idle then
		Pose.sample(guarded, state.idleTime, P.guarded)
		Pose.blend(P.idle, P.guarded, smoothstep(state.mood))
	end
	if strollW > 0 and strollStand then
		Pose.sample(strollStand, state.idleTime, P.extra)
		Pose.blend(P.idle, P.extra, strollW)
	end
	Pose.copy(P.idle, out)

	-- Moving: the eight cycles by direction and speed, on the shared phase. Humanoids start and stop almost
	-- at once; the poses ease between speeds instead.
	local before = state.blendSpeed
	state.blendSpeed = approach(state.blendSpeed, speed, if speed > state.blendSpeed then 14 else 10, dt)
	-- (setting off, the cycle comes in over MOVE_IN at most; slowing down, it follows the speed)
	local wanted = math.clamp(state.blendSpeed / MOVE_FULL, 0, 1)
	state.moveIn = if wanted > state.moveIn then math.min(wanted, state.moveIn + dt / MOVE_IN) else wanted
	local moving = smoothstep(state.moveIn)
	state.moving = moving
	local running = smoothstep((state.blendSpeed - RUN_FROM) / (RUN_FULL - RUN_FROM))
	-- (on the spring: DIR_OMEGA; a long frame is taken in short steps so the spring stays steady)
	local headings = Gait.directions(localVelocity)
	local left = math.min(dt, 0.25)
	while left > 0 do
		local h = math.min(left, 1 / 60)
		left -= h
		for _, d in ipairs(DIRECTIONS) do
			local goal = if speed > 0.5 then headings[d] else state.directions[d]
			local w, v = state.directions[d], state.directionSpeeds[d]
			v += (DIR_OMEGA * DIR_OMEGA * (goal - w) - 2 * DIR_OMEGA * v) * h
			state.directions[d] = math.clamp(w + v * h, 0, 1)
			state.directionSpeeds[d] = v
		end
	end
	if not state.legScale then
		state.legScale = legScale(character, clips.run.leg)
	end
	local walkClip, runClip = clips[CYCLE.walk.F], clips[CYCLE.run.F]
	local walkStride = (walkClip.stride or 4) * (state.legScale :: number)
	local runStride = (runClip.stride or 10) * (state.legScale :: number)
	local stride = walkStride + (runStride - walkStride) * running
	local travel = (walkClip.stride or 4) * (walkClip.stance or 0.6) -- studs a body moves over a planted foot
	if strollW > 0 and strollWalk then
		-- a stroll's walk takes the place of both the walk and the run forward
		local strollStride = (strollWalk.stride or 4) * (state.legScale :: number)
		stride += (strollStride - stride) * strollW
		travel += ((strollWalk.stride or 4) * (strollWalk.stance or 0.6) - travel) * strollW
	end
	local shared = math.clamp(travel / (stride / (state.legScale :: number)), 0.05, 0.95)
	local previous = state.phase
	-- The stride advances by the ground the body really covered since the last pose (another player's body is
	-- moved by smoothed positions, not by its velocity); a jump in position (a teleport) counts as nothing.
	local covered = dt * speed
	local position = root.Position
	if not root.Anchored and state.lastPosition then
		local moved = (position - state.lastPosition) * Vector3.new(1, 0, 1)
		covered = if moved.Magnitude < math.max(4, speed * dt * 3) then moved.Magnitude else 0
	end
	state.lastPosition = position
	state.stride = stride
	state.phase = (state.phase + covered / stride) % 1
	if state.grounded and speed > MOVE_FULL and not root.Anchored then
		if state.phase < previous or (previous < 0.5 and state.phase >= 0.5) then
			LocomotionController.Footfall:Fire(character)
		end
	end
	if moving > 0 then
		local total = 0
		for _, d in ipairs(DIRECTIONS) do
			local w = state.directions[d]
			if w > 0.002 then
				Pose.sampleCycle(clips[CYCLE.walk[d]], state.phase, shared, P.walk)
				if running > 0 then
					Pose.sampleCycle(clips[CYCLE.run[d]], state.phase, shared, P.run)
					Pose.blend(P.walk, P.run, running)
				end
				if d == "F" and strollW > 0 and strollWalk then
					Pose.sampleCycle(strollWalk, state.phase, shared, P.extra)
					Pose.blend(P.walk, P.extra, strollW)
				end
				total = Pose.mix(P.cycle, P.walk, w, total)
			end
		end
		Pose.blend(out, P.cycle, moving)
	end

	-- Setting off: the body tips into the first step. Stopping from a run: the stop on the foot that is down.
	if before < 1 and speed > 6 and state.grounded then
		state.start = startLayer("startStep", 1)
		state.stop = nil
	end
	if before > 8 and speed < 1 and state.grounded and not state.stop then
		local onRight = state.phase >= 0.75 or state.phase < 0.25
		state.stop = startLayer(if onRight then "stopRight" else "stopLeft", 1)
	end
	if state.stop and speed > 3 then
		state.stop.ending = true
	end
	state.stop = advance(state.stop, dt, 0.08, 0.2)
	local stopping = 0
	if state.stop then
		Pose.sample(state.stop.clip, state.stop.time, P.part)
		stopping = smoothstep(state.stop.weight)
		Pose.blend(out, P.part, stopping)
	end

	-- The air: the take-off when it jumped (or the hang when it stepped off), the top, the fall, a long fall.
	-- Its make-up follows the body's rise and fall while it is in the air, and is held as it was from the moment
	-- it lands (the speed drops to nothing then, and would swap the pose in one frame while it is still fading).
	if not state.grounded then
		state.airUp = smoothstep((velocity.Y - 2) / 10)
		state.airDown = smoothstep((-velocity.Y - 4) / 12)
		state.airLong = math.max(smoothstep((-velocity.Y - 40) / 25), smoothstep((state.airClock - 1.2) / 0.6))
	end
	if state.airWeight > 0 then
		local air = P.air
		local up, down = state.airUp, state.airDown
		Pose.sample(clips.jumpApex, state.airClock, air)
		if up > 0 and state.jumped then
			Pose.sample(clips.jump, math.min(state.airClock, clips.jump.length), P.part)
			Pose.blend(air, P.part, up)
		end
		if down > 0 then
			Pose.sample(clips.fall, state.airClock, P.part)
			local long = state.airLong
			if long > 0 then
				Pose.sample(clips.fallLong, state.airClock, P.extra)
				Pose.blend(P.part, P.extra, long)
			end
			Pose.blend(air, P.part, down)
		end
		Pose.blend(out, air, airW)
	end

	-- Layers over it all: the first step, the landing (the dip shallower while moving, the legs left to the
	-- cycle or the planted feet). Their weights are eased in and out, and a landing comes in over LAND_IN: in
	-- one frame its dip would snap the arms.
	state.start = advance(state.start, dt, 0.04, 0.14)
	if state.start then
		Pose.add(out, state.start.clip, state.start.time, smoothstep(state.start.weight) * moving, 1, false)
	end
	state.land = advance(state.land, dt, LAND_IN, 0.12)
	if state.land then
		Pose.add(out, state.land.clip, state.land.time, smoothstep(state.land.weight), 1 - 0.45 * moving, false)
	end

	-- Leaning into a curve (the root turning while it runs) and against a change of speed.
	local yaw = yawOf(root)
	local turned = if state.lastYaw then wrap(yaw - state.lastYaw) else 0
	state.lastYaw = yaw
	local yawRate = turned / math.max(dt, 1e-3)
	local bank = math.clamp(yawRate * speed * 0.0021, -LEAN_MAX, LEAN_MAX) * moving * (1 - airW)
	state.lean = approach(state.lean, bank, 5, dt)
	state.tip = approach(state.tip, math.clamp(-accel * 0.03, -5, 3) * moving * (1 - airW), 6, dt)

	-- Turning on the spot: the body lags the root, the head leads, then the body comes round and the feet
	-- step after it. Moving, the lag goes at once. A turn the camera drives (shift lock or first person on this
	-- player's own body, or any snap turn faster than a walk ever makes) takes the body and legs round with the root at
	-- once: the owner, 2026-10-25, "when you turn around with your camera in shiftlock your legs move with you and not
	-- delayed".
	local standing = (1 - moving) * (1 - airW)
	local locked = character == Players.LocalPlayer.Character
		and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	local snap = math.abs(yawRate) > CAMERA_TURN
	if standing > 0.5 and state.grounded and (locked or snap) then
		state.body = 0
		state.turning = false
		if math.abs(turned) > 0.01 then
			Feet.reset(state.feet)
		end
	elseif standing > 0.5 and state.grounded then
		state.body = math.clamp(state.body - turned, -100, 100)
		if math.abs(state.body) > TURN_AFTER then
			state.turning = true
		end
		if state.turning then
			state.body = approach(state.body, 0, 7, dt)
			if math.abs(state.body) < 1 then
				state.turning = false
			end
		end
		Feet.update(state.feet, turned, state.body, dt)
	else
		state.body = approach(state.body, 0, 14, dt)
		state.turning = false
		-- (the feet let go of their marks as the stride takes them: over a moment, while they are still partly
		-- planted; at once only when nothing plants them any more)
		if standing <= 0.01 then
			Feet.reset(state.feet)
		else
			Feet.relax(state.feet, dt)
		end
	end
	local rootRotation = out.joints.root or IDENTITY
	out.joints.root = CFrame.Angles(math.rad(state.tip), math.rad(state.body), math.rad(state.lean)) * rootRotation
	if math.abs(state.body) > 0.05 then
		out.joints.neck = CFrame.Angles(0, math.rad(-0.75 * state.body), 0) * (out.joints.neck or IDENTITY)
	end

	-- How much the after-pass plants the feet: standing, on the ground, not in a stop.
	state.plant = standing * (1 - stopping)
	-- Settling into a chair or getting up out of it: the seat over the standing body, by its weight.
	if seatClip then
		local w = smoothstep(state.seatWeight)
		Pose.sample(seatClip, state.idleTime, P.seat)
		Pose.blend(out, P.seat, w)
		state.plant *= 1 - w
	end
	return out.joints, out.offset
end

-- After every layer: a standing body's soles back on their marks (see Locomotion/Feet).
local function after(rig: PoseController.Rig, _dt: number)
	local character = rig.character
	local state = states[character]
	if not state then
		return
	end
	local weight = state.plant * (1 - rig.legsTaken)
	if weight <= 0.001 then
		return
	end
	local humanoid = rig.humanoid
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or humanoid.Sit then
		return
	end
	local stance = STANCES[1] + (STANCES[2] - STANCES[1]) * smoothstep(state.mood)
	Feet.plant(rig, state.feet, stance, floorDepth(character, root, humanoid), legLength(character), weight)
end

-- Roblox's own Animate script (added to characters by default) would play its walk on top
-- of ours, and tracks this client starts on its own body replicate to everyone. Only this
-- player's own Animate runs here, so only that one is stopped.
local function silenceDefaultAnimate(character: Model, humanoid: Humanoid): number
	local removed = 0
	for _, item in ipairs(character:GetChildren()) do
		if item.Name == "Animate" and (item:IsA("LocalScript") or item:IsA("Script")) then
			(item :: any).Enabled = false
			item:Destroy()
			removed += 1
		end
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, playing in ipairs(animator:GetPlayingAnimationTracks()) do
			playing:Stop(0)
		end
	end
	return removed
end

local function track(character: Model)
	-- Wait for the rig to be assembled.
	character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local own = character == Players.LocalPlayer.Character
	local removed = 0
	if own then
		removed += silenceDefaultAnimate(character, humanoid)
		-- The script can arrive a moment after the body.
		local connection = character.ChildAdded:Connect(function(item)
			if item.Name == "Animate" then
				task.defer(function()
					removed += silenceDefaultAnimate(character, humanoid)
				end)
			end
		end)
		task.delay(10, function()
			connection:Disconnect()
		end)
	end
	local rig = PoseController.bindWhenReady(character, 8)
	if RunService:IsStudio() and own then
		-- One line in the output (and Studio's log) that says whether the animator took over.
		task.delay(4, function()
			local joints = 0
			for _ in pairs(if rig then rig.motors else {}) do
				joints += 1
			end
			local animate = character:FindFirstChild("Animate")
			local animator = humanoid:FindFirstChildOfClass("Animator")
			print(
				string.format(
					"[DeathsGambit] Animation check: %s, %d joints (%s), clip animator %s, default Animate %s, Roblox tracks %d, walk speed %d",
					tostring(humanoid.RigType),
					joints,
					if rig then Joints.kind(rig.motors) else Joints.kind(Joints.find(character)),
					if rig then "on" else "OFF",
					if animate then "STILL PRESENT" elseif removed > 0 then "removed" else "absent",
					if animator then #animator:GetPlayingAnimationTracks() else 0,
					humanoid.WalkSpeed
				)
			)
		end)
	end
end

-- Animates a body that is neither a player's nor a bot's (a walker of the Tokyo crowd, drawn and moved
-- by World/Crowd on an anchored root). Call it again whenever the body comes back into the world.
function LocomotionController.adopt(character: Model)
	if adopted[character] == nil then
		adopted[character] = 0
		character.Destroying:Once(function()
			adopted[character] = nil
		end)
	end
	PoseController.bind(character)
end

-- How fast an adopted body is walking (studs a second): its stride follows.
function LocomotionController.setSpeed(character: Model, speed: number)
	if adopted[character] ~= nil then
		adopted[character] = speed
	end
end

function LocomotionController.init()
	for _, id in ipairs(REQUIRED) do
		local clip = ClipPlayer.get(id)
		if not clip then
			warn("[DeathsGambit] Missing movement clip " .. id .. "; run art/scripts/run_anims.py.")
			return
		end
		clips[id] = clip
	end
	PoseController.setBaseProvider(provide)
	PoseController.setAfterPass(after)
	-- Every player's character and every test bot's.
	Characters.each(function(character)
		task.spawn(track, character)
	end)
end

return LocomotionController
