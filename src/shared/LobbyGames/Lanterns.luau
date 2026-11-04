--!strict
-- The Lantern Run's rules: take the cold flame at the first lantern (at the foot of the spawn's ledge) and light the
-- eight others across the realm, in any order, before the flame dies. The clock runs from taking the flame to the
-- last lantern lit; the best is the fastest. Pure rules, used by the server (LobbyGameService) and tested in
-- LobbyGames.spec.

local Lanterns = {}

Lanterns.COUNT = 8
Lanterns.LIMIT = 240 -- seconds the cold flame lasts
Lanterns.MIN_TIME = 40 -- seconds: no honest run round all eight is faster
Lanterns.REACH = 8 -- studs sideways from a lantern that count as reaching it
Lanterns.REACH_HEIGHT = 11 -- ...and this far above or below it (the lanterns hang high on their posts)

export type Session = { startedAt: number, lit: { [number]: boolean }, count: number }

function Lanterns.newSession(now: number): Session
	return { startedAt = now, lit = {}, count = 0 }
end

-- Lights lantern `index`: true if it was dark until now.
function Lanterns.light(session: Session, index: number): boolean
	if index < 1 or index > Lanterns.COUNT or session.lit[index] then
		return false
	end
	session.lit[index] = true
	session.count += 1
	return true
end

function Lanterns.done(session: Session): boolean
	return session.count >= Lanterns.COUNT
end

-- Whether the flame has died before the run was done.
function Lanterns.out(session: Session, now: number): boolean
	return not Lanterns.done(session) and now - session.startedAt > Lanterns.LIMIT
end

-- The finished time in seconds (nil while a lantern is still dark, or when no honest run could be that fast).
function Lanterns.finish(session: Session, now: number): number?
	if not Lanterns.done(session) then
		return nil
	end
	local time = now - session.startedAt
	if time < Lanterns.MIN_TIME then
		return nil
	end
	return time
end

-- Whether `time` beats a saved best (0 means none saved yet).
function Lanterns.isBetter(best: number, time: number): boolean
	return best <= 0 or time < best
end

-- Whether a position is close enough to a lantern to light it.
function Lanterns.near(position: Vector3, lantern: Vector3): boolean
	local across = Vector3.new(position.X - lantern.X, 0, position.Z - lantern.Z).Magnitude
	return across <= Lanterns.REACH and math.abs(position.Y - lantern.Y) <= Lanterns.REACH_HEIGHT
end

return Lanterns
