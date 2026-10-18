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
			"Stare at someone up close (R), standing still, to learn their real name. Your eyes glow while you do.",
			"Write a learned name in {grimoire} (P) any time. The book burns red for a few seconds: make sure nobody sees.",
			"The victim dies 20 seconds later. You do not know your {cultists}: write one by mistake and they die too.",
		},
		"Match {agency} in number before they vote you out, arrest you or fill their task bar.",
		"Wander, find someone alone, and stare."
	),
	Follower = card(
		{
			"You know {hand}; they do not know you. Stare to learn real names (R) and pass them on a paper note.",
			"Sabotage: black out the map (Z), jam the stations near you (B), barricade the way (T).",
			"Accept {eyes} for fast reads from far away, but it kills you three minutes later.",
		},
		"{Circle} wins when it matches {agency} in number.",
		"Find {hand}, then pick up a blank sheet for your first name."
	),
	L = card({
		"You lead {agency} in secret. Only {butler} knows who you are.",
		"Once per match, during a meeting, arrest one player (K). A {cultist} or {hand} is removed.",
		"Arrest an innocent and they walk free while you die. Any arrest reveals that you are {zero}.",
	}, "Vote out or arrest {hand}, or fill the task bar.", "Work case files and watch for glowing eyes."),
	Watari = card(
		{
			"You know who {zero} is. {Zero} does not know you.",
			"If {zero} dies, you name the next {zero} within 30 seconds: anyone but yourself. They get a fresh arrest.",
			"Name someone from {circle} and their title is worthless, so choose carefully.",
		},
		"{Agency} wins when {hand} is voted out or arrested, or the task bar fills.",
		"Stay near {zero} and watch who stares at them."
	),
	TaskForce = card({
		"Work case files (E). Every one fills {agency}'s task bar; fill it and you win.",
		"Watch for glowing eyes (someone staring) and a burning red book ({hand} writing).",
		"Ring the bell to call a meeting. Real names of living players are blocked in every chat.",
	}, "Vote out {hand}, or fill the task bar, before {circle} takes over.", "Pick a station and keep your eyes open."),
}

return RoleCopy
