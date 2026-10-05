--!strict
-- The swap-in registry. Every sound, animation, model and icon the game can use is listed
-- here by name. An empty id means "use the built-in fallback": silence for audio, the
-- procedural pose for animations, the part-built version for models.
--
-- To use your own assets:
--   audio / animations: upload them in Studio or on the Creator Dashboard and paste the id
--     ("rbxassetid://123..." or just the number) into the matching slot.
--   models: export them from Studio as .rbxm into assets/shared/Models (Rojo syncs that folder
--     to ReplicatedStorage.InkboundAssets.Models) and name the file after the key below.

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
	grimoire = { id = "85538418554276", ref = "Black Souls: Grimoire (M-ART)", fallbackId = "" },
	meeting = { id = "82941366813687", ref = "Deltarune Ch.3+4: Query?", fallbackId = "" },
	vote = { id = "90401963211160", ref = "Deltarune Ch.3+4: Black Knife", fallbackId = "" },
	specter = { id = "124751068997305", ref = "OMORI: WHITE SPACE", fallbackId = "" },
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
	mapCityHum = { id = "81235587177208", ref = "distant city traffic hum at night, loop", fallbackId = "" },
	mapCrossingChirp = {
		id = "118593933745441",
		ref = "Japanese pedestrian crossing bird chirp, loop",
		fallbackId = "",
	},
	mapTrainArrive = { id = "134959404397926", ref = "metro train pulling into a station", fallbackId = "" },
	mapStationChime = { id = "74308843149652", ref = "Japanese station platform chime", fallbackId = "" },
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
	mapPianoFar = { id = "", ref = "an upright piano practising down a corridor, muffled, loop", fallbackId = "" },
	mapNewsRadio = { id = "", ref = "a late-night news radio murmuring in an empty room, loop", fallbackId = "" },
	mapWindWaste = { id = "", ref = "a dry wind moaning across an empty desert of ash, loop", fallbackId = "" },
	mapRiftHum = { id = "", ref = "a deep, hollow drone rising out of a chasm, loop", fallbackId = "" },
	-- The Grey Realm's soundscape (art/audio/*.wav made by art/scripts/audio/make_realm_audio.py): three
	-- beds that never stop, wind through rocks at the vistas, and one-shots that come now and then from a
	-- long way off (World: Audio/RealmAmbience). Keep every one of them quiet.
	realmWind = {
		id = "",
		ref = "a low, distant wind over an empty plain, slowly swelling, loop",
		fallbackId = "",
		volume = 0.5,
	},
	realmDrone = { id = "", ref = "a very quiet, low atmospheric drone, loop", fallbackId = "", volume = 0.4 },
	realmRumble = {
		id = "",
		ref = "an extremely subtle sub-bass rumble far below, loop",
		fallbackId = "",
		volume = 0.35,
	},
	realmRocks = {
		id = "",
		ref = "wind passing through rock spires, a thin whistle, loop",
		fallbackId = "",
		volume = 0.5,
	},
	realmStone1 = {
		id = "",
		ref = "a distant stone knock, as if a rock settled, one shot",
		fallbackId = "",
		volume = 0.6,
	},
	realmStone2 = { id = "", ref = "a far-off rumble of loose scree sliding, one shot", fallbackId = "", volume = 0.6 },
	realmMetal1 = { id = "", ref = "a faint distant metallic creak, one shot", fallbackId = "", volume = 0.5 },
	realmMetal2 = {
		id = "",
		ref = "a far, hollow metallic tone, like a chain moving, one shot",
		fallbackId = "",
		volume = 0.5,
	},
	realmFar1 = { id = "", ref = "a barely heard whisper on the wind, one shot", fallbackId = "", volume = 0.4 },
	realmFar2 = { id = "", ref = "a distant, unplaceable breath of sound, one shot", fallbackId = "", volume = 0.4 },
	-- The lobby mini-games.
	gameRune = { id = "", ref = "a soft, glassy single tone, played at different pitches, one shot", fallbackId = "" },
	gameWrong = { id = "", ref = "a dull low stone thud, one shot", fallbackId = "" },
	gameCheckpoint = { id = "", ref = "a pale bell tone, short, one shot", fallbackId = "" },
	gameFinish = { id = "", ref = "two soft bell tones rising, one shot", fallbackId = "" },
	gameDice = { id = "", ref = "bone dice rattled and thrown on stone, one shot", fallbackId = "" },
	gameThrow = { id = "", ref = "a pebble thrown, a short whoosh, one shot", fallbackId = "" },
	gameFall = {
		id = "",
		ref = "a pebble knocking against a rock wall, falling a very long way, fading into the distance, one shot",
		fallbackId = "",
	},
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

-- Not used while the Blender movement clips animate characters (src/shared/Anim/Clips.luau and
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
	InkSplat1 = "",
	InkSplat2 = "",
	InkSplat3 = "",
	InkDrop = "",
	RainStreak = "",
	Smoke = "",
	SoulGlow = "",
	Spark = "",
	Snowflake = "",
	Footprint = "",
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

-- An effect texture's content id: your upload, else the imported one, else "".
function Assets.texture(name: string): string
	local id = Assets.textures[name]
	if id and id ~= "" then
		return Assets.contentId(id)
	end
	local ModelLibrary = require(script.Parent.ModelLibrary) :: any
	return ModelLibrary.carrierTexture(name) or ""
end

-- A fresh copy of a model you exported to assets/shared/Models, or nil to build the fallback.
function Assets.model(key: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("InkboundAssets")
	local models = root and root:FindFirstChild("Models")
	local model = models and models:FindFirstChild(key)
	if model then
		return model:Clone()
	end
	return nil
end

return Assets
