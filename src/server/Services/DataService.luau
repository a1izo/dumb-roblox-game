-- Persistent player data in a DataStore with session locking: a server claims a profile
-- while the player is in it, so two servers never overwrite each other. The schema and its
-- upgrades live in Data/Migrations. If DataStores are unavailable (for example Studio
-- without API access) the player plays with temporary data that is never saved.
--
-- Locks: a server never takes a profile that another live server still holds. It asks that
-- server to save and let go (MessagingService), waits up to LOCK_WAIT seconds, and only
-- takes over a lock older than LOCK_TIMEOUT (its server died without releasing it).

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Signal = require(Shared:WaitForChild("Signal"))

local Migrations = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Migrations"))

local ProfileRemote = Net.event("Profile")

local DataService = {}

-- Fired as (player, data) once a profile is ready.
DataService.ProfileLoaded = Signal.new()

local IS_STUDIO = RunService:IsStudio()
-- Never rename the live store: every saved profile is in it. Studio test runs use their own
-- store so they cannot touch live data.
local STORE_NAME = "LGamePlayerData_v1" .. (if IS_STUDIO then Config.STUDIO_DATASTORE_SUFFIX else "")
local RELEASE_TOPIC = "LGameRelease_v1"
local LOCK_TIMEOUT = 150 -- a lock this old belongs to a server that died without releasing it
local LOCK_WAIT = 30 -- how long a joining player waits for another server to let go
local AUTOSAVE_INTERVAL = 60 -- autosaves also refresh the lock time
local SAVE_SOON_DELAY = 5

type Profile = {
	data: any,
	key: string,
	persistent: boolean, -- loaded from the store, so it is saved
	readOnly: boolean, -- saved by a newer server version: never written
	loaded: boolean,
	saving: boolean,
	saveSoonQueued: boolean,
	released: boolean, -- handed over to another server: stop writing
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Inkbound] DataStore unavailable: " .. tostring(result))
	end
end

local function updateLeaderstats(player: Player, data)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		local rank = Instance.new("StringValue")
		rank.Name = "Rank"
		rank.Parent = folder
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Parent = folder
		folder.Parent = player
	end
	local _, rank = Ranks.forXp(data.xp)
	local rankValue = folder:FindFirstChild("Rank")
	if rankValue and rankValue:IsA("StringValue") then
		rankValue.Value = rank.name
	end
	local coinValue = folder:FindFirstChild("Coins")
	if coinValue and coinValue:IsA("IntValue") then
		coinValue.Value = data.coins
	end
end

function DataService.payload(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return nil
	end
	local data = profile.data
	local index, rank, nextRank = Ranks.forXp(data.xp)
	local owned = {}
	for id, isOwned in pairs(data.owned) do
		if isOwned then
			table.insert(owned, id)
		end
	end
	return {
		coins = data.coins,
		xp = data.xp,
		rankIndex = index,
		rankName = rank.name,
		rankXp = rank.xp,
		nextRankName = if nextRank then nextRank.name else nil,
		nextRankXp = if nextRank then nextRank.xp else nil,
		owned = owned,
		equipped = table.clone(data.equipped),
		stats = data.stats,
		settings = data.settings,
		persistent = profile.persistent,
	}
end

function DataService.push(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded or player.Parent ~= Players then
		return
	end
	updateLeaderstats(player, profile.data)
	ProfileRemote:FireClient(player, DataService.payload(player))
end

-- The live data table for a loaded player, or nil.
function DataService.get(player: Player)
	local profile = profiles[player]
	if profile and profile.loaded then
		return profile.data
	end
	return nil
end

-- True when changes to this player's data are saved (not temporary, not read-only).
function DataService.isPersistent(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.loaded and profile.persistent and not profile.readOnly and not profile.released
end

-- Saving ------------------------------------------------------------------------------------

-- One UpdateAsync. Returns true only when the data was written by this server.
local function write(profile: Profile, release: boolean): boolean
	local activeStore = store
	if not activeStore or not profile.persistent or profile.readOnly or profile.released then
		return false
	end
	local data = profile.data
	data.v = Migrations.CURRENT
	local owned = true
	local ok, err = pcall(function()
		activeStore:UpdateAsync(profile.key, function(old)
			owned = true
			local record = if type(old) == "table" then old else {}
			local lock = record.lock
			-- Another server owns this profile now, or a newer version saved it: never overwrite.
			if type(lock) == "table" and lock.job ~= game.JobId then
				owned = false
				return nil
			end
			if Migrations.version(record.data) > Migrations.CURRENT then
				owned = false
				return nil
			end
			record.data = data
			record.lock = if release then nil else { job = game.JobId, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[Inkbound] Saving data failed for " .. profile.key .. ": " .. tostring(err))
		return false
	end
	if not owned then
		warn("[Inkbound] Did not save " .. profile.key .. ": another server owns this profile.")
	end
	return owned
end

-- Saves of one profile never overlap: a second save waits for the first.
local function save(profile: Profile, release: boolean): boolean
	while profile.saving do
		task.wait(0.1)
	end
	profile.saving = true
	local ok = write(profile, release)
	profile.saving = false
	return ok
end

-- Saves right away. Returns true when the data is safely stored (use before granting a purchase).
function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return false
	end
	return save(profile, false)
end

-- Saves within a few seconds; several calls in a row cause one save.
function DataService.saveSoon(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.saveSoonQueued then
		return
	end
	profile.saveSoonQueued = true
	task.delay(SAVE_SOON_DELAY, function()
		profile.saveSoonQueued = false
		if profiles[player] == profile then
			save(profile, false)
		end
	end)
end

-- Loading ------------------------------------------------------------------------------------

local function requestRelease(userId: number, job: string)
	pcall(function()
		MessagingService:PublishAsync(RELEASE_TOPIC, { userId = userId, job = job })
	end)
end

local function load(player: Player)
	local key = "player_" .. player.UserId
	local profile: Profile = {
		data = Migrations.defaults(Config.STARTING_COINS),
		key = key,
		persistent = false,
		readOnly = false,
		loaded = false,
		saving = false,
		saveSoonQueued = false,
		released = false,
	}
	profiles[player] = profile

	local activeStore = store
	if activeStore then
		local started = os.clock()
		local askedRelease = false
		local failures = 0
		while player.Parent == Players do
			local lockedBy: string? = nil
			local newer = false
			local seen: any = nil
			local ok, err = pcall(function()
				activeStore:UpdateAsync(key, function(old)
					lockedBy, newer = nil, false
					local record = if type(old) == "table" then old else {}
					seen = record
					if Migrations.version(record.data) > Migrations.CURRENT then
						newer = true
						return nil
					end
					local lock = record.lock
					if type(lock) == "table" and lock.job ~= game.JobId then
						local age = os.time() - (tonumber(lock.time) or 0)
						if age < LOCK_TIMEOUT then
							lockedBy = tostring(lock.job)
							return nil
						end
					end
					record.lock = { job = game.JobId, time = os.time() }
					return record
				end)
			end)
			if ok and newer then
				profile.data = (Migrations.migrate(seen.data, Config.STARTING_COINS))
				profile.readOnly = true
				warn("[Inkbound] " .. key .. " was saved by a newer version; loading it read-only.")
				break
			elseif ok and lockedBy == nil then
				profile.data = (Migrations.migrate(seen and seen.data, Config.STARTING_COINS))
				profile.persistent = true
				break
			elseif ok then
				-- Another server still holds the profile: ask it to save and let go.
				if not askedRelease and lockedBy then
					askedRelease = true
					requestRelease(player.UserId, lockedBy)
				end
				if os.clock() - started > LOCK_WAIT then
					if profiles[player] == profile then
						profiles[player] = nil
					end
					player:Kick("Your case file is still saving in another server. Please rejoin in a minute.")
					return
				end
				task.wait(3)
			else
				failures += 1
				warn("[Inkbound] Loading data failed for " .. player.Name .. ": " .. tostring(err))
				if IS_STUDIO or failures >= 5 then
					break
				end
				task.wait(2)
			end
		end
	end

	if player.Parent ~= Players then
		if profile.persistent then
			save(profile, true)
		end
		if profiles[player] == profile then
			profiles[player] = nil
		end
		return
	end
	if not profile.persistent then
		warn("[Inkbound] Using temporary data for " .. player.Name .. " (progress will not be saved).")
	end
	profile.loaded = true
	DataService.push(player)
	DataService.ProfileLoaded:Fire(player, profile.data)
end

-- Another server wants a profile this server holds: the player is moving there.
local function onReleaseRequest(message)
	local payload = message.Data
	if type(payload) ~= "table" or payload.job ~= game.JobId then
		return
	end
	local userId = tonumber(payload.userId)
	if not userId then
		return
	end
	for player, profile in pairs(profiles) do
		if player.UserId == userId then
			if profile.loaded and not profile.released then
				save(profile, true)
				profile.released = true
			end
			return
		end
	end
	-- The player already left this server: clear any lock of ours that was left behind.
	local activeStore = store
	if activeStore then
		pcall(function()
			activeStore:UpdateAsync("player_" .. userId, function(old)
				if type(old) == "table" and type(old.lock) == "table" and old.lock.job == game.JobId then
					old.lock = nil
					return old
				end
				return nil
			end)
		end)
	end
end

-- Match rewards. The profile is saved a few seconds later.
function DataService.grant(player: Player, coins: number, xp: number, won: boolean, tasks: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.coins += coins
	data.xp += xp
	data.stats.matches += 1
	data.stats.tasks += tasks
	if won then
		data.stats.wins += 1
	end
	DataService.push(player)
	DataService.saveSoon(player)
end

function DataService.init()
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			if profile.loaded and not profile.released then
				save(profile, true)
			end
			if profiles[player] == profile then
				profiles[player] = nil
			end
		end
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(RELEASE_TOPIC, onReleaseRequest)
		end)
		if not ok and not IS_STUDIO then
			warn("[Inkbound] Profile release requests unavailable: " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, profile in pairs(profiles) do
				if profile.loaded then
					task.spawn(save, profile, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, profile in pairs(profiles) do
			if profile.loaded and not profile.released then
				pending += 1
				task.spawn(function()
					save(profile, true)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
