-- Persistent player data (coins, experience, owned and equipped cosmetics) in a
-- DataStore with session locking: a server claims a profile while the player is in it,
-- so two servers never overwrite each other. If DataStores are unavailable (for example
-- Studio without API access) the player plays with temporary data.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Signal = require(Shared:WaitForChild("Signal"))

local ProfileRemote = Net.event("Profile")

local DataService = {}

-- Fired as (player, data) once a profile is ready.
DataService.ProfileLoaded = Signal.new()

local STORE_NAME = "LGamePlayerData_v1"
local LOCK_TIMEOUT = 150
local AUTOSAVE_INTERVAL = 60
local IS_STUDIO = RunService:IsStudio()

local profiles = {} -- [Player] = { data, persistent, key, loaded }
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[L game] DataStore unavailable: " .. tostring(result))
	end
end

local function defaultData()
	return {
		coins = Config.STARTING_COINS,
		xp = 0,
		owned = {},
		equipped = {},
		stats = { matches = 0, wins = 0, tasks = 0 },
	}
end

local function reconcile(data)
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end
	if type(data.coins) ~= "number" then
		data.coins = base.coins
	end
	if type(data.xp) ~= "number" then
		data.xp = base.xp
	end
	if type(data.owned) ~= "table" then
		data.owned = base.owned
	end
	if type(data.equipped) ~= "table" then
		data.equipped = base.equipped
	end
	if type(data.stats) ~= "table" then
		data.stats = base.stats
	end
	for key, value in pairs(base.stats) do
		if type(data.stats[key]) ~= "number" then
			data.stats[key] = value
		end
	end
	return data
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
		equipped = { hat = data.equipped.hat, trail = data.equipped.trail },
		stats = data.stats,
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

local function save(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.persistent or not store then
		return
	end
	local data = profile.data
	local ok, err = pcall(function()
		store:UpdateAsync(profile.key, function(old)
			local record = if type(old) == "table" then old else {}
			local lock = record.lock
			if type(lock) == "table" and lock.job ~= game.JobId then
				-- Another server owns this profile now; never overwrite its data.
				return nil
			end
			record.data = data
			if release then
				record.lock = nil
			else
				record.lock = { job = game.JobId, time = os.time() }
			end
			return record
		end)
	end)
	if not ok then
		warn("[L game] Saving data failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function load(player: Player)
	local key = "player_" .. player.UserId
	local profile = { data = defaultData(), persistent = false, key = key, loaded = false }
	profiles[player] = profile

	if store then
		for attempt = 1, 5 do
			local lockedElsewhere = false
			local ok, result = pcall(function()
				return store:UpdateAsync(key, function(old)
					lockedElsewhere = false
					local record = if type(old) == "table" then old else {}
					local lock = record.lock
					if type(lock) == "table" and lock.job ~= game.JobId then
						local age = os.time() - (tonumber(lock.time) or 0)
						-- On the last attempt the lock is taken over.
						if age < LOCK_TIMEOUT and attempt < 5 then
							lockedElsewhere = true
							return nil
						end
					end
					record.lock = { job = game.JobId, time = os.time() }
					return record
				end)
			end)
			if ok and type(result) == "table" then
				profile.data = reconcile(result.data)
				profile.persistent = true
				break
			end
			if not ok then
				warn("[L game] Loading data failed for " .. player.Name .. ": " .. tostring(result))
				if IS_STUDIO then
					break
				end
			end
			if player.Parent ~= Players then
				break
			end
			task.wait(if lockedElsewhere then 4 else 2)
		end
	end

	if player.Parent ~= Players then
		save(player, true)
		profiles[player] = nil
		return
	end
	if not profile.persistent then
		warn("[L game] Using temporary data for " .. player.Name .. " (progress will not be saved).")
	end
	profile.loaded = true
	DataService.push(player)
	DataService.ProfileLoaded:Fire(player, profile.data)
end

-- Adds match rewards.
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
end

function DataService.init()
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			save(player, true)
			profiles[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in pairs(profiles) do
				if profile.loaded then
					task.spawn(save, player, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
