-- Loads before anything plays. When the server builds a match map, this waits behind a loading card until
-- every piece of it has arrived over the network, then downloads every mesh, texture, decal and sound the
-- map, its cutscene sets, the props and the players' avatars use, and only then tells the server it is
-- ready (LoadGate holds the intro until everyone is). On joining, the props and textures load quietly
-- in the background, so the lobby and the shop do not pop in either.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Screens = require(script.Parent.Parent.UI.Screens)

local C = Kit.color

local MapPreloader = {}

local ReadyRemote = Net.event("MapReady")
local BATCH = 80 -- content ids per PreloadAsync call (each call reports progress when it returns)
local PIECES_TIMEOUT = 20 -- the longest to wait for the map's pieces to arrive
local MAP_NAME = "LGameMap"
local ASSETS = "DeathsGambitAssets"

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

-- The loading card: black, a line of text and a bar. Returns set(fraction, text) and close().
local function card(): ((number, string?) -> (), () -> ())
	Router.setBlocking("loading", true)
	local frame = Kit.Base.make("Frame", {
		Name = "Loading",
		BackgroundColor3 = C.void,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = Screens.system,
	})
	local label = Kit.label({
		Text = "Opening the case file",
		font = "label",
		size = "small",
		color = C.bone,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(0.6, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 51,
		Parent = frame,
	})
	local track = Kit.Base.make("Frame", {
		BackgroundColor3 = C.bone,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.32, 0, 0, 3),
		ZIndex = 51,
		Parent = frame,
	})
	local bar = Kit.Base.make("Frame", {
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 52,
		Parent = track,
	})
	local function set(fraction: number, text: string?)
		bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if text then
			label.Text = text
		end
	end
	local function close()
		Router.setBlocking("loading", false)
		frame:Destroy()
	end
	return set, close
end

local busy: Model? = nil

local function onMap(model: Model)
	if busy == model then
		return
	end
	busy = model
	local token = model:GetAttribute("LoadToken")
	local want = tonumber(model:GetAttribute("Pieces")) or 0
	local set, close = card()
	-- 1. Every piece of the map, over the network.
	local started = os.clock()
	while model.Parent and os.clock() - started < PIECES_TIMEOUT do
		local have = #model:GetDescendants()
		set(0.35 * math.min(1, have / math.max(1, want)), "Opening the case file")
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
		set(0.35 + 0.65 * fraction, "Gathering the evidence")
	end)
	if type(token) == "number" and model.Parent then
		ReadyRemote:FireServer(token)
	end
	close()
	busy = nil
end

function MapPreloader.init()
	workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == MAP_NAME and child:IsA("Model") then
			task.spawn(onMap, child)
		end
	end)
	-- Quietly, on joining: every prop and texture, so the lobby and the shop do not pop in.
	task.spawn(function()
		local store = ReplicatedStorage:WaitForChild(ASSETS, 60)
		if store then
			local list, seen = {}, {}
			contentOf(store, list, seen)
			preload(list)
		end
	end)
end

return MapPreloader
