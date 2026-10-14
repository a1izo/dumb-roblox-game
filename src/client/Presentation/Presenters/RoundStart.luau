-- Back to the round: a dip to black, "Round N of M" on it, and the screen comes back up on the map,
-- everyone already at their starting places (the server moves them while it is black).

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Cinema = require(script.Parent.Parent.Cinema)

local COVER, HOLD, UNCOVER = 0.45, 1.5, 0.55

return function(cue)
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	Cinema.waitUntil(cue.at)
	local round, rounds = tonumber(cue.data.round) or 1, tonumber(cue.data.rounds) or 1
	Cinema.blackout(COVER, HOLD, UNCOVER, function()
		return Cinema.card({
			kicker = "Investigation",
			title = string.format("Round %d of %d", round, rounds),
			typewriter = true,
			y = 0.5,
		})
	end)
end
