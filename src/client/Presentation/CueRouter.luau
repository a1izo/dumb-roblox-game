-- Receives presentation cues from the server and hands each one to its presenter. A cue that
-- belongs to another match, or that arrived more than a few seconds late (after a lag spike
-- or a rejoin), is dropped instead of played out of step with everyone else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local CueRouter = {}

export type Cue = {
	id: number,
	matchId: number,
	kind: string,
	at: number, -- server time the cue starts
	data: { [string]: any },
}

local MAX_LATE = 5

local listeners: { [string]: { (Cue) -> () } } = {}
local lastId = 0

-- listener(cue) runs in its own thread and may wait. A kind can have several listeners
-- (the cutscene, the characters' acting, ...).
function CueRouter.register(kind: string, listener: (Cue) -> ())
	local list = listeners[kind]
	if not list then
		list = {}
		listeners[kind] = list
	end
	table.insert(list, listener)
end

local function onCue(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" or type(payload.at) ~= "number" then
		return
	end
	local id = tonumber(payload.id) or 0
	if id <= lastId and id ~= 0 then
		return
	end
	lastId = math.max(lastId, id)
	if workspace:GetServerTimeNow() - payload.at > MAX_LATE then
		return
	end
	local list = listeners[payload.kind]
	if not list then
		return
	end
	if type(payload.data) ~= "table" then
		payload.data = {}
	end
	for _, listener in ipairs(list) do
		task.spawn(function()
			-- The state update sent in the same frame lands first, so listeners see the new phase.
			task.wait()
			local ok, err = pcall(listener, payload :: Cue)
			if not ok then
				warn("[DeathsGambit] The " .. payload.kind .. " cue failed: " .. tostring(err))
			end
		end)
	end
end

function CueRouter.init()
	Net.event("Cue").OnClientEvent:Connect(onCue)
end

return CueRouter
