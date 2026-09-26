-- The lighting on this screen: the venue the camera is in (lobby, map or meeting room) sets
-- the base look, the match phase lays a mood over it, and the Low graphics setting trims it
-- (see LightingPresets). Everything is blended slowly and is local to this client.
--
-- It also tunes the venue's own lamps: the strongest few cast hard shadows (the "keys"), the
-- rest are fill, and a mood scales the two groups apart: a single cold key over the meeting
-- table, lamps dying in the Grimoire phase, a blackout around the verdict's spotlight.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local LightingPresets = require(Shared:WaitForChild("LightingPresets"))
local Signal = require(Shared:WaitForChild("Signal"))
local Venues = require(Shared:WaitForChild("Venues"))

local ClientState = require(script.Parent.Parent.ClientState)
local CueRouter = require(script.Parent.Parent.Presentation.CueRouter)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Screens = require(script.Parent.Parent.UI.Screens)
local Textures = require(script.Parent.Parent.UI.Kit.Textures)

local LightingController = {}

-- Fired as (venue, preset) when the venue or its preset changes.
LightingController.Changed = Signal.new()

local BLEND = 3.5 -- seconds for a change of venue or mood
local CREEP_BLEND = 0.6 -- the vote's slow creep, applied in small steps

type Lamp = { brightness: number, range: number, shadows: boolean }

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local vignetteHolder: Frame
local currentKey = ""
local currentPreset: LightingPresets.Preset = LightingPresets.lobby
local currentVenue = "lobby"
local currentLook: LightingPresets.Look? = nil
local flashing = false
local debugKey: string? = nil -- "lobby", "meeting" or "map:<mapId>", set from the debug panel
local debugMood: string? = nil -- a phase id (or "OutroHand" / "OutroAgency"), from the debug panel
local winner: string? = nil -- the winning side once the ending starts
local phaseStartedAt = 0

-- The lamps of the venue being lit, with their values as built.
local lamps: { [Light]: Lamp } = setmetatable({}, { __mode = "k" }) :: any
local keys: { [Light]: boolean } = {}
local lampModel: Instance? = nil
local lampVenue = ""
local lampKeyCount = -1

local function focus(): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return Venues.LOBBY
	end
	local subject = camera.CameraSubject
	if subject and subject:IsA("Humanoid") and subject.RootPart then
		return subject.RootPart.Position
	elseif subject and subject:IsA("BasePart") then
		return subject.Position
	end
	return camera.Focus.Position
end

-- Lamps --------------------------------------------------------------------------------------

local function lampPosition(light: Light): Vector3?
	local parent = light.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

-- Finds the venue's lamps (once per venue and build) and picks the ones that cast shadows.
local function gatherLamps(venue: string, keyCount: number)
	local model = workspace:FindFirstChild(if venue == "lobby" then "LGameLobby" else "LGameMap")
	if model == lampModel and venue == lampVenue and keyCount == lampKeyCount then
		return
	end
	lampModel = model
	lampVenue = venue
	lampKeyCount = keyCount
	table.clear(keys)
	local list = {}
	if model then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("Light") then
				local at = lampPosition(item)
				if at and Venues.at(at) == venue then
					if not lamps[item] then
						lamps[item] = { brightness = item.Brightness, range = item.Range, shadows = item.Shadows }
					end
					table.insert(list, item)
				end
			end
		end
	end
	-- The keys: the lamps built to cast shadows first, then the strongest.
	table.sort(list, function(a, b)
		local la, lb = lamps[a], lamps[b]
		if la.shadows ~= lb.shadows then
			return la.shadows
		end
		return la.brightness * la.range > lb.brightness * lb.range
	end)
	for index = 1, math.min(keyCount, #list) do
		keys[list[index]] = true
	end
end

-- The brightness a lamp should have right now (the flicker returns lamps to this).
function LightingController.lampBrightness(light: Light): number?
	local lamp = lamps[light]
	local look = currentLook
	if not lamp or not look then
		return nil
	end
	return lamp.brightness * (if keys[light] then look.keyScale else look.fillScale)
end

local function applyLamps(look: LightingPresets.Look, time: number)
	gatherLamps(currentVenue, look.keyLights)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	for light, lamp in pairs(lamps) do
		if light.Parent and lampVenue == currentVenue then
			local at = lampPosition(light)
			if at and Venues.at(at) == currentVenue then
				local key = keys[light] == true
				local target = lamp.brightness * (if key then look.keyScale else look.fillScale)
				light.Range = lamp.range * look.rangeScale
				light.Shadows = key
				if time > 0 then
					TweenService:Create(light, info, { Brightness = target }):Play()
				else
					light.Brightness = target
				end
			end
		end
	end
end

-- The look ---------------------------------------------------------------------------------------

local function moodName(): string
	if debugMood then
		return debugMood
	end
	local public = ClientState.public
	if not public.active or currentVenue == "lobby" then
		return "Lobby"
	end
	if public.phase == "Outro" then
		return if winner == "Team" then "OutroAgency" else "OutroHand"
	end
	return public.phase
end

local function moodOf(name: string): LightingPresets.Mood
	return LightingPresets.moods[name] or LightingPresets.NEUTRAL
end

-- How far through the current phase (0 to 1).
local function progress(): number
	local endsAt = tonumber(ClientState.public.endsAt) or 0
	local span = endsAt - phaseStartedAt
	if span <= 0 then
		return 0
	end
	return math.clamp((workspace:GetServerTimeNow() - phaseStartedAt) / span, 0, 1)
end

local function setVignette(strength: number, time: number)
	local image = vignetteHolder:FindFirstChildOfClass("ImageLabel")
	if image then
		local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
		TweenService:Create(image, info, { ImageTransparency = 1 - strength }):Play()
	end
end

local function apply(look: LightingPresets.Look, time: number)
	currentLook = look
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = look.clockTime,
		Brightness = look.brightness,
		ExposureCompensation = look.exposure,
		Ambient = look.ambient,
		OutdoorAmbient = look.outdoorAmbient,
		EnvironmentDiffuseScale = look.envDiffuse,
		EnvironmentSpecularScale = look.envSpecular,
		FogStart = look.fogStart,
		FogEnd = look.fogEnd,
		FogColor = look.fogColor,
	}):Play()
	TweenService:Create(atmosphere, info, {
		Density = look.density,
		Haze = look.haze,
		Glare = look.glare,
		Color = look.atmosphereColor,
		Decay = look.decay,
	}):Play()
	TweenService:Create(grade, info, {
		Saturation = look.saturation,
		Contrast = look.contrast,
		TintColor = look.tint,
	}):Play()
	TweenService:Create(bloom, info, {
		Intensity = look.bloom,
		Size = look.bloomSize,
		Threshold = look.bloomThreshold,
	}):Play()
	bloom.Enabled = look.bloom > 0
	setVignette(look.vignette, time)
	applyLamps(look, time)
end

local function resolve(): LightingPresets.Look
	return LightingPresets.resolve(currentPreset, moodOf(moodName()), {
		low = Settings.get("lowGraphics") == true,
		progress = progress(),
	})
end

local function update(force: boolean?)
	local venue = Venues.at(focus())
	local mapId = if type(ClientState.public.mapId) == "string" then ClientState.public.mapId else nil
	if debugKey then
		venue = string.match(debugKey, "^(%a+)") or venue
		mapId = string.match(debugKey, "^map:(.+)$") or mapId
	end
	local key = venue .. ":" .. (if venue == "map" then mapId or "" else "") .. ":" .. moodName()
	if key == currentKey and not force then
		return
	end
	local instant = currentKey == ""
	local venueChanged = venue ~= currentVenue
		or (venue == "map" and currentPreset ~= LightingPresets.pick(venue, mapId))
	currentKey = key
	currentVenue = venue
	currentPreset = LightingPresets.pick(venue, mapId)
	if not flashing then
		apply(resolve(), if instant then 0 else BLEND)
	end
	if venueChanged or instant then
		LightingController.Changed:Fire(venue, currentPreset)
	end
end

-- Debug panel: forces a lighting preset (nil to follow the camera again).
function LightingController.setDebugPreset(key: string?)
	debugKey = key
	update(true)
end

-- Debug panel: forces a mood (nil to follow the phase again).
function LightingController.setDebugMood(name: string?)
	debugMood = name
	update(true)
end

function LightingController.venue(): string
	return currentVenue
end

function LightingController.preset(): LightingPresets.Preset
	return currentPreset
end

-- A lightning flash: the scene blows out for a moment, twice.
function LightingController.lightning()
	if flashing then
		return
	end
	flashing = true
	task.spawn(function()
		local base = if currentLook then currentLook.exposure else currentPreset.exposure
		for _, pulse in ipairs({ { 1.6, 0.06 }, { 0.2, 0.08 }, { 1.1, 0.05 } }) do
			Lighting.ExposureCompensation = base + pulse[1]
			task.wait(pulse[2])
		end
		Lighting.ExposureCompensation = base
		flashing = false
	end)
end

function LightingController.init()
	for _, child in ipairs(Lighting:GetChildren()) do
		local ours = child.Name == "InkboundAtmosphere"
			or child.Name == "InkboundGrade"
			or child.Name == "InkboundBloom"
			or child.Name == "InkboundSky"
		if ours or child:IsA("Sky") then
			child:Destroy()
		end
	end
	atmosphere = Create("Atmosphere", { Name = "InkboundAtmosphere", Parent = Lighting })
	grade = Create("ColorCorrectionEffect", { Name = "InkboundGrade", Parent = Lighting })
	bloom = Create("BloomEffect", { Name = "InkboundBloom", Parent = Lighting })
	-- Roblox's own night sky: stars and a small moon, nothing to upload.
	Create("Sky", {
		Name = "InkboundSky",
		StarCount = 2500,
		CelestialBodiesShown = true,
		MoonAngularSize = 14,
		SunAngularSize = 8,
		Parent = Lighting,
	})
	-- The mood's vignette, under the HUD.
	vignetteHolder = Create("Frame", {
		Name = "Vignette",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = Screens.world,
	})
	local function drawVignette()
		vignetteHolder:ClearAllChildren()
		local id = Textures.id("UiVignette")
		if id ~= "" then
			Create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = Color3.new(0, 0, 0),
				ImageTransparency = 1 - (if currentLook then currentLook.vignette else 0.2),
				Size = UDim2.fromScale(1, 1),
				Parent = vignetteHolder,
			})
		end
	end
	drawVignette()
	Textures.whenReady(drawVignette)

	update(true)
	ClientState.PublicChanged:Connect(function()
		if not ClientState.public.active then
			winner = nil
		end
		update()
	end)
	ClientState.PhaseChanged:Connect(function()
		phaseStartedAt = workspace:GetServerTimeNow()
		update()
	end)
	CueRouter.register("outro", function(cue)
		winner = if type(cue.data) == "table" then cue.data.winner else nil
		update(true)
	end)
	Settings.Changed:Connect(function(key)
		if key == "lowGraphics" then
			update(true)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			update()
			-- The vote's red creeps in over the phase.
			if not flashing and moodOf(moodName()).creep then
				apply(resolve(), CREEP_BLEND)
			end
		end
	end)
end

return LightingController
