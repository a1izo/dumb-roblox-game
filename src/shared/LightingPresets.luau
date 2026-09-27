--!strict
-- The look of the game: "noir night". Cold moonlight, warm lamps that cast hard shadows, deep
-- blacks, a slightly washed-out grade and a little haze; bloom only on real light sources
-- (its threshold sits above lit skin, so avatars never glow), red kept for what matters.
--
-- Two layers make the final look, blended by the client (World/LightingController):
--   * a venue preset: the lobby, the meeting room and each map;
--   * a phase mood on top: strong, but always blended slowly. The Grimoire phase falls
--     near-black and red, the meeting gets a harsh cold light over the table, the vote
--     darkens while red creeps in, the verdict and the ending black out around the
--     cutscene's spotlight.
-- resolve() combines them (and the Low graphics setting) into the values to apply.

local LightingPresets = {}

export type Preset = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	envDiffuse: number,
	envSpecular: number,
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
	-- the venue's own lamps: brightness and reach, and how many of the strongest cast shadows
	lamps: number,
	lampRange: number,
	keyLights: number,
	-- weather: 0 = none, 1 = downpour
	rain: number,
	lightning: boolean,
}

export type Mood = {
	exposure: number, -- added
	brightness: number, -- times the preset's
	ambient: number, -- times the preset's ambient colours
	saturation: number, -- added
	contrast: number, -- added
	tint: Color3, -- the grade leans towards this colour...
	tintAmount: number, -- ...by this much (0 to 1)
	fog: number, -- times the fog distances
	density: number, -- added to the haze
	bloom: number, -- times the bloom
	key: number, -- times the key lamps (the ones casting shadows)
	fill: number, -- times every other lamp
	vignette: number, -- darkened screen edges, 0 to 1
	-- The vote only: over the phase, the grade leans further towards this colour and darkens.
	creep: { tint: Color3, amount: number, exposure: number }?,
}

export type Look = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	envDiffuse: number,
	envSpecular: number,
	fogStart: number,
	fogEnd: number,
	fogColor: Color3,
	density: number,
	haze: number,
	glare: number,
	atmosphereColor: Color3,
	decay: Color3,
	saturation: number,
	contrast: number,
	tint: Color3,
	bloom: number,
	bloomSize: number,
	bloomThreshold: number,
	keyScale: number,
	fillScale: number,
	rangeScale: number,
	keyLights: number,
	vignette: number,
}

local rgb = Color3.fromRGB

local function preset(p: Preset): Preset
	return p
end

-- Venues -------------------------------------------------------------------------------------

-- The lobby: a lounge at night, warm lamps inside, cold windows.
LightingPresets.lobby = preset({
	clockTime = 0.3,
	brightness = 1.2,
	exposure = 0.05,
	ambient = rgb(26, 24, 30),
	outdoorAmbient = rgb(40, 44, 60),
	envDiffuse = 0.45,
	envSpecular = 0.35,
	fogStart = 80,
	fogEnd = 900,
	fogColor = rgb(14, 15, 22),
	density = 0.26,
	haze = 1.1,
	glare = 0,
	atmosphereColor = rgb(60, 64, 86),
	decay = rgb(40, 32, 44),
	saturation = -0.18,
	contrast = 0.16,
	tint = rgb(255, 244, 232),
	bloom = 0.35,
	bloomSize = 18,
	bloomThreshold = 2.2,
	lamps = 1,
	lampRange = 1,
	keyLights = 4,
	rain = 0.35,
	lightning = false,
})

-- The meeting room: one hard key light over the table, everything else falls away.
LightingPresets.meeting = preset({
	clockTime = 0,
	brightness = 0.4,
	exposure = -0.1,
	ambient = rgb(22, 22, 28),
	outdoorAmbient = rgb(20, 20, 26),
	envDiffuse = 0.35,
	envSpecular = 0.3,
	fogStart = 60,
	fogEnd = 900,
	fogColor = rgb(10, 9, 12),
	density = 0.18,
	haze = 0.4,
	glare = 0,
	atmosphereColor = rgb(40, 34, 42),
	decay = rgb(40, 22, 26),
	saturation = -0.4,
	contrast = 0.28,
	tint = rgb(240, 238, 244),
	bloom = 0.3,
	bloomSize = 16,
	bloomThreshold = 2.4,
	lamps = 1,
	lampRange = 1,
	keyLights = 3,
	rain = 0,
	lightning = false,
})

LightingPresets.maps = {
	-- Agency HQ: an office after hours. Moonlight through the windows, desk lamps, rain.
	TaskForceHQ = preset({
		clockTime = 0,
		brightness = 1.1,
		exposure = 0,
		ambient = rgb(30, 32, 40),
		outdoorAmbient = rgb(42, 48, 66),
		envDiffuse = 0.45,
		envSpecular = 0.35,
		fogStart = 100,
		fogEnd = 1400,
		fogColor = rgb(12, 13, 19),
		density = 0.24,
		haze = 0.9,
		glare = 0,
		atmosphereColor = rgb(58, 64, 86),
		decay = rgb(30, 30, 44),
		saturation = -0.28,
		contrast = 0.2,
		tint = rgb(232, 238, 255),
		bloom = 0.35,
		bloomSize = 18,
		bloomThreshold = 2.2,
		-- The office has many overlapping ceiling lamps: fewer and weaker, a few strong keys.
		lamps = 0.85,
		lampRange = 0.9,
		keyLights = 6,
		rain = 0.7,
		lightning = true,
	}),
	-- University Campus: a moonlit quad, warm lamp posts, mist between the buildings.
	UniversityCampus = preset({
		clockTime = 23.8,
		brightness = 1.6,
		exposure = 0.05,
		ambient = rgb(30, 32, 42),
		outdoorAmbient = rgb(58, 64, 86),
		envDiffuse = 0.5,
		envSpecular = 0.4,
		fogStart = 40,
		fogEnd = 650,
		fogColor = rgb(18, 20, 30),
		density = 0.32,
		haze = 1.8,
		glare = 0,
		atmosphereColor = rgb(62, 70, 92),
		decay = rgb(36, 36, 54),
		saturation = -0.3,
		contrast = 0.18,
		tint = rgb(228, 236, 255),
		bloom = 0.4,
		bloomSize = 20,
		bloomThreshold = 2.1,
		lamps = 1.1,
		lampRange = 1,
		keyLights = 6,
		rain = 0.6,
		lightning = true,
	}),
	-- Tokyo District: neon night in the rain, but readable. A violet night glow fills the
	-- streets so nothing is pitch black, lamps and shop windows make the pools of light, and the
	-- haze is thin enough to see down the long avenues of a big map.
	-- A readable night: the ambient alone keeps an unlit alley legible; the light comes from real
	-- fixtures (street lights, shopfronts, signs, lanterns). The haze and the fog (the night sky's
	-- own violet) swallow the city's far skyline, so there is no edge to see.
	TokyoDistrict = preset({
		clockTime = 0,
		brightness = 1.5,
		exposure = 0.4,
		ambient = rgb(80, 72, 102),
		outdoorAmbient = rgb(112, 102, 142),
		envDiffuse = 0.65,
		envSpecular = 0.5,
		fogStart = 110,
		fogEnd = 720,
		fogColor = rgb(40, 32, 58),
		density = 0.3,
		haze = 2.2,
		glare = 0.1,
		atmosphereColor = rgb(110, 86, 140),
		decay = rgb(70, 40, 80),
		saturation = -0.05,
		contrast = 0.14,
		tint = rgb(242, 236, 255),
		bloom = 0.5,
		bloomSize = 24,
		bloomThreshold = 1.9,
		lamps = 1,
		lampRange = 1,
		keyLights = 6,
		rain = 0.7,
		lightning = true,
	}),
	-- Under Tokyo: the station hall and the metro. Cool and dim like a real platform at night,
	-- lit by its fluorescent fittings alone; the street's glow and rain stay up top. Picked by
	-- the camera being inside the map's "look zone" boxes (SceneBuilder), not by map id.
	TokyoDistrict_Under = preset({
		clockTime = 0,
		brightness = 0.4,
		exposure = 0,
		ambient = rgb(34, 36, 44),
		outdoorAmbient = rgb(34, 36, 44),
		envDiffuse = 0.3,
		envSpecular = 0.3,
		fogStart = 80,
		fogEnd = 500,
		fogColor = rgb(20, 22, 28),
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(60, 64, 76),
		decay = rgb(40, 42, 50),
		saturation = -0.1,
		contrast = 0.12,
		tint = rgb(236, 242, 255),
		bloom = 0.2,
		bloomSize = 12,
		bloomThreshold = 2.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 4,
		rain = 0,
		lightning = false,
	}),
	-- Inside Tokyo's shops and rooms: the street's exposure and bloom would blow their lit walls
	-- out to white, so indoors the camera takes a plainer look, a step darker than the street.
	-- Picked by the interiors' look zones, like the metro's.
	TokyoDistrict_Inside = preset({
		clockTime = 0,
		brightness = 0.8,
		exposure = 0,
		ambient = rgb(58, 54, 70),
		outdoorAmbient = rgb(70, 66, 90),
		envDiffuse = 0.35,
		envSpecular = 0.3,
		fogStart = 120,
		fogEnd = 720,
		fogColor = rgb(40, 32, 58),
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(110, 86, 140),
		decay = rgb(70, 40, 80),
		saturation = -0.05,
		contrast = 0.12,
		tint = rgb(246, 240, 250),
		bloom = 0.2,
		bloomSize = 14,
		bloomThreshold = 2.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 4,
		rain = 0,
		lightning = false,
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

-- Phase moods ---------------------------------------------------------------------------------

local WHITE = Color3.new(1, 1, 1)

local function mood(overrides: { [string]: any }): Mood
	local m: { [string]: any } = {
		exposure = 0,
		brightness = 1,
		ambient = 1,
		saturation = 0,
		contrast = 0,
		tint = WHITE,
		tintAmount = 0,
		fog = 1,
		density = 0,
		bloom = 1,
		key = 1,
		fill = 1,
		vignette = 0.2,
	}
	for key, value in pairs(overrides) do
		m[key] = value
	end
	return m :: any
end

LightingPresets.NEUTRAL = mood({})

-- Keyed by phase id ("DeathNote" is the Grimoire phase), plus the two endings.
LightingPresets.moods = {
	DeathNote = mood({
		exposure = -0.9,
		brightness = 0.3,
		ambient = 0.3,
		saturation = -0.35,
		contrast = 0.25,
		tint = rgb(255, 96, 96),
		tintAmount = 0.55,
		fog = 0.35,
		density = 0.18,
		key = 0.4,
		fill = 0.2,
		vignette = 0.85,
	}),
	Meeting = mood({
		exposure = 0.05,
		brightness = 0.6,
		ambient = 0.45,
		saturation = -0.2,
		contrast = 0.18,
		tint = rgb(205, 222, 255),
		tintAmount = 0.55,
		bloom = 0.8,
		key = 1.5,
		fill = 0.35,
		vignette = 0.6,
	}),
	Vote = mood({
		exposure = -0.25,
		brightness = 0.4,
		ambient = 0.3,
		saturation = -0.25,
		contrast = 0.24,
		tint = rgb(205, 222, 255),
		tintAmount = 0.4,
		key = 1.25,
		fill = 0.22,
		vignette = 0.75,
		creep = { tint = rgb(255, 70, 70), amount = 0.6, exposure = -0.35 },
	}),
	Verdict = mood({
		exposure = -1.4,
		brightness = 0.1,
		ambient = 0.08,
		saturation = -0.5,
		contrast = 0.35,
		fog = 0.5,
		key = 0.12,
		fill = 0.04,
		vignette = 1,
	}),
	OutroHand = mood({
		exposure = -0.8,
		brightness = 0.2,
		ambient = 0.15,
		saturation = -0.15,
		contrast = 0.35,
		tint = rgb(255, 64, 64),
		tintAmount = 0.7,
		key = 0.25,
		fill = 0.08,
		vignette = 1,
	}),
	OutroAgency = mood({
		exposure = -0.4,
		brightness = 0.8,
		ambient = 0.35,
		saturation = -0.75,
		contrast = 0.25,
		tint = rgb(236, 244, 255),
		tintAmount = 0.8,
		key = 0.5,
		fill = 0.2,
		vignette = 0.8,
	}),
} :: { [string]: Mood }

-- The mood for a phase id (the ending needs the winning side: "Kira" or "Team").
function LightingPresets.moodFor(phase: string, winner: string?): Mood
	if phase == "Outro" then
		return if winner == "Team" then LightingPresets.moods.OutroAgency else LightingPresets.moods.OutroHand
	end
	return LightingPresets.moods[phase] or LightingPresets.NEUTRAL
end

-- Resolving ----------------------------------------------------------------------------------

local function scaled(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

export type Options = {
	low: boolean?, -- the Low graphics setting
	progress: number?, -- how far through the phase (0 to 1), for moods that creep
}

-- The values to apply for a venue preset under a mood.
function LightingPresets.resolve(p: Preset, m: Mood, options: Options?): Look
	local o = options or {}
	local low = o.low == true
	local tint = p.tint:Lerp(m.tint, math.clamp(m.tintAmount, 0, 1))
	local exposure = p.exposure + m.exposure
	local creep = m.creep
	if creep then
		local t = math.clamp(o.progress or 0, 0, 1)
		tint = tint:Lerp(creep.tint, creep.amount * t)
		exposure += creep.exposure * t
	end
	return {
		clockTime = p.clockTime,
		brightness = p.brightness * m.brightness,
		exposure = exposure,
		ambient = scaled(p.ambient, m.ambient),
		outdoorAmbient = scaled(p.outdoorAmbient, m.ambient),
		envDiffuse = p.envDiffuse,
		envSpecular = p.envSpecular,
		fogStart = p.fogStart * m.fog,
		fogEnd = p.fogEnd * m.fog,
		fogColor = p.fogColor,
		density = math.clamp((p.density + m.density) * (if low then 0.6 else 1), 0, 1),
		haze = if low then 0 else p.haze,
		glare = if low then 0 else p.glare,
		atmosphereColor = p.atmosphereColor,
		decay = p.decay,
		saturation = math.clamp(p.saturation + m.saturation, -1, 1),
		contrast = math.clamp(p.contrast + m.contrast, -1, 1),
		tint = tint,
		bloom = if low then 0 else p.bloom * m.bloom,
		bloomSize = p.bloomSize,
		bloomThreshold = p.bloomThreshold,
		keyScale = p.lamps * m.key,
		fillScale = p.lamps * m.fill,
		rangeScale = p.lampRange * (if low then 0.8 else 1),
		keyLights = if low then math.min(2, p.keyLights) else p.keyLights,
		vignette = m.vignette,
	}
end

return LightingPresets
