-- The Tokyo crowd's maths: the same crowd from the same seed, trips between the map's ends (by the shortest way,
-- never turning back, out of the world for a few seconds at the end of each), waiting at the kerb and crossing in a
-- wave, stepping through a player who pins a walker, whose body blocks a sight line, and when a
-- player's name tag hides among them.

local Maps = script.Parent.Parent:WaitForChild("Maps")
local Mechanics = Maps:WaitForChild("Mechanics")
local CrowdSim = require(Mechanics:WaitForChild("TokyoDistrict"):WaitForChild("CrowdSim"))
-- Tokyo's generated layout, with its crowd's walks (the place keeps it under Scenes; a test bundle may hold it apart).
local TOKYO = require(
	Maps:FindFirstChild("TokyoLayout") or Maps:WaitForChild("Scenes"):WaitForChild("Tokyo"):WaitForChild("Layout")
)

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

-- A district: four ends (two edges and two doors), a crossing between two of the pavements, a spur that is nobody's
-- end, and a pavement across the top.
local TRIPS = {
	nodes = {
		{ x = 0, y = 0, z = 0, kind = "walk" },
		{ x = 40, y = 0, z = 0, kind = "kerb" },
		{ x = 40, y = 0, z = -25, kind = "kerb" },
		{ x = 0, y = 0, z = -25, kind = "walk" },
		{ x = 40, y = 0, z = 30, kind = "walk" },
		{ x = 80, y = 0, z = 0, kind = "walk" },
		{ x = 80, y = 0, z = -25, kind = "walk" },
	},
	links = {
		{ a = 1, b = 2, kind = "walk", width = 2.5 },
		{ a = 2, b = 3, kind = "crossing", width = 5 },
		{ a = 3, b = 4, kind = "walk", width = 2.5 },
		{ a = 2, b = 5, kind = "walk", width = 2.5 }, -- a spur: nobody's end
		{ a = 2, b = 6, kind = "walk", width = 2.5 },
		{ a = 3, b = 7, kind = "walk", width = 2.5 },
		{ a = 6, b = 7, kind = "walk", width = 2.5 },
	},
	ends = {
		{ node = 1, kind = "edge", weight = 1 },
		{ node = 4, kind = "door", weight = 1 },
		{ node = 6, kind = "edge", weight = 1 },
		{ node = 7, kind = "door", weight = 1 },
	},
	posts = {},
}

-- Two crossings that meet at a corner, with a way round on the pavement between their far ends.
local TRIPS_CORNER = {
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
		{ a = 5, b = 6, kind = "walk", width = 2.5 },
	},
	ends = { { node = 1, kind = "edge", weight = 1 }, { node = 6, kind = "edge", weight = 1 } },
	posts = {},
}

-- Two pavements joined by a narrow single-file stretch (the middle walk): 1 - 2 - 3 - 4.
local NARROW = {
	nodes = {
		{ x = 0, y = 0, z = 0, kind = "walk" },
		{ x = 30, y = 0, z = 0, kind = "walk" },
		{ x = 50, y = 0, z = 0, kind = "walk" },
		{ x = 80, y = 0, z = 0, kind = "walk" },
	},
	links = {
		{ a = 1, b = 2, kind = "walk", width = 3 },
		{ a = 2, b = 3, kind = "walk", width = 1, single = true },
		{ a = 3, b = 4, kind = "walk", width = 3 },
	},
	ends = { { node = 1, kind = "edge", weight = 1 }, { node = 4, kind = "edge", weight = 1 } },
	posts = {},
}

-- One long walk with a spot beside it, halfway along: a shop sign to look up at (facing -Z).
local SPOTTED = {
	nodes = { { x = 0, y = 0, z = 0, kind = "walk" }, { x = 80, y = 0, z = 0, kind = "walk" } },
	links = { { a = 1, b = 2, kind = "walk", width = 3 } },
	spots = { { x = 40, z = 3.5, rot = 0, kind = "sign", link = 1, s = 40 } },
	posts = {},
}

local DT = 1 / 30
local WALKERS = 90 -- the crowd's size (Crowd.WALKERS, on the server)

local function distance(a, b): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Puts a walker on `link`, leaving node `from`, `s` studs along it and `lateral` to its left, bound for end `dest`.
local function put(sim, walker, link: number, from: number, s: number, dest: number, lateral: number?)
	walker.dest = dest
	walker.origin = if dest == 1 then 2 else 1
	sim:_enter(walker, link, from)
	walker.s = s
	walker.lateral = lateral or walker.side
	walker.side = walker.lateral
	walker.pace, walker.speed, walker.wait, walker.linger = 12, 0, 0, 0
	walker.shown, walker.away = true, 0
	sim:_place(walker)
	walker.heading = nil
	sim:_face(walker, 0)
end

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
		it("reads which walks are single file", function()
			local graph = CrowdSim.graph({
				nodes = {
					{ x = 0, y = 0, z = 0 },
					{ x = 10, y = 0, z = 0 },
					{ x = 20, y = 0, z = 0 },
				},
				links = {
					{ a = 1, b = 2, kind = "walk", width = 1, single = true },
					{ a = 2, b = 3, kind = "walk", width = 2.5 },
				},
			})
			expect(graph.links[1].single).to.equal(true)
			expect(graph.links[2].single).to.equal(false)
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
		it("takes every dead end for an end of a trip when none are given", function()
			local graph = CrowdSim.graph(GRAPH)
			expect(#graph.ends).to.equal(2)
			expect(graph.ends[1].node).to.equal(1)
			expect(graph.ends[2].node).to.equal(4)
			-- (and every node when there is no dead end: a ring)
			local ring = CrowdSim.graph({
				nodes = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 } },
				links = { { a = 1, b = 2, width = 2 }, { a = 2, b = 3, width = 2 }, { a = 3, b = 1, width = 2 } },
			})
			expect(#ring.ends).to.equal(3)
		end)
		it("seeds walkers part-way along trips, never on a crossing", function()
			local sim = CrowdSim.new(TRIPS, Random.new(5))
			sim:seed(60)
			local midway = 0
			for _, walker in ipairs(sim.walkers) do
				if not walker.standing then
					expect(sim.graph.links[walker.link].kind).to.equal("walk")
					expect(walker.dest ~= nil and walker.dest ~= walker.origin).to.equal(true)
					expect(walker.shown).to.equal(true)
					if walker.s > 1 and walker.s < sim.graph.links[walker.link].length - 1 then
						midway += 1
					end
				end
			end
			expect(midway > 40).to.equal(true)
		end)
		it("sends each trip from one end to another, never turning back on the way", function()
			local sim = CrowdSim.new(TRIPS, Random.new(8))
			sim:seed(20)
			local ends = {}
			for _, entry in ipairs(sim.graph.ends) do
				ends[entry.node] = true
			end
			local was, arrived, visited = {}, 0, {}
			for frame = 1, math.round(300 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				for index, walker in ipairs(sim.walkers) do
					if not walker.standing then
						local before = was[index]
						local away = (walker.away or 0) > 0
						if away and (before == nil or not before.away) then
							-- A trip ended: on the end it was sent to, and no other.
							expect(sim.graph.ends[walker.dest].node).to.equal(walker.to)
							visited[walker.to] = true
							arrived += 1
						end
						-- No turning round on the way, at a dead end or anywhere else (it comes back in at an end).
						if before and not before.away and not away and walker.from ~= before.from then
							expect(walker.to ~= before.from).to.equal(true)
						end
						was[index] = { link = walker.link, from = walker.from, away = away }
					end
				end
			end
			expect(arrived > 30).to.equal(true)
			expect(sim.trips >= arrived).to.equal(true)
			-- Every end was somebody's.
			for node in pairs(ends) do
				expect(visited[node]).to.equal(true)
			end
		end)
		it(
			"takes the pavement rather than step from one crossing onto another, and the crossings when that is all there is",
			function()
				-- The kinds of walk (and where it ends up) of the way from node 1 to end 2 (node 6).
				local function route(sim)
					local kinds, node = {}, 1
					local index = sim:_first(2, node)
					while index and #kinds < 12 do
						local link = sim.graph.links[index]
						table.insert(kinds, link.kind)
						node = if link.a == node then link.b else link.a
						if node == 6 then
							break
						end
						index = sim:_next(2, index, node)
					end
					return table.concat(kinds, ","), node
				end
				-- 1 -> 6 can go over both crossings (140 studs of walking and waiting) or round on the pavement (163): the
				-- second is taken, because stepping off one crossing onto another costs more than the way round.
				local text, node = route(CrowdSim.new(TRIPS_CORNER, Random.new(1)))
				expect(node).to.equal(6)
				expect(text).to.equal("walk,crossing,walk,walk")
				-- Without the way round, the two crossings are the way.
				local bare = table.clone(TRIPS_CORNER)
				bare.links = { table.unpack(TRIPS_CORNER.links, 1, 5) }
				text, node = route(CrowdSim.new(bare, Random.new(1)))
				expect(node).to.equal(6)
				expect(text).to.equal("walk,crossing,crossing,walk")
			end
		)
		it("never goes up a dead end and back to put a crossing behind it", function()
			-- Node 3 is a corner where two crossings meet, with a short spur (3 - 5) off it. Backing out of the spur used
			-- to "reset" the cost of crossing straight onto the second crossing and was cheaper than paying it: a pointless
			-- turn, not a way on, so the way is the two crossings.
			local spur = {
				nodes = {
					{ x = 0, y = 0, z = 0, kind = "walk" },
					{ x = 30, y = 0, z = 0, kind = "kerb" },
					{ x = 30, y = 0, z = -25, kind = "kerb" },
					{ x = 55, y = 0, z = -25, kind = "kerb" },
					{ x = 30, y = 0, z = -31, kind = "walk" },
					{ x = 85, y = 0, z = -25, kind = "walk" },
				},
				links = {
					{ a = 1, b = 2, kind = "walk", width = 2.5 },
					{ a = 2, b = 3, kind = "crossing", width = 5 },
					{ a = 3, b = 4, kind = "crossing", width = 5 },
					{ a = 3, b = 5, kind = "walk", width = 2.5 },
					{ a = 4, b = 6, kind = "walk", width = 2.5 },
				},
				ends = { { node = 1, kind = "edge", weight = 1 }, { node = 6, kind = "edge", weight = 1 } },
				posts = {},
			}
			local sim = CrowdSim.new(spur, Random.new(1))
			local seen, node = {}, 1
			local index = sim:_first(2, node)
			while index and #seen < 12 do
				table.insert(seen, index)
				local link = sim.graph.links[index]
				node = if link.a == node then link.b else link.a
				if node == 6 then
					break
				end
				index = sim:_next(2, index, node)
			end
			expect(node).to.equal(6)
			expect(table.concat(seen, ",")).to.equal("1,2,3,5")
			-- And over a long run nobody walks back along the walk they have just come by.
			local run4 = CrowdSim.new(spur, Random.new(3))
			run4:seed(10)
			local was = {}
			for _ = 1, math.round(120 / DT) do
				run4:step(DT, WALK)
				for number, walker in ipairs(run4.walkers) do
					if walker.shown and not walker.standing then
						local before = was[number]
						if before and before.link ~= walker.link and walker.shown and (before.away or 0) <= 0 then
							expect(walker.to ~= before.from).to.equal(true)
						end
						was[number] = { link = walker.link, from = walker.from, away = walker.away }
					else
						was[number] = nil
					end
				end
			end
		end)
		it(
			"is out of the world for a few seconds at the end of a trip, then back at another end with somewhere new to go",
			function()
				local sim = CrowdSim.new(TRIPS, Random.new(4))
				sim:seed(8)
				local walker = sim.walkers[1]
				local dest = walker.dest
				local frames = 0
				while (walker.away or 0) <= 0 and frames < 60 * 30 do
					sim:step(DT, WALK)
					frames += 1
				end
				expect((walker.away or 0) > 0).to.equal(true)
				expect(walker.shown).to.equal(false)
				expect(walker.away >= CrowdSim.AWAY[1] and walker.away <= CrowdSim.AWAY[2]).to.equal(true)
				local spent = 0
				while (walker.away or 0) > 0 and spent < 12 * 30 do
					sim:step(DT, WALK)
					spent += 1
					if (walker.away or 0) > 0 then
						expect(walker.shown).to.equal(false)
					end
				end
				expect(spent / 30 >= CrowdSim.AWAY[1] - 0.1).to.equal(true)
				expect(spent / 30 <= CrowdSim.AWAY[2] + 0.1).to.equal(true)
				-- Back in, at an end that is not the one it went to, on its way somewhere else.
				expect(walker.shown).to.equal(true)
				expect(walker.origin ~= dest).to.equal(true)
				expect(walker.dest ~= walker.origin).to.equal(true)
				expect(sim.graph.ends[walker.origin].node).to.equal(walker.from)
			end
		)
		it("keeps a walker between trips out of the world when the crowd is shown again", function()
			local sim = CrowdSim.new(TRIPS, Random.new(4))
			sim:seed(8)
			local walker = sim.walkers[1]
			while (walker.away or 0) <= 0 do
				sim:step(DT, WALK)
			end
			sim:setShown(false)
			expect(walker.shown).to.equal(false)
			sim:setShown(true)
			expect(walker.shown).to.equal(false)
			while (walker.away or 0) > 0 do
				sim:step(DT, WALK)
			end
			expect(walker.shown).to.equal(true)
		end)
		it("chooses the ends by weight, never the one a trip starts from", function()
			local sim = CrowdSim.new({
				nodes = { { x = 0, z = 0 }, { x = 20, z = 0 }, { x = 40, z = 0 }, { x = 60, z = 0 } },
				links = { { a = 1, b = 2, width = 2 }, { a = 2, b = 3, width = 2 }, { a = 3, b = 4, width = 2 } },
				ends = {
					{ node = 1, kind = "door", weight = 8 },
					{ node = 3, kind = "edge", weight = 1 },
					{ node = 4, kind = "edge", weight = 1 },
				},
			}, Random.new(9))
			local counts = { 0, 0, 0 }
			for _ = 1, 3000 do
				counts[sim:_destination(nil)] += 1
			end
			expect(counts[1] > counts[2] * 4).to.equal(true)
			expect(counts[1] > 2000).to.equal(true)
			for _ = 1, 200 do
				expect(sim:_destination(1) ~= 1).to.equal(true)
			end
		end)
		it("is the same crowd from the same seed, trips and all", function()
			local a, b = CrowdSim.new(TRIPS, Random.new(31)), CrowdSim.new(TRIPS, Random.new(31))
			a:seed(25)
			b:seed(25)
			run(a, 120, WALK)
			run(b, 120, WALK)
			expect(a.trips).to.equal(b.trips)
			for index, walker in ipairs(a.walkers) do
				expect(walker.x).to.be.near(b.walkers[index].x, 1e-9)
				expect(walker.dest).to.equal(b.walkers[index].dest)
			end
		end)
		it(
			"holds a faster walker back behind a slower one on a narrow walk, and sends it round on a wide one",
			function()
				-- Narrow (too narrow for two): the faster one stays behind and matches the pace ahead.
				local narrow = CrowdSim.new(lane(1.4), Random.new(3))
				narrow:seed(2)
				local slow, fast = narrow.walkers[1], narrow.walkers[2]
				put(narrow, slow, 1, 1, 14, 2, 0.5)
				slow.pace = 9
				put(narrow, fast, 1, 1, 4, 2, 0.5)
				fast.pace = 15
				local nearest = math.huge
				for _ = 1, math.round(5 / DT) do
					narrow:step(DT, WALK)
					nearest = math.min(nearest, distance(slow, fast))
				end
				expect(fast.s < slow.s).to.equal(true)
				expect(nearest >= 1.5).to.equal(true)
				expect(fast.speed <= slow.speed + 1).to.equal(true)
				-- Wide: it steps out and passes, never closer than a shoulder's width.
				local wide = CrowdSim.new(lane(7), Random.new(3))
				wide:seed(2)
				slow, fast = wide.walkers[1], wide.walkers[2]
				put(wide, slow, 1, 1, 14, 2, 1.2)
				slow.pace = 9
				put(wide, fast, 1, 1, 4, 2, 1.2)
				fast.pace = 15
				nearest = math.huge
				for _ = 1, math.round(4 / DT) do
					wide:step(DT, WALK)
					nearest = math.min(nearest, distance(slow, fast))
				end
				expect(fast.s > slow.s + 2).to.equal(true)
				expect(nearest >= 1.2).to.equal(true)
			end
		)
		it("does not step out to pass into someone coming the other way", function()
			local sim = CrowdSim.new(lane(7), Random.new(3))
			sim:seed(3)
			local slow, fast, coming = sim.walkers[1], sim.walkers[2], sim.walkers[3]
			put(sim, slow, 1, 1, 14, 2, 1.2)
			slow.pace = 9
			put(sim, fast, 1, 1, 4, 2, 1.2)
			fast.pace = 15
			-- Somebody walking the other way, in the lane it would pass in, 20 studs on.
			put(sim, coming, 1, 2, 40, 1, 1.2)
			coming.pace = 12
			local nearest = math.huge
			for _ = 1, math.round(1.2 / DT) do
				sim:step(DT, WALK)
				nearest = math.min(nearest, distance(fast, coming))
				-- (Still behind the slow one, in the lane it started in, while the other is near.)
				if distance(fast, coming) < 14 then
					expect(fast.lateral > -0.3).to.equal(true)
				end
			end
			expect(nearest > 1.2).to.equal(true)
		end)
		it("lets one way at a time into a single-file stretch, the other waiting at the end of its walk", function()
			local sim = CrowdSim.new(NARROW, Random.new(2))
			sim:seed(2)
			local a, b = sim.walkers[1], sim.walkers[2]
			-- A comes to the stretch from the west, B is already in it coming from the east.
			put(sim, a, 1, 1, 24, 2)
			put(sim, b, 2, 3, 6, 1)
			local waited, nearest = false, math.huge
			for _ = 1, math.round(6 / DT) do
				sim:step(DT, WALK)
				nearest = math.min(nearest, distance(a, b))
				if a.yielding then
					waited = true
					-- (It does not go in while B is in there.)
					expect(a.link).to.equal(1)
				end
			end
			expect(waited).to.equal(true)
			-- Then it did go through, and neither walked through the other.
			expect(a.link ~= 1).to.equal(true)
			expect(nearest >= 0.95).to.equal(true) -- (a stretch a stud wide: as far apart as two can be)
			-- A trip that starts at one end of the stretch waits for those already in it coming the other way, and not for
			-- those going its way.
			local start = CrowdSim.new(NARROW, Random.new(2))
			start:seed(2)
			local inside, leaving = start.walkers[1], start.walkers[2]
			put(start, inside, 2, 3, 3, 1) -- in the stretch, heading west for node 2
			expect(start:_comingThrough(leaving, 2, 2)).to.equal(true) -- from node 2, heading east: they meet
			expect(start:_comingThrough(leaving, 2, 3)).to.equal(false) -- from node 3, heading west: the same way
		end)
		it("makes a group at the kerb in rows, nobody closer than 1.6 studs to anyone standing", function()
			local sim = CrowdSim.new(GRAPH, Random.new(6))
			sim:seed(8)
			for index = 1, 8 do
				local walker = sim.walkers[index]
				put(sim, walker, 1, 1, 6 + 2.4 * (index - 1), 2, ({ 0.7, -0.7 })[index % 2 + 1])
				walker.pace = 13 + index % 3
			end
			for _ = 1, math.round(40 / DT) do
				sim:step(DT, RED)
			end
			local standing, near = {}, 0
			for index = 1, 8 do
				local walker = sim.walkers[index]
				expect(walker.speed < 0.1).to.equal(true)
				table.insert(standing, walker)
				if walker.s > 35 then
					near += 1
				end
			end
			-- Two abreast at the kerb, the rest in rows behind.
			expect(near >= 2).to.equal(true)
			for i = 1, #standing do
				for j = i + 1, #standing do
					expect(distance(standing[i], standing[j]) >= 1.6).to.equal(true)
				end
			end
			-- And across when the lamp gives the time, in a wave.
			local nearest = math.huge
			for _ = 1, math.round(12 / DT) do
				sim:step(DT, WALK)
				for i = 1, #standing do
					for j = i + 1, #standing do
						if standing[i].shown and standing[j].shown then
							nearest = math.min(nearest, distance(standing[i], standing[j]))
						end
					end
				end
			end
			-- (Released together from side-by-side places, they pass through the one point where the walk turns onto the
			-- crossing: a few can brush for a frame or two there. Nobody is ever exactly on top of anybody.)
			expect(nearest >= 0.1).to.equal(true)
		end)
		it("keeps walkers off each other over five minutes of trips", function()
			local sim = CrowdSim.new(TRIPS, Random.new(12))
			sim:seed(24)
			local close, samples = 0, 0
			for frame = 1, math.round(300 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				if frame % 3 == 0 then
					for i = 1, #sim.walkers do
						local a = sim.walkers[i]
						for j = i + 1, #sim.walkers do
							local b = sim.walkers[j]
							if a.shown and b.shown and not a.standing and not b.standing then
								samples += 1
								if distance(a, b) < 1.2 then
									close += 1
								end
							end
						end
					end
				end
			end
			expect(sim.trips > 80).to.equal(true)
			expect(close / samples < 0.002).to.equal(true)
		end)
		it("keeps Tokyo's own crowd moving and off each other through five minutes of the lamps", function()
			local sim = CrowdSim.new(TOKYO.crowd, Random.new(1))
			sim:seed(50)
			local close, samples = 0, 0
			for frame = 1, math.round(300 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				if frame % 3 == 0 then
					for i = 1, #sim.walkers do
						local a = sim.walkers[i]
						for j = i + 1, #sim.walkers do
							local b = sim.walkers[j]
							if a.shown and b.shown and not a.standing and not b.standing then
								samples += 1
								if distance(a, b) < 1.2 then
									close += 1
								end
							end
						end
					end
				end
			end
			-- Walkers keep coming and going (no gridlock), and are within a shoulder of each other very rarely.
			expect(sim.trips > 150).to.equal(true)
			expect(close / samples < 0.0015).to.equal(true)
		end)
		it(
			"stops at a free spot it passes: steps off to it, faces it for 3 to 10 seconds, steps back and goes on",
			function()
				local sim = CrowdSim.new(SPOTTED, Random.new(5))
				sim:seed(1)
				local walker = sim.walkers[1]
				put(sim, walker, 1, 1, 10, 2, 0.8)
				walker.pace = 9
				local spot = sim.graph.spots[1]
				walker.plan, walker.planAt = spot, 40 -- (the plan _enter makes with the walker's chance)
				local stood, facing, went, nearest = 0, nil, false, math.huge
				for _ = 1, math.round(45 / DT) do
					sim:step(DT, WALK)
					if walker.visit then
						expect(spot.taken).to.equal(walker)
						went = true
						if walker.visit.phase == "stand" then
							stood += DT
							nearest = math.min(nearest, distance(walker, spot))
							facing = math.abs((walker.heading - spot.heading + math.pi) % (2 * math.pi) - math.pi)
						end
					end
				end
				expect(went).to.equal(true)
				-- It stood on the spot, facing it, for the time it stands, and the spot is free again.
				expect(nearest < 0.2).to.equal(true)
				expect(stood >= CrowdSim.STAND[1] - 0.1 and stood <= CrowdSim.STAND[2] + 0.1).to.equal(true)
				expect(facing ~= nil and facing < 0.15).to.equal(true)
				expect(spot.taken).to.equal(nil)
				expect(walker.visit).to.equal(nil)
				-- And its trip went on to the end.
				expect(sim.trips >= 1).to.equal(true)
			end
		)
		it("lets one walker at a spot, the next going on past it", function()
			local sim = CrowdSim.new(SPOTTED, Random.new(5))
			sim:seed(2)
			local first, second = sim.walkers[1], sim.walkers[2]
			put(sim, first, 1, 1, 30, 2, 0.8)
			put(sim, second, 1, 1, 8, 2, -0.8)
			first.pace, second.pace = 9, 11
			local spot = sim.graph.spots[1]
			first.plan, first.planAt = spot, 40
			second.plan, second.planAt = spot, 40
			local passed, together = false, false
			for _ = 1, math.round(20 / DT) do
				sim:step(DT, WALK)
				-- Never two of them at the spot at once, and the one that walks on never visits it.
				expect(second.visit).to.equal(nil)
				if first.visit and second.shown and distance(second, spot) < 1.5 then
					together = true
				end
				if second.s > 55 and first.visit ~= nil then
					passed = true
				end
			end
			expect(passed).to.equal(true)
			expect(together).to.equal(false)
		end)
		it("never stands still on a walk for no reason", function()
			local sim = CrowdSim.new(TRIPS, Random.new(9))
			sim:seed(24)
			local idle, worst = {}, 0
			for frame = 1, math.round(300 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				for index, walker in ipairs(sim.walkers) do
					if not walker.standing and walker.shown and (walker.away or 0) <= 0 then
						local reason = walker.waiting
							or walker.yielding
							or walker.wait > 0
							or walker.behind ~= nil
							or walker.visit ~= nil
							or walker.squeeze > 0
						if walker.speed < 0.1 and not reason then
							idle[index] = (idle[index] or 0) + DT
							worst = math.max(worst, idle[index])
						else
							idle[index] = nil
						end
					else
						idle[index] = nil
					end
				end
			end
			-- (A walker held back by the braking for a kerb is a moment from its reason: the waiting.)
			expect(worst < 1.0).to.equal(true)
		end)
		it("uses Tokyo's own spots, one walker at each, over five minutes", function()
			local sim = CrowdSim.new(TOKYO.crowd, Random.new(3))
			sim:seed(50)
			expect(#sim.graph.spots > 20).to.equal(true)
			local visits, seen = 0, {}
			for frame = 1, math.round(300 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				if frame % 15 == 0 then
					local held = 0
					for _, walker in ipairs(sim.walkers) do
						if walker.visit then
							held += 1
							expect(walker.visit.spot.taken).to.equal(walker)
							if not seen[walker] or seen[walker] ~= walker.visit.spot then
								seen[walker] = walker.visit.spot
								visits += 1
							end
						end
					end
					local taken = 0
					for _, spot in ipairs(sim.graph.spots) do
						if spot.taken then
							taken += 1
							expect(spot.taken.visit.spot).to.equal(spot)
						end
					end
					expect(taken).to.equal(held)
				end
			end
			expect(visits >= 8).to.equal(true)
		end)
		it("turns a clerk towards a player who comes by, now and then, and back again", function()
			local sim = crowd(9, 0)
			local clerk = sim.walkers[#sim.walkers]
			local home = clerk.heading
			expect(home).to.be.near(math.rad(90), 1e-9)
			-- A player four studs off, standing there for a minute: it looks, up to 40 degrees round, and looks away.
			local env = { clearFor = 0, cars = true, players = { { x = 56, z = 14 } } }
			local farthest, turned = 0, 0
			for _ = 1, math.round(60 / DT) do
				sim:step(DT, env)
				local off = math.abs((clerk.heading - home + math.pi) % (2 * math.pi) - math.pi)
				farthest = math.max(farthest, off)
				if off > math.rad(10) then
					turned += 1
				end
			end
			expect(farthest <= CrowdSim.CLERK_TURN + 0.01).to.equal(true)
			expect(farthest > math.rad(25)).to.equal(true)
			-- (it notices, it does not stare)
			expect(turned / math.round(60 / DT) < 0.6).to.equal(true)
			expect(turned / math.round(60 / DT) > 0.05).to.equal(true)
			-- With nobody near it goes back to its own way and stays there.
			env.players = {}
			run(sim, 6, env)
			expect(clerk.heading).to.be.near(home, 0.02)
			-- And a player beyond the notice does nothing.
			env.players = { { x = 60 + CrowdSim.CLERK_NOTICE + 3, z = 10 } }
			run(sim, 20, env)
			expect(clerk.heading).to.be.near(home, 0.02)
		end)
		it("finds which trips pass the hub, and picks them more often", function()
			-- TRIPS: the crossing (2 - 3) is the hub. 1 -> 4 goes over it; 6 -> 7 is a walk 40 studs from it.
			local sim = CrowdSim.new(TRIPS, Random.new(2))
			expect(sim.graph.hub ~= nil).to.equal(true)
			expect(sim.graph.hub.x).to.be.near(40, 1e-6)
			expect(sim.graph.through[1][2]).to.equal(true) -- end 1 (node 1) to end 2 (node 4)
			expect(sim.graph.through[3][4]).to.equal(nil) -- end 3 (node 6) to end 4 (node 7)
			-- From end 3, the far end 4 is on a walk that does not pass it; end 1 is over the crossing.
			local counts = { 0, 0, 0, 0 }
			for _ = 1, 3000 do
				counts[sim:_destination(3, true)] += 1
			end
			expect(counts[3]).to.equal(0)
			expect(counts[1] > counts[4] * 2).to.equal(true)
			-- Without asking for the bias, the weights alone decide.
			local plain = { 0, 0, 0, 0 }
			for _ = 1, 3000 do
				plain[sim:_destination(3)] += 1
			end
			expect(math.abs(plain[1] - plain[4]) < 300).to.equal(true)
			-- A map without a crossing has no hub and no bias.
			expect(CrowdSim.new(lane(7), Random.new(1)).graph.hub).to.equal(nil)
		end)
		it("keeps the scramble thick enough to vanish into, over five minutes with the real lamps", function()
			local sim = CrowdSim.new(TOKYO.crowd, Random.new(1))
			sim:seed(WALKERS)
			local hub = sim.graph.hub
			local walkSamples, walkThick, close, samples = 0, 0, 0, 0
			for frame = 1, math.round(300 / DT) do
				-- (The cycle: 11 s of walk, 4 of blink, 32 of cars, 3 of amber.)
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = if t < 11 then 15 - t else 0, cars = t >= 15, players = {} })
				if frame % 3 == 0 then
					local near = 0
					for i = 1, #sim.walkers do
						local a = sim.walkers[i]
						if a.shown and not a.standing then
							if (a.x - hub.x) ^ 2 + (a.z - hub.z) ^ 2 <= 25 then
								near += 1
							end
							for j = i + 1, #sim.walkers do
								local b = sim.walkers[j]
								if b.shown and not b.standing then
									samples += 1
									if distance(a, b) < 1.2 then
										close += 1
									end
								end
							end
						end
					end
					if t < 11 then
						walkSamples += 1
						if near >= 2 then
							walkThick += 1
						end
					end
				end
			end
			-- Two or more within 5 studs of the middle for most of the walk lamp, nobody stuck, few on top of each other.
			expect(walkThick / walkSamples > 0.45).to.equal(true)
			expect(sim.trips > 300).to.equal(true)
			expect(close / samples < 0.002).to.equal(true)
		end)
		it("sends the whole crowd in one snapshot, well inside what an unreliable event carries", function()
			local MapSync = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MapSync"))
			local sim = CrowdSim.new(TOKYO.crowd, Random.new(1))
			sim:seed(WALKERS)
			local cars = {}
			for index = 1, 4 do
				cars[index] = { x = 0, z = 0, heading = 0, shown = true, braking = false, kind = 0, honks = 0 }
			end
			local size = buffer.len(MapSync.encode(1, sim.walkers, cars))
			expect(#sim.walkers >= WALKERS).to.equal(true)
			expect(size < MapSync.LIMIT - 200).to.equal(true)
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
					-- (the long way round on the pavement, from the far side of one crossing to the other)
					{ a = 5, b = 6, kind = "walk", width = 2.5 },
				},
				ends = { { node = 1, kind = "edge", weight = 1 }, { node = 6, kind = "edge", weight = 1 } },
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
		it("walks at its own pace, eases up to it, and comes to a stop when told", function()
			local sim = crowd(11, 8)
			run(sim, 3, WALK)
			local moving = 0
			for _, walker in ipairs(sim.walkers) do
				if not walker.standing and walker.speed > 0.5 then
					-- (never faster than its own pace, hurrying over the crossing on the cars' light apart)
					expect(walker.speed <= walker.pace * CrowdSim.HURRY + 1e-6).to.equal(true)
					moving += 1
				end
			end
			expect(moving > 0).to.equal(true)
			sim:setPace(0)
			run(sim, CrowdSim.STOP_TIME + 1, WALK)
			for _, walker in ipairs(sim.walkers) do
				expect(walker.speed).to.be.near(0, 1e-6)
			end
		end)
		it("makes strollers, walkers and people in a hurry in the shares asked for, each at its own pace", function()
			local sim = CrowdSim.new(TOKYO.crowd, Random.new(21))
			sim:seed(300)
			local counts, total = { stroll = 0, walk = 0, hurry = 0 }, 0
			for _, walker in ipairs(sim.walkers) do
				if not walker.standing then
					total += 1
					counts[walker.kind] += 1
					for _, kind in ipairs(CrowdSim.KINDS) do
						if kind.name == walker.kind then
							expect(walker.pace >= kind.pace[1] and walker.pace <= kind.pace[2]).to.equal(true)
						end
					end
				end
			end
			expect(total > 250).to.equal(true)
			expect(math.abs(counts.stroll / total - 0.25) < 0.1).to.equal(true)
			expect(math.abs(counts.walk / total - 0.5) < 0.1).to.equal(true)
			expect(math.abs(counts.hurry / total - 0.25) < 0.1).to.equal(true)
			-- (a player walks at 16: nobody on the pavement is as fast)
			expect(CrowdSim.PACE[2] < 16).to.equal(true)
		end)
		it("eases its speed up and down, never changing it faster than a walker can", function()
			local sim = CrowdSim.new(TRIPS, Random.new(14))
			sim:seed(24)
			local before, most = {}, 0
			for frame = 1, math.round(180 / DT) do
				local t = (frame * DT) % 50
				sim:step(DT, { clearFor = math.max(0, 15 - t), cars = t >= 15, players = {} })
				for index, walker in ipairs(sim.walkers) do
					if not walker.standing and walker.shown and (walker.away or 0) <= 0 then
						if before[index] ~= nil then
							most = math.max(most, math.abs(walker.speed - before[index]) / DT)
						end
						before[index] = walker.speed
					else
						before[index] = nil
					end
				end
			end
			-- (Up to a hair over the acceleration it is asked for: a walker that has braked all the way stops at once.)
			expect(most <= CrowdSim.DECEL + 40).to.equal(true)
			-- Starting from rest, it takes about a second to reach the pace of someone in a hurry.
			local start = CrowdSim.new(lane(7), Random.new(2))
			start:seed(1)
			local walker = start.walkers[1]
			put(start, walker, 1, 1, 5, 2, 1)
			walker.pace = 14
			start:step(DT, WALK)
			expect(walker.speed <= CrowdSim.ACCEL * DT + 1e-6).to.equal(true)
			run(start, 0.5, WALK)
			expect(walker.speed < 14).to.equal(true)
			run(start, 0.5, WALK)
			expect(walker.speed).to.be.near(14, 1e-6)
		end)
		it("turns no faster than a full turn a second, and starts its turn a stud before the corner", function()
			local sim = CrowdSim.new({
				nodes = { { x = 0, z = 0 }, { x = 30, z = 0 }, { x = 30, z = -30 } },
				links = { { a = 1, b = 2, width = 3 }, { a = 2, b = 3, width = 3 } },
			}, Random.new(1))
			sim:seed(1)
			local walker = sim.walkers[1]
			put(sim, walker, 1, 1, 22, 2, 1)
			walker.pace = 14
			walker.speed = 14
			local east, north = -math.pi / 2, 0
			local last, entered, atCorner, nearly = walker.heading, nil, nil, nil
			expect(walker.heading).to.be.near(east, 1e-6)
			for frame = 1, math.round(1.5 / DT) do
				sim:step(DT, WALK)
				expect(math.abs(walker.heading - last) <= CrowdSim.TURN * DT + 1e-9).to.equal(true)
				last = walker.heading
				if walker.link == 1 and walker.s > 29.4 and not nearly then
					nearly = math.abs(walker.heading - east)
				end
				if walker.link == 2 and not entered then
					entered = frame
					atCorner = math.abs(walker.heading - north)
				end
			end
			-- Already turning as it reached the corner, not yet round it, and round it a moment later.
			expect(nearly ~= nil and nearly > 0.02).to.equal(true)
			expect(atCorner ~= nil and atCorner > 0.05).to.equal(true)
			expect(math.abs(walker.heading - north) < 0.01).to.equal(true)
		end)
		it("faces the crossing while it waits at the kerb", function()
			local sim = crowd(3, 14)
			run(sim, 40, RED)
			local checked = 0
			for _, walker in ipairs(sim.walkers) do
				if walker.waiting then
					local onward = sim.graph.links[walker.next]
					local node = sim.graph.nodes[walker.to]
					local far = sim.graph.nodes[if onward.a == walker.to then onward.b else onward.a]
					local wanted = math.atan2(node.x - far.x, node.z - far.z)
					local off = math.abs((walker.heading - wanted + math.pi) % (2 * math.pi) - math.pi)
					expect(off < 0.35).to.equal(true)
					checked += 1
				end
			end
			expect(checked > 0).to.equal(true)
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
