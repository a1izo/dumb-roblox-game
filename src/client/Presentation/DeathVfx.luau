--!strict
-- The deaths' own effects, beat by beat (the user's ask of 2026-11-07: "vfx fitting them ... and maybe make them more
-- dramatic"): each death's acting (art/scripts/deaths.py) gets effects on its own moments, read off where the body is at
-- that moment (the chest, the mouth, the hands, the feet, the floor under them), layered over a custom death's own
-- effect (Presentation/CustomDeaths) and the death cutscene's burst and chalk line (Presenters/Death).
--
--   DeathVfx.play("collapseHeart", body, startedAt)    -- startedAt: the os.clock() time the clip started
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

local GOLD = Color3.fromRGB(255, 226, 160)

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

return DeathVfx
