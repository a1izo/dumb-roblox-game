--!strict
-- The How to Play book, one chapter per page. The text uses Terms placeholders.

local Terms = require(script.Parent.Parent.Terms)

export type Chapter = { title: string, body: { string } }

local RAW: { { title: string, body: { string } } } = {
	{
		title = "The case",
		body = {
			"One player is {hand}, who kills by writing a player's real name in {grimoire}.",
			"Everyone else works for {agency}, led by {zero}, whose identity is secret.",
			"Every player has a public alias (like Raven) and a secret real name (like Mei Sato).",
		},
	},
	{
		title = "Real names",
		body = {
			"Your real name is on your role card. Hold C to see it again.",
			"Finishing a case file flashes 3 letters of your real name to anyone close enough to watch.",
			"{Hand} needs a full real name to kill. {Zero} needs one to arrest.",
		},
	},
	{
		title = "A round",
		body = {
			"Investigation: work case files, watch the stations, trade notes.",
			"{Grimoire} phase: {hand} may write a name. Everyone else files a private report.",
			"Meeting: free chat. The victim, if any, dies during the meeting.",
			"Vote: pick a suspect or skip. The player with the most votes is out.",
		},
	},
	{
		title = "Case files and evidence",
		body = {
			"Camera, fingerprint, phone and forensics stations each post a different kind of clue."
				.. " Every station has four puzzles; you get one at random.",
			Terms.f(
				"Forensics analyses the ink of the last deadly entry in {grimoire}: whose pen could have written it."
			),
			"Clues appear on the evidence board (B) and on the board in the meeting room.",
			"{Hand} and {cultists} can fake a task: no clue, no flash. A missing board entry can expose them.",
		},
	},
	{
		title = "Notes and drop points",
		body = {
			"Take a blank sheet, write up to 40 characters, then drop it or hide it at a drop point.",
			"If anyone from {agency} reads a note naming a living player, it is confiscated and that player gets a hood.",
			"{Hand} can burn a note, but the smoke makes everyone nearby look suspicious.",
		},
	},
	{
		title = "Hoods and {eyes}",
		body = {
			"From round 2 one {cultist} may accept {eyes}: up close, they can read real names.",
			"Their eyes glow red while reading, and they die soon after the deal.",
			"A hood blocks {eyes} for the round it is worn.",
		},
	},
	{
		title = "{Zero} and {butler}",
		body = {
			"{Zero} reads the tip box and reports at {zeroDesk} and speaks on the meeting screen.",
			"{Butler} knows one letter of {hand}'s real name and should get it to {zero}.",
			"During the vote {zero} can serve one warrant with a full real name. A wrong arrest loses the match.",
		},
	},
	{
		title = "Winning",
		body = {
			"{Agency} wins when {hand} is voted out or arrested.",
			"{Hand} wins by killing {zero}, by matching {agency} in number, or by surviving 5 rounds.",
		},
	},
}

local HowToPlay: { Chapter } = {}
for i, chapter in ipairs(RAW) do
	local body = {}
	for j, line in ipairs(chapter.body) do
		body[j] = Terms.f(line)
	end
	HowToPlay[i] = { title = Terms.f(chapter.title), body = body }
end

return HowToPlay
