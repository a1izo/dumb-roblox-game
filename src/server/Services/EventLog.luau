-- Server-only record of the match. Key events are replayed at the reveal; sightings
-- feed the camera-footage clues; handled notes feed the fingerprint clues.

local Match = require(script.Parent.Match)

local EventLog = {}

local entries = {}
local sightings = {}
local prints = {}
local inks = {}

function EventLog.reset()
	entries = {}
	sightings = {}
	prints = {}
	inks = {}
end

-- A name written in the Grimoire killed someone: who wrote it, and when (match seconds). Server
-- only; the Forensics clues read it.
function EventLog.ink(writer, victim, writtenAt: number)
	table.insert(inks, {
		id = #inks + 1,
		writerUserId = writer.userId,
		writerAlias = writer.alias,
		victimAlias = victim.alias,
		writtenAt = writtenAt,
	})
end

-- The newest Grimoire death, or nil before the first.
function EventLog.lastInk()
	return inks[#inks]
end

-- A key event for the end-of-match replay. Roles may be named here: the replay is only
-- sent after every role has been revealed.
function EventLog.add(text: string, kind: string?)
	table.insert(entries, {
		time = Match.clock(),
		round = Match.round,
		text = text,
		kind = kind or "info",
	})
end

function EventLog.all()
	return entries
end

-- Something suspicious that a camera could have caught.
function EventLog.sighting(ps, activity: string, position: Vector3)
	table.insert(sightings, {
		at = Match.elapsed(),
		clock = Match.clock(),
		userId = ps.userId,
		alias = ps.alias,
		activity = activity,
		area = Match.nearestArea(position),
		reported = false,
	})
end

-- Newest sighting not reported yet and not older than maxAge seconds.
function EventLog.takeSighting(maxAge: number)
	local now = Match.elapsed()
	for i = #sightings, 1, -1 do
		local sighting = sightings[i]
		if now - sighting.at > maxAge then
			break
		end
		if not sighting.reported then
			sighting.reported = true
			return sighting
		end
	end
	return nil
end

-- A player left fingerprints on a paper note.
function EventLog.print(ps)
	table.insert(prints, {
		at = Match.elapsed(),
		userId = ps.userId,
		reported = false,
	})
end

function EventLog.takePrint(maxAge: number)
	local now = Match.elapsed()
	for i = #prints, 1, -1 do
		local entry = prints[i]
		if now - entry.at > maxAge then
			break
		end
		if not entry.reported then
			entry.reported = true
			return entry
		end
	end
	return nil
end

return EventLog
