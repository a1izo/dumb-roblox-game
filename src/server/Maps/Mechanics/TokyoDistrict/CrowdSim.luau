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
	walker.short = if onward
			and onward.kind == "crossing"
			and entry.kind ~= "crossing"
		then self.rng:NextNumber() * 3
		else 0
	walker.side = math.min(entry.half, 0.4 + self.rng:NextNumber() * math.max(0, entry.half - 0.4))
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
			walker.passing, walker.waiting, walker.held = false, false, false
			return true
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
		walker.shown = self.visible
		self:_place(walker)
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
						return true
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
		if walker.wait > 0 then
			walker.wait -= dt
		end
		if idle then
			want = 0
		end
		walker.speed = want
		walker.s += want * dt
		local slide = dt * CrowdSim.SIDESTEP * math.clamp(want / 6, 0, 1)
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
			if walker.linger > 0 then
				walker.wait = walker.linger
				walker.linger = 0
				walker.speed = 0
			elseif walker.wait <= 0 and walker.next == nil then
				self:_arrive(walker) -- the end of its trip
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
