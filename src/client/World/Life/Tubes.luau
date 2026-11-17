--!strict
-- A tired fitting (graphics plan, phase 13): one of the map's own ceiling lamps, named below by where it hangs,
-- stutters now and then on a fixed beat. Only that lamp's brightness is touched, and only while it stutters: it is
-- never given a new light, a new range or a shadow, and it goes back to what the lighting wants (a mood may have
-- dimmed it) the moment the stutter is over. Nothing in a blackout, with flashes off, or under Reduce motion.
--
-- The Bureau's archive tube also has a place for a buzz: when a sound named mapTubeBuzz is in Assets.sfx it loops from
-- the fitting, softly. There is none yet (silent until the owner picks one).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local LightingController = require(script.Parent.Parent.LightingController)
local Util = require(script.Parent.Util)
local LifePatterns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LifePatterns"))

local Tubes = {}

type Target = { name: string, at: { number }, reach: number, period: number, buzz: boolean }

local TARGETS: { [string]: { Target } } = {
	-- the science hall, a lamp over its middle; the archive's tubes
	UniversityCampus = {
		{ name = "science hall", at = { 58.7, 11.5, 70 }, reach = 12, period = 13.7, buzz = false },
	},
	TaskForceHQ = {
		{ name = "archive", at = { 65, 25, -61 }, reach = 14, period = 17.3, buzz = true },
	},
}

local NEAR = 90
local BUZZ_VOLUME = 0.16

type Item = {
	light: Light,
	anchor: BasePart,
	base: number,
	period: number,
	phase: number,
	stuttering: boolean,
	sound: Sound?,
}

local function resting(item: Item): number
	return LightingController.lampBrightness(item.light) or item.base
end

function Tubes.build(index: Util.Index, mapId: string): Util.Built?
	local targets = TARGETS[mapId]
	if not targets then
		return nil
	end
	local items: { Item } = {}
	for number, target in ipairs(targets) do
		local at = Util.world(target.at[1], target.at[2], target.at[3])
		local best: { anchor: BasePart, light: Light }? = nil
		local gap = target.reach
		for _, lamp in ipairs(index.lamps) do
			-- (a ceiling lamp that is on, not an emergency beacon that waits for a blackout)
			if lamp.light.Enabled and not lamp.anchor:HasTag("LMapEmergency") then
				local d = (lamp.anchor.Position - at).Magnitude
				if d < gap then
					gap = d
					best = lamp
				end
			end
		end
		if best then
			local item: Item = {
				light = best.light,
				anchor = best.anchor,
				base = best.light.Brightness,
				period = target.period,
				phase = number * 3.1,
				stuttering = false,
				sound = nil,
			}
			if target.buzz and (Assets.sfx :: any).mapTubeBuzz then
				local sound = Sfx.play("mapTubeBuzz", {
					group = "Ambience",
					parent = best.anchor,
					looped = true,
					volume = BUZZ_VOLUME,
				})
				if sound then
					sound.RollOffMinDistance = 5
					sound.RollOffMaxDistance = 32
					item.sound = sound
				end
			end
			table.insert(items, item)
		end
	end
	if #items == 0 then
		return nil
	end
	local function release(item: Item)
		if item.stuttering then
			item.stuttering = false
			if item.light.Parent then
				item.light.Brightness = resting(item)
			end
		end
	end
	return {
		step = function(env: Util.Env)
			for _, item in ipairs(items) do
				local into = (env.now + item.phase) % item.period
				local active = env.flashes
					and not env.blackout
					and into < LifePatterns.TUBE_LENGTH
					and (item.anchor.Position - env.eye).Magnitude < NEAR
				if active then
					item.stuttering = true
					item.light.Brightness = resting(item) * LifePatterns.tube(env.now, item.period, item.phase)
				else
					release(item)
				end
			end
		end,
		destroy = function()
			for _, item in ipairs(items) do
				release(item)
				if item.sound then
					item.sound:Destroy()
				end
			end
		end,
	}
end

local kind: Util.Kind = { name = "tubes", maps = { "UniversityCampus", "TaskForceHQ" }, build = Tubes.build }
return kind
