-- The Bureau's shared task bar. Every case file a Bureau player finishes (alive, or as a Specter)
-- fills it by one; nobody can see who did which. When it is full the Bureau wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Terms = require(Shared:WaitForChild("Terms"))
local WinConditions = require(Shared:WaitForChild("WinConditions"))

local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)

local TaskBarService = {}

function TaskBarService.onMatchStart()
	local bureau = 0
	for _, ps in ipairs(Match.list) do
		if not Match.isKiraSide(ps) then
			bureau += 1
		end
	end
	Match.taskBar = { done = 0, total = WinConditions.taskTotal(bureau, Config.TASKS_PER_BUREAU) }
end

-- The bar is as long as every case file handed out (CaseFileService assigns them).
function TaskBarService.setTotal(total: number)
	Match.taskBar.total = math.max(1, total)
	Match.pushState()
end

-- A Bureau player left with case files still to do: the bar no longer waits for them.
function TaskBarService.forgive(count: number)
	local bar = Match.taskBar
	if count <= 0 or not Match.active then
		return
	end
	bar.total = math.max(1, bar.total - count)
	TaskBarService.add(0)
end

-- One more case file done.
function TaskBarService.add(amount: number?)
	local bar = Match.taskBar
	if not Match.active or Match.winner ~= nil or bar.total <= 0 then
		return
	end
	bar.done = math.min(bar.total, bar.done + (amount or 1))
	if bar.done >= bar.total then
		EventLog.add(Terms.f("{Agency} finished every case file."), "end")
		Match.declareWinner("Team", Terms.f("{Agency} closed every case file."))
	end
	Match.pushState()
end

-- Debug panel: fills the bar to this share (0 to 1) without ending the match.
function TaskBarService.debugFill(share: number)
	local bar = Match.taskBar
	bar.done = math.clamp(math.floor(bar.total * share), 0, math.max(0, bar.total - 1))
	Match.pushState()
end

return TaskBarService
