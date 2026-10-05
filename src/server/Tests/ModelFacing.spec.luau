-- Studio's importer turns every prop's mesh data half way round the vertical axis, so
-- ModelLibrary.get turns each prop back (FACING_TURN): what the importer hands over with its
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
	local store = ReplicatedStorage:FindFirstChild("InkboundAssets")
	local created = false
	if not store then
		store = Instance.new("Folder")
		store.Name = "InkboundAssets"
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

local function markerSide(key: string): number
	local model = ModelLibrary.get(key)
	assert(model, "the fake prop should build")
	local marker = model:FindFirstChild("Marker", true) :: BasePart
	local slab = model:FindFirstChild("Slab", true) :: BasePart
	local side = marker.Position.Z - slab.Position.Z
	model:Destroy()
	return side
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ModelLibrary facing", function()
		local catalog = ModelCatalog :: any
		local folders = {}

		local function cleanup()
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
	end)
end
