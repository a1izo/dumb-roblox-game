-- Masked names for the lobby's name duel.

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
end
