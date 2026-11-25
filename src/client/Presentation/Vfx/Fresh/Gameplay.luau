--!strict
-- Deaths and gameplay moments on the new kit (stage 4d of the VFX rework). Only the effect code of the death beats, the
-- voted-out dissolve, the handcuff sparks, a haunt's mist, the dive's crash and the Deathsinger's eyes sits here; the
-- callers (DeathFx, DeathVfx, HauntBar, DiveController, EyesDealFx, EyeGlow) keep their old code behind a flag each
-- (Vfx/Pilot), and call these when it is on. These are WORLD and gameplay effects, so they keep docs/vfx.md rule 1: grey,
-- bone and soft white, and red only where it means danger (the stare, the deal, a heart that fails). No gore.

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Light = require(script.Parent.Parent.Light)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)
local Impact = require(script.Parent.Impact)
local Small = require(script.Parent.Small)
local Smoke = require(script.Parent.Smoke)

local Gameplay = {}

local COLD: Palette.Ramp = { Color3.new(1, 1, 1), Color3.fromRGB(205, 215, 230), Color3.fromRGB(70, 80, 95) }
local WHITE = Color3.new(1, 1, 1)
-- the Deathsinger's red (danger red kept): a pink-hot core, the red, a deep red edge
local EYES: Palette.Ramp = { Color3.fromRGB(255, 170, 160), Color3.fromRGB(235, 40, 50), Color3.fromRGB(100, 8, 14) }

-- A ramp for a colour a death already has (its colour kept, white-hot at birth, the same hue deeper at its end).
local function rampOf(colour: Color3): Palette.Ramp
	return Palette.shop(colour)
end

-- One hard star with a dark halo behind it (two emitters, no light of its own): the eyes' glints.
local function star(at: Vector3, ramp: Palette.Ramp, size: number, life: number)
	Emit.burst(at, {
		{
			{
				tex = "VfxGlint",
				ramp = ramp,
				size = C.size("VfxGlint", size, { { 0, 0 }, { 0.3, size }, { 1, 0 } }),
				alpha = { { 0, 1 }, { 0.15, 0.08 }, { 0.6, 0.25 }, { 1, 1 } },
				life = life,
				rot = { -14, 14 },
				bright = 2.3,
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxMist",
				ramp = C.shadow(ramp),
				size = { { 0, size * 0.5 }, { 1, size * 0.7 } },
				alpha = { { 0, 1 }, { 0.25, 0.65 }, { 0.8, 0.75 }, { 1, 1 } },
				life = life,
				light = 0,
				z = -1,
			},
			1,
		},
	})
end

-- Voted out: the body comes apart into ash rising off it for `seconds` (the body itself is faded by Anim/ActingController):
-- flakes carried up and off, a few embers at the edge that catch the light, a thread of soot. Three emitters fed by hand, so
-- they hold with the kit's clock. Returns the cancel.
function Gameplay.dissolve(root: BasePart, seconds: number): () -> ()
	local ash = Palette.WORLD.ash
	local still = C.still()
	local loop = Small.loop(root, {
		{
			tex = "VfxAshFlakes",
			ramp = ash,
			size = { { 0, 0.36, 0.1 }, { 0.7, 0.28, 0.08 }, { 1, 0.1 } },
			alpha = { { 0, 1 }, { 0.12, 0.12 }, { 0.75, 0.3 }, { 1, 1 } },
			life = { 1.3, 2.1 },
			speed = { 0.8, 2.4 },
			spread = 45,
			accel = Vector3.new(0.6, 2.6, 0.3),
			drag = 0.8,
			rot = { 0, 360 },
			spin = if still then 0 else { -140, 140 },
			light = 0,
			lit = 0.65,
			shape = Enum.ParticleEmitterShape.Box,
			rate = 30,
		},
		{
			tex = "VfxSparks",
			ramp = C.hotter(ash),
			size = { { 0, 0.22 }, { 1, 0.05 } },
			alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.2 }, { 1, 1 } },
			life = { 0.7, 1.3 },
			speed = { 0.6, 1.8 },
			spread = 45,
			accel = Vector3.new(0.4, 2.8, 0.2),
			drag = 1.2,
			face = "along",
			bright = 2.2,
			shape = Enum.ParticleEmitterShape.Box,
			rate = 10,
		},
		{
			tex = "VfxSmokePlume",
			ramp = C.shadow(ash),
			size = { { 0, 0.6 }, { 1, 2 } },
			alpha = { { 0, 1 }, { 0.3, 0.75 }, { 1, 1 } },
			life = { 1.4, 2.2 },
			speed = { 0.3, 0.8 },
			spread = 40,
			accel = Vector3.new(0.5, 1.6, 0.2),
			light = 0,
			lit = 0.3,
			z = -1,
			shape = Enum.ParticleEmitterShape.Box,
			rate = 4,
		},
	})
	local stopLater = Clock.after(seconds, function()
		loop.stop()
	end)
	local destroyLater = Clock.after(seconds + 2.6, function()
		loop.destroy()
	end)
	return function()
		stopLater()
		destroyLater()
		loop.destroy()
	end
end

-- Handcuffs clicking shut, Death's Manual landing: a hard star, white-hot sparks flung and falling, a flick of light.
function Gameplay.sparks(position: Vector3, tint: Color3?)
	local ramp = if tint == nil or tint == WHITE then nil else rampOf(tint)
	Small.tap(position, { ramp = ramp, scale = 1.5, sparks = 18, lead = 0.04 })
end

-- The chalk outline cutting in: a breath of pale dust off the floor round it.
function Gameplay.chalkDust(at: CFrame, tint: Color3?, size: number)
	Smoke.dustKick(at, {
		ramp = if tint == nil or tint == WHITE then Palette.WORLD.bone else rampOf(tint),
		scale = math.clamp(size / 6, 0.8, 1.6),
		lead = 0.05,
	})
end

-- DeathVfx's floor dust (a foot coming down, a knee, a body landing): `at` is the floor point.
function Gameplay.dust(floor: Vector3, scale: number)
	-- (two emitters a beat, not a whole recipe: the collapses call this several times in two seconds)
	local at = CFrame.new(floor + Vector3.new(0, 0.1, 0))
	Emit.burst(at, {
		{
			{
				tex = "VfxDustRoll",
				ramp = Palette.WORLD.dust,
				size = C.size("VfxDustRoll", 5 * scale, { { 0, 2 * scale }, { 1, 5 * scale } }),
				alpha = { { 0, 1 }, { 0.12, 0.12 }, { 0.7, 0.32 }, { 1, 1 } },
				life = { 1.3, 1.7 },
				speed = { 2 * scale, 5 * scale },
				drag = 1.6,
				spread = 180,
				face = "up",
				light = 0,
				lit = 0.55,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxShards",
				ramp = Palette.WORLD.dust,
				size = { { 0, 0.3 * scale, 0.12 * scale }, { 1, 0.24 * scale, 0.1 * scale } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0 }, { 1, 1 } },
				life = { 0.4, 0.8 },
				speed = { 3 * scale, 8 * scale },
				accel = Vector3.new(0, -30, 0),
				spread = 60,
				spin = if C.still() then 0 else { -300, 300 },
				rot = { 0, 360 },
				light = 0,
				lit = 0.6,
			},
			4,
		},
	}, nil, Vector3.new(1.2 * scale, 0.2, 1.2 * scale))
end

-- DeathVfx's soft puffs: a breath of sick from the mouth along `dir`, or one soft cloud about the body.
function Gameplay.puff(at: Vector3, colour: Color3, size: number, dir: Vector3?)
	local ramp: Palette.Ramp = { WHITE:Lerp(colour, 0.35), colour, Palette.deeper(colour) }
	if dir then
		Small.breath(at, { ramp = ramp, scale = math.max(1, size * 0.9), dir = dir, dark = false, lead = 0.03 })
	else
		Emit.burst(at, {
			tex = "VfxSmokePuff",
			ramp = ramp,
			size = C.size("VfxSmokePuff", math.clamp(size * 1.6, 1.2, 5.5), { { 0, size * 0.5 }, { 1, size * 1.6 } }),
			alpha = { { 0, 1 }, { 0.15, 0.18 }, { 0.7, 0.4 }, { 1, 1 } },
			life = { 1.2, 1.8 },
			speed = { 0.3, 0.9 },
			accel = Vector3.new(0, 0.8, 0),
			drag = 1.1,
			rot = { 0, 360 },
			light = 0,
			lit = 0.55,
		}, 1)
	end
end

-- DeathVfx's glow (the heart's seizure): one hard glint in the colour, and its light.
function Gameplay.glow(at: Vector3, colour: Color3, size: number, light: number?)
	local ramp = rampOf(colour)
	local s = math.clamp(size * 0.7, 0.8, 2.4)
	Emit.burst(at, {
		{
			{
				tex = "VfxGlint",
				ramp = C.hotter(ramp),
				size = C.size("VfxGlint", 2.6 * s, { { 0, 0 }, { 0.35, 2.6 * s }, { 1, 0 } }),
				alpha = { { 0, 0 }, { 0.5, 0.08 }, { 1, 1 } },
				life = 0.55,
				rot = { -14, 14 },
				bright = 2.3,
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxMist",
				ramp = C.shadow(ramp),
				size = { { 0, 1.2 * s }, { 1, 1.8 * s } },
				alpha = { { 0, 1 }, { 0.25, 0.6 }, { 0.8, 0.75 }, { 1, 1 } },
				life = 0.9,
				light = 0,
				z = -1,
			},
			1,
		},
	})
	if light then
		Light.flash(at, colour, size * 3, light, 0.4)
	end
end

-- The accident: the head meeting the floor, a soft blow in white (the floor point).
function Gameplay.knock(floor: Vector3)
	Impact.impact(CFrame.new(floor), { style = "sharp", scale = 0.6, ground = true, shake = true, lead = 0.04 })
end

-- A haunt's mist: a cold pale cloud welling up and rolling out low over the floor, frost specks glinting in it.
function Gameplay.hauntMist(position: Vector3)
	local floor, normal = Ground.at(position, nil, 8)
	local up = if normal.Magnitude > 0.01 then normal else Vector3.yAxis
	local side = up:Cross(if math.abs(up.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
	local spot = CFrame.fromMatrix(floor + up * 0.15, side, up)
	-- (three emitters: a roll along the floor, a bank that wells up out of it, specks of frost in it)
	Emit.burst(spot, {
		{
			{
				tex = "VfxDustRoll",
				ramp = COLD,
				size = C.size("VfxDustRoll", 6.5, { { 0, 2.5 }, { 1, 6.5 } }),
				alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
				life = { 2.1, 2.4 },
				speed = { 2, 5 },
				drag = 1.5,
				spread = 180,
				face = "up",
				light = 0.05,
				lit = 0.6,
				z = 1,
			},
			2,
		},
		{
			{
				tex = "VfxMist",
				ramp = COLD,
				size = { { 0, 3 }, { 1, 5.6 } },
				alpha = { { 0, 1 }, { 0.25, 0.12 }, { 0.75, 0.3 }, { 1, 1 } },
				life = { 2.2, 2.8 },
				speed = { 0.3, 1 },
				accel = Vector3.new(0, 0.5, 0),
				spread = 180,
				rot = { 0, 360 },
				light = 0.05,
				lit = 0.6,
			},
			3,
		},
		{
			{
				tex = "VfxSparks",
				ramp = C.hotter(COLD),
				size = { { 0, 0 }, { 0.3, 0.14 }, { 1, 0 } },
				alpha = { { 0, 1 }, { 0.2, 0.1 }, { 0.8, 0.3 }, { 1, 1 } },
				life = { 1.2, 2 },
				speed = { 0.5, 1.5 },
				spread = 180,
				bright = 1.6,
			},
			10,
		},
	}, nil, Vector3.new(3, 0.5, 3))
end

-- The dive's crash into the roof: a heavy blow laid flat on it, in the roof's own dust.
function Gameplay.crash(floor: Vector3, normal: Vector3, scale: number)
	local frame = CFrame.lookAt(floor, floor + normal) * CFrame.Angles(math.rad(-90), 0, 0)
	Impact.slam(frame, { ramp = Palette.WORLD.dust, scale = scale, shake = false, lead = 0.06 })
end

-- The Deathsinger's eyes lit in the dark before the rest of it (a glint in each).
function Gameplay.eyesOf(spots: { Vector3 })
	local red = EYES
	for _, spot in ipairs(spots) do
		star(spot, red, 1.6, 1.1)
	end
end

-- Your eyes taking fire: a hard star in each eye and a ring of red out from the face with sparks (the arcs, the flash and
-- the light stay the presenter's own).
function Gameplay.eyesIgnite(spots: { Vector3 }, head: Vector3)
	local red = EYES
	for _, spot in ipairs(spots) do
		star(spot, red, 2.6, 0.8)
	end
	Small.tap(head, { ramp = red, scale = 1.8, sparks = 10, lite = true, light = false, lead = 0.06 })
end

-- A stare's red eyes lighting: one hard star where each eye opens.
function Gameplay.eyeOpens(spot: Vector3)
	star(spot, EYES, 1.4, 0.7)
end

return Gameplay
