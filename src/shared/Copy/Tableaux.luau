--!strict
-- The five tableaux round the lobby's plaza: stone figures acting out how a case goes. Each has one line,
-- shown on the screen of whoever stands in front of it (never written in the world). The text uses Terms
-- placeholders. In the order they stand, clockwise from the terrace's steps.

local Terms = require(script.Parent.Parent.Terms)

export type Tableau = { id: string, line: string }

local RAW: { { id: string, line: string } } = {
	{
		id = "name",
		line = "Everyone uses an alias. Keep your real name to yourself.",
	},
	{
		id = "leak",
		line = "Every station logs who used it. Hack it fast or the alarm goes off.",
	},
	{
		id = "writing",
		line = "{Hand} kills by writing real names in {grimoire}.",
	},
	{
		id = "meeting",
		line = "A death calls a meeting. Talk, then vote.",
	},
	{
		id = "warrant",
		line = "{Zero} can arrest one player. A wrong arrest is fatal.",
	},
}

local Tableaux = {}

Tableaux.LIST = {} :: { Tableau }
for _, raw in ipairs(RAW) do
	table.insert(Tableaux.LIST, { id = raw.id, line = Terms.f(raw.line) })
end

-- The tableau standing on the nth base (nil past the last).
function Tableaux.get(index: number): Tableau?
	return Tableaux.LIST[index]
end

return Tableaux
