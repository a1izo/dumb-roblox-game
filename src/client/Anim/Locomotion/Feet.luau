--!strict
-- The feet of a standing body (the movement controller's after-pass). Once every layer has moved the body
-- (the idle's sway, a fidget's turn, a landing's dip), each leg is set upright on its sole's mark, sliding
-- up into the hip as the body sinks (R6's bent knee), so the soles never slide. Turning on the spot, the
-- body first lags behind its root and the feet hold their ground; then the body comes round and the feet
-- step after it, one at a time, each lifting as it turns.

local Feet = {}

export type Feet = {
	yaw: { [number]: number }, -- each foot's turn from the root's facing (degrees; [1] right, [-1] left)
	lift: { [number]: number }, -- how high each foot is off its mark (studs)
	stepping: number?, -- the foot taking a step (1 or -1), and how far into it (0..1)
	step: number,
	from: number, -- the stepping foot's turn when its step began
}

local STEP_TIME = 0.2 -- seconds a step takes
local STEP_LIFT = 0.16 -- studs a stepping foot rises
local STEP_AFTER = 18 -- degrees a foot may be turned from the body before it steps

function Feet.new(): Feet
	return { yaw = { [1] = 0, [-1] = 0 }, lift = { [1] = 0, [-1] = 0 }, stepping = nil, step = 0, from = 0 }
end

-- One frame: the root turned `turned` degrees (left +) and the body faces `body` degrees from the root
-- (its lag, eased off by the controller). Feet that are down stay where they are in the world; the one
-- most out of line with the body steps into line when it is out by more than STEP_AFTER.
function Feet.update(feet: Feet, turned: number, body: number, dt: number)
	for _, side in ipairs({ 1, -1 }) do
		if feet.stepping ~= side then
			feet.yaw[side] -= turned
		end
	end
	if feet.stepping then
		local side = feet.stepping :: number
		feet.step = math.min(1, feet.step + dt / STEP_TIME)
		local u = feet.step
		local k = u * u * (3 - 2 * u)
		feet.yaw[side] = feet.from + (body - feet.from) * k
		feet.lift[side] = STEP_LIFT * math.sin(math.pi * u)
		if u >= 1 then
			feet.lift[side] = 0
			feet.stepping = nil
		end
		return
	end
	local right, left = math.abs(feet.yaw[1] - body), math.abs(feet.yaw[-1] - body)
	local side = if right >= left then 1 else -1
	if math.max(right, left) > STEP_AFTER then
		feet.stepping = side
		feet.step = 0
		feet.from = feet.yaw[side]
	end
end

-- The feet back under the body at once (it sat down, took off, flies).
function Feet.reset(feet: Feet)
	feet.yaw[1], feet.yaw[-1] = 0, 0
	feet.lift[1], feet.lift[-1] = 0, 0
	feet.stepping = nil
end

-- The feet coming back under the body over a moment, while the stride takes them from their marks (setting off:
-- they are still partly planted, so a reset in one frame would snap the hips).
local RELAX = 12 -- per second
function Feet.relax(feet: Feet, dt: number)
	local k = math.min(1, dt * RELAX)
	for _, side in ipairs({ 1, -1 }) do
		feet.yaw[side] -= feet.yaw[side] * k
		feet.lift[side] -= feet.lift[side] * k
	end
	feet.stepping = nil
end

type Rig = {
	motors: { [string]: any },
	c0: { [string]: CFrame },
	c1: { [string]: CFrame },
}

local HIPS = { [1] = "rHip", [-1] = "lHip" }

-- Sets each leg upright on its sole's mark, `weight` of the way from the pose it has. stance: how far the
-- soles stand apart beyond hip width (studs); floor: the floor's height below the root's middle; leg: a
-- leg's length.
function Feet.plant(rig: Rig, feet: Feet, stance: number, floor: number, leg: number, weight: number)
	local root = rig.motors.root
	local rootC0, rootC1 = rig.c0.root, rig.c1.root
	if not root or not rootC0 or not rootC1 then
		return
	end
	-- the torso in the root's frame, as every layer has left it
	local torso = rootC0 * root.Transform * rootC1:Inverse()
	local fromTorso = torso:Inverse()
	for side, joint in pairs(HIPS) do
		local motor = rig.motors[joint]
		local c0, c1 = rig.c0[joint], rig.c1[joint]
		if motor and c0 and c1 then
			local turn = CFrame.Angles(0, math.rad(feet.yaw[side]), 0)
			local sole = turn * Vector3.new(side * (0.5 + stance), -floor + feet.lift[side], 0)
			local part = CFrame.new(sole) * turn * CFrame.new(0, leg / 2, 0)
			local target = c0:Inverse() * fromTorso * part * c1
			motor.Transform = if weight >= 1 then target else motor.Transform:Lerp(target, weight)
		end
	end
end

return Feet
