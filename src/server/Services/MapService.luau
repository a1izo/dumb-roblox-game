-- Builds the lobby once, and one match map plus the meeting room for every match.
-- All built models use persistent streaming so clients always have them. Lighting is set
-- per venue on each client (LightingController); the server only sets the defaults.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Venues = require(Shared:WaitForChild("Venues"))

local Maps = script.Parent.Parent:WaitForChild("Maps")
local Builder = require(Maps:WaitForChild("Builder"))
local Lobby = require(Maps:WaitForChild("Lobby"))
local MapContract = require(Maps:WaitForChild("MapContract"))
local MeetingRoom = require(Maps:WaitForChild("MeetingRoom"))
local TaskForceHQ = require(Maps:WaitForChild("TaskForceHQ"))
local UniversityCampus = require(Maps:WaitForChild("UniversityCampus"))
local TokyoDistrict = require(Maps:WaitForChild("TokyoDistrict"))

local MapService = {}

local MAPS = {
	TaskForceHQ = TaskForceHQ,
	UniversityCampus = UniversityCampus,
	TokyoDistrict = TokyoDistrict,
}

local LOBBY_ORIGIN = Venues.LOBBY
local MAP_ORIGIN = Venues.MAP
local MEETING_ORIGIN = Venues.MEETING

local lobbyInfo = nil
local currentModel: Model? = nil
local rotationIndex = 0

local function newModel(name: string): Model
	return Create("Model", {
		Name = name,
		ModelStreamingMode = Enum.ModelStreamingMode.Persistent,
	})
end

function MapService.nextMapId(): string
	local rotation = Config.MAP_ROTATION
	local id = rotation[(rotationIndex % #rotation) + 1]
	if MAPS[id] == nil then
		warn("[Inkbound] Unknown map in Config.MAP_ROTATION: " .. tostring(id))
		return "TaskForceHQ"
	end
	return id
end

function MapService.nextMapName(): string
	return MAPS[MapService.nextMapId()].name
end

local function updateNextMapLabel()
	if lobbyInfo then
		lobbyInfo.nextMapLabel.Text = "NEXT CASE\n" .. MapService.nextMapName()
	end
end

function MapService.advance()
	rotationIndex += 1
	updateNextMapLabel()
end

-- Builds a match map and the meeting room. Returns everything gameplay needs,
-- converted to world space.
function MapService.build(mapId: string)
	MapService.destroy()
	local def = MAPS[mapId] or MAPS.TaskForceHQ
	local model = newModel("LGameMap")
	local b = Builder.new(model, MAP_ORIGIN)
	local layout = def.build(b)

	local info = {
		id = mapId,
		name = def.name,
		model = model,
		stations = {},
		spawns = {},
		sheets = {},
		dropPoints = {},
		hoods = {},
		areas = {},
		boardLabels = {},
	}
	for i, stationDef in ipairs(layout.stations) do
		table.insert(info.stations, b:station(stationDef, "S" .. i))
	end
	info.tipBox = b:tipBox(layout.tipBox)
	table.insert(info.boardLabels, b:board(layout.board))
	for _, spot in ipairs(layout.spawns) do
		-- Face the middle of the map unless a rotation is given.
		local rot = spot.rot or math.deg(math.atan2(spot.x, spot.z))
		table.insert(info.spawns, b:world(b:cf(spot.x, 0, spot.z, rot)))
	end
	for i, sheet in ipairs(layout.sheets) do
		table.insert(info.sheets, { id = "P" .. i, position = b:worldPos(sheet.x, sheet.y, sheet.z) })
	end
	for i, drop in ipairs(layout.dropPoints) do
		table.insert(info.dropPoints, b:dropPoint(drop, "D" .. i))
	end
	for _, hood in ipairs(layout.hoods) do
		table.insert(info.hoods, b:worldPos(hood.x, hood.y, hood.z))
	end
	for _, area in ipairs(layout.areas) do
		table.insert(info.areas, { name = area.name, position = b:worldPos(area.x, 0, area.z) })
	end

	local meeting = MeetingRoom.build(Builder.new(model, MEETING_ORIGIN))
	info.meeting = meeting
	table.insert(info.boardLabels, meeting.boardLabel)

	model.Parent = workspace
	currentModel = model
	if RunService:IsStudio() then
		for _, problem in ipairs(MapContract.validateBuilt(info)) do
			warn("[Inkbound] Map " .. mapId .. ": " .. problem)
		end
	end
	return info
end

function MapService.destroy()
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
	end
end

function MapService.init()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ClockTime = 0.5
	for _, name in ipairs({ "LGameColor", "LGameBloom" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local model = newModel("LGameLobby")
	lobbyInfo = Lobby.build(Builder.new(model, LOBBY_ORIGIN))
	model.Parent = workspace
	updateNextMapLabel()
end

return MapService
