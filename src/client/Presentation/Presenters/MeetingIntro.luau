-- The meeting intro: the survivors arrive at the war room (the MeetingIntro shot,
-- art/scripts/cinema/shots/meeting_intro.py). Each "seat:k" part is the player standing at place k,
-- so the montage ends where the meeting begins.

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ShotPlayer = require(script.Parent.Parent.ShotPlayer)

return function(cue)
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	ShotPlayer.play("MeetingIntro", {
		at = cue.at,
		cast = if type(cue.data.cast) == "table" then cue.data.cast else {},
	})
end
