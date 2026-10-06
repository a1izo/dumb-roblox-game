-- Studio's importer turns every prop's mesh data half way round the vertical axis, so
-- ModelLibrary.get turns each prop back when the half turn is on: what the importer hands over with its
-- marker on +Z must come out with the marker on -Z, the way props are made and placed, with and
-- without the calibration cubes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local function meshPart(name: string, size: Vector3, position: Vector3): MeshPart
	local part = Instance.new("MeshPart")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	return part
end

-- A fake import: a slab with a marker on its +Z side, under the store the game reads.
local function fakeImport(key: string, set: string, withCubes: boolean): Instance
	ModelLibrary.setFacingTurned(true) -- these tests are about what the half turn does when it is on
	local store = ReplicatedStorage:FindFirstChild("DeathsGambitAssets")
	local created = false
	if not store then
		store = Instance.new("Folder")
		store.Name = "DeathsGambitAssets"
		store.Parent = ReplicatedStorage
		created = true
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpecImport" .. key
	folder:SetAttribute("SpecStoreCreated", created)
	local model = Instance.new("Model")
	model.Name = key
	meshPart("Slab", Vector3.new(4, 4, 1), Vector3.new(0, 2000, 0)).Parent = model
	meshPart("Marker", Vector3.new(1, 1, 1), Vector3.new(0, 2000, 2)).Parent = model
	model.Parent = folder
	if withCubes then
		local prefix = "Calib_Props" .. set
		meshPart(prefix .. "_O", Vector3.new(1, 1, 1), Vector3.new(0, 0, 0)).Parent = folder
		meshPart(prefix .. "_X", Vector3.new(1, 1, 1), Vector3.new(64, 0, 0)).Parent = folder
		meshPart(prefix .. "_Y", Vector3.new(1, 1, 1), Vector3.new(0, 64, 0)).Parent = folder
	end
	folder.Parent = store
	return folder
end

-- Which way the marker lies from the slab once the prop is placed the way the maps place it:
-- standing at the origin, turned `rot` degrees about the vertical axis (rot 0 faces -Z, 90 faces -X).
local function markerDirection(key: string, rot: number): Vector3
	local model = ModelLibrary.get(key)
	assert(model, "the fake prop should build")
	model:PivotTo(CFrame.new(300, 0, 300) * CFrame.Angles(0, math.rad(rot), 0))
	local marker = model:FindFirstChild("Marker", true) :: BasePart
	local slab = model:FindFirstChild("Slab", true) :: BasePart
	local direction = marker.Position - slab.Position
	model:Destroy()
	return Vector3.new(direction.X, 0, direction.Z).Unit
end

local function markerSide(key: string): number
	return markerDirection(key, 0).Z
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ModelLibrary facing", function()
		local catalog = ModelCatalog :: any
		local folders = {}
		local wasTurned = ModelLibrary.facingTurned()

		local function cleanup()
			ModelLibrary.setFacingTurned(wasTurned)
			for key in pairs({ SpecFacingBare = true, SpecFacingCubes = true }) do
				catalog[key] = nil
			end
			for _, folder in ipairs(folders) do
				if folder:GetAttribute("SpecStoreCreated") and folder.Parent then
					folder.Parent:Destroy()
				else
					folder:Destroy()
				end
			end
			folders = {}
		end

		it("turns a prop imported without calibration cubes so its marker faces -Z", function()
			catalog.SpecFacingBare = { size = { 4, 4, 3 }, pivot = "bottom", material = "Plastic", collide = false }
			table.insert(folders, fakeImport("SpecFacingBare", "", false))
			local ok, side = pcall(markerSide, "SpecFacingBare")
			cleanup()
			assert(ok, side)
			expect(side < -0.5).to.equal(true)
		end)

		it("turns a prop imported with an untouched cube set so its marker faces -Z", function()
			catalog.SpecFacingCubes = {
				size = { 4, 4, 3 },
				pivot = "bottom",
				material = "Plastic",
				collide = false,
				set = "SpecFacing",
			}
			table.insert(folders, fakeImport("SpecFacingCubes", "SpecFacing", true))
			local ok, side = pcall(markerSide, "SpecFacingCubes")
			cleanup()
			assert(ok, side)
			expect(side < -0.5).to.equal(true)
		end)

		it("places a turned prop the way the maps place it: rot 90 faces -X, rot 180 faces +Z", function()
			catalog.SpecFacingBare = { size = { 4, 4, 3 }, pivot = "bottom", material = "Plastic", collide = false }
			table.insert(folders, fakeImport("SpecFacingBare", "", false))
			local ok, west, south = pcall(function()
				return markerDirection("SpecFacingBare", 90), markerDirection("SpecFacingBare", 180)
			end)
			cleanup()
			assert(ok, west)
			expect(west.X < -0.9).to.equal(true)
			expect(south.Z > 0.9).to.equal(true)
		end)

		it("keeps the pivot upright at the bottom of the prop, so PivotTo places it at its yaw on the floor", function()
			catalog.SpecFacingBare = { size = { 4, 4, 3 }, pivot = "bottom", material = "Plastic", collide = false }
			table.insert(folders, fakeImport("SpecFacingBare", "", false))
			local ok, yaw, floor = pcall(function()
				local model = ModelLibrary.get("SpecFacingBare")
				assert(model, "the fake prop should build")
				model:PivotTo(CFrame.new(300, 0, 300) * CFrame.Angles(0, math.rad(30), 0))
				local box, size = model:GetBoundingBox()
				local _, ry = model:GetPivot():ToOrientation()
				local lowest = math.min(
					(model:FindFirstChild("Slab", true) :: BasePart).Position.Y
						- (model:FindFirstChild("Slab", true) :: BasePart).Size.Y / 2,
					box.Position.Y - size.Y / 2
				)
				model:Destroy()
				return math.round(math.deg(ry)), lowest
			end)
			cleanup()
			assert(ok, yaw)
			expect(yaw).to.equal(30)
			expect(math.abs(floor) < 0.05).to.equal(true)
		end)

		it("reports the half turn, which the Prop gallery shows, and can switch it off", function()
			ModelLibrary.setFacingTurned(true)
			local on = ModelLibrary.facingTurned()
			ModelLibrary.setFacingTurned(false)
			local off = ModelLibrary.facingTurned()
			cleanup()
			expect(on).to.equal(true)
			expect(off).to.equal(false)
		end)
	end)
end
