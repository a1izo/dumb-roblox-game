-- Developer product purchases (coin packs). A purchase is only reported to Roblox as
-- granted after the coins are safely saved; if anything is not ready, Roblox is told to try
-- again later, and a repeated receipt is never granted twice (ReceiptLedger).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Products = require(Shared:WaitForChild("Products"))

local Data = script.Parent.Parent:WaitForChild("Data")
local ReceiptLedger = require(Data:WaitForChild("ReceiptLedger"))

local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)

local MonetizationService = {}

local PurchaseGranted = Enum.ProductPurchaseDecision.PurchaseGranted
local NotProcessedYet = Enum.ProductPurchaseDecision.NotProcessedYet

function MonetizationService.processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return NotProcessedYet
	end
	local pack = Products.packById(receipt.ProductId)
	if not pack then
		warn("[Inkbound] A purchase of an unknown product id " .. tostring(receipt.ProductId) .. " is waiting.")
		return NotProcessedYet
	end
	local data = DataService.get(player)
	if not data or not DataService.isPersistent(player) then
		return NotProcessedYet
	end
	local premium = player.MembershipType == Enum.MembershipType.Premium
	local coins = Products.coinsFor(pack, premium)
	local status, undo = ReceiptLedger.apply(data, receipt.PurchaseId, coins, os.time())
	if status == "duplicate" then
		return PurchaseGranted
	elseif status ~= "granted" then
		return NotProcessedYet
	end
	if DataService.saveNow(player) then
		ReceiptLedger.prune(data.receipts, os.time())
		DataService.push(player)
		Match.notify(player, string.format("Thank you! +%d coins.", coins), "good")
		return PurchaseGranted
	end
	if undo then
		undo()
	end
	DataService.push(player)
	return NotProcessedYet
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, result = pcall(MonetizationService.processReceipt, receipt)
		if ok then
			return result
		end
		warn("[Inkbound] ProcessReceipt failed: " .. tostring(result))
		return NotProcessedYet
	end
end

return MonetizationService
