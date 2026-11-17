--!strict
-- Smoke puff, dust kick and mist (the plan's V2.5, against art/refs/vfx/smoke_dust.toml): matter, laid over the scene (light 0,
-- lit by it), lit from above with a dark belly, rising and slowing, outliving the hit by a second or two as a faint haze.
-- The 8 x 8 one-shot sheets (VfxSmokePuff, VfxDustRoll) hold 64 frames and the flipbook rate caps at 30, so their particles
-- live two seconds or more.
--
--   smokePuff   a billow from a point: a spark of fire at its heart, a dark billow behind, a wisp climbing, a thin haze left
--   dustKick    dust thrown along the floor by a foot or a blow: a roll, chips, a scuff of sparks, a darker roll under it
--   mist        a bank of fog that rolls in, never repeats visibly, and is let go

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Smoke = {}

export type PuffOptions = {
	ramp: Palette.Ramp?, -- the smoke's colours (the world's smoke by default)
	scale: number?,
	rise: number?, -- how hard it climbs
	lead: number?,
}

function Smoke.smokePuff(at: CFrame | Vector3, options: PuffOptions?): () -> ()
	local o = options or {}
	local ramp = o.ramp or Palette.WORLD.smoke
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local rise = o.rise or 2.2
	local lead = o.lead or 0.12
	local pos = C.position(at)
	return Moment.play(at, {
		lead = lead,
		gather = function()
			C.gather(pos, ramp, 1.2 * s, lead, 4, 0.3 * s)
		end,
		hit = function()
			Emit.burst(pos, {
				{
					{
						tex = "VfxSmokePuff",
						ramp = ramp,
						size = C.size("VfxSmokePuff", 5 * s, { { 0, 1.5 * s }, { 0.3, 4 * s }, { 1, 6 * s } }),
						alpha = { { 0, 1 }, { 0.12, 0.25 }, { 0.7, 0.45 }, { 1, 1 } },
						life = { 2.1, 2.4 },
						speed = { 0.5, 1.2 },
						accel = Vector3.new(0, rise, 0),
						drag = 1.1,
						rot = { 0, 360 },
						light = 0,
						lit = 0.55,
						z = 1,
					},
					1,
				},
				{
					{
						-- (the spark at its heart: the one bright thing, gone in a blink)
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.6 * s, { { 0, 0 }, { 0.3, 1.6 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						bright = 2.3,
						z = 2,
					},
					1,
				},
			})
		end,
		body = function()
			Emit.burst(pos, {
				{
					{
						-- (the dark billow behind: laid over)
						tex = "VfxSmokePuff",
						ramp = shade,
						size = C.size("VfxSmokePuff", 6.4 * s, { { 0, 2 * s }, { 0.3, 5 * s }, { 1, 7.5 * s } }),
						alpha = { { 0, 1 }, { 0.2, 0.55 }, { 0.7, 0.7 }, { 1, 1 } },
						life = { 2.2, 2.5 },
						speed = { 0.3, 0.8 },
						accel = Vector3.new(0, rise * 0.8, 0),
						drag = 1,
						rot = { 0, 360 },
						light = 0,
						lit = 0.2,
						z = 0,
					},
					1,
				},
				{
					{
						-- (a wisp climbing: smoke starts as a thin fast stem, then rolls over)
						tex = "VfxSmokePlume",
						ramp = ramp,
						size = { { 0, 0.5 * s }, { 1, 2.2 * s } },
						alpha = { { 0, 1 }, { 0.2, 0.55 }, { 0.7, 0.75 }, { 1, 1 } },
						life = { 2.2, 2.6 },
						speed = { 1, 2.5 },
						accel = Vector3.new(0, rise, 0),
						drag = 0.9,
						light = 0,
						lit = 0.5,
					},
					2,
				},
			})
		end,
		residue = function()
			Emit.burst(pos + Vector3.new(0, 1.2 * s, 0), {
				{
					{
						tex = "VfxMist",
						ramp = ramp,
						size = { { 0, 5 * s }, { 1, 7 * s } },
						alpha = { { 0, 1 }, { 0.3, 0.8 }, { 0.8, 0.85 }, { 1, 1 } },
						life = 3.2,
						speed = 0.4,
						accel = Vector3.new(0, 0.5, 0),
						light = 0,
						lit = 0.4,
						z = -1,
					},
					1,
				},
				{
					{
						tex = "VfxSmokePlume",
						ramp = shade,
						size = { { 0, 0.5 * s }, { 1, 1.4 * s } },
						alpha = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } },
						life = 2.6,
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

export type KickOptions = {
	ramp: Palette.Ramp?, -- the dust's colours (the world's dust by default)
	scale: number?,
	dir: Vector3?, -- the way it rolls (the CFrame's look by default)
	lead: number?,
}

-- Dust thrown along the floor at `at` (its up the floor's), rolling out the way `dir` points.
function Smoke.dustKick(at: CFrame, options: KickOptions?): () -> ()
	local o = options or {}
	local ramp = o.ramp or Palette.WORLD.dust
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.1
	local pos = at.Position
	local up = at.UpVector
	local way = o.dir or at.LookVector
	way = way - up * way:Dot(up)
	way = if way.Magnitude > 0.01 then way.Unit else at.LookVector
	local along = CFrame.lookAt(pos, pos + way)
	return Moment.play(at, {
		lead = lead,
		gather = function()
			C.gather(pos, ramp, 1.2 * s, lead, 5, 0.35 * s)
		end,
		hit = function()
			Emit.burst(along, {
				{
					{
						tex = "VfxDustRoll",
						ramp = ramp,
						size = C.size("VfxDustRoll", 6 * s, { { 0, 2.5 * s }, { 1, 6.5 * s } }),
						alpha = { { 0, 1 }, { 0.1, 0.3 }, { 0.7, 0.5 }, { 1, 1 } },
						life = { 2.1, 2.4 },
						speed = { 3 * s, 7 * s },
						drag = 1.6,
						spread = 8,
						dir = Enum.NormalId.Front,
						face = "up",
						light = 0,
						lit = 0.55,
						z = 1,
					},
					1,
				},
				{
					{
						-- (a scuff of sparks where stone met stone)
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.4 * s, { { 0, 0 }, { 0.3, 1.4 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						bright = 2.3,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxShards",
						ramp = ramp,
						size = { { 0, 0.35 * s, 0.15 * s }, { 1, 0.3 * s, 0.12 * s } },
						alpha = { { 0, 0 }, { 0.7, 0 }, { 1, 1 } },
						life = { 0.5, 0.9 },
						speed = { 6 * s, 14 * s },
						accel = Vector3.new(0, -40 * s, 0),
						spread = 22,
						dir = Enum.NormalId.Front,
						spin = { -300, 300 },
						rot = { 0, 360 },
						light = 0,
						lit = 0.6,
					},
					6,
				},
			})
		end,
		body = function()
			Emit.burst(along, {
				tex = "VfxDustRoll",
				ramp = shade,
				size = C.size("VfxDustRoll", 7.5 * s, { { 0, 3 * s }, { 1, 8 * s } }),
				alpha = { { 0, 1 }, { 0.15, 0.55 }, { 0.7, 0.7 }, { 1, 1 } },
				life = { 2.2, 2.5 },
				speed = { 2 * s, 4 * s },
				drag = 1.4,
				spread = 10,
				dir = Enum.NormalId.Front,
				face = "up",
				light = 0,
				lit = 0.1,
				z = -1,
			}, 1)
		end,
		residue = function()
			Emit.burst(pos + up * 0.8 * s, {
				{
					{
						tex = "VfxMist",
						ramp = ramp,
						size = { { 0, 5 * s }, { 1, 7 * s } },
						alpha = { { 0, 1 }, { 0.3, 0.8 }, { 0.8, 0.85 }, { 1, 1 } },
						life = 3,
						speed = 0.4,
						light = 0,
						lit = 0.5,
						z = -1,
					},
					1,
				},
			})
		end,
	})
end

export type MistOptions = {
	ramp: Palette.Ramp?, -- the fog's colours (the world's smoke by default)
	size: number?, -- studs across the bank
	density: number?, -- how thick (1)
}

export type Mist = {
	stop: () -> (), -- let it go: it makes no more and the last of it thins away
	destroy: () -> (), -- gone at once
}

-- A bank of fog over the floor at `at`. It fills in over a moment, then drifts without a visible repeat until stopped.
function Smoke.mist(at: CFrame | Vector3, options: MistOptions?): Mist
	local o = options or {}
	local ramp = o.ramp or Palette.WORLD.smoke
	local shade = C.shadow(ramp)
	local size = o.size or 8
	local d = o.density or 1
	local frame = C.frame(at)
	local holder = Emit.point(frame, Vector3.new(size, 0.2, size))
	local specs: { { [string]: any } } = {
		{
			tex = "VfxMist",
			ramp = ramp,
			size = { { 0, size * 0.9 }, { 1, size * 1.2 } },
			alpha = { { 0, 1 }, { 0.25, 0.72 }, { 0.75, 0.72 }, { 1, 1 } },
			life = { 8, 10 },
			speed = { 0.2, 0.8 },
			spread = 180,
			rot = { 0, 360 },
			spin = if C.still() then 0 else { -4, 4 },
			rate = 0.9 * d,
			light = 0,
			lit = 0.5,
		},
		{
			-- (the dark layer: a slower, deeper bank behind)
			tex = "VfxMist",
			ramp = shade,
			size = { { 0, size }, { 1, size * 1.3 } },
			alpha = { { 0, 1 }, { 0.3, 0.82 }, { 0.75, 0.84 }, { 1, 1 } },
			life = { 10, 12 },
			speed = { 0.1, 0.5 },
			spread = 180,
			rot = { 0, 360 },
			rate = 0.45 * d,
			light = 0,
			lit = 0.1,
			z = -1,
		},
		{
			-- (a bank lying on the floor: its picture flat)
			tex = "VfxMist",
			ramp = ramp,
			size = size * 1.3,
			alpha = { { 0, 1 }, { 0.3, 0.8 }, { 0.8, 0.82 }, { 1, 1 } },
			life = 9,
			speed = 0.001,
			face = "flat",
			rot = { 0, 360 },
			rate = 0.5 * d,
			light = 0,
			lit = 0.5,
			z = -0.5,
		},
		{
			-- (motes of dust turning in it)
			tex = "VfxAshFlakes",
			ramp = ramp,
			size = { { 0, 0.25 }, { 1, 0.2 } },
			alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.3 }, { 1, 1 } },
			life = 6,
			speed = { 0.3, 1 },
			spread = 180,
			accel = Vector3.new(0, 0.15, 0),
			rot = { 0, 360 },
			rate = 1,
			light = 0,
			lit = 0.6,
		},
	}
	local made: { ParticleEmitter } = {}
	local stopped = false
	local cancel = Moment.play(frame, {
		lead = 0.3,
		hit = function()
			-- the bank rolls in: a first fill, then the held emitters
			Emit.burst(frame, { { specs[1], 3 }, { specs[3], 1 } } :: any, nil, Vector3.new(size, 0.2, size))
		end,
		body = function()
			if stopped then
				return
			end
			for _, spec in ipairs(specs) do
				local e = Emit.make(holder, spec)
				e.Enabled = true
				table.insert(made, e)
			end
		end,
	})
	local function longest(): number
		local most = 0
		for _, spec in ipairs(specs) do
			most = math.max(most, Emit.longest(spec))
		end
		return most
	end
	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			cancel()
			for _, e in ipairs(made) do
				e.Enabled = false
			end
			Clock.after(longest() + 0.25, function()
				holder:Destroy()
			end)
		end,
		destroy = function()
			stopped = true
			cancel()
			holder:Destroy()
		end,
	}
end

return Smoke
