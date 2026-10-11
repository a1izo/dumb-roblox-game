--!strict
-- Last breath: the dive into the rift. Whoever steps over the rim falls towards the hall far below,
-- gathering speed, and has one press to brake. Braking takes room: press too late and you hit the roof.
-- The score is the gap left between you and the roof when you stop; the smallest gap wins. Divers whose
-- falls begin within a few seconds of each other are one wave and are ranked together.
--
-- The fall is the same curve for everyone and depends on time alone, so the server can score a dive from
-- two moments (when it began, when the brake was pressed) and every client can draw it the same way:
--   falling   from rest, ACCEL studs/s^2 up to MAX_SPEED
--   braking   from the speed at the press, slowing by BRAKE studs/s^2 to a stop
-- Heights here are studs above the roof; the fall begins HEIGHT above it for everyone.

local LastBreath = {}

LastBreath.ACCEL = 16
LastBreath.MAX_SPEED = 70
LastBreath.BRAKE = 90
-- Divers who begin within this many seconds of a wave's first diver belong to it.
LastBreath.WAVE = 4
-- Seconds a diver hangs where they stopped (or lies where they fell) before the rift gives them back.
LastBreath.HOLD = 2.2
-- A press sooner than this after the fall begins is not a brake (the fall has not begun in earnest).
LastBreath.MIN_BRAKE = 0.4
-- The fall begins this far under the rim (once a diver is really in the rift).
LastBreath.DROP = 2

-- The height every dive is scored from: from where the fall begins down to the roof.
function LastBreath.height(rimY: number, roofY: number): number
	return rimY - LastBreath.DROP - roofY
end

export type Outcome = {
	crashed: boolean,
	-- Studs left above the roof (0 when crashed).
	gap: number,
	-- Seconds after the fall began at which the diver is at rest (stopped, or on the roof).
	restAt: number,
}

local function reach(): number
	return LastBreath.MAX_SPEED / LastBreath.ACCEL
end

-- How fast a diver falls t seconds into the fall (before braking).
function LastBreath.speed(t: number): number
	return math.min(math.max(t, 0) * LastBreath.ACCEL, LastBreath.MAX_SPEED)
end

-- How far a diver has fallen t seconds into the fall (before braking).
function LastBreath.fallen(t: number): number
	local time = math.max(t, 0)
	local top = reach()
	if time <= top then
		return 0.5 * LastBreath.ACCEL * time * time
	end
	return 0.5 * LastBreath.ACCEL * top * top + LastBreath.MAX_SPEED * (time - top)
end

-- The seconds it takes to fall `distance` studs (before braking).
function LastBreath.timeToFall(distance: number): number
	local top = reach()
	local atTop = 0.5 * LastBreath.ACCEL * top * top
	if distance <= atTop then
		return math.sqrt(2 * math.max(distance, 0) / LastBreath.ACCEL)
	end
	return top + (distance - atTop) / LastBreath.MAX_SPEED
end

-- The room a brake needs from this speed.
function LastBreath.brakeDistance(speed: number): number
	return speed * speed / (2 * LastBreath.BRAKE)
end

-- How a dive from `height` ends when the brake is pressed `brakeAt` seconds in (nil: never pressed).
function LastBreath.outcome(height: number, brakeAt: number?): Outcome
	local impact = LastBreath.timeToFall(height)
	if not brakeAt or brakeAt >= impact then
		return { crashed = true, gap = 0, restAt = impact }
	end
	local speed = LastBreath.speed(brakeAt)
	local left = height - LastBreath.fallen(brakeAt)
	local room = LastBreath.brakeDistance(speed)
	if room >= left then
		-- Still moving when the roof arrives: slowing from `speed`, `left` studs take this long.
		local after = (speed - math.sqrt(math.max(speed * speed - 2 * LastBreath.BRAKE * left, 0))) / LastBreath.BRAKE
		return { crashed = true, gap = 0, restAt = brakeAt + after }
	end
	return { crashed = false, gap = left - room, restAt = brakeAt + speed / LastBreath.BRAKE }
end

-- Where a diver is t seconds into a dive from `height`: studs above the roof, and the speed downwards.
function LastBreath.at(height: number, t: number, brakeAt: number?): (number, number)
	local impact = LastBreath.timeToFall(height)
	if not brakeAt or t <= brakeAt then
		if t >= impact then
			return 0, 0
		end
		return height - LastBreath.fallen(t), LastBreath.speed(t)
	end
	if brakeAt >= impact then
		return 0, 0
	end
	local speed = LastBreath.speed(brakeAt)
	local left = height - LastBreath.fallen(brakeAt)
	local since = t - brakeAt
	local stops = speed / LastBreath.BRAKE
	local used = if since >= stops
		then LastBreath.brakeDistance(speed)
		else speed * since - 0.5 * LastBreath.BRAKE * since * since
	if used >= left then
		return 0, 0
	end
	return left - used, math.max(speed - LastBreath.BRAKE * since, 0)
end

-- Is `new` a better best than `old` (0: no best yet)? The smaller gap is the better one.
function LastBreath.isBetter(old: number, new: number): boolean
	return new > 0 and (old <= 0 or new < old)
end

-- A gap as it is shown: "0.84".
function LastBreath.format(gap: number): string
	return string.format("%.2f", gap)
end

-- What goes on the board: hundredths of a stud, never less than one (so a perfect stop still has a score).
function LastBreath.score(gap: number): number
	return math.max(1, math.floor(gap * 100 + 0.5))
end

function LastBreath.formatScore(score: number): string
	return LastBreath.format(score / 100)
end

-- Does a dive that began at `start` belong to the wave whose first diver began at `first`?
function LastBreath.sameWave(first: number, start: number): boolean
	return start - first >= 0 and start - first <= LastBreath.WAVE
end

export type Row = { id: any, crashed: boolean, gap: number }

-- A wave's divers in order: the smallest gap first, then those who hit the roof (in the order given).
function LastBreath.rank(rows: { Row }): { Row }
	local sorted = table.clone(rows)
	local order: { [any]: number } = {}
	for index, row in ipairs(rows) do
		order[row] = index
	end
	table.sort(sorted, function(a: Row, b: Row): boolean
		if a.crashed ~= b.crashed then
			return not a.crashed
		end
		if not a.crashed and a.gap ~= b.gap then
			return a.gap < b.gap
		end
		return order[a] < order[b]
	end)
	return sorted
end

return LastBreath
