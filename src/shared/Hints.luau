--!strict
-- One-time hints for new players. Each shows once per profile (saved in tipsSeen) and never
-- mentions anyone else's hidden state. The client decides when each one triggers; the
-- server only accepts ids from this list.
--
-- A text names what to press as {key.<name>}: Hints.resolve fills it in for the input the player is
-- using (keyboard, gamepad or touch), so a phone is never told to press a key it does not have.

local Terms = require(script.Parent.Terms)

export type Hint = { id: string, title: string, text: string }

local RAW: { { string } } = {
	-- { id, title, text }
	{
		"role_Kira", -- terms:ok (internal role id)
		"You are {hand}",
		"Collect real names by watching case files, then write one in {grimoire} each round. {key.card} to see your card again.",
	},
	{
		"role_Follower",
		"You are a {cultist}",
		"You know {hand}. Gather real names for them, rig flashes ({key.rig}) and file false reports.",
	},
	{
		"role_L",
		"You are {zero}",
		"Nobody knows it is you. Read tips at your desk ({key.desk}) and serve one warrant during a vote.",
	},
	{
		"role_Watari", -- terms:ok (internal role id)
		"You are {butler}",
		"Your role card holds one letter of {hand}'s real name. Get it to {zero} through the tip box.",
	},
	{
		"role_TaskForce",
		"You are an {agent}",
		"Work case files, watch the stations and vote {hand} out. {key.card} to see your role card again.",
	},
	{
		"phase_Investigation",
		"Investigation",
		"{key.work} at a station to work a case file. Each finished file posts a clue and flashes 3 letters of the worker's real name to anyone close.",
	},
	{
		"phase_DeathNote",
		"{Grimoire} phase",
		"Everyone gets a private screen at once, so nobody can tell who is writing. File your report or write your name.",
	},
	{ "phase_Meeting", "Meeting", "Free chat is open. A player written in {grimoire} dies during this meeting." },
	{
		"phase_Vote",
		"Vote",
		"Pick a suspect or skip. Nobody sees who you voted for, and removed players' roles stay secret.",
	},
	{
		"flash",
		"Letters flashed!",
		"Those letters belong to the worker's real name. Remember them: {hand} needs full names to kill.",
	},
	{
		"evidence",
		"New evidence",
		"Clues land on the evidence board ({key.board}). A player who worked but posted nothing may have faked it.",
	},
	{
		"sheet",
		"Blank sheets",
		"Take a sheet to write a secret note. Drop it, or hand it to someone standing close ({key.pass}).",
	},
	{
		"pass",
		"Passing notes",
		"Stand close to someone and {key.passDo} to offer your note. Anyone watching sees it change hands.",
	},
	{ "offer", "A note for you", "Take it ({key.pass}) or leave it. A note handed to you is never confiscated." },
	{ "hood", "Hoods", "A hood blocks {eyes} for the rest of the round. Everyone can see you wear it." },
	{
		"death",
		"Someone died",
		"Their name was written in {grimoire} during the last phase. Who could have learned it?",
	},
	{
		"eliminated",
		"You are a {Specter}",
		"Fly with {key.fly}. The living cannot see or hear you. Gather lost souls for coins and chat with other {specters}.",
	},
	{
		"scratchpad",
		"Your notes",
		"{key.pad} to open a private notepad. Only you can see it, and it clears when the match ends.",
	},
}

local Hints = {}

-- What each {key.<name>} reads as, by input.
Hints.KEYS = {
	keyboard = {
		card = "Hold C",
		rig = "hold T",
		desk = "Z",
		work = "Press E",
		board = "B",
		pass = "X",
		passDo = "press X",
		pad = "Press V",
		fly = "WASD, Space (up) and Ctrl (down)",
	},
	gamepad = {
		card = "Hold LB",
		rig = "hold B",
		desk = "LT",
		work = "Press X",
		board = "D-pad up",
		pass = "LB",
		passDo = "press LB",
		pad = "Press RT",
		fly = "the left stick, A (up) and LT (down)",
	},
	touch = {
		card = "Press and hold your role badge",
		rig = "hold its prompt",
		desk = "its button on the right",
		work = "Tap the prompt",
		board = "the Evidence button",
		pass = "tap its prompt",
		passDo = "tap the prompt",
		pad = "Tap Scratchpad",
		fly = "the stick and the Up and Down buttons",
	},
} :: { [string]: { [string]: string } }

-- A hint's text with every {key.<name>} filled in for `input` ("keyboard", "gamepad" or "touch").
function Hints.resolve(text: string, input: string): string
	local keys = Hints.KEYS[input] or Hints.KEYS.keyboard
	return (string.gsub(text, "{key%.(%a+)}", function(name: string): string?
		return keys[name]
	end))
end

Hints.LIST = {} :: { Hint }
Hints.BY_ID = {} :: { [string]: Hint }

for _, row in ipairs(RAW) do
	local hint = { id = row[1], title = Terms.f(row[2]), text = Terms.f(row[3]) }
	table.insert(Hints.LIST, hint)
	Hints.BY_ID[hint.id] = hint
end

return Hints
