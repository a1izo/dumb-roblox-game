-- Progress after each match (stats, quests, mastery, achievements, rank titles), the daily
-- streak and the daily quest reroll. Quest progress only ever comes from finished matches.
-- Matches under custom private-server rules do not count.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Progression = Shared:WaitForChild("Progression")
local ProgressRules = require(Progression:WaitForChild("ProgressRules"))
local Streak = require(Progression:WaitForChild("Streak"))
local TimeUtil = require(Progression:WaitForChild("TimeUtil"))

local AchievementService = require(script.Parent.AchievementService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Match = require(script.Parent.Match)
local ProfileService = require(script.Parent.ProfileService)
local ServerSettings = require(script.Parent.ServerSettings)

local ProgressService = {}

local function itemNames(ids: { string }): { string }
	local names = {}
	for _, id in ipairs(ids) do
		local item = Cosmetics.byId(id)
		table.insert(names, if item then item.name else id)
	end
	return names
end

-- Adds this match to every player's progress. rewards[ps] comes from RewardService.payout
-- and gains the extra lines (quests, achievements) and a `progress` summary for the results.
function ProgressService.onMatchEnd(rewards: { [any]: any })
	if ServerSettings.isCustom() then
		return
	end
	local now = TimeUtil.now()
	for _, ps in ipairs(Match.list) do
		local data = DataService.get(ps.player)
		local reward = rewards[ps]
		if data and reward then
			local summary: ProgressRules.Summary = {
				role = ps.role,
				side = if Match.isKiraSide(ps) then "Kira" else "Team",
				won = reward.won == true,
				survived = ps.alive,
				tasks = ps.stats.tasks,
				notesFound = ps.stats.notesFound,
				correctVotes = ps.stats.correctVotes,
				kills = ps.stats.kills,
				reads = ps.stats.reads,
				arrests = if ps.stats.arrestedKira then 1 else 0,
				duties = ps.stats.duties or 0,
				reports = ps.stats.reports or 0,
				rigs = ps.stats.rigs or 0,
				xpBefore = data.xp - reward.xp,
			}
			local result = ProgressRules.apply(data, summary, now)
			for _, line in ipairs(result.lines) do
				table.insert(reward.lines, line)
			end
			reward.coins += result.coins
			reward.xp += result.xp
			reward.progress = {
				unlocked = itemNames(result.unlocked),
				rankUp = result.rankUp,
				masteryLevel = result.masteryLevel,
				role = ps.role,
			}
			AchievementService.awardPending(ps.player)
			LeaderboardService.queue(ps.player, data)
			DataService.push(ps.player)
			DataService.saveSoon(ps.player)
		end
	end
end

local function claimStreak(player: Player)
	local data = DataService.get(player)
	if not data or Match.get(player) then
		return
	end
	local today = TimeUtil.day(TimeUtil.now())
	local state, reward = Streak.advance(data.streak, today)
	if not reward then
		Match.notify(player, "You already claimed today's streak.", "info")
		return
	end
	data.streak = state
	data.coins += reward.coins
	local text = string.format("Day %d streak: +%d coins.", state.count, reward.coins)
	if reward.itemId and not data.owned[reward.itemId] then
		data.owned[reward.itemId] = true
		local item = Cosmetics.byId(reward.itemId)
		text ..= " Unlocked: " .. (if item then item.name else reward.itemId) .. "."
	end
	ProgressRules.checkAchievements(data, TimeUtil.now())
	Match.notify(player, text, "good")
	AchievementService.awardPending(player)
	CosmeticsService.apply(player)
	DataService.push(player)
	DataService.saveSoon(player)
end

local function reroll(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.quest) ~= "string" then
		return
	end
	if ProgressRules.reroll(data, payload.quest, TimeUtil.now()) then
		Match.notify(player, "Quest swapped.", "info")
		DataService.push(player)
		DataService.saveSoon(player)
	else
		Match.notify(player, "You can swap one daily quest per day.", "bad")
	end
end

-- Achievements that depend only on the profile (for example the Academy).
function ProgressService.checkProfile(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local unlocked = ProgressRules.checkAchievements(data, TimeUtil.now())
	if #unlocked > 0 then
		AchievementService.awardPending(player)
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

function ProgressService.init()
	ProfileService.register("streak", 2, claimStreak)
	ProfileService.register("reroll", 2, reroll)
	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService.get(player)
		if data then
			ProgressRules.ensureQuests(data, TimeUtil.now())
		end
		ProgressService.checkProfile(player)
	end)
end

return ProgressService
