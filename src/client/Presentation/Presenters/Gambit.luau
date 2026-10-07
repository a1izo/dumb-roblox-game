-- The Death's Gambit opener: the bell, the lamp, a suit sleeve writing in a plain notebook (the
-- GambitOpener shot, art/scripts/cinema/shots/gambit.py), with the phase's name. Everyone sees it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Cinema = require(script.Parent.Parent.Cinema)
local ShotPlayer = require(script.Parent.Parent.ShotPlayer)

return function(cue)
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	local round = tonumber(cue.data.round)
	ShotPlayer.play("GambitOpener", {
		at = cue.at,
		onCard = function(key)
			if key ~= "gambit" then
				return nil
			end
			return Cinema.card({
				kicker = if round then "Round " .. round else nil,
				title = Terms.phase("DeathNote"),
				subtitle = "Write a name. Or watch.",
				typewriter = true,
				y = 0.72,
			})
		end,
	})
end
