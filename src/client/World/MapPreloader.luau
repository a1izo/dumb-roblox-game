-- Loads before anything plays. When the server builds a match map, this waits behind the loading screen (UI/
-- AppleLoading: only on the screens of the case's own players, also for a map already built when they join) until
-- every piece of it has arrived over the network, then downloads every mesh, texture, decal and sound the
-- map, its cutscene sets, the props and the players' avatars use, and only then tells the server it is
-- ready (LoadGate holds the intro until everyone is). On joining, the props, textures and the lobby load
-- in the background (the join's eye waits for them: joinReady), so the lobby and the shop do not pop in either.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local AppleLoading = require(script.Parent.Parent.UI.AppleLoading)
local Router = require(script.Parent.Parent.UI.Core.Router)

local MapPreloader = {}

local ReadyRemote = Net.event("MapReady")
local BATCH = 80 -- content ids per PreloadAsync call (each call reports progress when it returns)
local PIECES_TIMEOUT = 20 -- the longest to wait for the map's pieces to arrive
local MAP_NAME = "LGameMap"
local LOBBY_NAME = "LGameLobby"
local ASSETS = "DeathsGambitAssets"
local LOCAL = Players.LocalPlayer

local loaded: { [string]: boolean } = {}

-- A content id to download, and what to hand PreloadAsync for it. A bare id is fetched as a picture, so a mesh's
-- or a sound's id given that way fails ("Asset type does not match requested type", every import in the live place,
-- 2026-10-26): those go as the instance that uses them.
type Entry = { id: string, content: string | Instance }

local function add(list: { Entry }, seen: { [string]: boolean }, id: any, holder: Instance?)
	if type(id) == "string" and id ~= "" and not seen[id] and not loaded[id] then
		seen[id] = true
		table.insert(list, { id = id, content = holder or id })
	end
end

local SURFACE_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }

-- Every content id under `root`.
local function contentOf(root: Instance, list: { Entry }, seen: { [string]: boolean })
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("MeshPart") then
			add(list, seen, item.MeshId, item)
			add(list, seen, item.TextureID)
		elseif item:IsA("SpecialMesh") then
			add(list, seen, item.MeshId, item)
			add(list, seen, item.TextureId)
		elseif item:IsA("Decal") then -- Textures too
			add(list, seen, item.Texture)
		elseif item:IsA("SurfaceAppearance") then
			for _, key in ipairs(SURFACE_MAPS) do
				local ok, value = pcall(function()
					return (item :: any)[key]
				end)
				if ok then
					add(list, seen, value)
				end
			end
		elseif item:IsA("Shirt") then
			add(list, seen, item.ShirtTemplate)
		elseif item:IsA("Pants") then
			add(list, seen, item.PantsTemplate)
		elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
			add(list, seen, (item :: any).Texture)
		elseif item:IsA("Sound") then
			add(list, seen, item.SoundId, item)
		end
	end
end

-- Downloads `list`, calling onProgress(0..1) as it goes.
local function preload(list: { Entry }, onProgress: ((number) -> ())?)
	local total = #list
	for first = 1, total, BATCH do
		local batch = table.move(list, first, math.min(total, first + BATCH - 1), 1, {})
		local contents = {}
		for _, entry in ipairs(batch) do
			table.insert(contents, entry.content)
		end
		pcall(function()
			ContentProvider:PreloadAsync(contents)
		end)
		for _, entry in ipairs(batch) do
			loaded[entry.id] = true
		end
		if onProgress then
			onProgress(math.min(total, first + BATCH - 1) / total)
		end
	end
	if onProgress then
		onProgress(1)
	end
end

local busy: Model? = nil
local joinDone = false
local mapDone: Model? = nil

-- Is this map this player's case? (MapService stamps it with its players' ids; a debug preview has none.)
local function isMine(model: Model): boolean
	local list = model:GetAttribute("Players")
	return type(list) == "string" and string.find(list, "," .. LOCAL.UserId .. ",", 1, true) ~= nil
end

-- `quiet`: no loading screen (the join's own screen covers this load).
local function onMap(model: Model, quiet: boolean?)
	if busy == model then
		return
	end
	busy = model
	local token = model:GetAttribute("LoadToken")
	local want = tonumber(model:GetAttribute("Pieces")) or 0
	local loader = if isMine(model) and not quiet then AppleLoading.open() else nil
	if loader then
		Router.setBlocking("loading", true)
	end
	local function set(fraction: number)
		if loader then
			loader.progress(fraction)
		end
	end
	-- 1. Every piece of the map, over the network.
	local started = os.clock()
	while model.Parent and os.clock() - started < PIECES_TIMEOUT do
		local have = #model:GetDescendants()
		set(0.35 * math.min(1, have / math.max(1, want)))
		if have >= want then
			break
		end
		task.wait(0.1)
	end
	-- 2. Everything it, the props and the avatars are made of.
	local list, seen = {}, {}
	contentOf(model, list, seen)
	local store = ReplicatedStorage:FindFirstChild(ASSETS)
	if store then
		contentOf(store, list, seen)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			contentOf(player.Character, list, seen)
		end
	end
	preload(list, function(fraction: number)
		set(0.35 + 0.65 * fraction)
	end)
	if type(token) == "number" and model.Parent then
		ReadyRemote:FireServer(token)
	end
	mapDone = model
	busy = nil
	if loader then
		loader.finish()
		Router.setBlocking("loading", false)
	end
end

-- The join's own load is done: the props and the lobby downloaded (and the case's map, for a player joining a case
-- already running).
function MapPreloader.joinReady(): boolean
	if not joinDone then
		return false
	end
	local map = workspace:FindFirstChild(MAP_NAME)
	return not (map and map:IsA("Model") and isMine(map)) or mapDone == map
end

-- Is a case of this player's already running as they join? (They come in through the loading screen, not the eye.)
function MapPreloader.joiningCase(): boolean
	local map = workspace:FindFirstChild(MAP_NAME)
	return map ~= nil and map:IsA("Model") and isMine(map)
end

-- The lobby and the avatars in it, downloaded again on the way back from a case (most of it is still there).
function MapPreloader.lobby(onProgress: (number) -> ())
	local list, seen = {}, {}
	for _, root in ipairs({ workspace:FindFirstChild(LOBBY_NAME), ReplicatedStorage:FindFirstChild(ASSETS) }) do
		if root then
			contentOf(root, list, seen)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			contentOf(player.Character, list, seen)
		end
	end
	preload(list, onProgress)
end

function MapPreloader.init()
	workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == MAP_NAME and child:IsA("Model") then
			task.spawn(onMap, child)
		end
	end)
	-- A match found in another server: the loading screen goes up here, and its still goes with the teleport (a failed
	-- teleport puts the player back in the queue: the screen lifts after a while).
	Net.event("Teleporting").OnClientEvent:Connect(function()
		pcall(function()
			TeleportService:SetTeleportGui(AppleLoading.teleportGui())
		end)
		local loader = AppleLoading.open()
		loader.progress(0.2)
		task.delay(20, function()
			loader.finish()
		end)
	end)
	-- A case's map already built as this player joins.
	local existing = workspace:FindFirstChild(MAP_NAME)
	if existing and existing:IsA("Model") then
		task.spawn(onMap, existing, true)
	end
	-- Quietly, on joining: every prop and texture and the lobby, so the lobby and the shop do not pop in (the join's
	-- eye waits for this).
	task.spawn(function()
		local list, seen = {}, {}
		for _, root in ipairs({
			ReplicatedStorage:WaitForChild(ASSETS, 30),
			workspace:WaitForChild(LOBBY_NAME, 30),
		}) do
			if root then
				contentOf(root, list, seen)
			end
		end
		preload(list)
		joinDone = true
	end)
end

return MapPreloader
