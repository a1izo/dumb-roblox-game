-- The venues only the server builds from (ModelLibrary.SERVER_ONLY) go to ServerStorage's own store at install, off
-- every player's device, while the props and the client's own scenes stay in ReplicatedStorage; the server still
-- finds both. A made-up venue and set stand in, so the real imports of a place are never touched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ModelLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local function import(name: string, marker: string, mesh: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, part in ipairs({ marker, mesh }) do
		local piece = Instance.new("MeshPart")
		piece.Name = part
		piece.Anchored = true
		piece.Size = Vector3.new(1, 1, 1)
		piece.Position = Vector3.new(0, -5000, 0)
		piece.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ModelLibrary stores", function()
		it(
			"keeps a server-only venue in ServerStorage and a shared set in ReplicatedStorage, and finds both",
			function()
				ModelLibrary.SERVER_ONLY.MapsSpecVenue = true
				local venue =
					import("DeathsGambitMaps_SpecVenue", "DeathsGambitMapsSpecVenue_Version_3", "Map_SpecVenueFloor")
				local set = import("DeathsGambitModels_SpecSet", "DeathsGambitModelsSpecSet_Version_2", "SpecSetThing")
				local ok, err = pcall(function()
					ModelLibrary.install()
					local own = ServerStorage:FindFirstChild("DeathsGambitServerAssets")
					local shared = ReplicatedStorage:FindFirstChild("DeathsGambitAssets")
					expect(own ~= nil and venue.Parent == own).to.equal(true)
					expect(shared ~= nil and set.Parent == shared).to.equal(true)
					expect(ModelLibrary.version("MapsSpecVenue")).to.equal(3)
					expect(ModelLibrary.version("ModelsSpecSet")).to.equal(2)
					expect(ModelLibrary.source("Map_SpecVenueFloor") ~= nil).to.equal(true)
					expect(ModelLibrary.source("SpecSetThing") ~= nil).to.equal(true)
				end)
				ModelLibrary.SERVER_ONLY.MapsSpecVenue = nil
				venue:Destroy()
				set:Destroy()
				ModelLibrary.install()
				assert(ok, err)
			end
		)
	end)
end
