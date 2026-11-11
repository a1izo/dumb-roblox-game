-- Struck by lightning (10 s; remade 2026-11-11 as a scene death). A bare hilltop in a storm (the set:
-- maps/venues/scenes/remade.py lightning; the sky: SkySceneStorm), a lone dead oak beside the victim, rain driving
-- across. Lightning flickers in the clouds; the victim looks up into the rain, a hand lifting (the air prickling, sparks
-- crawling in the hair); the bolt: out of the sky into them in a white flash, the frame burning out; thrown rigid and
-- arched, arcs of current crawling over them; limp, down on the back; smoke rising off them, the oak burning.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local BOLT = Color3.fromRGB(214, 228, 255)
local ARC = Color3.fromRGB(150, 196, 255)
local STRUCK = 3.85

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({ size = Vector3.new(80, 1, 80), at = Vector3.new(0, -0.5, 0), color = Color3.fromRGB(56, 62, 50) })
	end
	local sky = ctx:light(Vector3.new(0, 60, -30), BOLT, 140, 0)
	ctx:light(Vector3.new(8, 10, 10), Color3.fromRGB(96, 108, 136), 40, 0.45)
	-- rain driving across the hill, and the wind with it
	SceneDeaths.emit(ctx, Vector3.new(-6, 18, -2), Vector3.new(50, 1, 40), {
		tex = "VfxStreak",
		color = Color3.fromRGB(196, 206, 222),
		size = { { 0, 0.05 }, { 1, 0.05 } },
		squash = -6,
		face = "along",
		alpha = { { 0, 0.5 }, { 1, 0.7 } },
		life = { 0.35, 0.5 },
		speed = { 70, 90 },
		dir = Enum.NormalId.Bottom,
		spread = 6,
		accel = Vector3.new(60, 0, 0),
		lit = 0.7,
		rate = 650,
	})
	local rain = Sfx.play("rainLoop", { looped = true, volume = 0.6 })
	if rain then
		table.insert(ctx.cleanups, function()
			rain:Destroy()
		end)
	end
	-- lightning in the clouds: a flicker of the sky light, a far bolt, thunder after it
	local function flicker(strength: number)
		sky.Brightness = 6 * strength
		ctx:tween(sky, 0.25, { Brightness = 0 })
		Cinema.flash(BOLT, 0.12 * strength, 0.2)
	end
	for _, spec in ipairs({ { 0.7, -60, -140, 0.6 }, { 2.3, 90, -180, 0.8 } }) do
		ctx:at(spec[1], function()
			flicker(spec[4])
			local top = ctx:world(Vector3.new(spec[2], 140, spec[3]))
			Vfx.Beams.bolt(
				top,
				ctx:world(Vector3.new(spec[2] * 0.8, -20, spec[3] * 0.9)),
				0.22,
				{ color = BOLT, width = 1.6, jag = 18, pieces = 12, bright = 3 }
			)
			task.delay(1.0, Sfx.play, "thunder", { volume = 0.6 * spec[4] })
		end)
	end

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneLightningVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", Vector3.new(0, 4.5, 0))
	end
	local function chest(): Vector3
		return at("Torso", Vector3.new(0, 3, 0))
	end

	-- the air prickling: sparks crawling in the hair, on the raised hand
	ctx:during(2.8, STRUCK, function(_t)
		if math.random() < 0.35 then
			local h = victim and ctx:limb(victim, "Head")
			local hand = victim and ctx:limb(victim, "Right Arm")
			local on = if math.random() < 0.6 then h else hand
			if on then
				local p = on.Position
					+ Vector3.new(math.random() - 0.5, (if on == h then 0.6 else -0.9), math.random() - 0.5)
				Vfx.Beams.bolt(
					p,
					p + Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5),
					0.08,
					{ color = ARC, width = 0.05, jag = 0.15, pieces = 4, bright = 3 }
				)
			end
		end
	end)

	-- the bolt
	ctx:at(STRUCK, function()
		local h = victim and ctx:limb(victim, "Head")
		local hit = if h then h.Position + Vector3.new(0, 0.6, 0) else ctx:world(Vector3.new(0, 5, 0))
		Vfx.Beams.bolt(
			hit + Vector3.new(14, 220, -30),
			hit,
			0.35,
			{ color = BOLT, width = 2.4, jag = 9, pieces = 14, bright = 4 }
		)
		Vfx.Beams.bolt(
			hit + Vector3.new(-10, 180, -20),
			hit,
			0.25,
			{ color = BOLT, width = 1.0, jag = 7, pieces = 10, bright = 3 }
		)
		sky.Brightness = 12
		ctx:tween(sky, 0.6, { Brightness = 0 })
		Vfx.Light.flash(hit, BOLT, 60, 14, 0.5)
		Cinema.flash(Color3.new(1, 1, 1), 1, 0.35)
		Vfx.Screen.shake(2.5, 0.8)
		Sfx.play("thunder", { volume = 1.2, pitch = 1.1 })
		-- the ground where they stand: a scorch ring and a burst of sparks
		Vfx.Beams.wave(
			CFrame.new(ctx:world(Vector3.new(0, 0.1, 0))),
			0.5,
			9,
			0.5,
			{ color = BOLT, width = 1.2, bright = 3 }
		)
		Vfx.Emit.burst(hit, {
			tex = "Spark",
			color = { { 0, Color3.new(1, 1, 1) }, { 1, ARC } },
			size = { { 0, 0.16 }, { 1, 0.04 } },
			squash = -2,
			face = "along",
			life = { 0.4, 0.9 },
			speed = { 14, 30 },
			drag = 2,
			accel = Vector3.new(0, -30, 0),
			spread = 180,
			light = 1,
			bright = 3,
		}, 90)
		-- the oak beside them catches
		local trunk =
			ctx:part({ size = Vector3.new(0.2, 0.2, 0.2), at = Vector3.new(-5, 7.5, -3), alpha = 1, cast = false })
		Vfx.Recipes.flame(trunk, { kind = "fire", scale = 3.2, color = Color3.fromRGB(255, 150, 70) } :: any)
	end)
	-- the frame burning out on the strike: a negative-white grade for a breath
	ctx:grade(STRUCK, STRUCK + 0.22, { Saturation = -1, Contrast = 0.9, Brightness = 0.35 }, 0.02)
	-- current crawling over the body while it shakes
	ctx:during(STRUCK + 0.05, 5.6, function(_t)
		if not victim or math.random() < 0.3 then
			return
		end
		local names = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
		local a = ctx:limb(victim, names[math.random(#names)])
		local b = ctx:limb(victim, names[math.random(#names)])
		if a and b and a ~= b then
			Vfx.Beams.bolt(
				a.Position,
				b.Position,
				0.09,
				{ color = ARC, width = 0.12, jag = 0.5, pieces = 6, bright = 3 }
			)
		end
	end)
	-- smoke off the body once it lies
	ctx:at(6.6, function()
		local torso = victim and ctx:limb(victim, "Torso")
		if torso then
			Vfx.Emit.make(torso, {
				tex = "VfxSmoke",
				grid = 8,
				startRandom = true,
				color = Color3.fromRGB(70, 70, 76),
				size = { { 0, 0.6 }, { 1, 2.6 } },
				alpha = { { 0, 0.5 }, { 1, 1 } },
				life = { 1.6, 2.6 },
				speed = { 1, 2 },
				spread = 20,
				accel = Vector3.new(3, 2, 0),
				lit = 0.8,
				rate = 8,
			})
		end
	end)
	ctx:at(7.4, function()
		flicker(0.7)
		task.delay(0.8, Sfx.play, "thunder", { volume = 0.5 })
	end)

	-- cameras
	-- 0.0 low from down the hill: the oak and the figure against the storm
	ctx:camera(0, 2.0, function(t)
		local u = t / 2.0
		return CFrame.lookAt(Vector3.new(10 - 2 * u, -2.2, 15 - 3 * u), Vector3.new(-2, 7.5, -2)), 34
	end)
	-- 2.0 the face from below, looking up into the rain; the hand rising
	ctx:camera(2.0, STRUCK - 0.12, function(t)
		local u = (t - 2.0) / (STRUCK - 2.12)
		local h = head()
		return CFrame.lookAt(h + Vector3.new(0.9 - 0.3 * u, -1.6, -2.3 + 0.3 * u), h + Vector3.new(0, 0.7, 0)), 38
	end)
	-- the strike from far off: the whole bolt out of the sky into the hilltop
	ctx:shot(STRUCK - 0.12, Vector3.new(4, 6, -46), Vector3.new(0, 30, 0), 44)
	-- 4.1 close round the arched body, the arcs crawling over it, slow
	ctx:camera(STRUCK + 0.25, 5.7, function(t)
		local u = (t - STRUCK - 0.25) / (5.7 - STRUCK - 0.25)
		local a = math.rad(30 - 70 * u)
		local c = chest() + Vector3.new(0, 0.6, 0)
		return CFrame.lookAt(c + Vector3.new(math.sin(a) * 5, -0.6, -math.cos(a) * 5), c), 36
	end)
	-- 5.7 from the side: limp, down on the back
	ctx:camera(5.7, 7.4, function(t)
		local u = (t - 5.7) / 1.7
		return CFrame.lookAt(Vector3.new(6.5, 2.4 - 0.6 * u, 1.2), Vector3.new(0, 2 - 1.3 * u, 0.8)), 38
	end)
	-- 7.4 rising high over the hilltop: the body smoking in the rain, the oak burning
	ctx:camera(7.4, 10, function(t)
		local u = smooth((t - 7.4) / 2.6)
		return CFrame.lookAt(Vector3.new(4 + 6 * u, 5 + 14 * u, 9 + 12 * u), Vector3.new(-1.5, 0.5, 0)), 40
	end)
	ctx:grade(0, nil, { Saturation = -0.45, Contrast = 0.18, TintColor = Color3.fromRGB(206, 214, 236) }, 0.1)
end

return { length = 10, build = build }
