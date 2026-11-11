-- A broken heart (12 s; remade 2026-11-11 as a scene death, the user's word of 2026-11-10 on the custom deaths:
-- "their scenarios, camera work, vfx, animation and everything SUCKS"). An old stone bridge over a canal at night in
-- the rain (the set: maps/venues/scenes/remade.py heart; the sky: SkySceneStorm), a lamp at the parapet. The victim
-- reads a letter held in both hands; it lands: a red light beats once in the chest, a hand flying to it; again, an
-- arch back, the letter let go to flutter down into the canal; the crack: red lines of light split across the chest
-- and the heart breaks into falling shards; doubled over, the knees go, down on the wet stones; the lamp gutters out.
-- No words, no faces: the letter's lines are scribbles.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local RED = Color3.fromRGB(230, 34, 48)
local DEEP = Color3.fromRGB(150, 10, 24)
local LAMP = Color3.fromRGB(255, 214, 160)
local BEAT1, BEAT2, CRACK = 4.5, 5.75, 6.6

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({ size = Vector3.new(60, 1, 9), at = Vector3.new(0, -0.5, 2), color = Color3.fromRGB(52, 54, 58) })
		ctx:part({ size = Vector3.new(60, 3, 0.9), at = Vector3.new(0, 1.5, -2.6), color = Color3.fromRGB(70, 70, 74) })
	end
	local lamp = ctx:light(Vector3.new(3.6, 8.6, -1.6), LAMP, 22, 1.6, true)
	ctx:light(Vector3.new(-6, 12, -20), Color3.fromRGB(120, 136, 170), 60, 0.5)
	-- the rain: streaks falling hard over the bridge, a haze of drops at the parapet and splashes on the stones
	SceneDeaths.emit(ctx, Vector3.new(0, 16, -2), Vector3.new(44, 1, 34), {
		tex = "VfxStreak",
		color = Color3.fromRGB(196, 206, 222),
		size = { { 0, 0.05 }, { 1, 0.05 } },
		squash = -6,
		face = "along",
		alpha = { { 0, 0.55 }, { 1, 0.75 } },
		life = { 0.35, 0.5 },
		speed = { 70, 90 },
		dir = Enum.NormalId.Bottom,
		spread = 4,
		lit = 0.7,
		rate = 700,
	})
	SceneDeaths.emit(ctx, Vector3.new(0, 0.1, 1.5), Vector3.new(20, 0.1, 8), {
		tex = "VfxRing",
		color = Color3.fromRGB(210, 220, 232),
		size = { { 0, 0.05 }, { 1, 0.5 } },
		alpha = { { 0, 0.4 }, { 1, 1 } },
		life = { 0.25, 0.4 },
		speed = { 0.01, 0.02 },
		dir = Enum.NormalId.Top,
		face = "flat",
		lit = 0.6,
		rate = 90,
	})
	local rain = Sfx.play("rainLoop", { looped = true, volume = 0.5 })
	if rain then
		table.insert(ctx.cleanups, function()
			rain:Destroy()
		end)
	end

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneHeartVictim")
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

	-- the letter in both hands: pale paper with lines of scribbled writing (no words)
	local letter: BasePart? = nil
	if victim then
		letter = ctx:attach(victim, "Right Arm", {
			size = Vector3.new(1.2, 0.02, 1.5),
			at = Vector3.new(-0.55, -1.15, -0.45),
			rot = Vector3.new(60, 0, 0),
			color = Color3.fromRGB(226, 222, 210),
			name = "Letter",
		})
		if letter then
			letter.Material = Enum.Material.SmoothPlastic
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.CanvasSize = Vector2.new(240, 300)
			gui.LightInfluence = 0.6
			gui.Parent = letter
			local rng = Random.new(1102)
			for k = 0, 9 do
				local y = 24 + k * 26
				local x = 18
				while x < 210 do
					local w = rng:NextInteger(12, 46)
					local stroke = Instance.new("Frame")
					stroke.BorderSizePixel = 0
					stroke.BackgroundColor3 = Color3.fromRGB(40, 44, 60)
					stroke.BackgroundTransparency = 0.15
					stroke.Position = UDim2.fromOffset(x, y + rng:NextInteger(-2, 2))
					stroke.Size = UDim2.fromOffset(math.min(w, 222 - x), 2)
					stroke.Rotation = rng:NextNumber(-3, 3)
					stroke.Parent = gui
					x += w + rng:NextInteger(5, 10)
				end
			end
		end
	end
	-- the letter let go on the second beat: it flutters down over the parapet into the canal
	ctx:at(BEAT2 + 0.05, function()
		if not letter then
			return
		end
		for _, item in ipairs(letter:GetChildren()) do
			if item:IsA("WeldConstraint") then
				item:Destroy()
			end
		end
		letter.Anchored = true
		local from = letter.CFrame
		local fall = ctx:world(Vector3.new(1.6, -15.8, -7.5))
		ctx:during(BEAT2 + 0.05, BEAT2 + 4.5, function(t)
			local u = (t - BEAT2 - 0.05) / 4.45
			local swing = math.sin(u * 14) * (1 - u) * 1.4
			local p = from.Position:Lerp(fall, u) + Vector3.new(swing, 0, math.cos(u * 11) * 0.6)
			p = Vector3.new(p.X, from.Position.Y + (fall.Y - from.Position.Y) * (u ^ 1.6), p.Z)
			if letter then
				letter.CFrame = CFrame.new(p) * CFrame.Angles(math.sin(u * 9) * 0.9, u * 6, math.cos(u * 7) * 0.7)
			end
		end)
	end)

	-- the heart: a red light in the chest that beats twice and cracks
	local glow: PointLight? = nil
	local core: BasePart? = nil
	if victim then
		core = ctx:attach(victim, "Torso", {
			size = Vector3.new(0.5, 0.5, 0.1),
			at = Vector3.new(0.25, 0.35, -0.52),
			color = RED,
			glow = true,
			alpha = 1,
			shape = "Ball",
			name = "Heart",
		})
		local torso = ctx:limb(victim, "Torso")
		if torso then
			local l = Instance.new("PointLight")
			l.Color = RED
			l.Range = 7
			l.Brightness = 0
			l.Parent = torso
			glow = l
		end
	end
	local function beat(strength: number)
		Sfx.play("heartbeat", { volume = 0.9 * strength })
		if core then
			core.Transparency = 0.1
			ctx:tween(core, 0.45, { Transparency = 0.65 })
		end
		if glow then
			glow.Brightness = 5 * strength
			ctx:tween(glow, 0.5, { Brightness = 0.8 * strength })
		end
		Cinema.flash(DEEP, 0.18 * strength, 0.35)
	end
	ctx:at(BEAT1, function()
		beat(0.7)
	end)
	ctx:at(BEAT2, function()
		beat(1)
	end)
	-- the crack: red lines of light split across the chest, the heart bursts into falling shards
	ctx:at(CRACK, function()
		Sfx.play("heartbeat", { volume = 1, pitch = 0.8 })
		local torso = victim and ctx:limb(victim, "Torso")
		if torso and victim then
			local rng = Random.new(66)
			for k = 1, 9 do
				local a = rng:NextNumber(0, math.pi * 2)
				local len = rng:NextNumber(0.35, 0.8)
				local line = ctx:attach(victim, "Torso", {
					size = Vector3.new(len, 0.05, 0.03),
					at = Vector3.new(0.25 + math.cos(a) * len * 0.5, 0.35 + math.sin(a) * len * 0.5, -0.53),
					rot = Vector3.new(0, 0, math.deg(a)),
					color = RED,
					glow = true,
					name = "Crack",
				})
				if line then
					line.Transparency = 1
					task.delay((k - 1) * 0.03, function()
						line.Transparency = 0
						ctx:tween(line, 2.2, { Transparency = 1 })
					end)
				end
			end
			Vfx.Emit.burst(torso.Position + torso.CFrame.LookVector * 0.6, {
				tex = "VfxChunk",
				grid = 2,
				startRandom = true,
				color = { { 0, Color3.fromRGB(255, 120, 130) }, { 1, DEEP } },
				size = { { 0, 0.22 }, { 1, 0.08 } },
				life = { 0.7, 1.3 },
				speed = { 3, 8 },
				spread = 70,
				accel = Vector3.new(0, -26, 0),
				rot = { 0, 360 },
				spin = { -260, 260 },
				light = 1,
				bright = 2,
			}, 34)
			Vfx.Light.flash(torso.Position, RED, 16, 6, 0.6)
		end
		if core then
			core.Transparency = 1
		end
		if glow then
			glow.Brightness = 6
			ctx:tween(glow, 2.5, { Brightness = 0 })
		end
		Cinema.flash(RED, 0.4, 0.5)
		Vfx.Screen.shake(1.2, 0.5)
	end)
	-- the lamp gutters and goes out over the body
	ctx:during(10.4, 11.4, function(t)
		lamp.Brightness = if math.floor(t * 18) % 3 == 0 then 0.2 else 1.4 * (1 - smooth((t - 10.4) / 1.0))
	end)
	ctx:at(11.4, function()
		lamp.Brightness = 0
	end)

	-- cameras
	-- 0.0 over the water: the bridge in the rain, the lamp, the figure at the parapet reading; a slow push
	ctx:camera(0, 2.6, function(t)
		local u = t / 2.6
		return CFrame.lookAt(Vector3.new(-12 + 2 * u, 2.6, -16 + 3 * u), Vector3.new(0, 3.8, 0)), 40 - 4 * u
	end)
	-- 2.6 over the shoulder, down onto the letter
	ctx:camera(2.6, 4.35, function(t)
		local u = (t - 2.6) / 1.75
		local h = head()
		return CFrame.lookAt(h + Vector3.new(0.9 - 0.2 * u, 0.6, 1.4), chest() + Vector3.new(0, 0.6, -1.0)), 40
	end)
	ctx:focus(2.6, 4.35, 2.2, 3)
	-- 4.35 the face from below in the rain as the first beat lands
	ctx:camera(4.35, 5.6, function(_t)
		local h = head()
		return CFrame.lookAt(h + Vector3.new(-0.7, -1.0, -2.3), h + Vector3.new(0, 0.1, 0)), 36
	end)
	-- 5.6 the chest: the second beat, the letter going, the crack
	ctx:camera(5.6, 7.4, function(t)
		local u = (t - 5.6) / 1.8
		local c = chest()
		return CFrame.lookAt(c + Vector3.new(0.6 - 0.4 * u, 0.4, -2.5 + 0.5 * u), c + Vector3.new(0, 0.3, 0)), 34
	end)
	-- 7.4 the letter falling down to the black water; the figure doubled over above, out of focus
	ctx:camera(7.4, 8.6, function(t)
		local u = (t - 7.4) / 1.2
		return CFrame.lookAt(Vector3.new(4.5, -6 - 4 * u, -12), Vector3.new(1.4, -10 - 4 * u, -7.5)), 40
	end)
	-- 8.6 from the side, low on the wet stones: the knees, over onto the face
	ctx:camera(8.6, 10.2, function(t)
		local u = (t - 8.6) / 1.6
		return CFrame.lookAt(Vector3.new(5.5 - u, 1.6, 0.8), Vector3.new(0, 1.4 - 0.6 * u, 0.4)), 40
	end)
	-- 10.2 high over the body, the rain falling past the lens toward it; rising; the lamp going out
	ctx:camera(10.2, 12, function(t)
		local u = (t - 10.2) / 1.8
		return CFrame.lookAt(Vector3.new(0.6, 10 + 6 * u, 1.2), Vector3.new(0, 0, 0.6)), 44
	end)
	ctx:grade(0, nil, { Saturation = -0.4, Contrast = 0.16, TintColor = Color3.fromRGB(210, 222, 240) }, 0.1)
end

return { length = 12, build = build }
