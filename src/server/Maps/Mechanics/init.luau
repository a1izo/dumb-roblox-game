-- Each map's own mechanic, kept in one place so nothing else checks map ids:
--   TokyoDistrict    : the scramble's lights, its cars and the crowd that crosses with them
--   UniversityCampus : tracks in the snow, seen by everyone
--   TaskForceHQ      : the breaker panel that blacks out both floors
-- A mechanic is a module returning { start, stop, onPhase?, onPhaseEnd?, stageMarks?, action?,
-- debug? }. Every hook runs protected: a bug in a map's mechanic warns, it never ends a match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Services = script.Parent.Parent:WaitForChild("Services")
local Match = require(Services:WaitForChild("Match"))
local RateLimit = require(Services:WaitForChild("RateLimit"))

export type Context = {
	map: any, -- MapService's info for the built map (model, layout, origin, builder, zones...)
	rng: Random,
	matchId: number,
}

export type Mechanic = {
	start: (Context) -> (),
	stop: () -> (),
	onPhase: ((string) -> ())?,
	onPhaseEnd: ((string) -> ())?,
	stageMarks: (({ any }) -> ())?, -- the intro's cast (each with .cf): marks the map keeps clear
	action: ((any, { [string]: any }) -> ())?, -- a living player's MapAction request
	debug: ((string, any) -> string?)?,
}

local Mechanics = {}

local current: Mechanic? = nil
local currentId: string? = nil

local function call(name: string, ...: any)
	local mechanic = current :: any
	local fn = mechanic and mechanic[name]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(
			string.format("[DeathsGambit] %s's mechanic failed in %s: %s", tostring(currentId), name, tostring(result))
		)
		return nil
	end
	return result
end

local function moduleFor(mapId: string): Mechanic?
	local child = script:FindFirstChild(mapId)
	if not child or not child:IsA("ModuleScript") then
		return nil
	end
	local ok, mechanic = pcall(require, child)
	if not ok then
		warn("[DeathsGambit] " .. mapId .. "'s mechanic did not load: " .. tostring(mechanic))
		return nil
	end
	return mechanic :: Mechanic
end

function Mechanics.start(map)
	Mechanics.stop()
	if not map or type(map.id) ~= "string" then
		return
	end
	current = moduleFor(map.id)
	currentId = map.id
	call("start", { map = map, rng = Match.rng, matchId = Match.id } :: Context)
end

-- Runs a mechanic given as a table, as if it were map `id`'s (the specs use it).
function Mechanics.adopt(id: string, mechanic: Mechanic, context: Context?)
	Mechanics.stop()
	current = mechanic
	currentId = id
	call("start", context or { map = { id = id }, rng = Match.rng, matchId = Match.id } :: Context)
end

function Mechanics.stop()
	if current then
		call("stop")
	end
	current = nil
	currentId = nil
	-- Whatever the mechanic changed about sight goes back to normal.
	Match.occluder = nil
	Match.sightScale = { flash = 1, witness = 1, eyes = 1 }
end

function Mechanics.onPhase(phase: string)
	call("onPhase", phase)
end

function Mechanics.onPhaseEnd(phase: string)
	call("onPhaseEnd", phase)
end

function Mechanics.stageMarks(cast: { any }?)
	if type(cast) == "table" then
		call("stageMarks", cast)
	end
end

-- The debug panel: passes a command to the running map's mechanic.
function Mechanics.debug(command: string, args: any): string?
	return call("debug", command, args)
end

function Mechanics.currentId(): string?
	return currentId
end

function Mechanics.init()
	Net.event("MapAction").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or type(payload.action) ~= "string" then
			return
		end
		if not RateLimit.allow(player, "mapAction", 0.5) then
			return
		end
		local ps = Match.getLiving(player)
		if not ps or ps.away == true then
			return
		end
		call("action", ps, payload)
	end)
end

return Mechanics
