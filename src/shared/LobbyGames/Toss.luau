--!strict
-- The rift stone-toss: throw a pebble from the cairn towards the rift. How far it goes follows how
-- high you aim (look higher to throw farther); one that lands in the rift falls a long way and the
-- score is how long you hear it (the echo): a pebble that drops near the rift's walls knocks against
-- them on the way down and rings longer. The server works it all out; the client only plays it.
-- Pure rules, tested in LobbyGames.spec.

local Toss = {}

Toss.COOLDOWN = 1.6 -- seconds between throws
Toss.RANGE = 14 -- studs from the cairn within which a throw counts
Toss.MIN_DISTANCE = 16
Toss.MAX_DISTANCE = 120
Toss.PITCH_LOW = -10 -- degrees of look pitch that throw the least...
Toss.PITCH_HIGH = 40 -- ...and the farthest
Toss.FREE_FALL = 1.65 -- seconds to fall to the city with nothing in the way
Toss.BOUNCE = 0.55 -- seconds each knock against the wall adds

export type Rift = { cx: number, cz: number, rx: number, rz: number, turn: number }
export type Result = { hit: boolean, land: Vector2, echo: number, bounces: number, flight: number }

-- How far a throw goes for a look pitch in degrees.
function Toss.distance(pitch: number): number
	local u = math.clamp((pitch - Toss.PITCH_LOW) / (Toss.PITCH_HIGH - Toss.PITCH_LOW), 0, 1)
	return Toss.MIN_DISTANCE + (Toss.MAX_DISTANCE - Toss.MIN_DISTANCE) * u
end

-- How far into the rift a point is, as the elliptical radius: 0 in the middle, 1 at the edge, above
-- 1 outside it.
function Toss.depth(point: Vector2, rift: Rift): number
	local a = math.rad(rift.turn)
	local dx, dz = point.X - rift.cx, point.Y - rift.cz
	local x = dx * math.cos(a) + dz * math.sin(a)
	local z = -dx * math.sin(a) + dz * math.cos(a)
	return math.sqrt((x / rift.rx) ^ 2 + (z / rift.rz) ^ 2)
end

-- The throw: `origin` and `dir` (a unit direction) on the ground plane (x, z), the look pitch in degrees.
function Toss.result(origin: Vector2, dir: Vector2, pitch: number, rift: Rift, rng: Random): Result
	local distance = Toss.distance(pitch)
	local land = origin + dir * distance
	local flight = 0.55 + distance / 70
	local u = Toss.depth(land, rift)
	if u >= 0.92 then
		return { hit = false, land = land, echo = 0, bounces = 0, flight = flight }
	end
	-- Near the walls it knocks more often; every throw has a little luck in it.
	local bounces = math.floor(u * u * 4.5) + (if rng:NextNumber() < 0.4 then 1 else 0)
	local echo = Toss.FREE_FALL + bounces * Toss.BOUNCE + rng:NextNumber(0, 0.3)
	return { hit = true, land = land, echo = math.floor(echo * 10 + 0.5) / 10, bounces = bounces, flight = flight }
end

function Toss.isBetter(best: number, echo: number): boolean
	return echo > best
end

return Toss
