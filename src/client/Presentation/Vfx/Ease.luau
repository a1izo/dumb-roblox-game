--!strict
-- Easing curves for the VFX kit (u 0..1 in, 0..1 out; outBack and outElastic overshoot). Effects move on curves,
-- never in straight lines: a burst flies out fast and settles (outExpo), a ring snaps open (outQuint), a seal
-- stamps down past its mark and back (outBack).

local Ease = {}

export type Fn = (number) -> number

function Ease.linear(u: number): number
	return u
end

function Ease.inQuad(u: number): number
	return u * u
end

function Ease.outQuad(u: number): number
	return 1 - (1 - u) * (1 - u)
end

function Ease.inCubic(u: number): number
	return u * u * u
end

function Ease.outCubic(u: number): number
	local v = 1 - u
	return 1 - v * v * v
end

function Ease.outQuart(u: number): number
	local v = 1 - u
	return 1 - v * v * v * v
end

function Ease.outQuint(u: number): number
	local v = 1 - u
	return 1 - v * v * v * v * v
end

function Ease.outExpo(u: number): number
	return if u >= 1 then 1 else 1 - 2 ^ (-10 * u)
end

function Ease.inExpo(u: number): number
	return if u <= 0 then 0 else 2 ^ (10 * u - 10)
end

function Ease.inOutSine(u: number): number
	return -(math.cos(math.pi * u) - 1) / 2
end

function Ease.inOutCubic(u: number): number
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

function Ease.smooth(u: number): number
	return u * u * (3 - 2 * u)
end

function Ease.outBack(u: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local v = u - 1
	return 1 + c3 * v * v * v + c1 * v * v
end

function Ease.outElastic(u: number): number
	if u <= 0 then
		return 0
	elseif u >= 1 then
		return 1
	end
	return 2 ^ (-10 * u) * math.sin((u * 10 - 0.75) * (2 * math.pi / 3)) + 1
end

-- A curve through points { {u, value}, ... } (u rising from 0 to 1), smooth between them.
function Ease.through(points: { { number } }): Fn
	return function(u: number): number
		if u <= points[1][1] then
			return points[1][2]
		end
		for k = 2, #points do
			local a, b = points[k - 1], points[k]
			if u <= b[1] then
				local t = (u - a[1]) / math.max(b[1] - a[1], 1e-6)
				t = t * t * (3 - 2 * t)
				return a[2] + (b[2] - a[2]) * t
			end
		end
		return points[#points][2]
	end
end

return Ease
