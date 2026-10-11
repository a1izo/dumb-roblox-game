-- The scramble's cars and its jaywalkers on the server. The cars are TrafficSim's numbers (the clients
-- draw them, World/Scramble); the lamps need no server at all (ScrambleCycle, from the map's
-- ScrambleEpoch). Someone on the crossing while the cars have their light is jaywalking: a car honks
-- and a camera may have seen it (a low sighting: it tells where someone was, it accuses nobody).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapSync = require(Shared:WaitForChild("MapSync"))
local ScrambleCycle = require(Shared:WaitForChild("ScrambleCycle"))

local Services = script.Parent.Parent.Parent.Parent:WaitForChild("Services")
local EventLog = require(Services:WaitForChild("EventLog"))
local Match = require(Services:WaitForChild("Match"))

local TrafficSim = require(script.Parent.TrafficSim)

local Scramble = {}

Scramble.JAYWALK_EVERY = 20 -- seconds between two sightings of the same jaywalker
Scramble.HONK_REACH = 70 -- studs: the nearest car this close honks at a jaywalker

local sim = nil
local map: any = nil
local origin = Vector3.zero
local shown = false

-- Whether a player's feet are on a kind of ground (root position: the feet are 3 studs below).
function Scramble.on(at: Vector3, kinds: { [string]: boolean }): boolean
	local zones = map and map.zones
	if not zones then
		return false
	end
	for _, kind in ipairs(zones:kindsAt(at - Vector3.new(0, 3, 0))) do
		if kinds[kind] then
			return true
		end
	end
	return false
end

-- Each signal over a lane learns which road it rules (the nearest stop line's): the clients read it.
local function markSignals()
	local scene = map.model and map.model:FindFirstChild("Scene")
	if not scene or not sim then
		return
	end
	local stops = {}
	for _, lane in ipairs(sim.lanes) do
		local x, z = TrafficSim.at(lane, lane.stop)
		table.insert(stops, { at = origin + Vector3.new(x, 0, z), road = lane.road })
	end
	for _, item in ipairs(scene:GetChildren()) do
		if item:IsA("Model") and item:GetAttribute("DeathsGambitProp") == "TrafficSignal" then
			local pivot = item:GetPivot().Position
			local best, bestDistance = nil, math.huge
			for _, stop in ipairs(stops) do
				local d = (Vector3.new(pivot.X, 0, pivot.Z) - stop.at).Magnitude
				if d < bestDistance then
					best, bestDistance = stop, d
				end
			end
			if best then
				item:SetAttribute("Road", best.road)
			end
		end
	end
end

function Scramble.start(ctx)
	map = ctx.map
	origin = ctx.map.origin or Vector3.zero
	local data = ctx.map.layout and ctx.map.layout.traffic
	if type(data) ~= "table" or #(data.lanes or {}) == 0 then
		sim = nil
		return
	end
	sim = TrafficSim.new(data, Random.new(ctx.rng:NextInteger(1, 2 ^ 30)))
	sim:clear(workspace:GetServerTimeNow())
	shown = true
	markSignals()
end

function Scramble.stop()
	sim = nil
	map = nil
	shown = false
end

-- Empty lanes; the cars come back by themselves when shown.
function Scramble.setShown(on: boolean, now: number)
	shown = on
	if sim then
		sim:clear(now)
	end
end

function Scramble.setPace(pace: number)
	if sim then
		sim:setPace(pace)
	end
end

-- people: whoever is on the roadway, in the map's coordinates.
function Scramble.step(dt: number, now: number, epoch: number, people: { { x: number, z: number } })
	if not sim or not shown then
		return
	end
	local green = {}
	for road = 1, ScrambleCycle.ROADS do
		green[road] = ScrambleCycle.roadLamp(epoch, now, road) == "green"
	end
	sim:step(dt, { now = now, green = green, people = people })
end

local CROSSING = { crossing = true }

-- Jaywalkers (looked for twice a second).
function Scramble.watch(now: number, epoch: number)
	if not map or Match.phase ~= "Investigation" or not ScrambleCycle.jaywalking(epoch, now) then
		return
	end
	for _, ps in ipairs(Match.living()) do
		local at = if ps.away ~= true then Match.position(ps) else nil
		if at and Scramble.on(at, CROSSING) then
			EventLog.sighting(ps, "was jaywalking", at, {
				priority = EventLog.LOW,
				where = "at the scramble",
				key = "jaywalk",
				every = Scramble.JAYWALK_EVERY,
			})
			if sim and shown then
				local car, distance = sim:nearest(at.X - origin.X, at.Z - origin.Z)
				if car and distance <= Scramble.HONK_REACH then
					sim:honk(car, now)
				end
			end
		end
	end
end

-- The snapshot's cars.
function Scramble.cars(): { MapSync.Car }
	local list = {}
	if sim then
		for i, car in ipairs(sim.cars) do
			list[i] = {
				x = car.x,
				z = car.z,
				heading = car.heading,
				shown = shown and car.shown,
				braking = car.braking == true,
				kind = car.kind - 1,
				honks = car.honks,
			}
		end
	end
	return list
end

function Scramble.describe(): string
	if not sim then
		return "no cars on this map"
	end
	local out = 0
	for _, car in ipairs(sim.cars) do
		if car.shown then
			out += 1
		end
	end
	return string.format("%d of %d cars out", out, #sim.cars)
end

return Scramble
