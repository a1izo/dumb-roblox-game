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
