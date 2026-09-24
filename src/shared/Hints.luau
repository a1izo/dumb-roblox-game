--!strict
-- One-time hints for new players. Each shows once per profile (saved in tipsSeen) and never
-- mentions anyone else's hidden state. The client decides when each one triggers; the
-- server only accepts ids from this list.

local Terms = require(script.Parent.Terms)

export type Hint = { id: string, title: string, text: string }

local RAW: { { string } } = {
	-- { id, title, text }
	{
		"role_Kira", -- terms:ok (internal role id)
		"You are {hand}",
		"Collect real names by watching case files, then write one in {grimoire} each round. Hold C to see your card again.",
	},
	{
		"role_Follower",
		"You are a {cultist}",
		"You know {hand}. Gather real names for them, rig flashes (hold T) and file false reports.",
	},
	{
		"role_L",
		"You are {zero}",
		"Nobody knows it is you. Read tips at your desk (Z) and serve one warrant during a vote.",
	},
	{
		"role_Watari", -- terms:ok (internal role id)
		"You are {butler}",
		"Your role card holds one letter of {hand}'s real name. Get it to {zero} through the tip box.",
	},
	{
		"role_TaskForce",
		"You are an {agent}",
		"Work case files, watch the stations and vote {hand} out. Hold C to see your role card again.",
	},
	{
		"phase_Investigation",
		"Investigation",
		"Press E at a station to work a case file. Each finished file posts a clue and flashes 3 letters of the worker's real name to anyone close.",
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
		"Clues land on the evidence board (B). A player who worked but posted nothing may have faked it.",
	},
	{
		"sheet",
		"Blank sheets",
		"Take a sheet to write a secret note. Drop it, or hide it at a loose grate for someone else.",
	},
	{ "dropPoint", "Loose grates", "Hidden notes wait here. Search it (E) or hide the note you carry (hold F)." },
	{ "hood", "Hoods", "A hood blocks {eyes} for the rest of the round. Everyone can see you wear it." },
	{
		"death",
		"Someone died",
		"Their name was written in {grimoire} during the last phase. Who could have learned it?",
	},
	{ "eliminated", "You are out", "You can still watch. Stay until the end to see every role and real name." },
	{
		"scratchpad",
		"Your notes",
		"Press V to open a private notepad. Only you can see it, and it clears when the match ends.",
	},
}

local Hints = {}

Hints.LIST = {} :: { Hint }
Hints.BY_ID = {} :: { [string]: Hint }

for _, row in ipairs(RAW) do
	local hint = { id = row[1], title = Terms.f(row[2]), text = Terms.f(row[3]) }
	table.insert(Hints.LIST, hint)
	Hints.BY_ID[hint.id] = hint
end

return Hints
