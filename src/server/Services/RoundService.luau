-- The match loop: lobby -> briefing -> up to five rounds of
-- (investigation, Death Note phase, meeting, vote) -> reveal -> lobby.
-- Win checks run after every removal from the match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local WinConditions = require(Shared:WaitForChild("WinConditions"))

local CaseFileService = require(script.Parent.CaseFileService)
local CharacterService = require(script.Parent.CharacterService)
local ChatService = require(script.Parent.ChatService)
local DeathNoteService = require(script.Parent.DeathNoteService)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local EvidenceService = require(script.Parent.EvidenceService)
local EyesService = require(script.Parent.EyesService)
local HoodService = require(script.Parent.HoodService)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Match)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MeetingService = require(script.Parent.MeetingService)
local NameService = require(script.Parent.NameService)
local NoteService = require(script.Parent.NoteService)
local RewardService = require(script.Parent.RewardService)
local RoleService = require(script.Parent.RoleService)
local SuspicionService = require(script.Parent.SuspicionService)
local VoteService = require(script.Parent.VoteService)
local WarrantService = require(script.Parent.WarrantService)

local BriefingRemote = Net.event("Briefing")
local RevealRemote = Net.event("Reveal")

local RoundService = {}

local MATCH_ZOOM = 18
local LOBBY_ZOOM = 128

local ROLE_TITLES = {
	Kira = "Kira",
	Follower = "a Kira follower",
	L = "L",
	Watari = "Watari",
	TaskForce = "Task Force",
}

-- Phases ----------------------------------------------------------------------------------

local function runPhase(name: string, onStart: (() -> ())?, onEnd: (() -> ())?)
	Match.phase = name
	Match.phaseEndsAt = workspace:GetServerTimeNow() + Match.phaseLength(name)
	if onStart then
		onStart()
	end
	Match.pushState()
	Match.pushAllPrivate()
	while Match.winner == nil and workspace:GetServerTimeNow() < Match.phaseEndsAt do
		task.wait(0.25)
	end
	if onEnd then
		onEnd()
	end
end

local function sendBriefings()
	local hint = NameService.watariHint()
	for _, ps in ipairs(Match.list) do
		BriefingRemote:FireClient(ps.player, {
			role = ps.role,
			alias = ps.alias,
			realName = ps.realName,
			allies = Match.allies(ps),
			hint = if ps.role == "Watari" then hint else nil,
			playerCount = #Match.list,
			followers = RoleService.count("Follower"),
			mapName = Match.mapName,
			duration = Match.phaseLength("Briefing"),
		})
	end
	if hint then
		EventLog.add("Watari's hint: " .. hint, "hint")
	end
end

local function placeAtSpawns()
	local spawns = table.clone(Match.map.spawns)
	Util.shuffle(spawns, Match.rng)
	for i, ps in ipairs(Match.living()) do
		ps.seatCFrame = nil
		CharacterService.placeAt(ps.player, spawns[((i - 1) % #spawns) + 1])
	end
end

local function freezeLiving(frozen: boolean)
	for _, ps in ipairs(Match.living()) do
		CharacterService.setFrozen(ps.player, frozen)
	end
end

local function startInvestigation()
	MeetingService.release()
	placeAtSpawns()
	freezeLiving(false)
	ChatService.refresh()
end

local function endInvestigation()
	CaseFileService.cancelAll("The investigation phase is over.")
	freezeLiving(true)
end

local function startRound(round: number)
	for _, ps in ipairs(Match.list) do
		ps.tasksThisRound = 0
	end
	HoodService.onRoundStart(round)
	Match.announce("Round " .. round .. " of " .. Config.MAX_ROUNDS, "Investigation: work the case files and watch each other.", "neutral")
end

local function endRound(round: number)
	SuspicionService.onRoundEnd()
	EyesService.onRoundEnd()
	HoodService.onRoundEnd(round)
end

-- Win checks --------------------------------------------------------------------------------

local function onEliminated(ps, kind: string, context)
	if not Match.active or Match.winner ~= nil then
		return
	end
	local entries = {}
	for _, other in ipairs(Match.list) do
		table.insert(entries, { role = other.role, alive = other.alive })
	end
	local lKilled = ps.role == "L" and kind == "dead" and type(context) == "table" and context.byKira == true
	local side, code = WinConditions.evaluate(entries, lKilled)
	if not side then
		return
	end
	local reason
	if code == "KiraRemoved" then
		if kind == "voted" then
			reason = "The Task Force voted out Kira."
		elseif kind == "arrested" then
			reason = "L arrested Kira with a valid warrant."
		elseif kind == "left" then
			reason = "Kira fled the investigation."
		else
			reason = "Kira is gone."
		end
	elseif code == "LKilled" then
		reason = "Kira wrote L's real name in the Death Note."
	else
		reason = "Kira's side now matches the investigation team in number."
	end
	Match.declareWinner(side, reason)
end

-- Match --------------------------------------------------------------------------------------

local function reveal()
	Match.phase = "Reveal"
	Match.phaseEndsAt = workspace:GetServerTimeNow() + Match.phaseLength("Reveal")
	CaseFileService.cancelAll(nil)
	VoteService.cancel()
	WarrantService.close()
	ChatService.onMatchEnd()
	freezeLiving(false)

	local winner = Match.winner or "Kira"
	local reason = Match.winReason or ""
	EventLog.add((if winner == "Team" then "The Task Force wins. " else "Kira wins. ") .. reason, "end")

	local rewards = RewardService.payout(winner)
	local roster = {}
	for _, ps in ipairs(Match.list) do
		table.insert(roster, {
			userId = ps.userId,
			alias = ps.alias,
			displayName = ps.displayName,
			realName = ps.realName,
			role = ps.role,
			status = ps.status,
			cause = ps.cause,
		})
	end
	local events = EventLog.all()
	for _, player in ipairs(Players:GetPlayers()) do
		local ps = Match.get(player)
		RevealRemote:FireClient(player, {
			winner = winner,
			reason = reason,
			mapName = Match.mapName,
			players = roster,
			events = events,
			rewards = if ps then rewards[ps] else nil,
			duration = Match.phaseLength("Reveal"),
		})
	end
	Match.announce(if winner == "Team" then "The Task Force wins" else "Kira wins", reason, if winner == "Team" then "team" else "kira")
	Match.pushState()
	Match.pushAllPrivate()
	while workspace:GetServerTimeNow() < Match.phaseEndsAt do
		task.wait(0.25)
	end
end

local function runMatch(players: { Player })
	-- Someone may have left between matchmaking and now.
	local present = {}
	for _, player in ipairs(players) do
		if player.Parent == Players then
			table.insert(present, player)
		end
	end
	if #present == 0 then
		return
	end
	local mapId = MapService.nextMapId()
	MapService.advance()
	Match.begin(present)
	local map = MapService.build(mapId)
	Match.map = map
	Match.mapName = map.name

	EventLog.reset()
	RoleService.assign()
	NameService.assign()
	EventLog.add(string.format("%d agents were deployed to %s.", #Match.list, map.name), "start")
	for _, ps in ipairs(Match.list) do
		EventLog.add(string.format("%s was %s. Real name: %s.", ps.alias, ROLE_TITLES[ps.role] or ps.role, ps.realName), "role")
	end

	EvidenceService.reset()
	CaseFileService.onMatchStart(map)
	NoteService.onMatchStart(map)
	HoodService.onMatchStart(map)
	SuspicionService.onMatchStart()
	MeetingService.onMatchStart(map)
	ChatService.onMatchStart()

	for i, ps in ipairs(Match.list) do
		ps.player.CameraMaxZoomDistance = MATCH_ZOOM
		if ps.player.Character then
			CharacterService.placeAt(ps.player, map.spawns[((i - 1) % #map.spawns) + 1])
			CharacterService.setFrozen(ps.player, true)
		else
			CharacterService.load(ps.player)
		end
	end

	runPhase("Briefing", sendBriefings)

	for round = 1, Config.MAX_ROUNDS do
		if Match.winner then
			break
		end
		Match.round = round
		startRound(round)
		runPhase("Investigation", startInvestigation, endInvestigation)
		if Match.winner then
			break
		end
		runPhase("DeathNote", DeathNoteService.open, DeathNoteService.close)
		if Match.winner then
			break
		end
		runPhase("Meeting", function()
			MeetingService.gather()
			ChatService.setMeetingOpen(true)
			Match.announce("Task Force meeting", "Free chat is open. Real names of living players are blocked.", "neutral")
		end)
		if Match.winner then
			break
		end
		runPhase("Vote", function()
			VoteService.open()
			WarrantService.open()
		end, function()
			WarrantService.close()
			if Match.winner then
				VoteService.cancel()
			else
				VoteService.close()
			end
			ChatService.setMeetingOpen(false)
		end)
		if Match.winner then
			break
		end
		endRound(round)
	end

	if not Match.winner then
		Match.declareWinner("Kira", "Kira survived all " .. Config.MAX_ROUNDS .. " rounds.")
	end
	reveal()
end

local function cleanup()
	CaseFileService.onMatchEnd()
	NoteService.onMatchEnd()
	HoodService.onMatchEnd()
	SuspicionService.onMatchEnd()
	VoteService.cancel()
	WarrantService.close()
	ChatService.onMatchEnd()
	MeetingService.onMatchEnd()

	local participants = Match.list
	Match.finish()
	MapService.destroy()
	for _, ps in ipairs(participants) do
		local player = ps.player
		if player.Parent == Players then
			player:SetAttribute("Alias", nil)
			player.CameraMaxZoomDistance = LOBBY_ZOOM
			Match.clearPrivate(player)
			CharacterService.load(player)
		end
	end
	ChatService.refresh()
	Match.pushState()
	MatchmakingService.onMatchEnded()
end

function RoundService.init()
	Match.Eliminated:Connect(onEliminated)
	Players.PlayerRemoving:Connect(function(player)
		local ps = Match.getLiving(player)
		if ps then
			EventLog.add(string.format("%s (%s) left the investigation.", ps.alias, ROLE_TITLES[ps.role] or ps.role), "left")
			Elimination.eliminate(ps, "left", nil, ps.alias .. " left the investigation.", {})
		end
	end)
end

function RoundService.start()
	task.spawn(function()
		while true do
			local players = MatchmakingService.waitForMatch()
			local ok, err = xpcall(runMatch, function(message)
				return debug.traceback(tostring(message), 2)
			end, players)
			if not ok then
				warn("[L game] The match stopped because of an error:\n" .. tostring(err))
			end
			local cleaned, cleanupErr = pcall(cleanup)
			if not cleaned then
				warn("[L game] Cleanup failed: " .. tostring(cleanupErr))
				Match.finish()
				MatchmakingService.onMatchEnded()
			end
		end
	end)
end

return RoundService
