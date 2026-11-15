-- Their time ran out (11 s; remade 2026-11-11 as a scene death, the clock remade 2026-11-15: the user, "make the clock
-- more high quality ... and make it better altogether"). A colossal clock lying in a grey void (the set:
-- maps/venues/scenes/remade.py clock: an enamel dial in a moulded brass bezel, serif numerals, a railroad track, a brass
-- boss over the hands; the sky: SkySceneVoid), a great pendulum swinging in the fog behind, gears turning round it,
-- sand falling from above in thin streams. The victim stands on the boss at the clock's middle looking at their
-- wristwatch; the blued hands sweep round under their feet; then time moves only in ticks: each tick jumps the world
-- (the hands, the pendulum, the gears, the falling sand, the dust, the victim, the camera) into its next moment and
-- holds it there, the ticks further and further apart; at the last one they are stopped dead mid-stride, the dial
-- cracks under them, the colour goes out of them, and they run out as sand, pouring off the boss's edge. No words, no
-- faces.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local ModelLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local TICKS = { 2.7, 3.25, 3.9, 4.65, 5.55, 6.6 }
local STOP = 7.4
local HAND = Color3.fromRGB(26, 30, 48)
local SAND = Color3.fromRGB(190, 184, 170)
local BRASS = Color3.fromRGB(226, 190, 120)
-- the top of the brass boss over the hands, where the victim stands (remade.py clock: 2.38), and where on it
local BOSS = 2.38
local STAND = Vector3.new(0, BOSS, 1.2)
-- the hands: their model (Core), reach to the tip and tail behind the arbor (props_scenes.CLOCK_HANDS), the height of
-- their middle over the dial, and a plain stand-in's width before the import holds them
local HANDS = {
	hour = { model = "SceneClockHourHand", length = 21, tail = 4.2, y = 0.5, width = 1.6, color = HAND },
	minute = { model = "SceneClockMinuteHand", length = 31, tail = 5.2, y = 1.0, width = 1.0, color = HAND },
	second = {
		model = "SceneClockSecondHand",
		length = 32.5,
		tail = 8,
		y = 1.42,
		width = 0.3,
		color = Color3.fromRGB(150, 30, 34),
	},
}
-- the pendulum: where it hangs from (behind the victim, past the rim, so it swings across the back of the tick
-- shots), how far it swings, its period
local PENDULUM_AT = Vector3.new(0, 64, 56)
local SWING, PERIOD = math.rad(13), 2.0

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The world's own time: running until the first tick, then only on the ticks (each jumps it to that moment).
local function shown(t: number): number
	if t < TICKS[1] then
		return t
	end
	local last = TICKS[1]
	for _, tick in ipairs(TICKS) do
		if t >= tick then
			last = tick
		end
	end
	return last
end

-- A model's point (in its own frame, at its pivot) measured once: the middle of its box and its size.
local function measure(model: Model): (CFrame, Vector3)
	model:PivotTo(CFrame.identity)
	return model:GetBoundingBox()
end

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({
			size = Vector3.new(4, 68, 68),
			at = Vector3.new(0, -2, 0),
			rot = Vector3.new(0, 0, 90),
			color = Color3.fromRGB(220, 218, 212),
			shape = "Cylinder",
		})
		ctx:part({
			size = Vector3.new(0.6, 8, 8),
			at = Vector3.new(0, BOSS - 0.3, 0),
			rot = Vector3.new(0, 0, 90),
			color = BRASS,
			material = Enum.Material.Metal,
			shape = "Cylinder",
		})
	end
	-- the light: high and cold from the front-left, a warm low rim from behind (the brass catches it), a soft fill
	ctx:light(Vector3.new(10, 40, -20), Color3.fromRGB(236, 236, 240), 120, 0.9)
	ctx:light(Vector3.new(-14, 10, 30), Color3.fromRGB(255, 214, 160), 60, 0.6)
	ctx:light(Vector3.new(4, 9, -6), Color3.fromRGB(220, 224, 236), 18, 0.35)

	-- the hands: the blued hour and minute hands and the red second hand turning on the arbor under the boss
	local hands: { [string]: (angle: number) -> () } = {}
	for name, spec in pairs(HANDS) do
		local model = ModelLibrary.get(spec.model)
		if model then
			local box, size = measure(model)
			-- (the arbor in the model's own frame: the tail end of its box, back by the tail)
			local arbor = Vector3.new(box.X, box.Y, box.Z + size.Z / 2 - spec.tail)
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CastShadow = true
					-- (its own colour under the texture: when Roblox is slow with a new texture the hand shows
					-- blued steel, not the plain grey seen in the place on 2026-11-15)
					p.Color = spec.color
					p.Material = Enum.Material.Metal
				end
			end
			model.Parent = ctx.stage.folder
			hands[name] = function(angle: number)
				local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				local at = Vector3.new(0, spec.y, 0)
				model:PivotTo(ctx.origin * CFrame.lookAt(at, at + dir) * CFrame.new(-arbor))
			end
		else
			local p = ctx:part({
				size = Vector3.new(spec.width, 0.24, spec.length + spec.tail),
				at = Vector3.new(0, spec.y, 0),
				color = spec.color,
				material = Enum.Material.Metal,
			})
			p.CastShadow = true
			hands[name] = function(angle: number)
				local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
				local mid = dir * ((spec.length - spec.tail) / 2) + Vector3.new(0, spec.y, 0)
				p.CFrame = ctx.origin * CFrame.lookAt(mid, mid + dir)
			end
		end
	end
	-- the time the clock shows: the second hand once round a minute of the world's time (12 at -Z, clockwise from
	-- above), the minute and hour hands creeping on from ten to two
	local function setHands(t: number)
		local s = shown(math.min(t, STOP)) * 6
		hands.second(s * math.pi * 2 / 12)
		hands.minute(s * math.pi * 2 / 160 + 1.0)
		hands.hour(s * math.pi * 2 / 900 + 3.4)
	end
	setHands(0)
	ctx:during(0, 11, setHands)

	-- the pendulum swinging in the fog behind, held between the ticks like everything else
	local pendulum = ModelLibrary.get("SceneClockPendulum")
	if pendulum then
		local box, size = measure(pendulum)
		local pivot = Vector3.new(box.X, box.Y + size.Y / 2 - 0.3, box.Z)
		for _, p in ipairs(pendulum:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
			end
		end
		for _, p in ipairs(pendulum:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = BRASS
				p.Material = Enum.Material.Metal
			end
		end
		pendulum.Parent = ctx.stage.folder
		local function swing(t: number)
			local a = SWING * math.sin(math.pi * 2 * shown(math.min(t, STOP)) / PERIOD + 0.6)
			pendulum:PivotTo(ctx.origin * CFrame.new(PENDULUM_AT) * CFrame.Angles(0, 0, a) * CFrame.new(-pivot))
		end
		swing(0)
		ctx:during(0, 11, swing)
	end

	-- gears turning in the fog round the clock, nearer than the set's still ones: each on its own axle, at its own
	-- speed, and only on the ticks once time stops running
	local gears = {}
	local rng = Random.new(2611)
	for k = 1, 7 do
		local model = ModelLibrary.get("RustGear")
		if not model then
			break
		end
		local a = (k / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		-- (a RustGear is 7.9 across: these 20 to 40, their near edge always 40+ out, clear of the 37.5 rim)
		local d = rng:NextNumber(62, 82)
		local at = Vector3.new(math.cos(a) * d, rng:NextNumber(-16, 24), math.sin(a) * d)
		model:ScaleTo(model:GetScale() * rng:NextNumber(2.5, 5))
		local box = measure(model)
		local facing = CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
			* CFrame.Angles(0, math.rad(rng:NextNumber(-40, 40)), 0)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CastShadow = false
			end
		end
		model.Parent = ctx.stage.folder
		table.insert(gears, {
			model = model,
			at = facing,
			hub = box.Position,
			speed = (if k % 2 == 0 then 1 else -1) * rng:NextNumber(0.12, 0.3),
		})
	end
	local function turnGears(t: number)
		local w = shown(math.min(t, STOP))
		for _, g in ipairs(gears) do
			-- (turning about the axle through the gear's middle: the RustGear stands on its edge, its axle along Z)
			g.model:PivotTo(ctx.origin * g.at * CFrame.Angles(0, 0, w * g.speed) * CFrame.new(-g.hub))
		end
	end
	turnGears(0)
	ctx:during(0, 11, turnGears)

	-- sand falling from far above in thin streams round them, and the dust in the air: both held still between ticks
	local held = {}
	for k = 1, 6 do
		local a = k * 1.3
		local e =
			SceneDeaths.emit(ctx, Vector3.new(math.cos(a) * 9, 40, math.sin(a) * 9 - 2), Vector3.new(0.4, 0.4, 0.4), {
				tex = "VfxDust",
				color = SAND,
				size = { { 0, 0.14 }, { 1, 0.1 } },
				life = { 2.6, 3 },
				speed = { 14, 16 },
				dir = Enum.NormalId.Bottom,
				spread = 1,
				lit = 0.8,
				rate = 60,
			})
		table.insert(held, e)
	end
	-- (where each stream lands on the dial: a little splash of sand)
	for k = 1, 6 do
		local a = k * 1.3
		local e =
			SceneDeaths.emit(ctx, Vector3.new(math.cos(a) * 9, 0.2, math.sin(a) * 9 - 2), Vector3.new(0.6, 0.1, 0.6), {
				tex = "VfxDust",
				color = SAND,
				size = { { 0, 0.1 }, { 1, 0.28 } },
				alpha = { { 0, 0.3 }, { 1, 1 } },
				life = { 0.4, 0.7 },
				speed = { 1, 2.5 },
				spread = 70,
				dir = Enum.NormalId.Top,
				accel = Vector3.new(0, -12, 0),
				lit = 0.8,
				rate = 30,
			})
		table.insert(held, e)
	end
	local dust = SceneDeaths.emit(ctx, Vector3.new(0, 6, -2), Vector3.new(26, 10, 26), {
		tex = "VfxGlow",
		color = Color3.fromRGB(236, 232, 222),
		size = { { 0, 0 }, { 0.2, 0.1 }, { 0.8, 0.08 }, { 1, 0 } },
		life = { 3, 5 },
		speed = { 0.05, 0.3 },
		spread = 180,
		rate = 16,
		bright = 0.8,
		light = 0.5,
	})
	table.insert(held, dust)
	ctx:during(TICKS[1], 11, function(t)
		local moving = false
		for _, tick in ipairs(TICKS) do
			if t >= tick and t < tick + 0.12 then
				moving = true
			end
		end
		for _, e in ipairs(held) do
			e.TimeScale = if moving then 1 else 0
		end
	end)

	-- the words engraved on the dial between the boss and VI: read from above with XII at the top
	local plate = ctx:part({
		size = Vector3.new(11, 0.05, 1.6),
		at = Vector3.new(0, 0.04, 18.9),
		alpha = 1,
		cast = false,
		name = "Motto",
	})
	local motto = ctx:text(plate, Enum.NormalId.Top, "MEMENTO MORI", Color3.fromRGB(96, 88, 78), Enum.Font.Merriweather)
	motto.TextScaled = true

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(STAND, STAND + Vector3.new(0, 0, -6)), "sceneClockVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", STAND + Vector3.new(0, 4.5, 0))
	end
	-- the wristwatch on the left wrist they look at (Core; nothing before its import)
	if victim then
		ctx:wear(victim, "wristwatch")
	end
	-- its crystal catches the light as they look
	ctx:at(0.7, function()
		local arm = victim and ctx:limb(victim, "Left Arm")
		if arm then
			Vfx.Recipes.twinkle((arm.CFrame * CFrame.new(0, -0.68, -0.72)).Position, { color = BRASS, scale = 0.5 })
		end
	end)

	-- the ticking: a hard tick on every half second of the sweep, then each tick of the stopped time louder and
	-- slower, a pale ring running out over the face from under them
	for k = 0, 4 do
		ctx:at(0.3 + k * 0.5, function()
			Sfx.play("clockTick", { volume = 0.4 })
		end)
	end
	for k, tick in ipairs(TICKS) do
		ctx:at(tick, function()
			Sfx.play("clockTick", { volume = 0.7 + k * 0.1, pitch = 1 - k * 0.07 })
			local feet = at("Torso", STAND)
			Vfx.Beams.wave(
				CFrame.new(ctx:world(Vector3.new(feet.X, 0.15, feet.Z))),
				1,
				10 + k * 3,
				0.5,
				{ color = Color3.fromRGB(236, 236, 240), width = 0.9, bright = 2 }
			)
			Cinema.flash(Color3.new(1, 1, 1), 0.12 + k * 0.03, 0.15)
			Vfx.Screen.shake(0.35 + k * 0.12, 0.18)
			local chest = ctx:world(at("Torso", STAND + Vector3.new(0, 3, 0)))
			Vfx.Emit.burst(chest, {
				tex = "VfxRing",
				color = { { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(200, 200, 210) } },
				size = { { 0, 1 }, { 1, 9 + k } },
				alpha = { { 0, 0.2 }, { 0.6, 0.55 }, { 1, 1 } },
				life = 0.45,
				bright = 1.6,
				z = 1,
			}, 1)
			-- (the second hand's tip, where it has jumped to)
			local s = shown(tick) * 6 * math.pi * 2 / 12
			local tip = ctx:world(Vector3.new(math.sin(s) * 31.5, 1.7, -math.cos(s) * 31.5))
			Vfx.Recipes.twinkle(tip, { color = Color3.fromRGB(255, 120, 120), scale = 1.4 })
		end)
	end
	-- stopped: the dial cracks under them, a grey shockwave runs out across the whole face, and the light drains
	ctx:at(STOP, function()
		local feet = at("Torso", STAND)
		Vfx.Beams.wave(
			CFrame.new(ctx:world(Vector3.new(feet.X, 0.2, feet.Z))),
			1,
			40,
			1.4,
			{ color = Color3.fromRGB(210, 210, 216), width = 2.4, bright = 2.4 }
		)
		Vfx.Ground.mark(
			ctx:world(Vector3.new(0, 0.12, 0)),
			Vector3.yAxis,
			"VfxCrack",
			26,
			Color3.fromRGB(40, 36, 32),
			4,
			{
				fadeIn = 0.25,
				transparency = 0.15,
			}
		)
		Vfx.Screen.shake(1.4, 0.4)
		Vfx.Screen.punch(-2, 0.3)
		Vfx.Light.flash(ctx:world(Vector3.new(0, 6, 0)), Color3.fromRGB(236, 236, 240), 40, 4, 0.8)
		Vfx.Emit.burst(ctx:world(STAND + Vector3.new(0, 0.2, 0)), {
			tex = "VfxDust",
			color = SAND,
			size = { { 0, 0.6 }, { 1, 2.2 } },
			alpha = { { 0, 0.4 }, { 1, 1 } },
			life = { 0.8, 1.4 },
			speed = { 3, 7 },
			drag = 3,
			spread = 85,
			rot = { 0, 360 },
			light = 0,
			lit = 1,
		}, 14)
	end)
	-- the sand they become pours off the boss's edge all round, a thin curtain onto the dial, for a while after
	SceneDeaths.emit(ctx, Vector3.new(0, BOSS - 0.3, 0), Vector3.new(8.2, 0.2, 8.2), {
		tex = "VfxDust",
		color = SAND,
		size = { { 0, 0.12 }, { 1, 0.08 } },
		life = { 0.5, 0.8 },
		speed = { 0.2, 0.6 },
		spread = 10,
		dir = Enum.NormalId.Bottom,
		accel = Vector3.new(0, -16, 0),
		lit = 0.8,
		rate = 240,
		shape = Enum.ParticleEmitterShape.Cylinder,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}, STOP + 1.3, 11)
	-- stopped: the colour goes out of them, then they run out as sand from the head down
	ctx:at(STOP, function()
		Sfx.play("clockTick", { volume = 1.2, pitch = 0.5 })
		if not victim then
			return
		end
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				local _, _, v = p.Color:ToHSV()
				ctx:tween(p, 0.8, { Color = Color3.fromHSV(0, 0, v * 0.75) })
				if p:IsA("MeshPart") and p.TextureID ~= "" then
					task.delay(0.5, function()
						p.TextureID = ""
					end)
				end
			end
		end
	end)
	ctx:at(STOP + 1.0, function()
		if not victim then
			return
		end
		local list = {}
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.Position.Y > b.Position.Y
		end)
		for i, p in ipairs(list) do
			task.delay((i - 1) / math.max(1, #list) * 1.4, function()
				if not p.Parent then
					return
				end
				Vfx.Emit.burst(p.Position, {
					tex = "VfxDust",
					color = SAND,
					size = { { 0, 0.14 }, { 1, 0.08 } },
					life = { 1.2, 2 },
					speed = { 0.2, 1 },
					spread = 180,
					accel = Vector3.new(0, -14, 0),
					lit = 0.8,
				}, 28, p.Size)
				ctx:tween(p, 0.4, { Transparency = 1 })
				for _, d in ipairs(p:GetDescendants()) do
					if d:IsA("Decal") then
						ctx:tween(d, 0.3, { Transparency = 1 })
					end
				end
			end)
		end
	end)

	-- cameras
	-- 0.0 close on the wristwatch they are looking at, the great clock out of focus beyond
	ctx:camera(0, 1.6, function(t)
		local w = at("Left Arm", STAND + Vector3.new(-0.5, 3, -0.8))
		local u = t / 1.6
		return CFrame.lookAt(w + Vector3.new(0.9 - 0.15 * u, 0.9, -1.6 + 0.2 * u), w + Vector3.new(0, -0.6, 0)), 34
	end)
	-- 1.6 straight down from high above: a tiny figure on the colossal clock, the hands sweeping under it; the picture
	-- turning slowly with the second hand
	ctx:camera(1.6, TICKS[1], function(t)
		local u = smooth((t - 1.6) / (TICKS[1] - 1.6))
		local a = -0.25 + 0.35 * u
		return CFrame.lookAt(
			Vector3.new(0.1, 52 - 18 * u, 0.2),
			Vector3.new(0, 0, 0),
			-- (XII at the top of the picture)
			Vector3.new(math.sin(a), 0, -math.cos(a))
		),
			40
	end)
	-- each tick a hard cut to a new, still angle
	local angles = {
		{ Vector3.new(-7, 3, -7), 32 },
		{ Vector3.new(6, 1.2, -5), 36 },
		{ Vector3.new(0, 9, -12), 34 },
		{ Vector3.new(-4, 2, 4), 38 },
		{ Vector3.new(5, 5, -9), 30 },
	}
	for k, spec in ipairs(angles) do
		ctx:shot(TICKS[k], function()
			return head() + spec[1]
		end, function()
			return head() + Vector3.new(0, -1.0, 0)
		end, spec[2])
	end
	-- the last tick: in on the face
	ctx:shot(TICKS[6], function()
		return head() + Vector3.new(0.6, -0.2, -2.2)
	end, function()
		return head()
	end, 30)
	-- stopped: rising slowly away as they run out into sand on the boss
	ctx:camera(STOP + 0.6, 11, function(t)
		local u = smooth((t - STOP - 0.6) / (11 - STOP - 0.6))
		local h = STAND + Vector3.new(0, 2.6, -1.9)
		return CFrame.lookAt(h + Vector3.new(3 + 6 * u, 3 + 18 * u, -6 - 10 * u), h), 36 + 6 * u
	end)
	-- (seen in the place: the white dial and the void washed the picture out; more contrast, a hair darker and warm, so
	-- the black numerals, the brass and the figure stand off the face)
	ctx:grade(0, nil, {
		Saturation = -0.4,
		Contrast = 0.26,
		Brightness = -0.05,
		TintColor = Color3.fromRGB(255, 243, 226),
	}, 0.1)
	ctx:grade(STOP, nil, { Saturation = -0.9, Contrast = 0.16 }, 0.6)
end

return { length = 11, build = build }
