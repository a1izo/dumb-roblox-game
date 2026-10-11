--!strict
-- The Tokyo scramble's signal cycle, the same on the server and on every client: it is worked out
-- from one number (the map's ScrambleEpoch attribute, a server time), so nothing is sent while it
-- runs. One turn of the cycle:
--   WALK   the crowd crosses, every way at once (cars wait at their stop lines)
--   FLASH  the walk lamps blink: finish crossing, nobody starts
--   CARS   the cars drive through; crossing now is jaywalking (after a short grace)
--   AMBER  the cars that can still stop do

local ScrambleCycle = {}

ScrambleCycle.WALK = 11
ScrambleCycle.FLASH = 4
ScrambleCycle.CARS = 32
ScrambleCycle.AMBER = 3
ScrambleCycle.LENGTH = ScrambleCycle.WALK + ScrambleCycle.FLASH + ScrambleCycle.CARS + ScrambleCycle.AMBER
-- Seconds into CARS before someone still on the crossing counts as jaywalking (they were let onto
-- it by the walk lamp a moment ago).
ScrambleCycle.GRACE = 2

export type Phase = "WALK" | "FLASH" | "CARS" | "AMBER"

local ORDER: { { name: Phase, length: number } } = {
	{ name = "WALK", length = ScrambleCycle.WALK },
	{ name = "FLASH", length = ScrambleCycle.FLASH },
	{ name = "CARS", length = ScrambleCycle.CARS },
	{ name = "AMBER", length = ScrambleCycle.AMBER },
}

-- The phase at `now`, how long it has run and how long it has left (seconds).
function ScrambleCycle.at(epoch: number, now: number): (Phase, number, number)
	local t = (now - epoch) % ScrambleCycle.LENGTH
	for _, phase in ipairs(ORDER) do
		if t < phase.length then
			return phase.name, t, phase.length - t
		end
		t -= phase.length
	end
	return "WALK", 0, ScrambleCycle.WALK -- (only a rounding error away from the cycle's end)
end

-- Seconds until the cars go, while someone may still step onto the crossing (WALK); 0 otherwise.
function ScrambleCycle.clearFor(epoch: number, now: number): number
	local phase, _, left = ScrambleCycle.at(epoch, now)
	return if phase == "WALK" then left + ScrambleCycle.FLASH else 0
end

-- Whether being on the crossing at `now` is jaywalking.
function ScrambleCycle.jaywalking(epoch: number, now: number): boolean
	local phase, into = ScrambleCycle.at(epoch, now)
	return phase == "AMBER" or (phase == "CARS" and into >= ScrambleCycle.GRACE)
end

-- What the walk lamps show: "walk", "blink" (finish crossing) or "wait".
function ScrambleCycle.walkLamp(phase: Phase): string
	return if phase == "WALK" then "walk" elseif phase == "FLASH" then "blink" else "wait"
end

-- Two roads meet at the scramble and share the cars' time, one after the other, so their cars never
-- cross each other's path: road 1 (the avenue) has the first half of CARS, road 2 (the station drive
-- and the east street) the second. Each ends on AMBER seconds of amber: road 1's inside CARS, road
-- 2's is the cycle's own AMBER. What a road's lamps show: "green", "amber" or "red".
ScrambleCycle.ROADS = 2

function ScrambleCycle.roadLamp(epoch: number, now: number, road: number): string
	local phase, into = ScrambleCycle.at(epoch, now)
	local half = ScrambleCycle.CARS / 2
	if road == 1 then
		if phase == "CARS" and into < half - ScrambleCycle.AMBER then
			return "green"
		elseif phase == "CARS" and into < half then
			return "amber"
		end
	elseif phase == "CARS" and into >= half then
		return "green"
	elseif phase == "AMBER" then
		return "amber"
	end
	return "red"
end

return ScrambleCycle
