-- Central server-side match state. Services read and change the per-player state
-- records kept here. This is the only module that sends the State and Private remotes,
-- so what each client may know is decided in one place.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local ServerSettings = require(script.Parent.ServerSettings)
local Util = require(Shared:WaitForChild("Util"))

local StateRemote = Net.event("State")
local PrivateRemote = Net.event("Private")
local NotifyRemote = Net.event("Notify")
local AnnounceRemote = Net.event("Announce")

local Match = {}

Match.active = false
Match.id = 0
Match.phase = "Lobby"
Match.round = 0
Match.phaseEndsAt = 0
-- When the phase began (server time), so clients that join mid-phase can tell how far in it is.
Match.phaseStartedAt = 0
Match.startClock = 0
Match.map = nil
Match.mapId = ""
Match.mapName = ""
Match.list = {}
Match.byPlayer = {}
Match.winner = nil
Match.winReason = nil
Match.initialCount = 0
-- Every name written in the Manual this match, filtered, in order; struck once it killed
-- (DeathNoteService). The ending shows them.
Match.written = {} :: { { name: string, struck: boolean } }
-- The Bureau's shared task bar (TaskBarService): case files done and needed.
Match.taskBar = { done = 0, total = 0 }
-- Why free roam should stop for a meeting ("death", "bell"...), set by requestMeeting(); the
-- match loop picks it up and clears it.
Match.meetingCall = nil :: { reason: string, by: any? }?
-- The Butler named the next Ace (once per match).
Match.successionUsed = false
Match.rng = Random.new()

-- Debug panel controls (Studio): skip ahead to a phase (and round), pause the phase timer,
-- and cut the ending short.
Match.debugSkipTo = nil :: { phase: string, round: number? }?
Match.debugPaused = false
Match.debugFastEnd = false

-- A map's own mechanic can change what blocks sight and how far it reaches (the Tokyo crowd
-- stands in the way; a blackout shortens a stare). Both are reset by finish().
-- occluder(from, to) -> true when something of the map's (not a player) blocks that line.
Match.occluder = nil :: ((Vector3, Vector3) -> boolean)?
Match.sightScale = { stare = 1, eyes = 1 } :: { [string]: number }

local SIGHT_RANGES = { stare = "STARE_RANGE", eyes = "OCULUS_RANGE" }

-- Fired as (playerState, kind) after a player leaves the living: kind is
-- "dead", "voted", "arrested" or "left".
Match.Eliminated = Signal.new()

local function newState(player: Player)
	return {
		player = player,
		userId = player.UserId,
		displayName = player.DisplayName,
		alias = "",
		role = "TaskForce",
		first = "",
		last = "",
		realName = "",
		alive = true,
		status = "alive",
		cause = nil,
		killedBy = nil,
		tasksThisRound = 0,
		taskStation = nil,
		-- Real names this player has learned by staring or with the Oculus: [userId] = true.
		learned = {},
		-- Diavolo: when the Manual can be written in again (server time), and a writing in progress.
		writeReadyAt = 0,
		writing = nil,
		-- Muerto: the Oculus deal ({ lifeLeft = seconds of free roam }) and the sabotage cooldown.
		eyes = nil,
		sabotageReadyAt = 0,
		-- The emergency bell: one ring per player per match.
		bellUsed = false,
		-- Ace (role "L", or a Coven player the Butler named by mistake: fakeAce).
		isAce = false,
		fakeAce = false,
		arrestUsed = false,
		carrying = nil,
		seatCFrame = nil,
		stats = {
			tasks = 0,
			notesFound = 0,
			correctVotes = 0,
			kills = 0,
			reads = 0,
			duties = 0,
			-- Votes cast in meetings (the stat key is older than the meaning).
			reports = 0,
			-- A Deathsinger's: Death's wager winnings and wins, lobby haunts, spirit trial runs.
			wagerCoins = 0,
			wagersWon = 0,
			haunts = 0,
			spiritRuns = 0,
			arrestedKira = false,
		},
	}
end

function Match.begin(players: { Player })
	Match.id += 1
	Match.active = true
	Match.phase = "Briefing"
	Match.round = 0
	Match.phaseEndsAt = 0
	Match.phaseStartedAt = 0
	Match.winner = nil
	Match.winReason = nil
	Match.written = {}
	Match.taskBar = { done = 0, total = 0 }
	Match.meetingCall = nil
	Match.successionUsed = false
	Match.startClock = os.clock()
	Match.list = {}
	Match.byPlayer = {}
	for _, player in ipairs(players) do
		local ps = newState(player)
		table.insert(Match.list, ps)
		Match.byPlayer[player] = ps
	end
	Match.initialCount = #Match.list
end

function Match.finish()
	Match.active = false
	Match.phase = "Lobby"
	Match.round = 0
	Match.phaseEndsAt = 0
	Match.phaseStartedAt = 0
	Match.map = nil
	Match.mapId = ""
	Match.mapName = ""
	Match.list = {}
	Match.byPlayer = {}
	Match.debugSkipTo = nil
	Match.debugPaused = false
	Match.debugFastEnd = false
	Match.occluder = nil
	Match.sightScale = { stare = 1, eyes = 1 }
	Match.meetingCall = nil
end

-- Asks the match loop to stop free roam for a meeting. The first reason wins until the loop
-- takes it; outside free roam it does nothing.
function Match.requestMeeting(reason: string, by: any?)
	if not Match.active or Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return
	end
	Match.meetingCall = { reason = reason, by = by }
end

-- How far a kind of sight reaches right now: "stare" (learning a name by staring), "eyes" (the
-- Oculus reading a name).
function Match.sightRange(kind: string): number
	return (Config :: any)[SIGHT_RANGES[kind]] * (Match.sightScale[kind] or 1)
end

-- True for the debug panel's test bots (tables standing in for players).
function Match.isBot(ps): boolean
	return type(ps.player) == "table"
end

-- Lookups -------------------------------------------------------------------

function Match.get(player: Player)
	return Match.byPlayer[player]
end

-- The player's state if they are alive in the running match, otherwise nil.
function Match.getLiving(player: Player)
	local ps = Match.byPlayer[player]
	if Match.active and ps and ps.alive then
		return ps
	end
	return nil
end

function Match.getByUserId(userId: number)
	for _, ps in ipairs(Match.list) do
		if ps.userId == userId then
			return ps
		end
	end
	return nil
end

function Match.isLivingUserId(userId: number): boolean
	if not Match.active then
		return false
	end
	local ps = Match.getByUserId(userId)
	return ps ~= nil and ps.alive
end

function Match.living()
	local result = {}
	for _, ps in ipairs(Match.list) do
		if ps.alive then
			table.insert(result, ps)
		end
	end
	return result
end

function Match.findRole(role: string)
	for _, ps in ipairs(Match.list) do
		if ps.role == role then
			return ps
		end
	end
	return nil
end

function Match.isKiraSide(ps): boolean
	return ps.role == "Kira" or ps.role == "Follower"
end

-- The living player who holds Ace's arrest right now (real or fake), if any.
function Match.ace()
	for _, ps in ipairs(Match.list) do
		if ps.isAce and ps.alive then
			return ps
		end
	end
	return nil
end

-- Time --------------------------------------------------------------------

local IS_STUDIO = RunService:IsStudio()

-- The cutscene phases.
local PRESENTATION = { Intro = true, Verdict = true, Outro = true }

-- Phase length in seconds. Studio test runs can be sped up with STUDIO_TIME_SCALE (cutscene
-- phases keep their length) and can skip the cutscenes with STUDIO_SKIP_PRESENTATION.
function Match.phaseLength(name: string): number
	if Match.debugFastEnd and (name == "Outro" or name == "Reveal") then
		return 0
	end
	local base = ServerSettings.phaseOverride(name) or Config.PHASE_TIME[name] or 10
	if IS_STUDIO then
		if PRESENTATION[name] then
			return if Config.STUDIO_SKIP_PRESENTATION then 0 else base
		end
		return math.max(3, base * Config.STUDIO_TIME_SCALE)
	end
	return base
end

function Match.elapsed(): number
	return os.clock() - Match.startClock
end

function Match.clock(): string
	return Util.formatClock(Match.elapsed())
end

-- Geometry ------------------------------------------------------------------

function Match.rootPart(ps): BasePart?
	local character = ps.player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Match.position(ps): Vector3?
	local root = Match.rootPart(ps)
	if root then
		return root.Position
	end
	return nil
end

function Match.eyePosition(ps): Vector3?
	local character = ps.player.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = Match.rootPart(ps)
	if root then
		return root.Position + Vector3.new(0, 1.5, 0)
	end
	return nil
end

local function characterList(): { Instance }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, bot in ipairs(CollectionService:GetTagged("LBotCharacter")) do
		table.insert(list, bot)
	end
	return list
end

-- True when no solid part blocks the line between two points. Hitting a part inside
-- `target` (for example the station being watched) counts as reaching the target.
function Match.hasLineOfSight(from: Vector3, to: Vector3, target: Instance?): boolean
	local direction = to - from
	if direction.Magnitude < 0.05 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterList()
	params.IgnoreWater = true
	local result = workspace:Raycast(from, direction, params)
	local clear = result == nil
		or (target ~= nil and result.Instance:IsDescendantOf(target))
		or (result.Position - to).Magnitude < 0.75
	if clear and Match.occluder then
		return not Match.occluder(from, to)
	end
	return clear
end

-- Can this player see `point` from close range with nothing in between?
function Match.canSee(ps, point: Vector3, range: number, target: Instance?): boolean
	local eye = Match.eyePosition(ps)
	if not eye then
		return false
	end
	if (eye - point).Magnitude > range then
		return false
	end
	return Match.hasLineOfSight(eye, point, target)
end

function Match.nearestArea(position: Vector3): string
	local map = Match.map
	if not map or not map.areas then
		return "an unknown spot"
	end
	local best = "the map"
	local bestDistance = math.huge
	for _, area in ipairs(map.areas) do
		local distance = (area.position - position).Magnitude
		if distance < bestDistance then
			best = area.name
			bestDistance = distance
		end
	end
	return best
end

-- Winning -------------------------------------------------------------------

function Match.declareWinner(side: string, reason: string)
	if Match.winner then
		return
	end
	Match.winner = side
	Match.winReason = reason
end

-- Client sync ---------------------------------------------------------------

function Match.publicState()
	local players = {}
	for _, ps in ipairs(Match.list) do
		table.insert(players, {
			userId = ps.userId,
			alias = ps.alias,
			alive = ps.alive,
			status = ps.status,
			cause = ps.cause,
		})
	end
	return {
		active = Match.active,
		phase = Match.phase,
		round = Match.round,
		taskBar = Match.taskBar,
		startedAt = Match.phaseStartedAt,
		endsAt = Match.phaseEndsAt,
		mapId = Match.mapId,
		mapName = Match.mapName,
		players = players,
	}
end

function Match.pushState(player: Player?)
	local state = Match.publicState()
	if player then
		StateRemote:FireClient(player, state)
	else
		StateRemote:FireAllClients(state)
	end
end

-- One-way knowledge: a Muerto knows Diavolo (and nobody else); the Butler knows whoever holds
-- Ace's title. Diavolo, Ace and everyone else know no one.
local function allyList(ps)
	local allies = {}
	for _, other in ipairs(Match.list) do
		if other ~= ps then
			local visible = (ps.role == "Follower" and other.role == "Kira") or (ps.role == "Watari" and other.isAce)
			if visible then
				table.insert(allies, {
					userId = other.userId,
					alias = other.alias,
					-- The Butler sees the title, never the side (a fake Ace shows as Ace too).
					role = if ps.role == "Watari" then "L" else other.role,
					alive = other.alive,
				})
			end
		end
	end
	return allies
end

function Match.allies(ps)
	return allyList(ps)
end

function Match.privateState(ps)
	if not ps or not Match.active then
		return { inMatch = false }
	end
	local payload = {
		inMatch = true,
		alive = ps.alive,
		role = ps.role,
		alias = ps.alias,
		realName = ps.realName,
		allies = allyList(ps),
		carrying = if ps.carrying then ps.carrying.kind else nil,
		noteId = if ps.carrying then ps.carrying.noteId else nil,
		taskStation = ps.taskStation,
		-- A Specter waiting in the lobby (GhostService).
		away = ps.away == true,
		bellUsed = ps.bellUsed,
		isAce = ps.isAce,
		fakeAce = ps.fakeAce,
		arrestUsed = ps.arrestUsed,
	}
	if Match.isKiraSide(ps) then
		-- The real names this player has learned, for the Manual (and the notes a Muerto writes).
		local learned = {}
		for userId in pairs(ps.learned) do
			local other = Match.getByUserId(userId)
			if other then
				table.insert(learned, {
					userId = other.userId,
					alias = other.alias,
					realName = other.realName,
					alive = other.alive,
				})
			end
		end
		table.sort(learned, function(a, b)
			return a.alias < b.alias
		end)
		payload.learned = learned
	end
	if ps.role == "Kira" then
		payload.writeReadyAt = ps.writeReadyAt
		payload.writing = ps.writing ~= nil
	elseif ps.role == "Follower" then
		payload.canDeal = ps.eyes == nil
		payload.sabotageReadyAt = ps.sabotageReadyAt
	end
	payload.tasksThisRound = ps.tasksThisRound
	if ps.eyes then
		payload.eyes = { lifeLeft = math.ceil(ps.eyes.lifeLeft) }
	end
	return payload
end

function Match.pushPrivate(ps)
	if ps.player.Parent == Players then
		PrivateRemote:FireClient(ps.player, Match.privateState(ps))
	end
end

function Match.pushAllPrivate()
	for _, ps in ipairs(Match.list) do
		Match.pushPrivate(ps)
	end
end

function Match.clearPrivate(player: Player)
	if player.Parent == Players then
		PrivateRemote:FireClient(player, { inMatch = false })
	end
end

-- Messages ------------------------------------------------------------------

-- kind: "info", "good", "bad" or "secret"
function Match.notify(player: Player, text: string, kind: string?)
	if player.Parent == Players then
		NotifyRemote:FireClient(player, { text = text, kind = kind or "info" })
	end
end

-- tone: "neutral", "danger", "team" or "kira"
function Match.announce(title: string, subtitle: string?, tone: string?)
	AnnounceRemote:FireAllClients({ title = title, subtitle = subtitle or "", tone = tone or "neutral" })
end

return Match
