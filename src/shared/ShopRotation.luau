--!strict
-- The featured items of the day: the same six for everyone on a given UTC day, picked by a
-- seeded random draw weighted by rarity, with at least one rare or better. Rotation items
-- can only be bought while featured (plus a short grace period after midnight, so a
-- purchase started just before the change still goes through).
--
-- With them, the day's deal: one card of the shop's own stock (never a rotation card), a quarter
-- off that day (DEAL_OFF, rounded down to 5 coins; the same grace after midnight). The six and the
-- deal are Today's hand (hand()).

local Cosmetics = require(script.Parent.Cosmetics)

local ShopRotation = {}

ShopRotation.SIZE = 6
ShopRotation.GRACE = 5 * 60
ShopRotation.DEAL_OFF = 0.25
local DAY = 86400

local WEIGHTS = { common = 60, rare = 28, epic = 10, legendary = 3 }

function ShopRotation.dayOf(unixTime: number): number
	return math.floor(unixTime / DAY)
end

-- Seconds until the next rotation.
function ShopRotation.secondsLeft(unixTime: number): number
	return DAY - (unixTime % DAY)
end

-- True when an item is sold only on the days it is in Today's hand (a rotation item, or a thing sold later
-- once its day has come).
function ShopRotation.rotates(item: Cosmetics.Item, unixTime: number): boolean
	return item.source == "rotation" or Cosmetics.laterPrice(item, unixTime) ~= nil
end

function ShopRotation.forDay(day: number): { string }
	local pool = Cosmetics.rotationPool()
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.source ~= "rotation" and Cosmetics.laterPrice(item, day * DAY) ~= nil then
			table.insert(pool, item)
		end
	end
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

-- The day's deal: a card of the shop's own stock, drawn by a seed of the day weighted by rarity (the
-- rarer, the less often), or nil when nothing is for sale.
function ShopRotation.dealFor(day: number): string?
	local pool = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.source == "shop" and item.price then
			table.insert(pool, item)
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	local total = 0
	for _, item in ipairs(pool) do
		total += WEIGHTS[item.rarity] or 1
	end
	local roll = Random.new(day * 104729 + 31):NextNumber() * total
	for _, item in ipairs(pool) do
		roll -= WEIGHTS[item.rarity] or 1
		if roll <= 0 then
			return item.id
		end
	end
	return pool[#pool].id
end

-- A deal's price: a quarter off, rounded down to 5 coins.
function ShopRotation.dealPrice(price: number): number
	return math.floor(price * (1 - ShopRotation.DEAL_OFF) / 5) * 5
end

-- True when the item is the deal at this time (its day, or the grace after its midnight).
function ShopRotation.isDeal(itemId: string, unixTime: number): boolean
	local day = ShopRotation.dayOf(unixTime)
	if ShopRotation.dealFor(day) == itemId then
		return true
	end
	return unixTime % DAY < ShopRotation.GRACE and ShopRotation.dealFor(day - 1) == itemId
end

-- What an item costs at this time (the deal's price on its day; a thing sold later, its price once its day
-- has come), or nil when it is not sold.
function ShopRotation.priceOf(item: Cosmetics.Item, unixTime: number): number?
	local price = item.price or Cosmetics.laterPrice(item, unixTime)
	if price and item.source == "shop" and ShopRotation.isDeal(item.id, unixTime) then
		return ShopRotation.dealPrice(price)
	end
	return price
end

-- Today's hand: the day's six, then its deal.
function ShopRotation.hand(day: number): { string }
	local cards = table.clone(ShopRotation.forDay(day))
	local deal = ShopRotation.dealFor(day)
	if deal then
		table.insert(cards, deal)
	end
	return cards
end

-- The emote the lobby's shop window shows on a day (client World/ShopWindow): the first emote of that day's
-- hand that one body can show, else one of the shop's own emotes by a seed of the day. Nil when there is none.
function ShopRotation.windowFor(day: number): string?
	local function showable(item: Cosmetics.Item?): boolean
		return item ~= nil and item.kind == "emote" and item.price ~= nil and not item.duo
	end
	for _, id in ipairs(ShopRotation.hand(day)) do
		if showable(Cosmetics.byId(id)) then
			return id
		end
	end
	local pool = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if showable(item) and item.source == "shop" then
			table.insert(pool, item.id)
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool)
	return pool[Random.new(day * 7177 + 3):NextInteger(1, #pool)]
end

-- Today's hand is dealt face down; a player turns the cards one by one (only to see them: the hand is
-- the same for everyone). `record` is the profile's shopTurned { day, cards }: a new day starts it
-- again. Returns whether anything changed (false for a card not in that day's hand, or already turned).
function ShopRotation.turn(record: any, day: number, itemId: any): boolean
	if type(record) ~= "table" or type(itemId) ~= "string" then
		return false
	end
	if not table.find(ShopRotation.hand(day), itemId) then
		return false
	end
	if record.day ~= day or type(record.cards) ~= "table" then
		record.day = day
		record.cards = {}
	end
	if table.find(record.cards, itemId) then
		return false
	end
	table.insert(record.cards, itemId)
	return true
end

-- The cards of `day`'s hand turned so far (none on another day).
function ShopRotation.turned(record: any, day: number): { string }
	if type(record) == "table" and record.day == day and type(record.cards) == "table" then
		return record.cards
	end
	return {}
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
