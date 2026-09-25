-- The debug panel's server side (F2 in a play test). It lets a tester drive every part of the
-- game alone: start a match at once on any map, skip or pause phases, change roles mid-match,
-- kill / vote out / arrest / revive anyone, hand out the Eyes, hoods and paper, force letter
-- flashes, add test bots that play, preview maps and cutscenes, and change the profile.
--
-- Who may use it: everyone in a Studio play test (Config.STUDIO_DEBUG), and in live servers
-- only the user ids in Config.DEBUG_USER_IDS. Test bots exist in Studio only. Allowed players
-- get the attribute LDebug, which shows the panel on their screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local RoleLogic = require(Shared:WaitForChild("RoleLogic"))
local Terms = require(Shared:WaitForChild("Terms"))
local TimeUtil = require(Shared:WaitForChild("Progression"):WaitForChild("TimeUtil"))

local Server = script.Parent.Parent
local Migrations = require(Server:WaitForChild("Data"):WaitForChild("Migrations"))
local Maps = Server:WaitForChild("Maps")
local MapContract = require(Maps:WaitForChild("MapContract"))
local SceneBuilder = require(Maps:WaitForChild("SceneBuilder"))

local CaseFileService = require(script.Parent.CaseFileService)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local DeathNoteService = require(script.Parent.DeathNoteService)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local EyesService = require(script.Parent.EyesService)
local GhostService = require(script.Parent.GhostService)
local HoodService = require(script.Parent.HoodService)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Match)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MonetizationService = require(script.Parent.MonetizationService)
local NameService = require(script.Parent.NameService)
local NoteService = require(script.Parent.NoteService)
local PassService = require(script.Parent.PassService)
local RoleService = require(script.Parent.RoleService)
local RoundService = require(script.Parent.RoundService)
local ServerSettings = require(script.Parent.ServerSettings)
local SuspicionService = require(script.Parent.SuspicionService)
local VoteService = require(script.Parent.VoteService)
local WarrantService = require(script.Parent.WarrantService)

local Bots = require(Server:WaitForChild("Debug"):WaitForChild("Bots"))

local DebugRemote = Net.event("Debug")
local BriefingRemote = Net.event("Briefing")
local RevealRemote = Net.event("Reveal")

local DebugService = {}

local IS_STUDIO = RunService:IsStudio()
DebugService.ENABLED = (IS_STUDIO and Config.STUDIO_DEBUG == true) or #(Config.DEBUG_USER_IDS or {}) > 0

local watching: { [Player]: boolean } = {}
local previewInfo = nil

function DebugService.allowed(player: Player): boolean
	if IS_STUDIO and Config.STUDIO_DEBUG == true then
		return true
	end
	return table.find(Config.DEBUG_USER_IDS or {}, player.UserId) ~= nil
end

local function reply(player: Player, text: string, kind: string?)
	Match.notify(player, "[debug] " .. text, kind or "secret")
end

-- Everyone who can be targeted: the match's players first, then the rest of the server.
local function person(userId: any)
	if type(userId) ~= "number" then
		return nil, nil
	end
	local ps = Match.getByUserId(userId)
	local player = if ps then ps.player else Players:GetPlayerByUserId(userId) or Bots.byUserId(userId)
	return ps, player
end

local function rootOf(player: any): BasePart?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function teleport(player: any, cframe: CFrame)
	local character = player and player.Character
	if character then
		character:PivotTo(cframe + Vector3.new(0, 3, 0))
	end
end

-- Snapshot -----------------------------------------------------------------------------------

local function snapshot(viewer: Player)
	if Match.active then
		previewInfo = nil -- a match replaced the preview
	end
	local people = {}
	local seen = {}
	local function add(player: any)
		if not player or seen[player] then
			return
		end
		seen[player] = true
		local ps = Match.get(player)
		table.insert(people, {
			userId = player.UserId,
			name = player.Name,
			alias = if ps then ps.alias else nil,
			role = if ps then ps.role else nil,
			realName = if ps then ps.realName else nil,
			alive = if ps then ps.alive else nil,
			status = if ps then ps.status else nil,
			bot = Bots.is(player),
			me = player == viewer,
			ready = MatchmakingService.isReady(player),
			eyes = if ps and ps.eyes then ps.eyes.readsLeft else nil,
			hood = ps ~= nil and Match.hasHood(ps),
			carrying = if ps and ps.carrying then ps.carrying.kind else nil,
			tasks = if ps then ps.tasksThisRound else nil,
			suspicion = if ps then SuspicionService.get(ps) else nil,
			forced = RoleService.debugForced[player.UserId],
		})
	end
	for _, ps in ipairs(Match.list) do
		add(ps.player)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		add(player)
	end
	for _, bot in ipairs(Bots.list) do
		add(bot)
	end
	local passes = {}
	for _, pass in ipairs(Products.PASSES) do
		table.insert(passes, { key = pass.key, name = pass.name, owned = PassService.owns(viewer, pass.key) })
	end
	local roles = {}
	for _, id in ipairs(RoleLogic.ALL) do
		table.insert(roles, { id = id, name = Terms.role(id, "Name") })
	end
	local data = DataService.get(viewer)
	local places = { stations = {}, areas = {} }
	local map = Match.map or previewInfo
	if map then
		for _, station in ipairs(map.stations or {}) do
			table.insert(places.stations, { id = station.id, name = station.name })
		end
		for _, area in ipairs(map.areas or {}) do
			table.insert(places.areas, area.name)
		end
	end
	return {
		places = places,
		match = {
			active = Match.active,
			phase = Match.phase,
			round = Match.round,
			endsAt = Match.phaseEndsAt,
			paused = Match.debugPaused,
			mapId = Match.mapId,
			mapName = Match.mapName,
			winner = Match.winner,
			nextMap = MapService.nextMapId(),
			running = MatchmakingService.isRunning(),
			butlerHint = Match.butlerHint,
		},
		settings = {
			timeScale = Config.STUDIO_TIME_SCALE,
			skipCutscenes = Config.STUDIO_SKIP_PRESENTATION,
			scenes = not SceneBuilder.disabled,
			botsAuto = Bots.autoPlay,
			botsKill = Bots.handKills,
			voteTarget = Bots.voteTarget,
			botsAllowed = IS_STUDIO,
			previewing = previewInfo ~= nil,
		},
		people = people,
		maps = MapService.list(),
		roles = roles,
		passes = passes,
		profile = if data then { coins = data.coins, xp = data.xp } else nil,
	}
end

local function pushSnapshots()
	for player in pairs(watching) do
		if player.Parent == Players then
			DebugRemote:FireClient(player, "snapshot", snapshot(player))
		else
			watching[player] = nil
		end
	end
end

-- Commands -------------------------------------------------------------------------------------

local function needMatch(player: Player): boolean
	if not Match.active then
		reply(player, "No match is running.", "bad")
		return false
	end
	return true
end

local function needTarget(player: Player, args): any
	local ps = Match.getByUserId(if type(args) == "table" then args.userId else nil)
	if not ps then
		reply(player, "Pick someone who is in the match.", "bad")
	end
	return ps
end

local UNIQUE = { Kira = true, L = true, Watari = true }

local PHASES = { Intro = true, Briefing = true, Investigation = true, DeathNote = true, Meeting = true, Vote = true }
-- The order of the phases inside a round.
local ROUND_ORDER = { Investigation = 1, DeathNote = 2, Meeting = 3, Vote = 4, Verdict = 5 }

local COMMANDS: { [string]: (Player, any) -> () } = {}

-- Match flow

COMMANDS.startMatch = function(player)
	if MatchmakingService.isRunning() then
		reply(player, "A match is already running.", "bad")
		return
	end
	if previewInfo then
		MapService.destroy()
		previewInfo = nil
	end
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		table.insert(list, other)
	end
	for _, bot in ipairs(Bots.list) do
		table.insert(list, bot)
	end
	while #list > Config.MAX_PLAYERS do
		table.remove(list)
	end
	if MatchmakingService.startNow(list) then
		reply(player, string.format("Starting on %s with %d players.", MapService.nextMapName(), #list), "good")
	else
		reply(player, "Could not start (the match loop is busy).", "bad")
	end
end

COMMANDS.nextMap = function(player, args)
	if type(args) == "table" and MapService.forceNext(tostring(args.mapId)) then
		reply(player, "The next match is on " .. MapService.nextMapName() .. ".", "good")
	end
end

COMMANDS.nextPhase = function(player)
	if needMatch(player) then
		Match.phaseEndsAt = workspace:GetServerTimeNow()
		reply(player, "Ending " .. Terms.phase(Match.phase) .. ".")
	end
end

COMMANDS.skipTo = function(player, args)
	if not needMatch(player) or type(args) ~= "table" or not PHASES[args.phase] then
		return
	end
	local round = if type(args.round) == "number" then math.floor(args.round) else nil
	local phase = args.phase
	if (phase == "Intro" or phase == "Briefing") and Match.phase ~= "Intro" then
		reply(player, "The intro and briefing only come once, at the start.", "bad")
		return
	end
	if round then
		local here = ROUND_ORDER[Match.phase] or 0
		local later = round > Match.round or (round == Match.round and (ROUND_ORDER[phase] or 0) > here)
		if not later or round > ServerSettings.rounds() then
			reply(player, "That point of the match has passed (or does not exist).", "bad")
			return
		end
	end
	Match.debugSkipTo = { phase = phase, round = round }
	Match.phaseEndsAt = workspace:GetServerTimeNow()
	reply(player, "Skipping to " .. Terms.phase(args.phase) .. (if round then " of round " .. round else "") .. ".")
end

COMMANDS.pause = function(player)
	if needMatch(player) then
		Match.debugPaused = not Match.debugPaused
		Match.pushState()
		reply(player, if Match.debugPaused then "Phase timer paused." else "Phase timer running.")
	end
end

COMMANDS.addTime = function(player, args)
	if not needMatch(player) then
		return
	end
	local seconds = if type(args) == "table" then tonumber(args.seconds) or 0 else 0
	local now = workspace:GetServerTimeNow()
	Match.phaseEndsAt = math.max(now + 1, Match.phaseEndsAt + seconds)
	Match.pushState()
	reply(player, string.format("%+d s (%d s left).", seconds, math.floor(Match.phaseEndsAt - now)))
end

COMMANDS.timeScale = function(player, args)
	local scale = if type(args) == "table" then tonumber(args.value) else nil
	if scale and scale > 0 then
		Config.STUDIO_TIME_SCALE = scale
		reply(player, string.format("Phase lengths x%.2f (from the next phase on).", scale))
	end
end

COMMANDS.skipCutscenes = function(player)
	Config.STUDIO_SKIP_PRESENTATION = not Config.STUDIO_SKIP_PRESENTATION
	reply(player, if Config.STUDIO_SKIP_PRESENTATION then "Cutscene phases skipped." else "Cutscene phases play.")
end

COMMANDS.win = function(player, args)
	if not needMatch(player) then
		return
	end
	local side = if type(args) == "table" and args.side == "Kira" then "Kira" else "Team"
	Match.declareWinner(side, "Debug: forced win.")
	reply(player, (if side == "Kira" then Terms.role("Kira", "Name") else Terms.side("Team", "Name")) .. " wins.")
end

COMMANDS.endMatch = function(player)
	if not needMatch(player) then
		return
	end
	Match.debugFastEnd = true
	Match.debugSkipTo = nil
	Match.declareWinner("Team", "Debug: the match was ended.")
	Match.phaseEndsAt = workspace:GetServerTimeNow()
	reply(player, "Ending the match (no outro).")
end

-- Roles

COMMANDS.setRole = function(player, args)
	if not needMatch(player) then
		return
	end
	local ps = needTarget(player, args)
	local role = if type(args) == "table" then args.role else nil
	if not ps or not table.find(RoleLogic.ALL, role) then
		return
	end
	local old = ps.role
	if old == role then
		return
	end
	-- Unique roles swap with whoever held them, so there is still one Hand, Zero and Butler.
	if UNIQUE[role] then
		for _, other in ipairs(Match.list) do
			if other ~= ps and other.role == role then
				other.role = old
				Match.notify(other.player, "[debug] Your role is now " .. Terms.role(old, "Name") .. ".", "secret")
			end
		end
	end
	ps.role = role
	ps.dnRound = 0
	ps.warrantUsed = false
	ps.warrantBlockedRound = 0
	ps.tamperRound = 0
	if role == "Kira" or old == "Kira" then
		Match.butlerHint = NameService.watariHint()
	end
	EventLog.add(string.format("Debug: %s became %s.", ps.alias, Terms.role(role, "a")), "role")
	Match.pushAllPrivate()
	Match.notify(ps.player, "[debug] Your role is now " .. Terms.role(role, "Name") .. ".", "secret")
	reply(player, string.format("%s is now %s.", ps.alias, Terms.role(role, "Name")), "good")
end

COMMANDS.forceRole = function(player, args)
	if type(args) ~= "table" or type(args.userId) ~= "number" then
		return
	end
	local role = args.role
	if role == nil or role == "" then
		RoleService.debugForced[args.userId] = nil
		reply(player, "Role for the next match: random.")
	elseif table.find(RoleLogic.ALL, role) then
		RoleService.debugForced[args.userId] = role
		reply(player, "Role for the next match: " .. Terms.role(role, "Name") .. ".")
	end
end

-- People

COMMANDS.kill = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		local cause = if type(args.cause) == "string" and table.find(Config.DEATH_CAUSES, args.cause)
			then args.cause
			else "Heart attack"
		DeathNoteService.debugKill(ps, cause)
	end
end

COMMANDS.voteOut = function(player, args)
	local ps = needTarget(player, args)
	if not ps or not ps.alive then
		return
	end
	-- The real verdict: cutscene, announcement, and removal at the climax.
	VoteService.present({
		counts = { { name = ps.alias, count = 3, userId = ps.userId }, { name = "Skip", count = 1 } },
		removed = ps,
		votesAgainst = 3,
		valid = {},
		tie = false,
		total = 4,
	})
end

COMMANDS.arrest = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		WarrantService.debugServe(ps)
	end
end

COMMANDS.leave = function(player, args)
	local ps, target = person(if type(args) == "table" then args.userId else nil)
	if Bots.is(target) then
		Bots.remove(target)
		reply(player, target.Name .. " removed.")
	elseif ps and ps.alive then
		Elimination.eliminate(ps, "left", nil, ps.alias .. " left the investigation.", {})
		Match.announce(ps.alias .. " left the case", "They disconnected.", "neutral")
	end
end

COMMANDS.revive = function(player, args)
	local ps = needTarget(player, args)
	if not ps or ps.alive then
		return
	end
	ps.alive = true
	ps.status = "alive"
	ps.cause = nil
	ps.eliminatedRound = nil
	GhostService.forget(ps.player)
	local character = ps.player.Character
	if character then
		character:SetAttribute("LHeldBody", nil)
		character:SetAttribute("Specter", nil)
	end
	CharacterService.load(ps.player)
	Match.pushState()
	Match.pushAllPrivate()
	reply(player, ps.alias .. " is alive again.", "good")
end

COMMANDS.eyes = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		EyesService.debugGrant(ps)
		reply(player, ps.alias .. " has the Specter's Eyes.")
	end
end

COMMANDS.hood = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		HoodService.debugWear(ps)
	end
end

COMMANDS.sheet = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		reply(player, if NoteService.debugGiveSheet(ps) then "Blank sheet given." else "They already carry paper.")
	end
end

COMMANDS.flash = function(player, args)
	local ps = needTarget(player, args)
	if ps and ps.alive then
		local station = CaseFileService.debugFlash(ps)
		reply(player, if station then "Case file finished at " .. station .. "." else "No station nearby.")
	end
end

COMMANDS.suspicion = function(player, args)
	local ps = needTarget(player, args)
	if ps then
		SuspicionService.add(ps, tonumber(args.amount) or 20)
		SuspicionService.push()
	end
end

COMMANDS.freeze = function(player, args)
	local _, target = person(if type(args) == "table" then args.userId else nil)
	if target then
		CharacterService.setFrozen(target, args.on == true)
		reply(player, if args.on then "Frozen." else "Unfrozen.")
	end
end

COMMANDS.tpTo = function(player, args)
	local _, target = person(if type(args) == "table" then args.userId else nil)
	local root = rootOf(target)
	if root then
		teleport(player, root.CFrame * CFrame.new(0, 0, 4))
	end
end

COMMANDS.bring = function(player, args)
	local _, target = person(if type(args) == "table" then args.userId else nil)
	local root = rootOf(player)
	if root and target then
		teleport(target, root.CFrame * CFrame.new(0, 0, -4))
	end
end

COMMANDS.tpPlace = function(player, args)
	local place = if type(args) == "table" then args.place else nil
	local map = Match.map or previewInfo
	if place == "lobby" then
		teleport(player, MapService.lobbySpawn())
	elseif place == "map" and map then
		teleport(player, map.spawns[1])
	elseif place == "meeting" and Match.map and Match.map.meeting then
		teleport(player, Match.map.meeting.seats[1])
	elseif type(place) == "string" and string.sub(place, 1, 8) == "station:" and map then
		for _, station in ipairs(map.stations) do
			if station.id == string.sub(place, 9) then
				teleport(player, station.desk.CFrame * CFrame.new(0, -1.5, -3.5))
			end
		end
	elseif type(place) == "string" and string.sub(place, 1, 5) == "area:" and map then
		local area = map.areas[tonumber(string.sub(place, 6)) or 0]
		if area then
			teleport(player, CFrame.new(area.position))
		end
	else
		reply(player, "Nothing to go to (no match or preview for that).", "bad")
	end
end

-- Test bots

COMMANDS.addBots = function(player, args)
	if not IS_STUDIO then
		reply(player, "Test bots only exist in Studio.", "bad")
		return
	end
	local count = if type(args) == "table" then tonumber(args.count) or 1 else 1
	local made = Bots.add(count)
	reply(player, string.format("Added %d bot(s). They join the next match (READY or Start match).", #made), "good")
end

COMMANDS.fillBots = function(player, args)
	if not IS_STUDIO then
		return
	end
	local wanted = if type(args) == "table" then tonumber(args.total) or Config.MIN_PLAYERS else Config.MIN_PLAYERS
	local count = #Players:GetPlayers() + #Bots.list
	if count < wanted then
		Bots.add(wanted - count)
	end
	reply(player, string.format("%d players and bots in the server.", #Players:GetPlayers() + #Bots.list))
end

COMMANDS.removeBots = function(player)
	Bots.removeAll()
	reply(player, "All bots removed.")
end

COMMANDS.botsAuto = function(player)
	Bots.autoPlay = not Bots.autoPlay
	reply(player, if Bots.autoPlay then "Bots play on their own." else "Bots only follow orders.")
end

COMMANDS.botsKill = function(player)
	Bots.handKills = not Bots.handKills
	reply(player, if Bots.handKills then "A bot Hand writes names." else "A bot Hand spares everyone.")
end

COMMANDS.botsVote = function(player, args)
	local target = if type(args) == "table" then args.target else nil
	Bots.voteTarget = if target == "skip" or type(target) == "number" then target else nil
	reply(player, "Bots vote: " .. (if target == "skip" then "skip" elseif target then "for the pick" else "at random"))
end

COMMANDS.botOrder = function(player, args)
	if type(args) ~= "table" then
		return
	end
	local _, bot = person(args.userId)
	if not Bots.is(bot) then
		reply(player, "Pick a bot first.", "bad")
		return
	end
	local root = rootOf(player)
	reply(player, Bots.order(bot, tostring(args.action), args.target, if root then root.Position else nil))
end

-- Maps and the world

COMMANDS.preview = function(player, args)
	if Match.active or MatchmakingService.isRunning() then
		reply(player, "Map previews only work between matches.", "bad")
		return
	end
	local mapId = if type(args) == "table" then tostring(args.mapId) else ""
	local ok, info = pcall(MapService.build, mapId)
	if not ok then
		reply(player, "The map failed to build: " .. tostring(info), "bad")
		return
	end
	info.model:SetAttribute("Preview", true)
	previewInfo = info
	teleport(player, info.spawns[1])
	reply(player, "Previewing " .. info.name .. ". Close the preview to go back.", "good")
end

COMMANDS.closePreview = function(player)
	if previewInfo then
		MapService.destroy()
		previewInfo = nil
	end
	teleport(player, MapService.lobbySpawn())
end

COMMANDS.scenes = function(player)
	SceneBuilder.disabled = not SceneBuilder.disabled
	MapService.rebuildLobby()
	if previewInfo and not Match.active then
		local id = previewInfo.id
		MapService.destroy()
		previewInfo = MapService.build(id)
		previewInfo.model:SetAttribute("Preview", true)
	end
	reply(
		player,
		if SceneBuilder.disabled
			then "Part-built venues (the next map too)."
			else "Blender scenes (when imported; the next map too)."
	)
end

COMMANDS.contract = function(player)
	local info = Match.map or previewInfo
	if not info then
		reply(player, "Build a map first (start a match or preview one).", "bad")
		return
	end
	local problems = MapContract.validateBuilt(info)
	for _, problem in ipairs(problems) do
		warn("[Inkbound debug] " .. info.name .. ": " .. problem)
	end
	reply(
		player,
		if #problems == 0 then "Map contract: all clear." else #problems .. " problem(s), listed in the Output.",
		if #problems == 0 then "good" else "bad"
	)
end

-- Presentation

COMMANDS.cue = function(player, args)
	if type(args) ~= "table" then
		return
	end
	local ps = Match.getByUserId(args.userId)
	local problem = RoundService.debugCue(tostring(args.kind), player, ps, args.extra)
	if problem then
		reply(player, problem, "bad")
	end
end

COMMANDS.announce = function(player, args)
	local tone = if type(args) == "table" then args.tone else "neutral"
	Match.announce("Debug announcement", "This is how a " .. tostring(tone) .. " announcement looks.", tone)
	for _, kind in ipairs({ "info", "good", "bad", "secret" }) do
		Match.notify(player, "A " .. kind .. " notification.", kind)
	end
end

COMMANDS.briefing = function(player, args)
	local role = if type(args) == "table" and table.find(RoleLogic.ALL, args.role) then args.role else "TaskForce"
	BriefingRemote:FireClient(player, {
		role = role,
		alias = "Raven",
		realName = "Kenji Mori",
		allies = {},
		hint = if role == "Watari" then 'The 2nd letter of the Hand\'s last name is "O".' else nil,
		playerCount = 8,
		followers = 1,
		mapName = MapService.nextMapName(),
		duration = 12,
	})
end

COMMANDS.results = function(player, args)
	local winner = if type(args) == "table" and args.winner == "Kira" then "Kira" else "Team"
	local roster = {}
	for i, id in ipairs(RoleLogic.ALL) do
		table.insert(roster, {
			userId = if i == 1 then player.UserId else -i,
			alias = ({ "Raven", "Moth", "Echo", "Vale", "Sable" })[i] or "Ash",
			displayName = if i == 1 then player.DisplayName else "Player " .. i,
			realName = "Test Name " .. i,
			role = id,
			status = if i == 2 then "dead" else "alive",
			cause = if i == 2 then "Heart attack" else nil,
		})
	end
	RevealRemote:FireClient(player, {
		winner = winner,
		reason = "Debug: a preview of the results screen.",
		mapName = MapService.nextMapName(),
		players = roster,
		events = EventLog.all(),
		rewards = {
			coins = 120,
			xp = 150,
			won = true,
			lines = { { "Played the case", 20, 30 }, { "Won", 60, 80 }, { "Case files", 40, 40 } },
		},
		duration = 20,
	})
end

-- Profile

local function profileOf(player: Player)
	local data = DataService.get(player)
	if not data then
		reply(player, "Your profile is not loaded.", "bad")
	end
	return data
end

COMMANDS.coins = function(player, args)
	local data = profileOf(player)
	if data then
		data.coins = math.max(0, data.coins + (tonumber(args and args.amount) or 500))
		DataService.push(player)
	end
end

COMMANDS.xp = function(player, args)
	local data = profileOf(player)
	if data then
		data.xp = math.max(0, data.xp + (tonumber(args and args.amount) or 500))
		DataService.push(player)
	end
end

COMMANDS.dayPlus = function(player)
	TimeUtil.setOffset(TimeUtil.offset() + 86400)
	DataService.push(player)
	reply(player, "Jumped a day ahead (streaks, quests, shop).")
end

COMMANDS.weekPlus = function(player)
	TimeUtil.setOffset(TimeUtil.offset() + 7 * 86400)
	DataService.push(player)
	reply(player, "Jumped a week ahead.")
end

COMMANDS.allCosmetics = function(player)
	local data = profileOf(player)
	if data then
		for _, item in ipairs(Cosmetics.ITEMS) do
			data.owned[item.id] = true
		end
		DataService.push(player)
		reply(player, "Every cosmetic unlocked.", "good")
	end
end

-- Resets one part of the profile to what a new player starts with.
local RESETTABLE = {
	tipsSeen = true,
	training = true,
	streak = true,
	quests = true,
	achievements = true,
	titles = true,
	mastery = true,
	owned = true,
	equipped = true,
	stats = true,
	weekly = true,
}

COMMANDS.reset = function(player, args)
	local data = profileOf(player)
	local key = if type(args) == "table" then args.key else nil
	if not data then
		return
	end
	local defaults = Migrations.defaults(Config.STARTING_COINS)
	if key == "all" then
		for field in pairs(RESETTABLE) do
			data[field] = defaults[field]
		end
		data.coins = defaults.coins
		data.xp = 0
	elseif RESETTABLE[key] then
		data[key] = defaults[key]
	else
		return
	end
	DataService.push(player)
	reply(player, "Reset: " .. tostring(key) .. ".")
end

COMMANDS.pass = function(player, args)
	if type(args) == "table" and type(args.key) == "string" then
		PassService.debugSet(player, args.key, args.on == true)
		DataService.push(player)
		reply(player, args.key .. (if args.on then " pass on." else " pass off."))
	end
end

COMMANDS.receipt = function(player, args)
	local key = if type(args) == "table" then args.key else nil
	for _, pack in ipairs(Products.COIN_PACKS) do
		if pack.key == key then
			local decision = MonetizationService.processReceipt({
				PlayerId = player.UserId,
				ProductId = pack.id,
				PurchaseId = "debug-" .. os.clock(),
				CurrencySpent = 0,
			})
			reply(
				player,
				"Receipt for "
					.. key
					.. ": "
					.. decision.Name
					.. (
						if decision == Enum.ProductPurchaseDecision.NotProcessedYet
							then " (Studio data is temporary unless API access is on, so nothing can be saved)"
							else ""
					)
			)
			return
		end
	end
	reply(player, "Unknown product " .. tostring(key), "bad")
end

-- Setup -----------------------------------------------------------------------------------------

function DebugService.init()
	if not DebugService.ENABLED then
		return
	end
	Bots.init()
	local function onPlayer(player: Player)
		if DebugService.allowed(player) then
			player:SetAttribute("LDebug", true)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		watching[player] = nil
	end)
	DebugRemote.OnServerEvent:Connect(function(player: Player, command: any, args: any)
		if typeof(player) ~= "Instance" or not DebugService.allowed(player) or type(command) ~= "string" then
			return
		end
		if command == "watch" then
			watching[player] = args == true or nil
			if args == true then
				DebugRemote:FireClient(player, "snapshot", snapshot(player))
			end
			return
		end
		local handler = COMMANDS[command]
		if not handler then
			return
		end
		local ok, err = pcall(handler, player, args)
		if not ok then
			warn("[Inkbound debug] " .. command .. " failed: " .. tostring(err))
			reply(player, command .. " failed: " .. tostring(err), "bad")
		end
		task.defer(pushSnapshots)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pushSnapshots()
		end
	end)
	print("[Inkbound] Debug panel enabled (press F2 in a play test).")
end

return DebugService
