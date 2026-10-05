--!strict
-- The Grey Realm's soundscape, quiet enough that you sometimes wonder whether you heard something:
--   * three beds that never stop (a low distant wind, a very quiet drone, a faint rumble far below),
--     their volumes swelling and ebbing on slow waves that never line up;
--   * one-shots that come now and then from a long way off, at a random side and distance, heard
--     through a little reverb (a stone knock, a creak of metal, a breath of whisper);
--   * the lobby's music ducked under all of it.
-- Wind through the rocks at the vistas is a scene sound marker instead (World/MapAmbient), so it
-- gets louder as you walk up to the rock.
-- Every slot is empty until its sound is uploaded (art/audio, Assets.sfx realm*): then nothing
-- plays and nothing breaks. Only while the camera is in the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local LightingController = require(script.Parent.Parent.World.LightingController)
local Mixer = require(script.Parent.Mixer)
local Sfx = require(script.Parent.Sfx)

local RealmAmbience = {}

local TUNING = {
	-- key, swing (how far the volume wanders, as a fraction), period (seconds of its slow wave), pitch swing.
	beds = {
		{ key = "realmWind", swing = 0.4, period = 41, pitch = 0.03 },
		{ key = "realmDrone", swing = 0.5, period = 59, pitch = 0.0 },
		{ key = "realmRumble", swing = 0.6, period = 73, pitch = 0.0 },
	},
	oneShots = { "realmStone1", "realmStone2", "realmMetal1", "realmMetal2", "realmFar1", "realmFar2" },
	gap = { 25, 70 }, -- seconds between one-shots
	distance = { 80, 220 }, -- studs from the listener
	volume = { 0.35, 0.8 }, -- times the slot's own volume
	-- How often the beds' volumes are nudged (seconds).
	step = 0.25,
}

type Bed = {
	sound: Sound,
	base: number,
	spec: { key: string, swing: number, period: number, pitch: number },
	phase: number,
}

local beds: { Bed } = {}
local active = false
local rng = Random.new()
local startedAt = os.clock()
local generation = 0

local function entryVolume(key: string): number
	local entry = Assets.sfx[key]
	return if entry and entry.volume then entry.volume else 1
end

local function enter()
	if active then
		return
	end
	active = true
	generation += 1
	Mixer.duck("realm", true)
	for index, spec in ipairs(TUNING.beds) do
		local sound = Sfx.play(spec.key, { group = "Ambience", looped = true, volume = 1 })
		if sound then
			table.insert(beds, { sound = sound, base = entryVolume(spec.key), spec = spec, phase = index * 2.3 })
		end
	end
end

local function leave()
	if not active then
		return
	end
	active = false
	generation += 1
	Mixer.duck("realm", false)
	for _, bed in ipairs(beds) do
		bed.sound:Destroy()
	end
	table.clear(beds)
end

local function nudge()
	local t = os.clock() - startedAt
	for _, bed in ipairs(beds) do
		local wave = math.sin(2 * math.pi * t / bed.spec.period + bed.phase) * 0.6
			+ math.sin(2 * math.pi * t / (bed.spec.period * 0.37) + bed.phase * 1.7) * 0.4
		bed.sound.Volume = bed.base * math.max(0, 1 + bed.spec.swing * wave)
		if bed.spec.pitch > 0 then
			bed.sound.PlaybackSpeed = 1 + bed.spec.pitch * wave
		end
	end
end

-- One sound from far away, on a random side.
local function oneShot()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local key = TUNING.oneShots[rng:NextInteger(1, #TUNING.oneShots)]
	local angle = rng:NextNumber(0, 2 * math.pi)
	local distance = rng:NextNumber(TUNING.distance[1], TUNING.distance[2])
	local at = camera.CFrame.Position
		+ Vector3.new(math.cos(angle) * distance, rng:NextNumber(-10, 20), math.sin(angle) * distance)
	local anchor = Create("Part", {
		Name = "RealmSound",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		Position = at,
		Parent = workspace,
	})
	local sound = Sfx.play(key, {
		group = "Ambience",
		volume = rng:NextNumber(TUNING.volume[1], TUNING.volume[2]),
		parent = anchor,
	})
	if sound then
		sound.RollOffMinDistance = 30
		sound.RollOffMaxDistance = 320
		Create(
			"ReverbSoundEffect",
			{ DecayTime = 3.5, Density = 0.8, Diffusion = 0.9, DryLevel = -6, WetLevel = -2, Parent = sound }
		)
	end
	task.delay(14, function()
		anchor:Destroy()
	end)
end

function RealmAmbience.init()
	LightingController.Changed:Connect(function(venue, preset)
		if venue == "lobby" and preset.realmSky then
			enter()
		else
			leave()
		end
	end)
	if LightingController.venue() == "lobby" and LightingController.preset().realmSky then
		enter()
	end
	task.spawn(function()
		while true do
			task.wait(TUNING.step)
			if active then
				nudge()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(TUNING.gap[1], TUNING.gap[2]))
			if active then
				oneShot()
			end
		end
	end)
end

return RealmAmbience
