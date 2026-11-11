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
