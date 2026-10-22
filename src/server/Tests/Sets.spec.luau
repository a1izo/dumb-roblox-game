-- Matching sets: every piece and title exists, a set completes only when every piece is owned, and its
-- title is handed out once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Sets = require(Shared:WaitForChild("Sets"))
local Mastery = require(Shared:WaitForChild("Progression"):WaitForChild("Mastery"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Sets", function()
		it("names only pieces and titles that exist", function()
			expect(Sets.valid()).to.equal(true)
		end)
		it("completes a set only when every piece is owned, once", function()
			local owned = { hat_fedora = true }
			local function owns(id: string): boolean
				return owned[id] == true
			end
			expect(#Sets.completed(owns)).to.equal(0)
			owned.writing_typewriter = true
			local done = Sets.completed(owns)
			expect(#done).to.equal(1)
			expect(done[1].id).to.equal("noir")
			owned[done[1].title] = true
			expect(#Sets.completed(owns)).to.equal(0)
		end)
		it("knows which sets an item is a piece of", function()
			expect(#Sets.of("death_stone")).to.equal(1)
			expect(#Sets.of("hat_cap")).to.equal(0)
		end)
	end)

	describe("Styles and emotes", function()
		it("gives every style a style and every emote a clip", function()
			for _, item in ipairs(Cosmetics.ITEMS) do
				if item.kind == "writing" or item.kind == "verdict" or item.kind == "death" then
					expect(type(item.style)).to.equal("string")
				elseif item.kind == "emote" then
					expect(type(item.emote)).to.equal("string")
					expect(Cosmetics.emote(item.emote)).to.equal(item)
				elseif item.kind == "specter" then
					expect(type(item.form)).to.equal("string")
				end
			end
		end)
		it("unlocks The Knife and Sugar Cubes at mastery 7", function()
			expect(Mastery.UNLOCKS.Kira[7]).to.equal("writing_knife") -- terms:ok (internal role id)
			expect(Mastery.UNLOCKS.L[7]).to.equal("verdict_sugar")
		end)
	end)
end
