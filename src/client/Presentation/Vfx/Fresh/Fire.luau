--!strict
-- Flame and fire burst (the plan's V2.5, against art/refs/vfx/fire_candle.toml).
--
-- flame: a loop with an ignition (a glow at the wick, a flare, then the tongues), a steady state that never repeats (a long
-- flipbook of tongues, a smaller white-hot one inside it, sparks that wander, a dark thread of soot rising), and an ending
-- (`out`: it balloons, shrinks away, and leaves a glowing wick dot and a thin smoke thread for two seconds). The handle has
-- the old Recipes.flame's shape: set, flare, out, destroy.
--
-- fireBurst: a four-point flare gathers it, the ball of fire opens (the sheet) with a white-hot core, sparks fly, the ball
-- goes to dark smoke that climbs, and embers fall and a thread of smoke is left, with a scorch if it was on the floor.

local Clock = require(script.Parent.Parent.Clock)
local Ease = require(script.Parent.Parent.Ease)
local Emit = require(script.Parent.Parent.Emit)
local Ground = require(script.Parent.Parent.Ground)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Fire = {}

export type Flame = {
	set: (scale: number, seconds: number?) -> (), -- grow or shrink to `scale` of its size (from nothing: it is lit)
	flare: (on: boolean) -> (), -- burn taller and brighter (a countdown), or calm again
	out: () -> (), -- go out: balloon, shrink, a glowing wick dot and a thread of smoke
	destroy: () -> (), -- gone at once
}

export type FlameOptions = {
	kind: string?, -- "candle" (the realm's pale candle flame), "fire" (a cold brazier fire) or "aura" (a drawn tongue)
	scale: number?, -- studs tall the flame stands
	ramp: Palette.Ramp?, -- the flame's colours (the candle's cream or the world's pale by default)
	light: boolean?, -- a flickering light (true)
	lit: boolean?, -- burning from the start (true), else out until set(1)
	plain: boolean?, -- the cheap world flame: only the body and the white-hot heart (no wandering sparks, no soot thread)
	lightRange: number?, -- the light's reach (the flame's own by default)
	lightBrightness: number?, -- the light's brightness at rest (the flame's own by default)
	lightColor: Color3?, -- the light's colour (the ramp's body by default)
}

local CANDLE = { Color3.new(1, 1, 1), Color3.fromRGB(238, 232, 214), Color3.fromRGB(120, 110, 92) } :: Palette.Ramp
local STEADY = 4

-- A flame on `parent` (a part or attachment at the wick; the flame stands up from it).
function Fire.flame(parent: Instance, options: FlameOptions?): Flame
	local o = options or {}
	local kind = o.kind or "candle"
	local candle, aura = kind == "candle", kind == "aura"
	local height = o.scale or (if candle then 0.55 elseif aura then 2.4 else 3)
	local ramp = o.ramp or (if candle then CANDLE else Palette.WORLD.pale)
	local tex = if candle then "VfxCandle" elseif aura then "VfxAuraFlame" else "VfxFire"
	local size = height * 1.45 -- (the flame fills about 70 % of its square's height)
	local scale = 0
	local flaring = false
	-- (the particles' middle sits a third of their square up from the wick; an attachment given as the wick lends its part)
	local holder = Instance.new("Attachment")
	holder.Name = "DGVfxFlame"
	local lift = CFrame.new(0, size * 0.33, 0)
	if parent:IsA("Attachment") then
		holder.CFrame = parent.CFrame * lift
		holder.Parent = parent.Parent
	else
		holder.CFrame = lift
		holder.Parent = parent
	end
	local others: { Attachment } = {}
	local function attachmentAt(offset: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "DGVfxFlame"
		a.CFrame = holder.CFrame * CFrame.new(offset)
		a.Parent = holder.Parent
		table.insert(others, a)
		return a
	end
	local emitters: { { e: ParticleEmitter, sizes: NumberSequence, steady: boolean } } = {}
	local function add(at: Attachment, spec: { [string]: any }, steady: boolean)
		local e = Emit.make(at, spec)
		e.Enabled = false
		table.insert(emitters, { e = e, sizes = e.Size, steady = steady })
	end
	-- One long-lived particle at a time, the next fading in over the last's fading out: its flipbook is the flicker.
	local function steady(spec: { [string]: any }): { [string]: any }
		spec.life = STEADY
		spec.rate = 1 / (STEADY * 0.95)
		spec.alpha = { { 0, 1 }, { 0.05, 0 }, { 0.95, 0 }, { 1, 1 } }
		return spec
	end
	-- the body of the flame, in the ramp's body colour (the texture carries the cream core and the darker rim)
	add(
		holder,
		steady({
			tex = tex,
			color = ramp[2],
			size = size,
			face = "up",
			locked = true,
			bright = 1.15,
			z = 0.2,
		}),
		true
	)
	-- the white-hot heart, a smaller tongue low inside it: the brightest thing in the flame
	add(
		attachmentAt(Vector3.new(0, -size * 0.1, 0)),
		steady({
			tex = tex,
			color = ramp[1],
			size = size * 0.5,
			face = "up",
			locked = true,
			bright = 2.3,
			z = 0.4,
		}),
		true
	)
	-- A world flame (`plain`) is seen all the time and keeps to the two layers above: its cost is the first thing it must meet.
	if not o.plain then
		-- sparks that wander up and out
		local bit = math.clamp(height * 0.18, 0.1, 0.6)
		add(holder, {
			tex = "VfxSparks",
			ramp = C.hotter(ramp),
			size = { { 0, bit }, { 1, bit * 0.25 } },
			alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
			life = { 1, 2 },
			speed = { height * 0.4, height * 1.1 },
			spread = 25,
			accel = Vector3.new(0, height * 0.5, 0),
			drag = 1,
			face = "along",
			rate = 1.6,
			bright = 1.6,
		}, false)
		-- the dark layer: a thread of soot standing up from the tip (laid over, so the flame still reads in a lit room)
		add(attachmentAt(Vector3.new(0, size * 0.5, 0)), {
			tex = "VfxSmokePlume",
			ramp = C.shadow(ramp),
			size = { { 0, height * 0.35 }, { 1, height * 1.2 } },
			alpha = { { 0, 1 }, { 0.25, 0.78 }, { 0.75, 0.85 }, { 1, 1 } },
			life = 3.6,
			speed = { height * 0.15, height * 0.3 },
			accel = Vector3.new(0, height * 0.3, 0),
			rate = 1.1,
			light = 0,
			lit = 0.2,
			z = -1,
		}, false)
	end

	local light: PointLight? = nil
	local stopFlicker: (() -> ())? = nil
	local brightness = o.lightBrightness or (if candle then 1.1 else 1.8)
	local range = o.lightRange or math.clamp(height * 9, 5, 30)
	if o.light ~= false then
		local l = Light.hold(holder, o.lightColor or ramp[2], range, 0, 0.3)
		light = l
	end
	local function wick(): Vector3
		return holder.WorldPosition - Vector3.new(0, size * 0.33, 0)
	end
	local function apply()
		local k = scale * (if flaring then 1.35 else 1)
		for _, entry in ipairs(emitters) do
			local on = scale > 0.02
			if on and not entry.e.Enabled and entry.steady then
				entry.e:Emit(1)
			elseif not on and entry.e.Enabled and entry.steady then
				entry.e:Clear()
			end
			entry.e.Enabled = on
			-- (a uniform size: the whole sequence as made, scaled; live particles take it at once)
			local keys = {}
			for _, p in ipairs(entry.sizes.Keypoints) do
				table.insert(keys, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
			end
			entry.e.Size = NumberSequence.new(keys)
		end
		if stopFlicker then
			stopFlicker()
			stopFlicker = nil
		end
		local l = light
		if l then
			if scale > 0.02 then
				stopFlicker = Light.flicker(
					l,
					brightness * k * (if flaring then 1.6 else 1),
					range * (if flaring then 1.4 else 1),
					0.18
				)
			else
				l.Brightness = 0
			end
		end
	end
	local tweening: (() -> ())? = nil
	local ignite: (seconds: number) -> ()
	-- The ignition: a glow at the wick (gather), a flare as it catches (hit), then the tongues (body).
	ignite = function(seconds: number)
		local origin = wick()
		Moment.play(origin, {
			lead = 0.3,
			gather = function()
				Emit.burst(origin, {
					tex = "VfxEmber",
					ramp = C.hotter(ramp),
					size = { { 0, 0.05 + height * 0.04 }, { 1, 0.02 } },
					alpha = { { 0, 1 }, { 0.3, 0.1 }, { 1, 1 } },
					life = 0.5,
					speed = 0,
					bright = 2,
				}, 1)
			end,
			hit = function()
				Emit.burst(origin + Vector3.new(0, size * 0.3, 0), {
					tex = "VfxGlint",
					ramp = C.hotter(ramp),
					size = C.size("VfxGlint", size * 1.1, { { 0, 0 }, { 0.3, size * 1.1 }, { 1, 0 } }),
					alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
					life = 0.55,
					rot = { -10, 10 },
					bright = 2.2,
				}, 1)
			end,
			body = function()
				if tweening then
					tweening()
				end
				scale = 0
				tweening = Clock.tween(seconds, Ease.outBack, function(u)
					scale = u
					apply()
				end)
			end,
		})
	end
	apply()
	if o.lit ~= false then
		ignite(0.35)
	end
	local flame: Flame
	flame = {
		set = function(target: number, seconds: number?)
			if tweening then
				tweening()
				tweening = nil
			end
			if scale <= 0.02 and target > 0.02 then
				ignite(seconds or 0.35)
				return
			end
			local from = scale
			tweening = Clock.tween(seconds or 0.35, if target > from then Ease.outBack else Ease.outQuad, function(u)
				scale = from + (target - from) * u
				apply()
			end)
		end,
		flare = function(on: boolean)
			if flaring ~= on then
				flaring = on
				apply()
			end
		end,
		out = function()
			if scale <= 0.02 then
				return
			end
			if tweening then
				tweening()
			end
			local at = wick()
			local from = scale
			-- it balloons for a beat, then shrinks away (the real flame goes in about a second and a half)
			tweening = Clock.tween(0.5, nil, function(u)
				local k = if u < 0.3
					then 1 + 0.35 * Ease.outQuad(u / 0.3)
					else 1.35 * (1 - Ease.inQuad((u - 0.3) / 0.7))
				scale = from * k
				apply()
			end, function()
				scale = 0
				apply()
			end)
			-- what a wick keeps for two seconds: a glowing dot, and a thread of smoke
			Clock.after(0.4, function()
				Emit.burst(at, {
					{
						{
							tex = "VfxEmber",
							ramp = C.hotter(ramp),
							size = { { 0, 0.04 + height * 0.05 }, { 1, 0.02 } },
							alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.3 }, { 1, 1 } },
							life = 2.2,
							speed = 0,
							bright = 2,
						},
						1,
					},
					{
						{
							tex = "VfxSmokePlume",
							ramp = C.shadow(ramp),
							size = { { 0, height * 0.3 }, { 1, height * 1.3 } },
							alpha = { { 0, 1 }, { 0.2, 0.7 }, { 1, 1 } },
							life = 2.6,
							speed = height * 0.2,
							accel = Vector3.new(0, height * 0.5, 0),
							light = 0,
							lit = 0.2,
						},
						1,
					},
				})
			end)
		end,
		destroy = function()
			if tweening then
				tweening()
			end
			if stopFlicker then
				stopFlicker()
			end
			holder:Destroy()
			for _, a in ipairs(others) do
				a:Destroy()
			end
		end,
	}
	return flame
end

export type BurstOptions = {
	ramp: Palette.Ramp?,
	scale: number?,
	ground: boolean?, -- on the floor: it leaves a scorch
	lead: number?,
}

-- A ball of fire at `at` (its up the surface's).
function Fire.fireBurst(at: CFrame, options: BurstOptions?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local lead = o.lead or 0.22
	local pos = at.Position
	return Moment.play(at, {
		lead = lead,
		gather = function()
			C.gather(pos, ramp, 2.6 * s, lead, 10, 0.5 * s)
			-- (the ref's four-point flare that gathers the fire)
			Emit.burst(pos, {
				tex = "VfxGlint",
				ramp = hot,
				size = C.size("VfxGlint", 3.4 * s, { { 0, 0 }, { 0.5, 3.4 * s }, { 1, 0 } }),
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.55,
				rot = { -10, 10 },
				bright = 1.8,
			}, 1)
		end,
		hit = function()
			Emit.burst(at, {
				{
					{
						tex = "VfxFireBurst",
						ramp = ramp,
						size = C.size("VfxFireBurst", 7 * s, { { 0, 3 * s }, { 0.2, 7 * s }, { 1, 8 * s } }),
						alpha = { { 0, 1 }, { 0.04, 0 }, { 0.6, 0.1 }, { 1, 1 } },
						life = 2,
						rot = { 0, 360 },
						bright = 1.1,
						z = 1,
					},
					1,
				},
				{
					{
						-- (the white-hot core: the smaller ball inside, the brightest layer)
						tex = "VfxFireBurst",
						ramp = hot,
						size = C.size("VfxFireBurst", 3.2 * s, { { 0, 1.4 * s }, { 0.2, 3.2 * s }, { 1, 3.8 * s } }),
						alpha = { { 0, 1 }, { 0.05, 0 }, { 0.5, 0.15 }, { 1, 1 } },
						life = 1.6,
						rot = { 0, 360 },
						bright = 2.3,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.7 * s }, { 1, 0.15 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
						life = { 0.35, 0.75 },
						speed = { 22 * s, 50 * s },
						drag = 3,
						accel = Vector3.new(0, -40 * s, 0),
						spread = 120,
						face = "along",
						bright = 1.5,
					},
					14,
				},
			})
			C.beat(pos + at.UpVector * 1, ramp[2], 30 * s, 4 * s, 0.06)
		end,
		body = function()
			Emit.burst(at, {
				{
					{
						-- (the fire goes to dark smoke that climbs: laid over, not added)
						tex = "VfxSmokePuff",
						ramp = shade,
						size = C.size("VfxSmokePuff", 6 * s, { { 0, 2.5 * s }, { 1, 7 * s } }),
						alpha = { { 0, 1 }, { 0.2, 0.5 }, { 0.7, 0.65 }, { 1, 1 } },
						life = { 2.1, 2.4 },
						accel = Vector3.new(0, 3, 0),
						drag = 0.8,
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
						size = { { 0, 0.5 * s }, { 1, 0.1 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.3 }, { 1, 1 } },
						life = { 1, 1.8 },
						speed = { 3 * s, 10 * s },
						spread = 180,
						accel = Vector3.new(0, -9, 0),
						drag = 1,
						face = "along",
						bright = 1.5,
					},
					8,
				},
			})
		end,
		residue = function()
			Emit.burst(at, {
				{
					{
						tex = "VfxSparks",
						ramp = ramp,
						size = { { 0, 0.3 * s }, { 1, 0.08 * s } },
						alpha = { { 0, 1 }, { 0.08, 0 }, { 0.6, 0.3 }, { 1, 1 } },
						life = { 2, 2.8 },
						speed = { 0.5, 2 },
						spread = 180,
						accel = Vector3.new(0, -1.5, 0),
						drag = 1.2,
						face = "along",
						bright = 1.4,
					},
					4,
				},
				{
					{
						tex = "VfxSmokePlume",
						ramp = shade,
						size = { { 0, 0.7 * s }, { 1, 1.8 * s } },
						alpha = { { 0, 1 }, { 0.2, 0.65 }, { 1, 1 } },
						life = 2.6,
						speed = 0.8,
						accel = Vector3.new(0, 1.5, 0),
						light = 0,
						lit = 0.2,
					},
					1,
				},
			})
			if o.ground then
				Ground.mark(pos, at.UpVector, "VfxScorch", 5 * s, Color3.fromRGB(150, 150, 155), 2.6, { fadeOut = 1.4 })
			end
		end,
	})
end

return Fire
