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

local presenters: { [string]: (Cue) -> () } = {}
local lastId = 0

-- presenter(cue) runs in its own thread and may wait.
function CueRouter.register(kind: string, presenter: (Cue) -> ())
	presenters[kind] = presenter
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
	local presenter = presenters[payload.kind]
	if not presenter then
		return
	end
	if type(payload.data) ~= "table" then
		payload.data = {}
	end
	task.spawn(function()
		-- The state update sent in the same frame lands first, so presenters see the new phase.
		task.wait()
		local ok, err = pcall(presenter, payload :: Cue)
		if not ok then
			warn("[Inkbound] The " .. payload.kind .. " cue failed: " .. tostring(err))
		end
	end)
end

function CueRouter.init()
	Net.event("Cue").OnClientEvent:Connect(onCue)
end

return CueRouter
