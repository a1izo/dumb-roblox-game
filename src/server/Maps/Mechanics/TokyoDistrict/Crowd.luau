-- The Tokyo crowd on the server: CrowdSim's walkers, moved as numbers (no body exists here: every
-- client draws its own from the snapshots, World/Crowd). What the crowd does to the match:
--   - a walker's body blocks sight (a letter flash, a faked task's witnesses, the Oculus), tested where
--     the clients saw it stand (they draw the crowd DRAWN_BEHIND seconds late);
--   - a living player's name tag hides while they stand inside the crowd.
-- Players never block each other's sight, and a walker is never a player: nothing here reads Match.list
-- but the name tags.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapSync = require(Shared:WaitForChild("MapSync"))

local Services = script.Parent.Parent.Parent.Parent:WaitForChild("Services")
local CharacterService = require(Services:WaitForChild("CharacterService"))
local Match = require(Services:WaitForChild("Match"))

local CrowdSim = require(script.Parent.CrowdSim)
local Looks = require(script.Parent.Looks)

local Crowd = {}

Crowd.WALKERS = 35 -- walking; the map's posts add those who stand
Crowd.DRAWN_BEHIND = 0.3 -- seconds late the clients draw the crowd (they glide between snapshots)
Crowd.LEVEL = 4 -- studs above or below a walker's feet a player's still count as beside it

local KEEP = 6 -- snapshots remembered for the sight lines

local sim = nil
local origin = Vector3.zero
local shown = false
local marks: { { x: number, z: number } }? = nil
local history: { { t: number, bodies: { any } } } = {}
local covers: { [number]: { hidden: boolean, clear: number } } = {}

-- Where the bodies stood at a past moment (the map's coordinates), from the two snapshots around it.
local function bodiesAt(t: number): { any }
	local before, after = nil, nil
	for _, sample in ipairs(history) do
		if sample.t <= t then
			before = sample
		elseif not after then
			after = sample
		end
	end
	local a = before or after
	local b = after or before
	if not a then
		return {}
	end
	local w = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0
	local out = {}
	for i, body in ipairs(a.bodies) do
		local other = b.bodies[i]
		if body.shown and other and other.shown then
			table.insert(out, {
				x = body.x + (other.x - body.x) * w,
				y = body.y + (other.y - body.y) * w,
				z = body.z + (other.z - body.z) * w,
			})
		end
	end
	return out
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function occluder(from: Vector3, to: Vector3): boolean
	if not sim or not shown then
		return false
	end
	return CrowdSim.blocks(bodiesAt(now() - Crowd.DRAWN_BEHIND), from - origin, to - origin)
end

local function uncover()
	for _, ps in ipairs(Match.list) do
		local character = ps.player.Character
		if character then
			CharacterService.setNameHidden(character, "crowd", false)
		end
	end
	table.clear(covers)
end

function Crowd.start(ctx)
	origin = ctx.map.origin or Vector3.zero
	local data = ctx.map.layout and ctx.map.layout.crowd
	table.clear(history)
	table.clear(covers)
	marks = nil
	if type(data) ~= "table" or #(data.nodes or {}) == 0 then
		sim = nil
		return
	end
	sim = CrowdSim.new(data, Random.new(ctx.rng:NextInteger(1, 2 ^ 30)))
	sim:seed(Crowd.WALKERS)
	shown = true
	Looks.ensure()
	Match.occluder = occluder
end

function Crowd.stop()
	uncover()
	sim = nil
	shown = false
	marks = nil
	table.clear(history)
end

-- Spots the crowd stops short of (the intro's cast on their marks); nil: none.
function Crowd.setMarks(list: { Vector3 }?)
	marks = nil
	if list then
		marks = {}
		for _, at in ipairs(list) do
			table.insert(marks :: any, { x = at.X - origin.X, z = at.Z - origin.Z })
		end
	end
end

-- A fresh crowd, walking (each investigation).
function Crowd.reseed()
	if sim then
		sim:seed(Crowd.WALKERS)
		sim.scale, sim.target = 1, 1
		shown = true
		table.clear(history)
	end
end

function Crowd.setPace(pace: number)
	if sim then
		sim:setPace(pace)
	end
end

function Crowd.setShown(on: boolean)
	shown = on
	if sim then
		sim:setShown(on)
	end
	if not on then
		uncover()
		table.clear(history)
	end
end

function Crowd.isShown(): boolean
	return sim ~= nil and shown
end

-- players: living players near the street, in the map's coordinates.
function Crowd.step(dt: number, clearFor: number, cars: boolean, players: { { x: number, z: number } })
	if sim and shown then
		sim:step(dt, { clearFor = clearFor, cars = cars, players = players, marks = marks })
	end
end

-- The walkers now on a crossing (the cars brake for them).
function Crowd.onCrossing(into: { { x: number, z: number } })
	if not sim or not shown then
		return
	end
	local links = sim.graph.links
	for _, walker in ipairs(sim.walkers) do
		if walker.shown and not walker.standing and links[walker.link].kind == "crossing" then
			table.insert(into, walker)
		end
	end
end

-- Remembers where everyone stands (called with each snapshot sent) and returns the snapshot's walkers.
function Crowd.record(t: number): { MapSync.Walker }
	if not sim then
		return {}
	end
	local bodies = table.create(#sim.walkers)
	for i, walker in ipairs(sim.walkers) do
		bodies[i] = { x = walker.x, y = walker.y or 0, z = walker.z, shown = walker.shown }
	end
	table.insert(history, { t = t, bodies = bodies })
	while #history > KEEP do
		table.remove(history, 1)
	end
	return sim.walkers
end

-- Name tags: hidden for a living player who stands inside the crowd (on its level).
function Crowd.cover(dt: number)
	if not sim or not shown then
		return
	end
	local bodies = bodiesAt(now() - Crowd.DRAWN_BEHIND)
	for _, ps in ipairs(Match.list) do
		local character = ps.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local state = covers[ps.userId]
			if not state then
				state = { hidden = false, clear = 0 }
				covers[ps.userId] = state
			end
			local at = root.Position - origin
			local hidden = false
			if ps.alive == true and ps.away ~= true then
				local level = {}
				for _, body in ipairs(bodies) do
					if math.abs(at.Y - 3 - body.y) <= Crowd.LEVEL then
						table.insert(level, body)
					end
				end
				hidden = CrowdSim.cover(state, level, at.X, at.Z, dt)
			else
				state.hidden = false
			end
			CharacterService.setNameHidden(character, "crowd", hidden)
		end
	end
end

function Crowd.describe(): string
	if not sim then
		return "no crowd on this map"
	end
	local walking, waiting, passing, standing = 0, 0, 0, 0
	for _, walker in ipairs(sim.walkers) do
		if walker.standing then
			standing += 1
		elseif walker.waiting then
			waiting += 1
		else
			walking += 1
		end
		if walker.passing then
			passing += 1
		end
	end
	return string.format(
		"crowd %s: %d walking, %d at the kerb, %d standing, %d stepping through someone",
		if shown then "out" else "hidden",
		walking,
		waiting,
		standing,
		passing
	)
end

return Crowd
