-- Display data for roles. Only a player's own role is ever sent to their client.

local Roles = {}

Roles.INFO = {
	Kira = {
		display = "KIRA",
		color = Color3.fromRGB(215, 35, 50),
		side = "Kira",
		blurb = "You own the Death Note. Each round you may write one full real name. Blend in, fake tasks, "
			.. "collect names from your followers and never get caught.",
	},
	Follower = {
		display = "KIRA FOLLOWER",
		color = Color3.fromRGB(235, 90, 70),
		side = "Kira",
		blurb = "You serve Kira. Gather real names, pass them on paper notes, fake tasks, rig flashes and "
			.. "spread false leads. From round 2 one follower may take the shinigami eyes deal.",
	},
	L = {
		display = "L",
		color = Color3.fromRGB(240, 240, 240),
		side = "Team",
		blurb = "You lead the investigation in secret. Speak through the anonymous screen, read the tip box, "
			.. "watch the suspicion meter and arrest Kira with one warrant and a full real name.",
	},
	Watari = {
		display = "WATARI",
		color = Color3.fromRGB(120, 180, 255),
		side = "Team",
		blurb = "You are L's assistant. Only L knows who you are. Pass your letter hint to L through the tip "
			.. "box. While you live, L keeps the suspicion meter.",
	},
	TaskForce = {
		display = "TASK FORCE",
		color = Color3.fromRGB(90, 160, 255),
		side = "Team",
		blurb = "Work the case files, watch the other players and vote Kira out. Every task you finish leaks "
			.. "three letters of your real name to anyone watching.",
	},
}

function Roles.get(role: string)
	return Roles.INFO[role] or Roles.INFO.TaskForce
end

return Roles
