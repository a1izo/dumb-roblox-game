-- Streaks, quests, mastery and the end-of-match progress rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = Shared:WaitForChild("Progression")
local Achievements = require(Progression:WaitForChild("Achievements"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Mastery = require(Progression:WaitForChild("Mastery"))
local ProgressRules = require(Progression:WaitForChild("ProgressRules"))
local Quests = require(Progression:WaitForChild("Quests"))
local Streak = require(Progression:WaitForChild("Streak"))
local TimeUtil = require(Progression:WaitForChild("TimeUtil"))

local Migrations = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Migrations"))

local DAY = 86400

local function summary(overrides)
	local base = {
		role = "TaskForce",
		side = "Team",
		won = true,
		survived = true,
		tasks = 5,
		notesFound = 1,
		correctVotes = 1,
		kills = 0,
		reads = 0,
		arrests = 0,
		duties = 0,
		reports = 0,
		rigs = 0,
		xpBefore = 0,
	}
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("TimeUtil", function()
		it("starts weeks on Monday", function()
			-- 2024-01-01 was a Monday; the Sunday before is in the previous week.
			local monday = 1704067200
			expect(TimeUtil.week(monday)).to.equal(TimeUtil.week(monday + 6 * DAY))
			expect(TimeUtil.week(monday - DAY) + 1).to.equal(TimeUtil.week(monday))
		end)
	end)

	describe("Streak", function()
		it("counts up on consecutive days and resets after a gap", function()
			local state = { day = -1, count = 0, best = 0 }
			local reward
			state, reward = Streak.advance(state, 100)
			expect(state.count).to.equal(1)
			expect(reward ~= nil).to.equal(true)
			local _, again = Streak.advance(state, 100)
			expect(again).to.equal(nil)
			state = Streak.advance(state, 101)
			expect(state.count).to.equal(2)
			state = Streak.advance(state, 105)
			expect(state.count).to.equal(1)
			expect(state.best).to.equal(2)
		end)
		it("gives the streak item on day 7", function()
			local state = { day = -1, count = 0, best = 0 }
			local reward
			for day = 1, 7 do
				state, reward = Streak.advance(state, day)
			end
			expect(reward and reward.itemId).to.equal(Streak.ITEM)
			expect(Cosmetics.byId(Streak.ITEM) ~= nil).to.equal(true)
		end)
	end)

	describe("Quests", function()
		it("picks the same quests for everyone, each on a different stat", function()
			local a = Quests.daily(20000)
			expect(table.concat(a, ",")).to.equal(table.concat(Quests.daily(20000), ","))
			expect(#a).to.equal(Quests.PER_PERIOD)
			local stats = {}
			for _, id in ipairs(a) do
				local quest = Quests.byId(id)
				expect(stats[quest.stat]).to.equal(nil)
				stats[quest.stat] = true
			end
			expect(#Quests.weekly(3000)).to.equal(Quests.PER_PERIOD)
			expect(#Quests.ghost(20000)).to.equal(Quests.PER_PERIOD)
			for _, id in ipairs(Quests.ghost(20000)) do
				expect((Quests.byId(id) :: any).period).to.equal("ghost")
			end
		end)
	end)

	describe("ProgressRules", function()
		it("counts a match into quests, mastery and stats", function()
			local data = Migrations.defaults(0)
			local now = 20000 * DAY + 100
			ProgressRules.ensureQuests(data, now)
			data.stats.matches = 1
			data.stats.wins = 1
			local result = ProgressRules.apply(data, summary(), now)
			expect(data.stats.roles.TaskForce.played).to.equal(1)
			expect(data.stats.roles.TaskForce.won).to.equal(1)
			expect(data.mastery.TaskForce).to.equal(Mastery.xpFor(true))
			expect(data.stats.survived).to.equal(1)
			expect(data.achievements.first_case ~= nil).to.equal(true)
			expect(result.coins > 0).to.equal(true)
			for _, item in ipairs(data.quests.daily.items) do
				local quest = Quests.byId(item.id)
				expect(item.progress <= quest.goal).to.equal(true)
			end
		end)
		it("does not unlock an achievement twice", function()
			local data = Migrations.defaults(0)
			local now = 20000 * DAY
			data.stats.matches = 1
			ProgressRules.apply(data, summary(), now)
			local coins = data.coins
			local result = ProgressRules.apply(data, summary({ won = false, tasks = 0 }), now)
			for _, id in ipairs(result.achievements) do
				expect(id ~= "first_case").to.equal(true)
			end
			expect(data.coins >= coins).to.equal(true)
		end)
		it("allows one daily quest swap per day", function()
			local data = Migrations.defaults(0)
			local now = 20000 * DAY
			ProgressRules.ensureQuests(data, now)
			local first = data.quests.daily.items[1].id
			expect(ProgressRules.reroll(data, first, now)).to.equal(true)
			expect(data.quests.daily.items[1].id ~= first).to.equal(true)
			expect(ProgressRules.reroll(data, data.quests.daily.items[2].id, now)).to.equal(false)
		end)
		it("unlocks only cosmetics that exist", function()
			for _, achievement in ipairs(Achievements.LIST) do
				if achievement.title then
					expect(Cosmetics.byId(achievement.title) ~= nil).to.equal(true)
				end
			end
			for _, unlocks in pairs(Mastery.UNLOCKS) do
				for _, id in pairs(unlocks) do
					expect(Cosmetics.byId(id) ~= nil).to.equal(true)
				end
			end
			for _, id in pairs(ProgressRules.RANK_TITLES) do
				expect(Cosmetics.byId(id) ~= nil).to.equal(true)
			end
		end)
	end)
end
