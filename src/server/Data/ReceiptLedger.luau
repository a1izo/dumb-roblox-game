--!strict
-- Records Robux purchases in the profile so each one is granted exactly once, even when
-- Roblox calls ProcessReceipt again after a crash or a failed save.
--
-- data.receipts is [purchaseId] = unix time. apply() grants and records a purchase and
-- returns an undo for when the save fails. prune() keeps the ledger small: it keeps the
-- newest KEEP entries, and never drops an entry younger than MIN_AGE (Roblox can retry a
-- receipt for days).

local ReceiptLedger = {}

ReceiptLedger.KEEP = 100
ReceiptLedger.MIN_AGE = 30 * 86400

-- status: "granted", "duplicate" or "invalid".
function ReceiptLedger.apply(data: any, purchaseId: any, coins: number, now: number): (string, (() -> ())?)
	if type(data) ~= "table" or type(purchaseId) ~= "string" or purchaseId == "" or coins <= 0 then
		return "invalid", nil
	end
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	if data.receipts[purchaseId] ~= nil then
		return "duplicate", nil
	end
	data.receipts[purchaseId] = now
	data.coins += coins
	local undone = false
	return "granted",
		function()
			if undone then
				return
			end
			undone = true
			data.coins -= coins
			data.receipts[purchaseId] = nil
		end
end

function ReceiptLedger.prune(receipts: { [string]: number }, now: number)
	local list = {}
	for id, time in pairs(receipts) do
		table.insert(list, { id = id, time = time })
	end
	if #list <= ReceiptLedger.KEEP then
		return
	end
	table.sort(list, function(a, b)
		return a.time < b.time
	end)
	local excess = #list - ReceiptLedger.KEEP
	for index = 1, excess do
		local entry = list[index]
		if now - entry.time > ReceiptLedger.MIN_AGE then
			receipts[entry.id] = nil
		end
	end
end

return ReceiptLedger
