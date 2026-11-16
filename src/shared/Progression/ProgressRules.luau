--!strict
-- Everything a finished match adds to a profile, as one pure function: lifetime stats,
-- quest progress, role mastery, achievements and rank titles. The server calls apply()
-- once per player after the rewards are paid; the result lists what to tell the player.

local Achievements = require(script.Parent.Achievements)
local Cosmetics = require(script.Parent.Parent.Cosmetics)
local Ledger = require(script.Parent.Ledger)
local Mastery = require(script.Parent.Mastery)
local Quests = require(script.Parent.Quests)
local TimeUtil = require(script.Parent.TimeUtil)
local Ranks = require(script.Parent.Parent.Ranks)

local ProgressRules = {}

-- Whether a case still writes the Season ledger (off since 2026-11-16).
ProgressRules.LEDGER = false

export type Summary = {
	role: string,
	side: string, -- "Team" or "Kira"
	won: boolean,
	survived: boolean,
	tasks: number,
	notesFound: number,
	correctVotes: number,
	kills: number,
	reads: number,
	arrests: number,
	duties: number,
	reports: number,
	rigs: number,
	-- (kept in the summary for the stats: no quest reads them any more)
	wagersWon: number?,
	haunts: number?,
	ghost: boolean?,
	xpBefore: number, -- profile xp before this match's rewards
}

export type Line = { label: string, coins: number, xp: number }

export type Result = {
	lines: { Line },
	unlocked: { string }, -- cosmetic ids
	achievements: { string },
	quests: { string },
	coins: number,
	xp: number,
	masteryLevel: { from: number, to: number }?,
	rankUp: { from: number, to: number }?,
	ledger: { points: number, tier: number, season: number }?,
}

-- Rank titles: reaching a rank unlocks its title.
ProgressRules.RANK_TITLES = {
	[2] = "title_rank_2",
	[3] = "title_rank_3",
	[4] = "title_rank_4",
	[5] = "title_rank_5",
	[6] = "title_rank_6",
	[7] = "title_rank_7",
	[8] = "title_rank_8",
} :: { [number]: string }

local function questItems(ids: { string }): { any }
	local items = {}
	for _, id in ipairs(ids) do
		table.insert(items, { id = id, progress = 0, done = false })
	end
	return items
end

-- Gives the profile this day's and week's quests if it still holds older ones.
function ProgressRules.ensureQuests(data: any, now: number)
	local day, week = TimeUtil.day(now), TimeUtil.week(now)
	local quests = data.quests
	-- (a list holding a quest that no longer exists, the lost-soul ones, is dealt again at once)
	local function stale(list: any): boolean
		for _, item in ipairs(list.items) do
			if not Quests.byId(item.id) then
				return true
			end
		end
		return false
	end
	if quests.daily.period ~= day or stale(quests.daily) then
		quests.daily = { period = day, items = questItems(Quests.daily(day)) }
	end
	if quests.weekly.period ~= week or stale(quests.weekly) then
		quests.weekly = { period = week, items = questItems(Quests.weekly(week)) }
	end
	-- (the Deathsinger quests are gone, 2026-11-16: an old profile's list is emptied)
	if type(quests.ghost) ~= "table" or type(quests.ghost.items) ~= "table" or #quests.ghost.items > 0 then
		quests.ghost = { period = -1, items = {} }
	end
end

-- Swaps one unfinished daily quest for another (once per day). Returns true on success.
function ProgressRules.reroll(data: any, questId: string, now: number): boolean
	ProgressRules.ensureQuests(data, now)
	local day = TimeUtil.day(now)
	if data.quests.rerollDay == day then
		return false
	end
	local items = data.quests.daily.items
	local ids = {}
	local target = nil
	for _, item in ipairs(items) do
		table.insert(ids, item.id)
		if item.id == questId and not item.done then
			target = item
		end
	end
	if not target then
		return false
	end
	local replacement = Quests.reroll(ids, questId, day * 31 + 7)
	if not replacement then
		return false
	end
	target.id = replacement
	target.progress = 0
	target.done = false
	data.quests.rerollDay = day
	return true
end

local function statFor(summary: Summary, quest: Quests.Quest): number
	-- (a quest's condition: the match counts only if you lived, or won and lived)
	if quest.when == "survived" and not summary.survived then
		return 0
	elseif quest.when == "wonAlive" and not (summary.won and summary.survived) then
		return 0
	end
	local stat = quest.stat
	local value: number
	if stat == "matches" then
		value = 1
	elseif stat == "wins" then
		value = if summary.won then 1 else 0
	elseif stat == "survived" then
		value = if summary.survived then 1 else 0
	else
		local raw = (summary :: any)[stat]
		value = if type(raw) == "number" then raw else 0
	end
	-- (a quest that wants so much in ONE match counts the match as 1 once the stat reaches it)
	if quest.each then
		return if value >= quest.each then 1 else 0
	end
	return value
end

local function unlock(data: any, result: Result, itemId: string?)
	if itemId and not data.owned[itemId] then
		data.owned[itemId] = true
		table.insert(result.unlocked, itemId)
	end
end

function ProgressRules.apply(data: any, summary: Summary, now: number): Result
	local result: Result = {
		lines = {},
		unlocked = {},
		achievements = {},
		quests = {},
		coins = 0,
		xp = 0,
	}
	local function add(label: string, coins: number, xp: number)
		result.coins += coins
		result.xp += xp
		table.insert(result.lines, { label = label, coins = coins, xp = xp })
	end

	-- Lifetime stats (matches, wins and tasks are counted with the rewards).
	local stats = data.stats
	stats.kills += summary.kills
	stats.arrests += summary.arrests
	stats.reads += summary.reads
	stats.correctVotes += summary.correctVotes
	stats.notesFound += summary.notesFound
	stats.duties += summary.duties
	-- (the Ferryman achievements read this since the lost souls went: it was never added up before 2026-11-16)
	stats.haunts = (stats.haunts or 0) + (summary.haunts or 0)
	stats.reports += summary.reports
	stats.rigs += summary.rigs
	if summary.survived then
		stats.survived += 1
	end
	local role = stats.roles[summary.role]
	if role then
		role.played += 1
		if summary.won then
			role.won += 1
		end
	end
	local side = stats.sides[summary.side]
	if side then
		side.played += 1
		if summary.won then
			side.won += 1
		end
	end

	-- This week's board.
	local week = TimeUtil.week(now)
	if data.weekly.week ~= week then
		data.weekly = { week = week, wins = 0, xp = 0 }
	end
	if summary.won then
		data.weekly.wins += 1
	end

	-- Quests.
	ProgressRules.ensureQuests(data, now)
	local lists = { data.quests.daily.items, data.quests.weekly.items }
	for _, list in ipairs(lists) do
		for _, item in ipairs(list) do
			local quest = Quests.byId(item.id)
			if quest and not item.done then
				item.progress = math.min(quest.goal, item.progress + statFor(summary, quest))
				if item.progress >= quest.goal then
					item.done = true
					table.insert(result.quests, quest.id)
					add("Quest: " .. quest.text, quest.coins, quest.xp)
				end
			end
		end
	end

	-- Role mastery.
	if data.mastery[summary.role] ~= nil then
		local before = data.mastery[summary.role]
		local after = before + Mastery.xpFor(summary.won)
		data.mastery[summary.role] = after
		local fromLevel, toLevel = Mastery.level(before), Mastery.level(after)
		if toLevel > fromLevel then
			result.masteryLevel = { from = fromLevel, to = toLevel }
			local unlocks = Mastery.UNLOCKS[summary.role] or {}
			for level = fromLevel + 1, toLevel do
				unlock(data, result, unlocks[level])
			end
		end
	end

	-- The Season ledger: the case's points (more for a win and for each quest finished in it), each tier
	-- reached paid at once. (Off since 2026-11-16: the user took the ledger out of the shop; its titles are
	-- achievements now and its other things are on sale. ProgressRules.LEDGER turns it back on.)
	local season = Ledger.season(now)
	if ProgressRules.LEDGER and season > 0 and type(data.ledger) == "table" then
		local points = Ledger.pointsFor(summary.won, #result.quests)
		for _, step in ipairs(Ledger.add(data.ledger, season, points)) do
			local item = step.reward.item
			if step.reward.coins then
				add(string.format("Ledger, tier %d", step.tier), step.reward.coins, 0)
			elseif item and data.owned[item] then
				-- (already owned: its worth in coins instead)
				add(string.format("Ledger, tier %d", step.tier), Ledger.instead(Cosmetics.byId(item)), 0)
			end
			unlock(data, result, item)
		end
		result.ledger = { points = points, tier = data.ledger.tier, season = season }
	end

	-- Achievements (after the stats above).
	for _, achievement in ipairs(Achievements.LIST) do
		if data.achievements[achievement.id] == nil and Achievements.value(data, achievement) >= achievement.goal then
			data.achievements[achievement.id] = now
			table.insert(result.achievements, achievement.id)
			add("Achievement: " .. achievement.name, achievement.coins, 0)
			unlock(data, result, achievement.title)
			if achievement.badgeId ~= 0 then
				data.pendingBadges[achievement.id] = true
			end
		end
	end

	-- Pay out, then rank titles for every rank reached.
	data.coins += result.coins
	data.xp += result.xp
	data.weekly.xp += result.xp
	local fromRank = Ranks.forXp(summary.xpBefore)
	local toRank = Ranks.forXp(data.xp)
	if toRank > fromRank then
		result.rankUp = { from = fromRank, to = toRank }
	end
	for index = 2, toRank do
		unlock(data, result, ProgressRules.RANK_TITLES[index])
	end
	return result
end

-- Achievements that only depend on the profile (training, streaks): checked outside matches.
function ProgressRules.checkAchievements(data: any, now: number): { string }
	local unlocked = {}
	for _, achievement in ipairs(Achievements.LIST) do
		if data.achievements[achievement.id] == nil and Achievements.value(data, achievement) >= achievement.goal then
			data.achievements[achievement.id] = now
			data.coins += achievement.coins
			table.insert(unlocked, achievement.id)
			if achievement.title and not data.owned[achievement.title] then
				data.owned[achievement.title] = true
			end
			if achievement.badgeId ~= 0 then
				data.pendingBadges[achievement.id] = true
			end
		end
	end
	return unlocked
end

return ProgressRules
