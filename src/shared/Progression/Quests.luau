--!strict
-- Quest definitions and the daily and weekly picks. Every quest can be done whatever your
-- role, and none asks for anything that hurts other players (no "vote someone out").
-- Progress comes only from the end-of-match summary.
--
-- stat: a key of the match summary (see ProgressRules): matches, wins, survived, tasks,
-- notesFound, correctVotes, duties, reports.

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
}

Quests.LIST = {
	-- daily
	{ id = "d_play2", text = "Play 2 matches", stat = "matches", goal = 2, coins = 40, xp = 40, period = "daily" },
	{ id = "d_play3", text = "Play 3 matches", stat = "matches", goal = 3, coins = 60, xp = 60, period = "daily" },
	{ id = "d_win1", text = "Win a match", stat = "wins", goal = 1, coins = 50, xp = 50, period = "daily" },
	{ id = "d_survive1", text = "Survive a match", stat = "survived", goal = 1, coins = 40, xp = 40, period = "daily" },
	{ id = "d_tasks5", text = "Work 5 case files", stat = "tasks", goal = 5, coins = 40, xp = 40, period = "daily" },
	{ id = "d_tasks8", text = "Work 8 case files", stat = "tasks", goal = 8, coins = 60, xp = 60, period = "daily" },
	{
		id = "d_note1",
		text = "Find a paper note",
		stat = "notesFound",
		goal = 1,
		coins = 50,
		xp = 50,
		period = "daily",
	},
	{
		id = "d_vote1",
		text = Terms.f("Vote for {hand} once"),
		stat = "correctVotes",
		goal = 1,
		coins = 50,
		xp = 50,
		period = "daily",
	},
	{ id = "d_souls3", text = "Gather 3 lost souls", stat = "duties", goal = 3, coins = 40, xp = 40, period = "daily" },
	{
		id = "d_report1",
		text = "Send a tip or report",
		stat = "reports",
		goal = 1,
		coins = 30,
		xp = 30,
		period = "daily",
	},
	-- weekly
	{
		id = "w_play10",
		text = "Play 10 matches",
		stat = "matches",
		goal = 10,
		coins = 200,
		xp = 200,
		period = "weekly",
	},
	{
		id = "w_play20",
		text = "Play 20 matches",
		stat = "matches",
		goal = 20,
		coins = 350,
		xp = 350,
		period = "weekly",
	},
	{ id = "w_win5", text = "Win 5 matches", stat = "wins", goal = 5, coins = 250, xp = 250, period = "weekly" },
	{ id = "w_win10", text = "Win 10 matches", stat = "wins", goal = 10, coins = 400, xp = 400, period = "weekly" },
	{
		id = "w_survive5",
		text = "Survive 5 matches",
		stat = "survived",
		goal = 5,
		coins = 200,
		xp = 200,
		period = "weekly",
	},
	{
		id = "w_tasks40",
		text = "Work 40 case files",
		stat = "tasks",
		goal = 40,
		coins = 250,
		xp = 250,
		period = "weekly",
	},
	{
		id = "w_notes5",
		text = "Find 5 paper notes",
		stat = "notesFound",
		goal = 5,
		coins = 250,
		xp = 250,
		period = "weekly",
	},
	{
		id = "w_votes3",
		text = Terms.f("Vote for {hand} 3 times"),
		stat = "correctVotes",
		goal = 3,
		coins = 250,
		xp = 250,
		period = "weekly",
	},
	{
		id = "w_souls15",
		text = "Gather 15 lost souls",
		stat = "duties",
		goal = 15,
		coins = 200,
		xp = 200,
		period = "weekly",
	},
	{
		id = "w_reports5",
		text = "Send 5 tips or reports",
		stat = "reports",
		goal = 5,
		coins = 200,
		xp = 200,
		period = "weekly",
	},
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
