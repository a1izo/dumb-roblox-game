-- Death's Manual (internal id "DeathNote"). Diavolo can write in it at any time during free roam,
-- but never unseen: he stands still for MANUAL_WRITE_TIME seconds with the book open and burning red.
-- A correct full real name kills its owner MANUAL_DELAY seconds of free roam later (the countdown
-- stops during meetings); a wrong name fails silently. Diavolo does not know the Muertos, so a
-- Muerto's name kills the Muerto too. Then the Manual is closed for MANUAL_COOLDOWN seconds.
--
-- A death opens on the book with the victim's real name and the cause written in it (the cutscene
-- plays for everyone at once) and calls a meeting; the ending shows every name written in the
-- match (Match.written).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local CharacterService = require(script.Parent.CharacterService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local Cues = require(script.Parent.Cues)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local TextFilter = require(script.Parent.TextFilter)

local DeathNoteRemote = Net.event("DeathNote")

local DeathNoteService = {}

-- Deaths written and waiting: seconds of free roam left before each takes its victim.
local pending: { { target: any, kira: any, cause: string, matchId: number, entry: any, left: number } } = {}
local ticker: RBXScriptConnection? = nil

local CUE_LEAD = 0.35

local function now(): number
	return workspace:GetServerTimeNow()
end

local function kill(target, kira, cause: string, matchId: number, entry)
	local function stillOn(): boolean
		return Match.id == matchId and Match.active and Match.winner == nil and target.alive
	end
	if not stillOn() then
		return
	end
	-- Free roam stops at once: everyone watches the death, then the meeting starts.
	Match.requestMeeting("death", target)
	-- The book first, then the death: the cutscene opens on the name being written, and the body falls
	-- as that shot ends. The victim's death style plays for everyone; the writer's writing style only on
	-- the writer's own screen (who wrote is secret while the case runs).
	local data = {
		userId = target.userId,
		alias = target.alias,
		cause = cause,
		realName = target.realName,
		written = true,
		death = CosmeticsService.style(target.player, "death"),
	}
	-- (a custom death written as the cause: its effect plays on the body as it falls, Presentation/CustomDeaths)
	local custom = Cosmetics.reasonByCause(cause)
	if custom then
		data.reason = custom.style
	end
	local writing = CosmeticsService.style(kira.player, "writing")
	if writing and typeof(kira.player) == "Instance" then
		local others = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= kira.player then
				table.insert(others, player)
			end
		end
		local mine = table.clone(data)
		mine.writing = writing
		local id = Cues.fire("death", mine, { hold = ManualTiming.HOLD, lead = CUE_LEAD, to = { kira.player } })
		Cues.fire("death", data, { lead = CUE_LEAD, to = others, sameAs = id })
	else
		Cues.fire("death", data, { hold = ManualTiming.HOLD, lead = CUE_LEAD })
	end
	task.delay(CUE_LEAD + ManualTiming.BOOK, function()
		if not stillOn() then
			return
		end
		if kira ~= target then
			kira.stats.kills += 1
		end
		Elimination.eliminate(
			target,
			"dead",
			cause,
			string.format("%s collapsed. Cause of death: %s.", target.alias, string.lower(cause)),
			{ byKira = true }
		)
		Match.announce(target.alias .. " is dead", "Cause of death: " .. cause, "danger")
		if entry then
			entry.struck = true
		end
	end)
end

-- Why Diavolo cannot start writing right now (nil: he can).
function DeathNoteService.writeProblem(ps): string?
	if not ps.alive or ps.role ~= "Kira" then
		return "role"
	elseif Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return "phase"
	elseif ps.writing then
		return "writing"
	elseif now() < ps.writeReadyAt then
		return "cooldown"
	end
	return nil
end

local function stopWriting(ps)
	ps.writing = nil
	CharacterService.setWriting(ps.player, false)
	CharacterService.setManualGlow(ps.player, false)
	CharacterService.setFrozen(ps.player, false)
end

-- The name is in the book: it dooms its owner (if it matches anyone) and the Manual closes.
local function finishWriting(ps, typed: string, cause: string)
	stopWriting(ps)
	ps.writeReadyAt = now() + Config.MANUAL_COOLDOWN

	-- Diavolo's own name never works; a Muerto's does.
	local target = nil
	for _, other in ipairs(Match.living()) do
		if other ~= ps and NameUtil.matches(typed, other.first, other.last) then
			target = other
			break
		end
	end

	local shown = TextFilter.broadcast(typed, ps.userId) or "(unreadable)"
	-- Every name written, for the ending's page (struck through once it kills).
	local entry = { name = shown, struck = false }
	table.insert(Match.written, entry)
	if target then
		EventLog.add(
			Terms.f(
				'{Hand} ({alias}) wrote "{name}" in {grimoire}. {target} was doomed.',
				{ alias = ps.alias, name = shown, target = target.alias }
			),
			"kill"
		)
		table.insert(pending, {
			target = target,
			kira = ps,
			cause = cause,
			matchId = Match.id,
			entry = entry,
			left = Config.MANUAL_DELAY,
		})
	else
		EventLog.add(
			Terms.f(
				'{Hand} ({alias}) wrote "{name}" in {grimoire}, but the name matched no one.',
				{ alias = ps.alias, name = shown }
			),
			"miss"
		)
	end
	Match.notify(ps.player, "The name is written. The Manual closes for a while.", "secret")
	Match.pushPrivate(ps)
end

-- Diavolo opens the Manual where he stands and writes: frozen, book open and glowing, for the whole
-- writing time. A meeting called in the middle stops it (nothing is written, no cooldown).
local function startWriting(ps, typed: string, cause: string)
	local token = {}
	ps.writing = token
	local player = ps.player
	CharacterService.setFrozen(player, true)
	CharacterService.setWriting(player, true)
	CharacterService.setManualGlow(player, true)
	Match.pushPrivate(ps)
	-- The writer, and only the writer, sees the name go into the book: the same shot for a right name
	-- and a wrong one.
	Cues.fire(
		"manualWrite",
		{ name = TextFilter.broadcast(typed, ps.userId) or "", writing = CosmeticsService.style(player, "writing") },
		{ to = { player }, lead = 0.25 }
	)
	local matchId = Match.id
	task.delay(Config.MANUAL_WRITE_TIME, function()
		if ps.writing ~= token or Match.id ~= matchId then
			return
		end
		if not ps.alive or Match.phase ~= "Investigation" then
			stopWriting(ps)
			Match.pushPrivate(ps)
			return
		end
		finishWriting(ps, typed, cause)
	end)
end

local function onWrite(player: Player, payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps then
		return
	end
	local problem = DeathNoteService.writeProblem(ps)
	if problem == "cooldown" then
		Match.notify(player, "The Manual is still closed.", "bad")
		return
	elseif problem then
		return
	end
	local typed = Util.cleanText(payload.name, Config.NAME_MAX_LENGTH)
	if #typed == 0 then
		return
	end
	local cause = "Heart attack"
	-- (one of the three plain causes, or the custom death the writer wears)
	local worn = Cosmetics.reason(CosmeticsService.style(player, "reason"))
	if type(payload.cause) == "string" then
		if table.find(Config.DEATH_CAUSES, payload.cause) then
			cause = payload.cause
		elseif worn and payload.cause == worn.cause then
			cause = worn.cause
		end
	end
	startWriting(ps, typed, cause)
end

-- The countdowns run only in free roam, so a death never lands in the middle of a meeting.
local function tick(dt: number)
	if
		not Match.active
		or Match.phase ~= "Investigation"
		or Match.meetingCall ~= nil
		or Match.debugPaused
		or #pending == 0
	then
		return
	end
	local due = {}
	for i = #pending, 1, -1 do
		local death = pending[i]
		death.left -= dt
		if death.left <= 0 then
			table.remove(pending, i)
			table.insert(due, 1, death)
		end
	end
	for _, death in ipairs(due) do
		kill(death.target, death.kira, death.cause, death.matchId, death.entry)
	end
end

-- Debug panel: kills a player the way the Manual does (cutscene, collapse, announcement).
function DeathNoteService.debugKill(target, cause: string?)
	local kira = Match.findRole("Kira") or target
	kill(target, kira, cause or "Heart attack", Match.id)
end

-- Debug panel: the Manual can be written in again right now.
function DeathNoteService.debugReady(ps)
	ps.writeReadyAt = 0
	Match.pushPrivate(ps)
end

function DeathNoteService.onMatchStart()
	pending = {}
end

function DeathNoteService.onMatchEnd()
	pending = {}
	for _, ps in ipairs(Match.list) do
		if ps.writing then
			stopWriting(ps)
		end
	end
end

-- Free roam is over (a meeting or the end): anyone in the middle of writing stops.
function DeathNoteService.interrupt()
	for _, ps in ipairs(Match.list) do
		if ps.writing then
			stopWriting(ps)
			Match.pushPrivate(ps)
		end
	end
end

function DeathNoteService.init()
	DeathNoteRemote.OnServerEvent:Connect(onWrite)
	if ticker then
		ticker:Disconnect()
	end
	ticker = RunService.Heartbeat:Connect(tick)
	Match.Eliminated:Connect(function(ps)
		if ps.writing then
			stopWriting(ps)
		end
	end)
end

return DeathNoteService
