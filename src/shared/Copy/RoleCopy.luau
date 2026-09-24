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
			"Each {grimoire} phase, write one full real name. That player dies during the next meeting.",
			"Real names leak 3 letters at a time whenever someone finishes a case file. Watch the flashes.",
			"Fake tasks and blend in. Your {cultists} can pass you names on paper notes.",
		},
		"Kill {zero}, match {agency} in number, or survive all 5 rounds.",
		"Stand near a busy station and watch whose letters flash."
	),
	Follower = card(
		{
			"You know who {hand} is. Gather real names and pass them on paper notes or drop points.",
			"Fake tasks, rig a station's next flash (hold T) and file false reports to frame others.",
			"From round 2, one {cultist} may accept {eyes}: read real names up close, then die soon after.",
		},
		"{Hand} wins if {zero} dies, if your side matches {agency} in number, or after 5 rounds.",
		"Check your allies on the role card, then look busy at a station."
	),
	L = card(
		{
			"You lead {agency} in secret. During meetings you speak through the anonymous screen.",
			"Read tips and reports at {zeroDesk} (Z). The suspicion meter shows who others suspect.",
			"Once per match, during the vote, arrest a player with their full real name. Arresting an innocent loses the match.",
		},
		"Vote out or arrest {hand}. If {hand} writes your real name, you lose.",
		"Open {zeroDesk} (Z) between rounds and read the tips."
	),
	Watari = card({
		"Only {zero} knows who you are. You do not know who {zero} is.",
		"Your hint is one letter of {hand}'s real name. Send it to {zero} through the tip box.",
		"While you live, {zero} keeps the suspicion meter.",
	}, "{Agency} wins when {hand} is voted out or arrested.", "Drop your hint in the tip box early."),
	TaskForce = card({
		"Work case files. Each one posts a clue on the evidence board (B).",
		"Finishing a task flashes 3 letters of your real name to anyone watching. Choose your moments.",
		"Talk it through in meetings, then vote. Real names of living players are blocked in chat.",
	}, "Vote out {hand} before {circle} takes over.", "Work a case file, then check the evidence board."),
}

return RoleCopy
