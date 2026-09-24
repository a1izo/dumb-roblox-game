--!strict
-- The look of each venue: night, washed-out colour, hard contrast, fog and rain. Clients
-- blend to the preset of the venue the camera is in. Lighting.Technology is Future (see
-- default.project.json), so lamps cast real shadows.

local LightingPresets = {}

export type Preset = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogStart: number,
	fogEnd: number,
	fogColor: Color3,
	-- Atmosphere
	density: number,
	haze: number,
	glare: number,
	atmosphereColor: Color3,
	decay: Color3,
	-- colour grade
	saturation: number,
	contrast: number,
	tint: Color3,
	-- bloom
	bloom: number,
	bloomSize: number,
	bloomThreshold: number,
	-- weather: 0 = none, 1 = downpour
	rain: number,
	lightning: boolean,
}

local function preset(p: Preset): Preset
	return p
end

LightingPresets.lobby = preset({
	clockTime = 0.5,
	brightness = 1,
	exposure = -0.1,
	ambient = Color3.fromRGB(58, 58, 70),
	outdoorAmbient = Color3.fromRGB(52, 52, 66),
	fogStart = 60,
	fogEnd = 900,
	fogColor = Color3.fromRGB(18, 18, 26),
	density = 0.28,
	haze = 1.5,
	glare = 0,
	atmosphereColor = Color3.fromRGB(60, 60, 80),
	decay = Color3.fromRGB(40, 30, 40),
	saturation = -0.35,
	contrast = 0.15,
	tint = Color3.fromRGB(235, 236, 255),
	bloom = 0.7,
	bloomSize = 24,
	bloomThreshold = 1.1,
	rain = 0.35,
	lightning = false,
})

LightingPresets.meeting = preset({
	clockTime = 0,
	brightness = 0.6,
	exposure = -0.15,
	ambient = Color3.fromRGB(44, 40, 48),
	outdoorAmbient = Color3.fromRGB(30, 28, 36),
	fogStart = 80,
	fogEnd = 1200,
	fogColor = Color3.fromRGB(10, 8, 12),
	density = 0.2,
	haze = 0.5,
	glare = 0,
	atmosphereColor = Color3.fromRGB(40, 30, 40),
	decay = Color3.fromRGB(40, 20, 25),
	saturation = -0.5,
	contrast = 0.28,
	tint = Color3.fromRGB(255, 238, 236),
	bloom = 0.8,
	bloomSize = 28,
	bloomThreshold = 1,
	rain = 0,
	lightning = false,
})

-- Per map id.
LightingPresets.maps = {
	TaskForceHQ = preset({
		clockTime = 22,
		brightness = 0.8,
		exposure = 0,
		ambient = Color3.fromRGB(70, 72, 84),
		outdoorAmbient = Color3.fromRGB(46, 48, 60),
		fogStart = 120,
		fogEnd = 1500,
		fogColor = Color3.fromRGB(14, 14, 20),
		density = 0.25,
		haze = 1,
		glare = 0,
		atmosphereColor = Color3.fromRGB(50, 55, 75),
		decay = Color3.fromRGB(30, 30, 45),
		saturation = -0.42,
		contrast = 0.2,
		tint = Color3.fromRGB(230, 238, 255),
		bloom = 0.6,
		bloomSize = 24,
		bloomThreshold = 1.2,
		rain = 0.7,
		lightning = true,
	}),
	UniversityCampus = preset({
		clockTime = 23,
		brightness = 0.9,
		exposure = 0,
		ambient = Color3.fromRGB(66, 68, 80),
		outdoorAmbient = Color3.fromRGB(70, 72, 90),
		fogStart = 40,
		fogEnd = 700,
		fogColor = Color3.fromRGB(20, 22, 30),
		density = 0.35,
		haze = 2,
		glare = 0,
		atmosphereColor = Color3.fromRGB(60, 66, 85),
		decay = Color3.fromRGB(35, 35, 50),
		saturation = -0.45,
		contrast = 0.18,
		tint = Color3.fromRGB(228, 236, 255),
		bloom = 0.6,
		bloomSize = 24,
		bloomThreshold = 1.2,
		rain = 0.6,
		lightning = true,
	}),
	TokyoDistrict = preset({
		clockTime = 0,
		brightness = 0.7,
		exposure = 0.05,
		ambient = Color3.fromRGB(62, 60, 78),
		outdoorAmbient = Color3.fromRGB(70, 66, 92),
		fogStart = 50,
		fogEnd = 650,
		fogColor = Color3.fromRGB(22, 18, 34),
		density = 0.38,
		haze = 2.2,
		glare = 0.2,
		atmosphereColor = Color3.fromRGB(80, 60, 100),
		decay = Color3.fromRGB(60, 30, 60),
		saturation = -0.3,
		contrast = 0.22,
		tint = Color3.fromRGB(240, 232, 255),
		bloom = 1,
		bloomSize = 32,
		bloomThreshold = 0.9,
		rain = 1,
		lightning = true,
	}),
} :: { [string]: Preset }

-- The preset for a venue ("lobby", "map", "meeting"); map presets need the map id.
function LightingPresets.pick(venue: string, mapId: string?): Preset
	if venue == "meeting" then
		return LightingPresets.meeting
	elseif venue == "map" then
		return LightingPresets.maps[mapId or ""] or LightingPresets.maps.TaskForceHQ
	end
	return LightingPresets.lobby
end

return LightingPresets
