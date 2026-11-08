--!strict
-- The deaths' own effects, beat by beat (the user's ask of 2026-11-07: "vfx fitting them ... and maybe make them more
-- dramatic"): each death's acting (art/scripts/deaths.py) gets effects on its own moments, read off where the body is at
-- that moment (the chest, the mouth, the hands, the feet, the floor under them), layered over a custom death's own
-- effect (Presentation/CustomDeaths) and the death cutscene's burst and chalk line (Presenters/Death); and each death
-- style's acting (fallen.py) gets more of its own on top of its effect (Presentation/Styles.death).
--
--   DeathVfx.play("collapseHeart", body, startedAt)    -- startedAt: the os.clock() time the clip started
--   DeathVfx.style("strings", body, moments)           -- as Presentation/Fallen starts a style's acting
--
-- In the world only (a 3D view in the shop draws no particles); lighter on Low graphics (Vfx.quiet).

local Vfx = require(script.Parent.Vfx)
local Cinema = require(script.Parent.Cinema)

local DeathVfx = {}

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(214, 28, 44)
local DUST = Color3.fromRGB(176, 168, 156)

type Body = {
	model: Model,
	torso: BasePart?,
	head: BasePart?,
	state: { [string]: any }, -- (what one beat leaves for a later one, per play)
}
type Beat = { at: number, fn: (Body) -> () }

-- Points on the body, now.
local function partOf(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") and p.Parent then p else nil
end

local function point(model: Model, name: string, local_: Vector3, fallback: Vector3?): Vector3
	local p = partOf(model, name)
	if p then
		return p.CFrame:PointToWorldSpace(local_)
	end
	return fallback or model:GetPivot().Position
end

local function chest(b: Body): Vector3
	return point(b.model, "Torso", Vector3.new(0, 0.3, -0.55))
end
local function middle(b: Body): Vector3
	return point(b.model, "Torso", Vector3.zero)
end
local function mouth(b: Body): Vector3
	return point(b.model, "Head", Vector3.new(0, -0.15, -0.6))
end
local function headAt(b: Body): Vector3
	return point(b.model, "Head", Vector3.zero)
end
local function hand(b: Body, side: number): Vector3
	return point(b.model, if side > 0 then "Right Arm" else "Left Arm", Vector3.new(0, -1, 0))
end
local function foot(b: Body, side: number): Vector3
	return point(b.model, if side > 0 then "Right Leg" else "Left Leg", Vector3.new(0, -1, 0))
end
local function floorUnder(b: Body, at: Vector3): Vector3
	return Vfx.Ground.at(at, { b.model }, 8)
end

-- Little recipes ----------------------------------------------------------------------------------------------------

local function glow(at: Vector3, color: Color3, size: number, life: number, light: number?)
	Vfx.Emit.burst(at, {
		tex = "VfxGlow",
		color = color,
		size = { { 0, size * 0.25 }, { 0.3, size }, { 1, size * 0.4 } },
		alpha = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } },
		life = life,
		light = 1,
		bright = 1.8,
		z = 2,
	}, 1)
	if light then
		Vfx.Light.flash(at, color, size * 3, light, life)
	end
end

local function puff(
	at: Vector3,
	color: Color3,
	size: number,
	count: number,
	speed: number,
	dir: Vector3?,
	life: number?
)
	local spec = {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = color,
		light = 0,
		lit = 0.6,
		size = { { 0, size * 0.4 }, { 1, size } },
		alpha = { { 0, 0.35 }, { 0.6, 0.6 }, { 1, 1 } },
		life = { (life or 0.8) * 0.8, life or 0.8 },
		speed = { speed * 0.6, speed },
		spread = 35,
		drag = 2,
		rot = { 0, 360 },
		spin = { -30, 30 },
	}
	if dir then
		local cf = CFrame.lookAt(at, at + dir)
		Vfx.Emit.burst(cf * CFrame.Angles(math.rad(-90), 0, 0), spec, count)
	else
		Vfx.Emit.burst(at, spec, count)
	end
end

local function dust(b: Body, at: Vector3, scale: number)
	local floor = floorUnder(b, at)
	Vfx.Emit.burst(floor + Vector3.new(0, 0.2, 0), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = DUST,
		light = 0,
		lit = 0.7,
		size = { { 0, 0.6 * scale }, { 1, 2.2 * scale } },
		alpha = { { 0, 0.45 }, { 0.6, 0.7 }, { 1, 1 } },
		life = { 0.7, 1.1 },
		speed = { 2 * scale, 5 * scale },
		spread = { 180, 8 },
		drag = 3,
		rot = { 0, 360 },
	}, math.floor(8 * scale + 0.5), Vector3.new(1.4, 0.2, 1.4) * scale)
end

local function sparks(at: Vector3, color: Color3, count: number, speed: number?)
	Vfx.Emit.burst(at, {
		tex = "VfxStreak",
		color = color,
		size = { { 0, 0.14 }, { 1, 0.03 } },
		squash = -2,
		life = { 0.18, 0.4 },
		speed = { (speed or 12) * 0.6, speed or 12 },
		drag = 3,
		accel = Vector3.new(0, -30, 0),
		spread = 180,
		face = "along",
		light = 1,
		bright = 1.6,
	}, count)
end

local function bits(at: Vector3, color: Color3, count: number, speed: number, size: number?)
	Vfx.Emit.burst(at, {
		tex = "VfxChunk",
		grid = 2,
		fps = 0,
		startRandom = true,
		color = color,
		light = 0.2,
		lit = 0.6,
		size = { { 0, size or 0.18 }, { 1, (size or 0.18) * 0.7 } },
		life = { 0.6, 1.0 },
		speed = { speed * 0.5, speed },
		spread = 70,
		accel = Vector3.new(0, -32, 0),
		rot = { 0, 360 },
		spin = { -400, 400 },
	}, count)
end

local function ring(b: Body, at: Vector3, color: Color3, from: number, to: number, seconds: number, width: number?)
	local floor = floorUnder(b, at)
	Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.08, 0)), from, to, seconds, {
		tex = "VfxRingBand",
		color = color,
		width = width or 0.8,
		light = 0.6,
		bright = 1.2,
	})
end

-- A hard ring of light round the body, upright (a pulse through it).
local function pulse(at: Vector3, color: Color3, to: number, seconds: number)
	Vfx.Beams.wave(CFrame.new(at) * CFrame.Angles(math.rad(90), 0, 0), 0.4, to, seconds, {
		tex = "VfxRingBand",
		color = color,
		width = 0.5,
		light = 1,
		bright = 1.6,
	})
end

-- Keeps calling `fn` every `every` seconds from now for `seconds` (on Vfx's clock, so it holds on a freeze frame).
local function during(seconds: number, every: number, fn: () -> ())
	local left, wait = seconds, 0
	Vfx.Clock.every(function(dt: number)
		left -= dt
		wait -= dt
		if wait <= 0 then
			wait += every
			fn()
		end
		return left > 0 -- (the clock drops a job whose step returns false)
	end)
end

local function screenFlash(color: Color3, brightness: number, seconds: number)
	Vfx.Screen.flash(color, brightness, seconds)
end

-- The deaths ------------------------------------------------------------------------------------------------------

local BEATS: { [string]: { Beat } } = {}

-- Heart attack: the seizure is a red pulse through the chest (and a red still frame), a weaker one as he gasps, dust
-- under the stepping foot and the knees, a dark thud as the body lands, a last breath.
BEATS.collapseHeart = {
	{
		at = 0.14,
		fn = function(b)
			glow(chest(b), RED, 3.4, 0.4, 3)
			pulse(chest(b), RED, 4.5, 0.45)
			Cinema.still(RED, 0.09)
		end,
	},
	{
		at = 0.5,
		fn = function(b)
			glow(chest(b), RED, 2.2, 0.35, 1.6)
			pulse(chest(b), RED, 3, 0.35)
		end,
	},
	{
		at = 0.8,
		fn = function(b)
			dust(b, foot(b, 1), 0.5)
		end,
	},
	{
		at = 1.38,
		fn = function(b)
			dust(b, middle(b), 0.8)
		end,
	},
	{
		at = 1.65,
		fn = function(b)
			dust(b, middle(b), 1.1)
			Vfx.Light.flash(middle(b), Color3.fromRGB(120, 10, 20), 14, 2.5, 0.6)
			Vfx.Screen.shakeAt(middle(b), 0.25, 0.25)
		end,
	},
	{
		at = 2.25,
		fn = function(b)
			puff(mouth(b), Color3.fromRGB(220, 220, 226), 0.8, 2, 1.2, nil, 0.9)
		end,
	},
}

-- Disease: each cough a puff of sick breath from the mouth, a sickly haze about them, dust as they sit down hard and as
-- they go over, a sick green light dying out.
local SICK = Color3.fromRGB(150, 160, 112)
BEATS.collapseDisease = {
	{
		at = 0.1,
		fn = function(b)
			during(2.2, 0.28, function()
				puff(middle(b), SICK, 2.6, 1, 0.6, nil, 1.6)
			end)
		end,
	},
}
for _, t in ipairs({ 0.14, 0.42, 0.7, 0.97 }) do
	table.insert(BEATS.collapseDisease, {
		at = t,
		fn = function(b)
			local head = partOf(b.model, "Head")
			local dir = if head then head.CFrame.LookVector else Vector3.new(0, 0, -1)
			puff(mouth(b), SICK, 1.4, 4, 4, dir, 0.7)
		end,
	})
end
table.insert(BEATS.collapseDisease, {
	at = 2.06,
	fn = function(b)
		dust(b, middle(b), 0.8)
	end,
})
table.insert(BEATS.collapseDisease, {
	at = 2.89,
	fn = function(b)
		dust(b, middle(b), 1.0)
		Vfx.Light.flash(middle(b), Color3.fromRGB(120, 140, 70), 12, 1.6, 1.4)
	end,
})

-- Accident: a splash where the foot slips, a white crack of light as the head hits the floor (the screen jolts), dust
-- as the legs come down.
local WATER = Color3.fromRGB(160, 200, 230)
BEATS.collapseAccident = {
	{
		at = 0.27,
		fn = function(b)
			local at = foot(b, 1)
			ring(b, at, WATER, 0.3, 2.6, 0.5, 0.5)
			Vfx.Emit.burst(floorUnder(b, at) + Vector3.new(0, 0.2, 0), {
				tex = "VfxDust",
				color = WATER,
				size = { { 0, 0.18 }, { 1, 0.08 } },
				life = { 0.4, 0.7 },
				speed = { 5, 10 },
				spread = { 50, 30 },
				accel = Vector3.new(0, -40, 0),
				light = 0.3,
				lit = 0.6,
			}, 14)
		end,
	},
	{
		at = 0.7,
		fn = function(b)
			local at = headAt(b)
			Vfx.Recipes.impact(
				CFrame.new(floorUnder(b, at)),
				{ color = WHITE, scale = 0.55, ground = true, shake = true }
			)
			screenFlash(WHITE, 0.35, 0.12)
			dust(b, at, 0.8)
		end,
	},
	{
		at = 0.98,
		fn = function(b)
			dust(b, foot(b, 1):Lerp(foot(b, -1), 0.5), 0.6)
		end,
	},
}

-- A long fall: a scuff at the toe that catches, the air rushing past as they come down, the floor answering hard (a
-- crack, a ring of dust, the screen jolting).
BEATS.deathFall = {
	{
		at = 0.42,
		fn = function(b)
			dust(b, foot(b, 1), 0.4)
		end,
	},
	{
		at = 0.5,
		fn = function(b)
			during(0.42, 0.05, function()
				local at = middle(b)
				Vfx.Emit.burst(at, {
					tex = "VfxStreak",
					color = Color3.fromRGB(220, 224, 232),
					size = { { 0, 0.1 }, { 1, 0.02 } },
					squash = -4,
					alpha = { { 0, 0.5 }, { 1, 1 } },
					life = 0.18,
					speed = { 18, 24 },
					dir = Enum.NormalId.Top,
					spread = 12,
					face = "along",
					light = 0.6,
				}, 3, Vector3.new(2, 2, 2))
			end)
		end,
	},
	{
		at = 0.95,
		fn = function(b)
			local at = middle(b)
			Vfx.Ground.mark(floorUnder(b, at), Vector3.yAxis, "VfxCrack", 8, Color3.fromRGB(40, 38, 42), 3, {
				fadeOut = 1.5,
			})
			ring(b, at, DUST, 1, 9, 0.7, 1.2)
			dust(b, at, 1.6)
			Vfx.Screen.shakeAt(at, 0.6, 0.35)
		end,
	},
}

-- A broken heart: a red glow gathering in the chest as the hands come to it; each beat a pulse; the crack a hard red
-- flash and still, red flecks falling like ash after it, and the light in the chest going out.
BEATS.deathHeart = {
	{
		at = 0.55,
		fn = function(b)
			glow(chest(b), RED, 1.6, 0.6, 1)
		end,
	},
	{
		at = 0.9,
		fn = function(b)
			pulse(chest(b), RED, 3.5, 0.4)
		end,
	},
	{
		at = 1.22,
		fn = function(b)
			pulse(chest(b), RED, 5, 0.5)
			Vfx.Screen.shakeAt(chest(b), 0.15, 0.2)
		end,
	},
	{
		at = 1.6,
		fn = function(b)
			Cinema.still(RED, 0.1)
			sparks(chest(b), Color3.fromRGB(255, 120, 130), 10, 9)
			during(1.6, 0.12, function()
				Vfx.Emit.burst(chest(b) + Vector3.new(0, 1.2, 0), {
					tex = "VfxEmber",
					color = RED,
					size = { { 0, 0.12 }, { 1, 0 } },
					life = { 1.2, 1.8 },
					speed = { 0.3, 0.8 },
					accel = Vector3.new(0, -2, 0),
					spread = 180,
					light = 1,
					bright = 1.4,
				}, 2, Vector3.new(2, 1, 2))
			end)
		end,
	},
	{
		at = 2.58,
		fn = function(b)
			dust(b, middle(b), 0.9)
		end,
	},
}

-- Frozen where they stood: the breath fogging as they shiver; ice glinting up the body as the frost climbs; a cold
-- flash as it sets; the floor cracking with frost as the statue hits.
local ICE = Color3.fromRGB(190, 228, 255)
BEATS.deathFrost = {
	{
		at = 0.25,
		fn = function(b)
			during(1.1, 0.34, function()
				local head = partOf(b.model, "Head")
				local dir = if head then head.CFrame.LookVector + Vector3.new(0, 0.3, 0) else Vector3.yAxis
				puff(mouth(b), Color3.fromRGB(235, 242, 250), 0.9, 2, 1.6, dir, 0.9)
			end)
		end,
	},
	{
		at = 0.9,
		fn = function(b)
			local k = 0
			during(0.6, 0.1, function()
				k += 1
				local spot = foot(b, 1):Lerp(headAt(b), math.min(1, k / 6)) + Vector3.new(0, 0, 0)
				Vfx.Recipes.twinkle(spot + Vector3.new((k % 2) - 0.5, 0, 0), { color = ICE, scale = 0.6 })
			end)
		end,
	},
	{
		at = 1.5,
		fn = function(b)
			glow(middle(b), ICE, 4, 0.5, 2.5)
		end,
	},
	{
		at = 2.45,
		fn = function(b)
			local at = middle(b)
			ring(b, at, ICE, 1, 8, 0.6, 1)
			Vfx.Screen.shakeAt(at, 0.45, 0.3)
		end,
	},
}

-- The chandelier: dust trickling down at the creak; the crush a heavy cloud, the screen jolting hard, glass skittering
-- over the floor and glinting.
local GOLD = Color3.fromRGB(255, 226, 160)
BEATS.deathChandelier = {
	{
		at = 0.2,
		fn = function(b)
			local top = headAt(b) + Vector3.new(0, 7, 0)
			during(0.7, 0.1, function()
				Vfx.Emit.burst(top, {
					tex = "VfxDust",
					color = DUST,
					size = { { 0, 0.1 }, { 1, 0.06 } },
					life = { 0.5, 0.8 },
					speed = { 1, 3 },
					dir = Enum.NormalId.Bottom,
					accel = Vector3.new(0, -20, 0),
					spread = 20,
					lit = 0.6,
				}, 3, Vector3.new(2.5, 0.2, 2.5))
			end)
		end,
	},
	{
		at = 0.95,
		fn = function(b)
			local at = middle(b)
			dust(b, at, 2)
			Vfx.Screen.shakeAt(at, 0.9, 0.4)
			screenFlash(GOLD, 0.3, 0.12)
			bits(floorUnder(b, at) + Vector3.new(0, 0.3, 0), GOLD, 20, 10, 0.16)
		end,
	},
	{
		at = 1.3,
		fn = function(b)
			for k = 1, 3 do
				local at = middle(b) + Vector3.new(math.cos(k * 2.1) * 1.6, -0.3, math.sin(k * 2.1) * 1.6)
				Vfx.Clock.after(k * 0.18, function()
					Vfx.Recipes.twinkle(at, { color = GOLD, scale = 0.7 })
				end)
			end
		end,
	},
}

-- Drowned on dry land: bubbles from the mouth as they claw; a blue light rippling over them like light through water
-- while they reach for the surface; a ring and a splash of droplets as they come down.
local SEA = Color3.fromRGB(110, 190, 240)
BEATS.deathDrown = {
	{
		at = 0.22,
		fn = function(b)
			during(0.8, 0.2, function()
				Vfx.Emit.burst(mouth(b), {
					tex = "VfxCircle",
					color = Color3.fromRGB(200, 236, 255),
					size = { { 0, 0.08 }, { 1, 0.2 } },
					alpha = { { 0, 0.3 }, { 0.8, 0.4 }, { 1, 1 } },
					life = { 0.8, 1.3 },
					speed = { 1.5, 3 },
					dir = Enum.NormalId.Top,
					spread = 25,
					light = 0.4,
					lit = 0.5,
				}, 3)
			end)
		end,
	},
	{
		at = 1.0,
		fn = function(b)
			local t = 0
			during(1.9, 0.08, function()
				t += 0.08
				local over = headAt(b) + Vector3.new(math.sin(t * 7) * 0.8, 3, math.cos(t * 5) * 0.8)
				Vfx.Light.flash(over, SEA, 10, 0.9 + 0.5 * math.sin(t * 11), 0.12)
			end)
		end,
	},
	{
		at = 3.12,
		fn = function(b)
			local at = middle(b)
			ring(b, at, SEA, 0.8, 7, 0.9, 0.9)
			Vfx.Emit.burst(floorUnder(b, at) + Vector3.new(0, 0.3, 0), {
				tex = "VfxDust",
				color = SEA,
				size = { { 0, 0.16 }, { 1, 0.06 } },
				life = { 0.5, 0.8 },
				speed = { 6, 11 },
				spread = { 40, 40 },
				accel = Vector3.new(0, -40, 0),
				light = 0.4,
			}, 20)
		end,
	},
}

-- Struck by lightning: static pricking at the head before it; the current crawling over the body in arcs while it
-- shakes, a blue edge on it; sparks thrown off as it lets go and smoke curling off the body; one last spark at the hand.
local COLD = Color3.fromRGB(200, 226, 255)
BEATS.deathLightning = {
	{
		at = 0.3,
		fn = function(b)
			during(0.25, 0.08, function()
				sparks(headAt(b) + Vector3.new(0, 0.6, 0), COLD, 2, 4)
			end)
		end,
	},
	{
		at = 0.58,
		fn = function(b)
			Vfx.Rim.glow(b.model, COLD, 0.5, { fill = 0.25, fadeIn = 0.05, fadeOut = 0.3 })
			local names = { "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
			local k = 0
			during(0.56, 0.07, function()
				k += 1
				local a = names[(k % #names) + 1]
				local z = names[((k * 3) % #names) + 1]
				if a ~= z then
					Vfx.Beams.bolt(point(b.model, a, Vector3.zero), point(b.model, z, Vector3.zero), 0.08, {
						color = COLD,
						width = 0.18,
						bright = 2,
						light = 1,
						pieces = 6,
						jag = 0.5,
						rate = 30,
					})
				end
				Vfx.Light.flash(middle(b), COLD, 12, 2 + (k % 3), 0.06)
			end)
		end,
	},
	{
		at = 1.14,
		fn = function(b)
			sparks(middle(b), COLD, 16, 14)
			during(2.0, 0.25, function()
				puff(middle(b) + Vector3.new(0, 0.3, 0), Color3.fromRGB(70, 68, 72), 1.2, 1, 1.2, Vector3.yAxis, 1.4)
			end)
		end,
	},
	{
		at = 2.4,
		fn = function(b)
			sparks(hand(b, 1), COLD, 6, 6)
		end,
	},
}

-- A thousand paper cuts: each cut a thin red slit of light across the body and torn scraps of paper; the pages
-- scattering over the floor as it goes down.
local PAPER = Color3.fromRGB(240, 234, 214)
BEATS.deathPages = {}
for k, t in ipairs({ 0.66, 0.9, 1.1, 1.32, 1.52 }) do
	table.insert(BEATS.deathPages, {
		at = t,
		fn = function(b)
			local at = middle(b) + Vector3.new(0, (k % 3) * 0.5 - 0.2, 0)
			local across = Vector3.new(math.cos(k * 1.7), math.sin(k * 0.9) * 0.6, math.sin(k * 1.7)).Unit
			local _, fade = Vfx.Beams.line(at - across * 1.3, at + across * 1.3, {
				color = Color3.fromRGB(255, 70, 80),
				width = 0.08,
				bright = 2,
				light = 1,
			})
			Vfx.Clock.after(0.12, function()
				fade(0.15)
			end)
			bits(at, PAPER, 6, 7, 0.14)
		end,
	})
end
table.insert(BEATS.deathPages, {
	at = 2.42,
	fn = function(b)
		local at = middle(b)
		bits(floorUnder(b, at) + Vector3.new(0, 0.5, 0), PAPER, 16, 6, 0.2)
		dust(b, at, 0.8)
	end,
})

-- Burned from within: flame bursting up off the head as it is thrown back screaming; embers dropping off the body as it
-- staggers; a lick of fire and a shower of embers where it lands.
local FIRE = Color3.fromRGB(255, 140, 60)
BEATS.deathBurn = {
	{
		at = 0.72,
		fn = function(b)
			Vfx.Emit.burst(headAt(b), {
				tex = "VfxFlame",
				grid = 8,
				fps = 40,
				startRandom = true,
				color = { { 0, Color3.fromRGB(255, 236, 180) }, { 0.4, FIRE }, { 1, Color3.fromRGB(70, 24, 10) } },
				size = { { 0, 0.9 }, { 0.4, 2.2 }, { 1, 0.6 } },
				alpha = { { 0, 0.3 }, { 0.7, 0.5 }, { 1, 1 } },
				life = { 0.4, 0.6 },
				speed = { 6, 10 },
				dir = Enum.NormalId.Top,
				spread = 15,
				light = 1,
				bright = 1.6,
			}, 6)
			Vfx.Light.flash(headAt(b), FIRE, 16, 3.5, 0.5)
		end,
	},
	{
		at = 0.95,
		fn = function(b)
			during(0.9, 0.08, function()
				Vfx.Emit.burst(middle(b), {
					tex = "VfxEmber",
					color = FIRE,
					size = { { 0, 0.12 }, { 1, 0 } },
					life = { 0.5, 0.9 },
					speed = { 1, 3 },
					accel = Vector3.new(0, -12, 0),
					spread = 180,
					light = 1,
					bright = 1.6,
				}, 3, Vector3.new(1.5, 2, 1))
			end)
		end,
	},
	{
		at = 2.39,
		fn = function(b)
			local at = middle(b)
			sparks(at, FIRE, 18, 10)
			Vfx.Light.flash(at, FIRE, 14, 2.5, 0.5)
			dust(b, at, 0.9)
		end,
	},
}

-- Choked on a potato chip: the crunch a gold flash of light at the eyes and a white flash of the screen (his moment);
-- crumbs sprayed from the mouth on each choking cough; a last glint as they lie still.
BEATS.deathChip = {
	{
		at = 0.62,
		fn = function(b)
			screenFlash(GOLD, 0.45, 0.14)
			Vfx.Recipes.twinkle(headAt(b) + Vector3.new(0.3, 0.2, -0.5), { color = GOLD, scale = 1.6 })
		end,
	},
	{
		at = 1.36,
		fn = function(b)
			bits(mouth(b), Color3.fromRGB(240, 200, 110), 8, 6, 0.12)
		end,
	},
	{
		at = 1.82,
		fn = function(b)
			bits(mouth(b), Color3.fromRGB(240, 200, 110), 8, 6, 0.12)
		end,
	},
	{
		at = 2.68,
		fn = function(b)
			dust(b, middle(b), 0.9)
		end,
	},
	{
		at = 3.1,
		fn = function(b)
			Vfx.Recipes.twinkle(headAt(b) + Vector3.new(0, 0.4, 0), { color = GOLD, scale = 0.8 })
		end,
	},
}

-- Their time ran out: each tick a pale ring through the floor and a tick of light, harder as they slow; the last one
-- a white flash, and still.
local PALE = Color3.fromRGB(236, 226, 196)
BEATS.deathClock = {}
for k, t in ipairs({ 1.0, 1.3, 1.62, 1.97, 2.35, 2.78 }) do
	table.insert(BEATS.deathClock, {
		at = t,
		fn = function(b)
			local at = middle(b)
			ring(b, at, PALE, 0.6, 2 + k * 0.6, 0.35, 0.4)
			Vfx.Light.flash(at, PALE, 8 + k, 1 + k * 0.3, 0.12)
		end,
	})
end
table.insert(BEATS.deathClock, {
	at = 3.25,
	fn = function(b)
		screenFlash(WHITE, 0.4, 0.2)
		glow(middle(b), PALE, 5, 0.5, 2)
	end,
})

-- Taken by the dark: shadow creeping in along the floor from behind as they look round; a black burst at the feet on
-- the yank; dark marks dragged over the floor on each pull; the dark swallowing them at the last.
local SHADOW = Color3.fromRGB(10, 8, 12)
BEATS.deathDark = {
	{
		at = 0.3,
		fn = function(b)
			local root = partOf(b.model, "HumanoidRootPart") or partOf(b.model, "Torso")
			local back = if root then root.CFrame.LookVector * -1 else Vector3.new(0, 0, 1)
			during(0.6, 0.08, function()
				local at = floorUnder(b, middle(b)) + back * 3 + Vector3.new(0, 0.3, 0)
				puff(at, SHADOW, 2, 1, 4, -back, 0.8)
			end)
		end,
	},
	{
		at = 0.8,
		fn = function(b)
			puff(foot(b, 1):Lerp(foot(b, -1), 0.5), SHADOW, 2.4, 6, 4, nil, 0.9)
		end,
	},
}
for _, t in ipairs({ 1.43, 1.9, 2.33, 2.82 }) do
	table.insert(BEATS.deathDark, {
		at = t,
		fn = function(b)
			local at = middle(b)
			Vfx.Ground.mark(floorUnder(b, at), Vector3.yAxis, "VfxCrack", 3, Color3.fromRGB(20, 16, 18), 4, {
				fadeOut = 1.5,
			})
			puff(at, SHADOW, 1.8, 3, 2, nil, 0.8)
		end,
	})
end
table.insert(BEATS.deathDark, {
	at = 2.85,
	fn = function(b)
		puff(middle(b), SHADOW, 4, 10, 3, nil, 1.4)
	end,
})

-- Plays a death's effects on `body` (the body playing the clip `clip`, which started at `startedAt`, os.clock()). A
-- beat already past by more than a moment is left out.
function DeathVfx.play(clip: string, body: Model?, startedAt: number?)
	local beats = BEATS[clip]
	if not beats or not body or not body:IsDescendantOf(workspace) then
		return
	end
	local b: Body = { model = body, state = {} }
	local started = startedAt or os.clock()
	for _, beat in ipairs(beats) do
		local delay = started + beat.at - os.clock()
		if delay > -0.08 then
			Vfx.Clock.after(math.max(0, delay), function()
				if body.Parent and body:IsDescendantOf(workspace) then
					local ok, err = pcall(beat.fn, b)
					if not ok then
						warn("[DeathsGambit] death effect " .. clip .. " at " .. beat.at .. ": " .. tostring(err))
					end
				end
			end)
		end
	end
end

-- The death styles: more on top of each style's own effect (Presentation/Styles.death), on its acting's moments.
local STYLES: { [string]: (b: Body, m: { [string]: number }) -> () } = {}

-- Cut Strings: a cold light from above finds the body as it is hauled up and holds while it dances; the strings'
-- snap a white flash; dust where the heap lands.
STYLES.strings = function(b, m)
	local snap = m.snap or 2.5
	Vfx.Clock.after(m.lift or 0.42, function()
		local over = headAt(b) + Vector3.new(0, 7, 0)
		Vfx.Light.flash(over, Color3.fromRGB(230, 236, 255), 18, 2.4, snap - (m.lift or 0.42))
	end)
	Vfx.Clock.after(snap, function()
		screenFlash(WHITE, 0.25, 0.1)
	end)
	Vfx.Clock.after(snap + 0.32, function()
		dust(b, middle(b), 1.0)
	end)
end

-- Murder of Crows: dark smoke rising off the body as it lifts; the burst a dark flash and a ring.
STYLES.crows = function(b, m)
	local burst = m.burst or 1.68
	Vfx.Clock.after(m.lift or 0.45, function()
		during(burst - (m.lift or 0.45), 0.1, function()
			puff(middle(b) + Vector3.new(0, -0.6, 0), Color3.fromRGB(16, 14, 20), 1.6, 1, 2, Vector3.yAxis, 1)
		end)
	end)
	Vfx.Clock.after(burst, function()
		pulse(middle(b), Color3.fromRGB(90, 70, 110), 6, 0.5)
		Vfx.Light.flash(middle(b), Color3.fromRGB(120, 90, 150), 16, 2, 0.4)
	end)
end

-- Petrified: grit falling off the body as the stone climbs; a grey ring as it sets; the screen jolting as it crumbles.
STYLES.stone = function(b, m)
	local set, crumble = m.set or 1.34, m.crumble or 2.3
	during(set, 0.15, function()
		Vfx.Emit.burst(middle(b), {
			tex = "VfxDust",
			color = Color3.fromRGB(150, 146, 138),
			size = { { 0, 0.12 }, { 1, 0.05 } },
			life = { 0.4, 0.7 },
			speed = { 0.5, 2 },
			accel = Vector3.new(0, -20, 0),
			spread = 180,
			lit = 0.6,
		}, 3, Vector3.new(2, 2, 2))
	end)
	Vfx.Clock.after(set, function()
		ring(b, middle(b), Color3.fromRGB(160, 156, 150), 0.6, 5, 0.5, 0.6)
	end)
	Vfx.Clock.after(crumble, function()
		Vfx.Screen.shakeAt(middle(b), 0.5, 0.35)
		dust(b, middle(b), 1.6)
	end)
end

-- Shattered: a cold light inside the glass growing as it rises; thin cracks of light flickering over it before it
-- breaks; a white flash as it shatters.
STYLES.glass = function(b, m)
	local look, shatter = m.look or 1.42, m.shatter or 1.86
	during(shatter, 0.1, function()
		Vfx.Light.flash(middle(b), Color3.fromRGB(190, 220, 255), 10, 1.2, 0.12)
	end)
	Vfx.Clock.after(look + 0.15, function()
		during(shatter - look - 0.15, 0.06, function()
			local at = middle(b) + Vector3.new(math.random() - 0.5, math.random() * 2 - 0.6, math.random() - 0.5)
			sparks(at, WHITE, 1, 2)
		end)
	end)
	Vfx.Clock.after(shatter, function()
		screenFlash(Color3.fromRGB(220, 236, 255), 0.35, 0.12)
		Vfx.Screen.shakeAt(middle(b), 0.35, 0.25)
	end)
end

-- Ash to Ash: embers rising off the body through its last try; an ember-orange edge on it; dust as it sinks.
STYLES.ash = function(b, m)
	local give, crumble = m.give or 0.92, m.crumble or 1.15
	during(crumble + 0.6, 0.08, function()
		Vfx.Emit.burst(middle(b), {
			tex = "VfxEmber",
			color = FIRE,
			size = { { 0, 0.1 }, { 1, 0 } },
			life = { 0.8, 1.4 },
			speed = { 1, 2.5 },
			accel = Vector3.new(0, 3, 0),
			spread = 60,
			light = 1,
			bright = 1.4,
		}, 2, Vector3.new(1.6, 1.4, 1.6))
	end)
	Vfx.Rim.glow(b.model, Color3.fromRGB(255, 120, 50), crumble, { fill = 0.12, fadeIn = 0.4, fadeOut = 0.4 })
	Vfx.Clock.after(give, function()
		dust(b, middle(b), 0.7)
	end)
end

-- Plays a death style's own extra effects on the fallen `body`, as its acting starts (`moments`: DeathTiming.fallen).
function DeathVfx.style(style: string?, body: Model?, moments: { [string]: number }?)
	local fn = if style then STYLES[style] else nil
	if not fn or not body or not body:IsDescendantOf(workspace) then
		return
	end
	local b: Body = { model = body, state = {} }
	local ok, err = pcall(fn, b, moments or {})
	if not ok then
		warn("[DeathsGambit] death effect " .. tostring(style) .. ": " .. tostring(err))
	end
end

-- (for checks: the clips and styles with effects of their own)
function DeathVfx.covered(): ({ string }, { string })
	local clips, styles = {}, {}
	for name in pairs(BEATS) do
		table.insert(clips, name)
	end
	for name in pairs(STYLES) do
		table.insert(styles, name)
	end
	table.sort(clips)
	table.sort(styles)
	return clips, styles
end

return DeathVfx
