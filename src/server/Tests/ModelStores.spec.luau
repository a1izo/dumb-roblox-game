-- The venues only the server builds from (ModelLibrary.SERVER_ONLY) are moved to the server's own store at install,
-- off every player's device; the props and the client's own scenes stay shared. Run on folders of its own: it must
-- never call install(), which gathers imports from the whole place (on 2026-11-11 a version of this spec that did took
-- the freshly built lobby out of Workspace in a play test).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local function import(parent: Instance, name: string, marker: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	local piece = Instance.new("MeshPart")
	piece.Name = marker
	piece.Parent = folder
	folder.Parent = parent
	return folder
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ModelLibrary stores", function()
		it("moves a server-only venue to the server's store and leaves a shared set where it is", function()
			local shared, own = Instance.new("Folder"), Instance.new("Folder")
			local venue = import(shared, "DeathsGambitMaps_Tokyo", "DeathsGambitMapsTokyo_Version_3")
			local scenes = import(shared, "DeathsGambitMaps_Scenes", "DeathsGambitMapsScenes_Version_7")
			local set = import(shared, "DeathsGambitModels_Core", "DeathsGambitModelsCore_Version_2")
			local moved = ModelLibrary.keepServerOnly(shared, own)
			expect(moved).to.equal(1)
			expect(venue.Parent == own).to.equal(true)
			expect(scenes.Parent == shared and set.Parent == shared).to.equal(true)
			for _, kind in ipairs({ "MapsLobby", "MapsMeeting", "MapsAgency", "MapsCampus", "MapsTokyo" }) do
				expect(ModelLibrary.SERVER_ONLY[kind]).to.equal(true)
			end
			expect(ModelLibrary.SERVER_ONLY.MapsScenes).to.equal(nil)
			shared:Destroy()
			own:Destroy()
		end)
	end)
end
