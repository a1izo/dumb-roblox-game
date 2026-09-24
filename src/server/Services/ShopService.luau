-- The cosmetic shop: buy with coins earned in matches, then equip in the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local ShopRequest = Net.event("ShopRequest")

local ShopService = {}

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
	if Match.getLiving(player) then
		Match.notify(player, "Cosmetics can be changed in the lobby.", "bad")
		return
	end
	local action = payload.action
	if action == "buy" then
		if data.owned[item.id] then
			Match.notify(player, "You already own " .. item.name .. ".", "info")
			return
		end
		if data.coins < item.price then
			Match.notify(player, "Not enough coins for " .. item.name .. ".", "bad")
			return
		end
		data.coins -= item.price
		data.owned[item.id] = true
		data.equipped[item.kind] = item.id
		Match.notify(player, "Bought and equipped " .. item.name .. ".", "good")
	elseif action == "equip" then
		if not data.owned[item.id] then
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
