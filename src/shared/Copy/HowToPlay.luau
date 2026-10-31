--!strict
-- The How to Play book, one chapter per page. The text uses Terms placeholders.

local Terms = require(script.Parent.Parent.Terms)

export type Chapter = { title: string, body: { string } }

local RAW: { { title: string, body: { string } } } = {
	{
		title = "The case",
		body = {
			"One player is {hand}. They kill by writing real names in {grimoire}.",
			"{Cultists} help {hand} in secret. Everyone else is {agency}, led by a secret {zero}.",
			"Everyone has a public alias and a secret real name.",
		},
	},
	{
		title = "Real names",
		body = {
			"Your real name is on your role card ({key.card}).",
			"{Hand} and {cultists} hack stations to see who used them in the last 25 seconds. Fail a hack and the alarm goes off.",
			"Chat only reaches players right next to you, as a bubble over your head. Real names are blocked: share them on paper notes.",
		},
	},
	{
		title = "Free roam",
		body = {
			"Work case files, watch each other, pass notes.",
			"{Hand} can write in {grimoire} any time, but the book glows red while open.",
			"Victims die 20 seconds later. Every death calls a meeting.",
			"In a meeting the whole table hears you.",
		},
	},
	{
		title = "Meetings",
		body = {
			"Meetings start on a death, a bell ring, or after three quiet minutes.",
			"Talk, then vote or skip. Ties remove nobody.",
		},
	},
	{
		title = "Case files",
		body = {
			"Each station gives you a random puzzle.",
			"Every case file fills the task bar. Fill it and {agency} wins.",
			"{Hand} and {cultists} can't work case files.",
		},
	},
	{
		title = "Notes",
		body = {
			"Grab a blank sheet, write up to 40 characters, and hand it over ({key.pass}).",
			"Anyone watching sees the note change hands.",
			"{Hand} can burn notes, but the smoke is easy to spot.",
		},
	},
	{
		title = "{Cultists} and {eyes}",
		body = {
			"{Cultists} know {hand}. {Hand} doesn't know them.",
			"{Cultists} can cut the lights and hide name tags.",
			"A {cultist} can take {eyes} to read names by staring, then dies 90 seconds later.",
		},
	},
	{
		title = "{Zero} and {butler}",
		body = {
			"{Zero} can arrest one player per match, during a meeting. Arrest an innocent and {zero} dies.",
			"Arresting reveals {zero}.",
			"{Butler} knows {zero}. If {zero} dies, {butler} picks the next one.",
		},
	},
	{
		title = "Winning",
		body = {
			"{Agency} wins by removing {hand} or filling the task bar.",
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
