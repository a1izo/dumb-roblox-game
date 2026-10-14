--!strict
-- The arithmetic of the movement set (LocomotionController), kept apart so the specs can check it:
-- which way a body moves among the four directional cycles, the phase each leg samples a cycle at,
-- how hard a landing was, and the order fidgets come in.

local Gait = {}

-- The four ways a body can move relative to where it faces, each with a walk and a run cycle (art/scripts/
-- locomotion.py): forward, back, left and right.
Gait.DIRECTIONS = { "F", "B", "L", "R" }

-- How much of each directional cycle to play for a velocity in the body's own frame (x right, z back):
-- weights that sum to 1, all forward for a body going straight ahead, half forward and half left on a
-- diagonal. Squared cosines, so the blend turns smoothly with the direction.
function Gait.directions(localVelocity: Vector3): { [string]: number }
	local x, z = localVelocity.X, localVelocity.Z
	local length = math.sqrt(x * x + z * z)
	if length < 1e-4 then
		return { F = 1, B = 0, L = 0, R = 0 }
	end
	local forward, left = -z / length, -x / length
	return {
		F = if forward > 0 then forward * forward else 0,
		B = if forward < 0 then forward * forward else 0,
		L = if left > 0 then left * left else 0,
		R = if left < 0 then left * left else 0,
	}
end

-- The cycle phase one leg samples a clip at. Every cycle lands its right foot at phase 0 (the left at
-- 0.5); a clip whose foot stays down for `stance` of its cycle is stretched so its stance lasts `shared`
-- of the shared cycle (and its swing the rest), so walk and run blended mid-way plant their feet
-- together. Monotone, 0 -> 0 and 1 -> 1.
function Gait.warp(phase: number, shared: number, stance: number): number
	phase %= 1
	if shared <= 0 or shared >= 1 then
		return phase
	end
	if phase < shared then
		return phase * stance / shared
	end
	return stance + (phase - shared) * (1 - stance) / (1 - shared)
end

-- The left leg's phase for a shared phase: its cycle is half a cycle behind the right leg's.
function Gait.leftWarp(phase: number, shared: number, stance: number): number
	return (Gait.warp(phase - 0.5, shared, stance) + 0.5) % 1
end

-- Landing strengths by the height it is like having fallen from (studs): below the first nothing plays
-- (a step down a kerb); then light, normal, heavy.
Gait.LANDINGS = {
	{ height = 0.6, clip = "landLight" },
	{ height = 4, clip = "landNormal" },
	{ height = 14, clip = "landHeavy" },
}

-- The landing clip for a body that met the ground at `speed` studs/s (downwards) under `gravity`.
function Gait.landing(speed: number, gravity: number): string?
	if speed <= 0 or gravity <= 0 then
		return nil
	end
	local height = speed * speed / (2 * gravity)
	local chosen = nil
	for _, tier in ipairs(Gait.LANDINGS) do
		if height >= tier.height then
			chosen = tier.clip
		end
	end
	return chosen
end

export type Bag = { order: { string }, next: number, last: string?, pool: { string }? }

-- A shuffled bag of fidgets: each is played once before any repeats, and never the same twice running.
function Gait.bag(): Bag
	return { order = {}, next = 1, last = nil, pool = nil }
end

function Gait.draw(bag: Bag, pool: { string }, random: Random): string?
	if #pool == 0 then
		return nil
	end
	if bag.next > #bag.order or bag.pool ~= pool then
		bag.pool = pool
		local order = table.clone(pool)
		for i = #order, 2, -1 do
			local j = random:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		if #order > 1 and order[1] == bag.last then
			order[1], order[#order] = order[#order], order[1]
		end
		bag.order, bag.next = order, 1
	end
	local id = bag.order[bag.next]
	bag.next += 1
	bag.last = id
	return id
end

return Gait
