-- Ace's arrest and the Butler's succession.
--
-- Ace (role id "L") is secret: only the Butler knows who holds the title. Once per match, during a
-- meeting or the vote, Ace points at a living player. A Coven player is arrested and removed; an
-- innocent one walks free and Ace dies instead. Either way the arrest reveals Ace to everyone.
--
-- When Ace dies, the Butler (role id "Watari") has BUTLER_PICK_TIME seconds to name the next Ace:
-- any other living player, once per match. The new Ace gets a fresh arrest. A Coven player named by
-- mistake is told they hold a fake title: their arrest fizzles and shows them up as a fake Ace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local Cues = require(script.Parent.Cues)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local MeetingService = require(script.Parent.MeetingService)

local ArrestRemote = Net.event("Arrest")
local ButlerPickRemote = Net.event("ButlerPick")

local ArrestService = {}

-- The Butler's pick in progress: who may pick, until when, and its match.
local pick: { butler: any, endsAt: number, matchId: number }? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The arrest cutscene (its result is announced publicly anyway). Ace's verdict style shows on Ace's
-- own screen, and on everyone's when the arrest is right.
local function playArrest(ace, suspect, result: string)
	-- (arrested at the table, they get up out of their chair first)
	MeetingService.standUp(suspect)
	local data = { userId = suspect.userId, alias = suspect.alias, result = result }
	local verdict = CosmeticsService.style(ace.player, "verdict")
	if verdict and result == "hand" then
		data.verdict = verdict
		Cues.fire("arrest", data, { hold = 4 })
	elseif verdict and typeof(ace.player) == "Instance" then
		local others = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= ace.player then
				table.insert(others, player)
			end
		end
		local mine = table.clone(data)
		mine.verdict = verdict
		local id = Cues.fire("arrest", mine, { hold = 4, to = { ace.player } })
		Cues.fire("arrest", data, { to = others, sameAs = id })
	else
		Cues.fire("arrest", data, { hold = 4 })
	end
end

-- Why this player cannot arrest right now (nil: they can).
function ArrestService.problem(ps): string?
	if not ps.alive or not ps.isAce then
		return "role"
	elseif Match.phase ~= "Meeting" and Match.phase ~= "Vote" then
		return "phase"
	elseif ps.arrestUsed then
		return "used"
	end
	return nil
end

-- Ace arrests `suspect` (checked by the caller). Returns false if nothing happened.
function ArrestService.arrest(ace, suspect, force: boolean?): boolean
	if not force and ArrestService.problem(ace) then
		return false
	end
	if not suspect or not suspect.alive or suspect == ace then
		return false
	end
	ace.arrestUsed = true
	Match.pushPrivate(ace)
	if ace.fakeAce then
		-- A Coven player wearing the title: nothing happens, and now everyone knows.
		EventLog.add(
			Terms.f("{alias} tried to arrest {suspect}, but held a fake {zero} title.", {
				alias = ace.alias,
				suspect = suspect.alias,
			}),
			"arrest"
		)
		Match.announce(
			Terms.f("A fake {zero}!"),
			Terms.f("{alias} tried to arrest {suspect}, but the warrant was worthless.", {
				alias = ace.alias,
				suspect = suspect.alias,
			}),
			"danger"
		)
		return true
	end
	local result = if suspect.role == "Kira" then "hand" elseif suspect.role == "Follower" then "cultist" else "innocent"
	playArrest(ace, suspect, result)
	if result == "innocent" then
		EventLog.add(
			Terms.f("{Zero} ({alias}) arrested {suspect}, who was innocent. {Zero} paid with their life.", {
				alias = ace.alias,
				suspect = suspect.alias,
			}),
			"arrest"
		)
		Match.announce(
			Terms.f("{alias} was {zero}", { alias = ace.alias }),
			Terms.f("{suspect} was innocent. The false arrest cost {zero} their life.", { suspect = suspect.alias }),
			"kira"
		)
		Elimination.eliminate(
			ace,
			"dead",
			"False arrest",
			Terms.f("{alias} ({zero}) died after arresting an innocent player.", { alias = ace.alias }),
			{}
		)
		return true
	end
	if result == "hand" then
		ace.stats.arrestedKira = true
	end
	EventLog.add(
		Terms.f("{Zero} ({alias}) arrested {suspect}, who was {role}.", {
			alias = ace.alias,
			suspect = suspect.alias,
			role = Terms.role(suspect.role, "a"),
		}),
		"arrest"
	)
	Match.announce(
		Terms.f("{alias} was {zero}: {suspect} arrested", { alias = ace.alias, suspect = suspect.alias }),
		if result == "hand"
			then Terms.f("{suspect} was {HAND}!", { suspect = suspect.alias })
			else Terms.f("{suspect} was a {cultist}. {Hand} is still free.", { suspect = suspect.alias }),
		"team"
	)
	Elimination.eliminate(
		suspect,
		"arrested",
		nil,
		Terms.f("{suspect} was arrested by {zero}.", { suspect = suspect.alias }),
		{}
	)
	return true
end

local function onArrest(player: Player, suspectUserId)
	if type(suspectUserId) ~= "number" then
		return
	end
	local ace = Match.getLiving(player)
	if not ace then
		return
	end
	local problem = ArrestService.problem(ace)
	if problem == "phase" then
		Match.notify(player, "You can only arrest during a meeting.", "bad")
		return
	elseif problem == "used" then
		Match.notify(player, "You have already used your arrest.", "bad")
		return
	elseif problem then
		return
	end
	ArrestService.arrest(ace, Match.getByUserId(suspectUserId))
end

-- Succession ---------------------------------------------------------------------------------

local function candidates(butler): { { userId: number, alias: string } }
	local list = {}
	for _, ps in ipairs(Match.living()) do
		if ps ~= butler then
			table.insert(list, { userId = ps.userId, alias = ps.alias })
		end
	end
	return list
end

local function closePick()
	if pick and pick.butler.player.Parent == Players then
		ButlerPickRemote:FireClient(pick.butler.player, { open = false })
	end
	pick = nil
end

-- Makes `chosen` the new Ace, named by the Butler.
function ArrestService.appoint(butler, chosen)
	Match.successionUsed = true
	chosen.isAce = true
	chosen.arrestUsed = false
	if Match.isKiraSide(chosen) then
		chosen.fakeAce = true
		Match.notify(
			chosen.player,
			Terms.f("{Butler} named you the new {zero}. You are not: your arrest will not work. Bluff, or keep quiet."),
			"secret"
		)
	else
		-- The title makes them Ace for good (their old role shows at the reveal as Ace).
		chosen.role = "L"
		Match.notify(
			chosen.player,
			Terms.f("{Butler} named you the new {zero}. You have one arrest: use it during a meeting."),
			"good"
		)
	end
	EventLog.add(
		Terms.f("{Butler} ({butler}) named {alias} the next {zero}{fake}.", {
			butler = butler.alias,
			alias = chosen.alias,
			fake = if chosen.fakeAce then Terms.f(" (a {cultist} or {hand}: a fake title)") else "",
		}),
		"succession"
	)
	Match.announce(Terms.f("A new {zero}"), Terms.f("{Butler} has named someone to carry on."), "team")
	Match.pushAllPrivate()
end

local function onPick(player: Player, chosenUserId)
	local current = pick
	if not current or type(chosenUserId) ~= "number" then
		return
	end
	if current.butler.player ~= player or not current.butler.alive or current.matchId ~= Match.id then
		return
	end
	local chosen = Match.getByUserId(chosenUserId)
	if not chosen or not chosen.alive or chosen == current.butler then
		return
	end
	closePick()
	ArrestService.appoint(current.butler, chosen)
end

-- Ace has died: the Butler (if alive, and the pick unused) chooses the next one.
local function startSuccession()
	if Match.successionUsed or Match.winner then
		return
	end
	local butler = Match.findRole("Watari")
	if not butler or not butler.alive then
		EventLog.add(Terms.f("{Zero} died and nobody was left to name the next one."), "succession")
		return
	end
	local endsAt = now() + Config.BUTLER_PICK_TIME
	local matchId = Match.id
	pick = { butler = butler, endsAt = endsAt, matchId = matchId }
	ButlerPickRemote:FireClient(butler.player, {
		open = true,
		endsAt = endsAt,
		candidates = candidates(butler),
	})
	Match.notify(
		butler.player,
		Terms.f("{Zero} is dead. Name the next {zero} within {n} seconds.", { n = Config.BUTLER_PICK_TIME }),
		"secret"
	)
	task.delay(Config.BUTLER_PICK_TIME, function()
		if pick and pick.matchId == matchId and pick.endsAt == endsAt then
			closePick()
			Match.successionUsed = true
			EventLog.add(Terms.f("{Butler} named nobody. {Agency} has no {zero} now."), "succession")
		end
	end)
end

-- Bots and the debug panel: the Butler's pick, made now.
function ArrestService.botPick(butler)
	if not pick or pick.butler ~= butler then
		return
	end
	local list = candidates(butler)
	local choice = list[Match.rng:NextInteger(1, math.max(1, #list))]
	if choice then
		local chosen = Match.getByUserId(choice.userId)
		closePick()
		if chosen then
			ArrestService.appoint(butler, chosen)
		end
	end
end

-- Debug panel: serves a real arrest on this player now, as Ace would (any phase).
function ArrestService.debugServe(suspect)
	local ace = Match.ace()
	if not ace or ace == suspect then
		ace = { alias = "Ace", stats = {}, player = suspect.player, isAce = true, fakeAce = false }
	end
	ArrestService.arrest(ace, suspect, true)
end

function ArrestService.pending()
	return pick
end

function ArrestService.onMatchEnd()
	closePick()
end

function ArrestService.init()
	ArrestRemote.OnServerEvent:Connect(onArrest)
	ButlerPickRemote.OnServerEvent:Connect(onPick)
	Match.Eliminated:Connect(function(ps)
		if pick and pick.butler == ps then
			closePick()
			Match.successionUsed = true
		end
		if ps.isAce and not ps.fakeAce then
			-- The pick waits until the death's own announcements are out.
			task.defer(startSuccession)
		end
		if pick and pick.butler.alive then
			-- Someone on the list is gone: send the Butler a fresh one.
			ButlerPickRemote:FireClient(pick.butler.player, {
				open = true,
				endsAt = pick.endsAt,
				candidates = candidates(pick.butler),
			})
		end
	end)
end

return ArrestService
