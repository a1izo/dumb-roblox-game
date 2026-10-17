-- The match loop: lobby -> intro -> briefing -> up to five rounds of
-- (investigation, Grimoire phase, meeting, vote, verdict) -> outro -> reveal -> lobby.
-- Win checks run after every removal from the match. A winner ends the gameplay phase at
-- once; cutscenes that are still playing (Cues holds) finish before the outro starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Casting = require(Shared:WaitForChild("Cinema"):WaitForChild("Casting"))
local LoadGate = require(script.Parent.LoadGate)

-- The longest a match start waits for slow clients to load the map (LoadGate).
local LOAD_TIMEOUT = 30
local Config = require(Shared:WaitForChild("Config"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))
local WinConditions = require(Shared:WaitForChild("WinConditions"))

local CaseFileService = require(script.Parent.CaseFileService)
local CharacterService = require(script.Parent.CharacterService)
local ChatService = require(script.Parent.ChatService)
local Cues = require(script.Parent.Cues)
local DeathNoteService = require(script.Parent.DeathNoteService)
local Elimination = require(script.Parent.Elimination)
local EmoteService = require(script.Parent.EmoteService)
local EventLog = require(script.Parent.EventLog)
local EvidenceService = require(script.Parent.EvidenceService)
local EyesService = require(script.Parent.EyesService)
local Analytics = require(script.Parent.Analytics)
local Mechanics = require(script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Mechanics"))
local GhostService = require(script.Parent.GhostService)
local HoodService = require(script.Parent.HoodService)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Match)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MeetingService = require(script.Parent.MeetingService)
local NameService = require(script.Parent.NameService)
local NoteService = require(script.Parent.NoteService)
local ProgressService = require(script.Parent.ProgressService)
local RewardService = require(script.Parent.RewardService)
local RoleService = require(script.Parent.RoleService)
local ServerSettings = require(script.Parent.ServerSettings)
local Staging = require(script.Parent.Staging)
local CosmeticsService = require(script.Parent.CosmeticsService)
local SuspicionService = require(script.Parent.SuspicionService)
local VoteService = require(script.Parent.VoteService)
local WagerService = require(script.Parent.WagerService)
local WarrantService = require(script.Parent.WarrantService)

local BriefingRemote = Net.event("Briefing")
local RevealRemote = Net.event("Reveal")

local RoundService = {}

local MATCH_ZOOM = 18
local LOBBY_ZOOM = 128

-- Phases ----------------------------------------------------------------------------------

type PhaseOptions = {
	length: number?, -- overrides Config.PHASE_TIME
	uncuttable: boolean?, -- runs its full length even after a winner is declared
}

-- A phase of length 0 (cutscenes skipped in Studio) still runs its start and end.
local function runPhase(name: string, onStart: (() -> ())?, onEnd: (() -> ())?, options: PhaseOptions?)
	local length = if options and options.length then options.length else Match.phaseLength(name)
	if Match.phaseLength(name) <= 0 then
		length = 0
	end
	-- The debug panel can skip ahead: every phase before the one asked for runs its start and
	-- end (so the match stays consistent) but takes no time.
	local skip = Match.debugSkipTo
	if skip then
		if skip.phase == name and (skip.round == nil or skip.round == Match.round) then
			Match.debugSkipTo = nil
		else
			length = 0
		end
	end
	local uncuttable = options ~= nil and options.uncuttable == true
	Match.phase = name
	GhostService.onPhase(name)
	Mechanics.onPhase(name)
	EmoteService.onPhase(name)
	Match.phaseStartedAt = workspace:GetServerTimeNow()
	Match.phaseEndsAt = Match.phaseStartedAt + length
	if onStart then
		onStart()
	end
	if length > 0 then
		Match.pushState()
		Match.pushAllPrivate()
		local lastPush = 0
		while (uncuttable or Match.winner == nil) and workspace:GetServerTimeNow() < Match.phaseEndsAt do
			local dt = task.wait(0.25)
			if Match.debugPaused then
				-- Paused from the debug panel: the clock stands still.
				Match.phaseEndsAt += dt
				Match.phaseStartedAt += dt
				if os.clock() - lastPush > 0.5 then
					lastPush = os.clock()
					Match.pushState()
				end
			end
			if Match.debugSkipTo and Match.debugSkipTo.phase ~= name then
				break
			end
		end
	end
	if onEnd then
		onEnd()
	end
	Mechanics.onPhaseEnd(name)
end

-- The intro cutscene: every player's avatar somewhere on the map doing something (Staging picks
-- the marks and activities), the camera visiting a few of them, and the Grimoire landing in
-- the middle of the map. Cameras are worked out on each client (Presentation/ShotSolver).
-- The intro shot made in Blender for each map (art/scripts/cinema/shots).
local INTRO_SHOTS = { UniversityCampus = "IntroCampus", TokyoDistrict = "IntroTokyo", TaskForceHQ = "IntroAgency" }

-- A shot's data by name (nil when it has not been exported).
local function shotData(name: string?): any
	local shots = Shared:WaitForChild("Cinema"):FindFirstChild("Shots")
	local module = if shots and name then shots:FindFirstChild(name) else nil
	if module and module:IsA("ModuleScript") then
		return require(module) :: any
	end
	return nil
end

local function introShot(): (string?, any)
	local name = INTRO_SHOTS[Match.mapId or ""]
	local shot = shotData(name)
	return if shot then name else nil, shot
end

local function introData(map)
	local userIds = {}
	for _, ps in ipairs(Match.living()) do
		table.insert(userIds, ps.userId)
	end
	local shotName, shot = introShot()
	if shot then
		-- Every named part (the one who sees the book...) goes to a random player, never by role.
		return {
			shot = shotName,
			cast = Casting.cast(shot, userIds, Match.rng),
			mapName = map.name or Match.mapName,
			playerCount = #Match.list,
			caseNumber = Match.rng:NextInteger(100, 999),
			duration = math.max(Match.phaseLength("Intro"), 8),
		}
	end
	local cast, vignettes = Staging.cast(map, userIds, Match.rng)
	return {
		mapName = map.name or Match.mapName,
		playerCount = #Match.list,
		caseNumber = Match.rng:NextInteger(100, 999),
		cast = cast,
		vignettes = vignettes,
		landmark = Staging.landmark(map),
		duration = math.max(Match.phaseLength("Intro"), 8),
	}
end

local function startIntro()
	local data = introData(Match.map)
	data.duration = Match.phaseLength("Intro")
	Mechanics.stageMarks(data.cast)
	Cues.fire("intro", data, { lead = 0.2 })
end

local function meetingCenter(): Vector3?
	local seats = Match.map and Match.map.meeting and Match.map.meeting.seats
	if not seats or #seats == 0 then
		return nil
	end
	local sum = Vector3.zero
	for _, seat in ipairs(seats) do
		sum += seat.Position
	end
	return sum / #seats
end

-- Each role's own cutscene for the briefing (art/scripts/cinema/shots/role_*.py), and who plays in it:
-- the player themself, and the allies they know (and only those).
local ROLE_SHOTS = {
	Kira = "RoleDiavolo",
	Follower = "RoleMuerto",
	L = "RoleAce",
	Watari = "RoleButler",
	TaskForce = "RoleOperative",
}

local function roleCast(ps): { [string]: number }
	local cast: { [string]: number } = { self = ps.userId }
	local n = 0
	for _, ally in ipairs(Match.allies(ps)) do
		if ps.role == "Follower" and ally.role == "Kira" then
			cast.diavolo = ally.userId
		elseif ps.role == "L" and ally.role == "Watari" then
			cast.butler = ally.userId
		elseif ally.role == "Follower" then
			n += 1
			cast["ally:" .. n] = ally.userId
		end
	end
	return cast
end

local function sendBriefings()
	local hint = NameService.watariHint()
	Match.butlerHint = hint
	-- Every role's cutscene is the same length, so it says nothing to anyone watching the clock.
	local at = workspace:GetServerTimeNow() + 0.4
	for _, ps in ipairs(Match.list) do
		local shotName = ROLE_SHOTS[ps.role]
		local hasShot = shotData(shotName) ~= nil
		BriefingRemote:FireClient(ps.player, {
			shot = if hasShot then shotName else nil,
			cast = if hasShot then roleCast(ps) else nil,
			at = at,
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
		EventLog.add(Terms.f("{Butler}'s hint: ") .. hint, "hint")
	end
end

-- Short cutscenes between phases, played to everyone while the match loop waits for them (not while
-- the debug panel is skipping ahead). Their lengths are the shots' (art/scripts/cinema/shots).
local GAMBIT_OPENER = 4
local MEETING_INTRO = 6
local ROUND_COVER = 0.5 -- the round card's fade to black (Presenters/RoundStart)

local function interlude(kind: string, data: { [string]: any }, seconds: number)
	if Match.debugSkipTo then
		return
	end
	Cues.fire(kind, data, { lead = 0.25, hold = seconds })
	Cues.waitHolds(seconds + 1)
end

-- The meeting intro's cast: each standing place's player ("seat:k" is the scene's place k, the
-- game's seat k + 1; MeetingService.gather puts the i-th player at seat i).
local function meetingCast(): { [string]: number }
	local cast = {}
	for i, ps in ipairs(Match.list) do
		if ps.alive then
			cast["seat:" .. ((i - 1) % 12)] = ps.userId
		end
	end
	return cast
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
	NoteService.cancelOffers("phase")
	freezeLiving(true)
end

local function startRound(round: number)
	for _, ps in ipairs(Match.list) do
		ps.tasksThisRound = 0
	end
	HoodService.onRoundStart(round)
	Match.announce(
		"Round " .. round .. " of " .. ServerSettings.rounds(),
		"Investigation: work the case files and watch each other.",
		"neutral"
	)
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
			reason = Terms.f("{Agency} voted out {hand}.")
		elseif kind == "arrested" then
			reason = Terms.f("{Zero} arrested {hand} with a valid warrant.")
		elseif kind == "left" then
			reason = Terms.f("{Hand} fled the investigation.")
		else
			reason = Terms.f("{Hand} is gone.")
		end
	elseif code == "LKilled" then
		reason = Terms.f("{Hand} wrote {zero}'s real name in {grimoire}.")
	else
		reason = Terms.f("{Circle} now matches {agency} in number.")
	end
	Match.declareWinner(side, reason)
end

-- Match --------------------------------------------------------------------------------------

-- The ending's length: its own, and a few seconds more for the Manual's page of names when a name
-- was written.
local function outroLength(): number
	local base = Match.phaseLength("Outro")
	return if base > 0 and #Match.written > 0 then base + ManualTiming.OUTRO else base
end

-- The ending cutscene: everyone still standing is gathered in the meeting room, the camera
-- finds the Hand, and each side hears its own music.
local function outroData(winner: string)
	local hand = Match.findRole("Kira")
	local zero = Match.findRole("L")
	local winners = {}
	-- What each winner plays instead of a cheer (their win scene), by user id.
	local scenes = {}
	for _, ps in ipairs(Match.list) do
		if (winner == "Team") ~= Match.isKiraSide(ps) then
			table.insert(winners, ps.userId)
			local scene = if ps.player then CosmeticsService.winScene(ps.player) else nil
			if scene then
				table.insert(scenes, { userId = ps.userId, emote = scene })
			end
		end
	end
	return {
		winner = winner,
		reason = Match.winReason or "",
		handUserId = if hand then hand.userId else nil,
		handAlias = if hand then hand.alias else nil,
		handRealName = if hand then hand.realName else nil,
		handAlive = hand ~= nil and hand.alive,
		zeroUserId = if zero then zero.userId else nil,
		zeroAlias = if zero then zero.alias else nil,
		winners = winners,
		winScenes = scenes,
		center = meetingCenter(),
		-- Every name written in the Manual this match (filtered when written), struck once it killed.
		written = Match.written,
		-- The case is closed: Diavolo's writing style and Ace's verdict style, for everyone.
		writing = if hand then CosmeticsService.style(hand.player, "writing") else nil,
		verdict = if zero then CosmeticsService.style(zero.player, "verdict") else nil,
		duration = math.max(outroLength(), 10),
	}
end

local function startOutro()
	CaseFileService.cancelAll(nil)
	VoteService.cancel()
	WarrantService.close()
	ChatService.setMeetingOpen(false)
	MeetingService.gather()
	if Match.debugFastEnd then
		return -- ended from the debug panel: straight to the lobby
	end
	local data = outroData(Match.winner or "Kira")
	data.duration = outroLength()
	Cues.fire("outro", data, { lead = 0.3 })
end

-- Debug panel: plays a cutscene for one player only, with data from the running match (the
-- match itself does not change). target is a player state for the cues about someone.
function RoundService.debugCue(kind: string, player: Player, target, extra: string?): string?
	if not Match.active or not Match.map then
		return "Cutscene previews need a running match (start one with bots)."
	end
	local to = { to = { player }, lead = 0.2 }
	target = target or Match.get(player)
	if kind == "intro" then
		Cues.fire("intro", introData(Match.map), to)
	elseif kind == "outro" then
		Cues.fire("outro", outroData(if extra == "Kira" then "Kira" else "Team"), to)
	elseif kind == "death" then
		Cues.fire("death", { userId = target.userId, alias = target.alias, cause = extra or "Heart attack" }, to)
	elseif kind == "verdict" then
		Cues.fire("verdict", {
			counts = {
				{ name = target.alias, count = 3, userId = target.userId },
				{ name = "Skip", count = 1 },
			},
			removedUserId = target.userId,
			removedAlias = target.alias,
			tie = false,
			total = 4,
			climax = VoteService.CLIMAX,
		}, to)
	elseif kind == "arrest" then
		Cues.fire("arrest", {
			userId = target.userId,
			alias = target.alias,
			result = if target.role == "Kira"
				then "hand"
				elseif target.role == "Follower" then "cultist"
				else "innocent",
		}, to)
	elseif kind == "eyesDeal" then
		Cues.fire("eyesDeal", { reads = Config.EYES_READS, deathRound = Match.round + 1 }, to)
	elseif kind == "shot" then
		-- Any Blender cutscene by name: you play the lead ("self" or the first part), the others fill the
		-- rest of its parts in match order.
		local shot = shotData(extra)
		if not shot then
			return "No cutscene called " .. tostring(extra) .. " (exported to Shared/Cinema/Shots?)"
		end
		local cast: { [string]: number } = {}
		local named, crowd = Casting.slots(shot)
		local others = {}
		for _, ps in ipairs(Match.list) do
			if ps.userId ~= player.UserId then
				table.insert(others, ps.userId)
			end
		end
		local lead = if table.find(named, "self") then "self" else named[1]
		if lead then
			cast[lead] = player.UserId
		end
		for _, slot in ipairs(named) do
			if slot ~= lead and #others > 0 then
				cast[slot] = table.remove(others, 1) :: number
			end
		end
		for _, slot in ipairs(crowd) do
			if #others > 0 then
				cast[slot] = table.remove(others, 1) :: number
			end
		end
		Cues.fire("shot", { shot = extra, cast = cast }, to)
	else
		return "Unknown cutscene " .. kind
	end
	return nil
end

local function reveal()
	Match.phase = "Reveal"
	Mechanics.onPhase("Reveal")
	EmoteService.onPhase("Reveal")
	Match.phaseStartedAt = workspace:GetServerTimeNow()
	Match.phaseEndsAt = Match.phaseStartedAt + Match.phaseLength("Reveal")
	CaseFileService.cancelAll(nil)
	VoteService.cancel()
	WarrantService.close()
	ChatService.onMatchEnd()
	freezeLiving(false)

	local winner = Match.winner or "Kira"
	local reason = Match.winReason or ""
	-- "The Agency wins" / "The Hand wins"
	local winnerName = if winner == "Team" then Terms.side("Team", "Name") else Terms.role("Kira", "Name")
	EventLog.add(winnerName .. " wins. " .. reason, "end")

	-- Diavolo guesses are settled first, so their coins are paid with the rest.
	WagerService.settleCase()
	local rewards = RewardService.payout(winner)
	ProgressService.onMatchEnd(rewards)
	for ps, reward in pairs(rewards) do
		Analytics.step(ps.player, "matchFinished")
		if reward.won then
			Analytics.step(ps.player, "firstWin")
		end
	end
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
			title = CosmeticsService.titleOf(ps.player),
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
	Match.pushState()
	Match.pushAllPrivate()
	while workspace:GetServerTimeNow() < Match.phaseEndsAt do
		task.wait(0.25)
	end
end

-- After a winner: let the last cutscene finish, play the outro, then show the results.
local function finale()
	Cues.waitHolds(6)
	runPhase("Outro", startOutro, nil, { uncuttable = true, length = outroLength() })
	reveal()
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
	Match.mapId = mapId
	Match.mapName = map.name

	for _, ps in ipairs(Match.list) do
		Analytics.step(ps.player, "matchStarted")
	end

	EventLog.reset()
	RoleService.assign()
	NameService.assign()
	EventLog.add(Terms.f("{n} {agents} were deployed to {map}.", { n = #Match.list, map = map.name }), "start")
	for _, ps in ipairs(Match.list) do
		EventLog.add(
			string.format("%s was %s. Real name: %s.", ps.alias, Terms.role(ps.role, "a"), ps.realName),
			"role"
		)
	end

	EvidenceService.reset()
	CaseFileService.onMatchStart(map)
	NoteService.onMatchStart(map)
	HoodService.onMatchStart(map)
	SuspicionService.onMatchStart()
	MeetingService.onMatchStart(map)
	ChatService.onMatchStart()
	GhostService.onMatchStart()
	WagerService.onMatchStart()
	Mechanics.start(map)

	for i, ps in ipairs(Match.list) do
		ps.player.CameraMaxZoomDistance = MATCH_ZOOM
		if ps.player.Character then
			CharacterService.applyOutfit(ps.player)
			CharacterService.placeAt(ps.player, map.spawns[((i - 1) % #map.spawns) + 1])
			CharacterService.setFrozen(ps.player, true)
		else
			CharacterService.load(ps.player)
		end
	end

	-- Everyone's client must have the map and its content before anything plays on it.
	local players = {}
	for _, ps in ipairs(Match.list) do
		table.insert(players, ps.player)
	end
	LoadGate.wait(map.loadToken, players, LOAD_TIMEOUT)

	Cues.reset()
	runPhase("Intro", startIntro)
	runPhase("Briefing", sendBriefings)

	for round = 1, ServerSettings.rounds() do
		if Match.winner then
			break
		end
		Match.round = round
		-- Back to the round: "Round N of M" on black; everyone is moved to their places under it.
		if not Match.debugSkipTo then
			Cues.fire("roundStart", { round = round, rounds = ServerSettings.rounds() }, { lead = 0.2 })
			task.wait(0.2 + ROUND_COVER)
		end
		startRound(round)
		runPhase("Investigation", startInvestigation, endInvestigation)
		if Match.winner then
			break
		end
		interlude("gambit", { round = round }, GAMBIT_OPENER)
		runPhase("DeathNote", DeathNoteService.open, DeathNoteService.close)
		-- The names written this round take their victims now, one scene after another.
		DeathNoteService.resolve()
		Cues.waitHolds(40)
		if Match.winner then
			break
		end
		MeetingService.gather()
		interlude("meetingIntro", { cast = meetingCast() }, MEETING_INTRO)
		runPhase("Meeting", function()
			MeetingService.gather()
			ChatService.setMeetingOpen(true)
			Match.announce(
				Terms.f("{Meeting}"),
				"Free chat is open. Real names of living players are blocked.",
				"neutral"
			)
		end)
		if Match.winner then
			break
		end
		local result = nil
		runPhase("Vote", function()
			VoteService.open()
			WarrantService.open()
		end, function()
			WarrantService.close()
			if Match.winner then
				VoteService.cancel()
			else
				result = VoteService.tally()
			end
		end)
		if result then
			-- The verdict plays in full, even when voting out the Hand ends the match.
			runPhase("Verdict", function()
				VoteService.present(result)
				WagerService.settleVote(if result.removed then result.removed.userId else nil)
			end, function()
				ChatService.setMeetingOpen(false)
			end, { length = if result.removed then nil else 4, uncuttable = true })
		else
			ChatService.setMeetingOpen(false)
		end
		if Match.winner then
			break
		end
		endRound(round)
		-- Let a death at the end of the round (the eyes deal) play out before moving on.
		Cues.waitHolds(6)
	end

	if not Match.winner then
		Match.declareWinner("Kira", Terms.f("{Hand} survived all {n} rounds.", { n = ServerSettings.rounds() }))
	end
	finale()
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
	GhostService.onMatchEnd()
	WagerService.onMatchEnd()
	Mechanics.stop()

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
			EventLog.add(string.format("%s (%s) left the investigation.", ps.alias, Terms.role(ps.role)), "left")
			Elimination.eliminate(ps, "left", nil, ps.alias .. " left the investigation.", {})
			Match.announce(ps.alias .. " left the case", "They disconnected.", "neutral")
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
				warn("[DeathsGambit] The match stopped because of an error:\n" .. tostring(err))
			end
			local cleaned, cleanupErr = pcall(cleanup)
			if not cleaned then
				warn("[DeathsGambit] Cleanup failed: " .. tostring(cleanupErr))
				Match.finish()
				MatchmakingService.onMatchEnded()
			end
		end
	end)
end

return RoundService
