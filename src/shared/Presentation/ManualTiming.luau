--!strict
-- How long Death's Manual is on screen when it takes a life, shared by the server (which times the
-- death) and the clients (which show it). A death by the Manual opens on the book, the victim's real
-- name and the cause written in it; only then does the body fall (Presenters/Death, DeathNoteService).

local ManualTiming = {}

ManualTiming.BOOK = 2.8 -- the book shot that opens the death cutscene (a sentence written in it: DeathLines)
ManualTiming.HOLD = 5.5 + ManualTiming.BOOK -- the match loop waits this long after the death cue
ManualTiming.WRITE = 2.6 -- Diavolo's own shot of the name inking itself in (private)
ManualTiming.OUTRO = 3 -- the ending's page of every name written, when there is one
-- A death style's body (Presentation/Fallen): it lies still this long after its collapse ends (the witnesses' faces
-- are shown meanwhile) before the style takes it.
ManualTiming.STYLE_AFTER = 1.2
-- "A true patriot" (a custom death): its grave scene (Shared/Cinema/DeathCuts "patriot_grave") starts this long after
-- the death's own shots are over, at least HOLD - BOOK after the body began to fall, on every screen at once.
ManualTiming.GRAVE_GAP = 0.3
ManualTiming.GRAVE = "patriot_grave"

return ManualTiming
