-- The Tokyo scramble's cars as plain maths (like CrowdSim: nothing in the world, the clients draw them).
-- One car at a time drives each lane of the map's layout.traffic: in from where the lane starts, up
-- to its stop line while its road's lamp is not green, over the junction and out. A car never comes
-- nearer than GAP studs to anyone standing in its lane: it brakes, stops dead if it must, honks (at
-- most every HONK_EVERY seconds) and drives on once the lane is clear. It never touches anyone.
-- Positions are in the map's own coordinates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapSync = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapSync"))

local TrafficSim = {}
TrafficSim.__index = TrafficSim

TrafficSim.CRUISE = 26 -- studs a second
TrafficSim.ACCEL = 14
TrafficSim.BRAKE = 30
TrafficSim.GAP = 5 -- studs a car's nose keeps short of anyone in its lane
TrafficSim.REACH = 3.8 -- how far from the lane's middle someone is still in it (half a car and a body)
TrafficSim.HONK_EVERY = 2.5
TrafficSim.HONK_WITHIN = 25 -- studs: a car honks at whoever stops it from this near
TrafficSim.SPAWN = { 3, 12 } -- seconds a lane stays empty between two cars
TrafficSim.CLEAR = 30 -- studs of a lane's start that must be empty for a car to appear
-- Half the length of each model a car can be, in MapSync.CARS' order (Taxi, Car, KeiTruck).
TrafficSim.KINDS = {
	{ half = 7.0 },
	{ half = 5.45 },
	{ half = 5.45 },
}

export type Env = {
	now: number,
	green: { [number]: boolean }, -- by road: whether its cars may pass their stop line
	people: { { x: number, z: number } }, -- whoever is on the roadway (players and crossing walkers)
}

-- A lane ready to drive: its points with the distance along it of each.
function TrafficSim.lane(data, index: number)
	local points, along, length = {}, { 0 }, 0
	for i, p in ipairs(data.points) do
		points[i] = { x = p[1], z = p[2] }
		if i > 1 then
			length += math.sqrt((p[1] - data.points[i - 1][1]) ^ 2 + (p[2] - data.points[i - 1][2]) ^ 2)
			along[i] = length
		end
	end
	-- The only models that drive this lane (a taxi rank's lane takes taxis), when it names any.
	local kinds = {}
	for _, key in ipairs(data.kinds or {}) do
		local kind = table.find(MapSync.CARS, key)
		if kind and TrafficSim.KINDS[kind] then
			table.insert(kinds, kind)
		end
	end
	return {
		points = points,
		along = along,
		length = length,
		stop = data.stop,
		road = data.road or math.ceil(index / 2),
		kinds = if #kinds > 0 then kinds else nil,
	}
end

-- The spot `s` studs along a lane and the way the lane runs there.
function TrafficSim.at(lane, s: number): (number, number, number, number)
	local points, along = lane.points, lane.along
	local last = #points
	for i = 2, last do
		if s <= along[i] or i == last then
			local a, b = points[i - 1], points[i]
			local span = math.max(along[i] - along[i - 1], 1e-3)
			local t = (s - along[i - 1]) / span -- (past either end: straight on)
			local dx, dz = (b.x - a.x) / span, (b.z - a.z) / span
			return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, dx, dz
		end
	end
	return points[1].x, points[1].z, 0, -1
end

-- Where a spot is along a lane (the nearest point of it) and how far to its side.
function TrafficSim.project(lane, x: number, z: number): (number, number)
	local points, along = lane.points, lane.along
	local best, bestS = math.huge, 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local span = dx * dx + dz * dz
		local t = if span > 1e-6 then math.clamp(((x - a.x) * dx + (z - a.z) * dz) / span, 0, 1) else 0
		local cx, cz = a.x + dx * t - x, a.z + dz * t - z
		local d = cx * cx + cz * cz
		if d < best then
			best, bestS = d, along[i - 1] + (along[i] - along[i - 1]) * t
		end
	end
	return bestS, math.sqrt(best)
end

function TrafficSim.new(data, rng: Random?)
	local self = setmetatable({}, TrafficSim)
	self.rng = rng or Random.new()
	self.lanes = {}
	self.cars = {}
	self.scale = 1 -- the traffic's pace (0: everything holds still), eased like the crowd's
	self.target = 1
	for index, lane in ipairs(data.lanes or {}) do
		self.lanes[index] = TrafficSim.lane(lane, index)
		self.cars[index] = { lane = index, shown = false, kind = 1, s = 0, speed = 0, honks = 0, honkAt = -math.huge }
	end
	self:clear(0)
	return self
end

-- Empties every lane; the first cars come a little after `now`.
function TrafficSim:clear(now: number)
	for index, car in ipairs(self.cars) do
		car.shown = false
		car.braking = false
		car.speed = 0
		car.dueAt = now + index * 1.5 + self.rng:NextNumber() * 3
		car.x, car.z, car.heading = 0, 0, 0
	end
end

function TrafficSim:setPace(target: number)
	self.target = math.clamp(target, 0, 1)
end

-- The nearest person standing in a lane between two distances along it (how far along they are).
local function inLane(lane, people, from: number, to: number): number?
	local nearest: number? = nil
	for _, person in ipairs(people) do
		local s, off = TrafficSim.project(lane, person.x, person.z)
		if off <= TrafficSim.REACH and s >= from and s <= to and (nearest == nil or s < nearest) then
			nearest = s
		end
	end
	return nearest
end

function TrafficSim:step(dt: number, env: Env)
	local ease = dt / 1.5
	self.scale += math.clamp(self.target - self.scale, -ease, ease)
	for index, car in ipairs(self.cars) do
		local lane = self.lanes[index]
		if not car.shown then
			-- A new car, once the lane's first stretch is empty.
			if env.now >= car.dueAt and self.scale > 0.5 and inLane(lane, env.people, 0, TrafficSim.CLEAR) == nil then
				car.kind = if lane.kinds
					then lane.kinds[self.rng:NextInteger(1, #lane.kinds)]
					else self.rng:NextInteger(1, #TrafficSim.KINDS)
				car.shown = true
				car.through = false
				car.holding = false
				car.s = 0
				car.speed = TrafficSim.CRUISE * 0.6
			else
				continue
			end
		end
		local half = TrafficSim.KINDS[car.kind].half
		local nose = car.s + half
		local limit = math.huge
		-- The stop line, unless the lamp is green or the car is past stopping for it. Whether it
		-- can still stop is settled once, when the lamp turns (or the car appears): a car that has
		-- begun to hold for the line holds until its green.
		if not car.through then
			if nose > lane.stop + 0.05 then
				car.through = true
			elseif env.green[lane.road] then
				car.holding = false
			else
				if not car.holding then
					if lane.stop - nose >= car.speed * car.speed / (2 * TrafficSim.BRAKE) then
						car.holding = true
					else
						car.through = true -- (the lamp changed too late to stop)
					end
				end
				if car.holding then
					limit = lane.stop - half
				end
			end
		end
		-- Whoever is in the lane ahead (or beside the car: it will not pull away into them). It honks
		-- only when the way is its own: never at people crossing on their walk lamp.
		local person = inLane(lane, env.people, car.s - half, math.huge)
		local blocked = false
		if person then
			local hold = person - TrafficSim.GAP - half
			if hold < limit then
				limit = hold
				blocked = (car.through or env.green[lane.road] == true) and person - nose <= TrafficSim.HONK_WITHIN
			end
		end
		local room = math.max(0, limit - car.s)
		local want = math.min(TrafficSim.CRUISE * self.scale, math.sqrt(2 * TrafficSim.BRAKE * room))
		local before = car.speed
		car.speed = if want < before then want else math.min(want, before + TrafficSim.ACCEL * dt)
		car.s = math.min(car.s + car.speed * dt, math.max(car.s, limit))
		if car.s >= limit then
			car.speed = 0
		end
		car.braking = car.speed < before - 0.01 or (car.speed < 1 and self.scale > 0.5)
		if blocked and car.speed < TrafficSim.CRUISE * 0.5 and env.now - car.honkAt >= TrafficSim.HONK_EVERY then
			car.honkAt = env.now
			car.honks += 1
		end
		if car.s - half >= lane.length then
			car.shown = false
			car.dueAt = env.now
				+ TrafficSim.SPAWN[1]
				+ self.rng:NextNumber() * (TrafficSim.SPAWN[2] - TrafficSim.SPAWN[1])
			continue
		end
		local x, z, dx, dz = TrafficSim.at(lane, car.s)
		car.x, car.z = x, z
		car.heading = math.atan2(-dx, -dz)
	end
end

-- The nearest shown car to a spot and how far it is (nil when no car is out).
function TrafficSim:nearest(x: number, z: number)
	local best, bestDistance = nil, math.huge
	for _, car in ipairs(self.cars) do
		if car.shown then
			local d = math.sqrt((car.x - x) ^ 2 + (car.z - z) ^ 2)
			if d < bestDistance then
				best, bestDistance = car, d
			end
		end
	end
	return best, bestDistance
end

-- A honk from a car that is not being blocked (someone jaywalking nearby): the same limit applies.
function TrafficSim:honk(car, now: number): boolean
	if now - car.honkAt < TrafficSim.HONK_EVERY then
		return false
	end
	car.honkAt = now
	car.honks += 1
	return true
end

return TrafficSim
