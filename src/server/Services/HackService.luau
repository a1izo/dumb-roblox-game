-- Hacking a station: how Diavolo and the Muertos learn real names. At a free station (in reach and
-- in sight) a Coven player starts a hack; from outside it looks exactly like someone working a
-- case file. The hack is HACK_STAGES timing checks (UI/HackScreen, after GTA Online's data crack)
-- over about HACK_TIME seconds. All passed: the hacker reads the real name of whoever finished a case
-- file there in the HACK_WINDOW seconds before the hack began (if anyone did), and learns it. One
-- missed: the station's alarm goes off for everyone (it is marked on every screen for ALARM_TIME
-- seconds, without saying who), the hack ends and the station cannot be hacked for HACK_LOCK seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CaseFileService = require(script.Parent.CaseFileService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local HackRemote = Net.event("Hack")
local HackStateRemote = Net.event("HackState")
local EyesNameRemote = Net.event("EyesName")

local HackService = {}

type Hack = { stationId: string, startedAt: number, passed: number, clock: number }

-- [playerState] = the hack in progress.
local hacks: { [any]: Hack } = {}
local monitor: RBXScriptConnection? = nil
local elapsed = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Ends a hack with no result. reason (shown to the hacker) is nil when they broke it off themself.
local function stop(ps, reason: string?, lockFor: number?)
	local hack = hacks[ps]
	if not hack then
		return
	end
	hacks[ps] = nil
	ps.hacking = nil
	CaseFileService.endHack(ps, hack.stationId, lockFor)
	HackStateRemote:FireClient(ps.player, { state = "stopped", reason = reason })
end

-- A missed check: the station's alarm for everyone, never naming who.
local function alarm(ps, hack: Hack)
	local info = CaseFileService.stationInfo(hack.stationId)
	-- (no words for the hacker or anyone else: the red station says it all)
	stop(ps, nil, Config.HACK_LOCK)
	if not info then
		return
	end
	info.desk:SetAttribute("AlarmUntil", now() + Config.ALARM_TIME)
	EventLog.add(
		string.format("%s (%s) set off the alarm hacking %s.", ps.alias, Terms.role(ps.role), info.name),
		"hack"
	)
end

-- Every check passed: read the station's log.
local function finish(ps, hack: Hack)
	local info = CaseFileService.stationInfo(hack.stationId)
	local target = CaseFileService.lastUser(hack.stationId, hack.startedAt - Config.HACK_WINDOW)
	stop(ps, nil, nil)
	local stationName = if info then info.name else "the station"
	if not target or target == ps or not target.alive then
		HackStateRemote:FireClient(ps.player, { state = "empty" })
		Match.notify(
			ps.player,
			string.format("Nobody used %s in the last %ds.", stationName, Config.HACK_WINDOW),
			"secret"
		)
		return
	end
	ps.learned[target.userId] = true
	ps.stats.reads += 1
	HackStateRemote:FireClient(ps.player, { state = "read", alias = target.alias, name = target.realName })
	EyesNameRemote:FireClient(ps.player, {
		userId = target.userId,
		name = target.realName,
		duration = Config.EYES_DURATION,
	})
	EventLog.add(
		string.format(
			"%s (%s) hacked %s and read %s's real name.",
			ps.alias,
			Terms.role(ps.role),
			stationName,
			target.alias
		),
		"hack"
	)
	Match.pushPrivate(ps)
end

-- Why this player cannot hack right now, whatever the station (nil: they can).
local function playerProblem(ps): string?
	if not ps.alive or not Match.isKiraSide(ps) then
		return "role"
	elseif Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return "phase"
	elseif ps.writing or ps.ritual or hacks[ps] then
		return "busy"
	end
	return nil
end

local PROBLEM_TEXT = {
	busy = "Station in use.",
	locked = "Locked after an alarm.",
}

local function start(ps, stationId)
	if type(stationId) ~= "string" or playerProblem(ps) then
		return
	end
	local problem = CaseFileService.hackProblem(ps, stationId)
	if problem then
		local text = PROBLEM_TEXT[problem]
		if text then
			Match.notify(ps.player, text, "bad")
		end
		return
	end
	local hack = { stationId = stationId, startedAt = now(), passed = 0, clock = os.clock() }
	hacks[ps] = hack
	ps.hacking = true
	CaseFileService.beginHack(ps, stationId)
	local info = CaseFileService.stationInfo(stationId)
	HackStateRemote:FireClient(ps.player, {
		state = "started",
		stationId = stationId,
		stationName = if info then info.name else "",
		stages = Config.HACK_STAGES,
		duration = Config.HACK_TIME,
		seed = Match.rng:NextInteger(1, 2 ^ 30),
	})
end

local function stage(ps, index, ok)
	local hack = hacks[ps]
	if not hack or type(index) ~= "number" or index ~= hack.passed + 1 then
		return
	end
	if ok ~= true then
		alarm(ps, hack)
		return
	end
	hack.passed = index
	if hack.passed >= Config.HACK_STAGES then
		-- No hack finishes quicker than a person could play it.
		if os.clock() - hack.clock < Config.HACK_MIN_TIME then
			alarm(ps, hack)
			return
		end
		finish(ps, hack)
	end
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or not RateLimit.allow(player, "hack", 0.2) then
		return
	end
	if payload.action == "start" then
		start(ps, payload.stationId)
	elseif payload.action == "stage" then
		stage(ps, payload.index, payload.ok)
	elseif payload.action == "cancel" then
		stop(ps, nil, nil)
	end
end

-- Moving off, the end of free roam or a hack left hanging all break a hack off.
local function watch(dt: number)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	for ps, hack in pairs(table.clone(hacks)) do
		local info = CaseFileService.stationInfo(hack.stationId)
		local position = Match.position(ps)
		if not ps.alive or Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
			stop(ps, "The hack was cut off.", nil)
		elseif not info or not position or (position - info.position).Magnitude > Config.TASK_RANGE + 4 then
			stop(ps, "You moved away.", nil)
		elseif os.clock() - hack.clock > Config.HACK_TIME + 20 then
			stop(ps, "The hack timed out.", nil)
		end
	end
end

-- Free roam is over: every hack stops.
function HackService.interrupt()
	for ps in pairs(table.clone(hacks)) do
		stop(ps, nil, nil)
	end
end

-- Bots: a hack with every check passed or the first one missed, as a player's would go.
function HackService.botStart(ps, stationId: string)
	start(ps, stationId)
end

function HackService.botStage(ps, ok: boolean)
	local hack = hacks[ps]
	if hack then
		stage(ps, hack.passed + 1, ok)
	end
end

function HackService.isHacking(ps): boolean
	return hacks[ps] ~= nil
end

function HackService.onMatchEnd()
	hacks = {}
end

function HackService.init()
	HackRemote.OnServerEvent:Connect(onRequest)
	if monitor then
		monitor:Disconnect()
	end
	monitor = RunService.Heartbeat:Connect(watch)
	Match.Eliminated:Connect(function(ps)
		stop(ps, nil, nil)
	end)
end

return HackService
