--!strict
-- A slow ceiling fan in two of the Bureau's rooms (graphics plan, phase 13). Made on the client from plain parts (a hub,
-- a rod, four blades; no mesh, no light, and its blades cast no shadow, so the key lamp's pool never flickers with it),
-- hung from the ceiling that is really there (found by a ray up from the room) at a spot clear of every lamp.
-- It slows to a stop when the building's power is cut, and stands still under Reduce motion.

local Util = require(script.Parent.Util)
local LifePatterns = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LifePatterns"))

local Fans = {}

type Room = { name: string, min: { number }, max: { number }, floor: number }

-- The rooms, in the map's own studs (floor level, then the room's two corners on the plan).
local ROOMS: { [string]: { Room } } = {
	TaskForceHQ = {
		{ name = "sergeant's office", min = { -100, 53 }, max = { -76, 75 }, floor = 0 },
		{ name = "break room", min = { 50, -75 }, max = { 100, -40 }, floor = 0 },
	},
}

local SPEED = 2.6 -- radians a second (a little over a third of a turn a second: slow)
local EASE = 0.5 -- 1 over the seconds the blades take to get up to speed or run down
local NEAR = 110 -- studs from the camera within which it turns
local CLEAR = 4.8 -- how far from a lamp's fitting the hub hangs
local DROP = 1.25 -- from the ceiling to the blades
local MARGIN = 4 -- from the room's walls
local STEPS = { { 0, 0 }, { 5, 0 }, { -5, 0 }, { 0, 5 }, { 0, -5 }, { 5, 5 }, { -5, -5 }, { 5, -5 }, { -5, 5 } }

local WOOD = Color3.fromRGB(74, 50, 34)
local IRON = Color3.fromRGB(34, 34, 38)

type Fan = { rotor: Model, base: CFrame, at: Vector3, angle: number, speed: number }

-- How far a point is from the nearest lamp fitting in the map, measured along the floor plan.
local function lampGap(index: Util.Index, x: number, z: number): number
	local nearest = math.huge
	for _, lamp in ipairs(index.lamps) do
		local p = lamp.anchor.Position
		nearest = math.min(nearest, Vector2.new(p.X - x, p.Z - z).Magnitude)
	end
	return nearest
end

local function hang(parts: { Instance }, at: Vector3, ceiling: number, phase: number): Fan
	local top = CFrame.new(at.X, ceiling, at.Z)
	local base = CFrame.new(at.X, ceiling - DROP, at.Z)
	local folder = Util.folder()
	local still = Instance.new("Model")
	still.Name = "FanFixture"
	-- (a cylinder lies along x: turned to stand)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local canopy =
		Util.solid(top * CFrame.new(0, -0.1, 0) * upright, Vector3.new(0.25, 0.9, 0.9), IRON, Enum.Material.Metal)
	local rod = Util.solid(
		top * CFrame.new(0, -(DROP - 0.35) / 2 - 0.2, 0) * upright,
		Vector3.new(DROP - 0.35, 0.16, 0.16),
		IRON,
		Enum.Material.Metal
	)
	canopy.Shape = Enum.PartType.Cylinder
	rod.Shape = Enum.PartType.Cylinder
	canopy.Parent = still
	rod.Parent = still
	still.Parent = folder
	table.insert(parts, still)

	local rotor = Instance.new("Model")
	rotor.Name = "FanRotor"
	local hub = Util.solid(base * upright, Vector3.new(0.5, 1.1, 1.1), IRON, Enum.Material.Metal)
	hub.Shape = Enum.PartType.Cylinder
	hub.Parent = rotor
	for i = 0, 3 do
		local turn = CFrame.Angles(0, i * math.pi / 2, 0)
		local blade = Util.solid(
			base * turn * CFrame.new(1.95, 0.02, 0) * CFrame.Angles(math.rad(9), 0, 0),
			Vector3.new(2.9, 0.07, 0.85),
			WOOD,
			Enum.Material.Wood
		)
		blade.Parent = rotor
	end
	rotor.WorldPivot = base
	rotor.Parent = folder
	table.insert(parts, rotor)
	return { rotor = rotor, base = base, at = at, angle = phase, speed = 0 }
end

function Fans.build(index: Util.Index, mapId: string): Util.Built?
	local rooms = ROOMS[mapId]
	if not rooms then
		return nil
	end
	local made: { Fan } = {}
	local pieces: { Instance } = {}
	local params = Util.rayParams()
	for number, room in ipairs(rooms) do
		for _, offset in ipairs(STEPS) do
			local x = (room.min[1] + room.max[1]) / 2 + offset[1]
			local z = (room.min[2] + room.max[2]) / 2 + offset[2]
			local inside = x > room.min[1] + MARGIN
				and x < room.max[1] - MARGIN
				and z > room.min[2] + MARGIN
				and z < room.max[2] - MARGIN
			local world = Util.world(x, room.floor, z)
			if inside and lampGap(index, world.X, world.Z) >= CLEAR then
				local hit = workspace:Raycast(world + Vector3.new(0, 6, 0), Vector3.new(0, 16, 0), params)
				local height = if hit then hit.Position.Y - world.Y else 0
				if hit and height >= 9 and height <= 16 then
					table.insert(
						made,
						hang(pieces, hit.Position - Vector3.new(0, DROP, 0), hit.Position.Y, number * 1.7)
					)
					break
				end
			end
		end
	end
	if #made == 0 then
		return nil
	end
	local fans = made
	return {
		step = function(env: Util.Env)
			local target = if env.reduced or env.blackout then 0 else SPEED
			for _, fan in ipairs(fans) do
				if (fan.at - env.eye).Magnitude <= NEAR then
					fan.speed = LifePatterns.approach(fan.speed, target, EASE, env.dt)
					if fan.speed > 0.002 then
						fan.angle = (fan.angle + fan.speed * env.dt) % (2 * math.pi)
						fan.rotor:PivotTo(fan.base * CFrame.Angles(0, fan.angle, 0))
					end
				end
			end
		end,
		destroy = function()
			for _, piece in ipairs(pieces) do
				piece:Destroy()
			end
		end,
	}
end

local kind: Util.Kind = { name = "fans", maps = { "TaskForceHQ" }, build = Fans.build }
return kind
