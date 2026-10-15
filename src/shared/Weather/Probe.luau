--!strict
-- What the rain and the snow need to know about a small patch of ground: where it really is
-- (the street, a bridge deck, the river's surface, a floor inside a building) and how much of it
-- is under cover. Rays go down for the ground and up from it for a roof, and the cover boxes are
-- asked about the same spots; it takes the whole patch into account (a few spots across it), so a
-- cell on the edge of the river or the drip line of a roof is told apart from one in the middle.
-- Shared so the headless tests can run it on a built map.

local CoverIndex = require(script.Parent.CoverIndex)

local Probe = {}

local DOWN = Vector3.new(0, -90, 0)
local UP = Vector3.new(0, 90, 0)
local LIFT = 1.2 -- studs over the ground the roof ray starts from

-- Spots across a patch, as offsets from its middle at a patch size of 1 (corners and the centre).
local SPOTS = {
	Vector2.new(0, 0),
	Vector2.new(0.27, 0.27),
	Vector2.new(-0.27, 0.27),
	Vector2.new(0.27, -0.27),
	Vector2.new(-0.27, -0.27),
}

-- The ground under the patch centred on (x, z) with sides `size`: the LOWEST of its spots (so
-- drops over the river's edge reach the water, and what stands over higher ground is simply
-- hidden under it), or nil when nothing is under it; and how much of it is covered, 0 to 1.
-- originY is where the rays start (a little over the player's head: a roof over that does not
-- hide the ground under it).
function Probe.patch(
	x: number,
	z: number,
	size: number,
	originY: number,
	params: RaycastParams,
	index: CoverIndex.Index
): (number?, number)
	local lowest: number? = nil
	local covered, count = 0, 0
	for _, spot in ipairs(SPOTS) do
		local sx, sz = x + spot.X * size, z + spot.Y * size
		local hit = workspace:Raycast(Vector3.new(sx, originY, sz), DOWN, params)
		if hit then
			local y = hit.Position.Y
			if lowest == nil or y < lowest then
				lowest = y
			end
			local over = Vector3.new(sx, y + LIFT, sz)
			local amount = if workspace:Raycast(over, UP, params) then 1 else 0
			covered += math.max(amount, index:above(over))
			count += 1
		end
	end
	return lowest, if count > 0 then covered / count else 1
end

-- A room the weather never reaches: a box (a look zone whose preset ends in "_Inside" or "_Under").
export type Zone = { cf: CFrame, half: Vector3 }

-- What a near cell lets fall, looked at as SUB x SUB small patches (2026-10-15: snow was falling in Campus
-- rooms, because a cell partly under a roof still sent its flakes over the whole of it, from over the ceiling,
-- and the wind carried them through the walls):
--   * each patch has its own ground and its own roof ray; a patch under cover is closed, and so is one
--     within `margin` of a room (horizontally) when the weather's fall, from the cell's ground up to `height`
--     over it, passes the room's height (up its slant, `lean` upwind a stud higher, for the slanted rain);
--   * the cell sends its weather only from the largest rectangle of open patches;
--   * and never from over a roof: `ceiling` is the lowest roof found over that rectangle grown by `margin`,
--     and a patch whose ground is not below where the weather then starts is closed too (a roof top seen
--     from above: the weather falls to the cell's ground, so it would start under that roof);
--   * with `overhangs` (the snow), a patch standing more than a step over the cell's ground with air under it
--     (a roof, an eave, a shed seen from above) is closed as well: its flakes would fall on through it.
-- Returns the cell's ground (the lowest of its patches; nil when there is none), how much of it the rectangle
-- is (0 to 1), the open rectangle (world x0, z0, x1, z1; nil when no patch is open), the ceiling over it (nil:
-- open sky) and whether every patch is open and the cell is far from any room (`far`: `margin` again beyond).
Probe.SUB = 3

-- Is a fall from `top` down to `bottom` at (x, z) inside a room, or within `margin` of one across the ground? A
-- slanted fall (`lean`: how far upwind it is a stud higher, the rain's) is followed up its slant.
local FALL_SAMPLES = 9
local function inZone(
	zones: { Zone },
	x: number,
	z: number,
	bottom: number,
	top: number,
	margin: number,
	lean: Vector3?
): boolean
	for _, zone in ipairs(zones) do
		local half = zone.half
		if lean then
			for k = 0, FALL_SAMPLES - 1 do
				local h = (top - bottom) * k / (FALL_SAMPLES - 1)
				local p = zone.cf:PointToObjectSpace(Vector3.new(x + lean.X * h, bottom + h, z + lean.Z * h))
				if
					math.abs(p.X) <= half.X + margin
					and math.abs(p.Z) <= half.Z + margin
					and p.Y >= -half.Y - 2
					and p.Y <= half.Y + 1
				then
					return true
				end
			end
		else
			local low = zone.cf:PointToObjectSpace(Vector3.new(x, bottom, z))
			local high = zone.cf:PointToObjectSpace(Vector3.new(x, top, z))
			if
				math.abs(low.X) <= half.X + margin
				and math.abs(low.Z) <= half.Z + margin
				and math.max(low.Y, high.Y) >= -half.Y - 2
				and math.min(low.Y, high.Y) <= half.Y + 1
			then
				return true
			end
		end
	end
	return false
end

-- The largest rectangle of true cells in an n x n grid (open[i][j], i along x, j along z): (i0, j0, i1, j1).
local function largest(open: { { boolean } }, n: number): (number?, number?, number?, number?)
	local best, bi0, bj0, bi1, bj1 = 0, nil, nil, nil, nil
	for i0 = 1, n do
		for j0 = 1, n do
			for i1 = i0, n do
				for j1 = j0, n do
					local area = (i1 - i0 + 1) * (j1 - j0 + 1)
					if area > best then
						local all = true
						for i = i0, i1 do
							for j = j0, j1 do
								if not open[i][j] then
									all = false
									break
								end
							end
							if not all then
								break
							end
						end
						if all then
							best, bi0, bj0, bi1, bj1 = area, i0, j0, i1, j1
						end
					end
				end
			end
		end
	end
	return bi0, bj0, bi1, bj1
end

function Probe.cell(
	x: number,
	z: number,
	size: number,
	originY: number,
	params: RaycastParams,
	index: CoverIndex.Index,
	zones: { Zone },
	margin: number,
	height: number,
	overhangs: boolean,
	lean: Vector3?
): (number?, number, { number }?, number?, boolean)
	local n = Probe.SUB
	local step = size / n
	local function middle(i: number, j: number): (number, number)
		return x - size / 2 + step * (i - 0.5), z - size / 2 + step * (j - 0.5)
	end
	-- Each patch's ground (nil: none) and whether the sky is over it.
	local lowest: number? = nil
	local ground: { { number | false } } = {}
	local sky: { { boolean } } = {}
	for i = 1, n do
		ground[i], sky[i] = {}, {}
		for j = 1, n do
			local sx, sz = middle(i, j)
			local hit = workspace:Raycast(Vector3.new(sx, originY, sz), DOWN, params)
			ground[i][j], sky[i][j] = false, false
			if hit then
				local y = hit.Position.Y
				ground[i][j] = y
				if lowest == nil or y < lowest then
					lowest = y
				end
				local over = Vector3.new(sx, y + LIFT, sz)
				sky[i][j] = workspace:Raycast(over, UP, params) == nil and index:above(over) < 0.5
			end
		end
	end
	if not lowest then
		return nil, 0, nil, nil, false
	end
	local base: number = lowest
	local open: { { boolean } } = {}
	for i = 1, n do
		open[i] = {}
		for j = 1, n do
			local y = ground[i][j]
			local ok = false
			if y and sky[i][j] then
				local sx, sz = middle(i, j)
				ok = not inZone(zones, sx, sz, base, base + height, margin, lean)
				if ok and overhangs and y > base + 2 then
					-- Air under it: a ray up from the cell's ground meets its underside (one starting inside a
					-- solid step or terrace meets nothing).
					local from = Vector3.new(sx, base + LIFT, sz)
					ok = workspace:Raycast(from, Vector3.new(0, y - from.Y - 0.2, 0), params) == nil
				end
			end
			open[i][j] = ok
		end
	end
	-- The rectangle, then the roof over it; a patch not below where the weather then starts closes, and the
	-- rectangle is found again (a smaller one can only be under the same roofs or higher ones).
	local rect: { number }? = nil
	local ceiling: number? = nil
	local patches = 0
	for _ = 1, 3 do
		local i0, j0, i1, j1 = largest(open, n)
		if not i0 or not j0 or not i1 or not j1 then
			return base, 0, nil, nil, false
		end
		rect = {
			x - size / 2 + step * (i0 - 1),
			z - size / 2 + step * (j0 - 1),
			x - size / 2 + step * i1,
			z - size / 2 + step * j1,
		}
		patches = (i1 - i0 + 1) * (j1 - j0 + 1)
		local r = rect :: { number }
		-- The lowest roof over the rectangle and a margin round it (eaves, an arcade's lean-to).
		local from = base + LIFT
		for _, corner in ipairs({
			Vector2.new(r[1] - margin, r[2] - margin),
			Vector2.new(r[3] + margin, r[2] - margin),
			Vector2.new(r[1] - margin, r[4] + margin),
			Vector2.new(r[3] + margin, r[4] + margin),
			Vector2.new((r[1] + r[3]) / 2, (r[2] + r[4]) / 2),
		}) do
			local hit = workspace:Raycast(Vector3.new(corner.X, from, corner.Y), UP, params)
			if hit and (ceiling == nil or hit.Position.Y < ceiling) then
				ceiling = hit.Position.Y
			end
		end
		local start = math.min(base + height, if ceiling then ceiling - 1 else math.huge)
		local closed = false
		for i = i0, i1 do
			for j = j0, j1 do
				local y = ground[i][j]
				if y and y > start - 1 then
					open[i][j] = false
					closed = true
				end
			end
		end
		if not closed then
			break
		end
		rect = nil
	end
	if not rect then
		return base, 0, nil, nil, false
	end
	local all = patches == n * n and not inZone(zones, x, z, base, base + height, margin * 2 + size / 2, lean)
	return base, patches / (n * n), rect, ceiling, all
end

-- Where a drop must start so that, falling along `fall` (a unit vector going down), it lands on
-- (x, z) at height `landing` after dropping `height` studs; and how far it travels to do so.
function Probe.dropStart(x: number, z: number, landing: number, height: number, fall: Vector3): (Vector3, number)
	local length = height / -fall.Y
	return Vector3.new(x - fall.X * length, landing + height, z - fall.Z * length), length
end

return Probe
