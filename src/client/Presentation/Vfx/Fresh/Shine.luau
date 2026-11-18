--!strict
-- Light effects (the plan's V2.5, against art/refs/vfx/glints_sparkles, light_pillar and lightning .toml): a glint, a pillar, an
-- arc of lightning between two points, and a charge that gathers, holds and can be released.
--
--   glint    a star that grows two arms (one longer), holds a moment and drops back to a dot; a dark halo behind it
--   pillar   a ring on the floor, then rays that merge into a column with dark gaps, rings lifting off it, a scorch left
--   arc      a small bright ball, then straight kinked strokes that jump (never glide), a dark mark and smoke where it lands
--   charge   specks drawn in round a dark heart that holds; release() is the hit

local Beams = require(script.Parent.Parent.Beams)
local Clock = require(script.Parent.Parent.Clock)
local Ease = require(script.Parent.Parent.Ease)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local Screen = require(script.Parent.Parent.Screen)
local Shape = require(script.Parent.Parent.Shape)
local C = require(script.Parent.Common)

local Shine = {}

export type GlintOptions = { ramp: Palette.Ramp?, scale: number?, lead: number? }

-- A glint at `at` (2.6 studs across at scale 1).
function Shine.glint(at: CFrame | Vector3, options: GlintOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.12
	local pos = C.position(at)
	return Moment.play(pos, {
		lead = lead,
		gather = function()
			C.gather(pos, ramp, 0.8 * s, lead, 3, 0.25 * s)
		end,
		hit = function()
			Emit.burst(pos, {
				{
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 2.6 * s, { { 0, 0 }, { 0.35, 2.6 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.05 }, { 1, 1 } },
						life = 0.55,
						rot = { -12, 12 },
						bright = 2.4,
						z = 2,
					},
					1,
				},
				{
					{
						-- (a second, smaller star turned across the first: the arms are never even)
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.5 * s, { { 0, 0 }, { 0.35, 1.5 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						rot = { 44, 50 },
						bright = 2,
						z = 3,
					},
					1,
				},
				{
					{
						-- (the dark halo behind: laid over, so the star reads on a lit floor too)
						tex = "VfxMist",
						ramp = shade,
						size = { { 0, 1.4 * s }, { 1, 2 * s } },
						alpha = { { 0, 1 }, { 0.25, 0.55 }, { 0.8, 0.7 }, { 1, 1 } },
						life = 1.1,
						light = 0,
						z = -1,
					},
					1,
				},
			})
			C.beat(pos, ramp[1], 7 * s, 1.4 * s, 0.04)
		end,
		body = function()
			Emit.burst(pos, {
				tex = "VfxSparks",
				ramp = hot,
				size = { { 0, 0.3 * s }, { 1, 0.08 * s } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
				life = { 0.5, 0.9 },
				speed = { 1 * s, 3 * s },
				spread = 180,
				drag = 1.5,
				face = "along",
				bright = 1.5,
			}, 4)
		end,
		residue = function()
			Emit.burst(pos, {
				tex = "VfxSparks",
				ramp = ramp,
				size = { { 0, 0.2 * s }, { 1, 0.05 * s } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.5, 0.3 }, { 1, 1 } },
				life = 1.8,
				speed = { 0.3 * s, 0.9 * s },
				spread = 180,
				accel = Vector3.new(0, 0.4, 0),
				drag = 1,
				face = "along",
				bright = 1.3,
			}, 2)
		end,
	})
end

export type PillarOptions = {
	ramp: Palette.Ramp?,
	height: number?, -- studs (20)
	radius: number?, -- studs (1.8)
	seconds: number?, -- it stands (1.6)
	lead: number?,
}

-- A column of light out of the floor at `at` (its up the column's).
function Shine.pillar(at: CFrame, options: PillarOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local height = o.height or 20
	local r = o.radius or 1.8
	local seconds = o.seconds or 1.6
	local lead = o.lead or 0.45
	local base = at.Position
	local up = at.UpVector
	return Moment.play(at, {
		lead = lead,
		residueAfter = seconds,
		gather = function()
			-- the ring on the floor, drawn before the column
			Emit.burst(at, {
				tex = "VfxShock",
				ramp = ramp,
				size = C.size("VfxShock", r * 3.2, { { 0, r * 0.8 }, { 1, r * 3.4 } }),
				alpha = { { 0, 0.2 }, { 0.6, 0.4 }, { 1, 1 } },
				life = 0.6,
				face = "flat",
				speed = 0.001,
				bright = 1.2,
			}, 1)
			C.gather(base, ramp, r * 2, lead, 8, 0.45)
		end,
		hit = function()
			local box = Vector3.new(r * 2, 0.2, r * 2)
			Emit.burst(at, {
				{
					{
						-- (the rays: thin bright lines racing up, with dark gaps between them)
						tex = "VfxStreak",
						ramp = hot,
						size = { { 0, 0.5 }, { 1, 0.25 } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.3 }, { 1, 1 } },
						life = { 0.5, 0.8 },
						speed = { height * 1.1, height * 1.8 },
						spread = 3,
						face = "along",
						bright = 1.5,
					},
					22,
				},
				{
					{
						-- (the base flares white-hot: the brightest thing in it)
						tex = "VfxShock",
						ramp = hot,
						size = C.size("VfxShock", r * 5, { { 0, r }, { 0.3, r * 5 }, { 1, r * 5.5 } }),
						alpha = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } },
						life = 0.6,
						face = "flat",
						speed = 0.001,
						bright = 2.3,
						z = 2,
					},
					1,
				},
			}, nil, box)
			-- the column: a white-hot core, the body, and a dark shell laid over (it is not added)
			local grow = { seconds = 0.16, hold = seconds, fade = 0.5, ease = Ease.outExpo }
			Shape.grow("tube", at, {
				size = r * 0.7,
				height = height,
				seconds = grow.seconds,
				hold = grow.hold,
				fade = grow.fade,
				ease = grow.ease,
				color = ramp[1],
				transparency = 0.1,
			})
			Shape.grow("tube", at, {
				size = r * 2,
				height = height,
				seconds = grow.seconds + 0.04,
				hold = grow.hold,
				fade = grow.fade,
				ease = grow.ease,
				color = ramp[2],
				transparency = 0.55,
			})
			Shape.grow("tube", at, {
				size = r * 2.8,
				height = height,
				seconds = grow.seconds + 0.08,
				hold = grow.hold,
				fade = grow.fade,
				ease = grow.ease,
				color = shade[1],
				material = Enum.Material.SmoothPlastic,
				transparency = 0.72,
			})
			-- the light: up with the column, drawn back after it
			local holder = Emit.point(base + up * (height * 0.3))
			local _, release = Light.hold(holder, ramp[2], height * 1.6, 3.2, 0.15)
			Clock.after(seconds, function()
				release(0.5)
				Clock.after(0.8, function()
					holder:Destroy()
				end)
			end)
		end,
		body = function()
			-- rings lift off the column and fade, the top ones first
			for k = 1, 3 do
				Clock.after((k - 1) * 0.15, function()
					Shape.grow("ring", at * CFrame.new(0, 0.3, 0), {
						size = r * 2.6,
						seconds = 0.2,
						hold = 0.4,
						fade = 0.6,
						rise = height * (0.5 + 0.15 * k),
						color = ramp[1],
						transparency = 0.5,
					})
				end)
			end
			-- sparks rise from the foot while it stands
			local foot = Emit.point(at, Vector3.new(r * 2.2, 0.1, r * 2.2))
			local _, stop = Emit.hold(foot, {
				tex = "VfxSparks",
				ramp = hot,
				size = { { 0, 0.4 }, { 1, 0.1 } },
				alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
				life = { 0.9, 1.6 },
				speed = { 6, 14 },
				spread = 10,
				face = "along",
				rate = 24,
				bright = 1.4,
			})
			Clock.after(seconds, function()
				stop()
				Clock.after(2.2, function()
					foot:Destroy()
				end)
			end)
		end,
		residue = function()
			Ground.mark(base, up, "VfxScorch", r * 4, Color3.fromRGB(150, 150, 155), 2.6, { fadeOut = 1.5 })
			Emit.burst(at, {
				{
					{
						-- (the one small mark that keeps glowing after the column has gone)
						tex = "VfxShock",
						ramp = ramp,
						size = C.size("VfxShock", r * 1.6, { { 0, r }, { 1, r * 1.6 } }),
						alpha = { { 0, 1 }, { 0.3, 0.4 }, { 0.8, 0.5 }, { 1, 1 } },
						life = 2.4,
						face = "flat",
						speed = 0.001,
						bright = 1.2,
					},
					1,
				},
				{
					{
						tex = "VfxSmokePuff",
						ramp = shade,
						size = C.size("VfxSmokePuff", r * 2.8, { { 0, r }, { 1, r * 3 } }),
						alpha = { { 0, 1 }, { 0.2, 0.55 }, { 0.7, 0.7 }, { 1, 1 } },
						life = 2.2,
						accel = Vector3.new(0, 1.2, 0),
						light = 0,
						lit = 0.2,
						z = -1,
					},
					1,
				},
				{
					{
						tex = "VfxSparks",
						ramp = ramp,
						size = { { 0, 0.3 }, { 1, 0.08 } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.3 }, { 1, 1 } },
						life = { 1.6, 2.2 },
						speed = { 0.5, 2 },
						spread = 60,
						accel = Vector3.new(0, -1.5, 0),
						face = "along",
						bright = 1.3,
					},
					4,
				},
			})
		end,
	})
end

export type ArcOptions = {
	ramp: Palette.Ramp?,
	seconds: number?, -- the strokes jump about for this long (0.35)
	jag: number?, -- how far the kinks swing out (a tenth of the length)
	shake: boolean?,
	lead: number?,
}

-- Lightning from `from` to `to`.
function Shine.arc(from: Vector3, to: Vector3, options: ArcOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local seconds = o.seconds or 0.35
	local lead = o.lead or 0.2
	local len = (to - from).Magnitude
	if len < 0.5 then
		return function() end
	end
	local mid = from:Lerp(to, 0.5)
	local along = CFrame.lookAt(mid, to)
	local jag = o.jag or len * 0.1
	-- the arcs: random cells of the arc sheet strung along the line, drawn anew each time the stroke jumps
	local function strokes()
		Emit.burst(along, {
			tex = "VfxArc",
			ramp = hot,
			size = { { 0, math.clamp(len * 0.35, 2, 10) }, { 1, math.clamp(len * 0.35, 2, 10) } },
			alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
			life = { 0.09, 0.14 },
			speed = 0.001,
			dir = Enum.NormalId.Front,
			face = "along",
			bright = 2,
			z = 2,
		}, 5, Vector3.new(0.3, 0.3, len))
	end
	return Moment.play(mid, {
		lead = lead,
		gather = function()
			C.gather(from, ramp, 1.2, lead, 6, 0.3)
			-- (a small bright ball that shrinks to a point as it lets go)
			Emit.burst(from, {
				tex = "VfxGlint",
				ramp = hot,
				size = C.size("VfxGlint", 2.2, { { 0, 2.2 }, { 1, 0.4 } }),
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.55,
				bright = 2,
			}, 1)
		end,
		hit = function()
			-- a white-hot stroke inside a coloured one
			Beams.bolt(from, to, seconds, {
				color = ramp[1],
				width = 0.45,
				bright = 2.3,
				pieces = 4,
				jag = jag,
				rate = 20,
				z = 2,
			})
			Beams.bolt(
				from,
				to,
				seconds,
				{ color = ramp[2], width = 1.1, bright = 1, pieces = 4, jag = jag, rate = 20 }
			)
			strokes()
			C.beat(mid, ramp[1], math.max(18, len), 3.6, 0.04)
			if o.shake then
				Screen.shakeAt(to, 0.7, 0.3)
			end
		end,
		body = function()
			-- it jumps rather than glides: three more draws
			for k = 1, 3 do
				Clock.after(k * 0.07, strokes)
			end
			-- the dark layer: a puff of smoke where it lands, and a burn on the floor under it
			Emit.burst(to, {
				tex = "VfxSmokePuff",
				ramp = shade,
				size = C.size("VfxSmokePuff", 3.2, { { 0, 1.2 }, { 1, 3.6 } }),
				alpha = { { 0, 1 }, { 0.15, 0.5 }, { 0.7, 0.65 }, { 1, 1 } },
				life = { 2.1, 2.4 },
				accel = Vector3.new(0, 1.5, 0),
				light = 0,
				lit = 0.2,
				z = -1,
			}, 1)
			local floorAt, normal = Ground.at(to, nil, 6)
			if (to - floorAt).Magnitude < 6 then
				Ground.mark(floorAt, normal, "VfxScorch", 3.5, Color3.fromRGB(140, 140, 145), 2.4, { fadeOut = 1.4 })
			end
		end,
		residue = function()
			Emit.burst(to, {
				{
					{
						tex = "VfxSparks",
						ramp = ramp,
						size = { { 0, 0.4 }, { 1, 0.1 } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.3 }, { 1, 1 } },
						life = { 0.6, 1.2 },
						speed = { 2, 7 },
						spread = 140,
						accel = Vector3.new(0, -30, 0),
						face = "along",
						bright = 1.5,
					},
					5,
				},
				{
					{
						tex = "VfxSmokePlume",
						ramp = shade,
						size = { { 0, 0.5 }, { 1, 1.4 } },
						alpha = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } },
						life = 2.5,
						speed = 0.6,
						accel = Vector3.new(0, 1.3, 0),
						light = 0,
						lit = 0.2,
					},
					1,
				},
			})
		end,
	})
end
return Shine
