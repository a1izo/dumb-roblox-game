-- The Tokyo crowd's maths: the same crowd from the same seed, waiting at the kerb and crossing in a
-- wave, stepping through a player who pins a walker, whose body blocks a sight line, and when a
-- player's name tag hides among them.

local Mechanics = script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Mechanics")
local CrowdSim = require(Mechanics:WaitForChild("TokyoDistrict"):WaitForChild("CrowdSim"))

-- Two walks either side of a road, a zebra between their kerbs, a clerk at a post.
local GRAPH = {
	nodes = {
		{ x = 0, y = 0, z = 0, kind = "walk" },
		{ x = 40, y = 0, z = 0, kind = "kerb" },
		{ x = 40, y = 0, z = -25, kind = "kerb" },
		{ x = 0, y = 0, z = -25, kind = "walk" },
	},
	links = {
		{ a = 1, b = 2, kind = "walk", width = 2.5 },
		{ a = 2, b = 3, kind = "crossing", width = 5 },
		{ a = 3, b = 4, kind = "walk", width = 2.5 },
	},
	posts = { { x = 60, y = 0, z = 10, rot = 90 } },
}

-- One long walk, as wide as asked.
local function lane(width: number)
	return {
		nodes = { { x = 0, y = 0, z = 0, kind = "walk" }, { x = 80, y = 0, z = 0, kind = "walk" } },
		links = { { a = 1, b = 2, kind = "walk", width = width } },
		posts = {},
	}
end

local DT = 1 / 30

local function crowd(seed: number, count: number)
	local sim = CrowdSim.new(GRAPH, Random.new(seed))
	sim:seed(count)
	return sim
end

local function run(sim, seconds: number, env)
	for _ = 1, math.round(seconds / DT) do
		sim:step(DT, env)
	end
end

local function onCrossing(sim): number
	local count = 0
	for _, walker in ipairs(sim.walkers) do
		if not walker.standing and sim.graph.links[walker.link].kind == "crossing" then
			count += 1
		end
	end
	return count
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local RED = { clearFor = 0, cars = true, players = {} }
	local WALK = { clearFor = 15, cars = false, players = {} }

	describe("CrowdSim", function()
		it("seeds the walkers on the walks, never on a crossing, and one body per post", function()
			local sim = crowd(7, 12)
			expect(#sim.walkers).to.equal(13)
			expect(onCrossing(sim)).to.equal(0)
			local clerk = sim.walkers[13]
			expect(clerk.standing).to.equal(true)
			expect(clerk.x).to.equal(60)
			expect(clerk.heading).to.be.near(math.rad(90))
		end)
		it("is the same crowd from the same seed", function()
			local a, b = crowd(42, 10), crowd(42, 10)
			run(a, 20, WALK)
			run(b, 20, WALK)
			for index, walker in ipairs(a.walkers) do
				expect(walker.x).to.be.near(b.walkers[index].x, 1e-9)
				expect(walker.z).to.be.near(b.walkers[index].z, 1e-9)
			end
			local c = crowd(43, 10)
			run(c, 20, WALK)
			local same = true
			for index, walker in ipairs(a.walkers) do
				if math.abs(walker.x - c.walkers[index].x) > 0.01 then
					same = false
				end
			end
			expect(same).to.equal(false)
		end)
		it("waits at the kerb while the cars have their light", function()
			local sim = crowd(3, 14)
			local waited = 0
			for _ = 1, math.round(40 / DT) do
				sim:step(DT, RED)
				expect(onCrossing(sim)).to.equal(0)
			end
			for _, walker in ipairs(sim.walkers) do
				if walker.waiting then
					waited += 1
					-- (Short of the kerb's node, on its own side of the road.)
					expect(math.abs(walker.z) <= 1.3 or math.abs(walker.z + 25) <= 1.3).to.equal(true)
				end
			end
			expect(waited > 0).to.equal(true)
		end)
		it("crosses in a wave on the walk lamp, and is across before the cars go", function()
			local sim = crowd(3, 14)
			run(sim, 40, RED)
			local most = 0
			for _ = 1, math.round(4 / DT) do
				sim:step(DT, WALK)
				most = math.max(most, onCrossing(sim))
			end
			expect(most >= 2).to.equal(true)
			-- Nobody starts across with too little time left.
			local late = crowd(5, 14)
			run(late, 40, RED)
			run(late, 3, { clearFor = 1, cars = false, players = {} })
			expect(onCrossing(late)).to.equal(0)
		end)
		it("never steps from one crossing straight onto another, nor waits on the roadway", function()
			-- A corner where two crossings meet, with pavement leading away from it.
			local corner = {
				nodes = {
					{ x = 0, y = 0, z = 0, kind = "walk" },
					{ x = 30, y = 0, z = 0, kind = "kerb" },
					{ x = 30, y = 0, z = -25, kind = "kerb" },
					{ x = 55, y = 0, z = -25, kind = "kerb" },
					{ x = 30, y = 0, z = -55, kind = "walk" },
					{ x = 85, y = 0, z = -25, kind = "walk" },
				},
				links = {
					{ a = 1, b = 2, kind = "walk", width = 2.5 },
					{ a = 2, b = 3, kind = "crossing", width = 5 },
					{ a = 3, b = 4, kind = "crossing", width = 5 },
					{ a = 3, b = 5, kind = "walk", width = 2.5 },
					{ a = 4, b = 6, kind = "walk", width = 2.5 },
				},
				posts = {},
			}
			local sim = CrowdSim.new(corner, Random.new(21))
			sim:seed(16)
			local was = {}
			local crossed = 0
			for frame = 1, math.round(240 / DT) do
				-- The lamps go round: 15 s of walk in every 50.
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				for index, walker in ipairs(sim.walkers) do
					local kind = sim.graph.links[walker.link].kind
					if walker.waiting then
						expect(kind).to.equal("walk")
					end
					if was[index] ~= nil and was[index].link ~= walker.link then
						if was[index].kind == "crossing" then
							expect(kind).to.equal("walk")
							crossed += 1
						end
					end
					was[index] = { link = walker.link, kind = kind }
				end
			end
			expect(crossed > 10).to.equal(true)
		end)
		it("leaves the standing where they are", function()
			local sim = crowd(9, 6)
			run(sim, 30, WALK)
			local clerk = sim.walkers[#sim.walkers]
			expect(clerk.x).to.equal(60)
			expect(clerk.z).to.equal(10)
			expect(clerk.speed).to.equal(0)
		end)
		it("walks at a player's pace and comes to a stop when told", function()
			local sim = crowd(11, 8)
			run(sim, 1, WALK)
			local moving = 0
			for _, walker in ipairs(sim.walkers) do
				if not walker.standing and walker.speed > 0 then
					expect(walker.speed >= CrowdSim.PACE[1] - 1e-6).to.equal(true)
					expect(walker.speed <= CrowdSim.PACE[2] * CrowdSim.HURRY + 1e-6).to.equal(true)
					moving += 1
				end
			end
			expect(moving > 0).to.equal(true)
			sim:setPace(0)
			run(sim, CrowdSim.STOP_TIME + 0.2, WALK)
			for _, walker in ipairs(sim.walkers) do
				expect(walker.speed).to.be.near(0, 1e-6)
			end
		end)
		it("walks round a player when the walk is wide enough", function()
			local sim = CrowdSim.new(lane(7), Random.new(1))
			sim:seed(1)
			local walker = sim.walkers[1]
			walker.s, walker.wait, walker.linger = 10, 0, 0
			sim:step(DT, RED)
			local player = { x = walker.x + walker.dx * 6, z = walker.z + walker.dz * 6 }
			local env = { clearFor = 0, cars = true, players = { player } }
			local nearest, passed = math.huge, false
			for _ = 1, math.round(3 / DT) do
				sim:step(DT, env)
				expect(walker.passing).to.equal(false)
				nearest = math.min(nearest, math.sqrt((player.x - walker.x) ^ 2 + (player.z - walker.z) ^ 2))
				if (player.x - walker.x) * walker.dx + (player.z - walker.z) * walker.dz < -2 then
					passed = true
				end
			end
			expect(passed).to.equal(true)
			expect(nearest > 1.9).to.equal(true)
		end)
		it("stops short of a player in its way, then steps through after being pinned", function()
			local sim = CrowdSim.new(lane(1), Random.new(1))
			sim:seed(1)
			local walker = sim.walkers[1]
			-- Put the player 4 studs ahead of the walker, squarely in its way, and keep them there.
			local env = { clearFor = 0, cars = true, players = { { x = 0, z = 0 } } }
			local function block()
				env.players[1].x = walker.x + walker.dx * 4
				env.players[1].z = walker.z + walker.dz * 4
			end
			walker.s, walker.wait, walker.linger = 10, 0, 0
			sim:step(DT, { clearFor = 0, cars = true, players = {} })
			block()
			local nearest = math.huge
			local steppedAt = nil
			for frame = 1, math.round(3 / DT) do
				sim:step(DT, env)
				local gap = math.sqrt((env.players[1].x - walker.x) ^ 2 + (env.players[1].z - walker.z) ^ 2)
				if not walker.passing then
					nearest = math.min(nearest, gap)
				elseif not steppedAt then
					steppedAt = frame * DT
				end
			end
			-- It never walked into them before giving up on going round.
			expect(nearest > 1.5).to.equal(true)
			expect(steppedAt ~= nil).to.equal(true)
			expect(steppedAt >= CrowdSim.PIN_TIME).to.equal(true)
			-- Once clear of them it is in the way again.
			env.players[1].x, env.players[1].z = 500, 500
			sim:step(DT, env)
			expect(walker.passing).to.equal(false)
		end)
		it("never steps through a mark of the intro's cast", function()
			local sim = CrowdSim.new(GRAPH, Random.new(1))
			sim:seed(1)
			local walker = sim.walkers[1]
			walker.s, walker.wait, walker.linger = 10, 0, 0
			sim:step(DT, RED)
			local mark = { x = walker.x + walker.dx * 4, z = walker.z + walker.dz * 4 }
			local env = { clearFor = 0, cars = true, players = {}, marks = { mark } }
			for _ = 1, math.round(4 / DT) do
				sim:step(DT, env)
				expect(walker.passing).to.equal(false)
				local gap = math.sqrt((mark.x - walker.x) ^ 2 + (mark.z - walker.z) ^ 2)
				expect(gap > 1.5).to.equal(true)
			end
		end)
	end)

	describe("CrowdSim.blocks", function()
		local body = { { x = 10, y = 0, z = 0 } }
		it("blocks a line through a body", function()
			expect(CrowdSim.blocks(body, Vector3.new(0, 4.5, 0), Vector3.new(20, 4.5, 0))).to.equal(true)
			expect(CrowdSim.blocks(body, Vector3.new(0, 4.5, 0.9), Vector3.new(20, 4.5, 0.9))).to.equal(true)
		end)
		it("lets a line past its shoulder, over its head or stopping short of it", function()
			expect(CrowdSim.blocks(body, Vector3.new(0, 4.5, 1.2), Vector3.new(20, 4.5, 1.2))).to.equal(false)
			expect(CrowdSim.blocks(body, Vector3.new(0, 6, 0), Vector3.new(20, 6, 0))).to.equal(false)
			expect(CrowdSim.blocks(body, Vector3.new(0, 4.5, 0), Vector3.new(8, 4.5, 0))).to.equal(false)
		end)
		it("lets someone on an upper floor look down past it", function()
			-- From 14 studs up, 4 studs out: the line is above its head where it passes it.
			expect(CrowdSim.blocks(body, Vector3.new(6, 18, 0), Vector3.new(30, 4.5, 0))).to.equal(false)
		end)
		it("does not blind someone standing shoulder to shoulder with it", function()
			expect(CrowdSim.blocks(body, Vector3.new(10.5, 4.5, 0), Vector3.new(30, 4.5, 0))).to.equal(false)
			expect(CrowdSim.blocks(body, Vector3.new(-10, 4.5, 0), Vector3.new(9.6, 4.5, 0))).to.equal(false)
		end)
		it("blocks nothing with nobody about", function()
			expect(CrowdSim.blocks({}, Vector3.new(0, 4.5, 0), Vector3.new(20, 4.5, 0))).to.equal(false)
		end)
	end)

	describe("CrowdSim.cover", function()
		local two = { { x = 1, y = 0, z = 0 }, { x = -2, y = 0, z = 3 } }
		local one = { { x = 1, y = 0, z = 0 } }
		it("hides a name tag with two bodies close by, not with one", function()
			expect(CrowdSim.cover({ hidden = false, clear = 0 }, two, 0, 0, 0.5)).to.equal(true)
			expect(CrowdSim.cover({ hidden = false, clear = 0 }, one, 0, 0, 0.5)).to.equal(false)
			expect(CrowdSim.cover({ hidden = false, clear = 0 }, two, 5, 0, 0.5)).to.equal(false)
		end)
		it("shows it again only once the crowd has been gone for half a second", function()
			local state = { hidden = false, clear = 0 }
			expect(CrowdSim.cover(state, two, 0, 0, 0.25)).to.equal(true)
			expect(CrowdSim.cover(state, one, 0, 0, 0.25)).to.equal(true)
			expect(CrowdSim.cover(state, two, 0, 0, 0.25)).to.equal(true)
			expect(CrowdSim.cover(state, one, 0, 0, 0.25)).to.equal(true)
			expect(CrowdSim.cover(state, one, 0, 0, 0.25)).to.equal(false)
		end)
		it("keeps it hidden a step further out than it took to hide it", function()
			local state = { hidden = false, clear = 0 }
			local ring = { { x = 5.5, y = 0, z = 0 }, { x = -5.5, y = 0, z = 0 } }
			expect(CrowdSim.cover(state, ring, 0, 0, 1)).to.equal(false)
			state.hidden = true
			expect(CrowdSim.cover(state, ring, 0, 0, 1)).to.equal(true)
		end)
	end)
end
