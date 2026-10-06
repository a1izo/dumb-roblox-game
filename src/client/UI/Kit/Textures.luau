--!strict
-- The UI's own textures (glyph atlases, the clipped-corner Notch shapes, scanlines, grain, icons). They
-- are drawn by art/scripts/ui and travel in DeathsGambitModels_Core.fbx on carrier quads, so importing that
-- file is all it takes; Assets.texture finds them. Until they are imported and loaded (or if a load
-- fails) every component draws a code-only version instead (plain rectangles, a Montserrat stand-in
-- for the lettering), and redraws when Ready fires.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Signal = require(Shared:WaitForChild("Signal"))

local Textures = {}

-- Every UI texture by name (the carrier is Tex_<name>).
Textures.NAMES = {
	-- lettering (glyph atlases, see src/shared/UI/GlyphFonts.luau)
	"UiTitle1",
	"UiHead1",
	"UiSemi1",
	"UiRnLight1",
	"UiRnMedium1",
	-- the Notch shapes (9-slice), the film textures, the screen-edge shade and the icons
	"UiNotch",
	"UiNotchBtn",
	"UiNotchBtnLine",
	"UiNotchWin",
	"UiNotchWinLine",
	"UiScan",
	"UiGrain",
	"UiVignette",
	"UiIcons",
	"UiWordmark",
}

Textures.Ready = Signal.new()

local loaded: { [string]: string } = {}
local ready = false

-- The content id of a loaded UI texture, or "" while it is missing or failed.
function Textures.id(name: string): string
	return loaded[name] or ""
end

function Textures.has(name: string): boolean
	return loaded[name] ~= nil
end

function Textures.isReady(): boolean
	return ready
end

-- Calls back now if the textures are ready, else once they are.
function Textures.whenReady(callback: () -> ()): Signal.Connection?
	if ready then
		task.spawn(callback)
		return nil
	end
	return Textures.Ready:Connect(callback)
end

local function load()
	local ids, byId = {}, {}
	for _, name in ipairs(Textures.NAMES) do
		local id = Assets.texture(name)
		if id ~= "" then
			table.insert(ids, id)
			byId[id] = name
		end
	end
	if #ids == 0 then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync(ids, function(id: string, status: Enum.AssetFetchStatus)
			local name = byId[id]
			if name and status == Enum.AssetFetchStatus.Success then
				loaded[name] = id
			end
		end)
	end)
	ready = true
	Textures.Ready:Fire()
end

function Textures.init()
	task.spawn(function()
		-- The server moves the imports into place at start; wait until it has.
		-- The store is named DeathsGambitAssets (InkboundAssets in a place from before the rename).
		local function find()
			return ReplicatedStorage:FindFirstChild("DeathsGambitAssets")
				or ReplicatedStorage:FindFirstChild("InkboundAssets")
		end
		local store = find()
		local waitUntil = os.clock() + 30
		while not store and os.clock() < waitUntil do
			task.wait(0.25)
			store = find()
		end
		if not store then
			return
		end
		local deadline = os.clock() + 30
		while not store:GetAttribute("Installed") and os.clock() < deadline do
			task.wait(0.25)
		end
		load()
	end)
end

return Textures
