--!strict
-- The five tableaux round the lobby's plaza: stone figures acting out how a case goes. Each has one line,
-- shown on the screen of whoever stands in front of it (never written in the world). The text uses Terms
-- placeholders. In the order they stand, clockwise from the terrace's steps.

local Terms = require(script.Parent.Parent.Terms)

export type Tableau = { id: string, line: string }

local RAW: { { id: string, line: string } } = {
	{
		id = "name",
		line = "Everyone here goes by an alias. Your real name is on your role card: keep it to yourself.",
	},
	{
		id = "leak",
		line = "Finish a case file, and three letters of your real name show to anyone standing close.",
	},
	{
		id = "writing",
		line = "{Hand} kills by writing a full real name in {grimoire}. Half a name is no use.",
	},
	{
		id = "meeting",
		line = "The dead are found at the meeting. Talk it over, then vote: the most votes is out.",
	},
	{
		id = "warrant",
		line = "{Zero} may serve one warrant, with a full real name. Arrest the wrong one and the case is lost.",
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
