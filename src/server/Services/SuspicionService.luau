-- L's suspicion meter. It is a hint, not proof: private reports, fake tasks that were
-- seen, standing near a burned note and idle rounds push it up. If Watari dies,
-- L loses the meter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Match = require(script.Parent.Match)

local SuspicionRemote = Net.event("Suspicion")

local SuspicionService = {}

local values: { [number]: number } = {}
local dirty = false
local runningId = 0

function SuspicionService.add(ps, amount: number)
	if not Match.active or not ps then
		return
	end
	local current = values[ps.userId] or 0
	values[ps.userId] = math.clamp(current + amount, 0, Config.SUSPICION.MAX)
	dirty = true
end

function SuspicionService.get(ps): number
	return values[ps.userId] or 0
end

-- The meter works while L lives and Watari is alive (or there never was a Watari).
function SuspicionService.enabled(): boolean
	local watari = Match.findRole("Watari")
	return watari == nil or watari.alive
end

function SuspicionService.push()
	dirty = false
	local l = Match.findRole("L")
	if not l or not l.alive then
		return
	end
	if not SuspicionService.enabled() then
		SuspicionRemote:FireClient(l.player, { enabled = false })
		return
	end
	local list = {}
	for _, ps in ipairs(Match.list) do
		if ps.alive and ps ~= l then
			table.insert(list, { userId = ps.userId, alias = ps.alias, value = values[ps.userId] or 0 })
		end
	end
	SuspicionRemote:FireClient(l.player, { enabled = true, values = list })
end

-- Idle players raise suspicion at the end of each round.
function SuspicionService.onRoundEnd()
	for _, ps in ipairs(Match.living()) do
		if ps.tasksThisRound == 0 then
			SuspicionService.add(ps, Config.SUSPICION.IDLE_ROUND)
		end
	end
	SuspicionService.push()
end

function SuspicionService.onMatchStart()
	values = {}
	dirty = true
	runningId += 1
	local myId = runningId
	task.spawn(function()
		while Match.active and runningId == myId do
			if dirty then
				SuspicionService.push()
			end
			task.wait(1)
		end
	end)
end

function SuspicionService.onMatchEnd()
	runningId += 1
	values = {}
end

function SuspicionService.init()
	-- Deaths change who is listed, and Watari's death switches the meter off.
	Match.Eliminated:Connect(function()
		dirty = true
	end)
end

return SuspicionService
