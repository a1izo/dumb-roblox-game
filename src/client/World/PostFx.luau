--!strict
-- The lens over the world on this screen (the owner, 2026-11-01): depth of field and film grain, both settings.
--
-- Depth of field (setting depthOfField): Off, Subtle (the default: only what is far, about 40 studs on, goes soft, so
-- names, faces and clues near you stay sharp) or Cinematic (a shorter sharp reach, softer beyond). Meetings and the
-- vote soften a little more. A cutscene's camera brings its own lens (Presentation/Cinema, ShotPlayer), so this one
-- steps aside while a scripted camera holds the view.
--
-- Film grain (setting filmGrain): subtle in play, heavier as the mood's vignette deepens (meetings, the vote, a
-- blackout, the verdict). Still under Reduce motion, and off in Low quality mode.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Create = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Create"))

local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)
local Textures = require(script.Parent.Parent.UI.Kit.Textures)
local LightingController = require(script.Parent.LightingController)

local PostFx = {}

-- { sharp reach, far softness } per setting (1 Subtle, 2 Cinematic)
local LENS = { { 40, 0.14 }, { 24, 0.32 } }
local HEAVY_FAR = 0.08 -- added in a heavy mood (a meeting, the vote)
local GRAIN_LIGHT = 0.955 -- the grain's transparency in play
local GRAIN_HEAVY = 0.885 -- and under the heaviest mood

local lens: DepthOfFieldEffect
local grain: ImageLabel? = nil
local grained = 0

-- How heavy the mood is, 0 (play) to 1 (the verdict), from its vignette.
local function heaviness(): number
	local look = LightingController.look()
	local vignette = if look then look.vignette else 0.2
	return math.clamp((vignette - 0.2) / 0.8, 0, 1)
end

local function grainWanted(): boolean
	return Settings.get("filmGrain") ~= false and not Motion.isLow() and Textures.has("UiGrain")
end

local function syncGrain()
	if grainWanted() and not grain then
		grain = Create("ImageLabel", {
			Name = "FilmGrain",
			BackgroundTransparency = 1,
			Image = Textures.id("UiGrain"),
			ImageTransparency = GRAIN_LIGHT,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(128, 128),
			Size = UDim2.new(1, 64, 1, 64),
			ZIndex = 2, -- (over the mood's vignette, under everything else on the world layer)
			Parent = Screens.world,
		}) :: ImageLabel
	elseif not grainWanted() and grain then
		grain:Destroy()
		grain = nil
	end
end

local function step()
	local camera = workspace.CurrentCamera
	local heavy = heaviness()
	local setting = math.clamp(math.floor((tonumber(Settings.get("depthOfField")) or 1) + 0.5), 0, 2)
	local scripted = camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable
	if setting == 0 or scripted or LightingController.venue() == "sets" then
		lens.Enabled = false
	else
		local spec = LENS[setting]
		lens.Enabled = true
		lens.FocusDistance = 0
		lens.InFocusRadius = spec[1] * (1 - 0.25 * heavy)
		lens.FarIntensity = spec[2] + HEAVY_FAR * heavy
		lens.NearIntensity = 0
	end
	local film = grain
	if film then
		film.ImageTransparency = GRAIN_LIGHT + (GRAIN_HEAVY - GRAIN_LIGHT) * heavy
		-- (its tiles jump 24 times a second, as film's do; held still under Reduce motion)
		if not Motion.isReduced() and os.clock() - grained >= 1 / 24 then
			grained = os.clock()
			film.Position = UDim2.fromOffset(math.random(-64, 0), math.random(-64, 0))
		end
	end
end

function PostFx.init()
	local old = Lighting:FindFirstChild("DeathsGambitLens")
	if old then
		old:Destroy()
	end
	lens = Create("DepthOfFieldEffect", {
		Name = "DeathsGambitLens",
		Enabled = false,
		FarIntensity = 0,
		NearIntensity = 0,
		FocusDistance = 0,
		InFocusRadius = 40,
		Parent = Lighting,
	}) :: DepthOfFieldEffect
	syncGrain()
	Textures.whenReady(syncGrain)
	Settings.Changed:Connect(function(key: string)
		if key == "filmGrain" or key == "lowGraphics" then
			syncGrain()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return PostFx
