-- The Specter's Eyes deal (internally "eyes"). From round 2 one Cultist (Follower) per match
-- may trade their life for the eyes: up close and in plain sight, a target's full real name shows above their head
-- for 3 seconds, on the follower's screen only. The follower's eyes glow red while
-- reading, and the follower dies publicly at the end of the second round after the deal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CharacterService = require(script.Parent.CharacterService)
local Cues = require(script.Parent.Cues)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)

local EyesRequest = Net.event("EyesRequest")
local EyesNameRemote = Net.event("EyesName")

local EyesService = {}

local function deal(ps, force: boolean?)
	if not force and (ps.role ~= "Follower" or Match.phase ~= "Investigation") then
		return
	end
	if not force and Match.round < Config.EYES_UNLOCK_ROUND then
		Match.notify(ps.player, "The deal unlocks in round " .. Config.EYES_UNLOCK_ROUND .. ".", "bad")
		return
	end
	if not force and (Match.eyesDealMade or ps.eyes) then
		Match.notify(ps.player, "The deal has already been made this match.", "bad")
		return
	end
	Match.eyesDealMade = true
	local reads = if Match.initialCount < Config.EYES_SMALL_SERVER_BELOW
		then Config.EYES_READS_SMALL_SERVER
		else Config.EYES_READS
	ps.eyes = {
		readsLeft = reads,
		countdown = Config.EYES_COUNTDOWN,
		dealRound = Match.round,
		read = {},
		lastRead = 0,
	}
	local deathRound = Match.round + Config.EYES_COUNTDOWN - 1
	Match.notify(
		ps.player,
		string.format(
			"The deal is made. Get close to a player and press R to see their real name (%d reads). You die at the end of round %d.",
			reads,
			deathRound
		),
		"secret"
	)
	Cues.fire("eyesDeal", { reads = reads, deathRound = deathRound }, { to = { ps.player }, lead = 0.1 })
	for _, other in ipairs(Match.list) do
		if other ~= ps and Match.isKiraSide(other) and other.alive then
			Match.notify(other.player, Terms.f("{alias} accepted {eyes}.", { alias = ps.alias }), "secret")
		end
	end
	EventLog.add(Terms.f("{alias} ({cultist}) accepted {eyes}.", { alias = ps.alias }), "eyes")
	Match.pushAllPrivate()
end

local function read(ps, targetUserId)
	local eyes = ps.eyes
	if not eyes or Match.phase ~= "Investigation" or type(targetUserId) ~= "number" then
		return
	end
	if eyes.readsLeft <= 0 then
		Match.notify(ps.player, "Your eyes have no reads left.", "bad")
		return
	end
	if os.clock() - eyes.lastRead < Config.EYES_COOLDOWN then
		return
	end
	local target = Match.getByUserId(targetUserId)
	if not target or not target.alive or target == ps then
		return
	end
	if eyes.read[target.userId] then
		Match.notify(ps.player, "You already know that name.", "bad")
		return
	end
	local targetHead = Match.eyePosition(target)
	if not targetHead or not Match.canSee(ps, targetHead, Config.EYES_RANGE, nil) then
		Match.notify(ps.player, "Too far away, or something is in the way.", "bad")
		return
	end

	eyes.lastRead = os.clock()
	-- The visible tell happens whether or not the read works.
	CharacterService.glowEyes(ps.player, Config.EYES_DURATION)

	if Match.hasHood(target) then
		Match.notify(ps.player, "A hood hides this person's name.", "bad")
		return
	end
	-- L cannot be read in the round of the deal. Other names may also blur in that round,
	-- so a blurred read never proves who L is.
	if Match.round == eyes.dealRound then
		if target.role == "L" or Match.rng:NextNumber() < Config.EYES_DEAL_ROUND_BLUR_CHANCE then
			Match.notify(ps.player, "The name flickers and will not settle. Try again in a later round.", "bad")
			return
		end
	end

	eyes.readsLeft -= 1
	eyes.read[target.userId] = true
	ps.stats.reads += 1
	EyesNameRemote:FireClient(ps.player, {
		userId = target.userId,
		name = target.realName,
		duration = Config.EYES_DURATION,
	})
	EventLog.add(
		Terms.f(
			"{alias} ({cultist}) read {target}'s real name with {eyes}.",
			{ alias = ps.alias, target = target.alias }
		),
		"eyes"
	)
	Match.pushPrivate(ps)
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps then
		return
	end
	if payload.action == "deal" then
		deal(ps)
	elseif payload.action == "read" then
		read(ps, payload.userId)
	end
end

-- Countdowns tick at the end of every round, starting with the round of the deal.
-- Debug panel: gives a player the Specter's Eyes now (any role, any round), with the usual
-- countdown and cutscene.
function EyesService.debugGrant(ps)
	ps.eyes = nil
	deal(ps, true)
end

function EyesService.onRoundEnd()
	for _, ps in ipairs(Match.list) do
		if ps.eyes and ps.alive then
			ps.eyes.countdown -= 1
			if ps.eyes.countdown <= 0 then
				EventLog.add(Terms.f("{alias} died after a deal with {eyes}.", { alias = ps.alias }), "death")
				Elimination.eliminate(
					ps,
					"dead",
					Terms.f("{Eyes} deal"),
					Terms.f(
						"{alias} collapsed. The deal with {eyes} claimed them: they were working with {hand}.",
						{ alias = ps.alias }
					),
					{}
				)
				Match.announce(
					ps.alias .. " is dead",
					Terms.f("Cause of death: the deal with {eyes}. They worked with {hand}."),
					"danger"
				)
				Cues.fire(
					"death",
					{ userId = ps.userId, alias = ps.alias, cause = Terms.f("{Eyes} deal") },
					{ hold = 5.5 }
				)
			else
				Match.pushPrivate(ps)
			end
		end
	end
end

function EyesService.init()
	EyesRequest.OnServerEvent:Connect(onRequest)
end

return EyesService
