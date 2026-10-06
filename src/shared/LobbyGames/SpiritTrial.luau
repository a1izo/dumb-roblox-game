--!strict
-- The spirit trial: for a Deathsinger waiting in the lobby (away from the case), a loop of glowing rings on the
-- lobby's grounds, run and jumped through in order against the clock. Only ghosts see it. Pure rules, used by
-- the server (LobbyGameService) and tested in LobbyGames.spec. The ring spots themselves come from the server,
-- which lays the loop out on the real ground (`SpiritTrial.layout` gives the plan, the server drops each spot
-- onto the floor).

local SpiritTrial = {}

SpiritTrial.RINGS = 8
SpiritTrial.MIN_TIME = 14 -- seconds: no honest lap is faster
SpiritTrial.MAX_SPEED = 32 -- studs per second between two rings, jumps included
SpiritTrial.REACH = 6 -- studs from a ring's middle that count as passing through it
SpiritTrial.WANDER = 120 -- studs from the loop's middle where a run is given up

export type Session = { startedAt: number, reached: number, lastAt: number }

-- Where the rings go, around `center` on the flat (heights are the floor's, added by the server): a loop
-- that swings in and out, so it is a zigzag rather than a plain circle.
function SpiritTrial.layout(center: Vector3): { Vector3 }
	local spots = {}
	for index = 1, SpiritTrial.RINGS do
		local angle = (index - 1) / SpiritTrial.RINGS * math.pi * 2
		local radius = if index % 2 == 0 then 52 else 34
		table.insert(spots, center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	return spots
end

function SpiritTrial.newSession(now: number): Session
	return { startedAt = now, reached = 0, lastAt = now }
end

-- A ring counts only in order and only if the run since the last one was possible: `travel` is the distance
-- in studs from the last ring (or the start).
function SpiritTrial.reach(session: Session, index: number, now: number, travel: number): (boolean, string?)
	if index ~= session.reached + 1 then
		return false, "out of order"
	end
	if now - session.lastAt < travel / SpiritTrial.MAX_SPEED then
		return false, "too fast"
	end
	session.reached = index
	session.lastAt = now
	return true, nil
end

-- The lap time in seconds once every ring is passed (nil before, or if it could not be honest).
function SpiritTrial.finish(session: Session, now: number): number?
	if session.reached < SpiritTrial.RINGS then
		return nil
	end
	local time = now - session.startedAt
	if time < SpiritTrial.MIN_TIME then
		return nil
	end
	return math.floor(time * 100 + 0.5) / 100
end

-- Lower is better; 0 means no time yet.
function SpiritTrial.isBetter(old: number, new: number): boolean
	return new > 0 and (old <= 0 or new < old)
end

return SpiritTrial
