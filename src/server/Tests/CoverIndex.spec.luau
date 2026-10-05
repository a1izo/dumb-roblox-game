-- The boxes that shelter from rain and snow: what stands over a spot, with turned boxes, thin
-- cover (a tree's crown), and boxes low enough to be under it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoverIndex = require(Shared:WaitForChild("Weather"):WaitForChild("CoverIndex"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("CoverIndex", function()
		it("stops what falls on a spot under a box", function()
			local index = CoverIndex.new()
			index:add(CFrame.new(10, 12, 20), Vector3.new(8, 1, 6), 1)
			expect(index:above(Vector3.new(10, 1, 20))).to.equal(1)
			expect(index:above(Vector3.new(13.9, 1, 22.9))).to.equal(1)
			expect(index:above(Vector3.new(14.1, 1, 20))).to.equal(0)
			expect(index:above(Vector3.new(10, 1, 23.1))).to.equal(0)
		end)

		it("ignores a box below the spot, or too low to be over a head", function()
			local index = CoverIndex.new()
			index:add(CFrame.new(0, 2, 0), Vector3.new(10, 1, 10), 1) -- its underside at 1.5
			index:add(CFrame.new(40, 6, 0), Vector3.new(10, 1, 10), 1)
			expect(index:above(Vector3.new(0, 1, 0))).to.equal(0) -- 1.5 is not 1.5 over a spot at 1
			expect(index:above(Vector3.new(40, 9, 0))).to.equal(0) -- the box is under the spot
			expect(index:above(Vector3.new(40, 1, 0))).to.equal(1)
		end)

		it("follows a box turned about the vertical", function()
			local index = CoverIndex.new()
			-- 20 long, 4 across, turned 90 degrees: it now runs along z.
			index:add(CFrame.new(5, 10, 5) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(20, 1, 4), 1)
			expect(index:above(Vector3.new(5, 1, 14))).to.equal(1)
			expect(index:above(Vector3.new(5, 1, -4))).to.equal(1)
			expect(index:above(Vector3.new(13, 1, 5))).to.equal(0)
		end)

		it("takes the most of the boxes over a spot, and keeps thin cover thin", function()
			local index = CoverIndex.new()
			index:add(CFrame.new(0, 10, 0), Vector3.new(10, 6, 10), 0.5) -- a tree's crown
			expect(index:above(Vector3.new(0, 1, 0))).to.equal(0.5)
			index:add(CFrame.new(2, 12, 2), Vector3.new(4, 1, 4), 1) -- an awning under it
			expect(index:above(Vector3.new(2, 1, 2))).to.equal(1)
			expect(index:above(Vector3.new(-4, 1, -4))).to.equal(0.5)
		end)

		it("finds boxes across bucket edges and forgets removed ones", function()
			local index = CoverIndex.new()
			local box = index:add(CFrame.new(16, 10, 16), Vector3.new(30, 1, 30), 1) -- spans several buckets
			expect(index:above(Vector3.new(2, 1, 2))).to.equal(1)
			expect(index:above(Vector3.new(30, 1, 30))).to.equal(1)
			index:remove(box)
			expect(index:above(Vector3.new(2, 1, 2))).to.equal(0)
			expect(index:above(Vector3.new(30, 1, 30))).to.equal(0)
			expect(index.count).to.equal(0)
		end)
	end)
end
