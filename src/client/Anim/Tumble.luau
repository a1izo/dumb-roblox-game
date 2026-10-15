--!strict
-- The rift dive's body (Controllers/DiveController plays it through PoseController.playProcedural): a body
-- that has no say in how it falls. Its references, principles only: the ragdolls of the Roblox game
-- Broken Bones IV (a body turning over slowly about an axis that keeps drifting, limbs loose and never
-- symmetrical, flung up and back by the air) and real high falls (the first moment over the edge pitches
-- the body forward, arms grabbing at nothing).
--
-- Three moods, one body, blended into each other:
--   tip    over the rim: the body pitches forward, the arms windmill, a leg kicks (about the first second)
--   fall   the whole body turns over on its own (slowly at first, faster as the wind builds); every limb
--          hangs on a loose spring whose rest is pushed up against the fall the faster it goes, flutters at
--          speed and swings out when the spin changes; steering only nudges the turning
--   hang   caught by the string at the upper back: a jolt that throws the limbs, then the body swings and
--          turns slowly under the string, limbs dangling
-- The fall path itself (where the body is) stays DiveController's: it is what is scored. This only turns the
-- torso about its middle (the root joint: the HumanoidRootPart, and so the camera, never turns) and moves
-- the limbs. Joint angles follow Shared/Anim/Joints: x pitch (limbs + forward/up; root - leans forward), y
-- twist, z roll (right limbs + out, left limbs - out).
--
-- A body is drawn from a seed, its speed and its steering: another client given the same seed draws a fall
-- of the same character (not frame for frame: close enough for someone watching from the rim).

local Tumble = {}

local TAU = math.pi * 2

type Spring = { x: number, v: number }
type Limb = { pitch: Spring, roll: Spring, twist: Spring }

export type State = {
	seed: number,
	q: CFrame, -- the torso's turn in the root's frame (rotation only)
	w: Vector3, -- its turning speed (radians a second, root frame)
	noise: { number },
	limbs: { [string]: Limb },
	mode: string, -- "tip", "fall" or "hang"
	modeAt: number, -- elapsed seconds when the mood began
	yaw: number, -- hanging: how far the body has turned on the string (radians)
	last: number, -- the elapsed seconds of the last sample
	speed: number, -- the fall's speed (studs a second), set by the caller
	steer: Vector3, -- steering in the root's frame (x right, z back), set by the caller
	poses: { [string]: CFrame },
}

-- The top speed the dive reaches (Shared/LobbyGames/LastBreath), for "how fast" as a fraction.
Tumble.TOP_SPEED = 80

local LIMBS = { "rShoulder", "lShoulder", "rHip", "lHip", "neck" }

-- Where each limb lies at rest in a loose fall (unit directions in the torso's frame: x right, y up, z back).
local LOOSE = {
	rShoulder = Vector3.new(0.62, -0.55, -0.55).Unit,
	lShoulder = Vector3.new(-0.7, -0.45, -0.4).Unit,
	rHip = Vector3.new(0.3, -0.93, 0.15).Unit,
	lHip = Vector3.new(-0.22, -0.94, -0.25).Unit,
}

-- How far the air lifts each limb at full speed (0: not at all, 1: straight along the wind).
local LIFT = { rShoulder = 0.78, lShoulder = 0.72, rHip = 0.42, lHip = 0.48 }

-- Joint limits (radians): pitch, roll (outward positive for the right side), so no limb passes through the
-- torso. R6 arms and legs are straight blocks.
local ROLL = {
	rShoulder = { -0.3, 2.9 },
	lShoulder = { -2.9, 0.3 },
	rHip = { -0.2, 1.25 },
	lHip = { -1.25, 0.2 },
}
local PITCH = {
	rShoulder = { -math.huge, math.huge },
	lShoulder = { -math.huge, math.huge },
	rHip = { -1.55, 1.9 },
	lHip = { -1.55, 1.9 },
}

-- An R6 arm hangs from the torso's top corner (its pivot) with its middle half a stud out and half a stud down
-- from it: where the arm's middle is for a pose (torso frame: the torso is 2 x 2 x 1 round its middle, the head
-- 2 x 1 x 1 on top of it).
local ARM = {
	rShoulder = { pivot = Vector3.new(1, 0.5, 0), reach = Vector3.new(0.5, -0.5, 0), out = 1 },
	lShoulder = { pivot = Vector3.new(-1, 0.5, 0), reach = Vector3.new(-0.5, -0.5, 0), out = -1 },
}

local function pose(pitch: number, roll: number, twist: number): CFrame
	return CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll) * CFrame.Angles(0, twist, 0)
end

-- Would the arm (a 1 x 2 x 1 block) pass into the torso or the head in this pose?
local function armInside(name: string, pitch: number, roll: number, twist: number): boolean
	local arm = ARM[name]
	local c = arm.pivot + pose(pitch, roll, twist):VectorToWorldSpace(arm.reach)
	local intoTorso = math.abs(c.X) < 1.45 and math.abs(c.Y) < 1.45 and math.abs(c.Z) < 0.95
	local intoHead = math.abs(c.X) < 1.45 and c.Y > 0.6 and c.Y < 2.45 and math.abs(c.Z) < 0.95
	return intoTorso or intoHead
end

-- The pose nearest (pitch, roll) that keeps the arm clear of the torso and the head: the nearest clear roll
-- either way (outwards first: past a quarter turn up, more roll swings the arm back in), else the nearest
-- clear pitch.
local function clearArm(name: string, pitch: number, roll: number, twist: number): (number, number)
	if not armInside(name, pitch, roll, twist) then
		return pitch, roll
	end
	local out = ARM[name].out
	for k = 1, 26 do
		local step = k * 0.1
		if not armInside(name, pitch, roll + out * step, twist) then
			return pitch, roll + out * step
		end
		if not armInside(name, pitch, roll - out * step, twist) then
			return pitch, roll - out * step
		end
	end
	for k = 1, 31 do
		local step = k * 0.1
		if not armInside(name, pitch + step, roll, twist) then
			return pitch + step, roll
		end
		if not armInside(name, pitch - step, roll, twist) then
			return pitch - step, roll
		end
	end
	return pitch, roll
end

local function spring(x: number): Spring
	return { x = x, v = 0 }
end

-- One step of a damped spring towards `target` (stiffness as a frequency, radians a second; damping as a
-- ratio: under 1 overshoots).
local function pull(s: Spring, target: number, freq: number, ratio: number, dt: number)
	local a = freq * freq * (target - s.x) - 2 * ratio * freq * s.v
	s.v += a * dt
	s.x += s.v * dt
end

-- Smooth noise in about [-1, 1]: three slow waves with phases from the seed.
local function wave(state: State, i: number, t: number, rate: number): number
	local n = state.noise
	local k = (i * 3) % #n
	return 0.55 * math.sin(t * rate * 1.0 + n[k + 1])
		+ 0.3 * math.sin(t * rate * 2.13 + n[(k + 1) % #n + 1])
		+ 0.15 * math.sin(t * rate * 4.37 + n[(k + 2) % #n + 1])
end

-- The (pitch, roll) that points a limb hanging along -Y in the direction d (torso frame).
local function aim(d: Vector3): (number, number)
	local roll = math.asin(math.clamp(d.X, -1, 1))
	local pitch = math.atan2(-d.Z, -d.Y)
	return pitch, roll
end

-- `target` moved by whole turns to the one nearest `current` (so a spring never spins the long way round).
local function near(current: number, target: number): number
	return target + TAU * math.floor((current - target) / TAU + 0.5)
end

function Tumble.new(seed: number): State
	local rng = Random.new(seed)
	local noise = {}
	for i = 1, 24 do
		noise[i] = rng:NextNumber(0, TAU)
	end
	local limbs: { [string]: Limb } = {}
	for _, name in ipairs(LIMBS) do
		local rest = LOOSE[name]
		local pitch, roll = 0, 0
		if rest then
			pitch, roll = aim(rest)
		end
		limbs[name] = { pitch = spring(pitch * 0.3), roll = spring(roll * 0.3), twist = spring(0) }
	end
	-- Over the edge: pitching forward (head first), with a little roll and turn of its own.
	local w = Vector3.new(-2.1 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.6, 0.6))
	return {
		seed = seed,
		q = CFrame.identity,
		w = w,
		noise = noise,
		limbs = limbs,
		mode = "tip",
		modeAt = 0,
		yaw = 0,
		last = 0,
		speed = 0,
		steer = Vector3.zero,
		poses = {},
	}
end

-- Caught: the string at the upper back snaps taut.
function Tumble.catch(state: State)
	if state.mode == "hang" then
		return
	end
	state.mode = "hang"
	state.modeAt = state.last
	local _, y = state.q:ToEulerAnglesYXZ()
	state.yaw = y
	-- The jolt: the torso is yanked back about its middle, the limbs thrown on by what they were doing.
	state.w = Vector3.new(state.w.X * 0.3 + 3.2, state.w.Y * 0.5, state.w.Z * 0.3)
	for name, limb in pairs(state.limbs) do
		if name ~= "neck" then
			limb.pitch.v += 6
			limb.roll.v += (if string.sub(name, 1, 1) == "r" then 4 else -4)
		else
			limb.pitch.v += 5
		end
	end
end

-- Turns the torso towards `goal` (rotation) with a spring on the angle between them.
local function steerTowards(q: CFrame, w: Vector3, goal: CFrame, freq: number, ratio: number, dt: number): Vector3
	local axis, angle = (q:Inverse() * goal):ToAxisAngle()
	local err = q:VectorToWorldSpace(axis * angle)
	return w + (err * freq * freq - w * 2 * ratio * freq) * dt
end

-- The joints' rotations `elapsed` seconds into the dive (for PoseController.playProcedural).
function Tumble.sample(state: State, elapsed: number): ({ [string]: CFrame }, Vector3?)
	local dt = math.clamp(elapsed - state.last, 0, 1 / 20)
	state.last = elapsed
	local t = elapsed
	local fast = math.clamp(state.speed / Tumble.TOP_SPEED, 0, 1)
	local since = t - state.modeAt
	if state.mode == "tip" and since > 0.9 then
		state.mode = "fall"
		state.modeAt = t
		since = 0
	end
	-- The torso's turning.
	local w = state.w
	if state.mode == "hang" then
		-- Hanging from a point above the shoulders: the body leans a little forward under it and turns
		-- slowly on the string, swinging out the jolt.
		state.yaw += (0.32 * wave(state, 7, t, 0.25) + 0.18) * dt
		local goal = CFrame.Angles(0, state.yaw, 0) * CFrame.Angles(math.rad(-22), 0, 0)
		w = steerTowards(state.q, w, goal, 3.4, 0.22, dt)
	else
		-- Falling: torques that drift (more of them as the wind builds), the air's drag on the turning, a
		-- limit to how fast it turns, and the steering's nudge.
		local push = (if state.mode == "tip" then 0.4 else 0.9 + 1.6 * fast)
		local torque = Vector3.new(wave(state, 1, t, 0.45), wave(state, 2, t, 0.3) * 0.5, wave(state, 3, t, 0.4)) * push
		torque += Vector3.new(state.steer.Z, 0, -state.steer.X) * 1.6
		w += (torque - w * (0.25 + 0.35 * fast)) * dt
		local most = 1.2 + 1.5 * fast
		if w.Magnitude > most then
			w = w.Unit * most
		end
	end
	state.w = w
	if w.Magnitude > 1e-5 then
		local q = state.q * CFrame.fromAxisAngle(state.q:VectorToObjectSpace(w.Unit), w.Magnitude * dt)
		state.q = q:Orthonormalize()
	end
	local q = state.q
	-- Where the air pushes the limbs (against the fall: up), or where they dangle (down), in the torso's frame.
	local hang = state.mode == "hang"
	local wind = q:VectorToObjectSpace(if hang then -Vector3.yAxis else Vector3.yAxis)
	local poses = state.poses
	for i, name in ipairs(LIMBS) do
		local limb = state.limbs[name]
		if name == "neck" then
			-- The head lolls: it lags the turning and nods with the flutter.
			local nod = 0.35 * wave(state, 11, t, 0.8) + (if hang then 0.35 else -0.15)
			pull(limb.pitch, nod - w.X * 0.12, 9, 0.35, dt)
			pull(limb.roll, 0.3 * wave(state, 12, t, 0.7) - w.Z * 0.1, 9, 0.35, dt)
			pull(limb.twist, 0.5 * wave(state, 13, t, 0.5), 7, 0.4, dt)
			poses.neck = pose(limb.pitch.x, limb.roll.x, limb.twist.x)
			continue
		end
		local rest = LOOSE[name]
		local lift = if hang then 0.9 else LIFT[name] * (0.2 + 0.8 * fast)
		local d = rest:Lerp(wind, lift)
		-- Flutter: quick small shakes that grow with the speed, and slower flailing of their own.
		local quick = (if hang then 0.02 else 0.05 + 0.2 * fast)
		local slow = (if hang then 0.08 else 0.28 + 0.12 * fast)
		d += Vector3.new(
			wave(state, 20 + i, t, 6.5) * quick + wave(state, 30 + i, t, 0.9) * slow,
			wave(state, 40 + i, t, 7.1) * quick * 0.6,
			wave(state, 50 + i, t, 5.9) * quick + wave(state, 60 + i, t, 0.8) * slow
		)
		if state.mode == "tip" then
			-- Grabbing at nothing: the arms windmill forward, a leg kicks.
			if name == "rShoulder" or name == "lShoulder" then
				local a = since * 9 + (if name == "rShoulder" then 0 else math.pi)
				d = Vector3.new(if name == "rShoulder" then 0.35 else -0.35, -math.cos(a), -math.sin(a))
			elseif name == "rHip" then
				d += Vector3.new(0, 0.2, -0.6 * math.sin(since * 7))
			end
		end
		if d.Magnitude < 1e-3 then
			d = rest
		end
		local pitch, roll = aim(d.Unit)
		local pr, rr = PITCH[name], ROLL[name]
		pitch = math.clamp(near(limb.pitch.x, pitch), pr[1], pr[2])
		roll = math.clamp(roll, rr[1], rr[2])
		-- Loose springs (arms looser than legs); a turning body flings them out (they lag the turn).
		local arm = name == "rShoulder" or name == "lShoulder"
		if arm then
			-- (The spring aims for a pose clear of the body...)
			pitch, roll = clearArm(name, pitch, roll, limb.twist.x)
		end
		local freq = (if arm then 7 else 9) * (if hang then 0.8 else 1)
		local ratio = if hang then 0.18 else 0.3
		pull(limb.pitch, pitch, freq, ratio, dt)
		pull(limb.roll, roll, freq, ratio, dt)
		pull(limb.twist, 0.4 * wave(state, 70 + i, t, 0.6), 6, 0.4, dt)
		limb.pitch.x = math.clamp(limb.pitch.x, pr[1], pr[2])
		limb.roll.x = math.clamp(limb.roll.x, rr[1], rr[2])
		if arm then
			-- (...and never passes through it on the way: an arm swinging in is set clear, its swing stopped.)
			local p, r = clearArm(name, limb.pitch.x, limb.roll.x, limb.twist.x)
			if p ~= limb.pitch.x or r ~= limb.roll.x then
				limb.pitch.x, limb.roll.x = p, r
				limb.pitch.v *= 0.3
				limb.roll.v *= 0.3
			end
		end
		poses[name] = pose(limb.pitch.x, limb.roll.x, limb.twist.x)
	end
	poses.root = q
	return poses, nil
end

return Tumble
