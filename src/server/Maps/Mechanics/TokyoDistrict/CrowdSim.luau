-- The Tokyo crowd as plain maths: no Humanoids, no parts, nothing in the world. Walkers follow the
-- map's walk graph (layout.crowd: nodes, links, posts), keep to the left of each walk (Japan), wait
-- on the kerb for the walk signal and cross together when it comes, slow and step round a player in
-- their way and, held up for PIN_TIME, walk through them. A few stand at posts all match (clerks).
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
CrowdSim.STOP_TIME = 1.5 -- seconds the whole crowd takes to come to a stop (or start again)
CrowdSim.HURRY = 1.4 -- caught on the crossing when the cars get their light
-- A player's name tag hides inside the crowd: COVER_COUNT walkers within COVER_IN studs; it shows
-- again once fewer are within COVER_OUT for COVER_HOLD seconds.
CrowdSim.COVER_COUNT = 2
CrowdSim.COVER_IN = 5
CrowdSim.COVER_OUT = 6
CrowdSim.COVER_HOLD = 0.5

local CROSSING_WEIGHT = 2 -- how much likelier a walker is to take a crossing than another way on

export type Env = {
	clearFor: number, -- seconds until the cars go, while the walk lamp lets people start (0 otherwise)
	cars: boolean, -- the cars have their light (or amber)
	players: { { x: number, z: number } }, -- living players, in the map's coordinates
	marks: { { x: number, z: number } }?, -- spots nobody walks through (the intro's cast)
}

-- The graph: every node with the ways out of it.
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
				length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2),
			}
			table.insert(links, entry)
			table.insert(a.out, #links)
			table.insert(b.out, #links)
		end
	end
	return { nodes = nodes, links = links, posts = data.posts or {} }
end

function CrowdSim.new(data, rng: Random?)
	local self = setmetatable({}, CrowdSim)
	self.graph = CrowdSim.graph(data)
	self.rng = rng or Random.new()
	self.walkers = {}
	self.scale = 1 -- the crowd's pace, eased towards `target`
	self.target = 1
	return self
end

local function other(link, node: number): number
	return if link.a == node then link.b else link.a
end

-- The way on from a node. offCrossing: the walker has just come over a crossing, and does not step
-- straight onto another (it would have to wait for the lamp standing on the roadway) while there is
-- pavement to take.
function CrowdSim:_pick(node: number, cameFrom: number?, offCrossing: boolean?): number?
	local graph = self.graph
	local out = graph.nodes[node].out
	local total, weights = 0, {}
	local function weigh(pavementOnly: boolean)
		total = 0
		for i, index in ipairs(out) do
			local link = graph.links[index]
			local weight = if cameFrom ~= nil and other(link, node) == cameFrom
				then 0
				elseif link.kind == "crossing" then (if pavementOnly then 0 else CROSSING_WEIGHT)
				else 1
			weights[i] = weight
			total += weight
		end
	end
	weigh(offCrossing == true)
	if total <= 0 and offCrossing then
		weigh(false)
	end
	if total <= 0 then
		return out[1] -- a dead end: back the way it came
	end
	local roll = self.rng:NextNumber() * total
	for i, weight in ipairs(weights) do
		roll -= weight
		if roll < 0 then
			return out[i]
		end
	end
	return out[#out]
end

-- Puts a walker on `link` leaving `from`, and settles what it will do at the far end.
function CrowdSim:_enter(walker, link: number, from: number)
	local graph = self.graph
	local entry = graph.links[link]
	walker.link = link
	walker.from = from
	walker.to = other(entry, from)
	walker.s = 0
	walker.next = self:_pick(walker.to, from, entry.kind == "crossing")
	local onward = walker.next and graph.links[walker.next]
	-- Waiting for the lamp, each stands a little short of the kerb, so a group forms (on the
	-- pavement: never short of a kerb it reaches over the roadway).
	walker.short = if onward
			and onward.kind == "crossing"
			and entry.kind ~= "crossing"
		then self.rng:NextNumber() * 3
		else 0
	walker.side = math.min(entry.half, 0.4 + self.rng:NextNumber() * math.max(0, entry.half - 0.4))
	-- A dead end ahead: stand there a while (looking round, checking a watch) before turning back.
	walker.linger = if onward == nil or other(onward, walker.to) == from then 2.5 + self.rng:NextNumber() * 4.5 else 0
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

-- Fills the crowd: `count` walkers spread over the walks (never on a crossing), and one standing
-- body at every post. Whoever was there before is gone.
function CrowdSim:seed(count: number)
	local graph = self.graph
	table.clear(self.walkers)
	local walks, total = {}, 0
	for index, link in ipairs(graph.links) do
		if link.kind ~= "crossing" and link.length > 1 then
			table.insert(walks, index)
			total += link.length
		end
	end
	for _ = 1, if #walks > 0 then count else 0 do
		local roll = self.rng:NextNumber() * total
		local chosen = walks[#walks]
		for _, index in ipairs(walks) do
			roll -= graph.links[index].length
			if roll < 0 then
				chosen = index
				break
			end
		end
		local link = graph.links[chosen]
		local walker = {
			pace = CrowdSim.PACE[1] + self.rng:NextNumber() * (CrowdSim.PACE[2] - CrowdSim.PACE[1]),
			speed = 0,
			lateral = 0,
			pinned = 0,
			wait = 0,
			passing = false,
			waiting = false,
			standing = false,
			shown = true,
		}
		self:_enter(walker, chosen, if self.rng:NextNumber() < 0.5 then link.a else link.b)
		walker.s = self.rng:NextNumber() * math.max(0, link.length - walker.short)
		walker.lateral = walker.side
		place(self, walker)
		table.insert(self.walkers, walker)
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
	for _, walker in ipairs(self.walkers) do
		walker.shown = shown
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
		if walker.s >= entry.length and not walker.waiting then
			walker.s = entry.length
			if walker.linger > 0 then
				walker.wait = walker.linger
				walker.linger = 0
				walker.speed = 0
			elseif walker.wait <= 0 and walker.next then
				-- Onto the next walk from where it stands: its place beside the old walk's line,
				-- measured along and across the new one, so it turns the corner without a sideways
				-- jump (turning back at a dead end, it is on what is now the right of the same walk)
				-- and drifts over to its own side again as it goes.
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
