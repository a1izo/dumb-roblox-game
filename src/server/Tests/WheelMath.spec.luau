-- The emote wheel's arithmetic (Shared/WheelMath): slot 1 at the top and clockwise, a dead zone in the middle,
-- each slot owning its 45 degrees, the slots' places round the wheel, and the Recent list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WheelMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WheelMath"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("WheelMath", function()
		it("measures angles clockwise from straight up", function()
			expect(WheelMath.angle(0, -1)).to.be.near(0, 1e-9)
			expect(WheelMath.angle(1, 0)).to.be.near(90, 1e-9)
			expect(WheelMath.angle(0, 1)).to.be.near(180, 1e-9)
			expect(WheelMath.angle(-1, 0)).to.be.near(270, 1e-9)
		end)

		it("picks slot 1 at the top and the rest clockwise, each over its own 45 degrees", function()
			expect(WheelMath.slot(0, -100, 10)).to.equal(1)
			expect(WheelMath.slot(100, -100, 10)).to.equal(2)
			expect(WheelMath.slot(100, 0, 10)).to.equal(3)
			expect(WheelMath.slot(0, 100, 10)).to.equal(5)
			expect(WheelMath.slot(-100, 0, 10)).to.equal(7)
			expect(WheelMath.slot(-100, -100, 10)).to.equal(8)
			-- the edges between slots: just either side of 22.5 degrees
			local function at(degrees: number): number?
				local r = math.rad(degrees)
				return WheelMath.slot(math.sin(r) * 100, -math.cos(r) * 100, 10)
			end
			expect(at(22)).to.equal(1)
			expect(at(23)).to.equal(2)
			expect(at(337)).to.equal(8)
			expect(at(338)).to.equal(1)
			for index = 1, 8 do
				expect(at((index - 1) * 45)).to.equal(index)
			end
		end)

		it("picks nothing inside the dead zone", function()
			expect(WheelMath.slot(0, 0, 10)).to.equal(nil)
			expect(WheelMath.slot(5, -5, 10)).to.equal(nil)
			expect(WheelMath.slot(0, -10, 10)).to.equal(1)
		end)

		it("places each slot round the middle where it is picked", function()
			-- (Vector2 holds single-precision numbers)
			for index = 1, 8 do
				local place = WheelMath.place(index)
				expect(place.Magnitude).to.be.near(1, 1e-5)
				expect(WheelMath.slot(place.X, place.Y, 0.5)).to.equal(index)
			end
			expect(WheelMath.place(1).Y).to.be.near(-1, 1e-5)
		end)

		it("keeps the last four played, newest first, without repeats", function()
			local list = {}
			for _, clip in ipairs({ "wave", "dance", "bow", "wave", "cheer", "laugh" }) do
				list = WheelMath.remember(list, clip)
			end
			expect(table.concat(list, ",")).to.equal("laugh,cheer,wave,bow")
			expect(#WheelMath.remember({ "a", "b", "c", "d" }, "e")).to.equal(4)
			expect(table.concat(WheelMath.remember({ "a", "b" }, "b"), ",")).to.equal("b,a")
		end)
	end)
end
