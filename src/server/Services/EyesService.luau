-- The Oculus of the Dead (internally "eyes"), a Muerto's only (never Diavolo's). The usual way to
-- learn a real name is hacking a station (HackService); a Muerto may instead take the deal at any
-- time in free roam: a OCULUS_RITUAL-second ritual in plain sight, eyes blazing. After it they can
-- stare: stand still, face someone within OCULUS_RANGE and hold it OCULUS_READ_TIME seconds, eyes
-- glowing, to learn their real name (the Manual lists it, and a note carries it to Diavolo). The
-- Muerto dies publicly after OCULUS_LIFESPAN seconds of free roam (the clock stops in meetings).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- Faster than this (studs per second, on the ground) and a stare breaks: staring means standing still.
local STILL_SPEED = 2.5

-- [playerState] = the stare in progress.
local stares: { [any]: { target: any, startedAt: number, needed: number } } = {}
local ticker: RBXScriptConnection? = nil
local accumulated = 0

local function canStare(ps): boolean
	return ps.alive and ps.eyes ~= nil and Match.phase == "Investigation" and Match.meetingCall == nil
end

local function stareRange(_ps): number
	return Match.sightRange("eyes")
end

local function moving(ps): boolean
	local root = Match.rootPart(ps)
	if not root then
		return true
	end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude > STILL_SPEED
end

-- Can the starer still see the target from here?
local function inSight(ps, target): boolean
	local head = Match.eyePosition(target)
	return head ~= nil and Match.canSee(ps, head, stareRange(ps), nil)
end

-- Is the starer's body turned toward the target (within FACING of straight at them)? A stare at someone behind your
-- back was an exploit's (2026-10-27); the client turns the body to face whoever it stares at.
local FACING = math.cos(math.rad(75))
local TURN_GRACE = 0.6 -- seconds for the client's turn to reach the server

local function facing(ps, target): boolean
	local root = Match.rootPart(ps)
	local head = Match.eyePosition(target)
	if not root or not head then
		return false
	end
	local to = head - root.Position
	to = Vector3.new(to.X, 0, to.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if to.Magnitude < 1 or look.Magnitude < 1e-3 then
		return true
	end
	return look.Unit:Dot(to.Unit) >= FACING
end

local function stopStare(ps, reason: string?)
	if not stares[ps] then
		return
	end
	stares[ps] = nil
	CharacterService.glowEyes(ps.player, 0)
	if reason then
		EyesNameRemote:FireClient(ps.player, { failed = reason })
	end
end

local function learn(ps, target)
	ps.learned[target.userId] = true
	ps.stats.reads += 1
	EyesNameRemote:FireClient(ps.player, {
		userId = target.userId,
		name = target.realName,
		duration = Config.EYES_DURATION,
	})
	EventLog.add(
		string.format(
			"%s (%s) learned %s's real name%s.",
			ps.alias,
			Terms.role(ps.role),
			target.alias,
			if ps.eyes then Terms.f(" with {eyes}") else " by staring"
		),
		"eyes"
	)
	Match.pushPrivate(ps)
end

local function startStare(ps, targetUserId)
	if not canStare(ps) or type(targetUserId) ~= "number" or ps.writing or ps.ritual or ps.hacking then
		return
	end
	local target = Match.getByUserId(targetUserId)
	if not target or not target.alive or target == ps then
		return
	end
	if ps.learned[target.userId] then
		Match.notify(ps.player, "You already know that name.", "bad")
		return
	end
	if not inSight(ps, target) then
		Match.notify(ps.player, "Too far away, or something is in the way.", "bad")
		return
	end
	local needed = Config.OCULUS_READ_TIME
	stares[ps] = { target = target, startedAt = os.clock(), needed = needed }
	-- The tell: red eyes for as long as the stare lasts (a read with the Oculus flares brighter and
	-- shorter, but just as visible).
	CharacterService.glowEyes(ps.player, needed + 0.3)
end

local function dieOfDeal(ps)
	ps.eyes = nil
	EventLog.add(Terms.f("{alias} died after a deal with {eyes}.", { alias = ps.alias }), "death")
	Match.requestMeeting("death", ps)
	Cues.fire("death", { userId = ps.userId, alias = ps.alias, cause = Terms.f("{Eyes} deal") }, { hold = 5.5 })
	Elimination.eliminate(
		ps,
		"dead",
		Terms.f("{Eyes} deal"),
		Terms.f("{alias} collapsed. The deal with {eyes} claimed them: they were working with {hand}.", {
			alias = ps.alias,
		}),
		{}
	)
	Match.announce(
		ps.alias .. " is dead",
		Terms.f("Cause of death: the deal with {eyes}. They worked with {hand}."),
		"danger"
	)
end

local function deal(ps, force: boolean?)
	if not force then
		-- (its own checks: canStare needs the Oculus, which this is how you get)
		local roaming = Match.phase == "Investigation" and Match.meetingCall == nil
		if ps.role ~= "Follower" or not ps.alive or not roaming or ps.ritual or ps.writing or ps.hacking then
			return
		end
		if ps.eyes then
			Match.notify(ps.player, "You have already made the deal.", "bad")
			return
		end
	end
	stopStare(ps, nil)
	-- The ritual: rooted to the spot, eyes blazing, for everyone to see.
	ps.ritual = true
	CharacterService.setFrozen(ps.player, true)
	CharacterService.glowEyes(ps.player, Config.OCULUS_RITUAL + 0.5)
	local matchId = Match.id
	task.delay(if force then 0 else Config.OCULUS_RITUAL, function()
		ps.ritual = nil
		if Match.id ~= matchId or not ps.alive then
			return
		end
		if Match.phase == "Investigation" and Match.meetingCall == nil then
			CharacterService.setFrozen(ps.player, false)
		end
		ps.eyes = { lifeLeft = Config.OCULUS_LIFESPAN }
		local minutes = math.floor(Config.OCULUS_LIFESPAN / 60 + 0.5)
		Match.notify(
			ps.player,
			string.format(
				"The deal is made. Reading a name now takes %d s from up to %d studs. You die in %d minute(s) of investigation.",
				Config.OCULUS_READ_TIME,
				Config.OCULUS_RANGE,
				minutes
			),
			"secret"
		)
		Cues.fire("eyesDeal", { lifespan = Config.OCULUS_LIFESPAN }, { to = { ps.player }, lead = 0.1 })
		EventLog.add(Terms.f("{alias} ({cultist}) accepted {eyes}.", { alias = ps.alias }), "eyes")
		Match.pushPrivate(ps)
	end)
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
	elseif payload.action == "stare" then
		startStare(ps, payload.userId)
	elseif payload.action == "stop" then
		stopStare(ps, nil)
	end
end

local function tick(dt: number)
	if not Match.active then
		return
	end
	accumulated += dt
	if accumulated < 0.1 then
		return
	end
	local step = accumulated
	accumulated = 0
	for ps, stare in pairs(table.clone(stares)) do
		local turned = os.clock() - stare.startedAt > TURN_GRACE and not facing(ps, stare.target)
		if not canStare(ps) or not stare.target.alive or not inSight(ps, stare.target) or turned then
			stopStare(ps, "lost")
		elseif moving(ps) then
			stopStare(ps, "moved")
		elseif os.clock() - stare.startedAt >= stare.needed then
			stares[ps] = nil
			learn(ps, stare.target)
		end
	end
	-- The Oculus' clock only runs in free roam.
	if Match.phase ~= "Investigation" or Match.meetingCall ~= nil or Match.debugPaused then
		return
	end
	for _, ps in ipairs(Match.list) do
		local eyes = ps.eyes
		if eyes and ps.alive then
			local before = math.ceil(eyes.lifeLeft)
			eyes.lifeLeft -= step
			if eyes.lifeLeft <= 0 then
				dieOfDeal(ps)
			elseif math.ceil(eyes.lifeLeft) ~= before and math.ceil(eyes.lifeLeft) % 10 == 0 then
				Match.pushPrivate(ps)
			end
		end
	end
end

-- Free roam is over: every stare stops.
function EyesService.interrupt()
	for ps in pairs(table.clone(stares)) do
		stopStare(ps, nil)
	end
end

-- Debug panel: gives a player the Oculus now (any role), with its usual clock and cutscene.
function EyesService.debugGrant(ps)
	ps.eyes = nil
	deal(ps, true)
end

-- Debug panel: this player learns everyone's real name.
function EyesService.debugLearnAll(ps)
	for _, other in ipairs(Match.list) do
		if other ~= ps then
			ps.learned[other.userId] = true
		end
	end
	Match.pushPrivate(ps)
end

function EyesService.onMatchEnd()
	stares = {}
end

function EyesService.init()
	EyesRequest.OnServerEvent:Connect(onRequest)
	if ticker then
		ticker:Disconnect()
	end
	ticker = RunService.Heartbeat:Connect(tick)
	Match.Eliminated:Connect(function(ps)
		stares[ps] = nil
		for other, stare in pairs(table.clone(stares)) do
			if stare.target == ps then
				stopStare(other, "lost")
			end
		end
	end)
end

return EyesService
