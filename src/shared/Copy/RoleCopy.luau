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
	Kira = card({
		"Hack a station ({key.use}) after someone uses it to learn their real name.",
		"Write names in {grimoire} ({key.manual}). The book glows red, so don't get seen.",
		"Victims die 20 seconds later. You don't know your {cultists}, so be careful.",
	}, "Match {agency} in number before they catch you.", "Follow someone to a station and hack it when they leave."),
	Follower = card({
		"You know {hand}. They don't know you. Hack stations for names ({key.use}) and pass them on notes.",
		"Cut the lights ({key.blackout}) to hide name tags.",
		"Take {eyes} to read names by staring ({key.stare}). You die 90 seconds later.",
	}, "{Circle} wins when it matches {agency} in number.", "Find {hand} and grab a blank sheet."),
	L = card({
		"You lead {agency} in secret. Only {butler} knows.",
		"Arrest one player per match during a meeting ({key.arrest}).",
		"Arrest an innocent and you die. Arresting reveals you.",
	}, "Remove {hand} or fill the task bar.", "Work case files and watch for glowing eyes."),
	Watari = card({
		"You know who {zero} is. They don't know you.",
		"If {zero} dies, you have 30 seconds to pick the next one.",
		"Pick someone from {circle} and their arrest won't work.",
	}, "Remove {hand} or fill the task bar.", "Stay near {zero}."),
	TaskForce = card({
		"Work case files ({key.use}) to fill the task bar.",
		"Hear an alarm? Whoever is there was hacking.",
		"Ring the bell to call a meeting.",
	}, "Remove {hand} or fill the task bar.", "Pick a station and keep watch."),
}

return RoleCopy
