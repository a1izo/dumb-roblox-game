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
-- A scene death (Presentation/SceneDeaths): after its cutscene the camera stays this long on the body where it lies.
ManualTiming.SCENE_AFTER = 2.4

return ManualTiming
