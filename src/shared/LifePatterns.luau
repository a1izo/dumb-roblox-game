--!strict
-- The pure arithmetic of the small things that move in the maps (client World/MapLife and World/Life/*, the graphics
-- plan's phase 13): fixed patterns for a failing neon sign or tube, a blink, a slow cycle through a few colours, a
-- sway that swells with a gust. No randomness anywhere: every pattern is a function of time and a phase, so a sign
-- flickers the same way every time it is looked at and a spec can check it.

local LifePatterns = {}

-- {start, length, level}: where in a period a sign stutters, for how long, and how bright it is then (1 = full).
local NEON: { { number } } = {
	{ 0.0, 0.07, 0.25 },
	{ 0.16, 0.06, 0.5 },
	{ 0.34, 0.18, 0.22 },
}

-- A failing tube: a longer, slower stutter, not a quick one.
local TUBE: { { number } } = {
	{ 0.0, 0.1, 0.45 },
	{ 0.22, 0.08, 0.2 },
	{ 0.4, 0.05, 0.6 },
	{ 0.55, 0.25, 0.3 },
	{ 1.05, 0.06, 0.5 },
}

local function stutter(list: { { number } }, t: number, period: number, phase: number): number
	local into = (t + phase) % period
	for _, step in ipairs(list) do
		if into >= step[1] and into < step[1] + step[2] then
			return step[3]
		end
	end
	return 1
end

-- How lit a neon sign is at time t (seconds): 1, except for a short stutter at the start of every `period`
-- (`phase` slides it, so two signs with the same period do not stutter together).
function LifePatterns.neon(t: number, period: number, phase: number): number
	return stutter(NEON, t, period, phase)
end

-- The same for a tired tube.
function LifePatterns.tube(t: number, period: number, phase: number): number
	return stutter(TUBE, t, period, phase)
end

-- The seconds a neon stutter and a tube stutter last (so a caller knows when to stop writing and let go).
LifePatterns.NEON_LENGTH = 0.52
LifePatterns.TUBE_LENGTH = 1.11

-- 1 for the first `duty` share of every `period`, else 0.
function LifePatterns.blink(t: number, period: number, duty: number, phase: number): number
	return if (t + phase) % period < period * duty then 1 else 0
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end
LifePatterns.smooth = smooth

-- Walks through `count` entries, holding each for `hold` seconds and then easing into the next over `fade`.
-- Returns (the entry now, the entry after it, how far across the ease is from 0 to 1).
function LifePatterns.cycle(
	t: number,
	hold: number,
	fade: number,
	phase: number,
	count: number
): (number, number, number)
	local span = hold + fade
	local at = t + phase
	local step = math.floor(at / span)
	local into = at - step * span
	local index = step % count + 1
	local nextIndex = index % count + 1
	local k = if into <= hold then 0 else smooth((into - hold) / fade)
	return index, nextIndex, k
end

-- Moves `current` towards `target` the way a heavy thing does (never overshooting): `rate` is 1 over the seconds it
-- takes to cover most of the gap.
function LifePatterns.approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- The wind's strength at time t, 0.6 to 1.5, from three slow rhythms that never line up (the same as the lobby's
-- World/WindSway, which keeps its own copy).
local GUSTS = { 41, 23, 13 }
function LifePatterns.gust(t: number): number
	local sum = 0
	for i, period in ipairs(GUSTS) do
		sum += math.sin(2 * math.pi * t / period + i * 1.9)
	end
	return 1.05 + 0.45 * sum / #GUSTS
end

-- A sway between -1 and 1: one slow swing with a little of a quicker one in it, so it never repeats evenly.
function LifePatterns.sway(t: number, period: number, phase: number): number
	local a = 2 * math.pi * t / period + phase
	return 0.75 * math.sin(a) + 0.25 * math.sin(1.7 * a + 1.3)
end

-- A steady number from 0 up to `span` for a place (its x and z), so the same thing always gets the same phase.
function LifePatterns.phaseOf(x: number, z: number, span: number): number
	local value = math.sin(x * 12.9898 + z * 78.233) * 43758.5453
	return (value - math.floor(value)) * span
end

return LifePatterns
