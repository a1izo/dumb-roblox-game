-- Frozen where they stood (12 s; remade 2026-11-11 as a scene death). A frozen lake at night under the stars (the
-- set: maps/venues/scenes/remade.py frost; the sky: SkySceneNight), bare trees along its snowy shores, snow falling.
-- The victim's last two steps out onto the ice; a look down: frost climbing their boots; a foot that will not come
-- up; hugging themselves, shaking, their breath fogging; one hand reaching out ahead as the shaking slows; then the
-- ice has all of them: a statue of clear ice, frozen in the reach, alone on the lake. No words, no faces.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local ICE = Color3.fromRGB(196, 226, 246)
local FROST = Color3.fromRGB(226, 240, 252)
-- when the ice closes over each part (scene seconds: from, to)
local CLIMB = {
	["Left Leg"] = { 2.4, 4.4 },
	["Right Leg"] = { 2.5, 4.6 },
	Torso = { 4.8, 7.6 },
	["Left Arm"] = { 6.4, 8.4 },
	["Right Arm"] = { 7.2, 8.9 },
	Head = { 8.1, 9.2 },
}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({
			size = Vector3.new(150, 0.6, 150),
			at = Vector3.new(0, -0.3, 0),
			color = Color3.fromRGB(120, 150, 170),
			material = Enum.Material.Ice,
		})
	end
	-- the moon's cold light from high ahead, a faint fill behind
	ctx:light(Vector3.new(-14, 34, -30), Color3.fromRGB(176, 200, 236), 80, 1.1)
	ctx:light(Vector3.new(6, 6, 10), Color3.fromRGB(110, 130, 170), 24, 0.35)
	-- snow falling slow and slanting
	SceneDeaths.emit(ctx, Vector3.new(0, 18, -2), Vector3.new(50, 1, 50), {
		tex = "Snowflake",
		color = Color3.fromRGB(236, 242, 250),
		size = { { 0, 0.12 }, { 1, 0.1 } },
		alpha = { { 0, 0.15 }, { 0.85, 0.3 }, { 1, 1 } },
		life = { 4, 6 },
		speed = { 3, 5 },
		dir = Enum.NormalId.Bottom,
		spread = 12,
		accel = Vector3.new(1.2, -0.4, 0.4),
		rot = { 0, 360 },
		spin = { -40, 40 },
		lit = 0.8,
		rate = 160,
	})
	-- a low drift of powder blowing over the ice
	SceneDeaths.emit(ctx, Vector3.new(-10, 0.3, -2), Vector3.new(2, 0.4, 40), {
		tex = "VfxSmoke",
		grid = 8,
		startRandom = true,
		color = FROST,
		size = { { 0, 1.2 }, { 1, 3.2 } },
		alpha = { { 0, 1 }, { 0.3, 0.86 }, { 1, 1 } },
		life = { 3, 4.5 },
		speed = { 4, 7 },
		dir = Enum.NormalId.Right,
		spread = 10,
		lit = 0.8,
		rate = 6,
	})

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneFrostVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", Vector3.new(0, 4.5, -0.7))
	end

	-- the breath: a puff of fog from the mouth on every breath, quicker as they shake, gone when they freeze
	for _, t in ipairs({ 0.4, 1.6, 2.9, 3.8, 4.6, 5.3, 5.9, 6.5, 7.1, 7.8, 8.6 }) do
		ctx:at(t, function()
			local h = victim and ctx:limb(victim, "Head")
			if h then
				Vfx.Emit.burst(h.Position + h.CFrame.LookVector * 0.7 - Vector3.new(0, 0.2, 0), {
					tex = "VfxSmoke",
					grid = 8,
					startRandom = true,
					color = FROST,
					size = { { 0, 0.2 }, { 1, 1.1 } },
					alpha = { { 0, 0.55 }, { 1, 1 } },
					life = { 0.9, 1.4 },
					speed = { 0.6, 1.2 },
					spread = 20,
					accel = Vector3.new(0, 0.6, 0),
					lit = 0.8,
				}, 4)
			end
		end)
	end

	-- the ice: a skin of clear ice over every part, closing from the feet up; frost crystals pricking out of it
	local shells: { { part: BasePart, from: number, to: number } } = {}
	ctx:at(2.3, function()
		if not victim then
			return
		end
		for name, span in pairs(CLIMB) do
			local limb = ctx:limb(victim, name)
			if limb then
				local grow = if name == "Head" then 1.14 else 1.1
				local shell = ctx:attach(victim, name, {
					size = limb.Size * grow,
					at = Vector3.zero,
					color = ICE,
					alpha = 1,
					name = "Ice",
				})
				if shell then
					shell.Material = Enum.Material.Glass
					shell.Reflectance = 0.25
					shell.CastShadow = false
					table.insert(shells, { part = shell, from = span[1], to = span[2] })
				end
			end
		end
	end)
	ctx:during(2.3, 12, function(t)
		for _, s in ipairs(shells) do
			s.part.Transparency = 1 - 0.62 * smooth((t - s.from) / (s.to - s.from))
		end
	end)
	-- crystals: little pale spikes standing out of the ice on each part as it closes
	for name, span in pairs(CLIMB) do
		ctx:at(span[2] - 0.3, function()
			if not victim then
				return
			end
			local limb = ctx:limb(victim, name)
			if not limb then
				return
			end
			local rng = Random.new(#name * 31)
			for _ = 1, if name == "Torso" then 7 else 4 do
				local h = limb.Size / 2
				local spike = ctx:attach(victim, name, {
					size = Vector3.new(0.08, rng:NextNumber(0.3, 0.6), 0.08),
					at = Vector3.new(rng:NextNumber(-h.X, h.X), rng:NextNumber(-h.Y, h.Y), -h.Z - 0.05),
					rot = Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-60, 60)),
					color = FROST,
					alpha = 0.2,
					name = "Crystal",
				})
				if spike then
					spike.Material = Enum.Material.Glass
					spike.CastShadow = false
				end
			end
			Vfx.Emit.burst(limb.Position, {
				tex = "VfxGlow",
				color = FROST,
				size = { { 0, 0.18 }, { 1, 0 } },
				life = { 0.4, 0.8 },
				speed = { 0.5, 2 },
				spread = 180,
				light = 1,
				bright = 2,
			}, 8)
		end)
	end
	-- frozen solid: a white glint across them, a crack of the ice under the feet
	ctx:at(9.25, function()
		local torso = victim and ctx:limb(victim, "Torso")
		if torso then
			Vfx.Light.flash(torso.Position, FROST, 14, 5, 0.6)
			Vfx.Recipes.twinkle(
				torso.Position + Vector3.new(0.4, 1.3, -0.6),
				{ color = Color3.new(1, 1, 1), scale = 1.4 }
			)
		end
		Cinema.flash(Color3.fromRGB(220, 236, 255), 0.25, 0.4)
	end)

	-- cameras
	-- 0.0 low across the ice: the last steps toward the lens, snow blowing, the trees on the shore behind
	ctx:camera(0, 2.5, function(t)
		local u = t / 2.5
		return CFrame.lookAt(Vector3.new(5 - 1.5 * u, 1.3, -15 + 3 * u), Vector3.new(0, 3.2, -0.6)), 36
	end)
	-- 2.5 down at the boots: the ice climbing them
	ctx:camera(2.5, 4.3, function(t)
		local u = (t - 2.5) / 1.8
		return CFrame.lookAt(Vector3.new(1.4 - 0.5 * u, 0.7 + 0.5 * u, -3.4), Vector3.new(0, 0.9 + 0.6 * u, -0.7)), 38
	end)
	ctx:focus(2.5, 4.3, 3.0, 3)
	-- 4.3 the struggle, from in front and a little above
	ctx:camera(4.3, 5.7, function(t)
		local u = (t - 4.3) / 1.4
		return CFrame.lookAt(Vector3.new(-2.8 + u, 4.4, -6.5), Vector3.new(0, 2.9, -0.7)), 38
	end)
	-- 5.7 round them, close, as they shake and the ice closes over the chest
	ctx:camera(5.7, 7.9, function(t)
		local u = (t - 5.7) / 2.2
		local a = math.rad(-40 + 80 * smooth(u))
		local c = Vector3.new(0, 3.4, -0.7)
		return CFrame.lookAt(c + Vector3.new(math.sin(a) * 4.2, 0.6, -math.cos(a) * 4.2), c), 34
	end)
	-- 7.9 the face as the ice reaches it, the hand reaching past the lens
	ctx:camera(7.9, 9.5, function(t)
		local u = (t - 7.9) / 1.6
		local h = head()
		return CFrame.lookAt(h + Vector3.new(0.9, -0.2, -2.4 + 0.4 * u), h + Vector3.new(0, -0.1, 0)), 30
	end)
	-- 9.5 pulling back and up: a statue of ice alone on the lake
	ctx:camera(9.5, 12, function(t)
		local u = smooth((t - 9.5) / 2.5)
		return CFrame.lookAt(Vector3.new(2 + 4 * u, 3.5 + 9 * u, -6 - 30 * u), Vector3.new(0, 3, -0.7)), 34 + 6 * u
	end)
	ctx:grade(0, nil, { Saturation = -0.35, Contrast = 0.14, TintColor = Color3.fromRGB(206, 224, 255) }, 0.1)
	ctx:grade(9.25, nil, { Saturation = -0.55, Contrast = 0.18, TintColor = Color3.fromRGB(200, 222, 255) }, 1.0)
end

return { length = 12, build = build }
