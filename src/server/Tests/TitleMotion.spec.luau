-- The titles whose letters move (Shared/TitleMotion, World/TitleAnimator; docs/shop-roadmap.md "Animated titles"):
-- each is a real title on sale for coins, in a face of its own, with a motion the animator plays and a line saying
-- what it does; no two share a motion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local TitleFonts = require(Shared:WaitForChild("TitleFonts"))
local TitleMotion = require(Shared:WaitForChild("TitleMotion"))

-- (the motions World/TitleAnimator draws)
local PLAYED = { flicker = true, chalk = true, heartbeat = true, shiver = true, afterglow = true }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	describe("Moving titles", function()
		it("are titles sold for coins, each in its own face", function()
			local count = 0
			for id in pairs(TitleMotion.all()) do
				count += 1
				local item = Cosmetics.byId(id)
				expect(item ~= nil).to.equal(true)
				expect(item and item.kind).to.equal("title")
				expect(item and item.source).to.equal("shop")
				expect(type(item and item.price) == "number" and (item :: any).price > 0).to.equal(true)
				expect(TitleFonts.look(id) ~= nil).to.equal(true)
			end
			expect(count).to.equal(5)
		end)
		it("each move as the animator can, a motion apiece, said in words", function()
			local seen = {}
			for _, kind in pairs(TitleMotion.all()) do
				expect(PLAYED[kind]).to.equal(true)
				expect(seen[kind]).to.equal(nil)
				seen[kind] = true
				expect(type(TitleMotion.NAMES[kind])).to.equal("string")
			end
		end)
		it("leave every other title still", function()
			expect(TitleMotion.of("title_detective")).to.equal(nil)
			expect(TitleMotion.of(nil)).to.equal(nil)
		end)
	end)
end
