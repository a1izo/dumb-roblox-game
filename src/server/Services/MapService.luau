-- Builds the lobby once, and one match map plus the meeting room for every match.
-- All built models use persistent streaming so clients always have them.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))

local Maps = script.Parent.Parent:WaitForChild("Maps")
local Builder = require(Maps:WaitForChild("Builder"))
local Lobby = require(Maps:WaitForChild("Lobby"))
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

local LOBBY_ORIGIN = Vector3.new(0, 0.2, 0)
local MAP_ORIGIN = Vector3.new(0, 0, 1000)
local MEETING_ORIGIN = Vector3.new(700, 0, 0)

local LOBBY_LIGHTING = {
	clockTime = 18.5,
	brightness = 1.5,
	ambient = Color3.fromRGB(100, 100, 110),
	outdoorAmbient = Color3.fromRGB(100, 100, 110),
	fogEnd = 100000,
	fogColor = Color3.fromRGB(30, 30, 35),
}

local lobbyInfo = nil
local currentModel: Model? = nil
local rotationIndex = 0

local function applyLighting(settings)
	Lighting.ClockTime = settings.clockTime
	Lighting.Brightness = settings.brightness
	Lighting.Ambient = settings.ambient
	Lighting.OutdoorAmbient = settings.outdoorAmbient
	Lighting.FogEnd = settings.fogEnd
	Lighting.FogColor = settings.fogColor
end

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
	applyLighting(def.lighting)
	return info
end

function MapService.destroy()
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
	end
	applyLighting(LOBBY_LIGHTING)
end

function MapService.init()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	if not Lighting:FindFirstChild("LGameColor") then
		Create("ColorCorrectionEffect", {
			Name = "LGameColor",
			Contrast = 0.08,
			Saturation = -0.1,
			TintColor = Color3.fromRGB(255, 248, 240),
			Parent = Lighting,
		})
	end
	if not Lighting:FindFirstChild("LGameBloom") then
		Create("BloomEffect", {
			Name = "LGameBloom",
			Intensity = 0.5,
			Size = 24,
			Threshold = 1.5,
			Parent = Lighting,
		})
	end
	applyLighting(LOBBY_LIGHTING)

	local model = newModel("LGameLobby")
	lobbyInfo = Lobby.build(Builder.new(model, LOBBY_ORIGIN))
	model.Parent = workspace
	updateNextMapLabel()
end

return MapService
