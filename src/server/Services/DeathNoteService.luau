-- The Death Note phase. Every living player gets a private screen at once: Kira types
-- one full real name into the Death Note, everyone else files a short report and picks
-- the player they suspect most. A correct name kills its target when the phase is over (resolve(),
-- before the meeting), each death its own scene. A wrong name fails silently.
--
-- Death's Manual is seen at work (the owner, 2026-10-12): Kira alone sees the name he wrote go into
-- the book (the same for a wrong name); a death by it opens on the book with the victim's real name
-- and the cause written in it, and the body falls when that shot is over; the ending shows every name
-- written in the match (Match.written).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local CharacterService = require(script.Parent.CharacterService)
local Cues = require(script.Parent.Cues)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local SuspicionService = require(script.Parent.SuspicionService)
local TextFilter = require(script.Parent.TextFilter)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LInboxRemote = Net.event("LInbox")

local DeathNoteService = {}

-- The deaths written this phase, in the order they were written (resolve() carries them out).
local pending: { { target: any, kira: any, cause: string, matchId: number, writtenAt: number, entry: any } } = {}

local CUE_LEAD = 0.35

local function kill(target, kira, cause: string, matchId: number, writtenAt: number?, entry)
	local function stillOn(): boolean
		return Match.id == matchId and Match.active and Match.winner == nil and target.alive
	end
	if not stillOn() then
		return
	end
	-- The book first, then the death: the cutscene opens on the name being written (its real name,
	-- public from now on: the owner's choice), and the body falls as that shot ends.
	Cues.fire("death", {
		userId = target.userId,
		alias = target.alias,
		cause = cause,
		realName = target.realName,
		written = true,
	}, { hold = ManualTiming.HOLD, lead = CUE_LEAD })
	task.delay(CUE_LEAD + ManualTiming.BOOK, function()
		if not stillOn() then
			return
		end
		kira.stats.kills += 1
		EventLog.ink(kira, target, writtenAt or Match.elapsed())
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

local function onWrite(player: Player, payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or ps.role ~= "Kira" or Match.phase ~= "DeathNote" then
		return
	end
	if ps.dnRound == Match.round then
		Match.notify(player, "You have already written a name this round.", "bad")
		return
	end
	local typed = Util.cleanText(payload.name, Config.NAME_MAX_LENGTH)
	if #typed == 0 then
		return
	end
	local cause = "Heart attack"
	if type(payload.cause) == "string" and table.find(Config.DEATH_CAUSES, payload.cause) then
		cause = payload.cause
	end
	ps.dnRound = Match.round

	-- Names of Kira and the followers count as wrong names.
	local target = nil
	for _, other in ipairs(Match.living()) do
		if not Match.isKiraSide(other) and NameUtil.matches(typed, other.first, other.last) then
			target = other
			break
		end
	end

	local shown = TextFilter.broadcast(typed, player.UserId) or "(unreadable)"
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
			writtenAt = Match.elapsed(),
			entry = entry,
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
	Match.notify(player, "The name has been written.", "secret")
	Match.pushPrivate(ps)
	-- The writer, and only the writer, sees it go into the book: the same shot for a right name and a
	-- wrong one.
	Cues.fire("manualWrite", { name = shown }, { to = { player }, lead = 0.25 })
end

local function onReport(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or ps.role == "Kira" or Match.phase ~= "DeathNote" then
		return
	end
	if ps.reportRound == Match.round then
		Match.notify(player, "You already filed a report this round.", "bad")
		return
	end
	local suspect = if type(payload.suspect) == "number" then Match.getByUserId(payload.suspect) else nil
	if not suspect or not suspect.alive or suspect == ps then
		Match.notify(player, "Pick a living suspect first.", "bad")
		return
	end
	local text = if type(payload.text) == "string" then Util.cleanText(payload.text, Config.REPORT_MAX_LENGTH) else ""
	ps.reportRound = Match.round
	SuspicionService.add(suspect, Config.SUSPICION.REPORT)

	local l = Match.findRole("L")
	if l and l.alive and l ~= ps then
		local filtered = ""
		if #text > 0 then
			filtered = TextFilter.forUser(text, player.UserId, l.userId) or "(unreadable)"
		end
		LInboxRemote:FireClient(l.player, {
			kind = "report",
			text = filtered,
			suspect = suspect.alias,
			round = Match.round,
			clock = Match.clock(),
		})
	end
	Match.notify(player, "Report filed.", "info")
	ps.stats.reports += 1
	Match.pushPrivate(ps)
end

-- Debug panel: kills a player the way the Grimoire does (collapse, cutscene, announcement).
function DeathNoteService.debugKill(target, cause: string?)
	local kira = Match.findRole("Kira") or target
	kill(target, kira, cause or "Heart attack", Match.id)
end

function DeathNoteService.open()
	for _, ps in ipairs(Match.living()) do
		CharacterService.setWriting(ps.player, true)
	end
end

function DeathNoteService.close()
	for _, ps in ipairs(Match.list) do
		CharacterService.setWriting(ps.player, false)
	end
end

-- The phase is over: every name written in it takes its victim now, each with its own scene (the
-- death cue holds the match loop while it plays).
function DeathNoteService.resolve()
	local due = pending
	pending = {}
	for _, death in ipairs(due) do
		kill(death.target, death.kira, death.cause, death.matchId, death.writtenAt, death.entry)
	end
end

-- Queues a death for the next resolve() (the Deathsinger's deal takes its maker this way).
function DeathNoteService.queue(target, kira, cause: string)
	table.insert(
		pending,
		{ target = target, kira = kira, cause = cause, matchId = Match.id, writtenAt = Match.elapsed(), entry = nil }
	)
end

function DeathNoteService.init()
	DeathNoteRemote.OnServerEvent:Connect(onWrite)
	ReportRemote.OnServerEvent:Connect(onReport)
end

return DeathNoteService
