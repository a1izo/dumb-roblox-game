-- Builds the lobby once, and one match map plus the meeting room for every match.
-- All built models use persistent streaming so clients always have them. Lighting is set
-- per venue on each client (LightingController); the server only sets the defaults.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local SpawnPicker = require(Shared:WaitForChild("SpawnPicker"))
local Venues = require(Shared:WaitForChild("Venues"))

local Maps = script.Parent.Parent:WaitForChild("Maps")
local Builder = require(Maps:WaitForChild("Builder"))
local Lobby = require(Maps:WaitForChild("Lobby"))
local MapContract = require(Maps:WaitForChild("MapContract"))
local SceneBuilder = require(Maps:WaitForChild("SceneBuilder"))
local Zones = require(Maps:WaitForChild("Zones"))

local LeaderboardService = require(script.Parent.LeaderboardService)
local LobbyGameService = require(script.Parent.LobbyGameService)
local ServerSettings = require(script.Parent.ServerSettings)
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
local lobbyModel: Model? = nil
local currentModel: Model? = nil
local rotationIndex = 0
-- The debug panel can pick the next map (it is used once).
local forcedNext: string? = nil

local loadToken = 0

local function newModel(name: string): Model
	return Create("Model", {
		Name = name,
		ModelStreamingMode = Enum.ModelStreamingMode.Persistent,
	})
end

function MapService.nextMapId(): string
	if forcedNext and MAPS[forcedNext] then
		return forcedNext
	end
	local rotation = {}
	for _, id in ipairs(Config.MAP_ROTATION) do
		if table.find(ServerSettings.maps(), id) then
			table.insert(rotation, id)
		end
	end
	if #rotation == 0 then
		rotation = Config.MAP_ROTATION
	end
	local id = rotation[(rotationIndex % #rotation) + 1]
	if MAPS[id] == nil then
		warn("[DeathsGambit] Unknown map in Config.MAP_ROTATION: " .. tostring(id))
		return "TaskForceHQ"
	end
	return id
end

function MapService.nextMapName(): string
	return MAPS[MapService.nextMapId()].name
end

-- (The next case's name is on every player's lobby page, from the lobby state; no sign in the world carries it.)
function MapService.advance()
	if forcedNext then
		forcedNext = nil
	else
		rotationIndex += 1
	end
end

-- Debug -----------------------------------------------------------------------------------

-- Every map id with its name, in rotation order.
function MapService.list(): { { id: string, name: string } }
	local list = {}
	for _, id in ipairs(Config.MAP_ROTATION) do
		if MAPS[id] then
			table.insert(list, { id = id, name = MAPS[id].name })
		end
	end
	return list
end

-- Makes the next match use this map (debug panel).
function MapService.forceNext(mapId: string): boolean
	if not MAPS[mapId] then
		return false
	end
	forcedNext = mapId
	return true
end

-- Where lobby players (and test bots) appear.
function MapService.lobbySpawn(): CFrame
	return if lobbyInfo then lobbyInfo.spawnCFrame else CFrame.new(LOBBY_ORIGIN + Vector3.new(0, 3, 14))
end

-- Rebuilds the lobby (after switching between the Blender scene and its greybox).
function MapService.rebuildLobby()
	if lobbyModel then
		lobbyModel:Destroy()
	end
	local model = newModel("LGameLobby")
	lobbyInfo = Lobby.build(Builder.new(model, LOBBY_ORIGIN))
	model.Parent = workspace
	lobbyModel = model
	LeaderboardService.setLabels(lobbyInfo.boards)
	LobbyGameService.setup(lobbyInfo.games)
end

-- True while a map is built outside a match (a debug preview).
function MapService.previewing(): boolean
	return currentModel ~= nil and currentModel:GetAttribute("Preview") == true
end

-- Builds a match map and the meeting room. Returns everything gameplay needs,
-- converted to world space.
-- players: the user ids of the case's players (stamped on the map, so only their screens show the loading screen for it).
function MapService.build(mapId: string, players: { number }?)
	local started = os.clock()
	MapService.destroy()
	local def = MAPS[mapId] or MAPS.TaskForceHQ
	local model = newModel("LGameMap")
	-- Which map this is, for clients looking at it outside a match (a debug preview).
	model:SetAttribute("MapId", def.id)
	local b = Builder.new(model, MAP_ORIGIN)
	local layout = def.build(b)

	local info = {
		id = mapId,
		loadToken = 0,
		name = def.name,
		model = model,
		stations = {},
		spawns = {},
		-- every spot a player may start on: the spawns and the spare spots (Shared/SpawnPicker deals from them)
		pool = {},
		sheets = {},
		areas = {},
	}
	for i, stationDef in ipairs(layout.stations) do
		table.insert(info.stations, b:station(stationDef, "S" .. i))
	end
	-- The emergency bell stands at the map's old tip-box spot.
	info.bell = b:bell(layout.tipBox)
	if layout.board then
		b:corkBoard(layout.board)
	end
	for _, spot in ipairs(layout.spawns) do
		-- Face the middle of the map unless a rotation is given.
		local rot = spot.rot or math.deg(math.atan2(spot.x, spot.z))
		table.insert(info.spawns, b:world(b:cf(spot.x, spot.y or 0, spot.z, rot)))
	end
	table.move(info.spawns, 1, #info.spawns, 1, info.pool)
	for _, spot in ipairs(layout.spare and layout.spare.spawns or {}) do
		local rot = spot.rot or math.deg(math.atan2(spot.x, spot.z))
		table.insert(info.pool, b:world(b:cf(spot.x, spot.y or 0, spot.z, rot)))
	end
	for i, sheet in ipairs(layout.sheets) do
		table.insert(info.sheets, { id = "P" .. i, position = b:worldPos(sheet.x, sheet.y, sheet.z) })
	end
	for _, area in ipairs(layout.areas) do
		-- Designed intro marks (where avatars perform), when the map has them.
		local marks = {}
		for _, mark in ipairs(area.marks or {}) do
			table.insert(marks, { kind = mark.kind, cf = b:world(b:cf(mark.x, mark.y or 0, mark.z, mark.rot or 0)) })
		end
		table.insert(
			info.areas,
			{ name = area.name, position = b:worldPos(area.x, area.y or 0, area.z), marks = marks }
		)
	end
	-- What kind of ground each place is (roads, crossings, water...), for placing things.
	info.zones = Zones.new(layout.zones or {}, MAP_ORIGIN)
	info.spare = layout.spare
	-- The map's own data and builder, for its mechanic (Maps/Mechanics): the Tokyo crowd's walks and
	-- the cars' lanes.
	info.layout = layout
	info.origin = MAP_ORIGIN
	info.builder = b

	local meeting = MeetingRoom.build(Builder.new(model, MEETING_ORIGIN))
	info.meeting = meeting
	-- The cutscene sets, far off along X (role and win cutscenes play there).
	SceneBuilder.build(Builder.new(model, Venues.SETS), "Sets")

	-- For the clients' preloader (Presentation/MapPreloader) and the load gate (LoadGate): how many pieces
	-- to wait for, and which build this is.
	loadToken += 1
	model:SetAttribute("Pieces", #model:GetDescendants())
	model:SetAttribute("LoadToken", loadToken)
	model:SetAttribute("Players", if players then "," .. table.concat(players, ",") .. "," else "")
	info.loadToken = loadToken
	model.Parent = workspace
	currentModel = model
	if RunService:IsStudio() then
		local parts, lights = 0, 0
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				parts += 1
			elseif item:IsA("Light") then
				lights += 1
			end
		end
		local scene = model:FindFirstChild("Scene", true)
		print(
			string.format(
				"[DeathsGambit] Built %s (%s) in %.2f s: %d parts, %d lights.",
				mapId,
				if scene then tostring(scene:GetAttribute("Mode") or "scene") else "parts",
				os.clock() - started,
				parts,
				lights
			)
		)
		for _, problem in ipairs(MapContract.validateBuilt(info)) do
			warn("[DeathsGambit] Map " .. mapId .. ": " .. problem)
		end
	end
	return info
end

local EYE = Vector3.new(0, 4.5, 0) -- a standing player's eyes over the spot

-- Can someone standing at `from` see someone standing at `to` (both floor points)? Only the map's own walls hide them.
local function sightBetween(model: Instance, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local a, b = from + EYE, to + EYE
	return workspace:Raycast(a, b - a, params) == nil
end

-- Deals `count` start spots on the map, spread out and out of each other's sight (Shared/SpawnPicker); `occupied`:
-- where the living stand already (a respawn keeps away from them).
function MapService.dealSpawns(info: any, count: number, rng: Random, occupied: { Vector3 }?): { CFrame }
	local pool: { CFrame } = if info.pool and #info.pool > 0 then info.pool else info.spawns
	local points = {}
	for index, cframe in ipairs(pool) do
		points[index] = cframe.Position
	end
	info.sight = info.sight or {}
	local sight: { [number]: boolean } = info.sight
	local function visible(a: number, b: number): boolean
		local key = math.min(a, b) * 4096 + math.max(a, b)
		if sight[key] == nil then
			sight[key] = sightBetween(info.model, points[a], points[b])
		end
		return sight[key]
	end
	local dealt = SpawnPicker.pick(points, count, rng, {
		gap = Config.STARE_RANGE,
		visible = visible,
		sees = function(spot: number, at: Vector3): boolean
			-- (t is a root, about 3 studs over the floor)
			return sightBetween(info.model, at - Vector3.new(0, 3, 0), points[spot])
		end,
		occupied = occupied,
	})
	local out = {}
	for _, index in ipairs(dealt) do
		table.insert(out, pool[index])
	end
	return out
end

function MapService.destroy()
	if currentModel then
		currentModel:Destroy()
		currentModel = nil
	end
	-- The map's Terrain water is not part of its model.
	SceneBuilder.clearWater()
end

function MapService.init()
	-- Night defaults; each client blends to its venue's look (World/LightingController).
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ClockTime = 0
	for _, name in ipairs({ "LGameColor", "LGameBloom" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- A place made from the template still has its baseplate just under the lobby's ground, where it
	-- would show through the rift; the lobby's own ground replaces it.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	-- And its spawn pad, at the world's middle: the middle of the lobby's plaza. Roblox picks among every spawn pad,
	-- so players kept appearing in the plaza rather than on the terrace's ring (the owner, 2026-10-24: "move the spawn
	-- to the actual spawn"). Any other pad left in the place is switched off: the lobby's own is the only one.
	for _, item in ipairs(workspace:GetDescendants()) do
		if item:IsA("SpawnLocation") then
			if item.Parent == workspace and item.Name == "SpawnLocation" then
				item:Destroy()
			elseif item.Name ~= "LobbySpawn" then
				item.Enabled = false
			end
		end
	end

	local model = newModel("LGameLobby")
	lobbyInfo = Lobby.build(Builder.new(model, LOBBY_ORIGIN))
	model.Parent = workspace
	lobbyModel = model
	LeaderboardService.setLabels(lobbyInfo.boards)
	LobbyGameService.setup(lobbyInfo.games)
end

return MapService
