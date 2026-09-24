--!strict
-- Lifetime achievements. Each one checks a number in the profile against a goal; many give
-- a title. badgeId: the Roblox badge to award (create badges on the Creator Dashboard and
-- paste the ids; 0 = no badge).

local Achievements = {}

export type Achievement = {
	id: string,
	name: string,
	text: string,
	path: { string }, -- where the number lives in the profile, from data (for example stats.wins)
	goal: number,
	coins: number,
	title: string?, -- cosmetic id of a title it unlocks
	badgeId: number,
}

local function a(
	id: string,
	name: string,
	text: string,
	path: { string },
	goal: number,
	coins: number,
	title: string?
): Achievement
	return { id = id, name = name, text = text, path = path, goal = goal, coins = coins, title = title, badgeId = 0 }
end

Achievements.LIST = {
	a("first_case", "First case", "Play your first match.", { "stats", "matches" }, 1, 25),
	a("regular", "Regular", "Play 10 matches.", { "stats", "matches" }, 10, 50),
	a("veteran", "Veteran", "Play 50 matches.", { "stats", "matches" }, 50, 150, "title_veteran"),
	a("career", "Career detective", "Play 100 matches.", { "stats", "matches" }, 100, 250),
	a("lifer", "Lifer", "Play 250 matches.", { "stats", "matches" }, 250, 500, "title_lifer"),
	a("first_win", "Case closed", "Win a match.", { "stats", "wins" }, 1, 25),
	a("winner10", "Closer", "Win 10 matches.", { "stats", "wins" }, 10, 100),
	a("winner50", "Unbeaten", "Win 50 matches.", { "stats", "wins" }, 50, 300, "title_unbeaten"),
	a("winner100", "Legend of the case", "Win 100 matches.", { "stats", "wins" }, 100, 500),
	a("tasks10", "Paperwork", "Work 10 case files.", { "stats", "tasks" }, 10, 25),
	a("tasks100", "Archivist", "Work 100 case files.", { "stats", "tasks" }, 100, 150, "title_archivist"),
	a("tasks500", "Workaholic", "Work 500 case files.", { "stats", "tasks" }, 500, 400),
	a("notes1", "Scrap of paper", "Find a paper note.", { "stats", "notesFound" }, 1, 25),
	a("notes25", "Paper trail", "Find 25 paper notes.", { "stats", "notesFound" }, 25, 200, "title_papertrail"),
	a("votes1", "Pointed finger", "Vote for the Hand.", { "stats", "correctVotes" }, 1, 25),
	a("votes25", "Sharp eye", "Vote for the Hand 25 times.", { "stats", "correctVotes" }, 25, 250, "title_sharpeye"),
	a("survive10", "Hard to kill", "Survive 10 matches.", { "stats", "survived" }, 10, 100),
	a("survive50", "Unwritten", "Survive 50 matches.", { "stats", "survived" }, 50, 300, "title_unwritten"),
	a("souls10", "Ferryman", "Gather 10 lost souls.", { "stats", "duties" }, 10, 50),
	a("souls100", "Shepherd of souls", "Gather 100 lost souls.", { "stats", "duties" }, 100, 250, "title_shepherd"),
	a("ink1", "First entry", "Write a name in the Grimoire and see it come true.", { "stats", "kills" }, 1, 25),
	a("ink25", "Ink-stained", "25 names come true.", { "stats", "kills" }, 25, 250, "title_inkstained"),
	a("arrest1", "Warrant served", "Arrest the Hand as Zero.", { "stats", "arrests" }, 1, 50),
	a("arrest10", "Handcuffs", "Arrest the Hand 10 times as Zero.", { "stats", "arrests" }, 10, 300, "title_handcuffs"),
	a("reads10", "Second sight", "Read 10 real names with the eyes.", { "stats", "reads" }, 10, 100),
	a("win_hand", "Written", "Win as the Hand.", { "stats", "roles", "Kira", "won" }, 1, 50), -- terms:ok
	a("win_cultist", "Devoted", "Win as a Cultist.", { "stats", "roles", "Follower", "won" }, 1, 50),
	a("win_zero", "Checkmate", "Win as Zero.", { "stats", "roles", "L", "won" }, 1, 50),
	a("win_butler", "At your service", "Win as the Butler.", { "stats", "roles", "Watari", "won" }, 1, 50), -- terms:ok
	a("win_agent", "Agent of the case", "Win as an Agent.", { "stats", "roles", "TaskForce", "won" }, 1, 50),
	a("streak7", "Night shift", "Keep a 7-day streak.", { "streak", "best" }, 7, 100),
} :: { Achievement }

local byId: { [string]: Achievement } = {}
for _, achievement in ipairs(Achievements.LIST) do
	byId[achievement.id] = achievement
end

function Achievements.byId(id: string): Achievement?
	return byId[id]
end

-- The current number for an achievement in a profile.
function Achievements.value(data: any, achievement: Achievement): number
	local node = data
	for _, key in ipairs(achievement.path) do
		if type(node) ~= "table" then
			return 0
		end
		node = node[key]
	end
	return if type(node) == "number" then node else 0
end

return Achievements
