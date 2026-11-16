--!strict
-- How long Ace's verdict plays (client Presentation/Verdicts: a full-screen insert since 2026-11-16), shared by the
-- server, which holds the match that long after the arrest's own shot (ArrestService) and gives the ending its last
-- beat (RoundService's plan), and the clients, which play it.

local VerdictTiming = {}

VerdictTiming.LENGTH = 3.4 -- seconds of the insert
VerdictTiming.ARREST = 2.6 -- the arrest's own shot before it (Presenters/Arrest)

return VerdictTiming
