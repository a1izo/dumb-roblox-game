-- Purchases are granted exactly once, the shop rotation is stable and fair, aliases follow
-- the rules, private-server settings stay in range, and cosmetic ids never change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AliasRules = require(Shared:WaitForChild("AliasRules"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local NamePools = require(Shared:WaitForChild("NamePools"))
local Products = require(Shared:WaitForChild("Products"))
local SettingsSchema = require(Shared:WaitForChild("SettingsSchema"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local ReceiptLedger = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("ReceiptLedger"))

-- Ids saved in profiles before cosmetics v2; they must keep working.
local LEGACY_IDS = {
	"hat_cap",
	"hat_fedora",
	"hat_deerstalker",
	"hat_fedora_white",
	"hat_tophat",
	"trail_ink",
	"trail_crimson",
	"trail_ice",
	"trail_gold",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ReceiptLedger", function()
		it("grants a purchase once", function()
			local data = { coins = 0, receipts = {} }
			local status = ReceiptLedger.apply(data, "p1", 500, 1000)
			expect(status).to.equal("granted")
			expect(data.coins).to.equal(500)
			local again = ReceiptLedger.apply(data, "p1", 500, 1001)
			expect(again).to.equal("duplicate")
			expect(data.coins).to.equal(500)
		end)
		it("undoes a grant when the save fails", function()
			local data = { coins = 100, receipts = {} }
			local _, undo = ReceiptLedger.apply(data, "p2", 500, 1000)
			expect(undo ~= nil).to.equal(true)
			if undo then
				undo()
			end
			expect(data.coins).to.equal(100)
			expect(data.receipts.p2).to.equal(nil)
			expect(ReceiptLedger.apply(data, "p2", 500, 1002)).to.equal("granted")
		end)
		it("rejects bad receipts", function()
			expect(ReceiptLedger.apply({ coins = 0 }, nil, 500, 0)).to.equal("invalid")
			expect(ReceiptLedger.apply({ coins = 0 }, "p3", 0, 0)).to.equal("invalid")
		end)
		it("prunes old entries but keeps recent ones", function()
			local receipts = {}
			local now = 100 * 86400
			for i = 1, 150 do
				receipts["old" .. i] = i
			end
			receipts.recent = now - 60
			ReceiptLedger.prune(receipts, now)
			local count = 0
			for _ in pairs(receipts) do
				count += 1
			end
			expect(count).to.equal(ReceiptLedger.KEEP)
			expect(receipts.recent ~= nil).to.equal(true)
		end)
	end)

	describe("Products", function()
		it("gives Premium members 10% more coins", function()
			local pack = Products.COIN_PACKS[1]
			expect(Products.coinsFor(pack, true)).to.equal(math.floor(pack.coins * 1.1 + 0.5))
			expect(Products.coinsFor(pack, false)).to.equal(pack.coins)
		end)
		it("never matches an unset id", function()
			expect(Products.packById(0)).to.equal(nil)
			expect(Products.passById(0)).to.equal(nil)
		end)
	end)

	describe("ShopRotation", function()
		it("is the same for everyone on a day", function()
			local a = ShopRotation.forDay(20000)
			local b = ShopRotation.forDay(20000)
			expect(table.concat(a, ",")).to.equal(table.concat(b, ","))
		end)
		it("always features something rare or better", function()
			for day = 20000, 20060 do
				local found = false
				for _, id in ipairs(ShopRotation.forDay(day)) do
					local item = Cosmetics.byId(id)
					if item and item.rarity ~= "common" then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)
		it("turns today's cards once each, and starts again on a new day", function()
			local record = { day = -1, cards = {} }
			local hand = ShopRotation.forDay(20002)
			expect(ShopRotation.turn(record, 20002, hand[1])).to.equal(true)
			expect(ShopRotation.turn(record, 20002, hand[1])).to.equal(false)
			local outside = nil
			for _, item in ipairs(Cosmetics.ITEMS) do
				if not outside and not table.find(ShopRotation.hand(20002), item.id) then
					outside = item.id
				end
			end
			expect(ShopRotation.turn(record, 20002, outside)).to.equal(false)
			expect(ShopRotation.turn(record, 20002, ShopRotation.dealFor(20002))).to.equal(true)
			expect(#ShopRotation.turned(record, 20002)).to.equal(2)
			expect(#ShopRotation.turned(record, 20003)).to.equal(0)
			local next = ShopRotation.forDay(20003)
			expect(ShopRotation.turn(record, 20003, next[1])).to.equal(true)
			expect(record.day).to.equal(20003)
			expect(#record.cards).to.equal(1)
		end)
		it("deals a card of the shop's own stock each day, a quarter off, beside the six", function()
			local deals = {}
			for day = 20000, 20060 do
				local id = ShopRotation.dealFor(day) :: string
				local item = Cosmetics.byId(id)
				expect(item ~= nil and item.source == "shop" and item.price ~= nil).to.equal(true)
				expect(table.find(ShopRotation.forDay(day), id)).to.equal(nil)
				expect(ShopRotation.dealFor(day)).to.equal(id)
				local hand = ShopRotation.hand(day)
				expect(#hand).to.equal(ShopRotation.SIZE + 1)
				expect(hand[#hand]).to.equal(id)
				deals[id] = true
			end
			local kinds = 0
			for _ in pairs(deals) do
				kinds += 1
			end
			expect(kinds > 10).to.equal(true)
		end)
		it("prices the deal a quarter off, rounded down to 5, on its day and in the grace", function()
			expect(ShopRotation.dealPrice(450)).to.equal(335)
			expect(ShopRotation.dealPrice(200)).to.equal(150)
			expect(ShopRotation.dealPrice(1000)).to.equal(750)
			local day = 20010
			local item = Cosmetics.byId(ShopRotation.dealFor(day) :: string) :: Cosmetics.Item
			local price = item.price :: number
			local noon = day * 86400 + 43200
			expect(ShopRotation.priceOf(item, noon)).to.equal(ShopRotation.dealPrice(price))
			expect(ShopRotation.dealPrice(price) <= price * 0.75).to.equal(true)
			local nextMidnight = (day + 1) * 86400
			local still = ShopRotation.dealFor(day + 1) == item.id
			expect(ShopRotation.priceOf(item, nextMidnight + 60)).to.equal(ShopRotation.dealPrice(price))
			expect(ShopRotation.priceOf(item, nextMidnight + ShopRotation.GRACE + 60)).to.equal(
				if still then ShopRotation.dealPrice(price) else price
			)
			local rotation = Cosmetics.byId(ShopRotation.forDay(day)[1]) :: Cosmetics.Item
			expect(ShopRotation.priceOf(rotation, noon)).to.equal(rotation.price)
		end)
		it("only features rotation items, without repeats", function()
			local seen = {}
			for _, id in ipairs(ShopRotation.forDay(20001)) do
				local item = Cosmetics.byId(id)
				expect(item ~= nil and item.source == "rotation").to.equal(true)
				expect(seen[id]).to.equal(nil)
				seen[id] = true
			end
		end)
	end)

	describe("AliasRules", function()
		it("accepts a plain alias", function()
			expect((AliasRules.check("Nightjar"))).to.equal(true)
		end)
		it("rejects short, long and non-letter aliases", function()
			expect((AliasRules.check("Ab"))).to.equal(false)
			expect((AliasRules.check("Abcdefghijklmn"))).to.equal(false)
			expect((AliasRules.check("Night Jar"))).to.equal(false)
			expect((AliasRules.check("Jar2"))).to.equal(false)
		end)
		it("rejects pool names and full names run together", function()
			local first = NamePools.FIRST_NAMES[1]
			local last = NamePools.LAST_NAMES[1]
			expect((AliasRules.check(first))).to.equal(false)
			expect((AliasRules.check(last))).to.equal(false)
			if #(first .. last) <= AliasRules.MAX then
				expect((AliasRules.check(first .. last))).to.equal(false)
			end
		end)
		it("rejects reserved words", function()
			expect((AliasRules.check("Admin"))).to.equal(false)
			expect((AliasRules.check("Inkbound"))).to.equal(false)
			expect((AliasRules.check("DeathsGambit"))).to.equal(false)
			expect((AliasRules.check("Ace"))).to.equal(false)
			expect((AliasRules.check("Diavolo"))).to.equal(false)
		end)
		it("keeps clear of player names", function()
			expect(AliasRules.clearOf("Nightjar", { "builderman", "Night_Jar" })).to.equal(false)
			expect(AliasRules.clearOf("Nightjar", { "builderman", "Somebody" })).to.equal(true)
		end)
	end)

	describe("SettingsSchema", function()
		it("clamps values into range and steps", function()
			local settings = SettingsSchema.clamp({ rounds = 99, investigation = 7, meeting = 64, maps = {} })
			expect(settings.rounds).to.equal(SettingsSchema.RANGES.rounds.max)
			expect(settings.investigation).to.equal(SettingsSchema.RANGES.investigation.min)
			expect(settings.meeting).to.equal(60)
			expect(#settings.maps).to.equal(#SettingsSchema.MAPS)
		end)
		it("knows default settings are not custom", function()
			expect(SettingsSchema.isCustom(SettingsSchema.defaults())).to.equal(false)
			local custom = SettingsSchema.defaults()
			custom.rounds = 3
			expect(SettingsSchema.isCustom(custom)).to.equal(true)
		end)
	end)

	describe("Cosmetics", function()
		it("keeps every id saved before cosmetics v2", function()
			for _, id in ipairs(LEGACY_IDS) do
				expect(Cosmetics.byId(id) ~= nil).to.equal(true)
			end
		end)
		it("gives every item a known kind and rarity, and ids once", function()
			local seen = {}
			for _, item in ipairs(Cosmetics.ITEMS) do
				expect(table.find(Cosmetics.KINDS, item.kind) ~= nil).to.equal(true)
				expect(Cosmetics.RARITY_COLORS[item.rarity] ~= nil).to.equal(true)
				expect(seen[item.id]).to.equal(nil)
				seen[item.id] = true
				if item.source == "shop" or item.source == "rotation" then
					expect(type(item.price)).to.equal("number")
				end
			end
		end)
		it("deals every kind in exactly one suit", function()
			expect(#Cosmetics.KINDS).to.equal(10)
			for _, kind in ipairs(Cosmetics.KINDS) do
				local suits = 0
				for _, suit in ipairs(Cosmetics.SUITS) do
					if suit.kinds and table.find(suit.kinds, kind) then
						suits += 1
					end
				end
				expect(suits).to.equal(1)
			end
		end)
	end)
end
