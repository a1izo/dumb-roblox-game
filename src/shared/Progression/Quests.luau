--!strict
-- Quest definitions and the daily and weekly picks. Every quest can be done whatever your
-- role, and none asks for anything that hurts other players (no "vote someone out").
-- Progress comes only from the end-of-match summary.
--
-- stat: a key of the match summary (see ProgressRules): matches, wins, survived, tasks,
-- notesFound, correctVotes, reports (votes cast in meetings: the key is older than the meaning).
-- Two optional conditions make a quest harder than a plain count:
--   when: "survived" | "wonAlive": the match only counts if you lived, or won and lived.
--   each: the stat must reach this many IN ONE match for the match to count (as 1).
-- (The Deathsinger quests and the lost-soul quests went 2026-11-16, with the lost souls; a profile still
-- holding one of them simply skips it.)

local Terms = require(script.Parent.Parent.Terms)

local Quests = {}

export type Quest = {
	id: string,
	text: string,
	stat: string,
	goal: number,
	coins: number,
	xp: number,
	period: string, -- "daily" or "weekly"
	when: string?,
	each: number?,
}

local function q(
	id: string,
	text: string,
	stat: string,
	goal: number,
	reward: number,
	period: string,
	extra: { when: string?, each: number? }?
): Quest
	return {
		id = id,
		text = text,
		stat = stat,
		goal = goal,
		coins = reward,
		xp = reward,
		period = period,
		when = if extra then extra.when else nil,
		each = if extra then extra.each else nil,
	}
end

-- Daily: three a day, each on a different stat, so a day mixes a few kinds of play. A plain count asks for
-- 3+ matches or 12+ case files; the rest ask you to do something well in one match.
Quests.LIST = {
	-- matches
	q("d_play3", "Play 3 matches", "matches", 3, 90, "daily"),
	q("d_play5", "Play 5 matches", "matches", 5, 150, "daily"),
	-- wins
	q("d_win1", "Win a match", "wins", 1, 80, "daily"),
	q("d_win2", "Win 2 matches", "wins", 2, 170, "daily"),
	q("d_winalive", "Win a match and live to see it", "wins", 1, 110, "daily", { when = "wonAlive" }),
	q("d_winalive2", "Win 2 matches without dying", "wins", 2, 220, "daily", { when = "wonAlive" }),
	-- surviving
	q("d_survive2", "Survive 2 matches", "survived", 2, 100, "daily"),
	q("d_survive3", "Survive 3 matches", "survived", 3, 150, "daily"),
	-- case files
	q("d_tasks12", "Work 12 case files", "tasks", 12, 90, "daily"),
	q("d_tasks20", "Work 20 case files", "tasks", 20, 150, "daily"),
	q("d_tasksone", "Work 8 case files in a single match", "tasks", 1, 120, "daily", { each = 8 }),
	q("d_tasksalive", "Work 6 case files and survive, twice", "tasks", 2, 150, "daily", { when = "survived", each = 6 }),
	-- paper notes
	q("d_note2", "Find 2 paper notes", "notesFound", 2, 100, "daily"),
	q("d_note3", "Find 3 paper notes", "notesFound", 3, 150, "daily"),
	q("d_noteone", "Find 2 paper notes in a single match", "notesFound", 1, 110, "daily", { each = 2 }),
	-- votes
	q("d_vote2", Terms.f("Vote for {hand} twice"), "correctVotes", 2, 130, "daily"),
	q("d_vote3", Terms.f("Vote for {hand} 3 times"), "correctVotes", 3, 190, "daily"),
	q("d_voteone", Terms.f("Vote for {hand} twice in a single match"), "correctVotes", 1, 140, "daily", { each = 2 }),
	-- meetings
	q("d_report3", "Vote in 3 meetings", "reports", 3, 90, "daily"),
	q("d_report2one", "Vote in 2 meetings in a single match", "reports", 1, 100, "daily", { each = 2 }),
	-- weekly
	q("w_play10", "Play 10 matches", "matches", 10, 200, "weekly"),
	q("w_play20", "Play 20 matches", "matches", 20, 350, "weekly"),
	q("w_win5", "Win 5 matches", "wins", 5, 250, "weekly"),
	q("w_win10", "Win 10 matches", "wins", 10, 400, "weekly"),
	q("w_survive5", "Survive 5 matches", "survived", 5, 200, "weekly"),
	q("w_tasks40", "Work 40 case files", "tasks", 40, 250, "weekly"),
	q("w_notes5", "Find 5 paper notes", "notesFound", 5, 250, "weekly"),
	q("w_votes3", Terms.f("Vote for {hand} 3 times"), "correctVotes", 3, 250, "weekly"),
	q("w_winalive3", "Win 3 matches and survive each", "wins", 3, 300, "weekly", { when = "wonAlive" }),
	q("w_reports5", "Vote in 5 meetings", "reports", 5, 200, "weekly"),
} :: { Quest }

Quests.PER_PERIOD = 3

local byId: { [string]: Quest } = {}
for _, quest in ipairs(Quests.LIST) do
	byId[quest.id] = quest
end

function Quests.byId(id: string): Quest?
	return byId[id]
end

local function pool(period: string): { Quest }
	local list = {}
	for _, quest in ipairs(Quests.LIST) do
		if quest.period == period then
			table.insert(list, quest)
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- The same picks for everyone in a period: no two quests on the same stat.
local function pick(period: string, seed: number): { string }
	local rng = Random.new(seed)
	local remaining = pool(period)
	local picked: { string } = {}
	local stats: { [string]: boolean } = {}
	while #picked < Quests.PER_PERIOD and #remaining > 0 do
		local index = rng:NextInteger(1, #remaining)
		local quest = table.remove(remaining, index) :: Quest
		if not stats[quest.stat] then
			stats[quest.stat] = true
			table.insert(picked, quest.id)
		end
	end
	return picked
end

function Quests.daily(day: number): { string }
	return pick("daily", day * 104729 + 3)
end

function Quests.weekly(week: number): { string }
	return pick("weekly", week * 130363 + 11)
end

-- A replacement daily quest for a reroll: one not already held, on a different stat.
function Quests.reroll(current: { string }, dropId: string, seed: number): string?
	local held: { [string]: boolean } = {}
	local stats: { [string]: boolean } = {}
	for _, id in ipairs(current) do
		held[id] = true
		local quest = byId[id]
		if quest and id ~= dropId then
			stats[quest.stat] = true
		end
	end
	local options = {}
	for _, quest in ipairs(pool("daily")) do
		if not held[quest.id] and not stats[quest.stat] then
			table.insert(options, quest.id)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[Random.new(seed):NextInteger(1, #options)]
end

return Quests
