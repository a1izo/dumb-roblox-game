-- Coins and experience at the end of a match, based on the result and performance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Terms = require(Shared:WaitForChild("Terms"))

local PartyService = require(script.Parent.PartyService)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local ServerSettings = require(script.Parent.ServerSettings)

local RewardService = {}

-- Returns [playerState] = { coins, xp, won, lines = { { label, coins, xp } } }.
function RewardService.payout(winner: string?)
	local R = Config.REWARDS
	local custom = ServerSettings.isCustom()
	local results = {}
	local players = {}
	for _, ps in ipairs(Match.list) do
		table.insert(players, ps.player)
	end
	local inParty: { [number]: boolean } = {}
	for _, group in ipairs(PartyService.groupsFor(players)) do
		if #group > 1 then
			for _, userId in ipairs(group) do
				inParty[userId] = true
			end
		end
	end
	for _, ps in ipairs(Match.list) do
		local kiraSide = Match.isKiraSide(ps)
		local won = (winner == "Team" and not kiraSide) or (winner == "Kira" and kiraSide)
		local lines = {}
		local coins, xp = 0, 0
		local function add(label: string, c: number, x: number)
			if c == 0 and x == 0 then
				return
			end
			-- Custom private-server rules pay participation only.
			if custom and #lines > 0 then
				return
			end
			coins += c
			xp += x
			table.insert(lines, { label = label, coins = c, xp = x })
		end
		add("Case closed", R.PARTICIPATE_COINS, R.PARTICIPATE_XP)
		if won then
			add("Victory", R.WIN_COINS, R.WIN_XP)
		end
		if ps.alive then
			add("Survived", R.SURVIVE_COINS, R.SURVIVE_XP)
		end
		local tasks = math.min(ps.stats.tasks, R.TASK_CAP)
		add(string.format("Case files x%d", tasks), tasks * R.TASK_COINS, tasks * R.TASK_XP)
		add(
			string.format("Notes found x%d", ps.stats.notesFound),
			ps.stats.notesFound * R.NOTE_FOUND_COINS,
			ps.stats.notesFound * R.NOTE_FOUND_XP
		)
		add(
			Terms.f("Votes on {hand} x{n}", { n = ps.stats.correctVotes }),
			ps.stats.correctVotes * R.CORRECT_VOTE_COINS,
			ps.stats.correctVotes * R.CORRECT_VOTE_XP
		)
		add(
			Terms.f("{Grimoire} kills x{n}", { n = ps.stats.kills }),
			ps.stats.kills * R.KILL_COINS,
			ps.stats.kills * R.KILL_XP
		)
		add(
			Terms.f("{Eyes} reads x{n}", { n = ps.stats.reads }),
			ps.stats.reads * R.EYES_READ_COINS,
			ps.stats.reads * R.EYES_READ_XP
		)
		if ps.stats.arrestedKira then
			add(Terms.f("Arrested {hand}"), R.ARREST_COINS, R.ARREST_XP)
		end
		local duties = ps.stats.duties or 0
		add(Terms.f("{Specter} duties x{n}", { n = duties }), duties * R.SPECTER_DUTY_COINS, duties * R.SPECTER_DUTY_XP)
		if inParty[ps.userId] and xp > 0 and not custom then
			local bonus = math.floor(xp * 0.1 + 0.5)
			add("Party bonus", 0, bonus)
		end
		if PassService.owns(ps.player, "coins2x") and coins > 0 then
			table.insert(lines, { label = "Double Coins", coins = coins, xp = 0 })
			coins *= 2
		end
		results[ps] = { coins = coins, xp = xp, won = won, lines = lines }
		DataService.grant(ps.player, coins, xp, won, ps.stats.tasks)
		local data = DataService.get(ps.player)
		if data then
			Analytics.coins(ps.player, coins, data.coins, "Gameplay", "MatchReward")
		end
	end
	return results
end

return RewardService
