-- The fixed patterns behind the small motions in the maps (Shared/LifePatterns): a sign stutters on a schedule and is
-- steady otherwise, a blink keeps its duty, a cycle walks its entries and eases between them, a phase is steady.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LifePatterns = require(Shared:WaitForChild("LifePatterns"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("LifePatterns", function()
		it("keeps a neon sign lit except in its stutter, the same every period", function()
			expect(LifePatterns.neon(5, 11, 0)).to.equal(1)
			expect(LifePatterns.neon(11.03, 11, 0) < 1).to.equal(true)
			expect(LifePatterns.neon(22.03, 11, 0)).to.equal(LifePatterns.neon(11.03, 11, 0))
			-- (past the stutter, the sign is steady)
			expect(LifePatterns.neon(11 + LifePatterns.NEON_LENGTH + 0.01, 11, 0)).to.equal(1)
		end)

		it("slides a sign's stutter with its phase", function()
			expect(LifePatterns.neon(0.03, 11, 0) < 1).to.equal(true)
			expect(LifePatterns.neon(0.03, 11, 5)).to.equal(1)
		end)

		it("never leaves a tube dark and ends its stutter on time", function()
			local lowest = 1
			for step = 0, 400 do
				lowest = math.min(lowest, LifePatterns.tube(step * 0.01, 13, 0))
			end
			expect(lowest > 0).to.equal(true)
			expect(lowest < 1).to.equal(true)
			expect(LifePatterns.tube(LifePatterns.TUBE_LENGTH + 0.01, 13, 0)).to.equal(1)
		end)

		it("blinks for its duty and no longer", function()
			local on = 0
			for step = 0, 99 do
				on += LifePatterns.blink(step * 0.02, 2, 0.25, 0)
			end
			expect(on).to.equal(25)
		end)

		it("walks through the entries of a cycle and eases between them", function()
			local index, nextIndex, k = LifePatterns.cycle(1, 4, 1, 0, 3)
			expect(index).to.equal(1)
			expect(nextIndex).to.equal(2)
			expect(k).to.equal(0)
			index, nextIndex, k = LifePatterns.cycle(4.5, 4, 1, 0, 3)
			expect(index).to.equal(1)
			expect(k > 0 and k < 1).to.equal(true)
			index, nextIndex = LifePatterns.cycle(5.5, 4, 1, 0, 3)
			expect(index).to.equal(2)
			expect(nextIndex).to.equal(3)
			index, nextIndex = LifePatterns.cycle(12.5, 4, 1, 0, 3)
			expect(index).to.equal(3)
			expect(nextIndex).to.equal(1)
		end)

		it("approaches a target without passing it", function()
			local value = 0
			for _ = 1, 600 do
				value = LifePatterns.approach(value, 1, 0.6, 1 / 30)
				expect(value <= 1).to.equal(true)
			end
			expect(value > 0.99).to.equal(true)
		end)

		it("keeps the wind and the sway in range", function()
			for step = 0, 500 do
				local g = LifePatterns.gust(step * 0.7)
				expect(g >= 0.59 and g <= 1.51).to.equal(true)
				local s = LifePatterns.sway(step * 0.1, 5, 0.4)
				expect(math.abs(s) <= 1).to.equal(true)
			end
		end)

		it("gives a place the same phase every time, inside its span", function()
			local a = LifePatterns.phaseOf(12.5, -40, 9)
			expect(a).to.equal(LifePatterns.phaseOf(12.5, -40, 9))
			expect(a >= 0 and a < 9).to.equal(true)
			expect(a ~= LifePatterns.phaseOf(13.5, -40, 9)).to.equal(true)
		end)
	end)
end
