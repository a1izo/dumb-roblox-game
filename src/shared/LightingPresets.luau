--!strict
-- The look of the game: "noir night". Cold moonlight, warm lamps that cast hard shadows, deep
-- blacks, a slightly washed-out grade and a little haze; bloom only on real light sources
-- (its threshold sits above lit skin, so avatars never glow), red kept for what matters.
--
-- Two layers make the final look, blended by the client (World/LightingController):
--   * a venue preset: the lobby, the meeting room and each map;
--   * a phase mood on top: strong, but always blended slowly. A blackout falls near-black
--     and red, the meeting gets a harsh cold light over the table, the vote
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
	-- weather: 0 = none, 1 = downpour; snow likewise (0 = none, 1 = a blizzard)
	rain: number,
	lightning: boolean,
	snow: number,
	-- The Grey Realm's sky: no moon or stars, and the layered moving clouds (World/RealmSky).
	realmSky: boolean?,
	-- Where the sun should stand (a direction from the world's middle): the clock and latitude that put it nearest are
	-- searched for (World/LightingController), and it shows as a great soft glow. Nil: the clock alone places it, and a
	-- realm sky shows none.
	sunAim: Vector3?,
	-- A map's own overcast sky: the six faces Sky<name>Ft..Dn (art/scripts/skies.py, carried in its FBX).
	-- Under it there are no stars and no moon's disc; the moon is only a dim cold light through the cloud.
	sky: string?,
}

export type Mood = {
	exposure: number, -- added
	brightness: number, -- times the preset's
	ambient: number, -- times the preset's ambient colours
	saturation: number, -- added
	contrast: number, -- added
	tint: Color3, -- the grade leans towards this colour...
	tintAmount: number, -- ...by this much (0 to 1)
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
	sky: string?,
	realmSky: boolean,
	sunAim: Vector3?,
}

local rgb = Color3.fromRGB

local function preset(p: Preset): Preset
	return p
end

-- Venues -------------------------------------------------------------------------------------

-- The lobby: the Grey Realm (remade 2026-11-04 to the user's reference videos), a flat grey wasteland under one
-- blinding glow low in the north: the sun stands there as a great soft disc, the haze brightening to white round it
-- and falling to near-black away from it, so whatever stands between you and it is a dark silhouette against the light
-- (from the spawn, the throne on its rock). The ground stays a deep dusk (the calls of 2026-10-06 and 2026-10-10: dark,
-- with the ground ahead still easy to see and pools of pale light where people gather); almost no colour left. The
-- clouds and their slow breathing are World/RealmSky's; these are the values it breathes around.
LightingPresets.lobby = preset({
	clockTime = 14.5,
	brightness = 1.3,
	exposure = -0.3,
	ambient = rgb(56, 60, 67),
	outdoorAmbient = rgb(70, 74, 82),
	envDiffuse = 0.5,
	envSpecular = 0.3,
	density = 0.36,
	haze = 2.1,
	glare = 1.5,
	atmosphereColor = rgb(176, 178, 184),
	decay = rgb(30, 32, 38),
	saturation = -0.78,
	contrast = 0.16,
	tint = rgb(212, 218, 230),
	bloom = 0.25,
	bloomSize = 18,
	bloomThreshold = 2.2,
	lamps = 1,
	lampRange = 1,
	keyLights = 3,
	rain = 0,
	lightning = false,
	snow = 0,
	realmSky = true,
	sunAim = Vector3.new(0, math.sin(math.rad(8)), -math.cos(math.rad(8))),
})

-- A dive into the rift, under the cloud the realm floats on: the night over Kagegaoka. Still no sun (the cloud
-- is overhead) and the hour is the realm's (it never changes mid-fall); the light is the city's, from far
-- below, cool and dim. A dark haze closes the far horizons, so neither the cloud deck's edge nor the
-- city's is seen; the cloud's lobes overhead stand out a little paler than the deck. A touch of colour
-- comes back (the warm windows far down). Set by World/LightingController from the camera's depth.
-- (2026-11-05, "a black screen after you jump in": the haze was 0.4 thick and near black while the city lies 620 studs
-- under the cloud, so for most of the fall the city could drown in it and leave the screen black until the last
-- stretch. Thinner and a shade lighter, so the streets' lamps and the lit windows show from the cloud down.)
LightingPresets.lobbyBelow = preset({
	clockTime = 14.5,
	brightness = 0.35,
	exposure = -0.15,
	ambient = rgb(46, 48, 60),
	outdoorAmbient = rgb(58, 56, 70),
	envDiffuse = 0.4,
	envSpecular = 0.3,
	density = 0.26,
	haze = 1.3,
	glare = 0,
	atmosphereColor = rgb(40, 40, 56),
	decay = rgb(52, 40, 40),
	saturation = -0.5,
	contrast = 0.18,
	tint = rgb(214, 218, 232),
	bloom = 0.35,
	bloomSize = 20,
	bloomThreshold = 2.0,
	lamps = 1,
	lampRange = 1,
	keyLights = 3,
	rain = 0,
	lightning = false,
	snow = 0,
	realmSky = true,
})

-- The last stretch of a dive, nearing the city: the haze thins, so the roof coming up is sharp.
LightingPresets.lobbyCity = preset({
	clockTime = 14.5,
	brightness = 0.35,
	exposure = -0.1,
	ambient = rgb(52, 50, 60),
	outdoorAmbient = rgb(64, 60, 70),
	envDiffuse = 0.4,
	envSpecular = 0.3,
	density = 0.18,
	haze = 0.9,
	glare = 0,
	atmosphereColor = rgb(40, 38, 52),
	decay = rgb(56, 42, 40),
	saturation = -0.42,
	contrast = 0.18,
	tint = rgb(218, 220, 232),
	bloom = 0.4,
	bloomSize = 20,
	bloomThreshold = 2.0,
	lamps = 1,
	lampRange = 1,
	keyLights = 3,
	rain = 0,
	lightning = false,
	snow = 0,
	realmSky = true,
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
	snow = 0,
})

LightingPresets.maps = {
	-- Agency HQ: the Agency's floors high in a tower, after hours, lit as noir (the owner, 2026-11-01): warm amber
	-- pools under the fittings over the desks and stations, the walkways between them a cold blue-grey that still
	-- shows a body and, up close, a face. Desk lamps, monitors and the city's glow through the glass do the rest. The
	-- haze is thin, so Kagegaoka's lights 440 studs down still show, fading into a violet night towards the horizon;
	-- rain streams down the glass, and lightning comes in through it (World/Lightning).
	TaskForceHQ = preset({
		clockTime = 0,
		brightness = 1.2,
		exposure = 0.15,
		-- (the fill turned right down, seen in a play test at full quality, 2026-11-02: at 44, 49, 66 it lit every
		-- surface evenly and the rooms read flat; this low, the lamps' pools are the light and a corner still reads)
		ambient = rgb(22, 24, 36),
		outdoorAmbient = rgb(26, 29, 44),
		envDiffuse = 0.2,
		envSpecular = 0.4,
		density = 0.22,
		haze = 1.7,
		glare = 0.05,
		atmosphereColor = rgb(84, 74, 118),
		decay = rgb(52, 40, 76),
		saturation = -0.08,
		contrast = 0.2,
		tint = rgb(255, 246, 236),
		bloom = 0.7,
		bloomSize = 26,
		-- (2.2, seen in a play test at full quality, 2026-11-06: pale skin under the brightest pool glowed at 1.5
		-- and still at 1.8 and was clean at 2.2; the fittings keep their glow, lit white surfaces lose their halo)
		bloomThreshold = 2.2,
		lamps = 1,
		lampRange = 1,
		keyLights = 6,
		rain = 0.7,
		lightning = true,
		snow = 0,
		sky = "Agency",
	}),
	-- University Campus: the eve of the entrance exam, a winter night in light snow. Low snow
	-- clouds glow a faint orange with the city's light and the snow on the ground throws the warm
	-- lamps, heaters and windows back up, while the shadows stay a cold blue. The ambient keeps an
	-- unlit corner legible, and the haze is thin enough to see from the gate to the clock tower.
	UniversityCampus = preset({
		-- (noir, tuned in a Studio play test at full quality through the player's own camera, 2026-11-02: the fill and
		-- the moon lit every surface evenly; turned down, the lamps, windows and neon carve the night)
		clockTime = 0,
		brightness = 0.6,
		exposure = 0.1,
		ambient = rgb(24, 27, 38),
		outdoorAmbient = rgb(38, 42, 60),
		envDiffuse = 0.25,
		envSpecular = 0.4,
		density = 0.4,
		haze = 2.2,
		glare = 0,
		atmosphereColor = rgb(116, 106, 116),
		decay = rgb(92, 70, 64),
		saturation = -0.12,
		contrast = 0.2,
		tint = rgb(246, 240, 244),
		bloom = 0.45,
		bloomSize = 22,
		bloomThreshold = 1.9,
		lamps = 1,
		lampRange = 1,
		keyLights = 6,
		rain = 0,
		lightning = false,
		snow = 0.85,
		sky = "Campus",
	}),
	-- Inside the campus buildings: a plainer look a step darker than the snow outside, so lit
	-- plaster and tiles never blow out. The snow stays at the outdoor amount: the flakes stop
	-- under the roof on their own, the wind is heard muffled, and footprints keep appearing on
	-- the lawns seen through the windows. Picked by the interiors' look zones.
	UniversityCampus_Inside = preset({
		-- (noir, tuned in a Studio play test at full quality through the player's own camera, 2026-11-02: the fill and
		-- the moon lit every surface evenly; turned down, the lamps, windows and neon carve the night)
		clockTime = 0,
		brightness = 0.5,
		exposure = 0,
		ambient = rgb(18, 18, 26),
		outdoorAmbient = rgb(24, 24, 34),
		envDiffuse = 0.15,
		envSpecular = 0.3,
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(124, 104, 100),
		decay = rgb(92, 70, 64),
		saturation = -0.08,
		contrast = 0.2,
		tint = rgb(248, 242, 238),
		bloom = 0.2,
		bloomSize = 14,
		bloomThreshold = 2.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 4,
		rain = 0,
		lightning = false,
		snow = 0.85,
		sky = "Campus",
	}),
	-- Tokyo District: neon night in the rain, but readable. A violet night glow fills the
	-- streets so nothing is pitch black, lamps and shop windows make the pools of light, and the
	-- haze is thin enough to see down the long avenues of a big map.
	-- A readable night: the ambient alone keeps an unlit alley legible; the light comes from real
	-- fixtures (street lights, shopfronts, signs, lanterns). The city runs on past the map to the
	-- haze (the night sky's own violet), which swallows its far skyline, so there is no edge to
	-- see; low down the haze takes the warm glow of a city's lights.
	TokyoDistrict = preset({
		-- (noir, tuned in a Studio play test at full quality through the player's own camera, 2026-11-02: the fill and
		-- the moon lit every surface evenly; turned down, the lamps, windows and neon carve the night)
		clockTime = 0,
		brightness = 0.45,
		exposure = 0.1,
		ambient = rgb(26, 24, 40),
		outdoorAmbient = rgb(42, 38, 62),
		envDiffuse = 0.25,
		envSpecular = 0.6,
		density = 0.4,
		haze = 3.3,
		glare = 0.1,
		atmosphereColor = rgb(98, 88, 140),
		decay = rgb(132, 66, 74),
		saturation = -0.05,
		contrast = 0.2,
		tint = rgb(242, 236, 255),
		bloom = 0.5,
		bloomSize = 24,
		bloomThreshold = 1.9,
		lamps = 1,
		lampRange = 1,
		keyLights = 6,
		rain = 1,
		lightning = true,
		snow = 0,
		sky = "Tokyo",
	}),
	-- Under Tokyo: the station hall and the metro. Cool and dim like a real platform at night,
	-- lit by its fluorescent fittings alone; the street's glow and rain stay up top. Picked by
	-- the camera being inside the map's "look zone" boxes (SceneBuilder), not by map id.
	TokyoDistrict_Under = preset({
		-- (noir, tuned in a Studio play test at full quality through the player's own camera, 2026-11-02: the fill and
		-- the moon lit every surface evenly; turned down, the lamps, windows and neon carve the night)
		clockTime = 0,
		brightness = 0.4,
		exposure = 0,
		ambient = rgb(20, 22, 28),
		outdoorAmbient = rgb(20, 22, 28),
		envDiffuse = 0.2,
		envSpecular = 0.3,
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(60, 64, 76),
		decay = rgb(40, 42, 50),
		saturation = -0.1,
		contrast = 0.18,
		tint = rgb(236, 242, 255),
		bloom = 0.2,
		bloomSize = 12,
		bloomThreshold = 2.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 4,
		rain = 1,
		lightning = false,
		snow = 0,
		sky = "Tokyo",
	}),
	-- Inside Tokyo's shops and rooms: the street's exposure and bloom would blow their lit walls
	-- out to white, so indoors the camera takes a plainer look, a step darker than the street.
	-- Picked by the interiors' look zones, like the metro's.
	TokyoDistrict_Inside = preset({
		-- (noir, tuned in a Studio play test at full quality through the player's own camera, 2026-11-02: the fill and
		-- the moon lit every surface evenly; turned down, the lamps, windows and neon carve the night)
		clockTime = 0,
		brightness = 0.5,
		exposure = 0,
		ambient = rgb(18, 17, 26),
		outdoorAmbient = rgb(24, 22, 34),
		envDiffuse = 0.15,
		envSpecular = 0.3,
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(110, 86, 140),
		decay = rgb(70, 40, 80),
		saturation = -0.05,
		contrast = 0.2,
		tint = rgb(246, 240, 250),
		bloom = 0.2,
		bloomSize = 14,
		bloomThreshold = 2.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 4,
		rain = 1,
		lightning = false,
		snow = 0,
		sky = "Tokyo",
	}),
} :: { [string]: Preset }

-- The preset for a venue ("lobby", "map", "meeting"); map presets need the map id.
-- The cutscene sets: night interiors lit only by what is in them (a desk lamp, candles, monitors, the
-- moon through a skylight). Very little ambient so the dark stays dark, no fog to speak of (the rooms are
-- small), a touch more bloom for the flames and screens.
LightingPresets.sets = preset({
	clockTime = 0,
	brightness = 0.2,
	exposure = 0,
	ambient = rgb(14, 14, 18),
	outdoorAmbient = rgb(16, 18, 26),
	envDiffuse = 0.25,
	envSpecular = 0.35,
	fogStart = 200,
	fogEnd = 1200,
	fogColor = rgb(8, 8, 12),
	density = 0.05,
	haze = 0,
	glare = 0,
	atmosphereColor = rgb(30, 30, 40),
	decay = rgb(20, 18, 24),
	saturation = -0.2,
	contrast = 0.3,
	tint = rgb(244, 240, 236),
	bloom = 0.45,
	bloomSize = 20,
	bloomThreshold = 1.8,
	lamps = 1,
	lampRange = 1,
	keyLights = 3,
	rain = 0,
	lightning = false,
	snow = 0,
})

-- The scene deaths' own looks (Presentation/SceneDeaths, set while one plays: World/LightingController.scene), each lit
-- like a map of its own: its sky (art/scripts/scene_skies.py), its sun aimed where the sky's glow is, its mist and its
-- grade. Asked 2026-11-08 after the first sets: "why are the scenarios so low quality?" (they had been lit by whatever
-- map look the far-off camera fell in, then pushed brighter in the grade until faces blew out).
local function scene(overrides: { [string]: any }): Preset
	local p: { [string]: any } = {
		clockTime = 0,
		brightness = 0,
		exposure = 0,
		ambient = rgb(30, 30, 34),
		outdoorAmbient = rgb(30, 30, 34),
		envDiffuse = 0.4,
		envSpecular = 0.4,
		density = 0,
		haze = 0,
		glare = 0,
		atmosphereColor = rgb(120, 120, 130),
		decay = rgb(60, 60, 70),
		saturation = 0,
		contrast = 0.1,
		tint = rgb(255, 255, 255),
		bloom = 0.35,
		bloomSize = 22,
		bloomThreshold = 1.6,
		lamps = 1,
		lampRange = 1,
		keyLights = 2,
		rain = 0,
		lightning = false,
		snow = 0,
	}
	for key, value in pairs(overrides) do
		p[key] = value
	end
	return p :: any
end

local function aim(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z).Unit
end

LightingPresets.scenes = {
	-- A military cemetery in a sunlit morning mist: the sun low at the upper left behind the saluter (rim light, the
	-- mist glowing round it), soft cream fill, the rows fading into the mist.
	patriot = scene({
		clockTime = 9,
		sunAim = aim(0.42, 0.4, 0.81),
		brightness = 1.4,
		exposure = -0.1,
		ambient = rgb(118, 116, 110),
		outdoorAmbient = rgb(150, 146, 136),
		envDiffuse = 0.6,
		envSpecular = 0.3,
		density = 0.42,
		haze = 2.2,
		glare = 0.9,
		atmosphereColor = rgb(228, 224, 212),
		decay = rgb(196, 188, 172),
		saturation = -0.32,
		contrast = 0.06,
		tint = rgb(255, 247, 232),
		bloom = 0.35,
		bloomSize = 30,
		bloomThreshold = 1.4,
		sky = "SceneMist",
	}),
	-- An underground car park: fluorescent fittings only, a warm haze hanging under the soffit.
	blackwall = scene({
		ambient = rgb(44, 44, 42),
		outdoorAmbient = rgb(30, 30, 30),
		density = 0.3,
		atmosphereColor = rgb(126, 122, 104),
		decay = rgb(70, 66, 56),
		contrast = 0.12,
		tint = rgb(255, 246, 226),
		bloom = 0.45,
	}),
	-- The asylum's lab: cold, blue-grey, the white tiled room beyond burning under its tubes.
	walrider = scene({
		ambient = rgb(34, 40, 46),
		outdoorAmbient = rgb(30, 34, 40),
		density = 0.18,
		atmosphereColor = rgb(96, 108, 118),
		decay = rgb(50, 56, 62),
		saturation = -0.25,
		contrast = 0.16,
		tint = rgb(222, 234, 246),
		bloom = 0.5,
	}),
	-- Desert hills at dusk: the sun low and gold to the front-left of the over-the-shoulder shots, long shadows.
	sam = scene({
		clockTime = 17.5,
		sunAim = aim(0.55, 0.16, 0.82),
		brightness = 2.2,
		exposure = -0.05,
		ambient = rgb(92, 74, 60),
		outdoorAmbient = rgb(140, 108, 80),
		envDiffuse = 0.5,
		envSpecular = 0.4,
		density = 0.28,
		haze = 1.4,
		glare = 0.5,
		atmosphereColor = rgb(222, 172, 120),
		decay = rgb(150, 100, 70),
		saturation = -0.06,
		contrast = 0.12,
		tint = rgb(255, 236, 206),
		bloom = 0.3,
		sky = "SceneDusk",
	}),
	-- A battlefield's orange dusk under smoke: the sun low behind the warlord's army (silhouettes), ember fill.
	ironMan = scene({
		clockTime = 18,
		sunAim = aim(-0.28, 0.1, -0.95),
		brightness = 2.0,
		exposure = -0.05,
		ambient = rgb(78, 54, 44),
		outdoorAmbient = rgb(122, 80, 58),
		envDiffuse = 0.5,
		density = 0.34,
		haze = 1.8,
		glare = 0.6,
		atmosphereColor = rgb(210, 128, 78),
		decay = rgb(120, 60, 40),
		saturation = -0.05,
		contrast = 0.14,
		tint = rgb(255, 224, 196),
		bloom = 0.35,
		sky = "SceneEmber",
	}),
	-- A dim board room after hours: the board's glow and the city through the blinds.
	selection = scene({
		ambient = rgb(24, 26, 32),
		outdoorAmbient = rgb(20, 22, 30),
		saturation = -0.15,
		contrast = 0.18,
		tint = rgb(232, 238, 255),
		bloom = 0.4,
	}),
	-- The star void of the requiem: no sun, the nebula sky all round, violet fill.
	requiem = scene({
		clockTime = 14,
		ambient = rgb(52, 34, 78),
		outdoorAmbient = rgb(70, 46, 100),
		envDiffuse = 0.7,
		envSpecular = 0.6,
		contrast = 0.12,
		bloom = 0.6,
		bloomThreshold = 1.3,
		sky = "SceneRequiem",
	}),
	-- The Devourer's purple sky.
	god = scene({
		clockTime = 14,
		ambient = rgb(70, 40, 100),
		outdoorAmbient = rgb(90, 50, 120),
		envDiffuse = 0.7,
		envSpecular = 0.6,
		contrast = 0.1,
		bloom = 0.6,
		bloomThreshold = 1.3,
		sky = "SceneGod",
	}),
	-- sans' battle screen: black, the victim lit flat by the scene's own lamps.
	sans = scene({ ambient = rgb(0, 0, 0), outdoorAmbient = rgb(0, 0, 0), bloom = 0.2 }),
} :: { [string]: Preset }

function LightingPresets.pick(venue: string, mapId: string?): Preset
	if venue == "meeting" then
		return LightingPresets.meeting
	elseif venue == "sets" then
		return LightingPresets.sets
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

-- Keyed by phase id, plus the two endings and the blackout.
LightingPresets.moods = {
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
	-- A blackout (a Muerto's sabotage): every lamp out but the red emergency ones,
	-- the city's glow through the glass, a red cast.
	Blackout = mood({
		exposure = -1.6,
		brightness = 0.05,
		ambient = 0.06,
		saturation = -0.4,
		contrast = 0.3,
		tint = rgb(255, 80, 80),
		tintAmount = 0.25,
		key = 0,
		fill = 0,
		vignette = 0.9,
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
	low: boolean?, -- the Low graphics setting: both of the cuts below
	noGlow: boolean?, -- no bloom, haze or glare, thinner air (World/Governor's second cut)
	fewShadows: boolean?, -- at most two shadow-casting lamps, shorter lamp range (its third)
	shadows: number?, -- the Shadows setting: 0 low (as fewShadows), 1 normal (the preset's keys), 2 high (two more)
	progress: number?, -- how far through the phase (0 to 1), for moods that creep
}

-- The values to apply for a venue preset under a mood.
function LightingPresets.resolve(p: Preset, m: Mood, options: Options?): Look
	local o = options or {}
	local noGlow = o.low == true or o.noGlow == true
	local fewShadows = o.low == true or o.fewShadows == true or o.shadows == 0
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
		density = math.clamp((p.density + m.density) * (if noGlow then 0.6 else 1), 0, 1),
		haze = if noGlow then 0 else p.haze,
		glare = if noGlow then 0 else p.glare,
		atmosphereColor = p.atmosphereColor,
		decay = p.decay,
		saturation = math.clamp(p.saturation + m.saturation, -1, 1),
		contrast = math.clamp(p.contrast + m.contrast, -1, 1),
		tint = tint,
		bloom = if noGlow then 0 else p.bloom * m.bloom,
		bloomSize = p.bloomSize,
		bloomThreshold = p.bloomThreshold,
		keyScale = p.lamps * m.key,
		fillScale = p.lamps * m.fill,
		rangeScale = p.lampRange * (if fewShadows then 0.8 else 1),
		keyLights = if fewShadows
			then math.min(2, p.keyLights)
			elseif o.shadows == 2 then p.keyLights + 2
			else p.keyLights,
		vignette = m.vignette,
		sky = p.sky,
		realmSky = p.realmSky == true,
		sunAim = p.sunAim,
	}
end

return LightingPresets
