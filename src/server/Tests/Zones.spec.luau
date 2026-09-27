-- The kinds of ground a Blender-made map exports: looked up by position and height, and the
-- ones nothing of the game's may stand on.

local Maps = script.Parent.Parent:WaitForChild("Maps")
local Zones = require(Maps:WaitForChild("Zones"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local origin = Vector3.new(0, 0, 3000)
	local zones = Zones.new({
		{ kind = "road", y0 = 0, y1 = 0, points = { -10, -5, 10, -5, 10, 5, -10, 5 } },
		{ kind = "sidewalk", y0 = 0, y1 = 0, points = { -10, 5, 10, 5, 10, 9, -10, 9 } },
		{ kind = "interior", y0 = 12, y1 = 12, points = { -10, -5, 10, -5, 10, 5, -10, 5 } },
	}, origin)

	describe("Zones", function()
		it("finds the ground at a spot, by height", function()
			expect(table.concat(zones:kindsAt(origin + Vector3.new(0, 0, 0)), ",")).to.equal("road")
			expect(table.concat(zones:kindsAt(origin + Vector3.new(0, 12, 0)), ",")).to.equal("interior")
			expect(table.concat(zones:kindsAt(origin + Vector3.new(0, 0, 7)), ",")).to.equal("sidewalk")
			expect(#zones:kindsAt(origin + Vector3.new(50, 0, 0))).to.equal(0)
		end)
		it("keeps things off roads but not off sidewalks or unknown ground", function()
			expect(zones:forbidden(origin + Vector3.new(3, 0.5, 0))).to.equal(true)
			expect(zones:forbidden(origin + Vector3.new(3, 12, 0))).to.equal(false)
			expect(zones:forbidden(origin + Vector3.new(3, 0, 7))).to.equal(false)
			expect(zones:forbidden(origin + Vector3.new(80, 0, 0))).to.equal(false)
		end)
	end)
end
