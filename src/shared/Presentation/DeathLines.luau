--!strict
-- What Death's Manual says happened, written in it as a death opens (the user's ask of 2026-11-08): the victim's name
-- and how they died in one sentence ("John Doe met their fate by Walrider."), a line of its own for every custom death
-- (Shared/Cosmetics kind "reason", its `line`) and for the three plain causes. Presentation/BookStage writes it with
-- the words scattered a little, as a hand writes.
--
--   DeathLines.sentence("John Doe", "Walrider") --> "John Doe met their fate by Walrider."

local Cosmetics = require(script.Parent.Parent:WaitForChild("Cosmetics"))

local DeathLines = {}

local PLAIN: { [string]: string } = {
	["Heart attack"] = "{name} died of a heart attack.",
	["Disease"] = "{name} died of a sudden illness.",
	["Accident"] = "{name} died in a stupid accident.",
}

-- The sentence for `name` dying of `cause` (a custom death's own line, a plain cause's, or "{name} died: cause").
function DeathLines.sentence(name: string, cause: string?): string
	local item = Cosmetics.reasonByCause(cause)
	local template = if item and type(item.line) == "string"
		then item.line
		else PLAIN[cause or ""] or ("{name} died: " .. tostring(cause or "unknown") .. ".")
	return (string.gsub(template, "{name}", function()
		return name
	end))
end

return DeathLines
