-- Every venue is a Blender scene with an FBX of its own: the lobby and the meeting room carry the
-- anchors their Luau builds at, and nothing points at the two retired imports (InkboundMaps.fbx,
-- InkboundModels.fbx): every scene names its own file and every prop belongs to a named set.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))

local Maps = script.Parent.Parent:WaitForChild("Maps")
local SceneBuilder = require(Maps:WaitForChild("SceneBuilder"))

local VENUES = { "Lobby", "Meeting", "Agency", "Campus", "Tokyo" }
local SETS = { Core = true, Tokyo = true, Agency = true, Campus = true, Lobby = true, Meeting = true }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Scenes", function()
		for _, venue in ipairs(VENUES) do
			it(venue .. " is a scene with an FBX of its own", function()
				local data = SceneBuilder.data(venue)
				expect(data ~= nil).to.equal(true)
				expect(data.fbx).to.equal("InkboundMaps_" .. venue .. ".fbx")
				expect(data.meshPrefix).to.equal("Map_" .. venue .. "_")
				expect(data.calibration).to.equal("Calib_" .. venue)
			end)
		end

		it("gives the lobby every anchor it builds at", function()
			local anchors = SceneBuilder.data("Lobby").layout.anchors
			local missing = {}
			local names = { "spawn", "title", "tagline", "howto", "nextCase", "wins", "xp", "weekly", "quests" }
			for _, name in ipairs({ "academyTitle", "academyLine", "academyGate", "dummy1", "dummy2", "dummy3" }) do
				table.insert(names, name)
			end
			-- An altar for each case-file drill, the Grimoire, the warrant and the eyes.
			for index = 1, #TaskTypes.LIST + 3 do
				table.insert(names, "drill" .. index)
			end
			-- The mini-games: the Spire Ascent's pad, centre and ten checkpoints, the rune courtyard's pad,
			-- centre and nine tiles, the dice rock and its four seats, the stone-toss and the rift's shape,
			-- and the two boards.
			for _, name in ipairs({
				"pkStart",
				"pkCenter",
				"runeStart",
				"runeCenter",
				"diceRock",
				"toss",
				"rift",
				"parkourBoard",
				"runesBoard",
			}) do
				table.insert(names, name)
			end
			for index = 1, 10 do
				table.insert(names, "pk" .. index)
			end
			for index = 1, 9 do
				table.insert(names, "rune" .. index)
			end
			for index = 1, 4 do
				table.insert(names, "diceSeat" .. index)
			end
			for _, name in ipairs(names) do
				if not anchors[name] then
					table.insert(missing, name)
				end
			end
			expect(table.concat(missing, ", ")).to.equal("")
		end)

		it("puts the spawn on the terrace, above the plaza", function()
			local anchors = SceneBuilder.data("Lobby").layout.anchors
			expect(anchors.spawn.y > 5).to.equal(true)
			expect(anchors.spawn.rot).to.equal(0)
		end)

		it("gives the meeting room its screen, board, a place for everyone and the Specters' spots", function()
			local anchors = SceneBuilder.data("Meeting").layout.anchors
			expect(anchors.screen ~= nil).to.equal(true)
			expect(anchors.board ~= nil).to.equal(true)
			local seats = 0
			while anchors["seat" .. (seats + 1)] do
				seats += 1
				local seat = anchors["seat" .. seats]
				-- Inside the room (60 x 60), clear of the table (26 across).
				local reach = Vector3.new(seat.x, 0, seat.z).Magnitude
				expect(reach > 15 and math.abs(seat.x) < 29 and math.abs(seat.z) < 29).to.equal(true)
			end
			expect(seats >= Config.MAX_PLAYERS).to.equal(true)
			expect(anchors.gallery8 ~= nil).to.equal(true)
		end)
	end)

	describe("ModelCatalog", function()
		it("puts every prop in a named set (none left in the retired InkboundModels.fbx)", function()
			local stray = {}
			for key, info in pairs(ModelCatalog :: any) do
				if not SETS[info.set or ""] then
					table.insert(stray, key)
				end
			end
			table.sort(stray)
			expect(table.concat(stray, ", ")).to.equal("")
		end)
	end)
end
