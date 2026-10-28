-- Display data for roles. Only a player's own role is ever sent to their client.
-- Names come from Terms; the keys are the internal role ids and never change.

local Terms = require(script.Parent.Terms)

local Roles = {}

Roles.INFO = {
	Kira = {
		display = Terms.role("Kira", "title"),
		color = Color3.fromRGB(215, 35, 50),
		side = "Kira",
		blurb = Terms.f("Hack stations to learn names, then write them in {grimoire}. Don't get seen."),
	},
	Follower = {
		display = Terms.role("Follower", "title"),
		color = Color3.fromRGB(235, 90, 70),
		side = "Kira",
		blurb = Terms.f("You know {hand}. Hack stations for names, pass them on notes, and cut the lights."),
	},
	L = {
		display = Terms.role("L", "title"),
		color = Color3.fromRGB(240, 240, 240),
		side = "Team",
		blurb = Terms.f("You lead {agency} in secret. Arrest one player in a meeting. Get it wrong and you die."),
	},
	Watari = {
		display = Terms.role("Watari", "title"),
		color = Color3.fromRGB(120, 180, 255),
		side = "Team",
		blurb = Terms.f("You know who {zero} is. If they die, you pick the next {zero}."),
	},
	TaskForce = {
		display = Terms.role("TaskForce", "title"),
		color = Color3.fromRGB(90, 160, 255),
		side = "Team",
		blurb = Terms.f("Work case files, watch for glowing eyes, and vote {hand} out."),
	},
}

function Roles.get(role: string)
	return Roles.INFO[role] or Roles.INFO.TaskForce
end

return Roles
