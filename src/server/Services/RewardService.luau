-- Coins and experience at the end of a match, based on the result and performance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Terms = require(Shared:WaitForChild("Terms"))

local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)

local RewardService = {}

-- Returns [playerState] = { coins, xp, won, lines = { { label, coins, xp } } }.
function RewardService.payout(winner: string?)
	local R = Config.REWARDS
	local results = {}
	for _, ps in ipairs(Match.list) do
		local kiraSide = Match.isKiraSide(ps)
		local won = (winner == "Team" and not kiraSide) or (winner == "Kira" and kiraSide)
		local lines = {}
		local coins, xp = 0, 0
		local function add(label: string, c: number, x: number)
			if c == 0 and x == 0 then
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
		results[ps] = { coins = coins, xp = xp, won = won, lines = lines }
		DataService.grant(ps.player, coins, xp, won, ps.stats.tasks)
	end
	return results
end

return RewardService
