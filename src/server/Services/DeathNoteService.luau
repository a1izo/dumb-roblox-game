-- The Death Note phase. Every living player gets a private screen at once: Kira types
-- one full real name into the Death Note, everyone else files a short report and picks
-- the player they suspect most. A correct name kills its target 40 seconds later,
-- during the meeting. A wrong name fails silently.
--
-- Death's Manual is seen at work (the owner, 2026-10-12): Kira alone sees the name he wrote go into
-- the book (the same for a wrong name); a death by it opens on the book with the victim's real name
-- and the cause written in it, and the body falls when that shot is over; the ending shows every name
-- written in the match (Match.written).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
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
local SuspicionService = require(script.Parent.SuspicionService)
local TextFilter = require(script.Parent.TextFilter)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LInboxRemote = Net.event("LInbox")

local DeathNoteService = {}

local CUE_LEAD = 0.35

local function kill(target, kira, cause: string, matchId: number, writtenAt: number?, entry)
	local function stillOn(): boolean
		return Match.id == matchId and Match.active and Match.winner == nil and target.alive
	end
	if not stillOn() then
		return
	end
	-- The book first, then the death: the cutscene opens on the name being written (its real name,
	-- public from now on: the owner's choice), and the body falls as that shot ends. The victim's death
	-- style plays for everyone; the writer's writing style only on the writer's own screen (who wrote is
	-- secret while the case runs).
	local data = {
		userId = target.userId,
		alias = target.alias,
		cause = cause,
		realName = target.realName,
		written = true,
		death = CosmeticsService.style(target.player, "death"),
	}
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
		local matchId = Match.id
		-- The death lands 40 seconds later, clamped so it and its cutscene both fall inside the meeting.
		local remaining = math.max(0, Match.phaseEndsAt - workspace:GetServerTimeNow())
		local delay = ManualTiming.killDelay(Config.DEATH_DELAY, remaining, Match.phaseLength("Meeting"))
		task.delay(delay, kill, target, ps, cause, matchId, Match.elapsed(), entry)
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
	Cues.fire(
		"manualWrite",
		{ name = shown, writing = CosmeticsService.style(player, "writing") },
		{ to = { player }, lead = 0.25 }
	)
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

function DeathNoteService.init()
	DeathNoteRemote.OnServerEvent:Connect(onWrite)
	ReportRemote.OnServerEvent:Connect(onReport)
end

return DeathNoteService
