-- The campus's mechanic: tracks in the snow. Every living player walking on untrodden snow (a ground
-- whose Look is "Snow": the lawns, the hollow; never the swept paths) leaves prints that last LIFE
-- seconds and that everyone sees, so a trail can be followed to whoever is at its end. The prints are
-- anonymous: nothing in them says whose they are. The server records them (a client that was not
-- there still sees a trail made before it arrived) and sends them to every client in small batches;
-- FootprintController draws them. Each investigation starts on fresh snow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tracks = require(Shared:WaitForChild("Tracks"))

local Services = script.Parent.Parent.Parent:WaitForChild("Services")
local Match = require(Services:WaitForChild("Match"))
local RateLimit = require(Services:WaitForChild("RateLimit"))

local TracksRemote = Net.event("Tracks")

local UniversityCampus = {}

local SAMPLE = 0.2 -- seconds between looks at everyone's feet
local SEND = 0.5 -- seconds between batches

local map: any = nil
local origin = Vector3.zero
local recorder = Tracks.newRecorder()
local pending: { Tracks.Print } = {}
local lastPrint: { [number]: Vector3 } = {}
local side: { [number]: number } = {}
local connection: RBXScriptConnection? = nil
local requests: RBXScriptConnection? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function now(): number
	return workspace:GetServerTimeNow()
end

local function solids(): Instance?
	local scene = if map and map.model then map.model:FindFirstChild("Scene") else nil
	return if scene then scene:FindFirstChild("Solids") else nil
end

local function walkers()
	local list = {}
	for _, ps in ipairs(Match.living()) do
		local character = ps.player and ps.player.Character
		if
			character
			and ps.away ~= true
			and character:GetAttribute("Specter") == nil
			and character:GetAttribute("Spectator") == nil
		then
			table.insert(list, { ps = ps, character = character })
		end
	end
	return list
end

local function sample()
	local ground = solids()
	if not ground or Match.phase ~= "Investigation" then
		return
	end
	params.FilterDescendantsInstances = { ground }
	for _, walker in ipairs(walkers()) do
		local root = walker.character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local userId = walker.ps.userId
			local at = root.Position
			local last = lastPrint[userId]
			local moved = if last then Vector3.new(at.X - last.X, 0, at.Z - last.Z) else Vector3.zero
			if last == nil or moved.Magnitude >= Tracks.STRIDE then
				local hit = workspace:Raycast(at, Vector3.new(0, -Tracks.REACH, 0), params)
				if hit and Tracks.leavesPrint(hit.Instance:GetAttribute("Look")) then
					local direction = if moved.Magnitude > 0.05 then moved.Unit else root.CFrame.LookVector
					side[userId] = -(side[userId] or 1)
					local across = Vector3.new(-direction.Z, 0, direction.X) * Tracks.SPREAD * side[userId]
					local spot = hit.Position + across - origin
					local print_ = recorder.add(spot.X, spot.Y, spot.Z, math.atan2(direction.X, direction.Z), now())
					table.insert(pending, print_)
					lastPrint[userId] = at
				else
					-- Off the snow: the next print starts afresh where the snow begins again.
					lastPrint[userId] = at
				end
			end
		end
	end
end

local function flush()
	if #pending == 0 then
		return
	end
	TracksRemote:FireAllClients({ kind = "add", data = Tracks.encode(pending, now()), at = now() })
	table.clear(pending)
end

local function clear()
	recorder.clear()
	table.clear(pending)
	table.clear(lastPrint)
	TracksRemote:FireAllClients({ kind = "clear" })
end

function UniversityCampus.start(ctx)
	map = ctx.map
	origin = ctx.map.origin or Vector3.zero
	clear()
	local sampled, sent = 0, 0
	connection = RunService.Heartbeat:Connect(function(dt)
		sampled += dt
		sent += dt
		if sampled >= SAMPLE then
			sampled = 0
			sample()
			recorder.prune(now())
		end
		if sent >= SEND then
			sent = 0
			flush()
		end
	end)
	-- A client that joins or reloads mid-round asks for the prints already there.
	requests = TracksRemote.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or payload.action ~= "sync" or not RateLimit.allow(player, "tracksSync", 5) then
			return
		end
		local all = recorder.all(now())
		TracksRemote:FireClient(player, { kind = "clear" })
		if #all > 0 then
			TracksRemote:FireClient(player, { kind = "add", data = Tracks.encode(all, now()), at = now() })
		end
	end)
end

function UniversityCampus.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if requests then
		requests:Disconnect()
		requests = nil
	end
	clear()
	map = nil
end

function UniversityCampus.onPhase(phase: string)
	if phase == "Investigation" then
		clear()
	end
end

function UniversityCampus.debug(command: string)
	if command == "tracks" then
		return string.format("%d prints on the snow", #recorder.all(now()))
	end
	return nil
end

-- (Players leaving take their stride state with them.)
Players.PlayerRemoving:Connect(function(player)
	lastPrint[player.UserId] = nil
	side[player.UserId] = nil
end)

return UniversityCampus
