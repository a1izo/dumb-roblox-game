--!strict
-- The interface's sounds. Every call is safe before the sounds are uploaded (an empty slot in Assets.sfx
-- plays nothing), and repeated sounds are spaced out so a fast mouse does not machine-gun the hover tick.
--
--   UiSound.play("uiClick")        click, hover ("uiHover"), open ("uiOpen"), tab / pick ("select"),
--                                  hold tick ("holdTick"), toast ("toast"), coin ("coin"), slam ("slam"),
--                                  glitch ("glitch"), stamp ("stamp"), error ("error")

local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local UiSound = {}

local GAPS: { [string]: number } = { uiHover = 0.07, glitch = 0.4, holdTick = 0.1, select = 0.05 }
local last: { [string]: number } = {}

function UiSound.play(key: string)
	local now = os.clock()
	local gap = GAPS[key] or 0.02
	if last[key] and now - last[key] < gap then
		return
	end
	last[key] = now
	Sfx.play(key, { group = "Ui" })
end

return UiSound
