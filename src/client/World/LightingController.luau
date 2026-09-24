-- Blends the lighting to the venue the camera is in (lobby, map or meeting room), so each
-- place keeps its own mood whichever one the server is running. Everything here is local.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local LightingPresets = require(Shared:WaitForChild("LightingPresets"))
local Signal = require(Shared:WaitForChild("Signal"))
local Venues = require(Shared:WaitForChild("Venues"))

local ClientState = require(script.Parent.Parent.ClientState)

local LightingController = {}

-- Fired as (venue, preset) when the venue or its preset changes.
LightingController.Changed = Signal.new()

local BLEND = 1.2

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local currentKey = ""
local currentPreset: LightingPresets.Preset = LightingPresets.lobby
local currentVenue = "lobby"
local flashing = false

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

local function apply(preset: LightingPresets.Preset, time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, {
		ClockTime = preset.clockTime,
		Brightness = preset.brightness,
		ExposureCompensation = preset.exposure,
		Ambient = preset.ambient,
		OutdoorAmbient = preset.outdoorAmbient,
		FogStart = preset.fogStart,
		FogEnd = preset.fogEnd,
		FogColor = preset.fogColor,
	}):Play()
	TweenService:Create(atmosphere, info, {
		Density = preset.density,
		Haze = preset.haze,
		Glare = preset.glare,
		Color = preset.atmosphereColor,
		Decay = preset.decay,
	}):Play()
	TweenService:Create(grade, info, {
		Saturation = preset.saturation,
		Contrast = preset.contrast,
		TintColor = preset.tint,
	}):Play()
	TweenService:Create(bloom, info, {
		Intensity = preset.bloom,
		Size = preset.bloomSize,
		Threshold = preset.bloomThreshold,
	}):Play()
end

local function update(force: boolean?)
	local venue = Venues.at(focus())
	local mapId = if type(ClientState.public.mapId) == "string" then ClientState.public.mapId else nil
	local key = venue .. ":" .. (if venue == "map" then mapId or "" else "")
	if key == currentKey and not force then
		return
	end
	local instant = currentKey == ""
	currentKey = key
	currentVenue = venue
	currentPreset = LightingPresets.pick(venue, mapId)
	if not flashing then
		apply(currentPreset, if instant then 0 else BLEND)
	end
	LightingController.Changed:Fire(venue, currentPreset)
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
		local base = currentPreset.exposure
		for _, pulse in ipairs({ { 1.6, 0.06 }, { 0.2, 0.08 }, { 1.1, 0.05 } }) do
			Lighting.ExposureCompensation = base + pulse[1]
			task.wait(pulse[2])
		end
		Lighting.ExposureCompensation = base
		flashing = false
	end)
end

function LightingController.init()
	for _, name in ipairs({ "InkboundAtmosphere", "InkboundGrade", "InkboundBloom" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	atmosphere = Create("Atmosphere", { Name = "InkboundAtmosphere", Parent = Lighting })
	grade = Create("ColorCorrectionEffect", { Name = "InkboundGrade", Parent = Lighting })
	bloom = Create("BloomEffect", { Name = "InkboundBloom", Parent = Lighting })
	update(true)
	ClientState.PublicChanged:Connect(function()
		update()
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			update()
		end
	end)
end

return LightingController
