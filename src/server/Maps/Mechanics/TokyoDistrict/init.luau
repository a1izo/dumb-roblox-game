-- Tokyo's mechanic: the scramble. Its lamps really cycle (ScrambleCycle, from the map's ScrambleEpoch:
-- the crowd crosses on the walk lamp, the cars drive on theirs), a crowd of walkers a player can
-- disappear into (Crowd) and a few cars that brake and honk for anyone in their lane (Scramble).
-- Nothing of the crowd or the cars exists on the server: they are numbers, sent to every client five
-- times a second in one small unreliable snapshot (MapSync) and drawn there.
--   Intro, Briefing : the crowd walks round the cast on their marks
--   Investigation   : a fresh crowd; jaywalking is seen by the cameras
--   DeathNote       : everyone and every car comes to a stop
--   after that      : nobody about until the next round

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapSync = require(Shared:WaitForChild("MapSync"))
local Net = require(Shared:WaitForChild("Net"))
local ScrambleCycle = require(Shared:WaitForChild("ScrambleCycle"))

local Services = script.Parent.Parent.Parent:WaitForChild("Services")
local Match = require(Services:WaitForChild("Match"))

local Crowd = require(script.Crowd)
local Scramble = require(script.Scramble)

local TokyoDistrict = {}

local SEND = 1 / MapSync.RATE
local SEND_HIDDEN = 1 -- seconds between snapshots while nobody is about (they only say so)
local WATCH = 0.5 -- seconds between looks at the name tags and the jaywalkers
local STREET = 4 -- studs above or below the street a player still counts as on it

local ROADWAY = { road = true, crossing = true }
local QUIET = { Meeting = true, Vote = true, Verdict = true, Reveal = true, Outro = true }

local map: any = nil
local origin = Vector3.zero
local epoch = 0 -- when the lamps' cycle began (the map's ScrambleEpoch)
local started = 0 -- when the snapshots' clock began (the map's SyncEpoch)
local connection: RBXScriptConnection? = nil
local remote: UnreliableRemoteEvent? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Living players at street level (the map's coordinates), and those of them on the roadway.
local function players(): ({ { x: number, z: number } }, { { x: number, z: number } })
	local near, roadway = {}, {}
	for _, ps in ipairs(Match.living()) do
		local at = if ps.away ~= true then Match.position(ps) else nil
		if at then
			local p = at - origin
			if math.abs(p.Y - 3) <= STREET then
				local spot = { x = p.X, z = p.Z }
				table.insert(near, spot)
				if Scramble.on(at, ROADWAY) then
					table.insert(roadway, spot)
				end
			end
		end
	end
	return near, roadway
end

local function send(t: number)
	if remote then
		remote:FireAllClients(MapSync.encode(t - started, Crowd.record(t), Scramble.cars()))
	end
end

function TokyoDistrict.start(ctx)
	map = ctx.map
	origin = ctx.map.origin or Vector3.zero
	epoch = now()
	started = epoch
	remote = Net.unreliable("MapSync")
	Crowd.start(ctx)
	Scramble.start(ctx)
	if map.model then
		map.model:SetAttribute("CrowdSeed", ctx.rng:NextInteger(0, 9999))
		map.model:SetAttribute("SyncEpoch", started)
		map.model:SetAttribute("ScrambleEpoch", epoch)
	end
	local sent, watched = math.huge, 0
	connection = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local t = now()
		local near, roadway = players()
		local phase = ScrambleCycle.at(epoch, t)
		Crowd.step(dt, ScrambleCycle.clearFor(epoch, t), phase == "CARS" or phase == "AMBER", near)
		Crowd.onCrossing(roadway)
		Scramble.step(dt, t, epoch, roadway)
		sent += dt
		if sent >= (if Crowd.isShown() then SEND else SEND_HIDDEN) then
			sent = 0
			send(t)
		end
		watched += dt
		if watched >= WATCH then
			Crowd.cover(watched)
			Scramble.watch(t, epoch)
			watched = 0
		end
	end)
end

function TokyoDistrict.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	Crowd.stop()
	Scramble.stop()
	-- One last snapshot with nobody in it, so every client clears its street.
	if remote and map then
		remote:FireAllClients(MapSync.encode(0, {}, {}))
	end
	if map and map.model and map.model.Parent then
		map.model:SetAttribute("ScrambleEpoch", nil)
	end
	map = nil
	remote = nil
end

function TokyoDistrict.onPhase(phase: string)
	if not map then
		return
	end
	if phase == "Investigation" then
		Crowd.setMarks(nil)
		Crowd.reseed()
		Scramble.setShown(true, now())
		Scramble.setPace(1)
	elseif phase == "DeathNote" then
		Crowd.setPace(0)
		Scramble.setPace(0)
	elseif QUIET[phase] then
		Crowd.setShown(false)
		Scramble.setShown(false, now())
	end
end

-- The intro's cast stand on their marks: the crowd walks round them.
function TokyoDistrict.stageMarks(cast: { any })
	local marks = {}
	for _, role in ipairs(cast) do
		if typeof(role.cf) == "CFrame" then
			table.insert(marks, role.cf.Position)
		end
	end
	Crowd.setMarks(marks)
end

function TokyoDistrict.debug(command: string)
	if not map then
		return nil
	end
	if command == "status" then
		local phase, _, left = ScrambleCycle.at(epoch, now())
		return string.format("%s for %.0f s more; %s; %s", phase, left, Crowd.describe(), Scramble.describe())
	elseif command == "walk" or command == "cars" then
		-- Turns the cycle to the start of WALK (or CARS) now.
		local offset = if command == "cars" then ScrambleCycle.WALK + ScrambleCycle.FLASH else 0
		epoch = now() - offset
		if map.model then
			map.model:SetAttribute("ScrambleEpoch", epoch)
		end
		return "the lamps turned to " .. string.upper(command)
	end
	return nil
end

return TokyoDistrict
