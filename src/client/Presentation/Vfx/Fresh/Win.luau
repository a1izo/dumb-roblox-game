--!strict
-- The win cutscenes' "fx" act kinds on the new kit (stage 4c; Presentation/WinCinema's FX table calls these when the kind's
-- Pilot flag is on, and keeps its old build behind the flag). The data in Shared/Cinema/WinCuts does not change: each kind
-- takes what the act already gives (the frame `at`, the cut's `color`, `scale`, the event's own numbers) and draws it from
-- the new sheets. A win cut is a shop effect, so every kind wears the cut's own colour at full strength: white-hot at the
-- core, the colour as the body, a darker shade of it at the edge (Palette.shop), never a grey.
--
--   wave     a flat ring on the floor: a shock band that thins and breaks, a dark band under it
--   sparks   hot streaks flung out of a point, a star at the point
--   bloom    a soft bank of light that swells and fades, a star at its start
--   ring     a camera-facing ring opening
--   dust     dust rolled out along the floor both ways from a point (the roll the impact leaves)
--   held     embers, motes, ash and drizzle: the specs of the held kinds (WinCinema holds them over a box)
--
-- The hits land at once (a small lead of 0.06 s for the recipes that gather first), because the cut's beat is the event's
-- time and the cut's timing is not changed here.

local Emit = require(script.Parent.Parent.Emit)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)
local Smoke = require(script.Parent.Smoke)

local Win = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- A cut's colour as a full-colour ramp.
function Win.ramp(color: Color3): Palette.Ramp
	return Palette.shop(color)
end

-- A matter ramp (dust, ash): the colour lit at birth, the colour, then a darker shade of it (no white-hot core: matter is laid over).
local function matter(color: Color3): Palette.Ramp
	return { color:Lerp(WHITE, 0.3), color, color:Lerp(BLACK, 0.55) }
end

-- A flat ring on the floor round `at`, `from` studs across to `to` over `seconds` (a shockwave).
function Win.wave(at: CFrame, event: { [string]: any }, color: Color3, s: number)
	local ramp = Win.ramp(color)
	local to = (event.to or 9) * s * 2.1
	local from = (event.from or 0.4) * s * 2
	-- (the sheet's own frames open the ring; one still picture has to be grown by hand when the sheet is not there)
	local life = math.max(event.seconds or 0.7, 0.6)
	Emit.burst(at, {
		{
			{
				-- (the dark band under the ring, laid over the floor so the bright one reads on a lit one)
				tex = "VfxShock",
				ramp = C.shadow(ramp),
				size = C.size("VfxShock", to * 1.04, { { 0, from }, { 1, to * 1.04 } }),
				alpha = { { 0, 1 }, { 0.1, 0.35 }, { 0.6, 0.55 }, { 1, 1 } },
				life = life,
				face = "flat",
				speed = 0.001,
				light = 0,
				lit = 0.3,
				z = -1,
			},
			1,
		},
		{
			{
				tex = "VfxShock",
				ramp = ramp,
				size = C.size("VfxShock", to, { { 0, from }, { 1, to } }),
				alpha = { { 0, 1 }, { 0.1, 0.15 }, { 0.6, 0.45 }, { 1, 1 } },
				life = life,
				face = "flat",
				speed = 0.001,
				bright = event.bright or 2.2,
				z = 1,
			},
			1,
		},
	})
end

-- Hot sparks flung out of `at`, falling, a star where they left.
function Win.sparks(at: CFrame, event: { [string]: any }, color: Color3, s: number)
	local ramp = Win.ramp(color)
	Emit.burst(at, {
		{
			{
				tex = "VfxSparks",
				ramp = C.hotter(ramp),
				size = { { 0, 0.6 * s }, { 1, 0.1 * s } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
				life = { 0.25, 0.7 },
				speed = { 12 * s, 28 * s },
				drag = 3,
				accel = Vector3.new(0, -42, 0),
				spread = event.spread or 75,
				face = "along",
				bright = 1.6,
				z = 1,
			},
			math.min(event.count or 22, 22),
		},
		{
			{
				tex = "VfxGlint",
				ramp = C.hotter(ramp),
				size = C.size("VfxGlint", 2.2 * s, { { 0, 0 }, { 0.3, 2.2 * s }, { 1, 0 } }),
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.55,
				rot = { -14, 14 },
				bright = 2.2,
				z = 2,
			},
			1,
		},
	})
end

-- A soft bank of light that swells and fades over `seconds` (a fire flaring, a page catching), a star at its start.
function Win.bloom(at: CFrame, event: { [string]: any }, color: Color3, s: number)
	local ramp = Win.ramp(color)
	local size = (event.size or 6) * s
	Emit.burst(at, {
		{
			{
				tex = "VfxMist",
				ramp = ramp,
				size = { { 0, 1.5 * s }, { 0.3, size }, { 1, size * 1.2 } },
				alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.65, 0.35 }, { 1, 1 } },
				life = event.seconds or 0.9,
				rot = { 0, 360 },
				light = 0.9,
				lit = 0.1,
				bright = event.bright or 1.2,
				z = 0.5,
			},
			1,
		},
		{
			{
				tex = "VfxGlint",
				ramp = C.hotter(ramp),
				size = C.size("VfxGlint", size * 0.45, { { 0, 0 }, { 0.3, size * 0.45 }, { 1, 0 } }),
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.55,
				rot = { -12, 12 },
				bright = 2.1,
				z = 1,
			},
			1,
		},
	})
end

-- A ring of light facing the camera, opening (a power landing, a vow).
function Win.ring(at: CFrame, event: { [string]: any }, color: Color3, s: number)
	local ramp = Win.ramp(color)
	local size = (event.size or 9) * s
	local life = math.max(event.seconds or 0.45, 0.6)
	Emit.burst(at, {
		{
			{
				-- (the dark ring behind it, laid over the scene so the bright one reads in a lit room)
				tex = "VfxShock",
				ramp = C.shadow(ramp),
				size = C.size("VfxShock", size * 1.05, { { 0, 0.5 * s }, { 0.5, size * 0.84 }, { 1, size * 1.05 } }),
				alpha = { { 0, 1 }, { 0.12, 0.3 }, { 0.6, 0.5 }, { 1, 1 } },
				life = life,
				light = 0,
				lit = 0.3,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxShock",
				ramp = ramp,
				size = C.size("VfxShock", size, { { 0, 0.5 * s }, { 0.5, size * 0.8 }, { 1, size } }),
				alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.6, 0.3 }, { 1, 1 } },
				life = life,
				bright = 2.2,
				z = 2,
			},
			1,
		},
	})
end

-- Dust rolled out along the floor both ways from `at` (the floor frame's look and the opposite).
function Win.dust(at: CFrame, _event: { [string]: any }, color: Color3, s: number)
	local ramp = matter(color)
	Smoke.dustKick(at, { ramp = ramp, scale = 0.6 * s, dir = at.LookVector, lead = 0.06 })
	Smoke.dustKick(at, { ramp = ramp, scale = 0.6 * s, dir = -at.LookVector, lead = 0.06 })
end

-- The held kinds' specs (rate the emitters make over their box; WinCinema holds them for the act's seconds).
Win.HELD = {
	-- embers rising off a fire: sparks that climb, slow and wander
	embers = function(color: Color3, s: number): { [string]: any }
		return {
			tex = "VfxSparks",
			ramp = Win.ramp(color),
			size = { { 0, 0.3 * s }, { 1, 0.05 * s } },
			alpha = { { 0, 1 }, { 0.1, 0.1 }, { 0.8, 0.25 }, { 1, 1 } },
			life = { 1.2, 2.4 },
			speed = { 1.5, 4.5 },
			spread = 25,
			accel = Vector3.new(0.8, 3, 0),
			drag = 0.6,
			rate = 22,
			face = "along",
			bright = 2.2,
		}
	end,
	-- motes of light drifting in a lamp's beam: small stars that open and close slowly
	motes = function(color: Color3, s: number): { [string]: any }
		return {
			tex = "VfxGlint",
			ramp = Win.ramp(color),
			size = { { 0, 0.2 * s }, { 0.5, 0.26 * s }, { 1, 0.2 * s } },
			alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.85, 0.3 }, { 1, 1 } },
			life = { 3, 5 },
			speed = { 0.05, 0.3 },
			spread = 180,
			accel = Vector3.new(0.05, 0.04, 0),
			rate = 6,
			bright = 2.2,
			light = 0.6,
		}
	end,
	-- ash falling: flakes with a lit side, tumbling, laid over (never added)
	ash = function(color: Color3, s: number): { [string]: any }
		return {
			tex = "VfxAshFlakes",
			ramp = matter(color),
			size = { { 0, 0.34 * s }, { 1, 0.26 * s } },
			alpha = { { 0, 1 }, { 0.1, 0.1 }, { 0.8, 0.25 }, { 1, 1 } },
			life = { 2.5, 4 },
			speed = { 0.4, 1.2 },
			spread = 180,
			accel = Vector3.new(0.4, -1.2, 0),
			rate = 12,
			light = 0,
			lit = 1,
			rot = { 0, 360 },
			spin = { -90, 90 },
		}
	end,
	-- sparks dripping off a burning edge: hot streaks falling
	drizzle = function(color: Color3, s: number): { [string]: any }
		return {
			tex = "VfxSparks",
			ramp = C.hotter(Win.ramp(color)),
			size = { { 0, 0.3 * s }, { 1, 0.04 * s } },
			alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
			life = { 0.3, 0.6 },
			speed = { 2, 6 },
			spread = 40,
			accel = Vector3.new(0, -30, 0),
			face = "along",
			rate = 20,
			bright = 2.2,
		}
	end,
}

return Win
