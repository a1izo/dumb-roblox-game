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
			"You hold {grimoire}. Hack stations to read who used them last, then write a real name in the "
				.. "book. Writing takes a few seconds and the book burns red: never let anyone see it. You do not "
				.. "know your {cultists}."
		),
	},
	Follower = {
		display = Terms.role("Follower", "title"),
		color = Color3.fromRGB(235, 90, 70),
		side = "Kira",
		blurb = Terms.f(
			"You know {hand}; nobody knows you. Hack stations for real names and pass them to {hand} on paper "
				.. "notes. Black out the lights, jam stations and barricade the way. You may accept {eyes}."
		),
	},
	L = {
		display = Terms.role("L", "title"),
		color = Color3.fromRGB(240, 240, 240),
		side = "Team",
		blurb = Terms.f(
			"You lead {agency} in secret: only {butler} knows it is you. In a meeting you may arrest one "
				.. "player. {Circle} goes; an innocent walks free and you die. The arrest reveals you."
		),
	},
	Watari = {
		display = Terms.role("Watari", "title"),
		color = Color3.fromRGB(120, 180, 255),
		side = "Team",
		blurb = Terms.f(
			"You know who {zero} is; {zero} does not know you. If {zero} dies, you name the next {zero} (anyone "
				.. "but yourself). Choose well: a {cultist} would get a worthless title."
		),
	},
	TaskForce = {
		display = Terms.role("TaskForce", "title"),
		color = Color3.fromRGB(90, 160, 255),
		side = "Team",
		blurb = Terms.f(
			"Work the case files to fill {agency}'s task bar, watch for glowing eyes and a burning red book, "
				.. "and vote {hand} out. Ring the bell if you saw something."
		),
	},
}

function Roles.get(role: string)
	return Roles.INFO[role] or Roles.INFO.TaskForce
end

return Roles
