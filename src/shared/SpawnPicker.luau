--!strict
-- Where players start (2026-10-27: they started in a fixed order on twelve spots a few studs apart, inside staring
-- range of each other, and a respawn could land on someone). The pool is a map's spawns and its spare spots spread
-- over the whole map; each time (the case's start, every investigation, a respawn) a fresh set is dealt: a random
-- first spot, then each next one the farthest from those dealt (and from anyone already standing about), never within
-- `gap` of anyone while a spot further off is left, and out of everyone's sight when one is.
--
-- Pure: the server passes who can see whom (Services/RoundService raycasts the map between the spots).

local SpawnPicker = {}

export type Options = {
	gap: number, -- nobody nearer than this (staring range)
	visible: ((a: number, b: number) -> boolean)?, -- can someone on pool spot a see pool spot b?
	sees: ((spot: number, at: Vector3) -> boolean)?, -- can someone standing at `at` see pool spot `spot`?
	occupied: { Vector3 }?, -- where the living already stand (a respawn keeps away from them)
}

-- Deals `count` spots of `pool` (indices into it, in the order dealt). More players than spots: the pool is dealt again.
function SpawnPicker.pick(pool: { Vector3 }, count: number, rng: Random, options: Options): { number }
	local dealt: { number } = {}
	if #pool == 0 then
		return dealt
	end
	local occupied = options.occupied or {}
	local taken: { [number]: boolean } = {}
	while #dealt < count do
		local best, bestKey: { number }? = nil, nil
		for index, at in ipairs(pool) do
			if not taken[index] then
				-- (the score, lower is better: inside the gap, seen by how many, then the nearest distance, further first)
				local nearest = math.huge
				local seen = 0
				for _, other in ipairs(dealt) do
					nearest = math.min(nearest, (pool[other] - at).Magnitude)
					if options.visible and options.visible(other, index) then
						seen += 1
					end
				end
				for _, standing in ipairs(occupied) do
					nearest = math.min(nearest, (standing - at).Magnitude)
					if options.sees and options.sees(index, standing) then
						seen += 1
					end
				end
				local key = { if nearest < options.gap then 1 else 0, seen, -nearest }
				if #dealt == 0 and #occupied == 0 then
					-- the first spot: anywhere
					key = { 0, 0, -rng:NextNumber() }
				end
				local better = bestKey == nil
				if bestKey then
					for k = 1, 3 do
						if key[k] ~= bestKey[k] then
							better = key[k] < bestKey[k]
							break
						end
					end
				end
				if better then
					best, bestKey = index, key
				end
			end
		end
		if best == nil then
			-- every spot dealt: start over on the pool, keeping what was dealt
			table.clear(taken)
		else
			taken[best] = true
			table.insert(dealt, best)
		end
	end
	return dealt
end

return SpawnPicker
