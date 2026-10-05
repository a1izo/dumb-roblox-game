--!strict
-- The Spire Ascent's rules: ten checkpoints up a spiral of floating stones, a fall puts you back on
-- the last one you reached, the clock runs from the pad to the last stone. Pure rules, used by the
-- server (LobbyGameService) and tested in LobbyGames.spec.

local Parkour = {}

Parkour.CHECKPOINTS = 10
Parkour.MIN_TIME = 40 -- seconds: no honest climb is faster
Parkour.MAX_SPEED = 48 -- studs per second between two stones, jumps and falls included
Parkour.REACH = 7 -- studs sideways from a stone's middle that count as standing on it
Parkour.REACH_HEIGHT = 6 -- ...and this far above or below it
Parkour.FALL_BELOW = 8 -- studs under the stone you last reached that count as a fall
Parkour.WANDER = 62 -- studs from the islet's middle where a run is given up

export type Session = { startedAt: number, reached: number, lastAt: number }

function Parkour.newSession(now: number): Session
	return { startedAt = now, reached = 0, lastAt = now }
end

-- A checkpoint counts only in order and only if the climb since the last one was possible:
-- `travel` is the distance in studs between the two stones (the pad for the first).
function Parkour.reach(session: Session, index: number, now: number, travel: number): (boolean, string?)
	if index ~= session.reached + 1 then
		return false, "out of order"
	end
	if now - session.lastAt < travel / Parkour.MAX_SPEED then
		return false, "too fast"
	end
	session.reached = index
	session.lastAt = now
	return true, nil
end

-- The finished time in seconds (nil while the run is not valid yet or never could have been).
function Parkour.finish(session: Session, now: number): number?
	if session.reached < Parkour.CHECKPOINTS then
		return nil
	end
	local time = now - session.startedAt
	if time < Parkour.MIN_TIME then
		return nil
	end
	return time
end

-- Whether `time` beats a saved best (0 means none saved yet).
function Parkour.isBetter(best: number, time: number): boolean
	return best <= 0 or time < best
end

-- 83.4 -> "1:23.4"
function Parkour.format(seconds: number): string
	local tenths = math.floor(seconds * 10 + 0.5)
	local minutes = tenths // 600
	local rest = (tenths - minutes * 600) / 10
	return string.format("%d:%04.1f", minutes, rest)
end

-- Centiseconds in the ordered data store, back to a clock reading.
function Parkour.formatCentis(centis: number): string
	return Parkour.format(centis / 100)
end

-- Whether a position stands on a checkpoint (its middle given).
function Parkour.near(position: Vector3, mark: Vector3): boolean
	local across = Vector3.new(position.X - mark.X, 0, position.Z - mark.Z).Magnitude
	return across <= Parkour.REACH and math.abs(position.Y - mark.Y) <= Parkour.REACH_HEIGHT
end

-- Whether a position is a fall from the checkpoint you last reached.
function Parkour.fell(position: Vector3, checkpoint: Vector3): boolean
	return position.Y < checkpoint.Y - Parkour.FALL_BELOW
end

return Parkour
