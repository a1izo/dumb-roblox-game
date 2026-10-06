--!strict
-- The collapse clip played for each public cause of death (Config.DEATH_CAUSES). A cause with no
-- entry (the Oculus of the Dead's deal) plays as a heart attack.

local Causes = {}

Causes.CLIP = {
	["Heart attack"] = "collapseHeart",
	["Disease"] = "collapseDisease",
	["Accident"] = "collapseAccident",
} :: { [string]: string }

function Causes.clipFor(cause: string?): string
	return Causes.CLIP[cause or ""] or Causes.CLIP["Heart attack"]
end

return Causes
