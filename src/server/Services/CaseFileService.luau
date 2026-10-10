-- Case-file stations. A task takes about 15 seconds; finishing it posts a clue to the
-- evidence board and flashes three new letters of the worker's real name to players
-- close by with a clear line of sight. Each task is a puzzle from the station type's pool
-- (Shared/Tasks): the server sends its id and seed, and checks the answer before accepting. Kira's side (the Hand and Cultists) can fake tasks (no
-- flash, no board entry) and a Cultist can rig a station so its next real flash shows false letters.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tasks = Shared:WaitForChild("Tasks")
local Config = require(Shared:WaitForChild("Config"))
local PuzzleSet = require(Tasks:WaitForChild("PuzzleSet"))
local TaskTypes = require(Tasks:WaitForChild("TaskTypes"))
local LetterReveal = require(Shared:WaitForChild("LetterReveal"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))

local EventLog = require(script.Parent.EventLog)
local EvidenceService = require(script.Parent.EvidenceService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)
local SuspicionService = require(script.Parent.SuspicionService)

local TaskRequest = Net.event("TaskRequest")
local TaskStateRemote = Net.event("TaskState")
local TamperRemote = Net.event("Tamper")
local LetterFlashRemote = Net.event("LetterFlash")

local CaseFileService = {}

local stations = {} -- id -> runtime record
local order = {}
local working = {} -- [playerState] = runtime record
local monitorConnection: RBXScriptConnection? = nil

local function setScreen(runtime, busy: boolean)
	local info = runtime.info
	info.desk:SetAttribute("Busy", busy)
	info.label.Text = string.upper(info.name) .. (if busy then "\nANALYSING..." else "\nREADY")
end

-- Everyone sees who is working a station (their character plays that station type's working
-- animation: LWorking holds the type, "Camera", "Fingerprint", "Phone" or "Forensics").
local function markWorking(ps, on: boolean, stationType: string?)
	local character = ps.player.Character
	if character then
		character:SetAttribute("LWorking", if on then stationType or true else nil)
	end
end

local function stopWork(ps, reason: string?)
	local runtime = working[ps]
	if not runtime then
		return
	end
	markWorking(ps, false)
	working[ps] = nil
	ps.taskStation = nil
	runtime.worker = nil
	setScreen(runtime, false)
	if reason then
		TaskStateRemote:FireClient(ps.player, { state = "cancelled", stationId = runtime.info.id, reason = reason })
	end
	Match.pushPrivate(ps)
end

function CaseFileService.cancelAll(reason: string?)
	for ps in pairs(table.clone(working)) do
		stopWork(ps, reason)
	end
end

-- Players who can see the worker right now.
local function witnesses(ps)
	local result = {}
	local target = Match.eyePosition(ps)
	if not target then
		return result
	end
	for _, other in ipairs(Match.living()) do
		if other ~= ps and Match.canSee(other, target, Match.sightRange("witness"), nil) then
			table.insert(result, other)
		end
	end
	return result
end

-- Clues ------------------------------------------------------------------------------

local function cameraClue(worker): string
	local sighting = EventLog.takeSighting(90)
	if sighting then
		return string.format(
			"Camera %s: %s %s %s.",
			sighting.clock,
			sighting.alias,
			sighting.activity,
			EventLog.place(sighting)
		)
	end
	local others = {}
	for _, ps in ipairs(Match.living()) do
		if ps ~= worker then
			table.insert(others, ps)
		end
	end
	local other = Util.pick(others, Match.rng)
	if other then
		local position = Match.position(other)
		if position then
			return string.format(
				"Camera %s: %s was seen near %s.",
				Match.clock(),
				other.alias,
				Match.nearestArea(position)
			)
		end
	end
	return "Camera footage: nothing unusual on the recent tapes."
end

local function fingerprintClue(worker): string
	local entry = EventLog.takePrint(150)
	if entry then
		local handler = Match.getByUserId(entry.userId)
		if handler then
			local pool = {}
			for _, ps in ipairs(Match.living()) do
				if ps ~= handler then
					table.insert(pool, ps)
				end
			end
			Util.shuffle(pool, Match.rng)
			local candidates = { handler }
			for i = 1, math.min(2, #pool) do
				table.insert(candidates, pool[i])
			end
			Util.shuffle(candidates, Match.rng)
			local names = {}
			for _, ps in ipairs(candidates) do
				table.insert(names, ps.alias)
			end
			return "Prints on a handled paper note match one of: " .. table.concat(names, ", ") .. "."
		end
	end
	local candidates = {}
	for _, runtime in ipairs(order) do
		if runtime.lastWorker and runtime.lastWorker ~= worker then
			table.insert(candidates, runtime)
		end
	end
	local runtime = Util.pick(candidates, Match.rng)
	if runtime then
		return string.format("Fresh prints at %s belong to %s.", runtime.info.name, runtime.lastWorker.alias)
	end
	return "Fingerprints: no usable prints on the case files yet."
end

local function phoneClue(): string
	local kira = Match.findRole("Kira")
	if not kira then
		return "Phone records: no suspicious calls."
	end
	if Match.phoneFacts == 0 then
		Match.phoneFacts = 1
		return Terms.f("Phone records: {hand}'s first name has {n} letters.", { n = #kira.first })
	elseif Match.phoneFacts == 1 then
		Match.phoneFacts = 2
		return Terms.f("Phone records: {hand}'s last name has {n} letters.", { n = #kira.last })
	end
	local side = {}
	for _, ps in ipairs(Match.living()) do
		if Match.isKiraSide(ps) then
			table.insert(side, ps)
		end
	end
	local ping = Util.pick(side, Match.rng)
	local position = if ping then Match.position(ping) else nil
	if position then
		return string.format(
			"Phone records: a burner phone pinged near %s at %s.",
			Match.nearestArea(position),
			Match.clock()
		)
	end
	return "Phone records: the burner phone is switched off."
end

-- Forensics: ink analysis of the Grimoire's last deadly entry. The first analysis after each
-- death names three people, one of whom wrote it; the list is fixed for that death, so repeat
-- analyses cannot narrow it down. Later analyses of the same death give the time of writing.
local function forensicsClue(worker): string
	local entry = EventLog.lastInk()
	if not entry then
		return Terms.f("Forensics: no ink samples yet. Nobody has died by {grimoire}.")
	end
	local record = Match.forensics[entry.id]
	if not record then
		local pool = {}
		for _, ps in ipairs(Match.living()) do
			if ps.userId ~= entry.writerUserId and ps ~= worker then
				table.insert(pool, ps)
			end
		end
		Util.shuffle(pool, Match.rng)
		local names = { entry.writerAlias }
		for i = 1, math.min(Config.FORENSICS.CANDIDATES - 1, #pool) do
			table.insert(names, pool[i].alias)
		end
		Util.shuffle(names, Match.rng)
		record = { names = names, uses = 0 }
		Match.forensics[entry.id] = record
	end
	record.uses += 1
	if record.uses == 1 then
		return string.format(
			"Ink from the entry that killed %s matches the pen of one of: %s.",
			entry.victimAlias,
			table.concat(record.names, ", ")
		)
	end
	local slack = Config.FORENSICS.TIME_SLACK
	local low = math.max(0, entry.writtenAt - Match.rng:NextInteger(0, slack))
	return string.format(
		"The name of %s was written between %s and %s.",
		entry.victimAlias,
		Util.formatClock(low),
		Util.formatClock(low + slack)
	)
end

-- What finishing a task at a station of each type posts to the evidence board.
local CLUES: { [string]: (any) -> string } = {
	Camera = cameraClue,
	Fingerprint = fingerprintClue,
	Phone = function()
		return phoneClue()
	end,
	Forensics = forensicsClue,
}

local function makeClue(stationType: string, worker): string
	local clue = CLUES[stationType]
	if not clue then
		error("no clue for station type " .. tostring(stationType))
	end
	return clue(worker)
end

-- Task flow ----------------------------------------------------------------------------

local function finish(ps, runtime)
	markWorking(ps, false)
	working[ps] = nil
	ps.taskStation = nil
	runtime.worker = nil
	setScreen(runtime, false)
	ps.tasksThisRound += 1
	local info = runtime.info

	if runtime.fake then
		ps.stats.fakeTasks += 1
		local seen = witnesses(ps)
		if #seen > 0 then
			SuspicionService.add(ps, Config.SUSPICION.FAKE_TASK_SEEN)
		end
		EventLog.add(
			string.format(
				"%s (%s) faked a task at %s%s.",
				ps.alias,
				Terms.role(ps.role),
				info.name,
				if #seen > 0 then " while being watched" else ""
			),
			"fake"
		)
		TaskStateRemote:FireClient(ps.player, { state = "done", stationId = info.id, fake = true })
		Match.pushPrivate(ps)
		return
	end

	ps.stats.tasks += 1
	runtime.lastWorker = ps
	EvidenceService.post(ps.alias, info.name, makeClue(info.type, ps))

	local pattern
	if runtime.tamperedBy ~= nil and runtime.tamperRound == Match.round then
		pattern = LetterReveal.fakeMask(ps.realName, Config.LETTERS_PER_FLASH, Match.rng)
		EventLog.add(
			string.format(
				"%s's letter flash at %s showed false letters (rigged by %s).",
				ps.alias,
				info.name,
				runtime.tamperedBy.alias
			),
			"tamper"
		)
		runtime.tamperedBy = nil
		runtime.tamperRound = 0
	else
		local picks = LetterReveal.pickNew(ps.realName, ps.revealed, Config.LETTERS_PER_FLASH, Match.rng)
		for _, index in ipairs(picks) do
			ps.revealed[index] = true
		end
		pattern = LetterReveal.mask(ps.realName, picks)
	end

	-- Only the worker and players close by with a clear view get the flash.
	local payload = { stationId = info.id, alias = ps.alias, pattern = pattern, duration = Config.FLASH_DURATION }
	for _, other in ipairs(Match.living()) do
		if other == ps or Match.canSee(other, info.screen.Position, Match.sightRange("flash"), info.model) then
			LetterFlashRemote:FireClient(other.player, payload)
		end
	end
	TaskStateRemote:FireClient(ps.player, { state = "done", stationId = info.id, fake = false })
	Match.pushPrivate(ps)
end

local function onStart(ps, stationId: string, wantFake: boolean)
	if Match.phase ~= "Investigation" or working[ps] then
		return
	end
	local runtime = stations[stationId]
	if not runtime then
		return
	end
	if runtime.worker then
		Match.notify(ps.player, "Someone is already working at this station.", "bad")
		return
	end
	local position = Match.position(ps)
	if not position or (position - runtime.info.position).Magnitude > Config.TASK_RANGE + 2 then
		return
	end
	local fake = wantFake and Match.isKiraSide(ps)
	runtime.worker = ps
	runtime.startedAt = os.clock()
	runtime.fake = fake
	-- A faked task has no puzzle; a real one gets one from the station's pool.
	runtime.puzzle = if fake then nil else TaskTypes.pickPuzzle(runtime.info.type, Match.rng)
	runtime.seed = Match.rng:NextInteger(1, 2 ^ 30)
	working[ps] = runtime
	ps.taskStation = runtime.info.id
	setScreen(runtime, true)
	markWorking(ps, true, runtime.info.type)
	TaskStateRemote:FireClient(ps.player, {
		state = "started",
		stationId = runtime.info.id,
		stationType = runtime.info.type,
		stationName = runtime.info.name,
		fake = fake,
		puzzle = runtime.puzzle,
		seed = if fake then nil else runtime.seed,
		duration = Config.TASK_DURATION,
		startedAt = workspace:GetServerTimeNow(),
	})
	Match.pushPrivate(ps)
end

local function onComplete(ps, stationId: string, answer: any)
	local runtime = working[ps]
	if not runtime or runtime.info.id ~= stationId then
		return
	end
	if Match.phase ~= "Investigation" then
		stopWork(ps, "The investigation phase is over.")
		return
	end
	if os.clock() - runtime.startedAt < Config.TASK_DURATION - 0.75 then
		TaskStateRemote:FireClient(ps.player, { state = "wait", stationId = stationId })
		return
	end
	local position = Match.position(ps)
	if not position or (position - runtime.info.position).Magnitude > Config.TASK_RANGE + 4 then
		stopWork(ps, "You moved away from the station.")
		return
	end
	if not runtime.fake and not PuzzleSet.verify(runtime.puzzle, runtime.seed, answer) then
		TaskStateRemote:FireClient(ps.player, { state = "wrong", stationId = stationId })
		return
	end
	finish(ps, runtime)
end

local function onTaskRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.stationId) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or not RateLimit.allow(player, "task", 0.25) then
		return
	end
	if payload.action == "start" then
		onStart(ps, payload.stationId, payload.fake == true)
	elseif payload.action == "complete" then
		onComplete(ps, payload.stationId, payload.answer)
	elseif payload.action == "cancel" then
		if working[ps] and working[ps].info.id == payload.stationId then
			stopWork(ps, nil)
		end
	end
end

-- A follower rigs a station: its next real task this round flashes false letters.
local function onTamper(player: Player, stationId)
	if type(stationId) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or ps.role ~= "Follower" or Match.phase ~= "Investigation" then
		return
	end
	if ps.tamperRound == Match.round then
		Match.notify(player, "You already rigged a station this round.", "bad")
		return
	end
	local runtime = stations[stationId]
	local position = Match.position(ps)
	if not runtime or not position or (position - runtime.info.position).Magnitude > Config.INTERACT_RANGE + 2 then
		return
	end
	runtime.tamperedBy = ps
	runtime.tamperRound = Match.round
	ps.tamperRound = Match.round
	ps.stats.rigs += 1
	EventLog.add(
		Terms.f("{alias} ({cultist}) rigged the flash at {station}.", { alias = ps.alias, station = runtime.info.name }),
		"tamper"
	)
	Match.notify(
		player,
		"Rigged. The next real task at " .. runtime.info.name .. " this round will flash false letters.",
		"secret"
	)
	Match.pushPrivate(ps)
end

-- Lifecycle ------------------------------------------------------------------------------

function CaseFileService.onMatchStart(map)
	stations = {}
	order = {}
	working = {}
	for _, info in ipairs(map.stations) do
		local runtime = {
			info = info,
			worker = nil,
			startedAt = 0,
			fake = false,
			puzzle = nil,
			seed = 0,
			tamperedBy = nil,
			tamperRound = 0,
			lastWorker = nil,
		}
		stations[info.id] = runtime
		table.insert(order, runtime)
	end
	if monitorConnection then
		monitorConnection:Disconnect()
	end
	local elapsed = 0
	monitorConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for ps, runtime in pairs(table.clone(working)) do
			local position = Match.position(ps)
			if not ps.alive then
				stopWork(ps, nil)
			elseif not position or (position - runtime.info.position).Magnitude > Config.TASK_RANGE + 4 then
				stopWork(ps, "You moved away from the station.")
			end
		end
	end)
end

function CaseFileService.onMatchEnd()
	CaseFileService.cancelAll(nil)
	if monitorConnection then
		monitorConnection:Disconnect()
		monitorConnection = nil
	end
	stations = {}
	order = {}
	working = {}
end

-- Debug panel: finishes a real case file for this player at the nearest station right now
-- (clue on the board, letters flashed to whoever can see it).
function CaseFileService.debugFlash(ps): string?
	local position = Match.position(ps)
	if not position then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, runtime in pairs(stations) do
		local distance = (runtime.info.position - position).Magnitude
		if distance < bestDistance and (runtime.worker == nil or runtime.worker == ps) then
			best, bestDistance = runtime, distance
		end
	end
	if not best then
		return nil
	end
	if working[ps] and working[ps] ~= best then
		stopWork(ps, nil)
	end
	best.worker = ps
	best.fake = false
	working[ps] = best
	finish(ps, best)
	return best.info.name
end

function CaseFileService.init()
	TaskRequest.OnServerEvent:Connect(onTaskRequest)
	TamperRemote.OnServerEvent:Connect(onTamper)
	Match.Eliminated:Connect(function(ps)
		stopWork(ps, nil)
	end)
end

return CaseFileService
