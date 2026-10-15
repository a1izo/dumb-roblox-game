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

	describe("Weather.Probe.cell", function()
		-- Another made-up world: a street at 6000 (top 0.5), a roof over x 5985..5995 (underside 13.5, top 14.5)
		-- and a solid step at the far end (x 6018.5..6024.5, z 5970..5980, top 3.5). Looked at from 40 up, as a
		-- camera over the roofs would.
		local folder: Folder
		local function build()
			folder = Instance.new("Folder")
			folder.Name = "SpecWeatherCell"
			folder.Parent = workspace
			slab(folder, Vector3.new(6000, 0, 6000), Vector3.new(60, 1, 60))
			slab(folder, Vector3.new(5990, 14, 6000), Vector3.new(10, 1, 60))
			slab(folder, Vector3.new(6021.5, 2, 5975), Vector3.new(6, 3, 10))
		end
		local params = RaycastParams.new()

		it("sends from the whole of an open cell far from any room", function()
			build()
			local landing, share, rect, ceiling, all =
				Probe.cell(6010, 6000, 9, 40, params, CoverIndex.new(), {}, 9, 15, true)
			expect(landing :: number).to.be.near(0.5, 1e-3)
			expect(share).to.be.near(1)
			expect(rect).to.be.ok()
			local r = rect :: { number }
			expect(r[1]).to.be.near(6005.5)
			expect(r[3]).to.be.near(6014.5)
			expect(ceiling).to.equal(nil)
			expect(all).to.equal(true)
			folder:Destroy()
		end)

		it("keeps clear of a room by the margin, but only where its fall passes the room's height", function()
			build()
			local index = CoverIndex.new()
			local room = { cf = CFrame.new(6014, 6.5, 6020), half = Vector3.new(4, 6, 4) }
			-- Patches at x 5997, 6000 and 6003: the last is within 9 of the room (x 6010..6018).
			local _, share, rect, _, all = Probe.cell(6000, 6020, 9, 40, params, index, { room }, 9, 15, true)
			expect(share).to.be.near(2 / 3)
			expect((rect :: { number })[3]).to.be.near(6001.5)
			expect(all).to.equal(false)
			-- The same room up high: snow falling 15 studs to the street never reaches it.
			local high = { cf = CFrame.new(6014, 60, 6020), half = Vector3.new(4, 6, 4) }
			local _, whole, wide = Probe.cell(6000, 6020, 9, 40, params, index, { high }, 9, 15, true)
			expect(whole).to.be.near(1)
			expect((wide :: { number })[3]).to.be.near(6004.5)
			folder:Destroy()
		end)

		it("follows a slanted fall up its slant to the rooms upwind", function()
			build()
			local index = CoverIndex.new()
			-- A room upwind (x 6016..6024): straight down, all three patches (x 5997, 6000, 6003) are clear of it;
			-- leaning a stud upwind a stud higher, the drops over 6000 and 6003 would come through it.
			local room = { cf = CFrame.new(6020, 6.5, 6020), half = Vector3.new(4, 6, 4) }
			local _, straight = Probe.cell(6000, 6020, 9, 40, params, index, { room }, 5, 34, false)
			expect(straight).to.be.near(1)
			local _, share, rect =
				Probe.cell(6000, 6020, 9, 40, params, index, { room }, 5, 34, false, Vector3.new(1, 0, 0))
			expect(share).to.be.near(1 / 3)
			expect((rect :: { number })[3]).to.be.near(5998.5)
			folder:Destroy()
		end)

		it("never starts the weather under a roof whose top it sees from above", function()
			build()
			local index = CoverIndex.new()
			-- Patches at x 5993 (the roof's top), 5996 and 5999 (the street beside it).
			local landing, _, rect, ceiling = Probe.cell(5996, 6000, 9, 40, params, index, {}, 5, 34, false)
			expect(landing :: number).to.be.near(0.5, 1e-3)
			expect((rect :: { number })[1]).to.be.near(5994.5)
			expect(ceiling :: number).to.be.near(13.5, 1e-3)
			-- The snow closes the roof's patch for the air under it, whatever the height.
			local _, _, snowRect = Probe.cell(5996, 6000, 9, 40, params, index, {}, 9, 40, true)
			expect((snowRect :: { number })[1]).to.be.near(5994.5)
			folder:Destroy()
		end)

		it("lets the snow fall over a solid step", function()
			build()
			-- Patches at x 6017 (the street) and 6020, 6023 (the step, solid down to the street).
			local landing, share = Probe.cell(6020, 5975, 9, 40, params, CoverIndex.new(), {}, 9, 15, true)
			expect(landing :: number).to.be.near(0.5, 1e-3)
			expect(share).to.be.near(1)
			folder:Destroy()
		end)
	end)
end
