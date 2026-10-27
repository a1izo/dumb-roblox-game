-- Case-file stations. Each task is a puzzle from the station type's pool (Shared/Tasks): the server
-- sends its id and seed, and the case file counts the moment a right answer comes back. Every
-- case file a Bureau player finishes fills the Bureau's shared task bar (TaskBarService), which never
-- says who did it. Bureau Specters can keep working them. Diavolo and the Muertos cannot use stations
-- at all; they can hack one instead (HackService), to read who finished a case file there last,
-- and a Muerto can jam the stations in an area for a while (SabotageService).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tasks = Shared:WaitForChild("Tasks")
local Config = require(Shared:WaitForChild("Config"))
local PuzzleSet = require(Tasks:WaitForChild("PuzzleSet"))
local TaskTypes = require(Tasks:WaitForChild("TaskTypes"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)
local TaskBarService = require(script.Parent.TaskBarService)

local TaskRequest = Net.event("TaskRequest")
local TaskStateRemote = Net.event("TaskState")

local CaseFileService = {}

local stations = {} -- id -> runtime record
local order = {}
local working = {} -- [playerState] = runtime record
local monitorConnection: RBXScriptConnection? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function jammed(runtime): boolean
	return now() < runtime.jammedUntil
end

local function setScreen(runtime, busy: boolean)
	local info = runtime.info
	local isJammed = jammed(runtime)
	info.desk:SetAttribute("Busy", busy)
	info.desk:SetAttribute("JammedUntil", if isJammed then runtime.jammedUntil else nil)
	-- (The name is the screen's own header; this is its state line, red while jammed.)
	local label = info.label
	if label:GetAttribute("Calm") == nil then
		label:SetAttribute("Calm", label.TextColor3)
	end
	label.Text = if isJammed then "JAMMED" elseif busy then "ANALYSING…" else "READY"
	label.TextColor3 = if isJammed then Color3.fromRGB(235, 72, 72) else label:GetAttribute("Calm")
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

-- Who may work a station: living Bureau players, and Bureau Specters still in the case.
local function canWork(ps): boolean
	if Match.isKiraSide(ps) then
		return false
	end
	return ps.alive or (ps.status ~= "left" and ps.away ~= true)
end

-- Locks every station in the map area around `position` (the three closest when that area has none)
-- for `seconds`. Returns the names of the stations jammed.
function CaseFileService.jamNear(position: Vector3, seconds: number): { string }
	local area = Match.nearestArea(position)
	local chosen = {}
	for _, runtime in ipairs(order) do
		if Match.nearestArea(runtime.info.position) == area then
			table.insert(chosen, runtime)
		end
	end
	if #chosen == 0 then
		local sorted = table.clone(order)
		table.sort(sorted, function(a, b)
			return (a.info.position - position).Magnitude < (b.info.position - position).Magnitude
		end)
		for i = 1, math.min(3, #sorted) do
			table.insert(chosen, sorted[i])
		end
	end
	local names = {}
	local untilTime = now() + seconds
	for _, runtime in ipairs(chosen) do
		runtime.jammedUntil = untilTime
		if runtime.worker then
			stopWork(runtime.worker, "The station jammed.")
		end
		setScreen(runtime, false)
		table.insert(names, runtime.info.name)
	end
	local matchId = Match.id
	task.delay(seconds + 0.1, function()
		if Match.id ~= matchId then
			return
		end
		for _, runtime in ipairs(chosen) do
			if not jammed(runtime) then
				setScreen(runtime, runtime.worker ~= nil or runtime.hacker ~= nil)
			end
		end
	end)
	return names
end

-- Close enough to the station, with it in sight (no case file worked, or hacked, through a wall).
local function reaches(ps, runtime): boolean
	local position = Match.position(ps)
	if not position or (position - runtime.info.position).Magnitude > Config.TASK_RANGE + 2 then
		return false
	end
	local eye = Match.eyePosition(ps)
	return eye ~= nil and Match.hasLineOfSight(eye, runtime.info.position, runtime.info.model)
end

-- Hacking (HackService) ----------------------------------------------------------------------

-- Why this player cannot start hacking this station (nil: they can). A hacked station looks busy,
-- exactly as if a case file were being worked there.
function CaseFileService.hackProblem(ps, stationId: string): string?
	local runtime = stations[stationId]
	if not runtime then
		return "missing"
	elseif jammed(runtime) then
		return "jammed"
	elseif runtime.worker or runtime.hacker then
		return "busy"
	elseif now() < runtime.hackLockedUntil then
		return "locked"
	elseif not reaches(ps, runtime) then
		return "far"
	end
	return nil
end

function CaseFileService.beginHack(ps, stationId: string)
	local runtime = stations[stationId]
	runtime.hacker = ps
	setScreen(runtime, true)
	markWorking(ps, true, runtime.info.type)
end

-- The hack is over (done, failed or broken off). lockFor: seconds before anyone may hack it again.
function CaseFileService.endHack(ps, stationId: string, lockFor: number?)
	local runtime = stations[stationId]
	if not runtime or runtime.hacker ~= ps then
		return
	end
	runtime.hacker = nil
	markWorking(ps, false)
	if lockFor then
		runtime.hackLockedUntil = now() + lockFor
	end
	setScreen(runtime, false)
end

function CaseFileService.isJammed(stationId: string): boolean
	local runtime = stations[stationId]
	return runtime ~= nil and jammed(runtime)
end

-- Who finished a case file at this station at or after `since` (server time), if anyone.
function CaseFileService.lastUser(stationId: string, since: number)
	local runtime = stations[stationId]
	if runtime and runtime.lastUser and runtime.lastAt >= since then
		return runtime.lastUser
	end
	return nil
end

-- The station's name and where it stands.
function CaseFileService.stationInfo(stationId: string)
	local runtime = stations[stationId]
	return if runtime then runtime.info else nil
end

-- Task flow ----------------------------------------------------------------------------

local function finish(ps, runtime)
	markWorking(ps, false)
	working[ps] = nil
	ps.taskStation = nil
	runtime.worker = nil
	setScreen(runtime, false)
	-- What a hack reads: who finished here last, and when.
	runtime.lastUser = ps
	runtime.lastAt = now()
	ps.tasksThisRound += 1
	ps.stats.tasks += 1
	TaskStateRemote:FireClient(ps.player, { state = "done", stationId = runtime.info.id })
	Match.pushPrivate(ps)
	TaskBarService.add(1)
end

local function onStart(ps, stationId: string)
	if Match.phase ~= "Investigation" or working[ps] then
		return
	end
	local runtime = stations[stationId]
	if not runtime then
		return
	end
	if jammed(runtime) then
		Match.notify(ps.player, "This station is jammed. Try another one.", "bad")
		return
	end
	if runtime.worker or runtime.hacker then
		Match.notify(ps.player, "Someone is already working at this station.", "bad")
		return
	end
	if not reaches(ps, runtime) then
		return
	end
	runtime.worker = ps
	runtime.startedAt = os.clock()
	runtime.puzzle = TaskTypes.pickPuzzle(runtime.info.type, Match.rng)
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
		puzzle = runtime.puzzle,
		seed = runtime.seed,
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
	local position = Match.position(ps)
	if not position or (position - runtime.info.position).Magnitude > Config.TASK_RANGE + 4 then
		stopWork(ps, "You moved away from the station.")
		return
	end
	-- (an answer quicker than anyone could really solve the puzzle is an exploit's: refused as a wrong one)
	local quick = os.clock() - (runtime.startedAt or 0) < PuzzleSet.minSeconds(runtime.puzzle)
	if quick or not PuzzleSet.verify(runtime.puzzle, runtime.seed, answer) then
		TaskStateRemote:FireClient(ps.player, { state = "wrong", stationId = stationId })
		return
	end
	finish(ps, runtime)
end

local function onTaskRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.stationId) ~= "string" then
		return
	end
	local ps = if Match.active then Match.get(player) else nil
	if not ps or not RateLimit.allow(player, "task", 0.25) then
		return
	end
	if not canWork(ps) then
		if Match.isKiraSide(ps) and payload.action == "start" then
			Match.notify(player, Terms.f("{Circle} cannot work case files."), "bad")
		end
		return
	end
	if payload.action == "start" then
		onStart(ps, payload.stationId)
	elseif payload.action == "complete" then
		onComplete(ps, payload.stationId, payload.answer)
	elseif payload.action == "cancel" then
		if working[ps] and working[ps].info.id == payload.stationId then
			stopWork(ps, nil)
		end
	end
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
			puzzle = nil,
			seed = 0,
			jammedUntil = 0,
			hacker = nil,
			hackLockedUntil = 0,
			lastUser = nil,
			lastAt = 0,
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
			if not canWork(ps) then
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

-- Debug panel: finishes a case file for this player at the nearest free station right now.
function CaseFileService.debugFinish(ps): string?
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
	working[ps] = best
	finish(ps, best)
	return best.info.name
end

function CaseFileService.init()
	TaskRequest.OnServerEvent:Connect(onTaskRequest)
end

return CaseFileService
