--!strict
-- The featured items of the day: the same six for everyone on a given UTC day, picked by a
-- seeded random draw weighted by rarity, with at least one rare or better. Rotation items
-- can only be bought while featured (plus a short grace period after midnight, so a
-- purchase started just before the change still goes through).

local Cosmetics = require(script.Parent.Cosmetics)

local ShopRotation = {}

ShopRotation.SIZE = 6
ShopRotation.GRACE = 5 * 60
local DAY = 86400

local WEIGHTS = { common = 60, rare = 28, epic = 10, legendary = 3 }

function ShopRotation.dayOf(unixTime: number): number
	return math.floor(unixTime / DAY)
end

-- Seconds until the next rotation.
function ShopRotation.secondsLeft(unixTime: number): number
	return DAY - (unixTime % DAY)
end

function ShopRotation.forDay(day: number): { string }
	local pool = Cosmetics.rotationPool()
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	local rng = Random.new(day * 7919 + 17)
	local picked: { string } = {}
	local remaining = table.clone(pool)
	local function draw(filter: ((Cosmetics.Item) -> boolean)?)
		local total = 0
		for _, item in ipairs(remaining) do
			if not filter or filter(item) then
				total += WEIGHTS[item.rarity] or 1
			end
		end
		if total <= 0 then
			return
		end
		local roll = rng:NextNumber() * total
		for index, item in ipairs(remaining) do
			if not filter or filter(item) then
				roll -= WEIGHTS[item.rarity] or 1
				if roll <= 0 then
					table.insert(picked, item.id)
					table.remove(remaining, index)
					return
				end
			end
		end
	end
	draw(function(item)
		return item.rarity ~= "common"
	end)
	while #picked < math.min(ShopRotation.SIZE, #pool) do
		draw(nil)
	end
	return picked
end

-- True when a rotation item can be bought at this time.
function ShopRotation.isFeatured(itemId: string, unixTime: number): boolean
	local day = ShopRotation.dayOf(unixTime)
	if table.find(ShopRotation.forDay(day), itemId) then
		return true
	end
	local sinceMidnight = unixTime % DAY
	return sinceMidnight < ShopRotation.GRACE and table.find(ShopRotation.forDay(day - 1), itemId) ~= nil
end

return ShopRotation
