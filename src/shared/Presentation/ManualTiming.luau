--!strict
-- How long Death's Manual is on screen when it takes a life, shared by the server (which times the
-- death) and the clients (which show it). A death by the Manual opens on the book, the victim's real
-- name and the cause written in it; only then does the body fall (Presenters/Death, DeathNoteService).

local ManualTiming = {}

ManualTiming.BOOK = 1.6 -- the book shot that opens the death cutscene
ManualTiming.HOLD = 5.5 + ManualTiming.BOOK -- the match loop waits this long after the death cue
ManualTiming.WRITE = 2.6 -- Diavolo's own shot of the name inking itself in (private)
ManualTiming.OUTRO = 3 -- the ending's page of every name written, when there is one
ManualTiming.DEATH_SLACK = 8 -- how long before the meeting's end the death (and its cutscene) still fits

-- When a name written now kills: `delay` seconds after writing, but always inside the meeting, with
-- the whole cutscene (book shot and all) before the meeting ends. remaining: seconds left of the
-- Death's Gambit phase; meeting: the meeting's length.
function ManualTiming.killDelay(delay: number, remaining: number, meeting: number): number
	local latest = remaining + math.max(4, meeting - (ManualTiming.DEATH_SLACK + ManualTiming.BOOK))
	return math.clamp(delay, remaining + 3, latest)
end

return ManualTiming
