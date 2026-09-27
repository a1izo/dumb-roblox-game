--!strict
-- What kind of ground a place is (road, crossing, sidewalk, interior, water...), from the zones
-- a Blender-made map exports with its layout. Used to keep things the game places itself (the
-- intro's chairs and marks) off roads, crossings, water and tracks.

local Zones = {}
Zones.__index = Zones

-- Where nothing of the game's may stand.
Zones.FORBIDDEN = {
	road = true,
	crossing = true,
	water = true,
	track = true,
	stairs = true,
	offlimits = true,
}

local CELL = 16

export type Zone = { kind: string, y0: number, y1: number, points: { number }, name: string? }
export type Zones = typeof(setmetatable(
	{} :: { list: { Zone }, grid: { [number]: { number } }, origin: Vector3 },
	Zones
))

local function key(i: number, j: number): number
	return i * 100003 + j
end

-- zones: the layout's zones (local coordinates); origin: the venue's origin in the world.
function Zones.new(zones: { Zone }, origin: Vector3): Zones
	local grid: { [number]: { number } } = {}
	for index, zone in ipairs(zones) do
		local p = zone.points
		local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
		for k = 1, #p, 2 do
			minX, maxX = math.min(minX, p[k]), math.max(maxX, p[k])
			minZ, maxZ = math.min(minZ, p[k + 1]), math.max(maxZ, p[k + 1])
		end
		for i = math.floor(minX / CELL), math.floor(maxX / CELL) do
			for j = math.floor(minZ / CELL), math.floor(maxZ / CELL) do
				local cell = grid[key(i, j)]
				if not cell then
					cell = {}
					grid[key(i, j)] = cell
				end
				table.insert(cell, index)
			end
		end
	end
	return setmetatable({ list = zones, grid = grid, origin = origin }, Zones)
end

-- Point in polygon (even-odd) on the flat list x1, z1, x2, z2...
function Zones.contains(points: { number }, x: number, z: number): boolean
	local inside = false
	local count = #points // 2
	local j = count
	for i = 1, count do
		local xi, zi = points[i * 2 - 1], points[i * 2]
		local xj, zj = points[j * 2 - 1], points[j * 2]
		if (zi > z) ~= (zj > z) then
			local t = (z - zi) / (zj - zi)
			if x < xi + t * (xj - xi) then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

-- The kinds of ground at a world position (its height within 1.5 studs of the zone's floor).
function Zones.kindsAt(self: Zones, position: Vector3): { string }
	local p = position - self.origin
	local out = {}
	local cell = self.grid[key(math.floor(p.X / CELL), math.floor(p.Z / CELL))]
	if not cell then
		return out
	end
	for _, index in ipairs(cell) do
		local zone = self.list[index]
		local low, high = math.min(zone.y0, zone.y1), math.max(zone.y0, zone.y1)
		if p.Y >= low - 1.5 and p.Y <= high + 1.5 and Zones.contains(zone.points, p.X, p.Z) then
			table.insert(out, zone.kind)
		end
	end
	return out
end

-- True when nothing of the game's may stand at a world position (a road, crossing, water...).
-- Places with no zones at all (older maps) are never forbidden.
function Zones.forbidden(self: Zones, position: Vector3): boolean
	for _, kind in ipairs(self:kindsAt(position)) do
		if Zones.FORBIDDEN[kind] then
			return true
		end
	end
	return false
end

return Zones
