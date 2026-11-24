--!strict
-- Small accents for the emotes that fire on every beat or step (stage 4b, second batch): a tap (one contact: a star, a ring
-- and a handful of sparks, a dark halo and a light on the beat), a step of dust off a heel and a puff of spores off a foot.
-- They are the full recipes' smaller cousins: the same textures and the same five moments, but each call makes only the
-- emitters a beat that comes twice a second can afford (the full impact would pile up past the budget).
--
--   tap       a four-point star on the contact, a shock ring (flat on the floor when told), sparks thrown, a dark halo behind
--   stepDust  a roll of dust thrown back off a landing heel, a flat ring, a scuff of sparks and a flash of the heel
--   spores    a small soft puff lit from above, a glint, specks lifting off slowly, a dark layer under it

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Small = {}

export type TapOptions = {
	ramp: Palette.Ramp?,
	scale: number?,
	flat: boolean?, -- the ring lies on the floor (the CFrame's up is the floor's)
	sparks: number?, -- how many sparks are thrown (7)
	gather: boolean?, -- a few specks drawn in first (off)
	light: boolean?, -- a light on the beat (on)
	lite: boolean?, -- only the star and the sparks, no ring and no dark halo (off)
	lead: number?,
}

-- One contact at `at` (a CFrame, or a point).
function Small.tap(at: CFrame | Vector3, options: TapOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.06
	local frame = C.frame(at)
	local pos = frame.Position
	return Moment.play(frame, {
		lead = lead,
		gather = if o.gather == true
			then function()
				C.gather(pos, ramp, 1 * s, lead, 4, 0.25 * s)
			end
			else nil,
		hit = function()
			local list: { any } = {
				{
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 2.2 * s, { { 0, 0 }, { 0.35, 2.2 * s }, { 1, 0 } }),
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
						tex = "VfxShock",
						ramp = ramp,
						size = C.size("VfxShock", 2.4 * s, { { 0, 0.8 * s }, { 0.5, 2.2 * s }, { 1, 2.4 * s } }),
						alpha = { { 0, 0.65 }, { 0.5, 0.75 }, { 1, 1 } },
						life = 0.45,
						face = if o.flat == true then "flat" else nil,
						speed = if o.flat == true then 0.001 else nil,
						bright = 0.9,
						z = 1,
					},
					1,
				},
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.5 * s }, { 1, 0.1 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
						life = { 0.3, 0.6 },
						speed = { 9 * s, 20 * s },
						drag = 3,
						accel = Vector3.new(0, -30 * s, 0),
						spread = if o.flat == true then 70 else 170,
						face = "along",
						bright = 1.5,
					},
					o.sparks or 7,
				},
				{
					{
						-- (the dark halo behind: laid over, so the star reads on a lit floor too)
						tex = "VfxMist",
						ramp = shade,
						size = { { 0, 1.2 * s }, { 1, 1.8 * s } },
						alpha = { { 0, 1 }, { 0.25, 0.6 }, { 0.8, 0.75 }, { 1, 1 } },
						life = 1,
						light = 0,
						z = -1,
					},
					1,
				},
			}
			if o.lite == true then
				table.remove(list, 4)
				table.remove(list, 2)
			end
			Emit.burst(frame, list)
			if o.light ~= false then
				C.beat(pos, ramp[1], 7 * s, 1.5 * s, 0.04)
			end
		end,
	})
end

export type StepOptions = {
	ramp: Palette.Ramp?, -- the dust (the world's dust by default)
	scale: number?,
	dir: Vector3?, -- the way it rolls (back along the walk)
	lead: number?,
}

-- A step of dust at `at` (the floor under the heel; its up the floor's), thrown the way `dir` points.
function Small.stepDust(at: CFrame, options: StepOptions?): () -> ()
	local o = options or {}
	local ramp = o.ramp or Palette.WORLD.dust
	local hot = C.hotter(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.04
	local pos = at.Position
	local up = at.UpVector
	local way = o.dir or -at.LookVector
	way = way - up * way:Dot(up)
	way = if way.Magnitude > 0.01 then way.Unit else -at.LookVector
	local along = CFrame.lookAt(pos, pos + way)
	return Moment.play(at, {
		lead = lead,
		hit = function()
			Emit.burst(along, {
				{
					{
						-- (the roll: a low wave of dust thrown back along the floor, lit from above)
						tex = "VfxDustRoll",
						ramp = ramp,
						size = C.size("VfxDustRoll", 3.2 * s, { { 0, 1.4 * s }, { 1, 3.4 * s } }),
						alpha = { { 0, 1 }, { 0.1, 0.35 }, { 0.7, 0.55 }, { 1, 1 } },
						life = { 2.1, 2.3 },
						speed = { 1.5 * s, 3.5 * s },
						drag = 1.8,
						spread = 10,
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
						tex = "VfxShock",
						ramp = ramp,
						size = C.size("VfxShock", 1.8 * s, { { 0, 0.5 * s }, { 0.5, 1.6 * s }, { 1, 1.8 * s } }),
						alpha = { { 0, 0.7 }, { 0.5, 0.8 }, { 1, 1 } },
						life = 0.4,
						face = "flat",
						speed = 0.001,
						bright = 0.8,
						z = 1,
					},
					1,
				},
				{
					{
						-- (the heel's own flash: the white-hot core of the step)
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.2 * s, { { 0, 0 }, { 0.3, 1.2 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						bright = 2.3,
						z = 2,
					},
					1,
				},
				{
					{
						-- (a scuff of sparks where the heel struck)
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.4 * s }, { 1, 0.08 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.25 }, { 1, 1 } },
						life = { 0.25, 0.5 },
						speed = { 5 * s, 11 * s },
						drag = 3,
						accel = Vector3.new(0, -26 * s, 0),
						spread = 60,
						face = "along",
						bright = 1.4,
					},
					4,
				},
			})
			C.beat(pos + up * 0.3, ramp[1], 5 * s, 0.7 * s, 0.04)
		end,
	})
end

export type SporeOptions = {
	ramp: Palette.Ramp?,
	scale: number?,
	lead: number?,
}

-- A puff of spores at `at` (where a foot came down).
function Small.spores(at: CFrame | Vector3, options: SporeOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.04
	local frame = C.frame(at)
	local pos = frame.Position
	return Moment.play(frame, {
		lead = lead,
		hit = function()
			Emit.burst(pos, {
				{
					{
						tex = "VfxSmokePuff",
						ramp = ramp,
						size = C.size("VfxSmokePuff", 2.6 * s, { { 0, 0.8 * s }, { 0.3, 2.2 * s }, { 1, 2.8 * s } }),
						alpha = { { 0, 1 }, { 0.12, 0.2 }, { 0.7, 0.4 }, { 1, 1 } },
						life = { 2.1, 2.3 },
						speed = { 0.3, 0.8 },
						accel = Vector3.new(0, 0.9, 0),
						drag = 1.1,
						rot = { 0, 360 },
						light = 0.4,
						lit = 0.6,
						z = 1,
					},
					1,
				},
				{
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1 * s, { { 0, 0 }, { 0.3, 1 * s }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.55,
						bright = 2,
						z = 2,
					},
					1,
				},
				{
					{
						-- (the spores: tiny pale specks lifting off, each wandering its own way)
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.45 * s }, { 1, 0.15 * s } },
						alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.75, 0.3 }, { 1, 1 } },
						life = { 1.4, 2.2 },
						speed = { 0.6, 1.6 },
						spread = 70,
						accel = Vector3.new(0, 0.7, 0),
						drag = 1.2,
						rot = { 0, 360 },
						bright = 1.2,
					},
					7,
				},
				{
					{
						-- (the dark layer under the puff: laid over, never added)
						-- (a short-lived mist, not the long puff sheet: a step comes every half second)
						tex = "VfxMist",
						ramp = shade,
						size = { { 0, 1.6 * s }, { 1, 2.4 * s } },
						alpha = { { 0, 1 }, { 0.25, 0.6 }, { 0.8, 0.75 }, { 1, 1 } },
						life = 1.3,
						speed = { 0.1, 0.4 },
						accel = Vector3.new(0, 0.5, 0),
						light = 0,
						lit = 0.2,
						z = -1,
					},
					1,
				},
			})
			C.beat(pos, ramp[1], 5 * s, 0.7 * s, 0.05)
		end,
	})
end

export type Loop = {
	stop: () -> (), -- it makes no more; the last of it thins away
	destroy: () -> (), -- gone at once
}

-- Layers held on `parent` (a part or attachment) at their rates, fed by hand a few times a second so they also show in the
-- booth's stills and hold with the kit's clock. `specs` are Emit specs with a `rate` (particles a second at 100%).
function Small.loop(parent: Instance, specs: { { [string]: any } }): Loop
	local feed: { { e: ParticleEmitter, per: number, owed: number } } = {}
	for _, spec in ipairs(specs) do
		local copy = table.clone(spec)
		local rate = (copy.rate :: number?) or 0
		copy.rate = nil
		table.insert(feed, { e = Emit.make(parent, copy), per = rate, owed = 0 })
	end
	local stopped = false
	local stopFeed = Clock.every(function(dt: number): boolean?
		if stopped then
			return false
		end
		for _, one in ipairs(feed) do
			one.owed += one.per * dt * Emit.share()
			local n = math.floor(one.owed)
			if n > 0 then
				one.owed -= n
				one.e:Emit(n)
			end
		end
		return true
	end)
	return {
		stop = function()
			stopped = true
			stopFeed()
		end,
		destroy = function()
			stopped = true
			stopFeed()
			for _, one in ipairs(feed) do
				one.e:Destroy()
			end
		end,
	}
end

-- The dark and white-hot versions of a ramp (for callers that build their own layers).
Small.shadow = C.shadow
Small.hotter = C.hotter

return Small
