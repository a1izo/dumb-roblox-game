--!strict
-- The collapse clip played for each public cause of death (Config.DEATH_CAUSES), and for each custom death bought in
-- the shop (Shared/Cosmetics kind "reason": its cause, written in the Manual, plays its own acting, "death" and its
-- style, art/scripts/deaths.py; the user's call of 2026-10-27, they had all played the heart attack). A cause with no
-- entry (the Oculus of the Dead's deal) plays as a heart attack.
--
-- A death style (Shared/Cosmetics kind "death") acts on the fallen body once its collapse is over (2026-11-07):
-- fallen<Style><Down|Up> (art/scripts/fallen.py), Down for a body lying face down, Up for one on its back. When each
-- moment comes is Shared/Anim/DeathTiming's.

local Cosmetics = require(script.Parent.Parent:WaitForChild("Cosmetics"))
local DeathTiming = require(script.Parent:WaitForChild("DeathTiming"))

local Causes = {}

Causes.CLIP = {
	["Heart attack"] = "collapseHeart",
	["Disease"] = "collapseDisease",
	["Accident"] = "collapseAccident",
} :: { [string]: string }

for _, item in ipairs(Cosmetics.ofKind("reason")) do
	local cause, style = item.cause, item.style
	if type(cause) == "string" and type(style) == "string" and style ~= "" then
		Causes.CLIP[cause] = "death" .. string.upper(string.sub(style, 1, 1)) .. string.sub(style, 2)
	end
end

function Causes.clipFor(cause: string?): string
	return Causes.CLIP[cause or ""] or Causes.CLIP["Heart attack"]
end

-- When things happen in a death's clip (DeathTiming.deaths): a heart attack's for a clip it does not know.
function Causes.timing(clip: string): DeathTiming.Timing
	return DeathTiming.deaths[clip] or DeathTiming.deaths.collapseHeart
end

local function capital(word: string): string
	return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
end

-- The clip a death style plays on a body lying `family` ("Down": face down, "Up": on its back), nil for a style with
-- none.
function Causes.fallenClip(style: string?, family: string): string?
	if type(style) ~= "string" or style == "" then
		return nil
	end
	local clip = "fallen" .. capital(style) .. family
	return if DeathTiming.fallen[clip] then clip else nil
end

-- How long a death style's clip runs (the same lying either way), 0 for a style with none.
function Causes.fallenLength(style: string?): number
	local clip = Causes.fallenClip(style, "Down")
	return if clip then DeathTiming.fallen[clip].length or 0 else 0
end

-- The moments of a death style's clip (DeathTiming.fallen), nil for none.
function Causes.moments(clip: string?): { [string]: number }?
	return if clip then DeathTiming.fallen[clip] else nil
end

return Causes
