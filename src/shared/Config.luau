--!strict
-- Tuning values for Death's Gambit. The server and every client read this module,
-- so it must never hold secrets (roles, real names, notes...).

local Config = {}

-- Match size. A server holds between 6 and 12 players.
Config.MIN_PLAYERS = 6
Config.MAX_PLAYERS = 12

-- Phase lengths in seconds. Investigation is free roam: it ends early on a death or the bell, and
-- its length is the fallback timer that calls a meeting when nothing else has.
Config.PHASE_TIME = {
	-- Presentation phases: cutscenes play in full, even in sped-up Studio runs.
	Intro = 15,
	Verdict = 7,
	Outro = 10,
	Briefing = 15, -- (only without role cutscenes: with them, the longest one plus BRIEFING_HOLD)
	Investigation = 180,
	Meeting = 60,
	Vote = 20,
	Reveal = 30,
}

-- Seconds the role card stays up to read after the longest role cutscene of the match (the briefing's length is that
-- cutscene's and this: Services/RoundService).
Config.BRIEFING_HOLD = 5

-- Lobby, parties and matchmaking
Config.LOBBY_COUNTDOWN = 15
Config.MAX_PARTY_SIZE = 4
Config.PARTY_INVITE_TIMEOUT = 60
-- Cross-server matchmaking through MemoryStoreService and TeleportService. It only runs in live
-- servers; in Studio every match is started inside the current server.
Config.CROSS_SERVER_MATCHMAKING = true
-- Seconds a queued party waits for a match in its own server before it also searches other servers.
Config.CROSS_SERVER_AFTER = 20

-- Case files. The Bureau shares one task bar: it is full at TASKS_PER_BUREAU case files for every
-- Bureau player the match started with.
Config.TASK_RANGE = 9
Config.TASKS_PER_BUREAU = 4

-- Death's Manual (internal id "DeathNote"): Diavolo writes any time in free roam, in plain sight.
Config.DEATH_CAUSES = { "Heart attack", "Disease", "Accident" }
Config.NAME_MAX_LENGTH = 40
Config.MANUAL_WRITE_TIME = 4 -- seconds standing with the glowing book open
Config.MANUAL_COOLDOWN = 60
Config.MANUAL_DELAY = 20 -- free-roam seconds between the writing and the death

-- Staring (Diavolo and Muertos): stand still, look at someone close, learn their real name.
Config.STARE_TIME = 4
Config.STARE_RANGE = 12
-- The Oculus deal (internally "eyes"): a Muerto only. A visible ritual, then fast reads from far
-- off, and death after OCULUS_LIFESPAN seconds of free roam.
Config.OCULUS_RITUAL = 3
Config.OCULUS_READ_TIME = 1
Config.OCULUS_RANGE = 30
Config.OCULUS_LIFESPAN = 180
Config.EYES_DURATION = 3 -- how long a learned name shows above its owner

-- Muerto sabotage: one shared cooldown per Muerto, never during a meeting.
Config.SABOTAGE_COOLDOWN = 45
Config.BLACKOUT_TIME = 15
Config.JAM_TIME = 30
Config.BARRICADE_TIME = 10

-- Meetings: one emergency bell per map, one ring per player per match.
Config.BELL_RANGE = 10

-- Ace's arrest and the Butler's succession.
Config.BUTLER_PICK_TIME = 30

-- World interaction
Config.INTERACT_RANGE = 10

-- Paper notes
Config.NOTE_MAX_LENGTH = 40
Config.BURN_TIME = 2
Config.SHEET_RESPAWN_TIME = 30
-- Passing a written note hand to hand: how close, how long the other has to take it, and how
-- soon the same player may offer again.
Config.PASS_RANGE = 4
Config.PASS_TIMEOUT = 5
Config.PASS_COOLDOWN = 3

-- Communication. In free roam the living type in proximity chat; full real names are blocked in
-- every chat, so only paper notes carry them.
Config.PROXIMITY_CHAT_RANGE = 20
Config.QUICK_CHAT_COOLDOWN = 2

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
	CORRECT_VOTE_COINS = 10,
	CORRECT_VOTE_XP = 15,
	KILL_COINS = 20,
	KILL_XP = 25,
	ARREST_COINS = 50,
	ARREST_XP = 60,
	EYES_READ_COINS = 5,
	EYES_READ_XP = 5,
	-- Lost souls gathered as a Specter (at most 8 per match, so always less than surviving
	-- plus winning).
	SPECTER_DUTY_COINS = 3,
	SPECTER_DUTY_XP = 5,
}

-- One-time reward for finishing every drill in the Academy (the lobby training wing).
Config.TRAINING_REWARD = 100
Config.TRAINING_DRILLS = { "camera", "fingerprint", "phone", "forensics", "grimoire", "warrant", "eyes" }

-- Maps in rotation (module names under ServerScriptService.Server.Maps)
Config.MAP_ROTATION = { "TaskForceHQ", "UniversityCampus", "TokyoDistrict" }

-- Studio testing helpers. These are ignored in live servers.
Config.STUDIO_MIN_PLAYERS = 1
-- Game passes treated as owned while testing in Studio, e.g. { "alias", "director", "vip" }.
Config.STUDIO_PASSES = {} :: { string }
-- Force the first player's role in Studio, by internal id: "Kira" (the Hand), "Follower"
-- (Cultist), "L" (Zero), "Watari" (the Butler) or "TaskForce" (Agent).
Config.STUDIO_FORCE_ROLE = ""
-- Multiplies every phase length in Studio, for example 0.3 for quick test runs.
Config.STUDIO_TIME_SCALE = 1
Config.RUN_TESTS_IN_STUDIO = true
-- Appended to the DataStore name in Studio, so test runs never touch live player data.
-- Set it to "" only to test against the live store on purpose.
Config.STUDIO_DATASTORE_SUFFIX = "_studio"
-- The debug panel for forcing phases, wins and eliminations in Studio play tests (still only for DEBUG_USER_IDS).
Config.STUDIO_DEBUG = true
-- Cuts the Intro, Verdict and Outro presentation phases short in Studio.
Config.STUDIO_SKIP_PRESENTATION = false
-- Test bots added from the debug panel play on their own (walk, work case files, vote, and
-- write names when they are the Hand). Both can be switched in the panel while testing.
Config.STUDIO_BOTS_AUTOPLAY = true
Config.STUDIO_BOTS_HAND_KILLS = true
-- The only Roblox users who get the debug panel, in Studio play tests and live servers alike (2026-10-27): the game's
-- owner, realALEXTEM, and Kenshi_89. Everyone in the server can see what it does.
Config.DEBUG_USER_IDS = { 409214934, 1503130900 } :: { number }

return Config
