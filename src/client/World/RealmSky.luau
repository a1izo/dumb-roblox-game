--!strict
-- The Grey Realm's sky: no sun, moon or stars, and clouds that never quite stop moving.
--
--   * Terrain clouds, the highest layer: grey, overcast, their cover and density wandering slowly
--     (sums of sines with periods that never line up, so the pattern does not repeat) so gaps open
--     and close in the grey and the whole sky gets a little darker and lighter.
--   * The lighting breathes: the ambient light, the exposure and the haze swell and ebb by a few
--     per cent over minutes. The scene's cloud sprites (realmcloud / realmhaze emitters, built by
--     the server's SceneBuilder) take the scene's light, so the whole cloud belt darkens and lightens
--     with it, one layer out of step with the next because they live at different distances.
--
-- Only while the camera is in the lobby (LightingController.Changed says which venue it is);
-- elsewhere the sky and clouds are put back as they were. Everything slow and local to this
-- client. The numbers to tune are all in TUNING.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local LightingController = require(script.Parent.LightingController)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local RealmSky = {}

local TUNING = {
	-- Terrain clouds: how much of the sky they cover, how thick they are, their colour.
	cover = 0.82,
	coverSwing = 0.07, -- cover wanders by up to this much either way (never past 1)
	density = 0.95,
	densitySwing = 0.05,
	color = Color3.fromRGB(172, 178, 190),
	colorSwing = 0.12, -- the clouds' colour darkens and lightens by up to this fraction
	-- Periods in seconds of the three waves everything wanders on (they never line up).
	periods = { 173, 97, 61 },
	-- The light's breathing: fractions (ambient, atmosphere density) and an exposure offset, and its own periods.
	ambientSwing = 0.05,
	densitySwingAtmosphere = 0.05,
	exposureSwing = 0.05,
	breathPeriods = { 131, 83, 47 },
	-- How often the values are nudged (seconds); the changes are far too slow to see the steps.
	step = 0.15,
}

type Saved = {
	clouds: boolean,
	cover: number,
	density: number,
	color: Color3,
	stars: number,
	bodies: boolean,
	sun: number,
	moon: number,
}

local sky: Sky? = nil
local clouds: Clouds? = nil
local saved: Saved? = nil
local active = false
local startedAt = os.clock()
local lastStep = 0

-- A slow wandering value in -1 to 1: three sines whose periods do not line up.
local function wander(t: number, periods: { number }, phase: number): number
	local sum = 0
	for i, period in ipairs(periods) do
		sum += math.sin(2 * math.pi * t / period + phase * i * 1.7)
	end
	return sum / #periods
end

local function findClouds(): Clouds
	local terrain = workspace.Terrain
	local found = terrain:FindFirstChildOfClass("Clouds")
	if found then
		return found
	end
	return Create("Clouds", { Parent = terrain })
end

local function remember()
	if saved then
		return
	end
	local current = findClouds()
	clouds = current
	local s = sky
	saved = {
		clouds = current.Enabled,
		cover = current.Cover,
		density = current.Density,
		color = current.Color,
		stars = if s then s.StarCount else 2500,
		bodies = if s then s.CelestialBodiesShown else true,
		sun = if s then s.SunAngularSize else 8,
		moon = if s then s.MoonAngularSize else 14,
	}
end

local function enter()
	sky = Lighting:FindFirstChild("DeathsGambitSky") :: Sky?
	remember()
	local s = sky
	if s then
		s.StarCount = 0
		s.CelestialBodiesShown = false
		s.SunAngularSize = 0
		s.MoonAngularSize = 0
	end
	local c = clouds
	if c then
		c.Enabled = true
		c.Cover = TUNING.cover
		c.Density = TUNING.density
		c.Color = TUNING.color
	end
	active = true
end

local function leave()
	active = false
	local restore = saved
	if not restore then
		return
	end
	local s = sky
	if s then
		s.StarCount = restore.stars
		s.CelestialBodiesShown = restore.bodies
		s.SunAngularSize = restore.sun
		s.MoonAngularSize = restore.moon
	end
	local c = clouds
	if c then
		c.Enabled = restore.clouds
		c.Cover = restore.cover
		c.Density = restore.density
		c.Color = restore.color
	end
end

-- The clouds and the light, a step further along.
local function nudge()
	local t = os.clock() - startedAt
	local c = clouds
	if c then
		c.Cover = math.clamp(TUNING.cover + TUNING.coverSwing * wander(t, TUNING.periods, 0.3), 0.55, 1)
		c.Density = math.clamp(TUNING.density + TUNING.densitySwing * wander(t, TUNING.periods, 2.1), 0.4, 1)
		local k = 1 + TUNING.colorSwing * wander(t, TUNING.periods, 4.4)
		c.Color = Color3.new(
			math.clamp(TUNING.color.R * k, 0, 1),
			math.clamp(TUNING.color.G * k, 0, 1),
			math.clamp(TUNING.color.B * k, 0, 1)
		)
	end
	-- The light breathes only when nothing else is moving it (a blend or a flash would fight us).
	local look = LightingController.look()
	if look and LightingController.settled() and not Settings.get("reduceMotion") then
		local b = wander(t, TUNING.breathPeriods, 1.3)
		local scale = 1 + TUNING.ambientSwing * b
		Lighting.Ambient = Color3.new(look.ambient.R * scale, look.ambient.G * scale, look.ambient.B * scale)
		Lighting.OutdoorAmbient =
			Color3.new(look.outdoorAmbient.R * scale, look.outdoorAmbient.G * scale, look.outdoorAmbient.B * scale)
		Lighting.ExposureCompensation = look.exposure + TUNING.exposureSwing * b
		local atmosphere = LightingController.atmosphere()
		atmosphere.Density = look.density * (1 + TUNING.densitySwingAtmosphere * wander(t, TUNING.breathPeriods, 3.7))
	end
end

function RealmSky.isActive(): boolean
	return active
end

function RealmSky.init()
	LightingController.Changed:Connect(function(venue, preset)
		if venue == "lobby" and preset.realmSky then
			if not active then
				enter()
			end
		elseif active then
			leave()
		end
	end)
	-- The first venue was announced before this module listened.
	if LightingController.venue() == "lobby" and LightingController.preset().realmSky then
		enter()
	end
	task.spawn(function()
		while true do
			task.wait(TUNING.step)
			if active and os.clock() - lastStep >= TUNING.step then
				lastStep = os.clock()
				nudge()
			end
		end
	end)
end

return RealmSky
