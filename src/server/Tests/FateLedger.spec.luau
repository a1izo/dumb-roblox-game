-- Fate's draw (a weekly deck the same for everyone, worth a draw, odds that add up, never a card owned) and the
-- Season ledger (season dates, tiers, rewards paid once each, a new season starting again; the case's points
-- in ProgressRules.apply), and the season's emote joining Today's hand once the season is over.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Fate = require(Shared:WaitForChild("Fate"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Progression = Shared:WaitForChild("Progression")
local Ledger = require(Progression:WaitForChild("Ledger"))
local ProgressRules = require(Progression:WaitForChild("ProgressRules"))
local ShopRotation = require(Shared:WaitForChild("ShopRotation"))

local Migrations = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Migrations"))

local DAY = 86400

local function nobodyOwns(_: any): boolean
	return false
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Fate's draw", function()
		it("deals the same deck of twelve sold things to everyone, each worth a draw", function()
			for week = 2900, 2912 do
				local deck = Fate.deck(week)
				expect(#deck).to.equal(Fate.SIZE)
				expect(table.concat(Fate.deck(week), ",")).to.equal(table.concat(deck, ","))
				local seen = {}
				local rarities = {}
				for _, id in ipairs(deck) do
					local item = Cosmetics.byId(id) :: any
					expect(item ~= nil and Fate.eligible(item)).to.equal(true)
					expect(item.price >= Fate.PRICE).to.equal(true)
					expect(seen[id]).to.equal(nil)
					seen[id] = true
					-- (a Godhood card counts among the legendary ones: Shared/Rarity)
					rarities[Rarity.fateGroup(item.rarity)] = true
				end
				expect(rarities.legendary).to.equal(true)
			end
			expect(table.concat(Fate.deck(2900), ",")).never.to.equal(table.concat(Fate.deck(2901), ","))
		end)
		it("gives odds that add up, the rarer the less likely, and none for what is owned", function()
			local deck = Fate.deck(2905)
			local first = Cosmetics.byId(deck[1]) :: any
			local function ownsFirst(item: any): boolean
				return item.id == deck[1]
			end
			local odds = Fate.odds(deck, ownsFirst)
			expect(odds[deck[1]]).to.equal(nil)
			local total = 0
			local byRarity: { [string]: number } = {}
			for id, chance in pairs(odds) do
				total += chance
				byRarity[Rarity.fateGroup((Cosmetics.byId(id) :: any).rarity)] = chance
			end
			expect(total).to.be.near(1, 1e-9)
			if byRarity.legendary and byRarity.rare then
				expect(byRarity.legendary < byRarity.rare).to.equal(true)
			end
			expect(first ~= nil).to.equal(true)
		end)
		it("never deals a card owned, and nothing once the deck is owned", function()
			local deck = Fate.deck(2906)
			local owned = { [deck[2]] = true, [deck[5]] = true }
			local function owns(item: any): boolean
				return owned[item.id] == true
			end
			for roll = 0, 0.999, 0.037 do
				local id = Fate.pick(deck, owns, roll) :: string
				expect(id ~= nil and not owned[id]).to.equal(true)
			end
			expect(Fate.pick(deck, nobodyOwns, 0)).to.equal(deck[1])
			expect(Fate.pick(deck, function(_: any): boolean
				return true
			end, 0.5)).to.equal(nil)
		end)
	end)

	describe("Season ledger", function()
		it("runs seasons of six weeks from its first day", function()
			local start = Ledger.START
			expect(Ledger.season(start - 1)).to.equal(0)
			expect(Ledger.season(start)).to.equal(1)
			expect(Ledger.season(start + 42 * DAY - 1)).to.equal(1)
			expect(Ledger.season(start + 42 * DAY)).to.equal(2)
			local from, to = Ledger.bounds(2)
			expect(from).to.equal(start + 42 * DAY)
			expect(to - from).to.equal(42 * DAY)
			expect(Ledger.name(1)).to.equal("The Season of Names")
		end)
		it("pays each tier once, coins or the season's things, and starts again in a new season", function()
			local record = { season = 0, points = 0, tier = 0 }
			expect(#Ledger.add(record, 1, 99)).to.equal(0)
			local reached = Ledger.add(record, 1, 151)
			expect(#reached).to.equal(2)
			expect(reached[1].tier).to.equal(1)
			expect(reached[2].reward.coins).to.equal(34)
			expect(#Ledger.add(record, 1, 0)).to.equal(0)
			reached = Ledger.add(record, 1, 750)
			expect(reached[#reached].tier).to.equal(10)
			expect(reached[#reached].reward.item).to.equal("title_s1_bookkeeper")
			reached = Ledger.add(record, 1, 99999)
			expect(reached[#reached].tier).to.equal(Ledger.TIERS)
			expect(reached[#reached].reward.item).to.equal("emote_new_world")
			expect(#Ledger.add(record, 1, 500)).to.equal(0)
			reached = Ledger.add(record, 2, 100)
			expect(record.points).to.equal(100)
			expect(#reached).to.equal(1)
			expect(reached[1].reward.item).to.equal(nil)
			local view = Ledger.view(record, 3)
			expect(view.points).to.equal(0)
		end)
		it("names season things that exist", function()
			for _, season in pairs(Ledger.SEASONS) do
				for tier, id in pairs(season.items) do
					local item = Cosmetics.byId(id) :: any
					expect(item ~= nil and item.source == "season" and tier <= Ledger.TIERS).to.equal(true)
				end
			end
		end)
		it("writes a case's points, more for a win and each quest, and pays the tiers it reaches", function()
			local data = Migrations.defaults(0)
			local now = Ledger.START + 3 * DAY
			data.ledger = { season = 1, points = 95, tier = 0 }
			local summary = {
				won = true,
				role = "L",
				side = "Team",
				survived = true,
				tasks = 0,
				notesFound = 0,
				correctVotes = 0,
				kills = 0,
				reads = 0,
				arrests = 0,
				duties = 0,
				reports = 0,
				rigs = 0,
				ghost = false,
				xpBefore = 0,
			} :: any
			local result = ProgressRules.apply(data, summary, now)
			local ledger = result.ledger :: any
			expect(ledger ~= nil).to.equal(true)
			expect(ledger.points >= Ledger.PLAY + Ledger.WIN).to.equal(true)
			expect(data.ledger.points).to.equal(95 + ledger.points)
			expect(data.ledger.tier >= 1).to.equal(true)
			local paid = false
			for _, line in ipairs(result.lines) do
				if string.find(line.label, "Ledger, tier 1", 1, true) then
					paid = true
				end
			end
			expect(paid).to.equal(true)
		end)
		it("puts the season's emote in Today's hand only once the season is over, at its later price", function()
			local newWorld = Cosmetics.byId("emote_new_world") :: any
			local _, ends = Ledger.bounds(1)
			expect(Cosmetics.laterPrice(newWorld, ends - 1)).to.equal(nil)
			expect(Cosmetics.laterPrice(newWorld, ends)).to.equal(1200)
			expect(ShopRotation.priceOf(newWorld, ends - DAY)).to.equal(nil)
			expect(ShopRotation.rotates(newWorld, ends + DAY)).to.equal(true)
			local before, after = false, false
			for day = math.floor(ends / DAY) - 300, math.floor(ends / DAY) - 1 do
				if table.find(ShopRotation.forDay(day), "emote_new_world") then
					before = true
				end
			end
			for day = math.floor(ends / DAY), math.floor(ends / DAY) + 400 do
				if table.find(ShopRotation.forDay(day), "emote_new_world") then
					after = true
				end
			end
			expect(before).to.equal(false)
			expect(after).to.equal(true)
		end)
	end)
end
