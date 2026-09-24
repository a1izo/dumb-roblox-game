-- Display data for roles. Only a player's own role is ever sent to their client.
-- Names come from Terms; the keys are the internal role ids and never change.

local Terms = require(script.Parent.Terms)

local Roles = {}

Roles.INFO = {
	Kira = {
		display = Terms.role("Kira", "title"),
		color = Color3.fromRGB(215, 35, 50),
		side = "Kira",
		blurb = Terms.f(
			"You hold {grimoire}. Each round you may write one full real name in it. Blend in, fake tasks, "
				.. "collect names from your {cultists} and never get caught."
		),
	},
	Follower = {
		display = Terms.role("Follower", "title"),
		color = Color3.fromRGB(235, 90, 70),
		side = "Kira",
		blurb = Terms.f(
			"You serve {hand}. Gather real names, pass them on paper notes, fake tasks, rig flashes and "
				.. "spread false leads. From round 2 one {cultist} may accept {eyes}."
		),
	},
	L = {
		display = Terms.role("L", "title"),
		color = Color3.fromRGB(240, 240, 240),
		side = "Team",
		blurb = Terms.f(
			"You lead {agency} in secret. Speak through the anonymous screen, read the tip box, "
				.. "watch the suspicion meter and arrest {hand} with one warrant and a full real name."
		),
	},
	Watari = {
		display = Terms.role("Watari", "title"),
		color = Color3.fromRGB(120, 180, 255),
		side = "Team",
		blurb = Terms.f(
			"You are {zero}'s assistant. Only {zero} knows who you are. Pass your letter hint to {zero} through "
				.. "the tip box. While you live, {zero} keeps the suspicion meter."
		),
	},
	TaskForce = {
		display = Terms.role("TaskForce", "title"),
		color = Color3.fromRGB(90, 160, 255),
		side = "Team",
		blurb = Terms.f(
			"Work the case files, watch the other players and vote {hand} out. Every task you finish leaks "
				.. "three letters of your real name to anyone watching."
		),
	},
}

function Roles.get(role: string)
	return Roles.INFO[role] or Roles.INFO.TaskForce
end

return Roles
