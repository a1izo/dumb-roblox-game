-- The match loop: lobby -> intro -> briefing -> free roam and meetings, over and over -> outro ->
-- reveal -> lobby. Free roam ("Investigation") ends early when someone dies, when someone rings the
-- bell, or when its timer runs out (Match.requestMeeting); then the living meet, talk and vote, and
-- free roam starts again. There is no round cap: the match ends when a side wins (win checks run
-- after every removal; the task bar declares its own win). A winner ends the gameplay phase at
-- once; cutscenes that are still playing (Cues holds) finish before the outro starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Casting = require(Shared:WaitForChild("Cinema"):WaitForChild("Casting"))
local CutLength = require(Shared:WaitForChild("Cinema"):WaitForChild("CutLength"))
local LoadGate = require(script.Parent.LoadGate)

-- The longest a match start waits for slow clients to load the map (LoadGate).
local LOAD_TIMEOUT = 30 -- the longest the start waits for the clients to load the map
local LOAD_GRACE = 6 -- once most are ready, how much longer the last ones get
local Config = require(Shared:WaitForChild("Config"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Trial = require(Shared:WaitForChild("Trial"))
local WinCuts = require(Shared:WaitForChild("Cinema"):WaitForChild("WinCuts")) :: any
local WinConditions = require(Shared:WaitForChild("WinConditions"))

local ArrestService = require(script.Parent.ArrestService)
local CaseFileService = require(script.Parent.CaseFileService)
local CharacterService = require(script.Parent.CharacterService)
local ChatService = require(script.Parent.ChatService)
local Cues = require(script.Parent.Cues)
local DeathNoteService = require(script.Parent.DeathNoteService)
local Elimination = require(script.Parent.Elimination)
local EmoteService = require(script.Parent.EmoteService)
local EventLog = require(script.Parent.EventLog)
local EyesService = require(script.Parent.EyesService)
local Analytics = require(script.Parent.Analytics)
local Mechanics = require(script.Parent.Parent:WaitForChild("Maps"):WaitForChild("Mechanics"))
local GhostService = require(script.Parent.GhostService)
local HackService = require(script.Parent.HackService)
local MapService = require(script.Parent.MapService)
local Match = require(script.Parent.Match)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MeetingService = require(script.Parent.MeetingService)
local NameService = require(script.Parent.NameService)
local NoteService = require(script.Parent.NoteService)
local ProgressService = require(script.Parent.ProgressService)
local RewardService = require(script.Parent.RewardService)
local RoleService = require(script.Parent.RoleService)
local SabotageService = require(script.Parent.SabotageService)
local Staging = require(script.Parent.Staging)
local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local ClipLengths = require(script.Parent.ClipLengths)
local TaskBarService = require(script.Parent.TaskBarService)
local VoteService = require(script.Parent.VoteService)
local WagerService = require(script.Parent.WagerService)

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
			-- Free roam stops the moment a meeting is called.
			if name == "Investigation" and Match.meetingCall ~= nil then
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
		elseif ps.role == "Watari" and ally.role == "L" then
			-- The Butler knows Ace now (Ace no longer knows the Butler).
			cast.ace = ally.userId
		elseif ally.role == "Follower" then
			n += 1
			cast["ally:" .. n] = ally.userId
		end
	end
	return cast
end

-- How long a role's cutscene plays this match (nil without one): its shot's length, stretched to its voiced line's clip
-- once the slot has one (Shared/Cinema/CutLength).
local function roleShotLength(role: string): number?
	local shot = shotData(ROLE_SHOTS[role])
	if not shot then
		return nil
	end
	local voice = if type(shot.sound) == "table" then shot.sound.voice else nil
	return CutLength.of(shot, if type(voice) == "string" then ClipLengths.get(voice) else nil)
end

-- (the voiced lines' clips are measured while the server starts, so a briefing never waits for them)
task.defer(function()
	local slots = {}
	for _, name in pairs(ROLE_SHOTS) do
		local shot = shotData(name)
		if shot and type(shot.sound) == "table" and type(shot.sound.voice) == "string" then
			table.insert(slots, shot.sound.voice)
		end
	end
	ClipLengths.warm(slots)
end)

-- The briefing lasts as long as this match's longest role cutscene and a hold for the role card after it, the same
-- for everyone: each player watches only their own cutscene, so nobody learns anything from how long it runs.
local function briefingLength(): number?
	local longest = 0
	for _, ps in ipairs(Match.list) do
		longest = math.max(longest, roleShotLength(ps.role) or 0)
	end
	if longest <= 0 or Match.phaseLength("Briefing") <= 0 then
		return nil
	end
	return longest + Config.BRIEFING_HOLD
end

local function sendBriefings()
	local at = workspace:GetServerTimeNow() + 0.4
	for _, ps in ipairs(Match.list) do
		local shotName = ROLE_SHOTS[ps.role]
		local hasShot = shotData(shotName) ~= nil
		BriefingRemote:FireClient(ps.player, {
			shot = if hasShot then shotName else nil,
			cast = if hasShot then roleCast(ps) else nil,
			length = if hasShot then roleShotLength(ps.role) else nil,
			at = at,
			role = ps.role,
			alias = ps.alias,
			realName = ps.realName,
			allies = Match.allies(ps),
			playerCount = #Match.list,
			followers = RoleService.count("Follower"),
			mapName = Match.mapName,
			duration = Match.phaseEndsAt - Match.phaseStartedAt,
		})
	end
end

-- Short cutscenes between phases, played to everyone while the match loop waits for them (not while
-- the debug panel is skipping ahead). Their lengths are the shots' (art/scripts/cinema/shots).
local MEETING_INTRO = 6

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

-- Every investigation starts everyone somewhere new: a fresh set from the map's whole pool of spots, spread out and
-- out of each other's sight (MapService.dealSpawns, Shared/SpawnPicker).
local function placeAtSpawns()
	local living = Match.living()
	local spots = MapService.dealSpawns(Match.map, #living, Match.rng)
	for i, ps in ipairs(living) do
		ps.seatCFrame = nil
		CharacterService.placeAt(ps.player, spots[i])
	end
end

local function freezeLiving(frozen: boolean)
	for _, ps in ipairs(Match.living()) do
		CharacterService.setFrozen(ps.player, frozen)
	end
end

local function startInvestigation()
	Match.meetingCall = nil
	for _, ps in ipairs(Match.list) do
		ps.tasksThisRound = 0
	end
	MeetingService.release()
	placeAtSpawns()
	freezeLiving(false)
	ChatService.refresh()
	Match.announce(
		Terms.phase("Investigation"),
		"Work the case files and watch each other. Anything can happen now.",
		"neutral"
	)
end

-- Free roam is over: everything that was going on in it stops, and everyone stands still.
local function endInvestigation()
	DeathNoteService.interrupt()
	EyesService.interrupt()
	HackService.interrupt()
	SabotageService.clear()
	CaseFileService.cancelAll("A meeting was called.")
	NoteService.cancelOffers("phase")
	freezeLiving(true)
end

-- What the meeting's announcement says about why it was called.
local function meetingReason(call): string
	if call.reason == "death" and call.by then
		return call.by.alias .. " is dead. The Bureau gathers."
	elseif call.reason == "bell" and call.by then
		return call.by.alias .. " rang the emergency bell."
	end
	return "Time to compare notes."
end

-- Win checks --------------------------------------------------------------------------------

local function onEliminated(_ps, kind: string, context)
	if not Match.active or Match.winner ~= nil then
		return
	end
	local entries = {}
	for _, other in ipairs(Match.list) do
		table.insert(entries, { role = other.role, alive = other.alive })
	end
	local _ = context
	local side, code = WinConditions.evaluate(entries)
	if not side then
		return
	end
	local reason
	if code == "KiraRemoved" then
		if kind == "voted" then
			reason = Terms.f("{Agency} voted out {hand}.")
		elseif kind == "arrested" then
			reason = Terms.f("{Zero} arrested {hand}.")
		elseif kind == "left" then
			reason = Terms.f("{Hand} fled the investigation.")
		else
			reason = Terms.f("{Hand} is gone.")
		end
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

-- Seconds of Ace's spotlight in the Bureau's ending (when Ace stands at the table and no win cutscene of theirs
-- already shows them).
local ACE_SHOT = 2.5

-- The winning side's lead (the owner's Q27, 2026-10-21): Diavolo for the Coven; for the Bureau its Ace, the one the
-- Butler named last when one was (never a Coven player named as a fake Ace), alive or dead. Nil when there is none.
local function sideLead(winner: string)
	if winner ~= "Team" then
		return Match.findRole("Kira")
	end
	local lead = nil
	for _, ps in ipairs(Match.list) do
		if ps.role == "L" and (not lead or (ps.appointedAt or 0) > (lead.appointedAt or 0)) then
			lead = ps
		end
	end
	return lead
end

-- How the ending goes (Presenters/Outro): the opening is the lead's win cutscene for everyone when they wear one (else
-- the sweep round the table), then the page of names, then Ace's spotlight (the Bureau's default), then Diavolo
-- under the lights. Every other winner who wears a win cutscene sees theirs on their own screen as the results come.
local function outroPlan(winner: string)
	local base = outroLength()
	local book = if base > 0 and #Match.written > 0 then ManualTiming.OUTRO else 0
	local half = math.max(0, base - book) / 2
	local side = if winner == "Team" then "bureau" else "coven"
	local lead = sideLead(winner)
	local cut = if lead and lead.player and lead.player.Parent then CosmeticsService.winCut(lead.player, side) else nil
	local cutLength = if cut then WinCuts[cut] and WinCuts[cut].length or 0 else 0
	local opening = if cutLength > 0 then cutLength else half
	-- (Ace's spotlight: the Bureau won with no win cutscene of Ace's, and Ace stands at the table)
	local ace = if winner == "Team" and cutLength == 0 and base > 0 and lead and lead.alive then ACE_SHOT else 0
	local private = {}
	for _, ps in ipairs(Match.list) do
		if ps ~= lead and ps.player and (winner == "Team") ~= Match.isKiraSide(ps) then
			local mine = CosmeticsService.winCut(ps.player, side)
			if mine then
				table.insert(private, { userId = ps.userId, cut = mine })
			end
		end
	end
	return {
		lead = if lead then lead.userId else nil,
		leadAlias = if lead then lead.alias else nil,
		centrepiece = if cutLength > 0 then cut else nil,
		timing = { opening = opening, book = book, ace = ace, hand = half },
		aceUserId = if ace > 0 and lead then lead.userId else nil,
		private = private,
		length = if base > 0 then opening + book + ace + half else 0,
	}
end

-- The ending cutscene: everyone still standing is gathered in the meeting room, the camera
-- finds the Hand, and each side hears its own music.
local function outroData(winner: string)
	local hand = Match.findRole("Kira")
	local zero = Match.findRole("L")
	local winners = {}
	for _, ps in ipairs(Match.list) do
		if (winner == "Team") ~= Match.isKiraSide(ps) then
			table.insert(winners, ps.userId)
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
	ChatService.setMeetingOpen(false)
	MeetingService.gather()
	if Match.debugFastEnd then
		return -- ended from the debug panel: straight to the lobby
	end
	local data = outroData(Match.winner or "Kira")
	local plan = outroPlan(Match.winner or "Kira")
	data.duration = plan.length
	data.lead = plan.lead
	data.leadAlias = plan.leadAlias
	data.centrepiece = plan.centrepiece
	data.timing = plan.timing
	data.aceUserId = plan.aceUserId
	data.private = plan.private
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
		Cues.fire("eyesDeal", { lifespan = Config.OCULUS_LIFESPAN }, to)
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
		local title = CosmeticsService.titleOf(ps.player)
		table.insert(roster, {
			userId = ps.userId,
			alias = ps.alias,
			displayName = ps.displayName,
			realName = ps.realName,
			role = ps.role,
			status = ps.status,
			cause = ps.cause,
			title = if title then title.name else nil,
			titleRarity = if title then title.rarity else nil,
			titleId = if title then title.id else nil,
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
	runPhase("Outro", startOutro, nil, { uncuttable = true, length = outroPlan(Match.winner or "Kira").length })
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
	local userIds = {}
	for _, ps in ipairs(Match.list) do
		table.insert(userIds, ps.userId)
	end
	local map = MapService.build(mapId, userIds)
	Match.map = map
	Match.mapId = mapId
	Match.mapName = map.name

	for _, ps in ipairs(Match.list) do
		Analytics.step(ps.player, "matchStarted")
		-- Starting a case ends the Trial for good (the user's call, 2026-10-27): a half-done Trial is not
		-- offered again (the Academy's gate can still begin it), and its client puts the wisp and panel away.
		local data = DataService.get(ps.player)
		if data and Trial.skip(data) then
			DataService.push(ps.player)
			DataService.saveSoon(ps.player)
		end
	end

	EventLog.reset()
	RoleService.assign()
	NameService.assign()
	-- Ace's title starts with the Ace role (the Butler can hand it on later).
	for _, ps in ipairs(Match.list) do
		ps.isAce = ps.role == "L"
	end
	EventLog.add(Terms.f("{n} {agents} were deployed to {map}.", { n = #Match.list, map = map.name }), "start")
	for _, ps in ipairs(Match.list) do
		EventLog.add(
			string.format("%s was %s. Real name: %s.", ps.alias, Terms.role(ps.role, "a"), ps.realName),
			"role"
		)
	end

	TaskBarService.onMatchStart()
	DeathNoteService.onMatchStart()
	CaseFileService.onMatchStart(map)
	NoteService.onMatchStart(map)
	MeetingService.onMatchStart(map)
	ChatService.onMatchStart()
	GhostService.onMatchStart()
	WagerService.onMatchStart()
	Mechanics.start(map)

	local starts = MapService.dealSpawns(map, #Match.list, Match.rng)
	for i, ps in ipairs(Match.list) do
		ps.player.CameraMaxZoomDistance = MATCH_ZOOM
		if ps.player.Character then
			CharacterService.applyOutfit(ps.player)
			CharacterService.placeAt(ps.player, starts[i])
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
	LoadGate.wait(map.loadToken, players, LOAD_TIMEOUT, LOAD_GRACE)

	Cues.reset()
	runPhase("Intro", startIntro)
	runPhase("Briefing", sendBriefings, nil, { length = briefingLength() })

	-- Match.round counts the meetings (free roam N ends in meeting N).
	local cycle = 0
	while not Match.winner do
		cycle += 1
		Match.round = cycle
		runPhase("Investigation", startInvestigation, endInvestigation)
		if Match.winner then
			break
		end
		-- The call stays set until the meeting starts, so nothing else in free roam (a second death
		-- due, the Oculus' clock) runs while the death scenes play.
		local call = Match.meetingCall or { reason = "timer" }
		Match.meetingCall = call
		Cues.waitHolds(40)
		if Match.winner then
			break
		end
		MeetingService.gather()
		interlude("meetingIntro", { cast = meetingCast() }, MEETING_INTRO)
		runPhase("Meeting", function()
			Match.meetingCall = nil
			-- (seated now: the intro's montage ends with everyone at their places, the meeting opens in the chairs)
			MeetingService.gather(true)
			MeetingService.setScreen(meetingReason(call))
			ChatService.setMeetingOpen(true)
			Match.announce(Terms.f("{Meeting}"), meetingReason(call), "neutral")
		end)
		if Match.winner then
			break
		end
		local result = nil
		runPhase("Vote", function()
			VoteService.open()
		end, function()
			if Match.winner then
				VoteService.cancel()
			else
				result = VoteService.tally()
			end
		end)
		if result then
			-- The verdict plays in full, even when voting out the Hand ends the match.
			runPhase("Verdict", function()
				-- (the one voted out gets up out of their chair before the verdict lands)
				if result.removed then
					MeetingService.standUp(result.removed)
				end
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
		-- Let an arrest's scene play out before free roam starts again.
		Cues.waitHolds(6)
	end
	finale()
end

local function cleanup()
	CaseFileService.onMatchEnd()
	NoteService.onMatchEnd()
	DeathNoteService.onMatchEnd()
	EyesService.onMatchEnd()
	HackService.onMatchEnd()
	SabotageService.clear()
	ArrestService.onMatchEnd()
	VoteService.cancel()
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
