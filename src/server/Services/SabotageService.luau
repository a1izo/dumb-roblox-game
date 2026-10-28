-- The Muerto's sabotage, in free roam only: the blackout (the lights, nothing else, the owner's call of
-- 2026-10-28). The whole map goes dark for BLACKOUT_TIME seconds and name tags hide: cover for a hack or
-- a writing. One use every SABOTAGE_COOLDOWN seconds per Muerto. Diavolo cannot sabotage; nothing
-- works during a meeting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local SabotageRemote = Net.event("Sabotage")

local SabotageService = {}

SabotageService.KINDS = { "blackout" }

local blackoutToken = 0
local blackoutOn = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function hideNames(hidden: boolean)
	for _, ps in ipairs(Match.list) do
		local character = ps.player.Character
		if character then
			CharacterService.setNameHidden(character, "blackout", hidden and ps.alive == true)
		end
	end
end

local function endBlackout()
	blackoutToken += 1
	if not blackoutOn then
		return
	end
	blackoutOn = false
	hideNames(false)
	local map = Match.map
	if map and map.model and map.model.Parent then
		map.model:SetAttribute("BlackoutUntil", nil)
	end
end

local function blackout(ps): boolean
	local map = Match.map
	if not map or not map.model then
		return false
	end
	blackoutToken += 1
	local mine = blackoutToken
	local matchId = Match.id
	blackoutOn = true
	map.model:SetAttribute("BlackoutUntil", now() + Config.BLACKOUT_TIME)
	hideNames(true)
	EventLog.add(Terms.f("{alias} ({cultist}) blacked out the map.", { alias = ps.alias }), "sabotage")
	task.delay(Config.BLACKOUT_TIME, function()
		if blackoutToken == mine and Match.id == matchId then
			endBlackout()
		end
	end)
	return true
end

local RUN: { [string]: (any) -> boolean } = {
	blackout = blackout,
}

-- Why this player cannot sabotage right now (nil: they can).
function SabotageService.problem(ps): string?
	if not ps.alive or ps.role ~= "Follower" then
		return "role"
	elseif Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return "phase"
	elseif ps.ritual then
		return "busy"
	elseif now() < ps.sabotageReadyAt then
		return "cooldown"
	end
	return nil
end

function SabotageService.run(ps, kind: string, force: boolean?): boolean
	local run = RUN[kind]
	if not run then
		return false
	end
	if not force then
		local problem = SabotageService.problem(ps)
		if problem == "cooldown" then
			Match.notify(ps.player, "Sabotage not ready.", "bad")
			return false
		elseif problem then
			return false
		end
	end
	if not run(ps) then
		return false
	end
	ps.sabotageReadyAt = now() + Config.SABOTAGE_COOLDOWN
	Match.pushPrivate(ps)
	return true
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or not RateLimit.allow(player, "sabotage", 0.5) then
		return
	end
	SabotageService.run(ps, payload.kind)
end

-- Free roam is over (a meeting or the end): the lights come back.
function SabotageService.clear()
	endBlackout()
end

function SabotageService.init()
	SabotageRemote.OnServerEvent:Connect(onRequest)
end

return SabotageService
