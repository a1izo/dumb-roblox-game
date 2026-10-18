-- Bureau HQ's mechanic. Its old main breaker is gone: the Muerto's blackout sabotage
-- (SabotageService) now darkens every map, this one included (Client/World/Blackout keeps the HQ's
-- emergency lamps and dead ceiling panels for it). Nothing of its own runs here any more.

local TaskForceHQ = {}

function TaskForceHQ.start(_ctx) end

function TaskForceHQ.stop() end

return TaskForceHQ
