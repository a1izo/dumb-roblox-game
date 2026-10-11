-- Bureau HQ's mechanic: the main breaker. Once per round, during the investigation, any living player
-- can pull the panel by the fire stair: both floors black out for BLACKOUT seconds (only the red
-- emergency lamps and the screens stay lit). While it lasts every name tag is hidden, a letter flash
-- reaches half as far and a faked task is only witnessed from close by; the Oculus still reads names
-- (those eyes see in the dark). The pull itself is on camera: the camera clue can name who did it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local Services = script.Parent.Parent.Parent:WaitForChild("Services")
local CharacterService = require(Services:WaitForChild("CharacterService"))
local EventLog = require(Services:WaitForChild("EventLog"))
local Match = require(Services:WaitForChild("Match"))

local TaskForceHQ = {}

TaskForceHQ.BLACKOUT = 15 -- seconds of dark
TaskForceHQ.SETTLE = 10 -- seconds into the investigation before the breaker can be pulled
TaskForceHQ.FLASH_SCALE = 0.5 -- 16 -> 8 studs
TaskForceHQ.WITNESS_SCALE = 0.4 -- 30 -> 12 studs

local map: any = nil
local panel: BasePart? = nil
local endsAt = 0
local token = 0

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

-- Lights back on (the blackout ran out, the investigation ended, or the match did).
local function restore()
	token += 1
	if endsAt == 0 then
		return
	end
	endsAt = 0
	Match.sightScale.flash = 1
	Match.sightScale.witness = 1
	hideNames(false)
	if map and map.model and map.model.Parent then
		map.model:SetAttribute("BlackoutUntil", nil)
	end
end

local function buildPanel(ctx)
	local anchor = ctx.map.layout and ctx.map.layout.anchors and ctx.map.layout.anchors.breaker
	local b = ctx.map.builder
	if not anchor or not b then
		warn("[DeathsGambit] Bureau HQ has no breaker anchor: no blackout this match.")
		return
	end
	local base = b:cf(anchor.x, anchor.y or 0, anchor.z, anchor.rot or 0)
	local part = b:part(
		Vector3.new(2.8, 6.6, 1.0),
		base * CFrame.new(0, 3.3, 0),
		Color3.fromRGB(120, 124, 130),
		Enum.Material.Metal,
		{ Name = "BreakerPanel", Parent = ctx.map.model }
	)
	ModelLibrary.dress(part, "BreakerPanel", CFrame.new(0, -3.3, 0))
	part:SetAttribute("Spent", false)
	part:AddTag("LBreaker")
	panel = part
end

function TaskForceHQ.start(ctx)
	map = ctx.map
	endsAt = 0
	buildPanel(ctx)
end

function TaskForceHQ.stop()
	restore()
	if panel then
		panel:Destroy()
	end
	panel = nil
	map = nil
end

function TaskForceHQ.onPhase(phase: string)
	if phase == "Investigation" and panel then
		panel:SetAttribute("Spent", false)
	end
end

function TaskForceHQ.onPhaseEnd(phase: string)
	if phase == "Investigation" then
		restore()
	end
end

-- Why a player cannot pull the breaker right now (nil: they can).
function TaskForceHQ.pullProblem(ps): string?
	if not panel then
		return "missing"
	elseif Match.phase ~= "Investigation" then
		return "phase"
	elseif panel:GetAttribute("Spent") == true then
		return "spent"
	elseif now() - Match.phaseStartedAt < TaskForceHQ.SETTLE then
		return "settling"
	end
	local at = Match.position(ps)
	if not at or (at - panel.Position).Magnitude > Config.INTERACT_RANGE + 2 then
		return "far"
	end
	return nil
end

function TaskForceHQ.action(ps, payload)
	if payload.action ~= "breaker" then
		return
	end
	local problem = TaskForceHQ.pullProblem(ps)
	if problem then
		if problem == "spent" then
			Match.notify(ps.player, "The breaker has already been pulled this round.", "bad")
		elseif problem == "settling" then
			Match.notify(ps.player, "The breaker is locked for a few more seconds.", "bad")
		end
		return
	end
	local part = panel :: BasePart
	part:SetAttribute("Spent", true)
	token += 1
	local mine = token
	local matchId = Match.id
	endsAt = now() + TaskForceHQ.BLACKOUT
	map.model:SetAttribute("BlackoutUntil", endsAt)
	Match.sightScale.flash = TaskForceHQ.FLASH_SCALE
	Match.sightScale.witness = TaskForceHQ.WITNESS_SCALE
	hideNames(true)
	EventLog.sighting(ps, "pulled the breaker", part.Position, { where = "at the breaker panel by the fire stair" })
	EventLog.add(string.format("%s pulled the breaker: both floors went dark.", ps.alias), "info")
	Match.notify(ps.player, "Lights out.", "secret")
	task.delay(TaskForceHQ.BLACKOUT, function()
		if token == mine and Match.id == matchId then
			restore()
		end
	end)
end

function TaskForceHQ.debug(command: string)
	if command == "blackout" and panel then
		panel:SetAttribute("Spent", false)
		local someone = Match.living()[1]
		if someone then
			Match.phaseStartedAt = math.min(Match.phaseStartedAt, now() - TaskForceHQ.SETTLE)
			TaskForceHQ.action(someone, { action = "breaker" })
			return "blackout started"
		end
	end
	return nil
end

return TaskForceHQ
