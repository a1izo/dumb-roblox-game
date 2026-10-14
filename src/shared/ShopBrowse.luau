--!strict
-- Browsing Death's hand (UI/ShopPanel): which cards a suit shows and in what order (a search, a "show"
-- filter and a sort), which are new, and the wishlist. Pure rules; the server keeps what was seen and
-- wished in the profile (ShopService "seen" and "wish").
--
--   new       an item whose `added` date is under NEW_DAYS old, until its suit has been looked at
--   wishlist  items not owned that are sold (in the shop, or in Today's hand on its day); a wished card in
--             today's hand is announced on arriving

local Cosmetics = require(script.Parent.Cosmetics)
local ShopRotation = require(script.Parent.ShopRotation)

local ShopBrowse = {}

ShopBrowse.NEW_DAYS = 14
ShopBrowse.WISH_LIMIT = 60
local DAY = 86400

export type Choice = { id: string, name: string }

ShopBrowse.SHOW = {
	{ id = "all", name = "All" },
	{ id = "notOwned", name = "Not owned" },
	{ id = "afford", name = "Can afford" },
	{ id = "wished", name = "Wished" },
} :: { Choice }

ShopBrowse.SORTS = {
	{ id = "order", name = "In order" },
	{ id = "cheapest", name = "Cheapest" },
	{ id = "dearest", name = "Dearest" },
	{ id = "rarest", name = "Rarest" },
	{ id = "newest", name = "Newest" },
} :: { Choice }

-- The next choice in a list after `id` (back to the first after the last).
function ShopBrowse.after(list: { Choice }, id: string): Choice
	for index, choice in ipairs(list) do
		if choice.id == id then
			return list[index % #list + 1]
		end
	end
	return list[1]
end

function ShopBrowse.nameOf(list: { Choice }, id: string): string
	for _, choice in ipairs(list) do
		if choice.id == id then
			return choice.name
		end
	end
	return list[1].name
end

-- The day an item came to the shop (unix time of its `added` date, UTC midnight), or nil.
function ShopBrowse.addedAt(item: Cosmetics.Item): number?
	local added = (item :: any).added
	if type(added) ~= "string" then
		return nil
	end
	local year, month, day = string.match(added, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
	if not year then
		return nil
	end
	return DateTime.fromUniversalTime(tonumber(year) :: number, tonumber(month) :: number, tonumber(day) :: number).UnixTimestamp
end

-- New to the shop at `now` (seen or not).
function ShopBrowse.isNew(item: Cosmetics.Item, now: number): boolean
	local at = ShopBrowse.addedAt(item)
	return at ~= nil and now >= at and now - at < ShopBrowse.NEW_DAYS * DAY
end

-- Forgets what was seen of items no longer new (so the profile does not keep growing).
function ShopBrowse.prune(seen: { [string]: any }, now: number)
	for id in pairs(seen) do
		local item = Cosmetics.byId(id)
		if not item or not ShopBrowse.isNew(item, now) then
			seen[id] = nil
		end
	end
end

-- Sold at all (so it can be wished for): a price, in the shop or in the rotation.
function ShopBrowse.wishable(item: Cosmetics.Item): boolean
	return item.price ~= nil and (item.source == "shop" or item.source == "rotation")
end

-- Can be bought at `now` for `coins` (owning it is the caller's to check).
function ShopBrowse.affordable(item: Cosmetics.Item, coins: number, now: number): boolean
	if not item.price or item.price > coins then
		return false
	end
	if item.source == "rotation" then
		return ShopRotation.isFeatured(item.id, now)
	end
	return item.source == "shop"
end

-- A search: every word typed is in the name (any case).
function ShopBrowse.matches(item: Cosmetics.Item, search: string?): boolean
	if not search or search == "" then
		return true
	end
	local name = string.lower(item.name)
	for word in string.gmatch(string.lower(search), "%S+") do
		if not string.find(name, word, 1, true) then
			return false
		end
	end
	return true
end

export type Options = {
	show: string?,
	sort: string?,
	search: string?,
	coins: number?,
	now: number?,
	owns: (Cosmetics.Item) -> boolean,
	wished: ((Cosmetics.Item) -> boolean)?,
}

local function rarityRank(item: Cosmetics.Item): number
	return table.find(Cosmetics.RARITIES, item.rarity) or 0
end

-- The items to show, in order (a new list; `items` is left as it is).
function ShopBrowse.apply(items: { Cosmetics.Item }, options: Options): { Cosmetics.Item }
	local now = options.now or os.time()
	local show = options.show or "all"
	local kept: { Cosmetics.Item } = {}
	local place: { [Cosmetics.Item]: number } = {}
	for index, item in ipairs(items) do
		local ok = ShopBrowse.matches(item, options.search)
		if ok and show == "notOwned" then
			ok = not options.owns(item)
		elseif ok and show == "afford" then
			ok = not options.owns(item) and ShopBrowse.affordable(item, options.coins or 0, now)
		elseif ok and show == "wished" then
			ok = options.wished ~= nil and options.wished(item)
		end
		if ok then
			table.insert(kept, item)
			place[item] = index
		end
	end
	local sort = options.sort or "order"
	if sort == "order" then
		return kept
	end
	-- Items with no price (earned) go last when sorting by price; ties keep the catalog's order.
	local function key(item: Cosmetics.Item): (number, number)
		if sort == "cheapest" then
			return if item.price then -item.price else -math.huge, 0
		elseif sort == "dearest" then
			return item.price or -math.huge, 0
		elseif sort == "rarest" then
			return rarityRank(item), item.price or 0
		end
		return ShopBrowse.addedAt(item) or -math.huge, 0
	end
	table.sort(kept, function(a, b)
		local a1, a2 = key(a)
		local b1, b2 = key(b)
		if a1 ~= b1 then
			return a1 > b1
		elseif a2 ~= b2 then
			return a2 > b2
		end
		return place[a] < place[b]
	end)
	return kept
end

-- The wished items (not owned) in the day's hand, in its order.
function ShopBrowse.wishedToday(
	wishlist: { [string]: any },
	owns: (Cosmetics.Item) -> boolean,
	day: number
): { Cosmetics.Item }
	local found = {}
	for _, id in ipairs(ShopRotation.forDay(day)) do
		local item = Cosmetics.byId(id)
		if item and wishlist[id] and not owns(item) then
			table.insert(found, item)
		end
	end
	return found
end

return ShopBrowse
