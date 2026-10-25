--!strict
-- The custom deaths' effects (Shared/Cosmetics kind "reason", 2026-10-25): what the cause written in the Manual does
-- to the body as it falls, played on every screen by the death cutscene (Presenters/Death) a moment before the body
-- hits the floor. Each is layered from the VFX kit (Presentation/Vfx): a white-hot moment, a body of colour, the
-- floor answering, light thrown on the scene; none uses ink.
--
--   CustomDeaths.play("lightning", body)

local Vfx = require(script.Parent.Vfx)

local CustomDeaths = {}

local WHITE = Color3.new(1, 1, 1)

type Fx = (body: Model, centre: Vector3, floor: Vector3, head: BasePart?, torso: BasePart?) -> ()

local FX: { [string]: Fx } = {}

local function floorOf(body: Model, at: Vector3): Vector3
	local hit = Vfx.Ground.at(at, { body }, 8)
	return hit
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
FX.fall = function(_, _, floor)
	Vfx.Clock.after(0.25, function()
		Vfx.Recipes.slam(CFrame.new(floor), { color = Color3.fromRGB(200, 196, 190), scale = 0.75, shake = true })
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
FX.frost = function(body, centre, floor)
	local ice = Color3.fromRGB(180, 225, 255)
	Vfx.Rim.glow(body, ice, 0.6, { fill = 0.45, fadeIn = 0.45, fadeOut = 0.5 })
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
	Vfx.Clock.after(0.8, function()
		Vfx.Emit.burst(centre, {
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
		Vfx.Ground.mark(floor, Vector3.yAxis, "VfxCrack", 6, ice, 3, { fadeOut = 1.2 })
		Vfx.Light.flash(centre, ice, 16, 3, 0.4)
	end)
end

-- The chandelier: crystal and dust come down from above and land on them in a gold flash.
FX.chandelier = function(_, centre, floor)
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
	Vfx.Clock.after(0.5, function()
		Vfx.Recipes.slam(CFrame.new(floor), { color = gold, scale = 0.9, shake = true })
		Vfx.Emit.burst(centre - Vector3.new(0, 1.5, 0), {
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
FX.clock = function(_, centre, floor)
	local pale = Color3.fromRGB(230, 220, 190)
	local base = Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 0.06, 0)))
	local face = Vfx.Emit.make(base, {
		tex = "VfxCircle",
		color = pale,
		size = 0.1,
		alpha = { { 0, 1 }, { 0.1, 0.25 }, { 0.85, 0.25 }, { 1, 1 } },
		life = 1.8,
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
	Vfx.Clock.after(1.1, function()
		Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.1, 0)), 3, 9, 0.6, {
			tex = "VfxRingBand",
			color = pale,
			width = 1,
			light = 0.6,
			bright = 1.1,
		})
		Vfx.Light.flash(centre, pale, 14, 3, 0.4)
	end)
	Vfx.Clock.after(2.2, function()
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

-- Plays the custom death `style` on `body` (a falling character), if there is one by that name.
function CustomDeaths.play(style: string?, body: Model?)
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
		if torso:IsA("BasePart") then torso else nil
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
