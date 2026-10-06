-- Lobby queue and matchmaking.
--   * Players press READY; party members queue together.
--   * When enough ready players are in this server, a countdown starts and the match
--     runs right here with up to 12 of them.
--   * In live servers, parties that cannot get a local match within a short wait are
--     also queued in a MemoryStore queue shared by all servers. One server at a time acts
--     as matchmaker: it reserves a private server and every lobby teleports its players
--     there, where they are readied automatically and the match starts.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local SpectateRules = require(Shared:WaitForChild("SpectateRules"))

local GhostService = require(script.Parent.GhostService)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Match)
local PartyService = require(script.Parent.PartyService)
local RateLimit = require(script.Parent.RateLimit)

local ReadyRemote = Net.event("Ready")

local Analytics = require(script.Parent.Analytics)
local LobbyStateRemote = Net.event("LobbyState")

local MatchmakingService = {}

local IS_STUDIO = RunService:IsStudio()
-- Never in private servers: it would teleport the owner's guests away.
local CROSS_SERVER = Config.CROSS_SERVER_MATCHMAKING
	and not IS_STUDIO
	and game.PlaceId ~= 0
	and not (game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0)

local QUEUE_TTL = 90
local ASSIGN_TTL = 120
local LOCK_TTL = 10
local CROSS_STEP = 3

local ready: { [Player]: number } = {} -- player -> time they readied
local tickets = {} -- key -> { members = { Player }, refreshed = number }
local countdownEnds: number? = nil
local matchRunning = false
local waitingThread: thread? = nil
local crossBusy = false

local queueMap: MemoryStoreSortedMap? = nil
local assignMap: MemoryStoreSortedMap? = nil
local lockMap: MemoryStoreSortedMap? = nil

local function minPlayers(): number
	return if IS_STUDIO then math.max(1, Config.STUDIO_MIN_PLAYERS) else Config.MIN_PLAYERS
end

-- Ready players grouped by party, oldest first.
local function readyGroups(): { { Player } }
	local list = {}
	for player, since in pairs(ready) do
		table.insert(list, { player = player, since = since })
	end
	table.sort(list, function(a, b)
		return a.since < b.since
	end)
	local seen = {}
	local groups = {}
	for _, entry in ipairs(list) do
		if not seen[entry.player] then
			local group = {}
			for _, member in ipairs(PartyService.membersOf(entry.player)) do
				if ready[member] and not seen[member] then
					seen[member] = true
					table.insert(group, member)
				end
			end
			if #group > 0 then
				table.insert(groups, group)
			end
		end
	end
	return groups
end

local function pickPlayers(): { Player }
	local chosen = {}
	for _, group in ipairs(readyGroups()) do
		if #chosen + #group <= Config.MAX_PLAYERS then
			for _, player in ipairs(group) do
				table.insert(chosen, player)
			end
		end
	end
	return chosen
end

local function ticketKey(group: { Player }): string
	local lowest = math.huge
	for _, player in ipairs(group) do
		lowest = math.min(lowest, player.UserId)
	end
	return "t" .. tostring(lowest)
end

local function ticketOf(player: Player)
	for key, ticket in pairs(tickets) do
		if table.find(ticket.members, player) then
			return key, ticket
		end
	end
	return nil, nil
end

local function removeTicket(key: string)
	if not tickets[key] then
		return
	end
	tickets[key] = nil
	local map = queueMap
	if map then
		task.spawn(function()
			pcall(function()
				map:RemoveAsync(key)
			end)
		end)
	end
end

local function unready(player: Player)
	ready[player] = nil
	local key = ticketOf(player)
	if key then
		removeTicket(key)
	end
end

function MatchmakingService.lobbyPayload(player: Player)
	local key = ticketOf(player)
	return {
		readyCount = #pickPlayers(),
		needed = minPlayers(),
		max = Config.MAX_PLAYERS,
		countdown = if countdownEnds then math.max(0, math.ceil(countdownEnds - os.clock())) else nil,
		-- A case may also have been started some other way (the debug panel); either way it is running.
		matchRunning = matchRunning or Match.active,
		ready = ready[player] ~= nil,
		watching = GhostService.isWatching(player),
		searching = key ~= nil,
		nextMap = MapService.nextMapName(),
	}
end

local function pushLobby()
	for _, player in ipairs(Players:GetPlayers()) do
		LobbyStateRemote:FireClient(player, MatchmakingService.lobbyPayload(player))
	end
end

-- Called by RoundService; yields until a group of players is ready to play.
function MatchmakingService.waitForMatch(): { Player }
	waitingThread = coroutine.running()
	return coroutine.yield()
end

function MatchmakingService.onMatchEnded()
	matchRunning = false
	countdownEnds = nil
	pushLobby()
end

local function startLocal(players: { Player })
	local thread = waitingThread
	if not thread then
		return
	end
	waitingThread = nil
	for _, player in ipairs(players) do
		unready(player)
	end
	matchRunning = true
	countdownEnds = nil
	pushLobby()
	task.spawn(thread, players)
end

-- Debug helpers (the debug panel and its test bots) ------------------------------------------

function MatchmakingService.setReady(player: any, on: boolean)
	if on then
		ready[player] = ready[player] or os.clock()
	else
		unready(player)
	end
	pushLobby()
end

function MatchmakingService.isReady(player: any): boolean
	return ready[player] ~= nil
end

-- True when a real player (not a test bot) is ready.
function MatchmakingService.humansReady(): boolean
	for player in pairs(ready) do
		if typeof(player) == "Instance" then
			return true
		end
	end
	return false
end

-- Starts a match at once with these players (no countdown). False if one is running.
function MatchmakingService.startNow(players: { any }): boolean
	if matchRunning or not waitingThread or #players == 0 then
		return false
	end
	startLocal(players)
	return true
end

function MatchmakingService.isRunning(): boolean
	return matchRunning
end

-- Cross-server --------------------------------------------------------------------------

local function teleportGroup(members: { Player }, code: string)
	local present = {}
	for _, player in ipairs(members) do
		if player.Parent == Players and ready[player] and not Match.get(player) then
			table.insert(present, player)
		end
	end
	if #present == 0 then
		return
	end
	for _, player in ipairs(present) do
		ready[player] = nil
		Match.notify(player, "Match found in another server. Teleporting...", "good")
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({
		lgameParty = if #present > 1 then ticketKey(present) .. "_" .. code else nil,
		autoReady = true,
	})
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, present, options)
	end)
	if not ok then
		warn("[DeathsGambit] Teleport failed: " .. tostring(err))
		for _, player in ipairs(present) do
			if player.Parent == Players then
				ready[player] = os.clock()
				Match.notify(player, "Teleport failed. You are back in the queue.", "bad")
			end
		end
	end
end

local function acquireLock(): boolean
	local map = lockMap
	if not map then
		return false
	end
	local ok, result = pcall(function()
		return map:UpdateAsync("matchmaker", function(old)
			local now = os.time()
			if old == nil or old.job == game.JobId or (tonumber(old.expires) or 0) < now then
				return { job = game.JobId, expires = now + LOCK_TTL }
			end
			return nil
		end, LOCK_TTL)
	end)
	return ok and type(result) == "table" and result.job == game.JobId
end

-- Runs on the one server that holds the lock: groups queued parties from all servers.
local function runMatchmaker()
	local queue = queueMap
	local assign = assignMap
	if not queue or not assign then
		return
	end
	local ok, items = pcall(function()
		return queue:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or type(items) ~= "table" then
		return
	end
	local entries = {}
	for _, item in ipairs(items) do
		local value = item.value
		if type(value) == "table" and type(value.users) == "table" and #value.users > 0 then
			table.insert(entries, { key = item.key, size = #value.users, queued = tonumber(value.queued) or 0 })
		end
	end
	table.sort(entries, function(a, b)
		return a.queued < b.queued
	end)
	local chosen = {}
	local total = 0
	for _, entry in ipairs(entries) do
		if total + entry.size <= Config.MAX_PLAYERS then
			table.insert(chosen, entry)
			total += entry.size
		end
	end
	if total < Config.MIN_PLAYERS then
		return
	end
	local okReserve, code = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	if not okReserve or type(code) ~= "string" then
		warn("[DeathsGambit] Could not reserve a match server: " .. tostring(code))
		return
	end
	for _, entry in ipairs(chosen) do
		pcall(function()
			queue:RemoveAsync(entry.key)
		end)
		pcall(function()
			assign:SetAsync(entry.key, { code = code }, ASSIGN_TTL)
		end)
	end
end

local function crossServerStepUnsafe()
	local queue = queueMap
	local assign = assignMap
	if not queue or not assign then
		return
	end
	-- 1. Queue groups that could not get a local match in time.
	local localPossible = not matchRunning and #pickPlayers() >= minPlayers()
	if localPossible then
		-- Enough players here: play locally instead of in another server.
		for key in pairs(table.clone(tickets)) do
			removeTicket(key)
		end
	else
		for _, group in ipairs(readyGroups()) do
			local oldest = math.huge
			for _, player in ipairs(group) do
				oldest = math.min(oldest, ready[player] or math.huge)
			end
			if os.clock() - oldest >= Config.CROSS_SERVER_AFTER then
				local key = ticketKey(group)
				local ticket = tickets[key]
				if not ticket or os.clock() - ticket.refreshed > 30 then
					local users = {}
					for _, player in ipairs(group) do
						table.insert(users, player.UserId)
					end
					local ok = pcall(function()
						queue:SetAsync(key, { users = users, job = game.JobId, queued = os.time() }, QUEUE_TTL)
					end)
					if ok then
						tickets[key] = { members = group, refreshed = os.clock() }
					end
				end
			end
		end
	end
	-- 2. Pick up assignments for our tickets.
	for key, ticket in pairs(table.clone(tickets)) do
		local ok, assignment = pcall(function()
			return assign:GetAsync(key)
		end)
		if ok and type(assignment) == "table" and type(assignment.code) == "string" then
			pcall(function()
				assign:RemoveAsync(key)
			end)
			tickets[key] = nil
			task.spawn(teleportGroup, ticket.members, assignment.code)
		end
	end
	-- 3. Act as the matchmaker when this server holds the lock.
	if acquireLock() then
		runMatchmaker()
	end
end

-- One step at a time; MemoryStore calls can be slow.
local function crossServerStep()
	if crossBusy then
		return
	end
	crossBusy = true
	local ok, err = pcall(crossServerStepUnsafe)
	crossBusy = false
	if not ok then
		warn("[DeathsGambit] Matchmaking step failed: " .. tostring(err))
	end
end

-- Lobby loop ------------------------------------------------------------------------------

local function onReady(player: Player, wantReady)
	if type(wantReady) ~= "boolean" or not RateLimit.allow(player, "ready", 0.5) then
		return
	end
	if Match.getLiving(player) then
		return
	end
	-- Spectators leave the match before they can queue for the next one.
	if wantReady and GhostService.isWatching(player) then
		return
	end
	if wantReady then
		Analytics.step(player, "ready")
	end
	for _, member in ipairs(PartyService.membersOf(player)) do
		if Match.getLiving(member) == nil then
			-- A party queues together: a member who is watching comes back to the lobby.
			if wantReady and SpectateRules.pullOnReady(member, player, GhostService.isWatching(member)) then
				GhostService.unwatch(member)
				Match.notify(member, "Your party readied up, so you left spectating.", "info")
			end
			if wantReady then
				ready[member] = ready[member] or os.clock()
			else
				unready(member)
			end
		end
	end
	pushLobby()
end

local function onPlayerAdded(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if
		ok
		and type(joinData) == "table"
		and type(joinData.TeleportData) == "table"
		and joinData.TeleportData.autoReady
	then
		ready[player] = os.clock()
	end
	pushLobby()
end

function MatchmakingService.init()
	if CROSS_SERVER then
		local ok, err = pcall(function()
			queueMap = MemoryStoreService:GetSortedMap("LGameQueue_v1")
			assignMap = MemoryStoreService:GetSortedMap("LGameAssign_v1")
			lockMap = MemoryStoreService:GetSortedMap("LGameLock_v1")
		end)
		if not ok then
			warn("[DeathsGambit] Cross-server matchmaking disabled: " .. tostring(err))
			queueMap = nil
			assignMap = nil
			lockMap = nil
		end
	end

	ReadyRemote.OnServerEvent:Connect(onReady)
	GhostService.setQueueCheck(function(player)
		return ready[player] ~= nil
	end)
	-- The lobby's SPECTATE button follows whether you are watching.
	Net.event("Watch").OnServerEvent:Connect(function()
		task.defer(pushLobby)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		unready(player)
		pushLobby()
	end)
	PartyService.Changed:Connect(function(affected)
		for _, player in ipairs(affected) do
			unready(player)
		end
		pushLobby()
	end)

	task.spawn(function()
		local sinceCross = 0
		while true do
			if not matchRunning then
				local count = #pickPlayers()
				if count >= minPlayers() then
					if not countdownEnds then
						countdownEnds = os.clock() + Config.LOBBY_COUNTDOWN
					elseif os.clock() >= countdownEnds then
						local players = pickPlayers()
						if #players >= minPlayers() and waitingThread then
							startLocal(players)
						end
					end
				else
					countdownEnds = nil
				end
			end
			sinceCross += 1
			if queueMap and sinceCross >= CROSS_STEP then
				sinceCross = 0
				task.spawn(crossServerStep)
			end
			pushLobby()
			task.wait(1)
		end
	end)
end

return MatchmakingService
