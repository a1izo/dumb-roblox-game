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
		line = "Every case file leaves your name in its station's log. Break in fast, or the alarm brings everyone running.",
	},
	{
		id = "writing",
		line = "{Hand} kills by writing a full real name in {grimoire}. The book burns red: someone may be watching.",
	},
	{
		id = "meeting",
		line = "A death calls the meeting. Talk it over, then vote: the most votes is out.",
	},
	{
		id = "warrant",
		line = "{Zero} may arrest one player in a meeting. Arrest the wrong one and {zero} pays with their life.",
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
