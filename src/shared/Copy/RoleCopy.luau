--!strict
-- What each role reads on its role card: three short bullets, how the role wins and a first
-- move. Keys are internal role ids; the text uses Terms placeholders.

local Terms = require(script.Parent.Parent.Terms)

export type RoleCopy = {
	bullets: { string },
	win: string,
	firstMove: string,
}

local function card(bullets: { string }, win: string, firstMove: string): RoleCopy
	local filled = {}
	for i, bullet in ipairs(bullets) do
		filled[i] = Terms.f(bullet)
	end
	return { bullets = filled, win = Terms.f(win), firstMove = Terms.f(firstMove) }
end

local RoleCopy: { [string]: RoleCopy } = {
	Kira = card(
		{
			"Hack a station ({key.use}) right after someone finishes a case file there: you read their real name. Miss a check and its alarm goes off.",
			"Write a learned name in {grimoire} ({key.manual}) any time. The book burns red for a few seconds: make sure nobody sees.",
			"The victim dies 20 seconds later. You do not know your {cultists}: write one by mistake and they die too.",
		},
		"Match {agency} in number before they vote you out, arrest you or fill their task bar.",
		"Follow someone to a station, and hack it when they leave."
	),
	Follower = card(
		{
			"You know {hand}; they do not know you. Hack stations for real names ({key.use}) and pass them on a paper note.",
			"Black out the lights ({key.blackout}): the map goes dark and name tags vanish, cover for a hack or a writing.",
			"Accept {eyes} to read names at a glance by staring ({key.stare}), but it kills you 90 seconds later.",
		},
		"{Circle} wins when it matches {agency} in number.",
		"Find {hand}, then pick up a blank sheet for your first name."
	),
	L = card({
		"You lead {agency} in secret. Only {butler} knows who you are.",
		"Once per match, during a meeting, arrest one player ({key.arrest}). A {cultist} or {hand} is removed.",
		"Arrest an innocent and they walk free while you die. Any arrest reveals that you are {zero}.",
	}, "Vote out or arrest {hand}, or fill the task bar.", "Work case files and watch for glowing eyes."),
	Watari = card(
		{
			"You know who {zero} is. {Zero} does not know you.",
			"If {zero} dies, you name the next {zero} within 30 seconds: anyone but yourself. They get a fresh arrest.",
			"Name someone from {circle} and their title is worthless, so choose carefully.",
		},
		"{Agency} wins when {hand} is voted out or arrested, or the task bar fills.",
		"Stay near {zero} and watch who hangs round the stations they use."
	),
	TaskForce = card({
		"Work case files ({key.use}). Every one fills {agency}'s task bar; fill it and you win.",
		"Every case file leaves your name on its station for a while. Run to an alarm: whoever is there was hacking.",
		"Ring the bell to call a meeting. Only a paper note can carry a real name.",
	}, "Vote out {hand}, or fill the task bar, before {circle} takes over.", "Pick a station and keep your eyes open."),
}

return RoleCopy
