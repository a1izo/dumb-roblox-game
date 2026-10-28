--!strict
-- The swap-in registry. Every sound, animation, model and icon the game can use is listed
-- here by name. An empty id means "use the built-in fallback": silence for audio, the
-- procedural pose for animations, the part-built version for models.
--
-- To use your own assets:
--   audio / animations: upload them in Studio or on the Creator Dashboard and paste the id
--     ("rbxassetid://123..." or just the number) into the matching slot.
--   models: export them from Studio as .rbxm into assets/shared/Models (Rojo syncs that folder
--     to ReplicatedStorage.DeathsGambitAssets.Models) and name the file after the key below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

export type Audio = {
	id: string, -- your upload
	ref: string, -- the track this slot was chosen for (a note, never loaded)
	fallbackId: string, -- used while id is empty, e.g. a licensed Creator Store track
	volume: number?,
}

-- Music slots. Roblox rejects uploads of copyrighted music, so an OST pick may never get an
-- id; fill fallbackId with a licensed track from the Creator Store in that case.
Assets.music = {
	lobby = { id = "96648998822349", ref = "Black Souls: Dreaming Doll (M-ART)", fallbackId = "" },
	shop = { id = "108565494678474", ref = "Deltarune Ch.1: Hip Shop", fallbackId = "" },
	training = { id = "127948284626151", ref = "Deltarune Ch.1: Beginning", fallbackId = "" },
	intro = { id = "129636839800962", ref = "Deltarune Ch.1: The Legend", fallbackId = "" },
	revealHand = { id = "132995375905574", ref = "Deltarune Ch.1: ANOTHER HIM", fallbackId = "" },
	inv_TaskForceHQ = { id = "102705059219535", ref = "OMORI: Lost Library", fallbackId = "" },
	inv_UniversityCampus = { id = "72785505837503", ref = "Deltarune Ch.1: School", fallbackId = "" },
	inv_TokyoDistrict = { id = "77962238440490", ref = "OMORI: Underwater Highway", fallbackId = "" },
	grimoire = { id = "85538418554276", ref = "Black Souls: Grimoire (M-ART)", fallbackId = "" }, -- terms:ok (a track title)
	meeting = { id = "82941366813687", ref = "Deltarune Ch.3+4: Query?", fallbackId = "" },
	vote = { id = "90401963211160", ref = "Deltarune Ch.3+4: Black Knife", fallbackId = "" },
	specter = { id = "124751068997305", ref = "OMORI: WHITE SPACE", fallbackId = "" },
	-- The role cutscenes' music (Shared/Cinema/Shots, `sound`): a bed played quietly under each voiced line, and the
	-- Operative's scene, which has no line, its own music. Silent until filled.
	bedDiavolo = {
		id = "",
		ref = "a low, slow, ominous bed under Diavolo's chip line: a held organ or choir note, quiet, 5-10 s",
		fallbackId = "",
		volume = 0.35,
	},
	bedMuerto = {
		id = "",
		ref = "a frantic pulse under the Muerto's DELETE: a racing heartbeat or stabbing strings, quiet, 6-10 s",
		fallbackId = "",
		volume = 0.35,
	},
	bedButler = {
		id = "",
		ref = "a gentle, uneasy bed under the Butler's question: a soft piano or a music box, quiet, 5-10 s",
		fallbackId = "",
		volume = 0.35,
	},
	bedAce = {
		id = "",
		ref = "a cool, thinking bed under Ace's line: low strings or a soft synth pad, quiet, 12-16 s",
		fallbackId = "",
		volume = 0.35,
	},
	musicOperative = {
		id = "",
		ref = "the Operative's locker-room scene, 15 s: steady, resolute, a little tense (drums and low strings)",
		fallbackId = "",
		volume = 0.6,
	},
	winAgency = { id = "140524483892887", ref = "Deltarune Ch.2: Powers Combined", fallbackId = "" },
	winHand = { id = "102060777088999", ref = "Deltarune Ch.1: THE WORLD REVOLVING", fallbackId = "" },
	defeat = { id = "140524483892887", ref = "Deltarune Ch.2: Faint Courage (Game Over)", fallbackId = "" },
	results = { id = "70827276394245", ref = "Deltarune Ch.2: Until Next Time", fallbackId = "" },
} :: { [string]: Audio }

-- Sound effects. Roblox's own uploads in the Creator Store are free to use.
Assets.sfx = {
	uiClick = { id = "105603302038059", ref = "soft click", fallbackId = "" },
	uiHover = { id = "111593606306412", ref = "faint tick", fallbackId = "" },
	uiOpen = { id = "116713052791035", ref = "paper slide", fallbackId = "" },
	toast = { id = "", ref = "short chime", fallbackId = "" },
	coin = { id = "", ref = "coin chime", fallbackId = "" },
	flashChime = { id = "", ref = "monitor beep", fallbackId = "" },
	select = { id = "", ref = "short soft blip when a tab or name is picked", fallbackId = "" },
	holdTick = { id = "", ref = "rising tick while a button is held", fallbackId = "" },
	slam = { id = "", ref = "heavy impact for a big title", fallbackId = "" },
	glitch = { id = "", ref = "short videotape glitch burst", fallbackId = "" },
	stamp = { id = "", ref = "rubber stamp thud", fallbackId = "" },
	error = { id = "", ref = "low buzz for a wrong answer", fallbackId = "" },
	pageTurn = { id = "106779604003131", ref = "page turn", fallbackId = "" },
	penScratch = { id = "100606791435959", ref = "pen scratching paper", fallbackId = "" },
	heartbeat = { id = "95533664124326", ref = "single heartbeat", fallbackId = "" },
	flatline = { id = "", ref = "heart monitor flatline", fallbackId = "" },
	bell = { id = "", ref = "distant church bell", fallbackId = "" },
	gavel = { id = "", ref = "gavel strike", fallbackId = "" },
	handcuffs = { id = "126639042660804", ref = "handcuffs click", fallbackId = "" },
	clockTick = { id = "82767158332135", ref = "clock tick", fallbackId = "" },
	thunder = { id = "138702332632737", ref = "rolling thunder", fallbackId = "" },
	rainLoop = { id = "134202339842350", ref = "steady rain loop", fallbackId = "" },
	eyesOpen = { id = "", ref = "low whoosh with a whisper", fallbackId = "" },
	wisp = { id = "", ref = "soft ghostly chime", fallbackId = "" },
	-- A Deathsinger haunting the lobby.
	hauntWhisper = { id = "", ref = "a faint, breathy whisper, words not quite heard", fallbackId = "" },
	hauntMist = { id = "", ref = "a short cold gust of wind", fallbackId = "" },
	hauntFlicker = { id = "", ref = "a flame or bulb sputtering for a moment", fallbackId = "" },
	mapCityHum = { id = "81235587177208", ref = "distant city traffic hum at night, loop", fallbackId = "" },
	mapCrossingChirp = {
		id = "118593933745441",
		ref = "Japanese pedestrian crossing bird chirp, loop",
		fallbackId = "",
	},
	mapTrainArrive = { id = "134959404397926", ref = "metro train pulling into a station", fallbackId = "" },
	mapStationChime = { id = "74308843149652", ref = "Japanese station platform chime", fallbackId = "" },
	-- (the Tokyo intro's own sounds, IntroTokyo d87dcfd: slots for them, each silent until a sound is uploaded)
	tokyoStationBed = {
		id = "",
		ref = "busy Tokyo station platform: crowd murmur, footsteps, a far announcement, loop",
		fallbackId = "",
	},
	introTokyoDrone = { id = "", ref = "low ominous drone swelling under a reveal", fallbackId = "" },
	bookShut = { id = "", ref = "a heavy leather book snapped shut", fallbackId = "" },
	doorRiser = { id = "", ref = "tension riser as train doors close", fallbackId = "" },
	mapRiver = { id = "96847503564877", ref = "gentle canal water flowing, loop", fallbackId = "" },
	mapLanternCreak = { id = "91834117633575", ref = "paper lanterns creaking in a light wind, loop", fallbackId = "" },
	mapIzakaya = { id = "113237103762830", ref = "muffled bar chatter and clinking glasses, loop", fallbackId = "" },
	mapOfficeHum = { id = "", ref = "empty office at night: air conditioning hum, loop", fallbackId = "" },
	mapRainGlass = { id = "", ref = "heavy rain against a tall window, loop", fallbackId = "" },
	mapServerHum = { id = "", ref = "server room fans and hum, loop", fallbackId = "" },
	mapPhoneRing = { id = "", ref = "an office desk phone ringing unanswered, loop", fallbackId = "" },
	mapSirenFar = { id = "", ref = "distant police siren across a city at night, loop", fallbackId = "" },
	mapHelicopter = { id = "", ref = "helicopter passing overhead, rotor loop", fallbackId = "" },
	mapWindSnow = { id = "", ref = "soft winter wind with light snow falling, loop", fallbackId = "" },
	mapHeaterHum = { id = "", ref = "kerosene heater burning, a low hum and tick, loop", fallbackId = "" },
	mapTowerBell = { id = "", ref = "one stroke of a large clock-tower bell, ringing out", fallbackId = "" },
	-- Bureau HQ's blackout and Tokyo's scramble (empty = silent until the owner picks the sounds).
	mapBreakerClunk = { id = "", ref = "a heavy electrical breaker lever thrown, one clunk", fallbackId = "" },
	mapPowerDown = {
		id = "",
		ref = "an office building's power dying: hum winding down, lights ticking off",
		fallbackId = "",
	},
	mapPowerUp = { id = "", ref = "power coming back: a hum rising, fluorescent tubes flickering on", fallbackId = "" },
	mapCarHorn = { id = "", ref = "a city car's short horn blast", fallbackId = "" },
	mapCarPass = { id = "", ref = "a car passing over a wet street at low speed", fallbackId = "" },
	mapPianoFar = { id = "", ref = "an upright piano practising down a corridor, muffled, loop", fallbackId = "" },
	mapNewsRadio = { id = "", ref = "a late-night news radio murmuring in an empty room, loop", fallbackId = "" },
	mapWindWaste = { id = "", ref = "a dry wind moaning across an empty desert of ash, loop", fallbackId = "" },
	mapRiftHum = { id = "", ref = "a deep, hollow drone rising out of a chasm, loop", fallbackId = "" },
	-- The Grey Realm's soundscape (art/audio/*.wav made by art/scripts/audio/make_realm_audio.py): three
	-- beds that never stop, wind through rocks at the vistas, and one-shots that come now and then from a
	-- long way off (World: Audio/RealmAmbience). Keep every one of them quiet.
	realmWind = {
		id = "81281007740259",
		ref = "a low, distant wind over an empty plain, slowly swelling, loop",
		fallbackId = "",
		volume = 0.5,
	},
	realmDrone = {
		id = "89104975703515",
		ref = "a very quiet, low atmospheric drone, loop",
		fallbackId = "",
		volume = 0.4,
	},
	realmRumble = {
		id = "127322146464393",
		ref = "an extremely subtle sub-bass rumble far below, loop",
		fallbackId = "",
		volume = 0.35,
	},
	realmRocks = {
		id = "101313581641395",
		ref = "wind passing through rock spires, a thin whistle, loop",
		fallbackId = "",
		volume = 0.5,
	},
	realmStone1 = {
		id = "91873565864565",
		ref = "a distant stone knock, as if a rock settled, one shot",
		fallbackId = "",
		volume = 0.6,
	},
	realmStone2 = {
		id = "118474779230622",
		ref = "a far-off rumble of loose scree sliding, one shot",
		fallbackId = "",
		volume = 0.6,
	},
	realmMetal1 = {
		id = "84904237384867",
		ref = "a faint distant metallic creak, one shot",
		fallbackId = "",
		volume = 0.5,
	},
	realmMetal2 = {
		id = "79290663643407",
		ref = "a far, hollow metallic tone, like a chain moving, one shot",
		fallbackId = "",
		volume = 0.5,
	},
	realmFar1 = {
		id = "98704419870158",
		ref = "a barely heard whisper on the wind, one shot",
		fallbackId = "",
		volume = 0.4,
	},
	realmFar2 = {
		id = "99801583005502",
		ref = "a distant, unplaceable breath of sound, one shot",
		fallbackId = "",
		volume = 0.4,
	},
	-- The lobby mini-games.
	gameRune = {
		id = "98148194967745",
		ref = "a soft, glassy single tone, played at different pitches, one shot",
		fallbackId = "",
	},
	gameWrong = { id = "127414524135377", ref = "a dull low stone thud, one shot", fallbackId = "" },
	gameCheckpoint = { id = "101303238513813", ref = "a pale bell tone, short, one shot", fallbackId = "" },
	gameFinish = { id = "111390306276390", ref = "two soft bell tones rising, one shot", fallbackId = "" },
	gameThrow = { id = "128956408965264", ref = "a pebble thrown, a short whoosh, one shot", fallbackId = "" },
	gameFall = {
		id = "129025505656884",
		ref = "a pebble knocking against a rock wall, falling a very long way, fading into the distance, one shot",
		fallbackId = "",
	},
	-- The rift dive and Death's mark (art/audio/game_bell_toll.wav, game_dive_wind.wav, game_dive_crash.wav).
	gameBellToll = {
		id = "129883053431239",
		ref = "one stroke of a great cracked bell, low, a long dying ring, one shot",
		fallbackId = "",
	},
	gameDiveWind = {
		id = "116650937413253",
		ref = "air rushing past a falling body, rising, about six seconds, one shot",
		fallbackId = "",
	},
	gameDiveCrash = {
		id = "81606899448339",
		ref = "a body landing hard on a flat roof, a dull heavy thud, one shot",
		fallbackId = "",
	},
	-- The deeper dive (2026-10-15): art/audio/game_dive_fall.wav, game_dive_string.wav, game_dive_impact.wav.
	-- Until they have ids, the dive plays gameDiveWind (looped) and gameDiveCrash instead.
	gameDiveFall = {
		id = "100898869843825",
		ref = "air tearing past a tumbling falling body, from a hush to a roar, about twelve seconds, one shot",
		fallbackId = "",
	},
	gameDiveString = {
		id = "122518920143812",
		ref = "a taut string snapping tight: a dry twang dying quickly, a soft whip of air, one shot",
		fallbackId = "",
	},
	gameDiveImpact = {
		id = "140509804863673",
		ref = "a body slamming into a flat roof: a heavy low thud with a dry crack on it, a short slap, one shot",
		fallbackId = "",
	},
	-- The Trial's wisp setting off somewhere new (art/audio/trial_chime.wav).
	trialChime = {
		id = "102047772661973",
		ref = "a soft warm two-note glass chime, quiet, a short shimmer after it, one shot",
		fallbackId = "",
		volume = 0.6,
	},
	-- The shop's styles (Presentation/Styles): art/audio/style_*.wav, silent until uploaded.
	typewriter = {
		id = "74506837948157",
		ref = "one typewriter key striking, a sharp clack",
		fallbackId = "",
		volume = 0.5,
	},
	knifeScrape = { id = "88295237282055", ref = "a knife blade scraping into paper", fallbackId = "", volume = 0.6 },
	crows = {
		id = "105511089763272",
		ref = "a flock of crows taking off, wings and caws",
		fallbackId = "",
		volume = 0.7,
	},
	stoneCrack = {
		id = "79409971128625",
		ref = "stone grinding and cracking, grit settling",
		fallbackId = "",
		volume = 0.7,
	},
	stringsSnap = { id = "128047806954958", ref = "taut strings twanging and snapping", fallbackId = "", volume = 0.6 },
	-- The paid win cutscenes (Shared/Cinema/WinCuts `sounds`): silent until the owner picks them.
	winRain = { id = "", ref = "rain on a tall window at night, steady, a room's quiet", fallbackId = "", volume = 0.5 },
	winBookShut = { id = "", ref = "a heavy leather book snapped shut", fallbackId = "", volume = 0.8 },
	winCandleOut = { id = "", ref = "a candle flame snuffed, a soft puff", fallbackId = "", volume = 0.5 },
	winThunder = { id = "", ref = "close thunder after a lightning flash, a long roll", fallbackId = "", volume = 0.8 },
	winWind = { id = "", ref = "high wind across a rooftop at night, a city far below", fallbackId = "", volume = 0.5 },
	winPagesTear = { id = "", ref = "many pages tearing loose at once, a rush of paper", fallbackId = "", volume = 0.7 },
	winCityDie = {
		id = "",
		ref = "a city's hum dying away, power going down block by block",
		fallbackId = "",
		volume = 0.6,
	},
	winGodhood = { id = "", ref = "one deep choir swell with a low impact", fallbackId = "", volume = 0.7 },
	winOfficeHum = { id = "", ref = "a quiet office at night: a lamp's buzz, a clock", fallbackId = "", volume = 0.4 },
	winStringSnap = { id = "", ref = "a taut string snapping, a quick whip", fallbackId = "", volume = 0.6 },
	winStamp = { id = "", ref = "a rubber stamp slammed on paper on a wooden desk", fallbackId = "", volume = 0.8 },
	winVoid = { id = "", ref = "a vast empty hall, low air, distant wind", fallbackId = "", volume = 0.4 },
	winKingFall = {
		id = "",
		ref = "a huge stone piece tipping and grinding as it falls",
		fallbackId = "",
		volume = 0.7,
	},
	winShatter = { id = "", ref = "glass and stone shattering into a rain of shards", fallbackId = "", volume = 0.8 },
	winPiecesLight = { id = "", ref = "a row of soft bright chimes rising", fallbackId = "", volume = 0.5 },
	-- The role cutscenes' voiced lines (Shared/Cinema/Shots, `sound.voice`): each starts on its shot's typed line, and a
	-- clip longer than the line's time there stretches the whole cutscene to fit it (Shared/Cinema/CutLength). Silent until
	-- filled.
	voiceDiavolo = {
		id = "",
		ref = 'Diavolo, calm then manic: "I\'ll take a potato chip... and EAT IT!" (the last two words shouted), about 3 s',
		fallbackId = "",
	},
	voiceMuerto = {
		id = "",
		ref = 'the Muerto, faster and louder with each stab: "Delete, delete, delete, delete, DELETE, DELETE...", about 4 s',
		fallbackId = "",
	},
	voiceButler = {
		id = "",
		ref = 'the Butler, quiet and kind: "Is something the matter? Hmm? ... What\'s wrong?", about 3.5 s',
		fallbackId = "",
	},
	voiceAce = {
		id = "",
		ref = 'Ace, flat and slow: "I had to test this just in case, but I, I never thought it would actually happen. '
			.. 'Diavolo... it seems you can kill people without having to be there in person.", about 11 s',
		fallbackId = "",
	},
	-- The map intros' moments (Shared/Cinema/Shots): silent until filled.
	bodyFall = { id = "", ref = "a body collapsing onto a hard floor, a dull thud", fallbackId = "" },
	trainDoors = { id = "", ref = "metro train doors chiming and sliding shut", fallbackId = "" },
	penStop = { id = "", ref = "a pen lifted sharply off paper, a short tap", fallbackId = "" },
	bookImpact = { id = "", ref = "a heavy book slamming down onto the ground from a height", fallbackId = "" },
	screenStatic = { id = "", ref = "a monitor's screen bursting into static, a short hiss", fallbackId = "" },
	-- The first join's eye intro (UI/EyeIntro) and the apple loading screen (UI/AppleLoading): silent until filled.
	introEyeOpen = { id = "", ref = "an eye snapping open: a low swell and a sharp, wet shimmer", fallbackId = "" },
	introAmbience = {
		id = "",
		ref = "a dark, close room tone under the closed eye: low hum, faint breath, loop",
		fallbackId = "",
		volume = 0.5,
	},
	loadAppleFall = {
		id = "",
		ref = "a soft rising whoosh as the apple falls, about 2 s",
		fallbackId = "",
		volume = 0.5,
	},
	loadAppleCatch = { id = "", ref = "an apple caught in a palm: a soft, firm slap", fallbackId = "", volume = 0.7 },
} :: { [string]: Audio }

-- Animations by pose id (see src/shared/Anim/Poses.luau). "" = the procedural pose. Every
-- client plays these from public events, on every character, so they must be poses anyone
-- could see anyway.
Assets.anim = {
	write = "",
	collapseHeart = "",
	collapseIllness = "",
	collapseFall = "",
	collapseTraffic = "",
	cuffed = "",
	slump = "",
	kneel = "",
	raiseHand = "",
	laugh = "",
	victory = "",
	victoryFist = "",
	victoryBow = "",
	defeat = "",
	specterFloat = "",
} :: { [string]: string }

-- Not used while the Blender movement clips animate characters (src/shared/Anim/Clips and
-- the empty Animate script). Kept for places that restore Roblox's Animate script.
Assets.locomotion = {
	idle = "",
	idleAlt = "",
	walk = "",
	run = "",
	jump = "",
	fall = "",
	climb = "",
	swim = "",
	swimIdle = "",
} :: { [string]: string }

-- Catalog clothing for the noir outfit layer. Empty = the part-built suit and tie.
Assets.outfit = {
	shirt = "",
	pants = "",
} :: { [string]: string }

-- Effect textures made in Blender (art/export/textures). They also arrive with the model import
-- (on quads named Tex_<name>), so these ids are only needed if you upload the PNGs yourself.
-- Empty = use the imported one, or Roblox's default particle when nothing is imported.
Assets.textures = {
	RainStreak = "",
	Smoke = "",
	SoulGlow = "",
	Spark = "",
	SpeechNah = "", -- Nah, I'd Win's speech bubble
	Snowflake = "",
	Footprint = "",
	AuraGlow = "", -- (the UI's soft light, UI/Kit/Surfaces)
} :: { [string]: string }

-- Pictures uploaded on their own through Studio's importer (art/export/textures). The first join's eye, painted in
-- layers by art/scripts/ui/eye_intro.py (UI/EyeIntro): the face with the eye shut in two halves, the eye's corner as it
-- opens (four frames), the foreground hair in two halves. The loading screen's apple, a 4 x 4 sheet of it turning, and
-- the hand that catches it, waiting and holding it (art/scripts/ui/intro_frames.py, UI/AppleLoading). "" until uploaded:
-- those screens then draw a stand-in.
Assets.images = {
	IntroBaseL = "112649732036299",
	IntroBaseR = "117826587593763",
	IntroEye1 = "73671134573669",
	IntroEye2 = "72561965034296",
	IntroEye3 = "86909090559573",
	IntroEye4 = "126999503834786",
	IntroHairL = "77350048823213",
	IntroHairR = "73218582422326",
	AppleSpin = "116054757714434",
	AppleHand1 = "119620415469239",
	AppleHand2 = "109922448543976",
	-- The pointer (UI/Cursor, art/scripts/ui/cursors.py): locked in a case, the closed-eyes mark; free, the pen nib.
	CursorLock = "",
	CursorFree = "",
	-- The Reál's mark (the user's, 2026-10-28): the currency's icon everywhere (UI/Kit/Icon "real"); the coin until
	-- it is uploaded.
	RealIcon = "",
} :: { [string]: string }

-- Placeholder glyphs until an icon sheet is uploaded; an image id replaces the glyph.
Assets.icons = {
	evidence = { glyph = "▤", image = "" },
	quickChat = { glyph = "✉", image = "" },
	note = { glyph = "✎", image = "" },
	eyes = { glyph = "◉", image = "" },
	desk = { glyph = "0", image = "" },
	vote = { glyph = "☐", image = "" },
	settings = { glyph = "⚙", image = "" },
	coin = { glyph = "¢", image = "" },
} :: { [string]: { glyph: string, image: string } }

-- "123" and "rbxassetid://123" both become "rbxassetid://123"; "" stays "".
function Assets.contentId(id: string): string
	if id == "" then
		return ""
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- The id to play for an audio slot, or nil while both the upload and the fallback are empty.
function Assets.audioId(entry: Audio?): string?
	if not entry then
		return nil
	end
	local id = if entry.id ~= "" then entry.id else entry.fallbackId
	if id == "" then
		return nil
	end
	return Assets.contentId(id)
end

-- An effect texture's content id: your upload, else the imported one, else "". The VFX kit's ("Vfx...", the Fx
-- import's) too; in the harness place (workspace attribute DGVfxLocal) those are read from Studio's content folder.
function Assets.texture(name: string): string
	local id = Assets.textures[name]
	if id and id ~= "" then
		return Assets.contentId(id)
	end
	if string.sub(name, 1, 3) == "Vfx" and workspace:GetAttribute("DGVfxLocal") then
		return "rbxasset://textures/dg_vfx_harness/" .. name .. ".png"
	end
	local ModelLibrary = require(script.Parent.ModelLibrary) :: any
	return ModelLibrary.carrierTexture(name) or ""
end

-- A fresh copy of a model you exported to assets/shared/Models, or nil to build the fallback.
function Assets.model(key: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("DeathsGambitAssets")
	local models = root and root:FindFirstChild("Models")
	local model = models and models:FindFirstChild(key)
	if model then
		return model:Clone()
	end
	return nil
end

return Assets
