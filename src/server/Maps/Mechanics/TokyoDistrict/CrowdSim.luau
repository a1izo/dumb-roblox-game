-- The Tokyo crowd as plain maths: no Humanoids, no parts, nothing in the world. Walkers follow the
-- map's walk graph (layout.crowd: nodes, links, ends, posts), each on a trip from one end of the map to another
-- (the station's doors, the map's edge, a shop's door) by the shortest way, keep to the left of each walk (Japan),
-- wait on the kerb for the walk signal and cross together when it comes, slow and step round a player in
-- their way and, held up for PIN_TIME, walk through them (and each client lets its own player through sooner
-- when a body would trap them: World/Crowd). At the end of its trip a walker leaves the world for a few seconds (it
-- went through a door, or off down the street) and comes back at another end with somewhere new to go. Now and then
-- one stops at the end of a walk for a moment (a shop window, a phone) before going on, as people do. A few stand at
-- posts all match (clerks).
-- Positions are in the map's own coordinates (the server adds nothing: clients add the map's origin).
-- Everything here is deterministic for a given Random, so the specs can step it by hand.

local CrowdSim = {}
CrowdSim.__index = CrowdSim

CrowdSim.PACE = { 13.5, 16 } -- studs a second: a player walks at 16
CrowdSim.BODY_RADIUS = 1.0 -- a walker's body for sight lines: a pillar this wide...
CrowdSim.BODY_HEIGHT = 5.2 -- ...and this tall
CrowdSim.NOTICE = 9 -- studs ahead a walker minds a player in its way
CrowdSim.SIDESTEP = 3.5 -- studs a second a walker drifts across its walk (at a walking pace: nobody slides sideways standing)
CrowdSim.SHOULDER = 2.6 -- how far to one side a player is still minded...
CrowdSim.SQUARELY = 2.0 -- ...and how far to one side they still bar the way (two bodies' half widths)
CrowdSim.PIN_TIME = 1.0 -- seconds held up before a walker steps through whoever blocks it
CrowdSim.PAUSE = 0.12 -- the share of walks a walker stops at the end of for a moment (never by a crossing)...
CrowdSim.PAUSE_TIME = { 1.5, 4 } -- ...for this many seconds
CrowdSim.STOP_TIME = 1.5 -- seconds the whole crowd takes to come to a stop (or start again)
CrowdSim.HURRY = 1.4 -- caught on the crossing when the cars get their light
CrowdSim.AWAY = { 2, 8 } -- seconds a walker is out of the world at the end of a trip, before it comes back at another end
-- A player's name tag hides inside the crowd: COVER_COUNT walkers within COVER_IN studs; it shows
-- again once fewer are within COVER_OUT for COVER_HOLD seconds.
CrowdSim.COVER_COUNT = 2
CrowdSim.COVER_IN = 5
CrowdSim.COVER_OUT = 6
CrowdSim.COVER_HOLD = 0.5

-- What a way costs a trip, in studs of walking: a crossing adds the wait for the lamp, and stepping straight from one
-- crossing onto another (waiting on the roadway) a good deal more, so a trip takes the pavement unless it is far
-- longer.
local CROSSING_COST = 15
local DOUBLE_COST = 60

-- How walkers mind each other (all in studs): each looks LOOK ahead for someone in its way, keeps GAP behind them and
-- is held back by anyone within CAP_ZONE of its line; two side by side steer apart to SEP (inside ZONE), and someone
-- still BEHIND it by that much counts as alongside (a walker passing). BRAKE: how fast the speed it may keep falls
-- with the gap. A walker steps out to pass only if nobody is coming the other way within ONCOMING. MIN_SIDE: the least
-- a walker keeps to its left, so two coming from opposite ends are never closer than twice that. ARRIVE_CLEAR: a walker
-- does not come in (or start) at an end that somebody is standing within this much of.
local CELL = 6
local LOOK = 6
local BEHIND = 2.2
local GAP = 1.8
local CAP_ZONE = 1.5
local SEP = 1.8
local ZONE = 2.2
local BRAKE = 5
local ONCOMING = 14
local MIN_SIDE = 0.65
local SAME = 0.6 -- the cosine of the turn between two headings within which walkers hold each other back (about 53 degrees)
local STUCK = 3 -- seconds held back for no good reason before a walker squeezes by...
local SQUEEZE = 1.5 -- ...for this long
local ARRIVE_CLEAR = 2.2

export type Env = {
	clearFor: number, -- seconds until the cars go, while the walk lamp lets people start (0 otherwise)
	cars: boolean, -- the cars have their light (or amber)
	players: { { x: number, z: number } }, -- living players, in the map's coordinates
	marks: { { x: number, z: number } }?, -- spots nobody walks through (the intro's cast)
}

local function farEnd(link, node: number): number
	return if link.a == node then link.b else link.a
end

-- A min-heap of { priority, value } pairs (for the routes below).
local function heapPush(heap, priority: number, value: number)
	table.insert(heap, { priority, value })
	local at = #heap
	while at > 1 do
		local up = at // 2
		if heap[up][1] <= heap[at][1] then
			break
		end
		heap[up], heap[at] = heap[at], heap[up]
		at = up
	end
end

local function heapPop(heap): (number, number)
	local top = heap[1]
	local last = table.remove(heap) :: any
	if #heap > 0 then
		heap[1] = last
		local at = 1
		while true do
			local left, right = at * 2, at * 2 + 1
			local least = at
			if left <= #heap and heap[left][1] < heap[least][1] then
				least = left
			end
			if right <= #heap and heap[right][1] < heap[least][1] then
				least = right
			end
			if least == at then
				break
			end
			heap[least], heap[at] = heap[at], heap[least]
			at = least
		end
	end
	return top[1], top[2]
end

-- The cheapest ways to one node: for each state (node * 2 + 0 when the walker came to the node by a walk, + 1 when it
-- came by a crossing) the link to take next. The state matters because stepping from one crossing straight onto
-- another costs more than a crossing after a walk.
local function routesTo(graph, target: number): { [number]: number }
	local nodes, links = graph.nodes, graph.links
	local best: { [number]: number } = {}
	local hop: { [number]: number } = {}
	local heap = {}
	for kind = 0, 1 do
		best[target * 2 + kind] = 0
		heapPush(heap, 0, target * 2 + kind)
	end
	while #heap > 0 do
		local distance, state = heapPop(heap)
		if distance <= (best[state] or math.huge) then
			local node, kind = state // 2, state % 2
			for _, index in ipairs(nodes[node].out) do
				local link = links[index]
				if (if link.kind == "crossing" then 1 else 0) == kind then
					local from = farEnd(link, node)
					for before = 0, 1 do
						local cost = link.length
						if link.kind == "crossing" then
							cost += CROSSING_COST + (if before == 1 then DOUBLE_COST else 0)
						end
						local key = from * 2 + before
						if distance + cost < (best[key] or math.huge) then
							best[key] = distance + cost
							hop[key] = index
							heapPush(heap, distance + cost, key)
						end
					end
				end
			end
		end
	end
	return hop
end

-- The graph: every node with the ways out of it, where trips begin and end (data.ends: node, kind "edge" or "door",
-- weight; with none given, every dead end, or every node of a graph without one) and the cheapest way to each end
-- from everywhere.
function CrowdSim.graph(data)
	local nodes, links = {}, {}
	for i, node in ipairs(data.nodes or {}) do
		nodes[i] = { x = node.x, y = node.y or 0, z = node.z, kind = node.kind or "walk", out = {} }
	end
	for _, link in ipairs(data.links or {}) do
		local a, b = nodes[link.a], nodes[link.b]
		if a and b and a ~= b then
			local entry = {
				a = link.a,
				b = link.b,
				kind = link.kind or "walk",
				half = (link.width or 2) / 2,
				single = link.single == true, -- too narrow for two to pass: one way at a time
				length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2),
			}
			table.insert(links, entry)
			table.insert(a.out, #links)
			table.insert(b.out, #links)
		end
	end
	local graph = { nodes = nodes, links = links, posts = data.posts or {}, ends = {}, endWeight = 0, hops = {} }
	-- A run of single-file walks that meet end to end is one narrow way (a corridor): it takes people one way at a
	-- time. Each such walk knows its corridor and which of its two ways is the corridor's forward.
	local corridors = 0
	local function extend(index: number, node: number, forward: boolean)
		while #nodes[node].out == 2 do
			local nextIndex = if nodes[node].out[1] == index then nodes[node].out[2] else nodes[node].out[1]
			local nextLink = links[nextIndex]
			if not nextLink.single or nextLink.corridor then
				return
			end
			nextLink.corridor = corridors
			nextLink.forward = if forward then node == nextLink.a else node == nextLink.b
			index, node = nextIndex, if node == nextLink.a then nextLink.b else nextLink.a
		end
	end
	for index, link in ipairs(links) do
		if link.single and not link.corridor then
			corridors += 1
			link.corridor = corridors
			link.forward = true
			extend(index, link.b, true)
			extend(index, link.a, false)
		end
	end
	local given = data.ends
	if given == nil or #given == 0 then
		given = {}
		for i, node in ipairs(nodes) do
			if #node.out == 1 then
				table.insert(given, { node = i, kind = "edge", weight = 1 })
			end
		end
		if #given < 2 then
			given = {}
			for i = 1, #nodes do
				table.insert(given, { node = i, kind = "edge", weight = 1 })
			end
		end
	end
	for _, entry in ipairs(given) do
		if nodes[entry.node] and (entry.weight or 1) > 0 then
			table.insert(graph.ends, { node = entry.node, kind = entry.kind or "edge", weight = entry.weight or 1 })
			graph.endWeight += entry.weight or 1
		end
	end
	for index, entry in ipairs(graph.ends) do
		graph.hops[index] = routesTo(graph, entry.node)
	end
	return graph
end

function CrowdSim.new(data, rng: Random?)
	local self = setmetatable({}, CrowdSim)
	self.graph = CrowdSim.graph(data)
	self.rng = rng or Random.new()
	self.walkers = {}
	self.scale = 1 -- the crowd's pace, eased towards `target`
	self.target = 1
	self.visible = true -- false between rounds (setShown): nobody is in the world, whatever else they are doing
	self.trips = 0 -- trips finished since the sim began
	self.grid = {} -- where everyone is at the start of a step (see _grid)
	return self
end

local function other(link, node: number): number
	return if link.a == node then link.b else link.a
end

-- The end (an index into graph.ends) a new trip goes to: chosen by weight, never `from` (the end it starts at).
function CrowdSim:_destination(from: number?): number
	local ends = self.graph.ends
	local total = self.graph.endWeight - (if from then ends[from].weight else 0)
	local roll = self.rng:NextNumber() * total
	for index, entry in ipairs(ends) do
		if index ~= from then
			roll -= entry.weight
			if roll < 0 then
				return index
			end
		end
	end
	return if from == 1 then #ends else 1
end

-- The way on from a node on the way to end `dest`, for a walker that came to it over a way of kind `arrived`; nil
-- when the node is the end itself (or there is no way to it).
function CrowdSim:_hop(dest: number, node: number, arrived: string): number?
	return self.graph.hops[dest][node * 2 + (if arrived == "crossing" then 1 else 0)]
end

-- Puts a walker on `link` leaving `from`, and settles what it will do at the far end.
function CrowdSim:_enter(walker, link: number, from: number)
	local graph = self.graph
	local entry = graph.links[link]
	walker.link = link
	walker.from = from
	walker.to = other(entry, from)
	walker.s = 0
	walker.next = self:_hop(walker.dest, walker.to, entry.kind)
	local onward = walker.next and graph.links[walker.next]
	-- Waiting for the lamp, each stands a little short of the kerb, so a group forms (on the
	-- pavement: never short of a kerb it reaches over the roadway).
	walker.short = if onward and onward.kind == "crossing" and entry.kind ~= "crossing" then 0.5 else 0
	walker.side = math.min(entry.half, MIN_SIDE + self.rng:NextNumber() * math.max(0, entry.half - MIN_SIDE))
	walker.linger = 0
	-- A moment's pause where the walk ends (a look in a window, at a phone), never on or before a crossing, and never
	-- at the end of the trip (it goes in or off there).
	local plain = entry.kind ~= "crossing" and onward ~= nil and onward.kind ~= "crossing"
	if plain and self.rng:NextNumber() < CrowdSim.PAUSE then
		local least, most = CrowdSim.PAUSE_TIME[1], CrowdSim.PAUSE_TIME[2]
		walker.linger = least + self.rng:NextNumber() * (most - least)
	end
end

-- Sends a walker off on a new trip from end `origin` to a fresh end: it starts on the first walk of the way, at its
-- node, with nothing left of its last trip. false when no way leads there.
function CrowdSim:_depart(walker, origin: number): boolean
	local graph = self.graph
	for _ = 1, 8 do
		local dest = self:_destination(origin)
		local first = graph.hops[dest][graph.ends[origin].node * 2]
		if first then
			walker.origin, walker.dest = origin, dest
			self:_enter(walker, first, graph.ends[origin].node)
			walker.lateral = walker.side
			walker.wait, walker.pinned, walker.speed = 0, 0, 0
			walker.stuck, walker.squeeze, walker.yielding, walker.behind = 0, 0, false, nil
			walker.passing, walker.waiting, walker.held = false, false, false
			return true
		end
	end
	return false
end

local function cellKey(cx: number, cz: number): number
	return (cx + 100) * 1000 + (cz + 100)
end

-- Where everyone is at the start of a step (a snapshot, so every walker decides from the same moment), binned in
-- CELL-stud squares: 50 bodies are cheap to rebuild each step.
function CrowdSim:_grid()
	local grid = self.grid
	table.clear(grid)
	for _, walker in ipairs(self.walkers) do
		if not walker.standing and walker.shown and (walker.away or 0) <= 0 then
			local key = cellKey(math.floor(walker.x / CELL), math.floor(walker.z / CELL))
			local bucket = grid[key]
			if not bucket then
				bucket = {}
				grid[key] = bucket
			end
			table.insert(bucket, {
				walker = walker,
				x = walker.x,
				z = walker.z,
				dx = walker.dx,
				dz = walker.dz,
				speed = walker.speed,
				-- standing for the lamp or for a pause, which nobody else's moving decides: an obstacle from any side
				fixed = walker.waiting or walker.wait > 0,
			})
		end
	end
end

-- Whether anyone is coming the other way within ONCOMING ahead of `walker`, near the sideways place `offset` (studs to
-- its left of where it is now): someone it would walk into if it stepped out there.
function CrowdSim:_oncoming(walker, offset: number): boolean
	local px, pz, dx, dz = walker.x, walker.z, walker.dx, walker.dz
	local nx, nz = dz, -dx
	local reach = math.ceil(ONCOMING / CELL)
	local cx, cz = math.floor(px / CELL), math.floor(pz / CELL)
	for gx = cx - reach, cx + reach do
		for gz = cz - reach, cz + reach do
			local bucket = self.grid[cellKey(gx, gz)]
			if bucket then
				for _, o in ipairs(bucket) do
					if o.walker ~= walker and o.dx * dx + o.dz * dz < -0.3 then
						local rx, rz = o.x - px, o.z - pz
						local ahead = rx * dx + rz * dz
						if ahead > 0 and ahead < ONCOMING and math.abs(rx * nx + rz * nz - offset) < SEP - 0.2 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- The way a walker is looking: along its walk, or, within LOOK_BEND of the end of it, towards where the path goes on
-- round the corner (so it sees whoever stands there, and is not walked into by whoever turns in front of it).
local LOOK_BEND = 3

function CrowdSim:_lookAhead(walker, entry): (number, number)
	local reach = walker.s + LOOK_BEND - entry.length
	if reach > 0 and walker.next then
		local graph = self.graph
		local onward = graph.links[walker.next]
		local from = graph.nodes[walker.to]
		local to = graph.nodes[other(onward, walker.to)]
		local length = math.max(onward.length, 1e-3)
		local along = math.min(reach, length) / length
		local vx = from.x + (to.x - from.x) * along - walker.x
		local vz = from.z + (to.z - from.z) * along - walker.z
		local size = math.sqrt(vx * vx + vz * vz)
		if size > 0.3 then
			return vx / size, vz / size
		end
	end
	return walker.dx, walker.dz
end

-- What the others about a walker ask of it: the speed it may keep (studs a second; huge when nobody is in its way) and
-- the sideways place (studs to the left of the walk's line) it should make for, or nil when nobody is near. Anyone
-- ahead within CAP_ZONE of its line, standing or walking the same way, holds it back so that it keeps GAP behind them;
-- it steers away from anyone alongside, round a slower walker or a standing one if the walk is wide enough, to the
-- right (where those coming the other way keep to) only when none of them is near.
function CrowdSim:_social(walker, entry): (number, number?, any)
	local px, pz = walker.x, walker.z
	local cx, cz = math.floor(px / CELL), math.floor(pz / CELL)
	local cap, blocker = math.huge, nil
	local needRight, needLeft, near = 0, 0, false
	-- It looks along its walk (holding back and steering by what it sees), and, near the end of it, also towards where
	-- the path goes on round the corner (holding back only): whoever stands at the kerb it is turning towards is seen
	-- from the first, and whoever has turned in front of it from the second.
	local lookX, lookZ = self:_lookAhead(walker, entry)
	local bends = lookX * walker.dx + lookZ * walker.dz < 0.98
	for pass = 1, if bends then 2 else 1 do
		local dx, dz = walker.dx, walker.dz
		if pass == 2 then
			dx, dz = lookX, lookZ
		end
		local nx, nz = dz, -dx
		for gx = cx - 1, cx + 1 do
			for gz = cz - 1, cz + 1 do
				local bucket = self.grid[cellKey(gx, gz)]
				if bucket then
					for _, o in ipairs(bucket) do
						local same = o.dx * dx + o.dz * dz
						if o.walker ~= walker and (same > SAME or o.fixed) then
							local rx, rz = o.x - px, o.z - pz
							local ahead = rx * dx + rz * dz
							local left = rx * nx + rz * nz
							local reach = math.abs(left)
							if ahead > -BEHIND and ahead < LOOK and reach < ZONE then
								if pass == 1 then
									near = true
									if reach < SEP then
										-- (someone dead ahead: it steps to the side with more room)
										local awayRight = if reach < 0.3 then walker.lateral >= 0 else left >= 0
										if awayRight then
											needRight = math.max(needRight, SEP - reach)
										else
											needLeft = math.max(needLeft, SEP - reach)
										end
									end
								end
								if ahead > 0 and reach < CAP_ZONE then
									local along = math.max(0, o.speed * same)
									local limit = math.max(0, along + (ahead - GAP) * BRAKE)
									if limit < cap then
										cap, blocker = limit, o.walker
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if not near then
		return cap, nil, blocker
	end
	local shift = 0
	if needRight > 0 and needLeft == 0 then
		shift = -needRight
	elseif needLeft > 0 and needRight == 0 then
		shift = needLeft
	end
	local target = math.clamp(walker.lateral + shift, -entry.half, entry.half)
	if target < walker.lateral and target < 0.3 and self:_oncoming(walker, target - walker.lateral) then
		target = walker.lateral -- (somebody is coming along the side it would step out to: it holds back instead)
	end
	return cap, target, blocker
end

-- Whether `walker`, at `node` and about to enter the single-file walk `link`, must wait: somebody is
-- already on that narrow way (or on the corridor of narrow walks it belongs to) going the other way. Someone who has
-- come to the end of their walk is on their way out of it, not in it.
function CrowdSim:_comingThrough(walker, link: number, node: number): boolean
	local links = self.graph.links
	local mine = links[link]
	local mineForward = (node == mine.a) == mine.forward
	for _, o in ipairs(self.walkers) do
		if o ~= walker and o.shown and not o.standing and (o.away or 0) <= 0 then
			local theirs = links[o.link]
			if theirs.corridor == mine.corridor and o.s < theirs.length - 0.8 then
				if ((o.from == theirs.a) == theirs.forward) ~= mineForward then
					return true
				end
			end
		end
	end
	return false
end

-- Whether a walker held back is waiting for a reason: somebody ahead of it, or somebody ahead of them and so on, is
-- standing for the lamp, a narrow way or a pause, rather than everybody waiting for everybody.
function CrowdSim:_queued(walker): boolean
	local ahead = walker.behind
	for _ = 1, 12 do
		if ahead == nil then
			return false
		end
		if ahead.waiting or ahead.yielding or ahead.wait > 0 then
			return true
		end
		ahead = ahead.behind
	end
	return false
end

-- Whether somebody stands within `radius` of a spot (other than `except`).
function CrowdSim:_crowded(x: number, z: number, radius: number, except): boolean
	for _, o in ipairs(self.walkers) do
		if o ~= except and o.shown and not o.standing and (o.away or 0) <= 0 then
			if (o.x - x) ^ 2 + (o.z - z) ^ 2 < radius * radius then
				return true
			end
		end
	end
	return false
end

-- The end of a trip: the walker is out of the world for a few seconds (through a door, off down the street).
function CrowdSim:_arrive(walker)
	local least, most = CrowdSim.AWAY[1], CrowdSim.AWAY[2]
	walker.away = least + self.rng:NextNumber() * (most - least)
	walker.shown = false
	walker.speed = 0
	walker.next = nil
	self.trips += 1
end

-- Back in the world at an end (by weight, not the one it left by) with somewhere new to go.
function CrowdSim:_return(walker)
	walker.away = 0
	local origin = self:_destination(walker.dest)
	if self:_depart(walker, origin) then
		self:_place(walker)
		local first = self.graph.links[walker.link]
		if
			self:_crowded(walker.x, walker.z, ARRIVE_CLEAR, walker)
			or (first.single and self:_comingThrough(walker, walker.link, walker.from))
		then
			walker.away = 0.5 -- (somebody stands in the doorway, or comes along the narrow way: a moment longer)
			walker.shown = false
		else
			walker.shown = self.visible
		end
	else
		walker.away = 1 -- (nowhere to go from there: try again in a moment)
	end
end

local function place(self, walker)
	local graph = self.graph
	local entry = graph.links[walker.link]
	local a, b = graph.nodes[walker.from], graph.nodes[walker.to]
	local length = math.max(entry.length, 1e-3)
	local dx, dz = (b.x - a.x) / length, (b.z - a.z) / length
	local t = math.clamp(walker.s / length, 0, 1)
	-- (The left of travel: -X when walking along -Z.)
	walker.x = a.x + (b.x - a.x) * t + dz * walker.lateral
	walker.z = a.z + (b.z - a.z) * t - dx * walker.lateral
	walker.y = a.y + (b.y - a.y) * t
	walker.dx, walker.dz = dx, dz
	if walker.speed > 0.5 or walker.heading == nil then
		walker.heading = math.atan2(-dx, -dz)
	end
end

function CrowdSim:_place(walker)
	place(self, walker)
end

-- Puts a new walker part-way along a trip (a random one between two ends, never on a crossing), so a street is not
-- empty when the crowd is made. false when no trip could be found (a graph with no way between its ends).
function CrowdSim:_seedOnTrip(walker): boolean
	local graph = self.graph
	for _ = 1, 20 do
		local origin = self:_destination(nil)
		local dest = self:_destination(origin)
		local target = graph.ends[dest].node
		local node, arrived = graph.ends[origin].node, "walk"
		local route, length = {}, 0
		while node ~= target and #route <= #graph.links do
			local index = self:_hop(dest, node, arrived)
			if not index then
				break
			end
			local link = graph.links[index]
			table.insert(route, { index = index, from = node })
			if link.kind ~= "crossing" then
				length += link.length
			end
			node, arrived = other(link, node), link.kind
		end
		if node == target and length > 0 then
			local roll = self.rng:NextNumber() * length
			for _, step in ipairs(route) do
				local link = graph.links[step.index]
				if link.kind ~= "crossing" then
					if roll < link.length then
						walker.origin, walker.dest = origin, dest
						self:_enter(walker, step.index, step.from)
						walker.s = math.max(0, math.min(roll, link.length - walker.short))
						walker.lateral = walker.side
						place(self, walker)
						local free = not self:_crowded(walker.x, walker.z, 2.4, walker)
						if free and link.single and self:_comingThrough(walker, step.index, step.from) then
							free = false
						end
						if free then
							return true
						end
						break
					end
					roll -= link.length
				end
			end
		end
	end
	return false
end

-- Fills the crowd: `count` walkers part-way along trips between the map's ends (never on a crossing), and one
-- standing body at every post. Whoever was there before is gone.
function CrowdSim:seed(count: number)
	local graph = self.graph
	table.clear(self.walkers)
	self.visible = true
	for _ = 1, if #graph.ends >= 2 then count else 0 do
		local walker = {
			pace = CrowdSim.PACE[1] + self.rng:NextNumber() * (CrowdSim.PACE[2] - CrowdSim.PACE[1]),
			speed = 0,
			lateral = 0,
			pinned = 0,
			wait = 0,
			away = 0,
			stuck = 0,
			squeeze = 0,
			yielding = false,
			passing = false,
			waiting = false,
			standing = false,
			shown = true,
		}
		if self:_seedOnTrip(walker) then
			table.insert(self.walkers, walker)
		end
	end
	for _, post in ipairs(graph.posts) do
		table.insert(self.walkers, {
			x = post.x,
			y = post.y or 0,
			z = post.z,
			heading = math.rad(post.rot or 0),
			speed = 0,
			passing = false,
			waiting = false,
			standing = true,
			shown = true,
		})
	end
end

-- The crowd's pace from now on: 1 walks, 0 comes to a stop (over STOP_TIME).
function CrowdSim:setPace(target: number)
	self.target = math.clamp(target, 0, 1)
end

function CrowdSim:setShown(shown: boolean)
	self.visible = shown
	for _, walker in ipairs(self.walkers) do
		-- (a walker out of the world at the end of its trip stays out of it: it comes back when its time is up)
		walker.shown = shown and (walker.away or 0) <= 0
	end
end

-- How a player ahead holds a walker up: the pace left to it (0 to 1) and which way to step (-1, 0, 1:
-- towards its right, nowhere, towards its left), and whether anyone is close at all.
local function mind(walker, players): (number, number, boolean)
	local pace, step, close = 1, 0, false
	for _, player in ipairs(players) do
		local rx, rz = player.x - walker.x, player.z - walker.z
		if rx * rx + rz * rz < 9 then
			close = true
		end
		local ahead = rx * walker.dx + rz * walker.dz
		local left = rx * walker.dz - rz * walker.dx
		if ahead > 0 and ahead < CrowdSim.NOTICE and math.abs(left) < CrowdSim.SHOULDER then
			-- Step to the side the player is not on. Squarely in the way, slow down the nearer they
			-- are, to a stop at arm's length; with room to pass their shoulder, only ease off.
			step = if left >= 0 then -1 else 1
			local room = if math.abs(left) < CrowdSim.SQUARELY
				then (ahead - 2) / (CrowdSim.NOTICE - 2)
				else 0.5 + ahead / CrowdSim.NOTICE
			pace = math.min(pace, math.clamp(room, 0, 1))
		end
	end
	return pace, step, close
end

function CrowdSim:step(dt: number, env: Env)
	local graph = self.graph
	local ease = dt / CrowdSim.STOP_TIME
	self.scale += math.clamp(self.target - self.scale, -ease, ease)
	self:_grid()
	for _, walker in ipairs(self.walkers) do
		if (walker.away or 0) > 0 then
			walker.away -= dt
			if walker.away <= 0 then
				self:_return(walker)
			end
			continue
		end
		if walker.standing or not walker.shown then
			continue
		end
		local entry = graph.links[walker.link]
		local want = walker.pace * self.scale
		local goal = walker.side
		-- The others about it: held back behind someone in its way, steering round or away from them.
		local cap, around, blocker = self:_social(walker, entry)
		walker.behind = blocker
		walker.yielding = false
		if around then
			goal = around
		end
		-- The kerb: wait there until the lamp gives time enough to get across.
		local onward = walker.next and graph.links[walker.next]
		walker.waiting = false
		if onward and onward.kind == "crossing" and walker.s >= entry.length - walker.short then
			local needs = (entry.length - walker.s + onward.length) / walker.pace + 0.5
			if env.clearFor < needs then
				walker.waiting = true
				walker.held = true
			elseif walker.held then
				-- (Nobody steps off at the very same instant.)
				walker.held = false
				walker.wait = self.rng:NextNumber() * 0.6
			end
		end
		local idle = walker.waiting or walker.wait > 0
		-- A mark in the way (someone staged for the intro): stop short of it, for as long as it is there.
		if env.marks then
			local pace, step = mind(walker, env.marks)
			want *= pace
			if step ~= 0 then
				goal = step * entry.half
			end
		end
		-- Players in the way: step aside and slow; held up for PIN_TIME, walk through them.
		local pace, step, close = mind(walker, env.players)
		if walker.passing then
			if not close then
				walker.passing = false
				walker.pinned = 0
			end
		else
			if step ~= 0 then
				goal = step * entry.half
			end
			want *= pace
			if pace < 0.25 and not idle and self.scale > 0.5 then
				walker.pinned += dt
				if walker.pinned >= CrowdSim.PIN_TIME then
					walker.passing = true
				end
			else
				walker.pinned = math.max(0, walker.pinned - dt * 0.5)
			end
		end
		if entry.kind == "crossing" and env.cars then
			want *= CrowdSim.HURRY
		end
		-- Held back by someone in its way. A walker held up for STUCK seconds by people who are not themselves waiting
		-- for anything squeezes by for a moment (nobody is stuck for good, however the crowd has knotted itself).
		if walker.squeeze > 0 then
			walker.squeeze -= dt
		else
			if want > 2 and cap < 1 and not idle and not self:_queued(walker) then
				walker.stuck += dt
				if walker.stuck >= STUCK then
					walker.stuck = 0
					walker.squeeze = SQUEEZE
				end
			else
				walker.stuck = math.max(0, walker.stuck - dt * 2)
			end
			want = math.min(want, cap)
		end
		if walker.wait > 0 then
			walker.wait -= dt
		end
		if idle then
			want = 0
		end
		walker.speed = want
		walker.s += want * dt
		-- (Held back behind someone and steering round them, it shuffles sideways as it edges on.)
		local steering = if around and math.abs(around - walker.lateral) > 0.05 then 3 else 0
		local slide = dt * CrowdSim.SIDESTEP * math.clamp(math.max(want, steering) / 6, 0, 1)
		walker.lateral += math.clamp(goal - walker.lateral, -slide, slide)
		-- (A walker whose step took it past the kerb before it had stopped for it looks at the lamp again: it is not let
		-- onto a crossing it has no time for.)
		if walker.s >= entry.length and not walker.waiting and onward and onward.kind == "crossing" then
			if env.clearFor < onward.length / walker.pace + 0.5 then
				walker.waiting = true
				walker.held = true
				walker.speed = 0
			end
		end
		if walker.s >= entry.length and not walker.waiting then
			walker.s = entry.length
			if walker.linger > 0 and self:_crowded(walker.x, walker.z, GAP, walker) then
				walker.linger = 0 -- (somebody is at the spot: it goes on instead)
			end
			if walker.linger > 0 then
				walker.wait = walker.linger
				walker.linger = 0
				walker.speed = 0
			elseif walker.wait <= 0 and walker.next == nil then
				self:_arrive(walker) -- the end of its trip
			elseif
				walker.wait <= 0
				and graph.links[walker.next].single
				and self:_comingThrough(walker, walker.next, walker.to)
			then
				walker.speed = 0 -- a narrow walk takes one way at a time: it waits here for those coming along it
				walker.yielding = true
			elseif walker.wait <= 0 then
				-- Onto the next walk from where it stands: its place beside the old walk's line,
				-- measured along and across the new one, so it turns the corner without a sideways
				-- jump and drifts over to its own side again as it goes.
				local ox, oz = walker.dz * walker.lateral, -walker.dx * walker.lateral
				self:_enter(walker, walker.next, walker.to)
				local onto = graph.links[walker.link]
				local a, b = graph.nodes[walker.from], graph.nodes[walker.to]
				local length = math.max(onto.length, 1e-3)
				local dx, dz = (b.x - a.x) / length, (b.z - a.z) / length
				walker.s = math.clamp(ox * dx + oz * dz, 0, length)
				walker.lateral = math.clamp(ox * dz - oz * dx, -onto.half, onto.half)
			end
		end
		place(self, walker)
	end
end

-- Sight lines ------------------------------------------------------------------------------------

-- Whether the straight line between two points (the map's coordinates) passes through one of the
-- bodies ({ x, y, z }: a pillar BODY_RADIUS wide and BODY_HEIGHT tall on its y). A body either end of
-- the line stands inside (someone shoulder to shoulder with a walker) does not block it.
function CrowdSim.blocks(bodies, from: Vector3, to: Vector3): boolean
	local dx, dz = to.X - from.X, to.Z - from.Z
	local span = dx * dx + dz * dz
	local radius = CrowdSim.BODY_RADIUS * CrowdSim.BODY_RADIUS
	for _, body in ipairs(bodies) do
		local fx, fz = body.x - from.X, body.z - from.Z
		local tx, tz = body.x - to.X, body.z - to.Z
		if fx * fx + fz * fz > radius and tx * tx + tz * tz > radius then
			local t = if span > 1e-6 then math.clamp((fx * dx + fz * dz) / span, 0, 1) else 0
			local cx, cz = from.X + dx * t - body.x, from.Z + dz * t - body.z
			if cx * cx + cz * cz < radius then
				local y = from.Y + (to.Y - from.Y) * t
				local base = body.y or 0
				if y >= base and y <= base + CrowdSim.BODY_HEIGHT then
					return true
				end
			end
		end
	end
	return false
end

-- Name tags -----------------------------------------------------------------------------------------

-- How many bodies stand within `radius` of a spot.
function CrowdSim.near(bodies, x: number, z: number, radius: number): number
	local count = 0
	for _, body in ipairs(bodies) do
		if (body.x - x) ^ 2 + (body.z - z) ^ 2 <= radius * radius then
			count += 1
		end
	end
	return count
end

-- One player's cover, stepped: state = { hidden, clear }; returns whether the tag is hidden now.
function CrowdSim.cover(state, bodies, x: number, z: number, dt: number): boolean
	if not state.hidden then
		if CrowdSim.near(bodies, x, z, CrowdSim.COVER_IN) >= CrowdSim.COVER_COUNT then
			state.hidden = true
			state.clear = 0
		end
	elseif CrowdSim.near(bodies, x, z, CrowdSim.COVER_OUT) < CrowdSim.COVER_COUNT then
		state.clear = (state.clear or 0) + dt
		if state.clear >= CrowdSim.COVER_HOLD then
			state.hidden = false
		end
	else
		state.clear = 0
	end
	return state.hidden == true
end

return CrowdSim
