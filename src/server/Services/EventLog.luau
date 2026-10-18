-- Server-only record of the match. Key events are replayed at the reveal.

local Match = require(script.Parent.Match)

local EventLog = {}

local entries = {}

function EventLog.reset()
	entries = {}
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

return EventLog
