-- The shop's five tiers (Shared/Rarity), pinned to the owner's choices of 2026-10-17: Scrawl, Penned (Inked until 2026-10-21), Sealed,
-- Condemned and Godhood in their colours, crimson for Godhood alone; the four emotes with a private cutscene
-- and nothing else in Godhood, Final Breakdown and Reaper's Eyes at 1500; Godhood counted with the legendary
-- cards in Fate's deck; a confirm before buying Condemned or Godhood.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local Fate = require(Shared:WaitForChild("Fate"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local TitleFonts = require(Shared:WaitForChild("TitleFonts"))

local GODHOOD = {
	emote_new_world = true,
	emote_final_breakdown = true,
	emote_reapers_eyes = true,
	emote_just_as_planned = true,
}

local function hex(color: Color3): string
	return string.format(
		"%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Rarity", function()
		it("has five tiers in order, with their names and colours", function()
			expect(table.concat(Rarity.ORDER, ",")).to.equal("common,rare,epic,legendary,godhood")
			local names, colours = {}, {}
			for _, id in ipairs(Rarity.ORDER) do
				table.insert(names, Rarity.name(id))
				table.insert(colours, hex(Rarity.color(id)))
			end
			expect(table.concat(names, ",")).to.equal("Scrawl,Penned,Sealed,Condemned,Godhood")
			expect(table.concat(colours, ",")).to.equal("A7A29A,6F93C2,9C7BEA,D9963F,A3192F")
			expect(Cosmetics.RARITIES).to.equal(Rarity.ORDER)
		end)

		it("ranks them, and reads an unknown tier as Scrawl", function()
			for index, id in ipairs(Rarity.ORDER) do
				expect(Rarity.rank(id)).to.equal(index)
			end
			expect(Rarity.rank("mythic")).to.equal(1)
			expect(Rarity.rank(nil)).to.equal(1)
			expect(Rarity.name("nonsense")).to.equal("Scrawl")
		end)

		it("keeps crimson for Godhood alone, darker than the danger red", function()
			local crimson = Rarity.color("godhood")
			for _, id in ipairs(Rarity.ORDER) do
				if id ~= "godhood" then
					local color = Rarity.color(id)
					-- every other tier is clearly not a red
					expect(color.R - math.max(color.G, color.B) < 0.4).to.equal(true)
				end
			end
			local danger = Color3.fromRGB(225, 17, 43)
			local function luma(c: Color3): number
				return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
			end
			expect(luma(crimson) < luma(danger)).to.equal(true)
		end)

		it("puts exactly the four emotes with a private cutscene, and a win cutscene a side, in Godhood", function()
			-- (the win cutscenes' Godhood ones: the owner's Q13, 2026-10-20)
			local WIN_GODHOOD = { win_coven_god = true, win_bureau_mate = true }
			for _, item in ipairs(Cosmetics.ITEMS) do
				expect(item.rarity == "godhood").to.equal(GODHOOD[item.id] == true or WIN_GODHOOD[item.id] == true)
				if GODHOOD[item.id] then
					expect(EmoteInfo.of(item.emote).cinematic).to.equal(true)
				end
			end
		end)

		it("sells Final Breakdown and Reaper's Eyes for 1500", function()
			expect((Cosmetics.byId("emote_final_breakdown") :: any).price).to.equal(1500)
			expect((Cosmetics.byId("emote_reapers_eyes") :: any).price).to.equal(1500)
		end)

		it("counts Godhood with the legendary cards in Fate's deck", function()
			expect(Rarity.fateGroup("godhood")).to.equal("legendary")
			for _, id in ipairs({ "common", "rare", "epic", "legendary" }) do
				expect(Rarity.fateGroup(id)).to.equal(id)
			end
			-- every weekly deck holds its legendary quota, Condemned and Godhood cards together
			local available = 0
			for _, item in ipairs(Cosmetics.ITEMS) do
				if Fate.eligible(item) and Rarity.fateGroup(item.rarity) == "legendary" then
					available += 1
				end
			end
			local wanted = math.min(Fate.QUOTA.legendary, available)
			local sawGodhood = false
			for week = 2900, 2960 do
				local top = 0
				for _, id in ipairs(Fate.deck(week)) do
					local rarity = (Cosmetics.byId(id) :: any).rarity
					if Rarity.fateGroup(rarity) == "legendary" then
						top += 1
					end
					sawGodhood = sawGodhood or rarity == "godhood"
				end
				expect(top >= wanted).to.equal(true)
			end
			-- and Godhood cards do come up in it
			expect(sawGodhood).to.equal(true)
		end)

		it("asks to confirm before buying Condemned or Godhood, never a lower tier", function()
			local asks = {}
			for _, id in ipairs(Rarity.ORDER) do
				table.insert(asks, tostring(Rarity.confirms(id)))
			end
			expect(table.concat(asks, ",")).to.equal("false,false,false,true,true")
		end)

		it(
			"gives each title tier its own look: no mark, a dot, then a diamond; the top two lean to their colour",
			function()
				local marks, leans = {}, {}
				for _, id in ipairs(Rarity.ORDER) do
					local mark, lean = Rarity.titleLook(id)
					table.insert(marks, mark or "-")
					table.insert(leans, tostring(lean > 0))
				end
				expect(table.concat(marks, ",")).to.equal("-,·,◆,◆,◆")
				expect(table.concat(leans, ",")).to.equal("false,false,false,true,true")
			end
		)

		it("writes a title in capitals between its marks, safe in rich text", function()
			local grey = Color3.fromRGB(163, 170, 181)
			local plain, letters = Rarity.titleText("Trainee", "common", grey)
			expect(plain).to.equal("TRAINEE")
			expect(letters == grey).to.equal(true)
			local marked = Rarity.titleText("Salt & <Ash>", "epic", grey)
			expect(string.find(marked, "SALT &amp; &lt;ASH&gt;", 1, true) ~= nil).to.equal(true)
			local _, marks = string.gsub(marked, "◆", "")
			expect(marks).to.equal(2)
			local _, amber = Rarity.titleText("Gilded Age", "legendary", grey)
			expect(amber == grey).to.equal(false)
		end)

		it("sets every title in a face of its own (Shared/TitleFonts), no two alike", function()
			local seen = {}
			for _, item in ipairs(Cosmetics.ofKind("title")) do
				local look = TitleFonts.look(item.id)
				expect(look ~= nil).to.equal(true)
				if look then
					local key = string.format(
						"%s/%s/%s/%s",
						look.font.Name,
						if look.weight then look.weight.Name else "-",
						tostring(look.italic == true),
						look.case or "upper"
					)
					expect(seen[key]).to.equal(nil)
					seen[key] = item.id
				end
			end
			local styled = Rarity.titleText("Terminally Online", "legendary", Color3.new(1, 1, 1), "title_set_online")
			expect(string.find(styled, "terminally online", 1, true) ~= nil).to.equal(true)
			expect(string.find(styled, "family=", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
