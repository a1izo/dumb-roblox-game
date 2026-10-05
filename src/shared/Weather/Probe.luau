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

-- Where a drop must start so that, falling along `fall` (a unit vector going down), it lands on
-- (x, z) at height `landing` after dropping `height` studs; and how far it travels to do so.
function Probe.dropStart(x: number, z: number, landing: number, height: number, fall: Vector3): (Vector3, number)
	local length = height / -fall.Y
	return Vector3.new(x - fall.X * length, landing + height, z - fall.Z * length), length
end

return Probe
