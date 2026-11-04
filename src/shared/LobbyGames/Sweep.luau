--!strict
-- The Reaper's Sweep's rules: a great two-bladed scythe turns round the dais' middle, low over the stones; jump it as a
-- blade comes, or it sweeps you off. It turns faster and faster and now and then swings back the other way. Alone, the
-- score is how long you last; with others, the last one standing wins. The scythe's angle depends on the time since
-- the round began and nothing else, so the server judges and every client draws it alike. Pure rules, used by the
-- server (LobbySweep) and the clients (SweepController), tested in LobbyActivities.spec.

local Sweep = {}

Sweep.WAIT = 6 -- seconds from the first to join until the round starts (others may join meanwhile)
Sweep.SPIN0 = 0.75 -- radians a second at the start (two blades: a pass every 4.2 s at any spot)
Sweep.SPIN_GAIN = 0.022 -- ...gained every second
Sweep.SPIN_MAX = 1.9
Sweep.LONGEST = 150 -- seconds a round lasts at most: whoever still stands then has won it
-- Seconds into a round at which the scythe swings back the other way.
Sweep.REVERSALS = { 17, 31, 43, 53, 62, 70, 77, 83, 89, 94, 99, 104, 109, 114, 119, 124, 129, 134, 139, 144 }
Sweep.ARMS = 2 -- blades, evenly round
Sweep.INNER = 2.6 -- studs from the middle where a blade's shaft begins (the pillar it turns on)
Sweep.OVER = 0.8 -- studs past the dais' edge a blade still reaches
Sweep.CLEAR = 1.5 -- studs over the dais a body's feet must be for a blade to pass under them
Sweep.WIDTH = 0.7 -- studs either side of a blade's line that it strikes

local function spun(t: number): number
	-- The angle turned in the first t seconds, all one way (the spin grows by SPIN_GAIN a second up to SPIN_MAX).
	local top = (Sweep.SPIN_MAX - Sweep.SPIN0) / Sweep.SPIN_GAIN
	if t <= top then
		return Sweep.SPIN0 * t + 0.5 * Sweep.SPIN_GAIN * t * t
	end
	return Sweep.SPIN0 * top + 0.5 * Sweep.SPIN_GAIN * top * top + Sweep.SPIN_MAX * (t - top)
end

-- The first blade's angle (radians, about the vertical, from +x toward +z) `t` seconds into a round.
function Sweep.angle(t: number): number
	local angle, from, sign = 0, 0, 1
	for _, at in ipairs(Sweep.REVERSALS) do
		if t <= at then
			break
		end
		angle += sign * (spun(at) - spun(from))
		from = at
		sign = -sign
	end
	return angle + sign * (spun(math.max(t, from)) - spun(from))
end

-- How fast it turns `t` seconds in (radians a second, its direction's sign included).
function Sweep.spin(t: number): number
	local sign = 1
	for _, at in ipairs(Sweep.REVERSALS) do
		if t <= at then
			break
		end
		sign = -sign
	end
	return sign * math.min(Sweep.SPIN0 + Sweep.SPIN_GAIN * t, Sweep.SPIN_MAX)
end

local function wrap(a: number): number
	return a - math.floor(a / (2 * math.pi)) * 2 * math.pi
end

-- Whether a blade turning from angle a0 to a1 (a short step, either way) passed over the point at `offset` (x, z from
-- the dais' middle) whose feet are `feet` studs over the dais, on a dais of `radius`.
function Sweep.struck(a0: number, a1: number, offset: Vector2, feet: number, radius: number): boolean
	local r = offset.Magnitude
	if feet > Sweep.CLEAR or r < Sweep.INNER - 0.8 or r > radius + Sweep.OVER then
		return false
	end
	local phi = math.atan2(offset.Y, offset.X)
	local width = Sweep.WIDTH / math.max(r, 1)
	local step = math.abs(a1 - a0)
	for arm = 0, Sweep.ARMS - 1 do
		local blade = a0 + arm * 2 * math.pi / Sweep.ARMS
		-- (how far round from the blade's start to the point, the way it is turning)
		local ahead = if a1 >= a0 then wrap(phi - blade) else wrap(blade - phi)
		if ahead <= step + width or ahead >= 2 * math.pi - width then
			return true
		end
	end
	return false
end

-- Whether a time survived beats a saved best (0 means none saved yet): longer is better.
function Sweep.isBetter(best: number, time: number): boolean
	return time > best
end

return Sweep
