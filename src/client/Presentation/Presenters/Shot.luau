-- A Blender cutscene played on its own (the debug panel's previews): the shot named in the cue, cast as
-- the server picked.

local ShotPlayer = require(script.Parent.Parent.ShotPlayer)

return function(cue)
	local data = cue.data or {}
	if type(data.shot) ~= "string" then
		return
	end
	ShotPlayer.play(data.shot, {
		at = cue.at,
		cast = if type(data.cast) == "table" then data.cast else {},
	})
end
