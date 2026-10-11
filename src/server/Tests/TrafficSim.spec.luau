-- The scramble's cars: they stop at the line on red, never come near anyone in their lane, honk no
-- more often than they should and drive on when the way is clear.

local Mechanics = script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Mechanics")
local TrafficSim = require(Mechanics:WaitForChild("TokyoDistrict"):WaitForChild("TrafficSim"))

-- One straight lane 200 studs long, its stop line 80 studs in; a second one of another road.
local DATA = {
	lanes = {
		{ points = { { 0, 0 }, { 100, 0 }, { 200, 0 } }, stop = 80, road = 1 },
		{ points = { { 0, 50 }, { 200, 50 } }, stop = 80, road = 2 },
	},
}

local DT = 1 / 30

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	-- Steps the traffic for `seconds`, calling each(sim, now) after every step.
	local function run(sim, clock: { now: number }, seconds: number, env, each: ((any, number) -> ())?)
		for _ = 1, math.round(seconds / DT) do
			clock.now += DT
			env.now = clock.now
			sim:step(DT, env)
			if each then
				each(sim, clock.now)
			end
		end
	end

	local function fresh()
		local sim = TrafficSim.new(DATA, Random.new(4))
		local clock = { now = 0 }
		return sim, clock
	end

	describe("TrafficSim lanes", function()
		it("finds a spot along a lane and back", function()
			local lane = TrafficSim.lane(DATA.lanes[1], 1)
			expect(lane.length).to.be.near(200)
			local x, z, dx, dz = TrafficSim.at(lane, 130)
			expect(x).to.be.near(130)
			expect(z).to.be.near(0)
			expect(dx).to.be.near(1)
			expect(dz).to.be.near(0)
			local s, off = TrafficSim.project(lane, 130, 3)
			expect(s).to.be.near(130)
			expect(off).to.be.near(3)
		end)
		it("keeps a lane to the cars it names", function()
			local data = { lanes = { { points = { { 0, 0 }, { 200, 0 } }, stop = 80, road = 1, kinds = { "Taxi" } } } }
			expect(TrafficSim.lane(data.lanes[1], 1).kinds[1]).to.equal(1)
			expect(TrafficSim.lane(DATA.lanes[1], 1).kinds).to.equal(nil)
			expect(TrafficSim.lane({ points = { { 0, 0 }, { 1, 0 } }, stop = 0.5, kinds = { "Tank" } }, 1).kinds).to.equal(
				nil
			)
			local sim = TrafficSim.new(data, Random.new(9))
			local now = 0
			for _ = 1, 60 * 30 do
				now += 1 / 30
				sim:step(1 / 30, { now = now, green = { true, true }, people = {} })
				if sim.cars[1].shown then
					expect(sim.cars[1].kind).to.equal(1)
				end
			end
		end)
		it("gives a lane with no road of its own the road of its pair", function()
			expect(TrafficSim.lane({ points = { { 0, 0 }, { 1, 0 } }, stop = 0.5 }, 1).road).to.equal(1)
			expect(TrafficSim.lane({ points = { { 0, 0 }, { 1, 0 } }, stop = 0.5 }, 3).road).to.equal(2)
		end)
	end)

	describe("TrafficSim", function()
		it("drives a car down a green lane and off its end", function()
			local sim, clock = fresh()
			local env = { now = 0, green = { true, true }, people = {} }
			local seen, furthest = false, 0
			run(sim, clock, 25, env, function()
				local car = sim.cars[1]
				if car.shown then
					seen = true
					furthest = math.max(furthest, car.x)
					expect(car.speed <= TrafficSim.CRUISE + 1e-6).to.equal(true)
				end
			end)
			expect(seen).to.equal(true)
			expect(furthest > 190).to.equal(true)
		end)
		it("stops with its nose at the line on red, and goes on green", function()
			local sim, clock = fresh()
			local env = { now = 0, green = { false, false }, people = {} }
			run(sim, clock, 25, env)
			local car = sim.cars[1]
			local half = TrafficSim.KINDS[car.kind].half
			expect(car.shown).to.equal(true)
			expect(car.speed).to.equal(0)
			expect(car.x + half <= 80 + 1e-6).to.equal(true)
			expect(car.x + half > 78).to.equal(true)
			-- Only its own road's lamp lets it go.
			env.green = { false, true }
			run(sim, clock, 3, env)
			expect(sim.cars[1].speed).to.equal(0)
			expect(sim.cars[2].x > 90).to.equal(true)
			env.green = { true, true }
			run(sim, clock, 3, env)
			expect(sim.cars[1].x > 90).to.equal(true)
		end)
		it("never comes within 4 studs of someone in its lane, and drives on when they leave", function()
			local sim, clock = fresh()
			local person = { x = 140, z = 1 }
			local env = { now = 0, green = { true, true }, people = { person } }
			local nearest, otherLane = math.huge, 0
			run(sim, clock, 20, env, function()
				local car = sim.cars[1]
				if car.shown then
					local half = TrafficSim.KINDS[car.kind].half
					nearest = math.min(nearest, person.x - (car.x + half))
				end
				if sim.cars[2].shown then
					otherLane = math.max(otherLane, sim.cars[2].x)
				end
			end)
			expect(nearest >= 4).to.equal(true)
			expect(nearest < TrafficSim.GAP + 0.5).to.equal(true)
			expect(sim.cars[1].speed).to.equal(0)
			-- (They are in nobody else's way: the other lane's car drove straight through.)
			expect(otherLane > 190).to.equal(true)
			env.people = {}
			run(sim, clock, 4, env)
			expect(sim.cars[1].shown == false or sim.cars[1].x > 150).to.equal(true)
		end)
		it("stops dead for someone who steps out right in front of it", function()
			local sim, clock = fresh()
			local env = { now = 0, green = { true, true }, people = {} }
			-- Wait for the car to be at speed, mid-lane.
			run(sim, clock, 25, env, function()
				local car = sim.cars[1]
				if car.shown and car.x > 100 and #env.people == 0 then
					table.insert(env.people, { x = car.x + TrafficSim.KINDS[car.kind].half + 2, z = 0 })
				end
			end)
			local car = sim.cars[1]
			local half = TrafficSim.KINDS[car.kind].half
			expect(car.shown).to.equal(true)
			expect(car.speed).to.equal(0)
			-- It was 2 studs short of them when they stepped out, and has not moved an inch nearer.
			expect(env.people[1].x - (car.x + half)).to.be.near(2, 1e-6)
		end)
		it("honks at whoever blocks its green, at most every 2.5 seconds, and never on red", function()
			local sim, clock = fresh()
			local env = { now = 0, green = { true, true }, people = { { x = 140, z = 0 } } }
			local honkTimes = {}
			local last = 0
			run(sim, clock, 20, env, function(_, now)
				local honks = sim.cars[1].honks
				if honks ~= last then
					last = honks
					table.insert(honkTimes, now)
				end
			end)
			expect(#honkTimes >= 2).to.equal(true)
			for index = 2, #honkTimes do
				expect(honkTimes[index] - honkTimes[index - 1] >= TrafficSim.HONK_EVERY - 1e-6).to.equal(true)
			end
			-- People crossing in front of a car held at its red line are left in peace.
			local quiet, quietClock = fresh()
			local red = { now = 0, green = { false, false }, people = { { x = 84, z = 0 } } }
			run(quiet, quietClock, 20, red)
			expect(quiet.cars[1].shown).to.equal(true)
			expect(quiet.cars[1].honks).to.equal(0)
		end)
		it("holds still when the traffic is told to, and keeps a new car out of an occupied lane", function()
			local sim, clock = fresh()
			local env = { now = 0, green = { false, false }, people = {} }
			run(sim, clock, 6, env)
			expect(sim.cars[1].shown).to.equal(true)
			sim:setPace(0)
			run(sim, clock, 2, env)
			local held = sim.cars[1].x
			env.green = { true, true }
			run(sim, clock, 6, env, function()
				expect(sim.cars[1].speed).to.be.near(0, 1e-6)
			end)
			expect(sim.cars[1].x).to.be.near(held, 1e-6)
			sim:setPace(1)
			run(sim, clock, 5, env)
			expect(sim.cars[1].shown == false or sim.cars[1].x > held + 20).to.equal(true)
			local blocked, blockedClock = fresh()
			local standing = { now = 0, green = { true, true }, people = { { x = 10, z = 0 } } }
			run(blocked, blockedClock, 20, standing)
			expect(blocked.cars[1].shown).to.equal(false)
		end)
	end)
end
