--!strict
-- Boxes that shelter from rain and snow without being solid (an awning, a tree's crown, a bus
-- shelter's roof), indexed by the ground they stand over so the weather can ask "how much is
-- stopped over this spot" without looking at every box. Pure arithmetic, no instances: the
-- client builds one from the parts the map builder tagged (World/RainController) and the specs
-- run it on made-up boxes.

local CoverIndex = {}
CoverIndex.__index = CoverIndex

export type Box = {
	cf: CFrame,
	half: Vector3,
	amount: number,
	bottom: number,
	top: number,
}

export type Index = typeof(setmetatable({} :: { buckets: { [string]: { Box } }, count: number }, CoverIndex))

local BUCKET = 16 -- studs across of one bucket of the ground

-- A box that only stops what falls on someone standing under it is one whose underside is at
-- least this far over the spot asked about (a counter or a bench under an awning does not count).
local CLEARANCE = 1.5

local function key(ix: number, iz: number): string
	return ix .. "," .. iz
end

function CoverIndex.new(): Index
	return setmetatable({ buckets = {}, count = 0 }, CoverIndex) :: any
end

function CoverIndex.add(self: Index, cf: CFrame, size: Vector3, amount: number): Box
	local half = size / 2
	local box: Box = { cf = cf, half = half, amount = amount, bottom = cf.Y - half.Y, top = cf.Y + half.Y }
	-- The ground the box covers, as a rectangle round it (the box may be turned about the vertical).
	local right, up, back = cf.RightVector, cf.UpVector, cf.LookVector
	local reachX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z
	local reachZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	for ix = math.floor((cf.X - reachX) / BUCKET), math.floor((cf.X + reachX) / BUCKET) do
		for iz = math.floor((cf.Z - reachZ) / BUCKET), math.floor((cf.Z + reachZ) / BUCKET) do
			local k = key(ix, iz)
			local bucket = self.buckets[k]
			if not bucket then
				bucket = {}
				self.buckets[k] = bucket
			end
			table.insert(bucket, box)
		end
	end
	self.count += 1
	return box
end

function CoverIndex.remove(self: Index, box: Box)
	local right, up, back = box.cf.RightVector, box.cf.UpVector, box.cf.LookVector
	local half = box.half
	local reachX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z
	local reachZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	for ix = math.floor((box.cf.X - reachX) / BUCKET), math.floor((box.cf.X + reachX) / BUCKET) do
		for iz = math.floor((box.cf.Z - reachZ) / BUCKET), math.floor((box.cf.Z + reachZ) / BUCKET) do
			local bucket = self.buckets[key(ix, iz)]
			if bucket then
				local at = table.find(bucket, box)
				if at then
					table.remove(bucket, at)
				end
			end
		end
	end
	self.count -= 1
end

-- How much the boxes over a spot stop (0 none, 1 everything): the most of any one box whose
-- footprint holds the spot and whose underside is over it.
function CoverIndex.above(self: Index, position: Vector3): number
	local bucket = self.buckets[key(math.floor(position.X / BUCKET), math.floor(position.Z / BUCKET))]
	if not bucket then
		return 0
	end
	local most = 0
	for _, box in ipairs(bucket) do
		if box.amount > most and box.bottom >= position.Y + CLEARANCE then
			local p = box.cf:PointToObjectSpace(Vector3.new(position.X, box.cf.Y, position.Z))
			if math.abs(p.X) <= box.half.X and math.abs(p.Z) <= box.half.Z then
				most = box.amount
			end
		end
	end
	return most
end

return CoverIndex
