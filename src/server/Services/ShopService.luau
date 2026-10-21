-- The cosmetic shop: buy with coins earned in matches, then equip in the lobby. Items from
-- the daily rotation can only be bought while they are featured; VIP and earned items
-- cannot be bought at all. An emote is not worn: a bought one goes on the emote wheel's first
-- empty slot (EmoteService). It also keeps what the shop needs to remember for browsing
-- (Shared/ShopBrowse): the new cards already looked at, and the wishlist, announced on arriving
-- when a wished card is in Today's hand. And Fate's draw (Shared/Fate): a card of the week's deck
-- not owned yet, for Fate.PRICE coins, told to the client (Net "Fate") so the shop can turn it over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Fate = require(Shared:WaitForChild("Fate"))
local Net = require(Shared:WaitForChild("Net"))
local ShopBrowse = require(Shared:WaitForChild("ShopBrowse"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local Analytics = require(script.Parent.Analytics)
local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local EmoteService = require(script.Parent.EmoteService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local ShopRequest = Net.event("ShopRequest")
local FateRemote = Net.event("Fate")

local ShopService = {}

-- Can this item be bought right now? Returns (ok, reason).
function ShopService.canBuy(item: Cosmetics.Item, now: number): (boolean, string)
	if not ShopRotation.priceOf(item, now) then
		return false, "That item cannot be bought."
	end
	if ShopRotation.rotates(item, now) then
		if not ShopRotation.isFeatured(item.id, now) then
			return false, "That item is not in today's rotation."
		end
	elseif item.source ~= "shop" then
		return false, "That item cannot be bought."
	end
	return true, ""
end

-- The new cards of a suit, looked at (their "New" ribbons go).
local function markSeen(player: Player, ids: any)
	local data = DataService.get(player)
	if not data or type(ids) ~= "table" then
		return
	end
	local now = os.time()
	local changed = false
	for index, id in ipairs(ids) do
		local item = if type(id) == "string" then Cosmetics.byId(id) else nil
		if index > 200 then
			break
		elseif item and ShopBrowse.isNew(item, now) and not data.shopSeen[id] then
			data.shopSeen[id] = true
			changed = true
		end
	end
	if changed then
		ShopBrowse.prune(data.shopSeen, now)
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- Fate's draw: a card of this week's deck not owned yet, by its odds.
local function drawFate(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if Match.get(player) then
		Match.notify(player, "Fate deals in the lobby.", "bad")
		return
	end
	local owns = function(item: Cosmetics.Item): boolean
		return CosmeticsService.owns(player, item)
	end
	local id = Fate.pick(Fate.deck(Fate.week(os.time())), owns, Random.new():NextNumber())
	local item = Cosmetics.byId(id)
	if not item then
		Match.notify(player, "Every card of this week's deck is yours. A new deck comes on Monday.", "info")
		return
	end
	if data.coins < Fate.PRICE then
		Match.notify(player, string.format("A draw costs %d coins.", Fate.PRICE), "bad")
		return
	end
	data.coins -= Fate.PRICE
	Analytics.coins(player, -Fate.PRICE, data.coins, "Shop", "fate:" .. item.id)
	data.owned[item.id] = true
	data.wishlist[item.id] = nil
	if item.kind == "emote" then
		EmoteService.placeBought(data, item.emote)
	end
	FateRemote:FireClient(player, { itemId = item.id })
	Match.notify(player, "Fate deals you " .. item.name .. ".", "good")
	CosmeticsService.grantSets(player)
	CosmeticsService.grantMilestones(player)
	DataService.push(player)
	DataService.saveSoon(player)
	CosmeticsService.apply(player)
end

-- A heart on a card: on the wishlist, or off it.
local function wish(player: Player, item: Cosmetics.Item, on: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	if on then
		if not ShopBrowse.wishable(item) or CosmeticsService.owns(player, item) then
			return
		end
		local count = 0
		for _ in pairs(data.wishlist) do
			count += 1
		end
		if count >= ShopBrowse.WISH_LIMIT then
			Match.notify(player, "Your wishlist is full (" .. ShopBrowse.WISH_LIMIT .. ").", "info")
			return
		end
		data.wishlist[item.id] = true
	elseif data.wishlist[item.id] then
		data.wishlist[item.id] = nil
	else
		return
	end
	DataService.push(player)
	DataService.saveSoon(player)
end

-- On arriving: the wished cards in Today's hand (bought ones leave the wishlist).
function ShopService.announceWishes(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local owns = function(item: Cosmetics.Item): boolean
		return CosmeticsService.owns(player, item)
	end
	for id in pairs(data.wishlist) do
		local item = Cosmetics.byId(id)
		if not item or owns(item) then
			data.wishlist[id] = nil
		end
	end
	local found = ShopBrowse.wishedToday(data.wishlist, owns, ShopRotation.dayOf(os.time()))
	if #found == 0 then
		return
	end
	local names = {}
	for _, item in ipairs(found) do
		table.insert(names, item.name)
	end
	Match.notify(
		player,
		string.format(
			"From your wishlist, in Today's hand: %s.",
			if #names == 1 then names[1] else table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
		),
		"good"
	)
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	if not RateLimit.allow(player, "shop", 0.3) then
		return
	end
	if payload.action == "seen" then
		markSeen(player, payload.itemIds)
		return
	elseif payload.action == "fate" then
		drawFate(player)
		return
	end
	if type(payload.itemId) ~= "string" then
		return
	end
	local data = DataService.get(player)
	local item = Cosmetics.byId(payload.itemId)
	if not data or not item then
		return
	end
	if Match.get(player) then
		Match.notify(player, "Cosmetics can be changed in the lobby.", "bad")
		return
	end
	local action = payload.action
	if action == "wish" then
		wish(player, item, payload.on == true)
		return
	end
	if action == "turn" then
		-- A card of Today's hand turned over (only to see it).
		if ShopRotation.turn(data.shopTurned, ShopRotation.dayOf(os.time()), item.id) then
			DataService.push(player)
			DataService.saveSoon(player)
		end
		return
	end
	if action == "buy" then
		if CosmeticsService.owns(player, item) then
			Match.notify(player, "You already own " .. item.name .. ".", "info")
			return
		end
		local ok, reason = ShopService.canBuy(item, os.time())
		if not ok then
			Match.notify(player, reason, "bad")
			return
		end
		local price = ShopRotation.priceOf(item, os.time()) :: number
		if data.coins < price then
			Match.notify(player, "Not enough coins for " .. item.name .. ".", "bad")
			return
		end
		data.coins -= price
		Analytics.coins(player, -price, data.coins, "Shop", item.id)
		data.owned[item.id] = true
		data.wishlist[item.id] = nil
		if item.kind == "emote" then
			local slot = EmoteService.placeBought(data, item.emote)
			Match.notify(
				player,
				if slot
					then string.format("Bought %s. It is on your emote wheel (%d).", item.name, slot)
					else "Bought " .. item.name .. ". Put it on your emote wheel in Your look.",
				"good"
			)
		else
			data.equipped[Cosmetics.slotOf(item)] = item.id
			Match.notify(player, "Bought and equipped " .. item.name .. ".", "good")
		end
		CosmeticsService.grantSets(player)
		CosmeticsService.grantMilestones(player)
	elseif action == "equip" then
		if item.kind == "emote" or not CosmeticsService.owns(player, item) then
			return
		end
		data.equipped[Cosmetics.slotOf(item)] = item.id
	elseif action == "unequip" then
		local slot = Cosmetics.slotOf(item)
		if data.equipped[slot] == item.id then
			data.equipped[slot] = nil
		end
	elseif action == "stance" then
		-- An emote that can be a stance becomes yours (picked again: none).
		if not item.stance or not CosmeticsService.owns(player, item) then
			return
		end
		data.stance = if data.stance == item.id then "" else item.id
	else
		return
	end
	DataService.push(player)
	DataService.saveSoon(player)
	CosmeticsService.apply(player)
end

function ShopService.init()
	ShopRequest.OnServerEvent:Connect(onRequest)
	DataService.ProfileLoaded:Connect(function(player)
		-- (a moment after arriving, once the lobby is on screen)
		task.delay(6, function()
			if player.Parent then
				ShopService.announceWishes(player)
			end
		end)
	end)
end

return ShopService
