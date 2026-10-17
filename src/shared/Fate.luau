--!strict
-- Fate's draw (the shop's Fate suit): each week (Mondays, UTC) a deck of SIZE things the shop sells, laid face
-- up with the odds of each. A draw costs PRICE coins and deals one card you do not own yet, by those odds:
-- the rarer, the less likely (WEIGHTS). Every card is sold for at least the price of a draw, nothing in the
-- deck is only found here, and it is coins only. With the whole deck owned there is nothing to draw until the
-- next week's. The server draws (ShopService "fate").

local Cosmetics = require(script.Parent.Cosmetics)
local Rarity = require(script.Parent.Rarity)
local TimeUtil = require(script.Parent.Progression.TimeUtil)

local Fate = {}

Fate.SIZE = 12
Fate.PRICE = 250
-- (by Rarity.fateGroup: a Godhood card counts as a legendary one, in the quota and the odds)
Fate.WEIGHTS = { common = 40, rare = 30, epic = 18, legendary = 8 }
-- How many of each rarity a deck holds (then filled from the rest when a rarity runs short).
local QUOTA = { legendary = 2, epic = 3, rare = 4, common = 3 }
Fate.QUOTA = QUOTA

function Fate.week(unixTime: number): number
	return TimeUtil.week(unixTime)
end

-- What can be in a deck: sold in the shop or in the rotation, for at least the price of a draw.
function Fate.eligible(item: Cosmetics.Item): boolean
	return (item.source == "shop" or item.source == "rotation") and (item.price or 0) >= Fate.PRICE
end

-- A week's deck, the same for everyone: SIZE item ids.
function Fate.deck(week: number): { string }
	local pool = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if Fate.eligible(item) then
			table.insert(pool, item)
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	local rng = Random.new(week * 6151 + 11)
	-- (shuffled by the week's seed, then dealt by rarity)
	for index = #pool, 2, -1 do
		local other = rng:NextInteger(1, index)
		pool[index], pool[other] = pool[other], pool[index]
	end
	local deck: { string } = {}
	local taken: { [string]: boolean } = {}
	for _, rarity in ipairs(Cosmetics.RARITIES) do
		local want = QUOTA[rarity] or 0
		for _, item in ipairs(pool) do
			if want > 0 and Rarity.fateGroup(item.rarity) == rarity and #deck < Fate.SIZE then
				table.insert(deck, item.id)
				taken[item.id] = true
				want -= 1
			end
		end
	end
	for _, item in ipairs(pool) do
		if #deck < Fate.SIZE and not taken[item.id] then
			table.insert(deck, item.id)
			taken[item.id] = true
		end
	end
	return deck
end

-- The odds of each card not owned (0 to 1, adding up to 1), by id; none when everything is owned.
function Fate.odds(deck: { string }, owns: (Cosmetics.Item) -> boolean): { [string]: number }
	local total = 0
	local weights: { [string]: number } = {}
	for _, id in ipairs(deck) do
		local item = Cosmetics.byId(id)
		if item and not owns(item) then
			local weight = Fate.WEIGHTS[Rarity.fateGroup(item.rarity)] or 1
			weights[id] = weight
			total += weight
		end
	end
	local odds: { [string]: number } = {}
	for id, weight in pairs(weights) do
		odds[id] = weight / total
	end
	return odds
end

-- The card a roll (0 to 1) deals from the cards not owned, in the deck's order; nil when everything is owned.
function Fate.pick(deck: { string }, owns: (Cosmetics.Item) -> boolean, roll: number): string?
	local odds = Fate.odds(deck, owns)
	local last = nil
	for _, id in ipairs(deck) do
		local chance = odds[id]
		if chance then
			last = id
			roll -= chance
			if roll < 0 then
				return id
			end
		end
	end
	return last
end

return Fate
