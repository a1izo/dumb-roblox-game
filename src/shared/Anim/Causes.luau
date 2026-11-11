--!strict
-- The collapse clip played for each public cause of death (Config.DEATH_CAUSES), and for each custom death bought in
-- the shop (Shared/Cosmetics kind "reason": its cause, written in the Manual, plays its own acting, "death" and its
-- style, art/scripts/deaths.py; the user's call of 2026-10-27, they had all played the heart attack). A cause with no
-- entry (the Oculus of the Dead's deal) plays as a heart attack.
--

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
	if type(cause) == "string" and type(item.scene) == "number" then
		-- (a scene death: everyone watches its cutscene, Presentation/SceneDeaths; the body itself just falls)
		Causes.CLIP[cause] = "collapseHeart"
	elseif type(cause) == "string" and type(style) == "string" and style ~= "" then
		Causes.CLIP[cause] = "death" .. string.upper(string.sub(style, 1, 1)) .. string.sub(style, 2)
	end
end

function Causes.clipFor(cause: string?): string
	return Causes.CLIP[cause or ""] or Causes.CLIP["Heart attack"]
end

-- How long a scene death's cutscene runs (Shared/Cosmetics `scene`), 0 for a cause without one.
function Causes.sceneLength(cause: string?): number
	local item = Cosmetics.reasonByCause(cause)
	return if item and type(item.scene) == "number" then item.scene else 0
end

-- The scene a cause plays (its custom death's style) when it has one.
function Causes.scene(cause: string?): string?
	local item = Cosmetics.reasonByCause(cause)
	return if item and type(item.scene) == "number" then item.style else nil
end

-- When things happen in a death's clip (DeathTiming.deaths): a heart attack's for a clip it does not know.
function Causes.timing(clip: string): DeathTiming.Timing
	return DeathTiming.deaths[clip] or DeathTiming.deaths.collapseHeart
end

return Causes
