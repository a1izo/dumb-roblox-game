-- Letter reveal rules for the task flash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LetterReveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LetterReveal"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("LetterReveal.mask", function()
		it("shows only the chosen letters", function()
			expect(LetterReveal.mask("Haruto Kisaragi", { 1, 3, 6 })).to.equal("H _ R _ _ O   _ _ _ _ _ _ _ _")
		end)
		it("uppercases revealed letters", function()
			expect(LetterReveal.mask("Ren Ito", { 5 })).to.equal("_ _ _   I _ _")
		end)
	end)

	describe("LetterReveal.pickNew", function()
		it("reveals three letters never shown before", function()
			local rng = Random.new(7)
			local name = "Mei Tachibana"
			local revealed = {}
			local seen = 0
			for _ = 1, 4 do
				local picks = LetterReveal.pickNew(name, revealed, 3, rng)
				expect(#picks).to.equal(3)
				for _, index in ipairs(picks) do
					expect(revealed[index]).to.equal(nil)
					expect(string.sub(name, index, index)).never.to.equal(" ")
					revealed[index] = true
					seen += 1
				end
			end
			expect(seen).to.equal(12)
		end)
		it("still shows three letters once the name is used up", function()
			local rng = Random.new(3)
			local revealed = { [1] = true, [2] = true, [3] = true, [5] = true, [6] = true }
			local picks = LetterReveal.pickNew("Ren Ito", revealed, 3, rng)
			expect(#picks).to.equal(3)
		end)
	end)

	describe("LetterReveal.fakeMask", function()
		it("keeps the word lengths of the real name", function()
			local fake = LetterReveal.fakeMask("Sora Kato", 3, Random.new(11))
			local real = LetterReveal.mask("Sora Kato", {})
			expect(#fake).to.equal(#real)
		end)
	end)
end
