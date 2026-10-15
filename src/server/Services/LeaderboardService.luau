-- Global leaderboards (all-time wins, experience, this week's wins, and the lobby mini-games'
-- fastest Spire Ascent, most rune rounds, fastest spirit trial and the rift's smallest gap) in ordered data stores. Scores are
-- written as absolute values, gathered up and flushed every 20 seconds within the request budget; the
-- top 10 are read every 5 minutes and shown in the Leaderboards panel. One board is also written in the
-- world: Most Wins, on its slab in the lobby (and the player at its top sits on the throne, in stone:
-- client World/Champion).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LastBreath = require(Shared:WaitForChild("LobbyGames"):WaitForChild("LastBreath"))
local Parkour = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Parkour"))
local Net = require(Shared:WaitForChild("Net"))
local TimeUtil = require(Shared:WaitForChild("Progression"):WaitForChild("TimeUtil"))

local LeaderboardRemote = Net.event("Leaderboard")

local LeaderboardService = {}

local FLUSH_EVERY = 20
local READ_EVERY = 300
local TOP = 10
local SUFFIX = if RunService:IsStudio() then Config.STUDIO_DATASTORE_SUFFIX else ""

type Entry = { rank: number, userId: number, name: string, value: number }

local pending: { [number]: { wins: number, xp: number, weekly: number, week: number } } = {}
-- The mini-games' newly improved bests, written on the next flush: the Spire Ascent and the spirit trial in
-- centiseconds (lower is better), the rune rounds cleared, and the rift's smallest gap in hundredths of a
-- stud (lower is better).
local extra: { [number]: { parkour: number?, runes: number?, spirit: number?, rift: number? } } = {}
local boards: { [string]: { Entry } } =
	{ wins = {}, xp = {}, weekly = {}, parkour = {}, runes = {}, spirit = {}, rift = {} }
-- Boards where the lowest score is the best.
local LOWEST = { parkour = true, spirit = true, rift = true }
local nameCache: { [number]: string } = {}
local labels: { [string]: TextLabel } = {}
local enabled = true

-- The stores that are not a week's: board -> name.
local STORES = {
	wins = "LGameLB_Wins_v1",
	xp = "LGameLB_Xp_v1",
	parkour = "LGameLB_Parkour_v1",
	runes = "LGameLB_Runes_v1",
	spirit = "LGameLB_Spirit_v1",
	-- (v2: the dive became about 650 studs deep on 2026-10-15; the old board measured a 205-stud fall.)
	rift = "LGameLB_Rift_v2",
}
-- Until the spirit trial had a store of its own, its times fell through to the weekly store's name with no
-- week ("..._Wnil"). They are copied across once (see moveSpirit).
local OLD_SPIRIT = "LGameLB_Wins_Wnil"

local function store(board: string, week: number?): OrderedDataStore
	local name = STORES[board]
	if name then
		return DataStoreService:GetOrderedDataStore(name .. SUFFIX)
	end
	assert(board == "weekly" and week ~= nil, "no leaderboard store for " .. tostring(board))
	return DataStoreService:GetOrderedDataStore("LGameLB_Wins_W" .. tostring(week) .. SUFFIX)
end

-- The spirit trial's old times, brought to its own store: only while that store is still empty, so it
-- happens once (and never writes over a newer time).
local function moveSpirit()
	local ok, err = pcall(function()
		if #store("spirit"):GetSortedAsync(true, 1):GetCurrentPage() > 0 then
			return
		end
		local old = DataStoreService:GetOrderedDataStore(OLD_SPIRIT .. SUFFIX)
		for _, row in ipairs(old:GetSortedAsync(true, TOP):GetCurrentPage()) do
			store("spirit"):SetAsync(row.key, row.value)
		end
	end)
	-- (Quiet where the stores cannot be reached at all: a Studio place without API access.)
	if not ok and not string.find(tostring(err), "not allowed", 1, true) then
		warn("[DeathsGambit] Could not move the spirit trial's old times: " .. tostring(err))
	end
end

-- Remembers a player's latest scores; they are written on the next flush.
function LeaderboardService.queue(player: Player, data)
	if not data then
		return
	end
	pending[player.UserId] = {
		wins = data.stats.wins,
		xp = data.xp,
		weekly = data.weekly.wins,
		week = data.weekly.week,
	}
end

-- Players whose mini-game bests must wait (a Specter waiting in the lobby: a new best on the public board
-- could give them away). Held bests are written once the hold is lifted.
local held: { [number]: boolean } = {}

function LeaderboardService.hold(userId: number, on: boolean)
	held[userId] = if on then true else nil
end

-- Remembers a mini-game best that just improved ("parkour": seconds, lower is better; "runes": rounds).
function LeaderboardService.record(player: Player, board: string, value: number)
	local mine = extra[player.UserId]
	if not mine then
		mine = {}
		extra[player.UserId] = mine
	end
	if board == "parkour" then
		mine.parkour = math.floor(value * 100 + 0.5)
	elseif board == "runes" then
		mine.runes = math.floor(value)
	elseif board == "spirit" then
		mine.spirit = math.floor(value * 100 + 0.5)
	elseif board == "rift" then
		mine.rift = LastBreath.score(value)
	end
end

local function budget(): number
	return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync)
end

local function flush()
	local currentWeek = TimeUtil.week(TimeUtil.now())
	for userId, scores in pairs(pending) do
		if budget() < 6 then
			return
		end
		pending[userId] = nil
		local key = tostring(userId)
		local ok, err = pcall(function()
			store("wins"):SetAsync(key, math.floor(scores.wins))
			store("xp"):SetAsync(key, math.floor(scores.xp))
			if scores.week == currentWeek then
				store("weekly", currentWeek):SetAsync(key, math.floor(scores.weekly))
			end
		end)
		if not ok then
			warn("[DeathsGambit] Could not save leaderboard scores: " .. tostring(err))
			enabled = not string.find(tostring(err), "not allowed", 1, true)
			return
		end
	end
end

local function flushGames()
	for userId, scores in pairs(extra) do
		if budget() < 6 then
			return
		end
		if held[userId] then
			continue
		end
		extra[userId] = nil
		local key = tostring(userId)
		local ok, err = pcall(function()
			if scores.parkour then
				store("parkour"):SetAsync(key, scores.parkour)
			end
			if scores.runes then
				store("runes"):SetAsync(key, scores.runes)
			end
			if scores.spirit then
				store("spirit"):SetAsync(key, scores.spirit)
			end
			if scores.rift then
				store("rift"):SetAsync(key, scores.rift)
			end
		end)
		if not ok then
			warn("[DeathsGambit] Could not save mini-game scores: " .. tostring(err))
			enabled = not string.find(tostring(err), "not allowed", 1, true)
			return
		end
	end
end

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function readBoard(board: string, week: number?): { Entry }
	local entries = {}
	local ok, pages = pcall(function()
		return store(board, week):GetSortedAsync(LOWEST[board] == true, TOP)
	end)
	if not ok or not pages then
		return entries
	end
	for index, row in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(row.key) or 0
		table.insert(entries, { rank = index, userId = userId, name = nameOf(userId), value = row.value })
	end
	return entries
end

local TITLES = {
	wins = "MOST WINS",
	xp = "MOST EXPERIENCE",
	weekly = "WINS THIS WEEK",
	parkour = "FASTEST ASCENT",
	runes = "MOST RUNES CLEARED",
	spirit = "FASTEST SPIRIT TRIAL",
	rift = "LAST BREATH",
}

local function renderLabels()
	for board, label in pairs(labels) do
		local lines = { TITLES[board] or string.upper(board), "" }
		for _, entry in ipairs(boards[board] or {}) do
			local value = if board == "rift"
				then LastBreath.formatScore(entry.value)
				elseif board == "parkour" or board == "spirit" then Parkour.formatCentis(entry.value)
				else tostring(entry.value)
			table.insert(lines, string.format("%d. %s  %s", entry.rank, entry.name, value))
		end
		if #(boards[board] or {}) == 0 then
			table.insert(lines, "No scores yet.")
		end
		label.Text = table.concat(lines, "\n")
	end
end

local function read()
	local week = TimeUtil.week(TimeUtil.now())
	boards = {
		wins = readBoard("wins"),
		xp = readBoard("xp"),
		weekly = readBoard("weekly", week),
		parkour = readBoard("parkour"),
		runes = readBoard("runes"),
		spirit = readBoard("spirit"),
		rift = readBoard("rift"),
	}
	renderLabels()
	LeaderboardRemote:FireAllClients(boards)
end

-- The boards in the world to write into, by board (the lobby has one: { wins = label }).
function LeaderboardService.setLabels(newLabels: { [string]: TextLabel })
	labels = newLabels
	renderLabels()
end

function LeaderboardService.init()
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent == Players then
				LeaderboardRemote:FireClient(player, boards)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nameCache[player.UserId] = player.DisplayName
	end)
	task.spawn(function()
		task.wait(8)
		moveSpirit()
		local sinceRead = READ_EVERY
		while enabled do
			pcall(flush)
			pcall(flushGames)
			if sinceRead >= READ_EVERY then
				sinceRead = 0
				pcall(read)
			end
			task.wait(FLUSH_EVERY)
			sinceRead += FLUSH_EVERY
		end
	end)
	game:BindToClose(function()
		if enabled then
			pcall(flush)
			pcall(flushGames)
		end
	end)
end

return LeaderboardService
