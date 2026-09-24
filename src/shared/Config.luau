--!strict
-- Tuning values for Inkbound. The server and every client read this module,
-- so it must never hold secrets (roles, real names, notes...).

local Config = {}

-- Match size. A server holds between 6 and 12 players.
Config.MIN_PLAYERS = 6
Config.MAX_PLAYERS = 12
Config.MAX_ROUNDS = 5

-- Phase lengths in seconds. Five rounds of 200 seconds plus briefing and reveal is about 18 minutes.
Config.PHASE_TIME = {
	-- Presentation phases: cutscenes play in full, even in sped-up Studio runs.
	Intro = 8,
	Verdict = 7,
	Outro = 10,
	Briefing = 15,
	Investigation = 100,
	DeathNote = 20,
	Meeting = 60,
	Vote = 20,
	Reveal = 30,
}

-- Lobby, parties and matchmaking
Config.LOBBY_COUNTDOWN = 15
Config.MAX_PARTY_SIZE = 4
Config.PARTY_INVITE_TIMEOUT = 60
-- Cross-server matchmaking through MemoryStoreService and TeleportService. It only runs in live
-- servers; in Studio every match is started inside the current server.
Config.CROSS_SERVER_MATCHMAKING = true
-- Seconds a queued party waits for a match in its own server before it also searches other servers.
Config.CROSS_SERVER_AFTER = 20

-- Case files
Config.TASK_DURATION = 15
Config.TASK_RANGE = 9
Config.FLASH_RANGE = 16
Config.FLASH_DURATION = 3
Config.LETTERS_PER_FLASH = 3
Config.WITNESS_RANGE = 30

-- The Grimoire (internal phase id "DeathNote")
Config.DEATH_DELAY = 40
Config.DEATH_CAUSES = { "Heart attack", "Traffic accident", "Sudden illness", "Accidental fall" }
Config.NAME_MAX_LENGTH = 40

-- Specter's Eyes (internally "eyes")
Config.EYES_UNLOCK_ROUND = 2
Config.EYES_COUNTDOWN = 2
Config.EYES_READS = 3
Config.EYES_READS_SMALL_SERVER = 2
Config.EYES_SMALL_SERVER_BELOW = 8
Config.EYES_RANGE = 14
Config.EYES_DURATION = 3
Config.EYES_COOLDOWN = 4
-- While the eyes are new (the round of the deal) some names blur. Zero's name always blurs in that
-- round, so a blurred read never proves that the target is L.
Config.EYES_DEAL_ROUND_BLUR_CHANCE = 0.35

-- World interaction
Config.INTERACT_RANGE = 10

-- Paper notes
Config.NOTE_MAX_LENGTH = 40
Config.BURN_TIME = 2
Config.BURN_SMOKE_RANGE = 20
Config.SHEET_RESPAWN_TIME = 30
Config.DROP_POINT_CAPACITY = 3

-- Communication
Config.TIP_MAX_LENGTH = 150
Config.TIP_COOLDOWN = 15
Config.REPORT_MAX_LENGTH = 120
Config.L_SCREEN_MAX_LENGTH = 150
Config.L_SCREEN_COOLDOWN = 3
Config.QUICK_CHAT_COOLDOWN = 2

-- Suspicion meter (0-100, shown to L only)
Config.SUSPICION = {
	REPORT = 10,
	FAKE_TASK_SEEN = 15,
	NEAR_BURN = 12,
	IDLE_ROUND = 8,
	MAX = 100,
}

-- Rewards paid at the end of a match
Config.STARTING_COINS = 100
Config.REWARDS = {
	PARTICIPATE_COINS = 20,
	PARTICIPATE_XP = 30,
	WIN_COINS = 60,
	WIN_XP = 80,
	SURVIVE_COINS = 15,
	SURVIVE_XP = 20,
	TASK_COINS = 4,
	TASK_XP = 6,
	TASK_CAP = 10,
	NOTE_FOUND_COINS = 10,
	NOTE_FOUND_XP = 10,
	CORRECT_VOTE_COINS = 10,
	CORRECT_VOTE_XP = 15,
	KILL_COINS = 20,
	KILL_XP = 25,
	ARREST_COINS = 50,
	ARREST_XP = 60,
	EYES_READ_COINS = 5,
	EYES_READ_XP = 5,
}

-- One-time reward for finishing every drill in the Academy (the lobby training wing).
Config.TRAINING_REWARD = 100
Config.TRAINING_DRILLS = { "camera", "fingerprint", "phone", "grimoire", "warrant", "eyes" }

-- Maps in rotation (module names under ServerScriptService.Server.Maps)
Config.MAP_ROTATION = { "TaskForceHQ", "UniversityCampus", "TokyoDistrict" }

-- Studio testing helpers. These are ignored in live servers.
Config.STUDIO_MIN_PLAYERS = 1
-- Force the first player's role in Studio, by internal id: "Kira" (the Hand), "Follower"
-- (Cultist), "L" (Zero), "Watari" (the Butler) or "TaskForce" (Agent).
Config.STUDIO_FORCE_ROLE = ""
-- Multiplies every phase length in Studio, for example 0.3 for quick test runs.
Config.STUDIO_TIME_SCALE = 1
Config.RUN_TESTS_IN_STUDIO = true
-- Appended to the DataStore name in Studio, so test runs never touch live player data.
-- Set it to "" only to test against the live store on purpose.
Config.STUDIO_DATASTORE_SUFFIX = "_studio"
-- A debug panel (press F2) for forcing phases, wins and eliminations. Studio only.
Config.STUDIO_DEBUG = true
-- Cuts the Intro, Verdict and Outro presentation phases short in Studio.
Config.STUDIO_SKIP_PRESENTATION = false

return Config
