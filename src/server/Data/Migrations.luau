--!strict
-- The player profile schema. defaults() is the newest shape. migrate() upgrades an older
-- profile one version at a time, then fills in anything missing from the defaults.
-- A profile saved by a newer server (a higher v) is never changed: the caller loads a copy
-- read-only, so an older server can never downgrade it while an update rolls out.
--
-- Adding a field only needs an entry in defaults(); fill() adds it to old profiles.
-- Renaming or reshaping data needs a new step in STEPS and a higher CURRENT.

local Migrations = {}

Migrations.CURRENT = 2

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
		},
		tipsSeen = {}, -- [tipId] = true
		training = { done = false, drills = {} },
		alias = "", -- custom public alias (Custom Alias pass), already filtered
		titles = {}, -- [titleId] = true
		equippedTitle = "",
		streak = { day = -1, count = 0, best = 0 },
		quests = {
			daily = { period = -1, items = {} },
			weekly = { period = -1, items = {} },
			rerollDay = -1,
		},
		achievements = {}, -- [achievementId] = unix time
		pendingBadges = {}, -- [achievementId] = true while the badge award still has to succeed
		mastery = mastery, -- [roleId] = xp
		receipts = {}, -- [purchaseId] = unix time
		privateSettings = {},
		weekly = { week = -1, wins = 0, xp = 0 },
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

-- One function per version: STEPS[n] upgrades a version n profile to n + 1.
local STEPS: { [number]: (any) -> () } = {
	-- v1 held coins, xp, owned, equipped { hat, trail } and stats { matches, wins, tasks }.
	-- Everything new comes from defaults(), so nothing needs converting.
	[1] = function(_data) end,
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
