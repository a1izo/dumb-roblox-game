--!strict
-- Holds the start of a match until every player's client has the map: all of its pieces arrived over the
-- network and every mesh and texture it (and the cutscenes) use downloaded (Presentation/MapPreloader).
-- Without this the intro played while the map was still arriving, things popping in mid-cutscene.
--
-- MapService.build stamps the map with a load token and its number of pieces; each client answers
-- "MapReady" with that token once it is done. A slow or stuck client never holds the others past
-- `timeout` seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local LoadGate = {}

local ReadyRemote = Net.event("MapReady")
local ready: { [number]: number } = {} -- userId -> the last token that client finished

function LoadGate.init()
	ReadyRemote.OnServerEvent:Connect(function(player: Player, token: any)
		if type(token) == "number" then
			ready[player.UserId] = token
		end
	end)
end

-- Waits until every real player in `players` (bots have nothing to load) has reported `token`, they left,
-- or `timeout` seconds pass. Once most of them are ready (all but a quarter), the rest get `grace` seconds more at
-- most: a client that never answers cannot hold everyone for the whole timeout (2026-10-27). Returns whether everyone
-- made it.
function LoadGate.wait(token: number, players: { any }, timeout: number, grace: number?): boolean
	local started = os.clock()
	local mostAt: number? = nil
	while os.clock() - started < timeout do
		local total, done = 0, 0
		for _, player in ipairs(players) do
			if typeof(player) == "Instance" and player.Parent then
				total += 1
				if ready[player.UserId] == token then
					done += 1
				end
			end
		end
		if done >= total then
			return true
		end
		if grace and done >= math.max(1, math.ceil(total * 0.75)) then
			mostAt = mostAt or os.clock()
			if os.clock() - (mostAt :: number) >= grace then
				return false
			end
		end
		task.wait(0.2)
	end
	return false
end

return LoadGate
