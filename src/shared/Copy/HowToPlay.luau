--!strict
-- The How to Play book, one chapter per page. The text uses Terms placeholders.

local Terms = require(script.Parent.Parent.Terms)

export type Chapter = { title: string, body: { string } }

local RAW: { { title: string, body: { string } } } = {
	{
		title = "The case",
		body = {
			"One player is {hand}, who kills by writing a player's real name in {grimoire}.",
			"{Cultists} help {hand} in secret. Everyone else works for {agency}, led by {zero}, whose identity is secret.",
			"Every player has a public alias (like Raven) and a secret real name (like Mei Sato).",
		},
	},
	{
		title = "Real names",
		body = {
			"Your real name is on your role card. {key.card} to see it again.",
			"{Hand} and {cultists} learn real names by hacking a station: it shows who finished a case file there in the last 25 seconds. A hack looks like work, but a missed check sets off the station's alarm for everyone.",
			"There is no typing in a case, only quick-chat phrases. Only a paper note can carry a real name.",
		},
	},
	{
		title = "Free roam",
		body = {
			"Work case files, watch each other, pass notes. Anything can happen at any time.",
			"{Hand} can write in {grimoire} whenever he likes, but the book burns red for a few seconds: whoever sees it knows.",
			"A written victim dies 20 seconds later. Every death calls a meeting.",
			"Quick-chat phrases only reach players close to you.",
		},
	},
	{
		title = "Meetings",
		body = {
			"A meeting starts when someone dies, when someone rings the bell (once each per match), or after three quiet minutes.",
			"Talk it over, then vote: pick a suspect or skip. A tie or a skip removes nobody.",
		},
	},
	{
		title = "Case files",
		body = {
			"Camera, fingerprint, phone and forensics stations each have four puzzles; you get one at random.",
			"Every case file done fills {agency}'s task bar. Fill it and {agency} wins.",
			"{Hand} and {cultists} cannot work case files. Bureau {specters} still can.",
		},
	},
	{
		title = "Notes",
		body = {
			"Take a blank sheet, write up to 40 characters, then drop it or hand it to someone close by ({key.pass}).",
			"A handed note can be taken or left. Anyone watching sees the paper change hands.",
			"{Hand} can burn a note; the smoke is easy to spot.",
		},
	},
	{
		title = "{Cultists} and {eyes}",
		body = {
			"A {cultist} knows {hand}, but {hand} does not know them.",
			"{Cultists} sabotage: a blackout, jammed stations, or a barricade across the way.",
			"A {cultist} may accept {eyes}: stare at anyone to read their name at a glance, eyes blazing, and die 90 seconds later.",
		},
	},
	{
		title = "{Zero} and {butler}",
		body = {
			"Once per match, during a meeting, {zero} can arrest one player. {Circle} is removed; an innocent costs {zero} their life.",
			"Any arrest reveals who {zero} is.",
			"{Butler} knows {zero}. If {zero} dies, {butler} names the next one, who gets a fresh arrest.",
		},
	},
	{
		title = "Winning",
		body = {
			"{Agency} wins when {hand} is voted out or arrested, or when the task bar is full.",
			"{Circle} wins by matching {agency} in number.",
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
