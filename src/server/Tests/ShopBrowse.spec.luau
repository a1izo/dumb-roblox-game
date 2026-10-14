-- Browsing the shop (Shared/ShopBrowse): the search, the show filter and the orders; what counts as new
-- and for how long; what can be wished for, and the wished cards found in a day's hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local ShopBrowse = require(Shared:WaitForChild("ShopBrowse"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local DAY = 86400

local function item(id: string, name: string, price: number?, rarity: string, source: string, added: string?): any
	return { id = id, kind = "emote", name = name, price = price, rarity = rarity, source = source, added = added }
end

local A = item("a", "Office Party", 450, "rare", "shop", "2026-10-14")
local B = item("b", "The Classic", 200, "common", "shop", nil)
local C = item("c", "Final Breakdown", 650, "epic", "shop", "2026-10-01")
local D = item("d", "New World", nil, "legendary", "season", "2026-10-14")
local LIST = { A, B, C, D }

local function ids(list: { any }): string
	local out = {}
	for _, entry in ipairs(list) do
		table.insert(out, entry.id)
	end
	return table.concat(out, ",")
end

local function nobodyOwns(_: any): boolean
	return false
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Shop browsing", function()
		it("searches by every word typed, in any case", function()
			expect(ShopBrowse.matches(A, "party")).to.equal(true)
			expect(ShopBrowse.matches(A, "OFFICE par")).to.equal(true)
			expect(ShopBrowse.matches(A, "office dance")).to.equal(false)
			expect(ShopBrowse.matches(A, "")).to.equal(true)
			expect(ShopBrowse.matches(A, "  ")).to.equal(true)
			expect(ids(ShopBrowse.apply(LIST, { search = "the", owns = nobodyOwns }))).to.equal("b")
		end)
		it("shows what is not owned, what you can afford and what you wished for", function()
			local function ownsB(entry: any): boolean
				return entry == B
			end
			expect(ids(ShopBrowse.apply(LIST, { show = "notOwned", owns = ownsB }))).to.equal("a,c,d")
			-- (D is earned, never sold; B is owned)
			expect(ids(ShopBrowse.apply(LIST, { show = "afford", coins = 500, owns = ownsB }))).to.equal("a")
			expect(ids(ShopBrowse.apply(LIST, {
				show = "wished",
				owns = nobodyOwns,
				wished = function(entry: any): boolean
					return entry == C
				end,
			}))).to.equal("c")
		end)
		it("orders by price, rarity and newness, the unpriced last and ties as dealt", function()
			local now = DateTime.fromUniversalTime(2026, 10, 15).UnixTimestamp
			local function order(sort: string): string
				return ids(ShopBrowse.apply(LIST, { sort = sort, owns = nobodyOwns, now = now }))
			end
			expect(order("order")).to.equal("a,b,c,d")
			expect(order("cheapest")).to.equal("b,a,c,d")
			expect(order("dearest")).to.equal("c,a,b,d")
			expect(order("rarest")).to.equal("d,c,a,b")
			expect(order("newest")).to.equal("a,d,c,b")
			expect(#LIST).to.equal(4) -- (the list given is left as it was)
		end)
		it("cycles its choices and names them", function()
			expect(ShopBrowse.after(ShopBrowse.SHOW, "all").id).to.equal("notOwned")
			expect(ShopBrowse.after(ShopBrowse.SORTS, "newest").id).to.equal("order")
			expect(ShopBrowse.after(ShopBrowse.SORTS, "nonsense").id).to.equal("order")
			expect(ShopBrowse.nameOf(ShopBrowse.SHOW, "afford")).to.equal("Can afford")
		end)
		it("counts a card new for two weeks from the day it came", function()
			local came = DateTime.fromUniversalTime(2026, 10, 14).UnixTimestamp
			expect(ShopBrowse.addedAt(A)).to.equal(came)
			expect(ShopBrowse.isNew(A, came)).to.equal(true)
			expect(ShopBrowse.isNew(A, came + 13 * DAY)).to.equal(true)
			expect(ShopBrowse.isNew(A, came + ShopBrowse.NEW_DAYS * DAY)).to.equal(false)
			expect(ShopBrowse.isNew(A, came - DAY)).to.equal(false)
			expect(ShopBrowse.isNew(B, came)).to.equal(false)
			expect(ShopBrowse.addedAt(item("x", "X", 1, "common", "shop", "14/10/2026"))).to.equal(nil)
		end)
		it("dates every catalog date it can read", function()
			for _, entry in ipairs(Cosmetics.ITEMS) do
				if (entry :: any).added ~= nil then
					expect(ShopBrowse.addedAt(entry) ~= nil).to.equal(true)
				end
			end
		end)
		it("forgets what was seen once it is no longer new", function()
			local real = Cosmetics.byId("emote_office_party")
			expect(real ~= nil).to.equal(true)
			local came = ShopBrowse.addedAt(real :: any) :: number
			local seen = { emote_office_party = true, nothing_at_all = true }
			ShopBrowse.prune(seen, came + DAY)
			expect(seen.emote_office_party).to.equal(true)
			expect(seen.nothing_at_all).to.equal(nil)
			ShopBrowse.prune(seen, came + 30 * DAY)
			expect(seen.emote_office_party).to.equal(nil)
		end)
		it("wishes only for what is sold", function()
			expect(ShopBrowse.wishable(A)).to.equal(true)
			expect(ShopBrowse.wishable(D)).to.equal(false)
			expect(ShopBrowse.wishable(item("v", "V", 100, "rare", "vip"))).to.equal(false)
			expect(ShopBrowse.wishable(item("r", "R", 100, "rare", "rotation"))).to.equal(true)
		end)
		it("finds the wished cards in a day's hand, in its order, unowned", function()
			local day = 20375
			local hand = ShopRotation.forDay(day)
			local wishlist = { [hand[3]] = true, [hand[1]] = true, not_in_the_hand = true }
			local found = ShopBrowse.wishedToday(wishlist, nobodyOwns, day)
			expect(ids(found)).to.equal(hand[1] .. "," .. hand[3])
			local ownsFirst = function(entry: any): boolean
				return entry.id == hand[1]
			end
			expect(ids(ShopBrowse.wishedToday(wishlist, ownsFirst, day))).to.equal(hand[3])
		end)
	end)
end
