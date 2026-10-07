-- Server-only record of the match. Key events are replayed at the reveal; sightings
-- feed the camera-footage clues; handled notes feed the fingerprint clues.

local Match = require(script.Parent.Match)

local EventLog = {}

-- How much a sighting is worth to the camera clue: a low one (a note passed hand to hand, a
-- jaywalker) is only reported when nothing better was seen in the same window.
EventLog.LOW = 1
EventLog.NORMAL = 2
EventLog.HIGH = 3

local LOW_KEEP = 40 -- low sightings kept at most (the oldest go first)

-- Match seconds (the specs replace it to step time by hand).
EventLog.now = function(): number
	return Match.elapsed()
end

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

export type SightingOptions = {
	priority: number?, -- EventLog.LOW / NORMAL (default) / HIGH
	where: string?, -- how the clue names the place ("at the scramble"); default "near <area>"
	key: string?, -- with every: the same player's same key is logged at most once per `every` seconds
	every: number?,
}

-- Something suspicious that a camera could have caught.
function EventLog.sighting(ps, activity: string, position: Vector3, options: SightingOptions?)
	local opts: SightingOptions = options or {}
	local now = EventLog.now()
	local priority = opts.priority or EventLog.NORMAL
	if opts.key and opts.every then
		for i = #sightings, 1, -1 do
			local old = sightings[i]
			if now - old.at >= opts.every then
				break
			end
			if old.key == opts.key and old.userId == ps.userId then
				return
			end
		end
	end
	table.insert(sightings, {
		at = now,
		clock = Match.clock(),
		userId = ps.userId,
		alias = ps.alias,
		activity = activity,
		area = Match.nearestArea(position),
		where = opts.where,
		priority = priority,
		key = opts.key,
		reported = false,
	})
	if priority <= EventLog.LOW then
		local low = 0
		for i = #sightings, 1, -1 do
			if sightings[i].priority <= EventLog.LOW then
				low += 1
				if low > LOW_KEEP then
					table.remove(sightings, i)
				end
			end
		end
	end
end

-- The best unreported sighting not older than maxAge seconds: the highest priority, the newest
-- among equals. A low one is only taken when nothing better is waiting in the window.
function EventLog.takeSighting(maxAge: number)
	local now = EventLog.now()
	local best = nil
	for i = #sightings, 1, -1 do
		local sighting = sightings[i]
		if now - sighting.at > maxAge then
			break
		end
		if not sighting.reported and (best == nil or sighting.priority > best.priority) then
			best = sighting
		end
	end
	if best then
		best.reported = true
	end
	return best
end

-- Where a sighting happened, as the camera clue words it.
function EventLog.place(sighting): string
	return sighting.where or ("near " .. sighting.area)
end

-- A player left fingerprints on a paper note.
function EventLog.print(ps)
	table.insert(prints, {
		at = EventLog.now(),
		userId = ps.userId,
		reported = false,
	})
end

function EventLog.takePrint(maxAge: number)
	local now = EventLog.now()
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
