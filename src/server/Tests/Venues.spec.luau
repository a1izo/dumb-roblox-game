-- Where Specters may fly: every map's box follows its outer walls and ceiling, and the camera
-- clamp finds the nearest point inside a box.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Venues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Venues"))

local function inside(position: Vector3, min: Vector3, max: Vector3): boolean
	return Venues.clampInto(position, min, max) == position
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Venues.specterBounds", function()
		it("keeps Specters inside Agency HQ's walls and under its ceiling", function()
			local min, max = Venues.specterBounds("map", "TaskForceHQ")
			expect(inside(Venues.MAP + Vector3.new(79, 5, 59), min, max)).to.equal(true)
			expect(inside(Venues.MAP + Vector3.new(81, 5, 0), min, max)).to.equal(false)
			expect(inside(Venues.MAP + Vector3.new(0, 5, -61), min, max)).to.equal(false)
			expect(inside(Venues.MAP + Vector3.new(0, 15, 0), min, max)).to.equal(false)
		end)
		it("lets Specters reach the rooftops on the outdoor maps, but not past the edge", function()
			-- Tokyo's box comes from its Blender scene (MapBounds): the metro under it included.
			local min, max = Venues.specterBounds("map", "TokyoDistrict")
			expect(inside(Venues.MAP + Vector3.new(490, 70, 390), min, max)).to.equal(true)
			expect(inside(Venues.MAP + Vector3.new(-200, -24, -300), min, max)).to.equal(true)
			expect(inside(Venues.MAP + Vector3.new(0, 81, 0), min, max)).to.equal(false)
			expect(inside(Venues.MAP + Vector3.new(502, 5, 0), min, max)).to.equal(false)
			local campusMin, campusMax = Venues.specterBounds("map", "UniversityCampus")
			expect(inside(Venues.MAP + Vector3.new(0, 29, -70), campusMin, campusMax)).to.equal(true)
			expect(inside(Venues.MAP + Vector3.new(0, 5, 91), campusMin, campusMax)).to.equal(false)
		end)
		it("uses the meeting room itself for the meeting", function()
			local min, max = Venues.specterBounds("meeting")
			expect(inside(Venues.MEETING + Vector3.new(29, 17, -29), min, max)).to.equal(true)
			expect(inside(Venues.MEETING + Vector3.new(31, 5, 0), min, max)).to.equal(false)
		end)
		it("still gives an unknown map a box around the map's origin", function()
			local min, max = Venues.specterBounds("map", "SomeNewMap")
			expect(inside(Venues.MAP + Vector3.new(0, 5, 0), min, max)).to.equal(true)
		end)
	end)

	describe("Venues.at", function()
		it("tells the three places apart, over the whole of a big map", function()
			expect(Venues.at(Venues.LOBBY)).to.equal("lobby")
			expect(Venues.at(Venues.LOBBY + Vector3.new(900, 40, 900))).to.equal("lobby")
			expect(Venues.at(Venues.MEETING + Vector3.new(20, 5, -20))).to.equal("meeting")
			expect(Venues.at(Venues.MAP + Vector3.new(-500, -24, -400))).to.equal("map")
			expect(Venues.at(Venues.MAP + Vector3.new(500, 60, 400))).to.equal("map")
		end)
	end)

	describe("Venues.clampInto", function()
		it("moves a point outside onto the nearest face, minus the inset", function()
			local min, max = Vector3.new(0, 0, 0), Vector3.new(10, 10, 10)
			local clamped = Venues.clampInto(Vector3.new(15, 5, -3), min, max, 1)
			expect(clamped.X).to.be.near(9)
			expect(clamped.Y).to.be.near(5)
			expect(clamped.Z).to.be.near(1)
		end)
		it("leaves a point inside where it is", function()
			local min, max = Vector3.new(0, 0, 0), Vector3.new(10, 10, 10)
			expect(Venues.clampInto(Vector3.new(4, 4, 4), min, max)).to.equal(Vector3.new(4, 4, 4))
		end)
	end)
end
