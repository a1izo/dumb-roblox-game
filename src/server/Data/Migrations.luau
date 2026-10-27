--!strict
-- The player profile schema. defaults() is the newest shape. migrate() upgrades an older
-- profile one version at a time, then fills in anything missing from the defaults.
-- A profile saved by a newer server (a higher v) is never changed: the caller loads a copy
-- read-only, so an older server can never downgrade it while an update rolls out.
--
-- Adding a field only needs an entry in defaults(); fill() adds it to old profiles.
-- Renaming or reshaping data needs a new step in STEPS and a higher CURRENT.

local Migrations = {}

Migrations.CURRENT = 7

-- Internal role ids; they never change even though the displayed names do.
local ROLE_IDS = { "Kira", "Follower", "L", "Watari", "TaskForce" }

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

function Migrations.defaults(startingCoins: number)
	local roles = {}
	local mastery = {}
	for _, id in ipairs(ROLE_IDS) do
		roles[id] = { played = 0, won = 0 }
		mastery[id] = 0
	end
	return {
		v = Migrations.CURRENT,
		coins = startingCoins,
		xp = 0,
		owned = {}, -- [itemId] = true
		equipped = {}, -- [kind] = itemId
		stats = {
			matches = 0,
			wins = 0,
			tasks = 0,
			fakeTasks = 0,
			kills = 0,
			arrests = 0,
			reads = 0,
			correctVotes = 0,
			notesFound = 0,
			survived = 0,
			duties = 0,
			reports = 0,
			rigs = 0,
			roles = roles, -- [roleId] = { played, won }
			sides = { Team = { played = 0, won = 0 }, Kira = { played = 0, won = 0 } },
		},
		settings = {
			music = 0.7,
			sfx = 1,
			ambience = 0.8,
			ui = 1,
			uiScale = 1,
			reduceMotion = false,
			cameraShake = true,
			hints = true,
			lowGraphics = false,
			emoteMusic = true, -- other players' emote sounds (Shared/EmoteMedia)
			emoteCamera = true, -- the camera moving round your own showpiece emotes, in the lobby
			emoteCutscenes = true, -- the private cutscenes of the Godhood emotes, in the lobby
			master = 1,
			fov = 70,
			brightness = 0,
			screenFlashes = true,
			showFps = false,
			showHud = true,
			weather = true,
			nameTags = true,
			chatBubbles = true,
			otherAuras = true,
			otherEmoteFx = true,
		},
		tipsSeen = {}, -- [tipId] = true
		-- The Academy's drills. `unrewarded` is set (by Shared/Trial) on a profile that finishes all seven now
		-- that they pay nothing by themselves; it is deliberately not a default, so profiles that finished
		-- them when they did pay can be told apart.
		training = { done = false, drills = {} },
		-- The Trial (Shared/Trial): done, the offer turned down, the Academy's one reward paid for it, and how many
		-- of its steps were done (a rejoin carries on from there).
		trial = { done = false, skipped = false, paid = false, step = 0 },
		-- The lobby mini-games' bests: the Spire Ascent's fastest time (seconds, 0 = none), the most rune
		-- rounds cleared, the longest stone-toss echo (seconds), the fastest spirit trial, the rift's smallest gap (studs, 0 = none), the most tolls survived in a row with
		-- Death's mark; the grey apples found (a bit for each of the seven); and the name duels won.
		lobbyGames = {
			parkourBest = 0,
			runesBest = 0,
			tossBest = 0,
			spiritBest = 0,
			riftBest = 0,
			markBest = 0,
			apples = 0,
			duelWins = 0,
		},
		alias = "", -- custom public alias (Custom Alias pass), already filtered
		titles = {}, -- [titleId] = true
		equippedTitle = "",
		streak = { day = -1, count = 0, best = 0 },
		quests = {
			daily = { period = -1, items = {} },
			weekly = { period = -1, items = {} },
			ghost = { period = -1, items = {} },
			rerollDay = -1,
		},
		achievements = {}, -- [achievementId] = unix time
		pendingBadges = {}, -- [achievementId] = true while the badge award still has to succeed
		mastery = mastery, -- [roleId] = xp
		receipts = {}, -- [purchaseId] = unix time
		privateSettings = {},
		weekly = { week = -1, wins = 0, xp = 0 },
		-- The shop's Today's hand: the cards turned so far, on which day (Shared/ShopRotation.turn).
		shopTurned = { day = -1, cards = {} },
		-- The emote wheel's eight clip ids, "" for an empty slot; empty = never changed (Shared/EmoteWheel).
		emoteWheel = {},
		-- The player's own control bindings, by platform then action (Shared/Bindings); empty = the defaults.
		keybinds = {},
		-- The stance (an owned emote item that can be one), "" for none (Shared/Cosmetics `stance`).
		stance = "",
		-- The Season ledger (Progression/Ledger): the season it is for, its points and the tier paid up to.
		ledger = { season = 0, points = 0, tier = 0 },
		-- Browsing the shop (Shared/ShopBrowse): new cards already looked at, and the wishlist.
		shopSeen = {}, -- [itemId] = true
		wishlist = {}, -- [itemId] = true
	}
end

-- Copies every key that is missing from data, or has the wrong type, from defaults. Recurses
-- into tables the defaults describe field by field (for example settings); maps whose default
-- is empty (owned, receipts...) are left as they are.
local function fill(data: any, defaults: any)
	for key, default in pairs(defaults) do
		local value = data[key]
		if type(value) ~= type(default) then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and next(default) ~= nil then
			fill(value, default)
		end
	end
end

-- The retired victory poses and what they cost (coins), refunded by the v2 -> v3 step.
local RETIRED_VICTORY_POSES = { win_fist = 400, win_bow = 700 }

-- One function per version: STEPS[n] upgrades a version n profile to n + 1.
local STEPS: { [number]: (any) -> () } = {
	-- v1 held coins, xp, owned, equipped { hat, trail } and stats { matches, wins, tasks }.
	-- Everything new comes from defaults(), so nothing needs converting.
	[1] = function(_data) end,
	-- v2 -> v3: the victory poses were retired (the win cutscenes replace them). Whoever owned one
	-- gets its price back in coins and nothing stays equipped in that slot.
	[2] = function(data)
		local refunded = 0
		for id, price in pairs(RETIRED_VICTORY_POSES) do
			if type(data.owned) == "table" and data.owned[id] then
				data.owned[id] = nil
				refunded += price
			end
		end
		if type(data.equipped) == "table" then
			data.equipped.victory = nil
		end
		if refunded > 0 then
			data.coins = (tonumber(data.coins) or 0) + refunded
		end
	end,
	-- v3 -> v4: the rift's dive became about three times as deep (2026-10-15), so the old smallest gaps
	-- are not comparable: each is kept as riftBestV1 (shown nowhere) and the best starts again. The
	-- retired bone dice's best goes.
	[3] = function(data)
		local games = data.lobbyGames
		if type(games) == "table" then
			if (tonumber(games.riftBest) or 0) > 0 then
				games.riftBestV1 = games.riftBest
			end
			games.riftBest = 0
			games.diceBest = nil
		end
	end,
	-- v4 -> v5 (2026-10-21, the owner's calls in the shop overhaul): trails left the game, with no refund, so the
	-- trail ids and the trail slot go; and so does the win scene, the emote a winner played at the table in "The
	-- end" (the table win pose was removed: winners cheer, and the win cutscenes replace it).
	[4] = function(data)
		if type(data.owned) == "table" then
			for id in pairs(data.owned) do
				if type(id) == "string" and string.sub(id, 1, 6) == "trail_" then
					data.owned[id] = nil
				end
			end
		end
		if type(data.equipped) == "table" then
			data.equipped.trail = nil
		end
		data.winScene = nil
	end,
	-- v5 -> v6 (2026-10-21, the owner's drops in the shop overhaul, no refund): the ties (and their slot), the
	-- Deerstalker, the Ivory Fedora, the Velvet Cap and the Bone Vellum cover leave the game. A master who had
	-- earned a role's level-10 tie has that role's level-10 title instead.
	[5] = function(data)
		local dropped = {
			hat_deerstalker = true,
			hat_fedora_white = true,
			hat_cap_vip = true,
			book_white = true,
		}
		local masters = {
			tie_m_hand = "title_m10_hand",
			tie_m_cultist = "title_m10_cultist",
			tie_m_zero = "title_m10_zero",
			tie_m_butler = "title_m10_butler",
			tie_m_agent = "title_m10_agent",
		}
		if type(data.owned) == "table" then
			local ids = {}
			for id in pairs(data.owned) do
				table.insert(ids, id)
			end
			for _, id in ipairs(ids) do
				if type(id) == "string" and (dropped[id] or string.sub(id, 1, 4) == "tie_") then
					if masters[id] then
						data.owned[masters[id]] = true
					end
					data.owned[id] = nil
				end
			end
		end
		if type(data.equipped) == "table" then
			data.equipped.tie = nil
			if dropped[data.equipped.hat] then
				data.equipped.hat = nil
			end
			if dropped[data.equipped.grimoire] then
				data.equipped.grimoire = nil
			end
		end
	end,
	-- v6 -> v7 (2026-10-27, the user's call, no refund): the Wardrobe leaves the shop and the hats leave the game
	-- (every hat_ id owned, and the hat slot).
	[6] = function(data)
		if type(data.owned) == "table" then
			local ids = {}
			for id in pairs(data.owned) do
				table.insert(ids, id)
			end
			for _, id in ipairs(ids) do
				if type(id) == "string" and string.sub(id, 1, 4) == "hat_" then
					data.owned[id] = nil
				end
			end
		end
		if type(data.equipped) == "table" then
			data.equipped.hat = nil
		end
	end,
}

function Migrations.version(data: any): number
	if type(data) == "table" and type(data.v) == "number" then
		return data.v
	end
	return 1
end

-- Returns the profile to use and whether it must be treated as read-only.
function Migrations.migrate(data: any, startingCoins: number): (any, boolean)
	local defaults = Migrations.defaults(startingCoins)
	if type(data) ~= "table" then
		return defaults, false
	end
	local version = Migrations.version(data)
	if version > Migrations.CURRENT then
		local copy = deepCopy(data)
		fill(copy, defaults)
		return copy, true
	end
	while version < Migrations.CURRENT do
		local step = STEPS[version]
		assert(step ~= nil, "missing profile migration from v" .. version)
		step(data)
		version += 1
		data.v = version
	end
	fill(data, defaults)
	return data, false
end

return Migrations
