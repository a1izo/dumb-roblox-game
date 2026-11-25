--!strict
-- What a Manual cover does in play (the owner, 2026-10-25: "make the manual covers more high quality and give them
-- meaning because buying them makes no sense right now"): whenever Death's Manual is out in someone's hands (held
-- open while they pick a name, or written in: the server's LWriting book, CharacterService.setWriting), its cover
-- gives itself away to everyone close enough to see, each in its own way, and more strongly while a name is being
-- written (LManualOpen). A cover is a signature: whoever saw it once knows it again.
--
--   oxblood   the hide still has a pulse: a dark red glow that beats in it, faster while it is written in
--   gilded    gilt glinting slowly over the board; gold flecks rising off the page as a name goes in
--   burnt     embers falling off its charred edges and a thread of smoke; a shower of them while written in
--   casefile  loose pages slipping out of the folder as it opens
--   iron      the padlock clanking open with a spark as it comes out; the iron glowing dull red as it is written in
--   scale     the eye on the cover, open and red, blinking; a red breath off it while written in
--   mirror    a cold light running along the cracks in the glass; the glass frosting over while written in

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Characters = require(script.Parent.Parent.Characters)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Presentation.Vfx.Pilot)

local CoverTells = {}

type Tell = {
	-- emitters made at once, each with its rate while the book is held and while it is written in
	emitters: { { spec: { [string]: any }, held: number, writing: number } },
	appear: ((carrier: BasePart, size: Vector3) -> ())?, -- once, as the book comes out
	light: { color: Color3, held: number, writing: number, beat: number? }?,
}

local GOLD = Color3.fromRGB(232, 190, 96)
local BLOOD = Color3.fromRGB(150, 18, 24)
local EMBER = Color3.fromRGB(255, 150, 60)
local COLD = Color3.fromRGB(196, 222, 255)

local TELLS: { [string]: Tell } = {
	oxblood = {
		emitters = {
			{
				spec = {
					tex = "VfxGlow",
					color = BLOOD,
					size = { { 0, 1.6 }, { 0.15, 2.2 }, { 1, 1.4 } },
					alpha = { { 0, 1 }, { 0.15, 0.45 }, { 1, 1 } },
					life = 0.9,
					locked = true,
					light = 0.7,
					bright = 1.1,
					z = 0.6,
				},
				held = 1.1,
				writing = 2.2,
			},
		},
		light = { color = BLOOD, held = 0.6, writing = 1.2, beat = 1.1 },
	},
	gilded = {
		emitters = {
			{
				spec = {
					tex = "VfxFlare",
					color = GOLD,
					size = { { 0, 0 }, { 0.4, 0.35 }, { 1, 0 } },
					life = 0.6,
					rot = { 0, 45 },
					locked = true,
					light = 1,
					bright = 1.6,
					shape = Enum.ParticleEmitterShape.Box,
					z = 0.6,
				},
				held = 1.6,
				writing = 3,
			},
			{
				spec = {
					tex = "VfxEmber",
					color = GOLD,
					size = { { 0, 0.1 }, { 1, 0 } },
					life = { 0.8, 1.4 },
					speed = { 0.4, 1 },
					spread = 30,
					accel = Vector3.new(0, 1.2, 0),
					bright = 1.5,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0,
				writing = 12,
			},
		},
	},
	burnt = {
		emitters = {
			{
				spec = {
					tex = "VfxEmber",
					color = { { 0, Color3.fromRGB(255, 210, 140) }, { 1, EMBER } },
					size = { { 0, 0.09 }, { 1, 0 } },
					life = { 0.6, 1.1 },
					speed = { 0.2, 0.6 },
					spread = 50,
					accel = Vector3.new(0, -1.5, 0),
					bright = 1.5,
					shape = Enum.ParticleEmitterShape.Box,
					shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				},
				held = 4,
				writing = 16,
			},
			{
				spec = {
					tex = "VfxSmoke",
					grid = 8,
					color = Color3.fromRGB(70, 64, 60),
					light = 0,
					lit = 0.4,
					size = { { 0, 0.4 }, { 1, 1.4 } },
					alpha = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } },
					life = { 1.2, 1.8 },
					speed = { 0.4, 0.9 },
					spread = 15,
					rot = { 0, 360 },
				},
				held = 1,
				writing = 3,
			},
		},
		light = { color = EMBER, held = 0.3, writing = 0.8 },
	},
	casefile = {
		emitters = {},
		appear = function(carrier: BasePart, size: Vector3)
			Sfx.play("pageTurn", { parent = carrier, volume = 0.8 })
			Vfx.Emit.burst(carrier.Position, {
				tex = "VfxPage",
				color = Color3.fromRGB(236, 230, 214),
				light = 0,
				lit = 0.8,
				size = { { 0, 0.35 }, { 1, 0.3 } },
				alpha = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				life = { 1.2, 1.8 },
				speed = { 1, 3 },
				spread = 70,
				accel = Vector3.new(0, -3, 0),
				drag = 2,
				rot = { 0, 360 },
				spin = { -140, 140 },
			}, 3, size)
		end,
	},
	iron = {
		emitters = {
			{
				spec = {
					tex = "VfxGlow",
					color = Color3.fromRGB(150, 50, 24),
					size = 1.6,
					alpha = { { 0, 1 }, { 0.2, 0.55 }, { 0.8, 0.55 }, { 1, 1 } },
					life = 1.2,
					locked = true,
					light = 0.8,
					bright = 1,
					z = 0.6,
				},
				held = 0,
				writing = 2,
			},
		},
		appear = function(carrier: BasePart)
			-- (the padlock clanking open with a spark)
			Sfx.play("handcuffs", { parent = carrier, volume = 0.9, pitch = 0.8 })
			Vfx.Emit.burst(carrier.Position, {
				tex = "VfxEmber",
				color = Color3.fromRGB(255, 200, 120),
				size = { { 0, 0.12 }, { 1, 0 } },
				life = { 0.3, 0.6 },
				speed = { 4, 8 },
				spread = 70,
				accel = Vector3.new(0, -16, 0),
				bright = 1.8,
			}, 8)
		end,
	},
	scale = {
		emitters = {
			{
				spec = {
					tex = "VfxGlow",
					color = BLOOD,
					size = { { 0, 0.9 }, { 0.1, 1.1 }, { 0.85, 1.1 }, { 0.92, 0.1 }, { 1, 1.1 } },
					alpha = { { 0, 1 }, { 0.1, 0.35 }, { 1, 0.35 } },
					life = 2.4,
					locked = true,
					light = 1,
					bright = 1.3,
					z = 0.7,
				},
				held = 0.42,
				writing = 0.42,
			},
			{
				spec = {
					tex = "VfxSmoke",
					grid = 8,
					color = Color3.fromRGB(90, 14, 18),
					light = 0.2,
					lit = 0.3,
					size = { { 0, 0.5 }, { 1, 1.6 } },
					alpha = { { 0, 1 }, { 0.25, 0.65 }, { 1, 1 } },
					life = { 1, 1.6 },
					speed = { 0.4, 0.9 },
					spread = 20,
					rot = { 0, 360 },
				},
				held = 0,
				writing = 3,
			},
		},
		light = { color = BLOOD, held = 0.4, writing = 0.9 },
	},
	mirror = {
		emitters = {
			{
				spec = {
					tex = "VfxFlare",
					color = COLD,
					size = { { 0, 0 }, { 0.5, 0.3 }, { 1, 0 } },
					life = 0.5,
					rot = { 0, 45 },
					locked = true,
					light = 1,
					bright = 1.6,
					shape = Enum.ParticleEmitterShape.Box,
					z = 0.6,
				},
				held = 2,
				writing = 4,
			},
			{
				spec = {
					tex = "VfxGlow",
					color = COLD,
					size = 1.8,
					alpha = { { 0, 1 }, { 0.2, 0.6 }, { 0.8, 0.6 }, { 1, 1 } },
					life = 1.4,
					locked = true,
					light = 0.8,
					bright = 1,
					z = 0.5,
				},
				held = 0,
				writing = 1.6,
			},
		},
		light = { color = COLD, held = 0.25, writing = 0.7 },
	},
}

-- The Black Mirror's tell on the new kit (the pilot V3.3: the dearest of the two legendary covers, 1100; Pilot.on.cover = false
-- brings the old tell back). The idea: cold light trapped in cracked glass. Five moments, a loop's:
--   gather   0.0 s as the book comes out: specks of cold light drawn in to the cover (Fresh.glint's gather)
--   hit      0.12 s later: one star of white-hot cold light flashes across the glass, with a small light
--   body     held: a glint every second or so crosses the glass, a few cold motes rise; written in: glints three times
--            as often and a frost of fog blooms off the cover (the glass "frosts over")
--   break-up each glint erodes by itself (the sheet is drawn eaten away); the frost thins with its rate
--   residue  the motes and the last of the frost drift 1 to 2 s after the pen lifts
-- Full colour (a shop effect): the cover's own cold blue, white-hot at the core.
local COLD_RAMP = Palette.shop(COLD)
local MIRROR_FRESH: Tell = {
	emitters = {
		{
			spec = {
				tex = "VfxGlint",
				ramp = COLD_RAMP,
				size = 1.3,
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.6,
				rot = { -14, 14 },
				locked = true,
				light = 1,
				bright = 2.3,
				shape = Enum.ParticleEmitterShape.Box,
				z = 0.6,
			},
			held = 1.6,
			writing = 3,
		},
		{
			spec = {
				tex = "VfxMist",
				ramp = COLD_RAMP,
				size = { { 0, 1.6 }, { 1, 2.6 } },
				alpha = { { 0, 1 }, { 0.25, 0.12 }, { 0.75, 0.25 }, { 1, 1 } },
				life = { 1.4, 1.8 },
				speed = { 0.2, 0.5 },
				spread = 60,
				rot = { 0, 360 },
				light = 0.8,
				lit = 0.1,
				shape = Enum.ParticleEmitterShape.Box,
				z = -0.5,
			},
			held = 0,
			writing = 1.6,
		},
		{
			spec = {
				tex = "VfxSparks",
				ramp = COLD_RAMP,
				size = { { 0, 0.26 }, { 1, 0.06 } },
				alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
				life = { 1, 1.6 },
				speed = { 0.2, 0.6 },
				spread = 40,
				accel = Vector3.new(0, 0.4, 0),
				bright = 1.5,
				shape = Enum.ParticleEmitterShape.Box,
			},
			held = 0.8,
			writing = 3,
		},
	},
	appear = function(carrier: BasePart)
		Fresh.glint(carrier.Position, { ramp = COLD_RAMP, scale = 0.7 })
	end,
	light = { color = COLD, held = 0.25, writing = 0.7 },
}

-- The other six covers on the new kit (stage 4c; each behind its own Pilot flag, the old tell kept above). Every one is full
-- colour (a shop effect): the cover's own colour, white-hot at the core and a darker shade of itself at the edge, each from a
-- shaped sheet (a glint, a mist, sparks, a paper, ash flakes, a plume), never the old glow dot. Five moments, a loop's:
--   gather   the cover coming out of the pocket draws specks in (its appear)
--   hit      the first flash of the cover's own thing (a heartbeat, a gleam, a spark, a page, a padlock, the eye)
--   body     its steady tell at the held rate; at the written-in rate while a name goes in
--   break-up each piece erodes with its sheet (glints, mist and plume are drawn eaten away)
--   residue  a few specks, flakes or pages still drifting a second or two after the pen lifts
local OX_RAMP = Palette.shop(BLOOD)
local OX_DARK =
	{ Palette.deeper(BLOOD), Palette.deeper(BLOOD):Lerp(Color3.new(0, 0, 0), 0.4), Color3.fromRGB(10, 2, 3) }
local GOLD_RAMP = Palette.shop(GOLD)
local EMBER_RAMP = Palette.shop(EMBER)
local CHAR_RAMP = { Color3.fromRGB(120, 100, 88), Color3.fromRGB(46, 38, 34), Color3.fromRGB(12, 10, 9) }
local PAPER_RAMP = Palette.shop(Color3.fromRGB(222, 196, 136))
local IRON_BODY = Color3.fromRGB(214, 78, 34)
local IRON_RAMP = Palette.shop(IRON_BODY)
local OX_GLOW = { BLOOD, BLOOD, Palette.deeper(BLOOD) } -- (a glow keeps its colour from birth: a white-hot start would make it a grey haze)
local IRON_GLOW = { IRON_BODY, IRON_BODY, Palette.deeper(IRON_BODY) }

local FRESH_TELLS: { [string]: Tell } = {
	-- the hide still has a pulse: a dark red heart that beats in the leather, a dark layer under it, hot specks
	oxblood = {
		emitters = {
			{
				spec = {
					tex = "VfxMist",
					ramp = OX_GLOW,
					size = { { 0, 1.6 }, { 0.15, 2.6 }, { 1, 1.8 } },
					alpha = { { 0, 1 }, { 0.15, 0.14 }, { 0.7, 0.32 }, { 1, 1 } },
					life = 0.9,
					rot = { 0, 360 },
					locked = true,
					light = 0.7,
					lit = 0.1,
					bright = 1.3,
					z = 0.6,
				},
				held = 1.1,
				writing = 2.2,
			},
			{
				spec = {
					tex = "VfxMist",
					ramp = OX_DARK,
					size = { { 0, 1.6 }, { 1, 2.4 } },
					alpha = { { 0, 1 }, { 0.25, 0.3 }, { 0.8, 0.5 }, { 1, 1 } },
					life = 1.2,
					rot = { 0, 360 },
					locked = true,
					light = 0,
					lit = 0.3,
					z = 0.3,
				},
				held = 1.1,
				writing = 2.2,
			},
			{
				spec = {
					tex = "VfxSparks",
					ramp = OX_RAMP,
					size = { { 0, 0.22 }, { 1, 0.05 } },
					alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
					life = { 0.8, 1.4 },
					speed = { 0.3, 0.8 },
					spread = 40,
					accel = Vector3.new(0, 0.6, 0),
					face = "along",
					bright = 1.5,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0.8,
				writing = 5,
			},
		},
		appear = function(carrier: BasePart)
			Fresh.tap(carrier.Position, { ramp = OX_RAMP, scale = 0.45, sparks = 5, lite = true, light = false })
		end,
		light = { color = BLOOD, held = 0.6, writing = 1.2, beat = 1.1 },
	},
	-- gilt glinting slowly over the board, gold flecks rising off the page as a name goes in
	gilded = {
		emitters = {
			{
				spec = {
					tex = "VfxGlint",
					ramp = GOLD_RAMP,
					size = 1.3,
					alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
					life = 0.6,
					rot = { -14, 14 },
					locked = true,
					light = 1,
					bright = 2.3,
					shape = Enum.ParticleEmitterShape.Box,
					z = 0.6,
				},
				held = 1.6,
				writing = 3,
			},
			{
				spec = {
					tex = "VfxSparks",
					ramp = GOLD_RAMP,
					size = { { 0, 0.24 }, { 1, 0.05 } },
					alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
					life = { 0.8, 1.5 },
					speed = { 0.4, 1 },
					spread = 30,
					accel = Vector3.new(0, 1.2, 0),
					face = "along",
					bright = 1.6,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0,
				writing = 12,
			},
		},
		appear = function(carrier: BasePart)
			Fresh.tap(carrier.Position, { ramp = GOLD_RAMP, scale = 0.45, sparks = 5, lite = true, light = false })
		end,
		light = { color = GOLD, held = 0.2, writing = 0.6 },
	},
	-- embers falling off its charred edges, a thread of smoke, ash flakes; a shower of them while written in
	burnt = {
		emitters = {
			{
				spec = {
					tex = "VfxSparks",
					ramp = EMBER_RAMP,
					size = { { 0, 0.4 }, { 1, 0.08 } },
					alpha = { { 0, 1 }, { 0.12, 0.05 }, { 0.8, 0.2 }, { 1, 1 } },
					life = { 0.6, 1.1 },
					speed = { 0.2, 0.6 },
					spread = 50,
					accel = Vector3.new(0, -1.5, 0),
					face = "along",
					bright = 2.1,
					shape = Enum.ParticleEmitterShape.Box,
					shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				},
				held = 4,
				writing = 16,
			},
			{
				spec = {
					tex = "VfxSmokePlume",
					ramp = CHAR_RAMP,
					size = { { 0, 0.5 }, { 1, 1.5 } },
					alpha = { { 0, 1 }, { 0.2, 0.35 }, { 0.8, 0.5 }, { 1, 1 } },
					life = { 1.2, 1.8 },
					speed = { 0.4, 0.9 },
					spread = 15,
					light = 0,
					lit = 0.4,
					z = -0.4,
				},
				held = 1,
				writing = 3,
			},
			{
				spec = {
					tex = "VfxAshFlakes",
					ramp = CHAR_RAMP,
					size = { { 0, 0.22 }, { 1, 0.16 } },
					alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.8, 0.25 }, { 1, 1 } },
					life = { 1.4, 2.2 },
					speed = { 0.2, 0.5 },
					spread = 70,
					accel = Vector3.new(0, -1, 0),
					drag = 1,
					rot = { 0, 360 },
					spin = { -80, 80 },
					light = 0,
					lit = 0.6,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0.6,
				writing = 3,
			},
		},
		appear = function(carrier: BasePart)
			Fresh.tap(carrier.Position, { ramp = EMBER_RAMP, scale = 0.4, sparks = 5, lite = true, light = false })
		end,
		light = { color = EMBER, held = 0.3, writing = 0.8 },
	},
	-- loose pages slipping out of the folder as it opens, one now and then after, more while written in
	casefile = {
		emitters = {
			{
				spec = {
					tex = "VfxPaper",
					ramp = PAPER_RAMP,
					size = { { 0, 0.55 }, { 1, 0.48 } },
					alpha = { { 0, 1 }, { 0.1, 0 }, { 0.8, 0.1 }, { 1, 1 } },
					life = { 1.6, 2.4 },
					speed = { 0.4, 1.2 },
					spread = 70,
					accel = Vector3.new(0, -1.6, 0),
					drag = 1.5,
					rot = { 0, 360 },
					spin = { -90, 90 },
					light = 0,
					lit = 0.8,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0.25,
				writing = 1.2,
			},
		},
		appear = function(carrier: BasePart, size: Vector3)
			Sfx.play("pageTurn", { parent = carrier, volume = 0.8 })
			-- (three pages slipping out and turning as they fall: the sheet of tumbling pages, slow like the old ones)
			Vfx.Emit.burst(carrier.Position, {
				tex = "VfxPaper",
				ramp = PAPER_RAMP,
				size = { { 0, 0.55 }, { 1, 0.48 } },
				alpha = { { 0, 1 }, { 0.1, 0 }, { 0.8, 0.1 }, { 1, 1 } },
				life = { 1.6, 2.4 },
				speed = { 1, 3 },
				spread = 70,
				accel = Vector3.new(0, -2.5, 0),
				drag = 2,
				rot = { 0, 360 },
				spin = { -120, 120 },
				light = 0,
				lit = 0.8,
			}, 3, size)
		end,
	},
	-- the padlock clanking open with a spark as it comes out; the iron glowing dull red as it is written in
	iron = {
		emitters = {
			{
				spec = {
					tex = "VfxMist",
					ramp = IRON_GLOW,
					size = { { 0, 1.2 }, { 0.2, 1.8 }, { 1, 1.4 } },
					alpha = { { 0, 1 }, { 0.2, 0.3 }, { 0.8, 0.4 }, { 1, 1 } },
					life = 1.2,
					rot = { 0, 360 },
					locked = true,
					light = 0.8,
					lit = 0.1,
					bright = 1,
					z = 0.6,
				},
				held = 0,
				writing = 2,
			},
			{
				spec = {
					tex = "VfxSparks",
					ramp = IRON_RAMP,
					size = { { 0, 0.2 }, { 1, 0.04 } },
					alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
					life = { 0.5, 1 },
					speed = { 0.4, 1.2 },
					spread = 60,
					accel = Vector3.new(0, -3, 0),
					face = "along",
					bright = 1.6,
					shape = Enum.ParticleEmitterShape.Box,
				},
				held = 0,
				writing = 4,
			},
		},
		appear = function(carrier: BasePart)
			Sfx.play("handcuffs", { parent = carrier, volume = 0.9, pitch = 0.8 })
			Fresh.tap(carrier.Position, { ramp = IRON_RAMP, scale = 0.45, sparks = 8, lite = true })
		end,
		light = { color = Color3.fromRGB(214, 78, 34), held = 0.1, writing = 0.7 },
	},
	-- the eye on the cover, open and red, blinking; a red breath off it while written in
	scale = {
		emitters = {
			{
				spec = {
					tex = "VfxGlint",
					ramp = OX_RAMP,
					size = 0.9,
					alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } },
					life = 2.4,
					locked = true,
					light = 1,
					bright = 2,
					z = 0.7,
				},
				held = 0.42,
				writing = 0.42,
			},
			{
				spec = {
					tex = "VfxMist",
					ramp = OX_DARK,
					size = { { 0, 0.5 }, { 1, 1.6 } },
					alpha = { { 0, 1 }, { 0.25, 0.4 }, { 1, 1 } },
					life = { 1, 1.6 },
					speed = { 0.4, 0.9 },
					spread = 20,
					rot = { 0, 360 },
					light = 0.2,
					lit = 0.3,
				},
				held = 0,
				writing = 3,
			},
		},
		appear = function(carrier: BasePart)
			Fresh.tap(carrier.Position, { ramp = OX_RAMP, scale = 0.4, sparks = 4, lite = true, light = false })
		end,
		light = { color = BLOOD, held = 0.4, writing = 0.9 },
	},
}

-- Which Pilot flag turns each cover's tell on (the Black Mirror's is `cover`, the first of them, from the pilot).
local COVER_FLAG: { [string]: string } = {
	mirror = "cover",
	oxblood = "coverOxblood",
	gilded = "coverGilded",
	burnt = "coverBurnt",
	casefile = "coverCasefile",
	iron = "coverIron",
	scale = "coverScale",
}

-- The tells by cover style. A new tell is read when asked for, so the Pilot flags can be flipped while the game runs.
CoverTells.STYLES = setmetatable({} :: { [string]: Tell }, {
	__index = function(_, style: string): Tell?
		local flag = COVER_FLAG[style]
		if flag and (Pilot.on :: any)[flag] then
			return if style == "mirror" then MIRROR_FRESH else FRESH_TELLS[style]
		end
		return TELLS[style]
	end,
})

-- A carrier at the held book's middle (welded to its largest piece), for the tell's emitters and light.
local function carrierOf(book: Model): (BasePart?, Vector3)
	local cf, size = book:GetBoundingBox()
	local biggest: BasePart? = nil
	for _, piece in ipairs(book:GetDescendants()) do
		if piece:IsA("BasePart") and (not biggest or piece.Size.Magnitude > (biggest :: BasePart).Size.Magnitude) then
			biggest = piece
		end
	end
	if not biggest then
		return nil, size
	end
	local carrier = Instance.new("Part")
	carrier.Name = "CoverTell"
	carrier.Size = size
	carrier.CFrame = cf
	carrier.Transparency = 1
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.Massless = true
	carrier.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = biggest
	weld.Part1 = carrier
	weld.Parent = carrier
	carrier.Parent = book
	return carrier, size
end

local function dress(character: Model, book: Model)
	local player = Players:GetPlayerFromCharacter(character)
	local style = if player then player:GetAttribute("LGrimoireStyle") else nil
	local tell = if type(style) == "string" then CoverTells.STYLES[style] else nil
	if not tell then
		return
	end
	task.defer(function()
		if not book.Parent then
			return
		end
		local carrier, size = carrierOf(book)
		if not carrier then
			return
		end
		local made: { { emitter: ParticleEmitter, held: number, writing: number } } = {}
		for _, entry in ipairs(tell.emitters) do
			local emitter = Vfx.Emit.make(carrier, entry.spec)
			table.insert(made, { emitter = emitter, held = entry.held, writing = entry.writing })
		end
		local light: PointLight? = nil
		if tell.light then
			local lamp = Instance.new("PointLight")
			lamp.Color = tell.light.color
			lamp.Range = 8
			lamp.Shadows = false
			lamp.Parent = carrier
			light = lamp
		end
		local function apply()
			local writing = character:GetAttribute("LManualOpen") == true
			local quiet = Motion.isLow()
			for _, entry in ipairs(made) do
				local rate = if writing then entry.writing else entry.held
				entry.emitter.Rate = if quiet then rate * 0.5 else rate
				entry.emitter.Enabled = rate > 0
			end
			if light and tell.light then
				light.Brightness = if writing then tell.light.writing else tell.light.held
			end
		end
		apply()
		local changed = character:GetAttributeChangedSignal("LManualOpen"):Connect(apply)
		book.Destroying:Once(function()
			changed:Disconnect()
		end)
		-- (a beating light: oxblood's pulse)
		if light and tell.light and tell.light.beat and not Motion.isReduced() then
			task.spawn(function()
				while light.Parent and book.Parent do
					local writing = character:GetAttribute("LManualOpen") == true
					local peak = (if writing then tell.light.writing else tell.light.held) * 1.8
					local period = (tell.light.beat :: number) / (if writing then 1.8 else 1)
					light.Brightness = peak
					TweenService:Create(light, TweenInfo.new(period * 0.7, Enum.EasingStyle.Quad), {
						Brightness = peak * 0.3,
					}):Play()
					task.wait(period)
				end
			end)
		end
		if tell.appear then
			tell.appear(carrier, size)
		end
	end)
end

function CoverTells.init()
	Characters.each(function(character: Model)
		local book = character:FindFirstChild("LWriting")
		if book and book:IsA("Model") then
			dress(character, book)
		end
		character.ChildAdded:Connect(function(child: Instance)
			if child.Name == "LWriting" and child:IsA("Model") then
				dress(character, child)
			end
		end)
	end)
end

return CoverTells
