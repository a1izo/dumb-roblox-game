-- The Death Note phase. Every living player gets a private screen at once: Kira types
-- one full real name into the Death Note, everyone else files a short report and picks
-- the player they suspect most. A correct name kills its target 40 seconds later,
-- during the meeting. A wrong name fails silently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent.CharacterService)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local SuspicionService = require(script.Parent.SuspicionService)
local TextFilter = require(script.Parent.TextFilter)

local DeathNoteRemote = Net.event("DeathNote")
local ReportRemote = Net.event("Report")
local LInboxRemote = Net.event("LInbox")

local DeathNoteService = {}

local function kill(target, kira, cause: string, matchId: number)
	if Match.id ~= matchId or not Match.active or Match.winner ~= nil or not target.alive then
		return
	end
	kira.stats.kills += 1
	Elimination.eliminate(
		target,
		"dead",
		cause,
		string.format("%s collapsed. Cause of death: %s.", target.alias, string.lower(cause)),
		{ byKira = true }
	)
	Match.announce(target.alias .. " is dead", "Cause of death: " .. cause, "danger")
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
	if target then
		EventLog.add(
			string.format('Kira (%s) wrote "%s" in the Death Note. %s was doomed.', ps.alias, shown, target.alias),
			"kill"
		)
		local matchId = Match.id
		-- The death lands 40 seconds later, clamped so it always falls inside the meeting.
		local remaining = math.max(0, Match.phaseEndsAt - workspace:GetServerTimeNow())
		local meeting = Match.phaseLength("Meeting")
		local delay = math.clamp(Config.DEATH_DELAY, remaining + 3, remaining + math.max(4, meeting - 3))
		task.delay(delay, kill, target, ps, cause, matchId)
	else
		EventLog.add(
			string.format('Kira (%s) wrote "%s" in the Death Note, but the name matched no one.', ps.alias, shown),
			"miss"
		)
	end
	Match.notify(player, "The name has been written.", "secret")
	Match.pushPrivate(ps)
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
	Match.pushPrivate(ps)
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
