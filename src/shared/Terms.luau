--!strict
-- Every name a player can read: the game, roles, sides, items and phases. Code writes
-- sentences with placeholders, e.g. Terms.f("{Hand} wins."), so renaming anything is a
-- change to this file only.
--
-- Internal ids never change: role ids ("Kira", "Follower", "L", "Watari", "TaskForce"),
-- side ids ("Kira", "Team"), the phase id "DeathNote", remote names, tags and DataStore keys.

local RunService = game:GetService("RunService")

local Terms = {}

Terms.GAME = "Inkbound"
Terms.TAGLINE = "Find the Hand.  Protect your real name."

export type RoleNames = {
	name: string, -- mid-sentence: "the Hand", "Cultist"
	Name: string, -- sentence start: "The Hand"
	title: string, -- headings: "THE HAND"
	a: string, -- with an article: "the Hand", "a Cultist", "an Agent"
	plural: string,
}

Terms.ROLE = {
	Kira = { name = "the Hand", Name = "The Hand", title = "THE HAND", a = "the Hand", plural = "Hands" },
	Follower = { name = "Cultist", Name = "Cultist", title = "CULTIST", a = "a Cultist", plural = "Cultists" },
	L = { name = "Zero", Name = "Zero", title = "ZERO", a = "Zero", plural = "Zeros" },
	Watari = { name = "the Butler", Name = "The Butler", title = "THE BUTLER", a = "the Butler", plural = "Butlers" },
	TaskForce = { name = "Agent", Name = "Agent", title = "AGENT", a = "an Agent", plural = "Agents" },
} :: { [string]: RoleNames }

Terms.SIDE = {
	Team = { name = "the Agency", Name = "The Agency", title = "THE AGENCY" },
	Kira = { name = "the Hand's circle", Name = "The Hand's circle", title = "THE HAND'S CIRCLE" },
}

-- Phase ids come from Config.PHASE_TIME plus "Lobby".
Terms.PHASE = {
	Lobby = "Lobby",
	Intro = "Case opening",
	Briefing = "Briefing",
	Investigation = "Investigation",
	DeathNote = "Grimoire phase",
	Meeting = "Agency meeting",
	Vote = "Vote",
	Verdict = "Verdict",
	Outro = "The end",
	Reveal = "Case closed",
}

Terms.STATUS = {
	alive = "Alive",
	dead = "Dead",
	voted = "Voted out",
	arrested = "Arrested",
	left = "Left",
}

-- Placeholders usable in Terms.f. Lower case = mid-sentence, capitalised = sentence start,
-- upper case = headings.
Terms.NAMES = {
	game = "Inkbound",
	GAME = "INKBOUND",

	hand = "the Hand",
	Hand = "The Hand",
	HAND = "THE HAND",
	cultist = "Cultist",
	Cultist = "Cultist",
	CULTIST = "CULTIST",
	cultists = "Cultists",
	Cultists = "Cultists",
	zero = "Zero",
	Zero = "Zero",
	ZERO = "ZERO",
	butler = "the Butler",
	Butler = "The Butler",
	BUTLER = "THE BUTLER",
	agent = "Agent",
	Agent = "Agent",
	AGENT = "AGENT",
	agents = "Agents",
	Agents = "Agents",
	agency = "the Agency",
	Agency = "The Agency",
	AGENCY = "THE AGENCY",
	circle = "the Hand's circle",
	Circle = "The Hand's circle",

	grimoire = "the Grimoire",
	Grimoire = "The Grimoire",
	GRIMOIRE = "THE GRIMOIRE",
	specter = "Specter",
	Specter = "Specter",
	SPECTER = "SPECTER",
	specters = "Specters",
	eyes = "Specter's Eyes",
	Eyes = "Specter's Eyes",
	EYES = "SPECTER'S EYES",
	zeroDesk = "Zero's desk",
	ZeroDesk = "Zero's desk",
	ZERO_DESK = "ZERO'S DESK",
	zeroScreen = "Zero's screen",
	ZeroScreen = "Zero's screen",
	ZERO_SCREEN = "ZERO'S SCREEN",
	meeting = "Agency meeting",
	Meeting = "Agency meeting",
	MEETING = "AGENCY MEETING",
	-- The single glyph that stands for Zero on screens and signs.
	zeroGlyph = "0",
}

local IS_STUDIO = RunService:IsStudio()

-- Fills {placeholders} from vars first, then from Terms.NAMES.
-- An unknown placeholder errors in Studio and is left as-is in live servers.
function Terms.f(template: string, vars: { [string]: any }?): string
	return (
		string.gsub(template, "{([%w_]+)}", function(key: string): string?
			if vars and vars[key] ~= nil then
				return tostring(vars[key])
			end
			local name = Terms.NAMES[key]
			if name then
				return name
			end
			if IS_STUDIO then
				error(string.format("Terms.f: unknown placeholder {%s} in %q", key, template), 2)
			end
			return nil
		end)
	)
end

-- A role's name in one of the RoleNames forms ("name" by default).
function Terms.role(roleId: string, form: string?): string
	local names = Terms.ROLE[roleId] or Terms.ROLE.TaskForce
	return (names :: any)[form or "name"]
end

-- A side's name ("Team" or "Kira") in the given form ("name" by default).
function Terms.side(sideId: string, form: string?): string
	local names = Terms.SIDE[sideId] or Terms.SIDE.Team
	return (names :: any)[form or "name"]
end

function Terms.phase(phaseId: string): string
	return Terms.PHASE[phaseId] or phaseId
end

function Terms.status(status: string): string
	return Terms.STATUS[status] or status
end

return Terms
