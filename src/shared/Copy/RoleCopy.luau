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

-- (the owner, 2026-10-29: "just keep it simple": three short lines, no "how you win" on the card)
local RoleCopy: { [string]: RoleCopy } = {
	Kira = card(
		{ "Hack stations for names", "Kill with the Manual", "Victims die in 20 seconds" },
		"Match {agency} in number before they catch you.",
		"Follow someone to a station and hack it when they leave."
	),
	Follower = card(
		{ "You know {hand}", "Hack stations for names", "Cut the lights for cover" },
		"{Circle} wins when it matches {agency} in number.",
		"Find {hand} and grab a blank sheet."
	),
	L = card(
		{ "You lead {agency} in secret", "Arrest one player in a meeting", "A wrong arrest kills you" },
		"Remove {hand} or fill the task bar.",
		"Work case files and watch for glowing eyes."
	),
	Watari = card(
		{ "You know who {zero} is", "Keep {zero} alive", "If {zero} dies, pick the next" },
		"Remove {hand} or fill the task bar.",
		"Stay near {zero}."
	),
	TaskForce = card(
		{ "Work case files", "Watch for glowing eyes", "Vote {hand} out" },
		"Remove {hand} or fill the task bar.",
		"Pick a station and keep watch."
	),
}

return RoleCopy
