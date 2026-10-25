--!strict
-- The VFX kit's recipes: the effects the game's own effects are built from, each layered (a hot white core, a
-- coloured body, darker smoke or dust under it, sparks and specks flung off, light thrown on the scene, the camera
-- feeling it), timed on curves: fast in, slow out.
--
--   Recipes.impact(at, { color, scale, ground, shake, flash })   a hit: flare, burst, spikes, sparks, ring, dust
--   Recipes.slam(at, { color, scale })                           a landing: an impact on the floor, debris thrown up
--   Recipes.twinkle(at, { color, scale })                        a glint: a star that blooms and closes
--   Recipes.pillar(at, { color, height, radius, seconds })       a column of light out of the floor
--   Recipes.flame(parent, { kind, scale, color, light })         a living flame (candle or fire), with its light
--
-- `at` is a CFrame whose up is the surface's (the world's up for a hit in the air).

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)
local Emit = require(script.Parent.Emit)
local Shape = require(script.Parent.Shape)
local Beams = require(script.Parent.Beams)
local Light = require(script.Parent.Light)
local Screen = require(script.Parent.Screen)

local Recipes = {}

local WHITE = Color3.new(1, 1, 1)

-- A colour toward white by `u` (0..1): the hot heart of a coloured light.
local function hot(color: Color3, u: number): Color3
	return color:Lerp(WHITE, u)
end

export type ImpactOptions = {
	color: Color3?,
	scale: number?,
	ground: boolean?, -- a ring and dust along the floor (true when the hit is on it)
	shake: boolean?, -- the camera feels it (when near)
	flash: boolean?, -- the scene flashes (big hits only)
	spikes: boolean?, -- spikes flung off (true)
}

function Recipes.impact(at: CFrame, options: ImpactOptions?)
	local o = options or {}
	local color = o.color or Color3.fromRGB(235, 232, 225)
	local s = o.scale or 1
	local pos = at.Position
	-- the heart: a white star that opens and is gone in a blink, a coloured glow round it, an anime burst
	Emit.burst(at, {
		{
			{
				tex = "VfxFlare",
				color = WHITE,
				size = { { 0, 3 * s }, { 0.25, 7 * s }, { 1, 2 * s } },
				alpha = { { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } },
				life = 0.22,
				bright = 1.6,
				rot = { 0, 360 },
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxGlow",
				color = color,
				size = { { 0, 3 * s }, { 0.2, 9 * s }, { 1, 11 * s } },
				alpha = { { 0, 0.3 }, { 1, 1 } },
				life = 0.45,
				bright = 0.55,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxBurst",
				color = color,
				size = { { 0, 2 * s }, { 0.12, 9 * s }, { 1, 10.5 * s } },
				alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
				life = 0.3,
				light = 0.3,
				bright = 1.1,
				rot = { 0, 360 },
				z = 1.5,
			},
			1,
		},
		{
			{
				tex = "VfxBurst",
				color = hot(color, 0.75),
				size = { { 0, 1.5 * s }, { 0.12, 5 * s }, { 1, 5.5 * s } },
				alpha = { { 0, 0 }, { 0.4, 0.2 }, { 1, 1 } },
				life = 0.18,
				bright = 0.9,
				rot = { 0, 360 },
				z = 1.8,
			},
			1,
		},
	})
	-- flung off it: spikes of its colour and white-hot sparks that fall
	local up = o.ground and 80 or 180
	local flung = {}
	if o.spikes ~= false then
		table.insert(flung, {
			{
				tex = "VfxSpike",
				color = { { 0, hot(color, 0.6) }, { 1, color } },
				size = { { 0, 1.6 * s }, { 1, 0.2 * s } },
				squash = -1.4,
				life = { 0.16, 0.3 },
				speed = { 42 * s, 70 * s },
				drag = 12,
				spread = up,
				face = "along",
				light = 0.4,
				bright = 1.1,
				z = 1,
			},
			12,
		})
	end
	table.insert(flung, {
		{
			tex = "VfxStreak",
			color = { { 0, WHITE }, { 0.4, hot(color, 0.4) }, { 1, color } },
			size = { { 0, 0.32 * s }, { 1, 0.08 * s } },
			squash = -2,
			life = { 0.3, 0.65 },
			speed = { 30 * s, 58 * s },
			drag = 4,
			accel = Vector3.new(0, -60 * s, 0),
			spread = up,
			face = "along",
			bright = 1.4,
		},
		26,
	})
	table.insert(flung, {
		{
			tex = "VfxEmber",
			color = hot(color, 0.3),
			size = { { 0, 0.22 * s }, { 1, 0 } },
			life = { 0.6, 1.2 },
			speed = { 5 * s, 16 * s },
			drag = 3,
			accel = Vector3.new(0, 5 * s, 0),
			spread = up,
			bright = 1.2,
		},
		14,
	})
	Emit.burst(at, flung)
	-- along the floor: a shockwave front, a glow spreading under it, dust rolling out
	if o.ground then
		local floor = CFrame.new(pos) * (at - at.Position)
		Beams.wave(floor * CFrame.new(0, 0.12, 0), 0.6 * s, 9 * s, 0.42, {
			tex = "VfxRingBand",
			color = hot(color, 0.25),
			width = 1.7 * s,
			light = 0.5,
			bright = 1.1,
		})
		Emit.burst(floor * CFrame.new(0, 0.08, 0), {
			{
				{
					tex = "VfxRing",
					color = color,
					size = { { 0, 1.5 * s }, { 1, 13 * s } },
					alpha = { { 0, 0.1 }, { 0.6, 0.55 }, { 1, 1 } },
					life = 0.5,
					speed = 0.001,
					face = "flat",
					light = 0.5,
					bright = 0.9,
					spread = 0,
				},
				1,
			},
			{
				{
					tex = "VfxDust",
					grid = 4,
					mode = "OneShot",
					color = Color3.fromRGB(128, 126, 124),
					light = 0,
					lit = 0.6,
					size = { { 0, 1.6 * s }, { 1, 4.2 * s } },
					alpha = { { 0, 0.05 }, { 0.7, 0.35 }, { 1, 1 } },
					life = { 0.8, 1.2 },
					speed = { 14 * s, 22 * s },
					drag = 5,
					spread = { 88, 88 },
					rot = { 0, 360 },
					spin = { -40, 40 },
				},
				10,
			},
		})
	end
	if not o.ground then
		Emit.burst(at, {
			tex = "VfxRing",
			color = hot(color, 0.2),
			size = { { 0, 1 * s }, { 1, 12 * s } },
			alpha = { { 0, 0 }, { 0.5, 0.4 }, { 1, 1 } },
			life = 0.32,
			light = 0.45,
			bright = 1,
			z = 1.2,
		}, 1)
	else
		Emit.burst(at * CFrame.new(0, 0.5 * s, 0), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(78, 78, 82),
			light = 0,
			lit = 0.45,
			size = { { 0, 1.6 * s }, { 1, 4.2 * s } },
			alpha = { { 0, 0.45 }, { 0.6, 0.6 }, { 1, 1 } },
			life = { 1.0, 1.5 },
			speed = { 6 * s, 12 * s },
			drag = 3,
			spread = { 80, 80 },
			rot = { 0, 360 },
			spin = { -30, 30 },
		}, 5)
	end
	Light.flash(pos + at.UpVector * 1.5, color, 22 * s, 4, 0.4)
	if o.shake ~= false then
		Screen.shakeAt(pos, 1.3 * s, 0.35)
	end
	if o.flash then
		Screen.flash(hot(color, 0.5), 0.25, 0.3)
	end
end

-- A landing on the floor: an impact laid on it and bits of it thrown up.
function Recipes.slam(at: CFrame, options: ImpactOptions?)
	local o = table.clone(options or {})
	o.ground = true
	Recipes.impact(at, o)
	local Ground = require(script.Parent.Ground)
	local s = o.scale or 1
	-- a dome of light snapping out of the floor and gone
	Shape.grow("dome", at, {
		size = 7 * s,
		from = 0.2,
		seconds = 0.14,
		fade = 0.16,
		ease = Ease.outExpo,
		color = hot(o.color or WHITE, 0.35),
		transparency = 0.6,
		grow = 1.2,
	})
	Ground.mark(at.Position, at.UpVector, "VfxCrack", 9 * s, Color3.fromRGB(150, 150, 155), 2.5, { fadeOut = 1.2 })
	Ground.debris(at.Position, math.floor(7 * s + 0.5), { size = 0.7 * s, speed = 24 * s, life = 1.8 })
end

-- A glint: a star that blooms and closes, turning, with a few specks.
function Recipes.twinkle(at: Vector3, options: { color: Color3?, scale: number? }?)
	local o = options or {}
	local color = o.color or WHITE
	local s = o.scale or 1
	Emit.burst(at, {
		{
			{
				tex = "VfxFlare",
				color = hot(color, 0.5),
				size = { { 0, 0 }, { 0.35, 2.4 * s }, { 1, 0 } },
				life = 0.55,
				rot = { 0, 360 },
				spin = { -90, 90 },
				bright = 1.3,
			},
			1,
		},
		{
			{
				tex = "VfxEmber",
				color = color,
				size = { { 0, 0.14 * s }, { 1, 0 } },
				life = { 0.4, 0.8 },
				speed = { 1.5 * s, 4 * s },
				spread = 180,
				drag = 2,
				bright = 1.2,
			},
			5,
		},
	})
end

-- A column of light out of the floor: it shoots up and widens on an outExpo curve, streaks race up it, specks rise,
-- the floor glows and rings under it, then it narrows and fades.
function Recipes.pillar(at: CFrame, options: { color: Color3?, height: number?, radius: number?, seconds: number? }?)
	local o = options or {}
	local color = o.color or WHITE
	local height = o.height or 30
	local r = o.radius or 2
	local seconds = o.seconds or 1.2
	local base = at.Position
	local top = base + at.UpVector * height
	-- the column: a soft white core in a wide coloured glow (beams facing the camera, their streaks racing up), opened
	-- in a blink and closed slowly from its edges
	local layers = {
		{
			tex = "VfxColumn",
			color = WHITE,
			width = r * 1.1,
			bright = 1.4,
			speed = height * 0.9,
			repeats = height * 0.6,
		},
		{
			tex = "VfxColumn",
			color = hot(color, 0.15),
			width = r * 3.2,
			bright = 0.8,
			speed = height * 0.5,
			repeats = height * 0.9,
		},
		{ tex = "VfxColumn", color = color, width = r * 6, bright = 0.35, speed = height * 0.3, repeats = height },
	}
	for k, layer in ipairs(layers) do
		local full = layer.width
		local beam, stop = Beams.line(top, base, {
			tex = layer.tex,
			color = layer.color,
			width = 0.01,
			bright = layer.bright,
			speed = layer.speed,
			repeats = layer.repeats,
			z = k,
		})
		Clock.tween(0.18 + 0.05 * k, Ease.outExpo, function(u)
			beam.Width0, beam.Width1 = full * u, full * u
		end)
		Clock.after(seconds, function()
			stop(0.45 + 0.1 * k)
		end)
	end
	-- the floor: a ring snapping out from the column's foot, a glow on it, specks rising
	local floor = at * CFrame.new(0, 0.1, 0)
	Beams.wave(floor, r, r * 5, 0.5, { tex = "VfxRingBand", color = hot(color, 0.3), width = 1.4, bright = 1.1 })
	local point = Emit.point(floor)
	local _, stopSpecks = Emit.hold(point, {
		tex = "VfxEmber",
		color = hot(color, 0.4),
		size = { { 0, 0.2 }, { 1, 0 } },
		life = { 0.8, 1.6 },
		speed = { 8, 18 },
		spread = 10,
		rate = 34,
		shape = Enum.ParticleEmitterShape.Disc,
		bright = 1.3,
	})
	point.Size = Vector3.new(r * 2.4, 0.05, r * 2.4)
	local _, stopGlow = Emit.hold(point, {
		tex = "VfxGlow",
		color = color,
		size = r * 6,
		alpha = { { 0, 1 }, { 0.5, 0.45 }, { 1, 1 } },
		life = 1,
		rate = 2,
		speed = 0.001,
		face = "flat",
		bright = 0.8,
	})
	Light.flash(base + at.UpVector * 4, color, 30, 3, seconds + 0.5)
	Clock.after(seconds + 0.3, function()
		stopSpecks()
		stopGlow()
		Clock.after(2, function()
			point:Destroy()
		end)
	end)
end

export type Flame = {
	set: (scale: number, seconds: number?) -> (), -- grow or shrink to `scale` of its size
	flare: (on: boolean) -> (), -- burn taller and brighter (a countdown), or calm again
	out: () -> (), -- go out: shrink, a curl of smoke from the wick, the light dies
	destroy: () -> (), -- gone at once
}

export type FlameOptions = {
	kind: string?, -- "candle" (the realm's pale candle flame) or "fire" (a tinted fire, braziers)
	scale: number?, -- studs tall the flame stands
	color: Color3?, -- for "fire"
	light: boolean?, -- a flickering light (true)
	lightRange: number?,
	lightBrightness: number?,
	lit: boolean?, -- burning from the start (true), else out until set(1)
}

-- A living flame on `parent` (a part or attachment at the wick; the flame stands up from it). Two flame particles
-- half a life apart, each fading in and out, add as light to a steady flame whose flipbook flickers; a halo round
-- it; for fire, embers and a breath of smoke; a light that flickers on noise.
function Recipes.flame(parent: Instance, options: FlameOptions?): Flame
	local o = options or {}
	local candle = (o.kind or "candle") == "candle"
	local height = o.scale or (if candle then 0.55 else 3)
	local color = o.color or (if candle then WHITE else Color3.fromRGB(205, 222, 245))
	local size = height * 1.45 -- (the flame fills about 70 % of its square's height)
	local scale = if o.lit == false then 0 else 1
	local flaring = false
	-- (the particles' middle sits a third of their square up from the wick: the flame's base at the wick; an
	-- attachment given as the wick lends its part and place)
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
	-- (each emitter's size as made, at the flame's full size: every scale is taken from it)
	local emitters: { { e: ParticleEmitter, sizes: NumberSequence, steady: boolean } } = {}
	local function add(at: Attachment, spec: { [string]: any }, steady: boolean)
		local e = Emit.make(at, spec)
		table.insert(emitters, { e = e, sizes = e.Size, steady = steady })
		if steady and scale > 0.02 then
			e:Emit(1)
		end
		return e
	end
	-- One long-lived particle at a time, the next fading in over the last's fading out (a steady light that never
	-- doubles up and burns white): its flipbook is the flicker.
	local STEADY = 4
	local function steady(spec: { [string]: any }): { [string]: any }
		spec.life = STEADY
		spec.rate = 1 / (STEADY * 0.95)
		spec.alpha = { { 0, 1 }, { 0.05, spec.solid or 0 }, { 0.95, spec.solid or 0 }, { 1, 1 } }
		spec.solid = nil
		return spec
	end
	local function attachmentAt(offset: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "DGVfxFlame"
		a.CFrame = holder.CFrame * CFrame.new(offset)
		a.Parent = holder.Parent
		return a
	end
	local others: { Attachment } = {}
	if candle then
		add(
			holder,
			steady({
				tex = "VfxCandleFlame",
				grid = 8,
				fps = 24,
				startRandom = true,
				color = WHITE,
				size = size,
				face = "up",
				locked = true,
				light = 1,
				bright = 1.45,
				z = 0.2,
			}),
			true
		)
	end
	-- the heart: a small hot glow low in the flame
	add(
		holder,
		steady({
			tex = "VfxGlow",
			color = WHITE,
			size = size * 0.42,
			solid = 0.25,
			face = "camera",
			locked = true,
			bright = if candle then 1.1 else 0.9,
			z = 0.3,
		}),
		true
	)
	-- the halo round it
	add(
		holder,
		steady({
			tex = "VfxGlow",
			color = hot(color, 0.15),
			size = size * (if candle then 1.9 else 1.5),
			solid = if candle then 0.6 else 0.55,
			face = "camera",
			locked = true,
			bright = if candle then 0.5 else 0.7,
			z = 0,
		}),
		true
	)
	if not candle then
		-- the fire's body: tongues of flame born on a bed at the wick, rising, swelling and burning out as they climb,
		-- white-hot at birth, the fire's colour through the middle of their lives, darkening as they go (alpha-blended
		-- more than added, so the colour holds instead of burning white)
		local bed = attachmentAt(Vector3.new(0, -size * 0.33, 0))
		table.insert(others, bed)
		add(bed, {
			tex = "VfxFlame",
			grid = 8,
			fps = 40,
			startRandom = true,
			color = {
				{ 0, hot(color, 0.6) },
				{ 0.25, color },
				{ 0.7, color:Lerp(Color3.new(0, 0, 0), 0.55) },
				{ 1, color:Lerp(Color3.new(0, 0, 0), 0.8) },
			},
			size = { { 0, 0.42 * height }, { 0.3, 0.62 * height }, { 1, 0.3 * height } },
			alpha = { { 0, 1 }, { 0.12, 0.25 }, { 0.65, 0.45 }, { 1, 1 } },
			life = { 0.55, 0.9 },
			rate = 26,
			speed = { 0.6 * height, 1.25 * height },
			spread = 9,
			accel = Vector3.new(0, 0.35 * height, 0),
			drag = 1.2,
			rot = { -14, 14 },
			face = "up",
			light = 0.3,
			bright = 1.1,
			z = 0.2,
		}, false)
		-- its hot heart: smaller, white, added as light, low in the fire
		add(bed, {
			tex = "VfxFlame",
			grid = 8,
			fps = 40,
			startRandom = true,
			color = hot(color, 0.75),
			size = { { 0, 0.32 * height }, { 0.4, 0.45 * height }, { 1, 0.15 * height } },
			alpha = { { 0, 1 }, { 0.15, 0.3 }, { 0.6, 0.6 }, { 1, 1 } },
			life = { 0.35, 0.55 },
			rate = 14,
			speed = { 0.3 * height, 0.6 * height },
			spread = 6,
			face = "up",
			light = 1,
			bright = 0.8,
			z = 0.3,
		}, false)
		-- embers rising off it, and a breath of dark smoke over it
		add(holder, {
			tex = "VfxEmber",
			color = hot(color, 0.5),
			size = { { 0, 0.05 * height }, { 1, 0 } },
			life = { 0.8, 1.6 },
			rate = 7,
			speed = { 0.7 * height, 1.7 * height },
			spread = 22,
			accel = Vector3.new(0, 0.6 * height, 0),
			drag = 0.6,
			bright = 1.3,
		}, false)
		local top = attachmentAt(Vector3.new(0, size * 0.35, 0))
		table.insert(others, top)
		add(top, {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(58, 58, 62),
			light = 0,
			lit = 0.25,
			size = { { 0, 0.35 * height }, { 1, 1.1 * height } },
			alpha = { { 0, 0.55 }, { 0.4, 0.6 }, { 1, 1 } },
			life = { 2.6, 3.6 },
			rate = 1.6,
			speed = { 0.5 * height, 0.8 * height },
			spread = 10,
			rot = { 0, 360 },
			spin = { -20, 20 },
		}, false)
	end
	local light: PointLight? = nil
	local stopFlicker: (() -> ())? = nil
	local range = o.lightRange or (if candle then 9 else 22)
	local brightness = o.lightBrightness or (if candle then 0.9 else 1.6)
	if o.light ~= false then
		local l = Instance.new("PointLight")
		l.Color = hot(color, 0.1)
		l.Range = range
		l.Brightness = brightness * scale
		l.Shadows = false
		l.Parent = holder
		light = l
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
		if light then
			if scale > 0.02 then
				stopFlicker = Light.flicker(
					light,
					brightness * k * (if flaring then 1.6 else 1),
					range * (if flaring then 1.4 else 1),
					0.18
				)
			else
				light.Brightness = 0
			end
		end
	end
	apply()
	local tweening: (() -> ())? = nil
	local flame: Flame
	flame = {
		set = function(target: number, seconds: number?)
			if tweening then
				tweening()
			end
			local from = scale
			local wasOut = from <= 0.02
			if wasOut and target > 0.02 then
				-- a light struck: a tiny flare at the wick as it catches
				local at = (holder :: Attachment).WorldPosition - Vector3.new(0, size * 0.33, 0)
				Emit.burst(at, {
					tex = "VfxFlare",
					color = hot(color, 0.6),
					size = { { 0, 0 }, { 0.3, size * 1.2 }, { 1, 0 } },
					life = 0.3,
					rot = { 0, 360 },
					bright = 1.3,
				}, 1)
			end
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
			local wick = (holder :: Attachment).WorldPosition - Vector3.new(0, size * 0.33, 0)
			flame.set(0, 0.25)
			-- the curl of smoke a wick gives off as it goes out
			Emit.burst(wick + Vector3.new(0, size * 0.6, 0), {
				tex = "VfxWisp",
				grid = 4,
				mode = "OneShot",
				color = Color3.fromRGB(200, 200, 204),
				light = 0,
				lit = 0.35,
				size = size * 2.4,
				alpha = { { 0, 0.15 }, { 0.7, 0.45 }, { 1, 1 } },
				life = 2.4,
				face = "up",
				bright = 1,
			}, 1)
		end,
		destroy = function()
			if stopFlicker then
				stopFlicker()
			end
			holder:Destroy()
			for _, at in ipairs(others) do
				at:Destroy()
			end
		end,
	}
	return flame
end

return Recipes
