--!strict
-- The custom deaths' effects (Shared/Cosmetics kind "reason", 2026-10-25): what the cause written in the Manual does
-- to the body as it falls, played on every screen by the death cutscene (Presenters/Death) a moment before the body
-- hits the floor. Each is layered from the VFX kit (Presentation/Vfx): a white-hot moment, a body of colour, the
-- floor answering, light thrown on the scene; none uses ink.
--
--   CustomDeaths.play("lightning", body)

local Cinema = require(script.Parent.Cinema)
local DeathScreen = require(script.Parent.DeathScreen)
local Vfx = require(script.Parent.Vfx)

local CustomDeaths = {}

local WHITE = Color3.new(1, 1, 1)
local CRIMSON = Color3.fromRGB(150, 14, 26) -- (blood is kept to a few dark drops)

-- `hit`: seconds from the effect's start to when the body hits the floor (Shared/Anim/DeathTiming), for the effects
-- whose impact lands with it.
type Fx = (body: Model, centre: Vector3, floor: Vector3, head: BasePart?, torso: BasePart?, hit: number?) -> ()

local FX: { [string]: Fx } = {}

local function floorOf(body: Model, at: Vector3): Vector3
	local hit = Vfx.Ground.at(at, { body }, 8)
	return hit
end

-- Where the body is now (its torso, or `fallback`), and the floor under it: for an impact that lands where the body
-- has fallen to, not where it stood when the effect began.
local function bodyNow(body: Model, fallback: Vector3): (Vector3, Vector3)
	local torso = body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart")
	local at = if torso and torso:IsA("BasePart") and torso.Parent then torso.Position else fallback
	return at, floorOf(body, at)
end

-- A held emitter on a still box of air round the body, let go after `seconds`.
local function hold(centre: Vector3, size: Vector3, spec: { [string]: any }, seconds: number)
	local box = Vfx.Emit.point(CFrame.new(centre), size)
	spec.shape = spec.shape or Enum.ParticleEmitterShape.Box
	local e = Vfx.Emit.make(box, spec)
	Vfx.Clock.after(seconds, function()
		e.Enabled = false
	end)
	Vfx.Clock.after(seconds + Vfx.Emit.longest(spec) + 0.3, function()
		box:Destroy()
	end)
	return e
end

-- A long fall: the floor comes up hard, dust thrown out low, a crack under them.
FX.fall = function(body, centre, _, _, _, hit)
	Vfx.Clock.after(hit or 0.25, function()
		local _, floor = bodyNow(body, centre)
		Vfx.Recipes.slam(CFrame.new(floor), { color = Color3.fromRGB(200, 196, 190), scale = 0.85, shake = true })
	end)
end

-- A broken heart: a red light beats twice in the chest, then cracks into falling pieces.
FX.heart = function(_, _, floor, _, torso)
	local chest = if torso then (torso.CFrame * CFrame.new(0, 0.2, -0.6)).Position else floor + Vector3.new(0, 3, 0)
	local red = Color3.fromRGB(220, 30, 50)
	for _, at in ipairs({ 0, 0.32 }) do
		Vfx.Clock.after(at, function()
			Vfx.Emit.burst(chest, {
				tex = "VfxGlow",
				color = red,
				size = { { 0, 1.2 }, { 0.3, 4.4 }, { 1, 1.6 } },
				alpha = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } },
				life = 0.45,
				light = 1,
				bright = 1.8,
				z = 2,
			}, 1)
			Vfx.Light.flash(chest, red, 10, 2.5, 0.3)
		end)
	end
	Vfx.Clock.after(0.7, function()
		Vfx.Emit.burst(chest, {
			{
				{
					tex = "VfxFlare",
					color = Color3.fromRGB(255, 180, 190),
					size = { { 0, 0.4 }, { 0.25, 3 }, { 1, 0 } },
					life = 0.25,
					rot = { 0, 360 },
					bright = 1.5,
					z = 2,
				},
				1,
			},
			{
				{
					tex = "VfxChunk",
					grid = 2,
					fps = 0,
					startRandom = true,
					color = { { 0, Color3.fromRGB(255, 90, 100) }, { 1, Color3.fromRGB(120, 10, 24) } },
					light = 0.6,
					lit = 0.4,
					size = { { 0, 0.3 }, { 1, 0.18 } },
					life = { 0.7, 1.1 },
					speed = { 3, 8 },
					spread = 180,
					accel = Vector3.new(0, -30, 0),
					rot = { 0, 360 },
					spin = { -300, 300 },
					z = 1,
				},
				16,
			},
		})
		Vfx.Light.flash(chest, red, 14, 4, 0.5)
	end)
end

-- Frozen where they stood: frost climbs them (a cold edge and mist), then breaks off as falling ice.
FX.frost = function(body, centre, floor, _, _, hit)
	local ice = Color3.fromRGB(180, 225, 255)
	local breaks = hit or 0.8
	Vfx.Rim.glow(body, ice, breaks + 0.15, { fill = 0.45, fadeIn = 0.45, fadeOut = 0.5 })
	hold(floor + Vector3.new(0, 0.4, 0), Vector3.new(3, 0.4, 3), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(215, 235, 250),
		light = 0.1,
		lit = 0.6,
		size = { { 0, 1.2 }, { 1, 3.6 } },
		alpha = { { 0, 0.55 }, { 0.6, 0.7 }, { 1, 1 } },
		life = { 1.2, 1.8 },
		speed = { 0.5, 1.5 },
		spread = 70,
		rot = { 0, 360 },
		rate = 12,
	}, 1)
	hold(centre, Vector3.new(2, 4, 1.4), {
		tex = "VfxEmber",
		color = ice,
		size = { { 0, 0 }, { 0.3, 0.14 }, { 1, 0 } },
		life = { 0.6, 1.1 },
		speed = { 0.2, 0.8 },
		spread = 180,
		bright = 1.4,
		rate = 30,
	}, 0.8)
	Vfx.Clock.after(breaks, function()
		local at, ground = bodyNow(body, centre)
		Vfx.Emit.burst(at, {
			{
				{
					tex = "VfxFlare",
					color = WHITE,
					size = { { 0, 0.5 }, { 0.25, 5 }, { 1, 0 } },
					life = 0.22,
					rot = { 0, 360 },
					bright = 1.6,
					z = 2,
				},
				1,
			},
			{
				{
					tex = "VfxChunk",
					grid = 2,
					fps = 0,
					startRandom = true,
					color = { { 0, WHITE }, { 1, ice } },
					light = 0.5,
					lit = 0.5,
					size = { { 0, 0.4 }, { 1, 0.28 } },
					alpha = { { 0, 0.2 }, { 0.8, 0.35 }, { 1, 1 } },
					life = { 0.6, 1.1 },
					speed = { 4, 11 },
					spread = 180,
					accel = Vector3.new(0, -45, 0),
					rot = { 0, 360 },
					spin = { -400, 400 },
				},
				30,
			},
		}, nil, Vector3.new(2, 4, 1.4))
		Vfx.Ground.mark(ground, Vector3.yAxis, "VfxCrack", 6, ice, 3, { fadeOut = 1.2 })
		Vfx.Light.flash(at, ice, 16, 3, 0.4)
	end)
end

-- The chandelier: crystal and dust come down from above and land on them in a gold flash.
FX.chandelier = function(body, centre, floor, _, _, hit)
	local gold = Color3.fromRGB(255, 230, 170)
	Vfx.Emit.burst(floor + Vector3.new(0, 16, 0), {
		tex = "VfxSpike",
		color = { { 0, WHITE }, { 1, gold } },
		size = { { 0, 0.6 }, { 1, 0.4 } },
		squash = -1.2,
		life = { 0.5, 0.6 },
		speed = { 26, 30 },
		dir = Enum.NormalId.Bottom,
		spread = 6,
		accel = Vector3.new(0, -30, 0),
		face = "along",
		light = 0.5,
		bright = 1.4,
	}, 14, Vector3.new(3, 0.5, 3))
	Vfx.Clock.after(hit or 0.5, function()
		local _, ground = bodyNow(body, centre)
		Vfx.Recipes.slam(CFrame.new(ground), { color = gold, scale = 0.9, shake = true })
		Vfx.Emit.burst(ground + Vector3.new(0, 0.5, 0), {
			tex = "VfxFlare",
			color = WHITE,
			size = { { 0, 0 }, { 0.2, 0.4 }, { 0.4, 0 }, { 0.6, 0.35 }, { 1, 0 } },
			life = { 0.8, 1.4 },
			speed = { 3, 8 },
			spread = 80,
			accel = Vector3.new(0, -20, 0),
			rot = { 0, 90 },
			bright = 1.5,
		}, 18)
	end)
end

-- Drowned on dry land: rings spread over the floor as if it were water, bubbles stream up round them.
FX.drown = function(_, centre, floor)
	local sea = Color3.fromRGB(110, 180, 230)
	for k, at in ipairs({ 0, 0.35, 0.7 }) do
		Vfx.Clock.after(at, function()
			Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.08, 0)), 0.6, 7 + k * 2, 1.1, {
				tex = "VfxRingBand",
				color = sea,
				width = 0.8,
				light = 0.5,
				bright = 1,
			})
		end)
	end
	hold(centre, Vector3.new(2.4, 4, 1.6), {
		tex = "VfxRing",
		color = Color3.fromRGB(200, 235, 255),
		size = { { 0, 0.1 }, { 0.2, 0.3 }, { 1, 0.45 } },
		alpha = { { 0, 0.3 }, { 0.8, 0.4 }, { 1, 1 } },
		life = { 0.8, 1.4 },
		speed = { 2, 4 },
		spread = 10,
		accel = Vector3.new(0, 2, 0),
		light = 0.6,
		bright = 1.2,
		rate = 26,
	}, 1.2)
	Vfx.Emit.burst(floor + Vector3.new(0, 0.2, 0), {
		tex = "VfxStreak",
		color = { { 0, WHITE }, { 1, sea } },
		size = { { 0, 0.25 }, { 1, 0.08 } },
		squash = -1.6,
		life = { 0.4, 0.7 },
		speed = { 10, 18 },
		spread = 25,
		accel = Vector3.new(0, -40, 0),
		face = "along",
		light = 0.4,
		bright = 1.2,
	}, 18, Vector3.new(2, 0.2, 2))
	Vfx.Light.flash(centre, sea, 14, 2.5, 1.2)
end

-- Struck by lightning: a bolt out of the sky, a white flash, a scorch on the floor and smoke curling off it.
FX.lightning = function(_, centre, floor)
	local cold = Color3.fromRGB(200, 225, 255)
	for k = 1, 3 do
		Vfx.Clock.after((k - 1) * 0.05, function()
			Vfx.Beams.bolt(floor + Vector3.new(math.random(-3, 3), 60, math.random(-3, 3)), centre, 0.28, {
				color = cold,
				width = if k == 1 then 2.2 else 1.1,
				bright = 2,
				light = 1,
				pieces = 12,
				jag = 2.2,
				rate = 24,
			})
		end)
	end
	Vfx.Screen.flash(cold, 0.5, 0.35)
	Vfx.Recipes.impact(CFrame.new(floor), { color = cold, scale = 1.2, ground = true, shake = true })
	Vfx.Ground.mark(floor, Vector3.yAxis, "VfxCrack", 7, Color3.fromRGB(40, 38, 42), 3, { fadeOut = 1.5 })
	Vfx.Light.flash(centre, cold, 40, 8, 0.4)
	Vfx.Clock.after(0.3, function()
		hold(floor + Vector3.new(0, 0.5, 0), Vector3.new(2.5, 0.5, 2.5), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(60, 58, 62),
			light = 0,
			lit = 0.4,
			size = { { 0, 0.8 }, { 1, 2.8 } },
			alpha = { { 0, 0.5 }, { 0.6, 0.65 }, { 1, 1 } },
			life = { 1.6, 2.4 },
			speed = { 1.5, 3 },
			spread = 15,
			rot = { 0, 360 },
			rate = 7,
		}, 1.6)
	end)
end

-- A thousand paper cuts: torn pages whirl up round them, faster and faster, and fly off.
FX.pages = function(_, centre, floor)
	local pages: { { part: BasePart, angle: number, radius: number, rise: number, tilt: number } } = {}
	for k = 1, 12 do
		local part = Vfx.Shape.part("page", "VfxPage")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = part.Size * 0.8
		part.Parent = Vfx.Emit.folder()
		table.insert(pages, {
			part = part,
			angle = k / 12 * math.pi * 2,
			radius = 1.6 + (k % 3) * 0.35,
			rise = (k % 4) * 0.6,
			tilt = math.random() * math.pi,
		})
	end
	local began = Vfx.Clock.now()
	Vfx.Clock.every(function(_, now)
		local t = now - began
		if t > 1.8 then
			for _, p in ipairs(pages) do
				p.part:Destroy()
			end
			return false
		end
		local spinRate = 3 + t * 6
		for _, p in ipairs(pages) do
			local a = p.angle + t * spinRate
			local out = if t > 1.3 then (t - 1.3) * 18 else 0
			local r = p.radius + out
			local y = 0.6 + p.rise + t * 1.4 + out * 0.4
			p.part.CFrame = CFrame.new(floor + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
				* CFrame.Angles(p.tilt + t * 4, a, 0.4)
			p.part.Transparency = if t > 1.3 then (t - 1.3) / 0.5 else 0
		end
		return true
	end)
	hold(centre, Vector3.new(3, 4, 3), {
		tex = "VfxChunk",
		grid = 2,
		fps = 0,
		startRandom = true,
		color = Color3.fromRGB(240, 234, 214),
		light = 0,
		lit = 0.8,
		size = { { 0, 0.12 }, { 1, 0.08 } },
		life = { 0.6, 1 },
		speed = { 2, 5 },
		spread = 180,
		rot = { 0, 360 },
		spin = { -400, 400 },
		rate = 40,
	}, 1.4)
end

-- Burned from within: a glow under the skin, embers pouring off them, flame licking up, smoke after.
FX.burn = function(body, centre, floor)
	local fire = Color3.fromRGB(255, 130, 50)
	Vfx.Rim.glow(body, fire, 1.1, { fill = 0.5, fadeIn = 0.3, fadeOut = 0.7 })
	hold(centre, Vector3.new(2, 4, 1.2), {
		tex = "VfxFlame",
		grid = 8,
		fps = 40,
		startRandom = true,
		color = { { 0, Color3.fromRGB(255, 230, 170) }, { 0.35, fire }, { 1, Color3.fromRGB(60, 20, 10) } },
		size = { { 0, 0.8 }, { 0.4, 1.4 }, { 1, 0.4 } },
		alpha = { { 0, 0.4 }, { 0.6, 0.5 }, { 1, 1 } },
		life = { 0.4, 0.7 },
		speed = { 2, 4 },
		spread = 10,
		face = "up",
		light = 0.5,
		bright = 1.3,
		rate = 40,
		z = 1.2,
	}, 1.1)
	hold(centre, Vector3.new(2, 4, 1.2), {
		tex = "VfxEmber",
		color = { { 0, Color3.fromRGB(255, 220, 160) }, { 1, fire } },
		size = { { 0, 0.18 }, { 1, 0 } },
		life = { 0.8, 1.6 },
		speed = { 2, 6 },
		spread = 40,
		accel = Vector3.new(0, 4, 0),
		bright = 1.5,
		rate = 50,
		z = 1,
	}, 1.2)
	Vfx.Light.flash(centre, fire, 18, 3, 1.4)
	Vfx.Clock.after(1, function()
		Vfx.Ground.mark(floor, Vector3.yAxis, "VfxCrack", 5, Color3.fromRGB(40, 30, 26), 3, { fadeOut = 1.5 })
		hold(centre, Vector3.new(2, 3, 1.2), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(70, 64, 60),
			light = 0,
			lit = 0.4,
			size = { { 0, 1 }, { 1, 3.4 } },
			alpha = { { 0, 0.5 }, { 0.6, 0.65 }, { 1, 1 } },
			life = { 1.6, 2.4 },
			speed = { 1.5, 3 },
			spread = 15,
			rot = { 0, 360 },
			rate = 8,
		}, 1.4)
	end)
end

-- Choked on a potato chip: a crunch at the mouth, crumbs everywhere, a gold glint, then quiet.
FX.chip = function(_, centre, _, head)
	local mouth = if head then (head.CFrame * CFrame.new(0, -0.25, -0.6)).Position else centre + Vector3.new(0, 1.5, 0)
	local gold = Color3.fromRGB(255, 214, 120)
	Vfx.Emit.burst(mouth, {
		{
			{
				tex = "VfxBurst",
				color = gold,
				size = { { 0, 0.5 }, { 0.15, 3 }, { 1, 3.4 } },
				alpha = { { 0, 0 }, { 0.5, 0.25 }, { 1, 1 } },
				life = 0.25,
				light = 0.6,
				rot = { 0, 360 },
				bright = 1.2,
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = { { 0, Color3.fromRGB(255, 225, 140) }, { 1, Color3.fromRGB(210, 150, 60) } },
				light = 0.1,
				lit = 0.7,
				size = { { 0, 0.22 }, { 1, 0.15 } },
				life = { 0.6, 1 },
				speed = { 4, 9 },
				spread = 70,
				accel = Vector3.new(0, -30, 0),
				rot = { 0, 360 },
				spin = { -400, 400 },
			},
			30,
		},
	})
	Vfx.Clock.after(0.4, function()
		Vfx.Recipes.twinkle(mouth + Vector3.new(0.4, 0.3, 0), { color = gold, scale = 1.4 })
	end)
end

-- Their time ran out: a stopwatch's face opens on the floor under them, turns, and is gone with a tick of light.
FX.clock = function(_, centre, floor, _, _, hit)
	local pale = Color3.fromRGB(230, 220, 190)
	local last = hit or 1.1 -- the last tick, as the body lands
	local base = Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 0.06, 0)))
	local face = Vfx.Emit.make(base, {
		tex = "VfxCircle",
		color = pale,
		size = 0.1,
		alpha = { { 0, 1 }, { 0.1, 0.25 }, { 0.85, 0.25 }, { 1, 1 } },
		life = last + 0.7,
		speed = 0.001,
		face = "flat",
		spin = -40,
		light = 0.5,
		bright = 1.1,
	})
	face:Emit(1)
	Vfx.Clock.tween(0.5, Vfx.Ease.outBack, function(u)
		face.Size = NumberSequence.new(math.max(0.1, 7 * u))
	end)
	Vfx.Clock.after(last, function()
		Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.1, 0)), 3, 9, 0.6, {
			tex = "VfxRingBand",
			color = pale,
			width = 1,
			light = 0.6,
			bright = 1.1,
		})
		Vfx.Light.flash(centre, pale, 14, 3, 0.4)
	end)
	Vfx.Clock.after(last + 1.1, function()
		base:Destroy()
	end)
end

-- Taken by the dark: shadow rises off the floor round them and closes over them; two red eyes, then nothing.
FX.dark = function(body, centre, floor, head)
	local blood = Color3.fromRGB(200, 20, 36)
	Vfx.Rim.glow(body, Color3.fromRGB(10, 6, 8), 1, { fill = 0.7, fadeIn = 0.6, fadeOut = 0.6 })
	hold(floor + Vector3.new(0, 0.5, 0), Vector3.new(3.4, 0.6, 3.4), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(12, 10, 14),
		light = 0,
		lit = 0.2,
		size = { { 0, 2 }, { 1, 5.5 } },
		alpha = { { 0, 0.15 }, { 0.6, 0.3 }, { 1, 1 } },
		life = { 1.2, 1.8 },
		speed = { 2, 4 },
		spread = 20,
		accel = Vector3.new(0, 1, 0),
		rot = { 0, 360 },
		spin = { -30, 30 },
		rate = 34,
		z = 0.8,
	}, 1.3)
	Vfx.Clock.after(0.55, function()
		local eyes = if head then head.Position + Vector3.new(0, 0.1, 0) else centre + Vector3.new(0, 1.6, 0)
		for _, side in ipairs({ -0.22, 0.22 }) do
			Vfx.Emit.burst(eyes + Vector3.new(side, 0, 0), {
				tex = "VfxFlare",
				color = blood,
				size = { { 0, 0.2 }, { 0.3, 1.4 }, { 1, 0 } },
				life = 0.7,
				rot = { 0, 45 },
				bright = 1.6,
				z = 2,
			}, 1)
		end
		Vfx.Light.flash(eyes, blood, 10, 2, 0.6)
	end)
end

-- The second batch (2026-11-08): each re-acts a scene the user named (art/scripts/deaths_scenes.py); these are their
-- signature effects, from the death's `fx` beat on (DeathTiming), the rest of their beats in Presentation/DeathVfx.

-- A point on a part of the body (in the part's own frame), or `fallback`.
local function on(body: Model, name: string, local_: Vector3, fallback: Vector3): Vector3
	local part = body:FindFirstChild(name)
	if part and part:IsA("BasePart") and part.Parent then
		return part.CFrame:PointToWorldSpace(local_)
	end
	return fallback
end

-- A light on a still point that fades in and holds `seconds`, then fades out.
local function glowFor(at: Vector3, color: Color3, range: number, brightness: number, seconds: number)
	local anchor = Vfx.Emit.point(CFrame.new(at))
	local _, stop = Vfx.Light.hold(anchor, color, range, brightness, 0.15)
	Vfx.Clock.after(seconds, function()
		stop(0.4)
	end)
	Vfx.Clock.after(seconds + 0.6, function()
		anchor:Destroy()
	end)
end

-- A bullet's hit on the chest: a spit of sparks, a few dark drops, a jolt; the muzzle's flash from in front of them.
local function shot(body: Model, centre: Vector3, scale: number)
	local chest = on(body, "Torso", Vector3.new(0, 0.3, -0.55), centre)
	local torso = body:FindFirstChild("Torso")
	local ahead = if torso and torso:IsA("BasePart") then torso.CFrame.LookVector else Vector3.new(0, 0, -1)
	Vfx.Emit.burst(chest, {
		{
			{
				tex = "VfxFlare",
				color = Color3.fromRGB(255, 236, 200),
				size = { { 0, 0.3 }, { 0.2, 1.6 * scale }, { 1, 0 } },
				life = 0.12,
				rot = { 0, 360 },
				bright = 2,
				z = 2,
			},
			1,
		},
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = CRIMSON,
				light = 0,
				lit = 0.5,
				size = { { 0, 0.12 }, { 1, 0.07 } },
				life = { 0.4, 0.7 },
				speed = { 3, 7 },
				spread = 40,
				accel = Vector3.new(0, -35, 0),
				rot = { 0, 360 },
				spin = { -300, 300 },
			},
			math.floor(5 * scale + 0.5),
		},
	})
	Vfx.Light.flash(chest + ahead * 9 + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 210, 150), 16, 4, 0.08)
	Vfx.Screen.shakeAt(chest, 0.18 * scale, 0.15)
end

-- This is... requiem: the blow stops dead and everything turns back. A void of violet and green stars closes round them
-- and the picture goes violet; they are rewound in stutters, afterimages smeared behind; let go, the barrage (DeathVfx).
FX.requiem = function(body, centre, _, _, _, _)
	local violet, green = Color3.fromRGB(150, 70, 230), Color3.fromRGB(80, 230, 160)
	local untint = Cinema.tint({ Saturation = -0.25, Contrast = 0.3, TintColor = Color3.fromRGB(205, 178, 255) }, 0.12)
	Vfx.Clock.after(1.58, untint)
	hold(centre, Vector3.new(8, 6, 8), {
		tex = "VfxWisp",
		color = { { 0, violet }, { 0.5, green }, { 1, violet } },
		size = { { 0, 0.4 }, { 0.5, 1.6 }, { 1, 0 } },
		alpha = { { 0, 1 }, { 0.3, 0.35 }, { 1, 1 } },
		life = { 1, 1.6 },
		speed = { 0.4, 1.4 },
		spread = 180,
		rot = { 0, 360 },
		spin = { -60, 60 },
		light = 1,
		bright = 1.7,
		rate = 34,
	}, 1.45)
	hold(centre, Vector3.new(10, 7, 10), {
		tex = "VfxEmber",
		color = WHITE,
		size = { { 0, 0 }, { 0.5, 0.12 }, { 1, 0 } },
		life = { 0.8, 1.4 },
		speed = { 0.1, 0.4 },
		spread = 180,
		bright = 2.2,
		rate = 50,
	}, 1.45)
	glowFor(centre + Vector3.new(0, 1, 0), violet, 22, 2.6, 1.45)
	-- rewound (0.74-1.34 s into the acting): an afterimage every few frames, violet and green by turns
	local k = 0
	local stopAt = 0.74
	Vfx.Clock.after(0.1, function()
		local left = stopAt
		Vfx.Clock.every(function(dt)
			left -= dt
			k += 1
			if k % 4 == 0 then
				DeathScreen.ghost(body, if (k // 4) % 2 == 0 then violet else green, 0.55, 0.5)
			end
			return left > 0
		end)
	end)
end

-- Blackwall gateway: scanned (a green line down them), outlined in red, the red glitch eating in, a burst of red-orange
-- sparks chaining through them, the body burning red as it goes down.
FX.blackwall = function(body, centre, floor, _, _, hit)
	local red, ember = Color3.fromRGB(255, 30, 40), Color3.fromRGB(255, 110, 40)
	local down = hit or 1.9
	-- the scan: a thin green plane down the body, twice
	for pass = 0, 1 do
		Vfx.Clock.after(pass * 0.18, function()
			local plane = Instance.new("Part")
			plane.Anchored = true
			plane.CanCollide = false
			plane.CanQuery = false
			plane.CanTouch = false
			plane.CastShadow = false
			plane.Material = Enum.Material.Neon
			plane.Color = Color3.fromRGB(90, 255, 140)
			plane.Transparency = 0.25
			plane.Size = Vector3.new(3.6, 0.05, 2.4)
			plane.Parent = Vfx.Emit.folder()
			local top, bottom = centre + Vector3.new(0, 2.4, 0), floor + Vector3.new(0, 0.05, 0)
			Vfx.Clock.tween(0.2, nil, function(u)
				plane.CFrame = CFrame.new(top:Lerp(bottom, u))
			end, function()
				plane:Destroy()
			end)
		end)
	end
	Vfx.Clock.after(0.2, function()
		Cinema.outline(body, red, down + 0.6)
		Vfx.Rim.glow(body, red, down, { fill = 0.3, fadeIn = 0.4, fadeOut = 0.5 })
	end)
	-- the glitch: red blocks and lines flickering round the head and chest
	Vfx.Clock.after(0.2, function()
		local head = on(body, "Head", Vector3.zero, centre + Vector3.new(0, 1.5, 0))
		hold(head + Vector3.new(0, -0.6, 0), Vector3.new(2.6, 2.6, 2), {
			tex = "VfxChunk",
			grid = 2,
			fps = 0,
			startRandom = true,
			color = { { 0, Color3.fromRGB(255, 80, 80) }, { 1, red } },
			light = 1,
			bright = 2.2,
			size = { { 0, 0.22 }, { 1, 0.1 } },
			life = { 0.08, 0.2 },
			speed = { 0, 0.5 },
			spread = 180,
			rate = 70,
			z = 1.5,
		}, 0.9)
		hold(head + Vector3.new(0, -0.6, 0), Vector3.new(3, 3, 2), {
			tex = "VfxStreak",
			color = red,
			size = { { 0, 0.06 }, { 1, 0.02 } },
			squash = -3,
			life = { 0.06, 0.14 },
			speed = { 6, 12 },
			dir = Enum.NormalId.Right,
			spread = 4,
			face = "along",
			light = 1,
			bright = 2,
			rate = 40,
		}, 0.9)
	end)
	-- the burst, chaining (1.32 s into the acting): head, chest, belly
	for index, local_ in ipairs({ Vector3.new(0, 1.5, -0.3), Vector3.new(0, 0.3, -0.5), Vector3.new(0, -0.6, -0.5) }) do
		Vfx.Clock.after(1.02 + (index - 1) * 0.07, function()
			local at = on(body, "Torso", local_, centre)
			Vfx.Emit.burst(at, {
				{
					{
						tex = "VfxFlare",
						color = { { 0, WHITE }, { 1, ember } },
						size = { { 0, 0.5 }, { 0.2, 4 }, { 1, 0 } },
						life = 0.2,
						rot = { 0, 360 },
						bright = 2,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxStreak",
						color = { { 0, Color3.fromRGB(255, 220, 160) }, { 1, ember } },
						size = { { 0, 0.16 }, { 1, 0.03 } },
						squash = -2.2,
						life = { 0.25, 0.5 },
						speed = { 10, 22 },
						drag = 3,
						accel = Vector3.new(0, -25, 0),
						spread = 180,
						face = "along",
						light = 1,
						bright = 1.8,
					},
					24,
				},
			})
			Vfx.Light.flash(at, ember, 22, 4, 0.3)
			if index == 1 then
				Cinema.flash(red, 0.35, 0.3)
				Vfx.Screen.shakeAt(at, 0.4, 0.3)
			end
		end)
	end
	-- burning red to the floor
	Vfx.Clock.after(1.05, function()
		Vfx.Rim.glow(body, ember, down - 1.05 + 0.8, { fill = 0.55, fadeIn = 0.15, fadeOut = 0.8 })
		hold(on(body, "Torso", Vector3.zero, centre), Vector3.new(2, 3, 1.4), {
			tex = "VfxEmber",
			color = { { 0, Color3.fromRGB(255, 200, 140) }, { 1, red } },
			size = { { 0, 0.16 }, { 1, 0 } },
			life = { 0.6, 1.2 },
			speed = { 1, 4 },
			spread = 60,
			accel = Vector3.new(0, 5, 0),
			bright = 1.6,
			rate = 40,
		}, down - 1.05 + 0.6)
	end)
	Vfx.Clock.after(down, function()
		local at, ground = bodyNow(body, centre)
		Vfx.Ground.mark(ground, Vector3.yAxis, "VfxCrack", 5, Color3.fromRGB(60, 10, 14), 3, { fadeOut = 1.4 })
		hold(at, Vector3.new(2.4, 0.6, 3), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(50, 40, 42),
			light = 0,
			lit = 0.4,
			size = { { 0, 0.8 }, { 1, 2.8 } },
			alpha = { { 0, 0.5 }, { 0.6, 0.65 }, { 1, 1 } },
			life = { 1.4, 2 },
			speed = { 1, 2.5 },
			spread = 20,
			rot = { 0, 360 },
			rate = 9,
		}, 1.4)
	end)
end

-- A GOD.. IS NOT... AFRAID OF...: the boast in the chat, a cosmic glow on them; they come apart a segment at a time
-- (arms, legs, body, head) in magenta and cyan, a last pulse, and down in violet smoke.
FX.god = function(body, centre, _, _, _, hit)
	local magenta, cyan = Color3.fromRGB(255, 70, 220), Color3.fromRGB(70, 230, 255)
	local down = hit or 2.35
	DeathScreen.chat("A GOD DOES NOT FEAR DEATH!", cyan, 3.4)
	Vfx.Rim.glow(body, magenta, down, { fill = 0.25, fadeIn = 0.3, fadeOut = 0.6 })
	glowFor(centre + Vector3.new(0, 1, 0), magenta, 20, 2.4, down)
	hold(centre, Vector3.new(3, 5, 3), {
		tex = "VfxWisp",
		color = { { 0, cyan }, { 1, magenta } },
		size = { { 0, 0.2 }, { 0.4, 0.9 }, { 1, 0 } },
		alpha = { { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } },
		life = { 0.7, 1.2 },
		speed = { 1, 3 },
		spread = 30,
		accel = Vector3.new(0, 4, 0),
		rot = { 0, 360 },
		light = 1,
		bright = 1.8,
		rate = 30,
	}, down)
	local order = { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso", "Head" }
	for index, name in ipairs(order) do
		Vfx.Clock.after(0.6 + (index - 1) * 0.16, function()
			local at = on(body, name, Vector3.zero, centre)
			local color = if index % 2 == 0 then cyan else magenta
			Vfx.Emit.burst(at, {
				{
					{
						tex = "VfxFlare",
						color = { { 0, WHITE }, { 1, color } },
						size = { { 0, 0.4 }, { 0.2, 3.2 }, { 1, 0 } },
						life = 0.22,
						rot = { 0, 360 },
						bright = 2,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxChunk",
						grid = 2,
						fps = 0,
						startRandom = true,
						color = { { 0, color }, { 1, Color3.fromRGB(70, 20, 110) } },
						light = 0.8,
						lit = 0.3,
						size = { { 0, 0.26 }, { 1, 0.12 } },
						life = { 0.5, 0.9 },
						speed = { 4, 9 },
						spread = 180,
						accel = Vector3.new(0, -20, 0),
						rot = { 0, 360 },
						spin = { -400, 400 },
					},
					14,
				},
			})
			Vfx.Light.flash(at, color, 14, 3, 0.25)
			Vfx.Screen.shakeAt(at, 0.15, 0.12)
		end)
	end
	Vfx.Clock.after(1.48, function()
		local at = on(body, "Torso", Vector3.zero, centre)
		Vfx.Beams.wave(CFrame.new(at) * CFrame.Angles(math.rad(90), 0, 0), 0.5, 9, 0.5, {
			tex = "VfxRingBand",
			color = magenta,
			width = 0.7,
			light = 1,
			bright = 1.8,
		})
		Cinema.flash(magenta, 0.3, 0.35)
	end)
	Vfx.Clock.after(down, function()
		local at, ground = bodyNow(body, centre)
		Vfx.Beams.wave(CFrame.new(ground + Vector3.new(0, 0.1, 0)), 1, 8, 0.6, {
			tex = "VfxRingBand",
			color = cyan,
			width = 0.8,
			light = 0.8,
			bright = 1.4,
		})
		hold(at, Vector3.new(2.4, 0.6, 3), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(90, 40, 120),
			light = 0.3,
			lit = 0.4,
			size = { { 0, 1 }, { 1, 3.2 } },
			alpha = { { 0, 0.5 }, { 0.6, 0.65 }, { 1, 1 } },
			life = { 1.2, 1.8 },
			speed = { 1, 2.5 },
			spread = 25,
			rot = { 0, 360 },
			rate = 10,
		}, 1.2)
	end)
end

-- and I.. am..: the snap: a white flash over everything, a shockwave of light rolling out from the hand; the arm left
-- burnt, smoking and shedding embers as they stagger back and sit down.
FX.ironMan = function(body, centre, _, _, _, hit)
	local hand = on(body, "Right Arm", Vector3.new(0, -1, 0), centre)
	local gold = Color3.fromRGB(255, 226, 160)
	Cinema.flash(WHITE, 0.85, 0.9)
	Vfx.Light.flash(hand, WHITE, 60, 7, 0.6)
	Vfx.Beams.wave(CFrame.new(hand), 0.4, 46, 1.4, {
		tex = "VfxRingBand",
		color = gold,
		width = 1.6,
		light = 1,
		bright = 2,
	})
	Vfx.Emit.burst(hand, {
		tex = "VfxFlare",
		color = { { 0, WHITE }, { 1, gold } },
		size = { { 0, 0.6 }, { 0.2, 7 }, { 1, 0 } },
		life = 0.35,
		rot = { 0, 360 },
		bright = 2.4,
		z = 3,
	}, 1)
	Vfx.Screen.shakeAt(hand, 0.35, 0.4)
	local arm = body:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		local _, burnt = Vfx.Emit.hold(arm, {
			tex = "VfxEmber",
			color = { { 0, Color3.fromRGB(255, 210, 140) }, { 1, Color3.fromRGB(255, 90, 30) } },
			size = { { 0, 0.12 }, { 1, 0 } },
			life = { 0.5, 1.1 },
			speed = { 0.5, 2 },
			spread = 60,
			accel = Vector3.new(0, 3, 0),
			bright = 1.6,
			rate = 30,
		})
		local _, smoke = Vfx.Emit.hold(arm, {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(110, 104, 100),
			light = 0,
			lit = 0.5,
			size = { { 0, 0.4 }, { 1, 1.8 } },
			alpha = { { 0, 0.55 }, { 0.6, 0.7 }, { 1, 1 } },
			life = { 1.2, 1.8 },
			speed = { 0.6, 1.4 },
			spread = 15,
			accel = Vector3.new(0, 1.5, 0),
			rot = { 0, 360 },
			rate = 6,
		})
		Vfx.Clock.after(math.max(1.6, (hit or 2.9) - 0.2), burnt)
		Vfx.Clock.after((hit or 2.9) + 1.4, smoke)
	end
end

-- Let's dance!: blade mode. The picture drains cold and slows, 斬 slams on, red cut lines are drawn through them one
-- after another; the cuts land in four strokes (a red slash across the screen each), and they come apart at red edges.
FX.sam = function(body, centre, _, _, _, hit)
	local red = Color3.fromRGB(255, 34, 48)
	local land = 1.22 -- (1.62 s into the acting)
	local untint = Cinema.tint({ Saturation = -0.75, Contrast = 0.35, TintColor = Color3.fromRGB(190, 214, 255) }, 0.1)
	Vfx.Clock.after(land + 0.05, untint)
	Vfx.Clock.after(0.05, function()
		DeathScreen.glyph("斬", red, 0.95)
	end)
	local lines: { (fade: number?) -> () } = {}
	local rng = Random.new()
	for index = 1, 8 do
		Vfx.Clock.after(0.12 + index * 0.1, function()
			local mid = on(body, "Torso", Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-1.2, 1.4), 0), centre)
			local angle = rng:NextNumber(0, math.pi)
			local torso = body:FindFirstChild("Torso")
			local frame = if torso and torso:IsA("BasePart") then torso.CFrame.Rotation else CFrame.identity
			local dir =
				frame:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), rng:NextNumber(-0.3, 0.3)))
			local _, fade = Vfx.Beams.line(mid - dir * 2.4, mid + dir * 2.4, {
				tex = "VfxRingBand",
				color = red,
				width = 0.09,
				light = 1,
				bright = 2.4,
			})
			table.insert(lines, fade)
		end)
	end
	for stroke = 0, 3 do
		Vfx.Clock.after(land + stroke * 0.1, function()
			for _ = 1, 2 do
				local fade = table.remove(lines, 1)
				if fade then
					fade(0.12)
				end
			end
			local at = on(body, "Torso", Vector3.new(0, 0.4 - stroke * 0.4, -0.5), centre)
			Vfx.Emit.burst(at, {
				{
					{
						tex = "VfxFlare",
						color = { { 0, WHITE }, { 1, red } },
						size = { { 0, 0.3 }, { 0.2, 3 }, { 1, 0 } },
						life = 0.16,
						rot = { 0, 360 },
						bright = 2.2,
						z = 2,
					},
					1,
				},
				{
					{
						tex = "VfxStreak",
						color = { { 0, WHITE }, { 1, red } },
						size = { { 0, 0.12 }, { 1, 0.02 } },
						squash = -2.5,
						life = { 0.15, 0.3 },
						speed = { 14, 24 },
						drag = 3,
						spread = 180,
						face = "along",
						light = 1,
						bright = 2,
					},
					14,
				},
			})
			Cinema.slash(red, 0.55, 0.28, Vector2.new(0.5, 0.45), -35 + stroke * 50, if stroke % 2 == 0 then 1 else -1)
			Vfx.Screen.shakeAt(at, 0.25, 0.15)
		end)
	end
	Vfx.Clock.after(land, function()
		Vfx.Rim.glow(body, red, (hit or 2.2) - land + 0.6, { fill = 0.12, fadeIn = 0.05, fadeOut = 0.6 })
	end)
	Vfx.Clock.after(3, function()
		for _, fade in ipairs(lines) do
			fade(0.2)
		end
	end)
end

-- Walrider: four shots from the doorway (muzzle flashes, hits on the chest); on their back the swarm gathers, then
-- tears out of them: grey static boiling up at the lens, and the picture goes red.
FX.walrider = function(body, centre, _, _, _, hit)
	for index, at in ipairs({ 0, 0.25, 0.47, 0.73 }) do
		Vfx.Clock.after(at, function()
			shot(body, centre, if index == 1 then 1.2 else 0.9)
		end)
	end
	local tear = 2.95 -- (3.2 s into the acting)
	Vfx.Clock.after(math.max((hit or 1.5) + 0.5, 2.0), function()
		hold(on(body, "Torso", Vector3.zero, centre), Vector3.new(3, 1.2, 3.4), {
			tex = "VfxWisp",
			color = Color3.fromRGB(60, 60, 64),
			size = { { 0, 0.2 }, { 0.5, 0.7 }, { 1, 0 } },
			alpha = { { 0, 1 }, { 0.3, 0.3 }, { 1, 1 } },
			life = { 0.5, 0.9 },
			speed = { 0.5, 1.5 },
			spread = 180,
			rot = { 0, 360 },
			spin = { -200, 200 },
			light = 0,
			lit = 0.5,
			rate = 30,
		}, tear - 2.0)
	end)
	Vfx.Clock.after(tear, function()
		local chest = on(body, "Torso", Vector3.new(0, 0, -0.5), centre)
		local untint =
			Cinema.tint({ Saturation = -0.4, Contrast = 0.45, TintColor = Color3.fromRGB(255, 120, 120) }, 0.1)
		Vfx.Clock.after(1.5, untint)
		Cinema.flash(Color3.fromRGB(200, 0, 0), 0.5, 0.4)
		Vfx.Screen.shakeAt(chest, 0.6, 0.6)
		hold(chest, Vector3.new(1.4, 0.6, 1.4), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(28, 28, 30),
			light = 0,
			lit = 0.3,
			size = { { 0, 1 }, { 1, 3.4 } },
			alpha = { { 0, 0.2 }, { 0.6, 0.4 }, { 1, 1 } },
			life = { 0.5, 0.9 },
			speed = { 10, 18 },
			spread = 25,
			drag = 2,
			rot = { 0, 360 },
			spin = { -120, 120 },
			rate = 50,
			z = 1,
		}, 0.9)
		hold(chest, Vector3.new(1.4, 0.6, 1.4), {
			tex = "VfxDust",
			color = { { 0, Color3.fromRGB(220, 220, 224) }, { 1, Color3.fromRGB(90, 90, 96) } },
			size = { { 0, 0.14 }, { 1, 0.05 } },
			life = { 0.2, 0.5 },
			speed = { 14, 26 },
			spread = 30,
			light = 0.4,
			lit = 0.5,
			rate = 120,
		}, 0.9)
	end)
end

-- heh, didja really think-: the second slash lands (a red crescent across them, a red cut over the screen), a health
-- bar empties over their head; at the end they go to dust.
FX.sans = function(body, centre, _, head, _, hit)
	local red = Color3.fromRGB(255, 20, 30)
	local chest = on(body, "Torso", Vector3.new(0, 0.3, -0.6), centre)
	Vfx.Emit.burst(chest, {
		tex = "VfxCrescent",
		color = red,
		size = { { 0, 1.5 }, { 0.3, 4.8 }, { 1, 5.2 } },
		alpha = { { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } },
		life = 0.4,
		rot = { -50, -40 },
		light = 1,
		bright = 2.2,
		z = 3,
	}, 1)
	Cinema.slash(red, 0.6, 0.35, Vector2.new(0.5, 0.45), -40, 1)
	Vfx.Light.flash(chest, red, 14, 3, 0.25)
	if head then
		DeathScreen.bar(head, 1.6, 0.25)
	end
	local down = hit or 3
	Vfx.Clock.after(down - 0.35, function()
		Vfx.Rim.glow(body, Color3.fromRGB(230, 230, 236), 0.6, { fill = 0.55, fadeIn = 0.3, fadeOut = 0.3 })
	end)
	Vfx.Clock.after(down + 0.1, function()
		local at = bodyNow(body, centre)
		Vfx.Emit.burst(at, {
			{
				{
					tex = "VfxDust",
					color = { { 0, WHITE }, { 1, Color3.fromRGB(170, 170, 176) } },
					size = { { 0, 0.18 }, { 1, 0.08 } },
					life = { 0.8, 1.5 },
					speed = { 1, 4 },
					spread = 180,
					accel = Vector3.new(0, 1.5, 0),
					drag = 1,
					light = 0.2,
					lit = 0.6,
				},
				60,
			},
			{
				{
					tex = "VfxSmoke",
					grid = 8,
					mode = "OneShot",
					color = Color3.fromRGB(210, 210, 214),
					light = 0,
					lit = 0.6,
					size = { { 0, 1 }, { 1, 3 } },
					alpha = { { 0, 0.45 }, { 0.6, 0.7 }, { 1, 1 } },
					life = { 1, 1.6 },
					speed = { 0.5, 1.5 },
					spread = 60,
					rot = { 0, 360 },
				},
				8,
			},
		}, nil, Vector3.new(2.4, 0.8, 3))
	end)
end

-- A true patriot: one shot from far off; white flowers lift round them on the wind as they go down, and a gust of
-- petals when they lie in them (the grave and the salute come after, Presenters/Death and Shared/Cinema/DeathCuts).
FX.patriot = function(body, centre, floor, _, _, hit)
	shot(body, centre, 1)
	local down = hit or 2.4
	local petal = {
		tex = "VfxChunk",
		grid = 2,
		fps = 0,
		startRandom = true,
		color = { { 0, WHITE }, { 1, Color3.fromRGB(236, 236, 228) } },
		light = 0.2,
		lit = 0.7,
		size = { { 0, 0.16 }, { 1, 0.12 } },
		life = { 1.6, 2.6 },
		speed = { 0.5, 1.6 },
		spread = 40,
		accel = Vector3.new(2.2, 0.6, 0.8),
		drag = 0.6,
		rot = { 0, 360 },
		spin = { -200, 200 },
		rate = 26,
	}
	hold(floor + Vector3.new(0, 0.3, 0), Vector3.new(9, 0.3, 9), table.clone(petal), down + 1.8)
	Vfx.Clock.after(down, function()
		local _, ground = bodyNow(body, centre)
		local gust = table.clone(petal)
		gust.speed = { 3, 7 }
		gust.spread = 70
		gust.accel = Vector3.new(2, -1.5, 0.6)
		Vfx.Emit.burst(ground + Vector3.new(0, 0.3, 0), gust, 40, Vector3.new(3, 0.3, 3.4))
	end)
end

-- Plays the custom death `style` on `body` (a falling character), if there is one by that name. `timing.hit`: seconds
-- from now until the body hits the floor (Shared/Anim/DeathTiming), where the impact of a fall, a crushing or a breaking
-- lands.
function CustomDeaths.play(style: string?, body: Model?, timing: { hit: number? }?)
	local fx = if style then FX[style] else nil
	if not fx or not body then
		return
	end
	local torso = body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart")
	local head = body:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local centre = torso.Position
	fx(
		body,
		centre,
		floorOf(body, centre),
		if head and head:IsA("BasePart") then head else nil,
		if torso:IsA("BasePart") then torso else nil,
		if timing and timing.hit and timing.hit > 0 then timing.hit else nil
	)
end

-- (for checks: the styles there are)
function CustomDeaths.styles(): { string }
	local list = {}
	for name in pairs(FX) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return CustomDeaths
