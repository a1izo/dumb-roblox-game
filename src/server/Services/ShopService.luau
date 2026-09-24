-- The cosmetic shop: buy with coins earned in matches, then equip in the lobby. Items from
-- the daily rotation can only be bought while they are featured; VIP and earned items
-- cannot be bought at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local Analytics = require(script.Parent.Analytics)
local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local ShopRequest = Net.event("ShopRequest")

local ShopService = {}

-- Can this item be bought right now? Returns (ok, reason).
function ShopService.canBuy(item: Cosmetics.Item, now: number): (boolean, string)
	if not item.price then
		return false, "That item cannot be bought."
	end
	if item.source == "rotation" and not ShopRotation.isFeatured(item.id, now) then
		return false, "That item is not in today's rotation."
	end
	if item.source ~= "shop" and item.source ~= "rotation" then
		return false, "That item cannot be bought."
	end
	return true, ""
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.itemId) ~= "string" then
		return
	end
	if not RateLimit.allow(player, "shop", 0.3) then
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
		local price = item.price :: number
		if data.coins < price then
			Match.notify(player, "Not enough coins for " .. item.name .. ".", "bad")
			return
		end
		data.coins -= price
		Analytics.coins(player, -price, data.coins, "Shop", item.id)
		data.owned[item.id] = true
		data.equipped[item.kind] = item.id
		Match.notify(player, "Bought and equipped " .. item.name .. ".", "good")
	elseif action == "equip" then
		if not CosmeticsService.owns(player, item) then
			return
		end
		data.equipped[item.kind] = item.id
	elseif action == "unequip" then
		if data.equipped[item.kind] == item.id then
			data.equipped[item.kind] = nil
		end
	else
		return
	end
	DataService.push(player)
	DataService.saveSoon(player)
	CosmeticsService.apply(player)
end

function ShopService.init()
	ShopRequest.OnServerEvent:Connect(onRequest)
end

return ShopService
