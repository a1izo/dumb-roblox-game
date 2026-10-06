--!strict
-- Every name a player can read: the game, roles, sides, items and phases. Code writes
-- sentences with placeholders, e.g. Terms.f("{Hand} wins."), so renaming anything is a
-- change to this file only. The placeholder keys keep their original spelling ({Hand} is
-- Diavolo, {zero} is Ace, {grimoire} is Death's Manual...); only the words they print change.
--
-- Internal ids never change: role ids ("Kira", "Follower", "L", "Watari", "TaskForce"),
-- side ids ("Kira", "Team"), the phase id "DeathNote", remote names, tags and DataStore keys.

local RunService = game:GetService("RunService")

local Terms = {}

Terms.GAME = "Death's Gambit"
Terms.TAGLINE = "Sfuggi al destino che Diavolo ha scelto per te"

export type RoleNames = {
	name: string, -- mid-sentence: "Diavolo", "Muerto"
	Name: string, -- sentence start: "Diavolo", "Muerto"
	title: string, -- headings: "DIAVOLO"
	a: string, -- with an article: "Diavolo", "a Muerto", "an Operative"
	plural: string,
}

Terms.ROLE = {
	Kira = { name = "Diavolo", Name = "Diavolo", title = "DIAVOLO", a = "Diavolo", plural = "Diavolos" },
	Follower = { name = "Muerto", Name = "Muerto", title = "MUERTO", a = "a Muerto", plural = "Muertos" },
	L = { name = "Ace", Name = "Ace", title = "ACE", a = "Ace", plural = "Aces" },
	Watari = { name = "the Butler", Name = "The Butler", title = "THE BUTLER", a = "the Butler", plural = "Butlers" },
	TaskForce = {
		name = "Operative",
		Name = "Operative",
		title = "OPERATIVE",
		a = "an Operative",
		plural = "Operatives",
	},
} :: { [string]: RoleNames }

Terms.SIDE = {
	Team = { name = "the Bureau", Name = "The Bureau", title = "THE BUREAU" },
	Kira = { name = "the Coven", Name = "The Coven", title = "THE COVEN" },
}

-- Phase ids come from Config.PHASE_TIME plus "Lobby".
Terms.PHASE = {
	Lobby = "Lobby",
	Intro = "Case opening",
	Briefing = "Briefing",
	Investigation = "Investigation",
	DeathNote = "Death's Gambit",
	Meeting = "Bureau meeting",
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
	game = "Death's Gambit",
	GAME = "DEATH'S GAMBIT",

	hand = "Diavolo",
	Hand = "Diavolo",
	HAND = "DIAVOLO",
	cultist = "Muerto",
	Cultist = "Muerto",
	CULTIST = "MUERTO",
	cultists = "Muertos",
	Cultists = "Muertos",
	zero = "Ace",
	Zero = "Ace",
	ZERO = "ACE",
	butler = "the Butler",
	Butler = "The Butler",
	BUTLER = "THE BUTLER",
	agent = "Operative",
	Agent = "Operative",
	AGENT = "OPERATIVE",
	agents = "Operatives",
	Agents = "Operatives",
	agency = "the Bureau",
	Agency = "The Bureau",
	AGENCY = "THE BUREAU",
	circle = "the Coven",
	Circle = "The Coven",

	grimoire = "Death's Manual",
	Grimoire = "Death's Manual",
	GRIMOIRE = "DEATH'S MANUAL",
	specter = "Deathsinger",
	Specter = "Deathsinger",
	SPECTER = "DEATHSINGER",
	specters = "Deathsingers",
	eyes = "the Oculus of the Dead",
	Eyes = "The Oculus of the Dead",
	EYES = "THE OCULUS OF THE DEAD",
	zeroDesk = "Ace's desk",
	ZeroDesk = "Ace's desk",
	ZERO_DESK = "ACE'S DESK",
	zeroScreen = "Ace's screen",
	ZeroScreen = "Ace's screen",
	ZERO_SCREEN = "ACE'S SCREEN",
	meeting = "Bureau meeting",
	Meeting = "Bureau meeting",
	MEETING = "BUREAU MEETING",
	-- The single glyph that stands for Ace on screens and signs.
	zeroGlyph = "A",
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
