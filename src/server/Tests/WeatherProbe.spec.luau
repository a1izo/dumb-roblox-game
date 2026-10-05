-- Where a drop must start to land on a given spot (Weather/Probe), and what a patch of ground
-- reports on a small made-up world: the lowest ground under it (so rain over a river's edge
-- reaches the water), and how much of it is covered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather")
local CoverIndex = require(Weather:WaitForChild("CoverIndex"))
local Probe = require(Weather:WaitForChild("Probe"))

local function slab(folder: Instance, centre: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanQuery = true
	part.Size = size
	part.CFrame = CFrame.new(centre)
	part.Parent = folder
	return part
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Weather.Probe.dropStart", function()
		it("starts a straight drop right over where it lands", function()
			local start, length = Probe.dropStart(10, 20, -6, 30, Vector3.new(0, -1, 0))
			expect(start.X).to.be.near(10)
			expect(start.Y).to.be.near(24)
			expect(start.Z).to.be.near(20)
			expect(length).to.be.near(30)
		end)

		it("starts a slanted drop upwind, so it still lands on the spot", function()
			local fall = Vector3.new(0.3, -1, -0.2).Unit
			local start, length = Probe.dropStart(0, 0, 0, 34, fall)
			expect(start.Y).to.be.near(34)
			local landing = start + fall * length
			expect(landing.X).to.be.near(0, 1e-6)
			expect(landing.Y).to.be.near(0, 1e-6)
			expect(landing.Z).to.be.near(0, 1e-6)
			expect(length > 34).to.equal(true)
		end)
	end)

	describe("Weather.Probe.patch", function()
		-- A made-up world far from anything real: a street at 5000, a lower slab (the river) next to
		-- it, and a roof over part of the street.
		local folder: Folder
		local function build()
			folder = Instance.new("Folder")
			folder.Name = "SpecWeather"
			folder.Parent = workspace
			slab(folder, Vector3.new(5000, 0, 5000), Vector3.new(40, 1, 40)) -- the street, top at 0.5
			slab(folder, Vector3.new(5000 + 40, -6, 5000), Vector3.new(40, 1, 40)) -- lower ground, top at -5.5
			slab(folder, Vector3.new(5000 - 10, 14, 5000), Vector3.new(10, 1, 40)) -- a roof over x -15..-5
		end
		local params = RaycastParams.new()

		it("finds the ground under an open patch", function()
			build()
			local index = CoverIndex.new()
			local landing, cover = Probe.patch(5000 + 10, 5000, 9, 5, params, index)
			expect(landing).to.be.ok()
			expect(landing :: number).to.be.near(0.5, 1e-3)
			expect(cover).to.be.near(0)
			folder:Destroy()
		end)

		it("takes the lowest ground when a patch straddles an edge", function()
			build()
			local index = CoverIndex.new()
			-- Centred on the street's edge (x 5000 + 20): half the patch is over the lower ground.
			local landing = Probe.patch(5000 + 20, 5000, 9, 5, params, index)
			expect(landing :: number).to.be.near(-5.5, 1e-3)
			folder:Destroy()
		end)

		it("reports a roof overhead, and half of it at the roof's edge", function()
			build()
			local index = CoverIndex.new()
			local _, under = Probe.patch(5000 - 10, 5000, 9, 5, params, index)
			expect(under).to.be.near(1)
			-- The roof ends at x = 5000 - 5: a patch centred there has about half its spots under it.
			local _, edge = Probe.patch(5000 - 5, 5000, 9, 5, params, index)
			expect(edge > 0.2 and edge < 0.8).to.equal(true)
			folder:Destroy()
		end)

		it("counts a cover box as shelter, and nothing where there is no ground", function()
			build()
			local index = CoverIndex.new()
			index:add(CFrame.new(5000 + 10, 9, 5000), Vector3.new(20, 1, 20), 0.5)
			local _, thin = Probe.patch(5000 + 10, 5000, 9, 5, params, index)
			expect(thin).to.be.near(0.5)
			local landing, cover = Probe.patch(9000, 9000, 9, 5, params, index)
			expect(landing).to.equal(nil)
			expect(cover).to.equal(1)
			folder:Destroy()
		end)
	end)
end
