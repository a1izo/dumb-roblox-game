--!strict
-- The menace of a pose (the pilot's V3.2, against art/refs/vfx/aura.toml): the room's pressure. A loop's five moments:
--
--   gather   0.0 s   specks drawn in to the chest (the close-up before the power-up; 0.5 s)
--   hit      0.55 s  the release: a small star in the pose's colour, a white-hot glint at its core, a flat ring on the floor,
--                    a few sparks, one light (a violet-white release, not a white blob: the star is small)
--   body     0.6 s   a bank of fog climbing off the floor round the body, full colour, with a dark bank laid under it and
--                    motes turning in it; one soft light of the colour holds on it
--   break-up the bank thins as the emitters stop (no cut)
--   residue  the motes and the last of the fog drift 3 to 4 s after
--
-- With `lean` (under the level-2 aura, which has its own bank, specks, glint and light: stage 4b) it is the floor bank and the star
-- only (no motes, no ring), and holds no light of its own.
-- Twelve emitters and two lights at most (the showpiece budget, plan Part 9): four loop emitters, a gather, a star, a glint, a
-- ring and sparks at the release, and the beat's light plus the held one.

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Menace = {}

export type Options = {
	ramp: Palette.Ramp?, -- the pose's own colour (Palette.emote), full strength
	floor: number?, -- studs below the chest to the floor (2.8 by default)
	size: number?, -- the bank's width in studs
	lean: boolean?, -- under an aura (it has its own bank, specks, glint and light): only the floor bank and the star
}

export type Handle = {
	stop: () -> (), -- the pose ends: the bank thins away
	destroy: () -> (), -- gone now
}

-- A menace round the chest at `chest` (a point), standing on a floor `floor` studs lower.
function Menace.menace(chest: Vector3, options: Options?): Handle
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local width = o.size or 5.5
	local base = chest - Vector3.new(0, o.floor or 2.8, 0)
	local holder = Emit.point(base, Vector3.new(width, 0.2, width))
	local still = C.still()
	local specs: { { [string]: any } } = {
		{
			-- the bank that climbs: many middling puffs of the colour, full strength, lit from within
			tex = "VfxMist",
			ramp = ramp,
			size = { { 0, 3.2 }, { 1, 5.6 } },
			alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.7, 0.25 }, { 1, 1 } },
			life = { 2.6, 3.6 },
			speed = { 0.3, 0.9 },
			accel = Vector3.new(0, 1.3, 0),
			rot = { 0, 360 },
			spin = if still then 0 else { -10, 10 },
			rate = 5,
			light = 0.85,
			lit = 0.1,
			bright = 1.4,
		},
		{
			-- (the dark bank laid under it: it reads on a lit floor too)
			tex = "VfxMist",
			ramp = shade,
			size = { { 0, 3.6 }, { 1, 6 } },
			alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.75, 0.32 }, { 1, 1 } },
			life = { 3, 4 },
			speed = { 0.2, 0.6 },
			accel = Vector3.new(0, 0.9, 0),
			rot = { 0, 360 },
			rate = 3,
			light = 0,
			lit = 0.2,
			z = -1,
		},
		{
			-- (a bank lying on the floor, its picture flat)
			tex = "VfxMist",
			ramp = ramp,
			size = width * 1.1,
			alpha = { { 0, 1 }, { 0.3, 0.2 }, { 0.8, 0.3 }, { 1, 1 } },
			life = 4,
			speed = 0.001,
			face = "flat",
			rot = { 0, 360 },
			rate = 1,
			light = 0.75,
			lit = 0.15,
			z = -0.5,
		},
		{
			-- (motes of the colour turning in it)
			tex = "VfxAshFlakes",
			ramp = hot,
			size = { { 0, 0.5 }, { 1, 0.35 } },
			alpha = { { 0, 1 }, { 0.2, 0.15 }, { 0.8, 0.3 }, { 1, 1 } },
			life = { 3, 4 },
			speed = { 0.3, 1 },
			accel = Vector3.new(0, 0.5, 0),
			rot = { 0, 360 },
			rate = 4,
			light = 0.9,
			lit = 0.1,
		},
	}
	if o.lean then
		specs = { specs[3] }
	end
	local made: { ParticleEmitter } = {}
	local releaseLight: ((number?) -> ())? = nil
	local feedStop: (() -> ())? = nil
	local stopped = false
	local cancel = Moment.play(chest, {
		lead = 0.55,
		gather = function()
			if not o.lean then
				C.gather(chest, ramp, 2.6, 0.55, 14, 0.4)
			end
		end,
		hit = function()
			if stopped then
				return
			end
			local list: { any } = {
				{
					{
						tex = "VfxImpactC",
						ramp = hot,
						size = C.size("VfxImpactC", 3.4, { { 0, 1.6 }, { 0.2, 3.4 }, { 1, 3.8 } }),
						alpha = { { 0, 0 }, { 0.55, 0.1 }, { 1, 1 } },
						life = 0.6,
						rot = { 0, 360 },
						bright = 1.25,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxGlint",
						ramp = hot,
						size = C.size("VfxGlint", 1.4, { { 0, 0 }, { 0.3, 1.4 }, { 1, 0 } }),
						alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
						life = 0.3,
						bright = 2.1,
						z = 3,
					},
					1,
				},
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.5 }, { 1, 0.1 } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
						life = { 0.35, 0.7 },
						speed = { 10, 26 },
						drag = 3,
						spread = 180,
						face = "along",
						bright = 1.4,
					},
					10,
				},
			}
			if o.lean then
				table.remove(list, 3)
				table.remove(list, 2)
			end
			Emit.burst(chest, list)
			-- the ring lies on the floor
			Emit.burst(
				base,
				if o.lean
					then {}
					else {
						{
							{
								tex = "VfxShock",
								ramp = ramp,
								size = C.size("VfxShock", 7, { { 0, 2 }, { 0.5, 6 }, { 1, 7 } }),
								alpha = { { 0, 0.4 }, { 0.5, 0.6 }, { 1, 1 } },
								life = 0.5,
								face = "flat",
								speed = 0.001,
								bright = 0.9,
								z = 1,
							},
							1,
						},
					}
			)
			C.beat(chest, ramp[2], 16, 2.4, 0.04)
		end,
		body = function()
			if stopped then
				return
			end
			-- (the bank is fed by hand a few times a second, at each layer's rate: the same looks as a rate, and it also
			-- shows in the booth's stills and holds with the kit's clock)
			local feed: { { e: ParticleEmitter, per: number, owed: number } } = {}
			for _, spec in ipairs(specs) do
				local copy = table.clone(spec)
				local rate = (copy.rate :: number?) or 0
				copy.rate = nil
				local e = Emit.make(holder, copy)
				table.insert(made, e)
				table.insert(feed, { e = e, per = rate, owed = 0 })
			end
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
			feedStop = stopFeed
			if not o.lean then
				local _, release = Light.hold(holder, ramp[2], 12, 0.8, 1.2)
				releaseLight = release
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
			if releaseLight then
				releaseLight(1.2)
			end
			Clock.after(longest() + 0.25, function()
				holder:Destroy()
			end)
		end,
		destroy = function()
			stopped = true
			cancel()
			if feedStop then
				feedStop()
			end
			if releaseLight then
				releaseLight(0.1)
			end
			holder:Destroy()
		end,
	}
end

return Menace
