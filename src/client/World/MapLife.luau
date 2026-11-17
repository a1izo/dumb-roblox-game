--!strict
-- Things that move in the finished rooms (the owner's graphics plan, 2026-11-13, phase 13: "a room where nothing moves
-- reads as a model, however well it is lit"). One pattern, shared: a map comes in, the map is sorted out once (what
-- props, signs and lamps it has), and each kind of motion in World/Life takes what it can animate and stands it up.
-- Every kind is stepped about 30 times a second while its map is the one the camera is in, and taken down (its parts
-- gone, what it moved put back) the moment the map goes, the player switches to Low graphics, or the camera leaves for
-- the lobby.
--
-- Rules every kind keeps:
--   * Off in Low quality mode (Motion.isLow). Under Reduce motion nothing shakes, flashes or spins (env.reduced).
--   * Built from the map's own parts, its own lights and plain parts: no new mesh, no new light, no new sound id.
--   * Anything solid it adds is CanCollide, CanQuery and CanTouch false: a walk, a hiding place, a sight line are never
--     changed.
--   * Cheap: nothing searches the tree while stepping; only what is near the camera is moved; particles go through
--     Vfx/Emit.share().
--
-- To add a kind: a module in World/Life returning a Kind (Life/Util), and one line in KINDS below.

local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Blackout = require(script.Parent.Blackout)
local Governor = require(script.Parent.Governor)
local LightingController = require(script.Parent.LightingController)
local Util = require(script.Parent.Life.Util)

local MapLife = {}

local Life = script.Parent.Life
local KINDS: { Util.Kind } = {
	require(Life.Fans),
	require(Life.Glows),
	require(Life.Neon),
	require(Life.Tubes),
	require(Life.Sway),
	require(Life.Steam),
}

local STEP = 1 / 30
local SETTLE = 1.5 -- seconds a map must have been there before it is sorted out (it arrives in pieces)

type Running = { kind: Util.Kind, built: Util.Built }

local running: { Running } = {}
local builtFor: Instance? = nil
local seen: Instance? = nil
local seenAt = 0
local accumulated = 0

local function clear()
	for _, item in ipairs(running) do
		local ok, err = pcall(item.built.destroy)
		if not ok then
			Util.complain(item.kind.name .. " (taking down)", err)
		end
	end
	table.clear(running)
	builtFor = nil
end

local function build(map: Instance)
	builtFor = map
	local mapId = map:GetAttribute("MapId")
	if type(mapId) ~= "string" then
		return
	end
	local index = Util.index(map)
	for _, kind in ipairs(KINDS) do
		if table.find(kind.maps, mapId) then
			local ok, built = pcall(kind.build, index, mapId)
			if not ok then
				Util.complain(kind.name, built)
			elseif built then
				table.insert(running, { kind = kind, built = built :: Util.Built })
			end
		end
	end
end

local function step(dt: number)
	accumulated += dt
	if accumulated < STEP then
		return
	end
	local span = accumulated
	accumulated = 0
	local now = os.clock()
	local map = workspace:FindFirstChild("LGameMap")
	local wanted = not Motion.isLow() and map ~= nil and LightingController.venue() == "map"
	if not wanted or map ~= seen then
		if #running > 0 or builtFor ~= nil then
			clear()
		end
		seen = if wanted then map else nil
		seenAt = now
		return
	end
	if map ~= builtFor then
		if now - seenAt < SETTLE then
			return
		end
		build(map :: Instance)
	end
	if #running == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	local reduced = Motion.isReduced()
	local env: Util.Env = {
		now = now,
		dt = span,
		eye = if camera then camera.CFrame.Position else Vector3.zero,
		reduced = reduced,
		flashes = not reduced and not Motion.flashesOff(),
		particles = not Governor.low("particles"),
		share = Util.share(),
		blackout = Blackout.isActive(),
	}
	for index = #running, 1, -1 do
		local item = running[index]
		local ok, err = pcall(item.built.step, env)
		if not ok then
			Util.complain(item.kind.name, err)
			pcall(item.built.destroy)
			table.remove(running, index)
		end
	end
end

function MapLife.init()
	RunService.Heartbeat:Connect(step)
end

return MapLife
