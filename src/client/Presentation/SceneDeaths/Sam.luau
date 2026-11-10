-- Let's dance! (art/refs/deaths/sam.md, 14 s): two characters on dusk desert hills (brown-gold sky, boulders): the
-- victim (Sam's part, a red sword) and the killer (white-haired, silver cyborg armour, a long blade leaving RED trails).
-- Over the killer's shoulder the combo cuts across the victim; the vertical cut; the huge white brush 斬 painted on;
-- BLADE MODE: the whole picture cool BLUE (not inverted), the 斬 at the right, the lock-on box on the victim's chest and
-- the green cut line; the cut (sparks); the stagger; the overhead swing; grabbed, "Play time's over.", run through,
-- red cuts glowing on the chest; the blade out; staggering away; both standing; black. A small HUD like the game's.

local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local RED = Color3.fromRGB(255, 36, 40)
local DUSK = Color3.fromRGB(214, 170, 110)

-- The set of parts (before it was modelled): only when the Scenes import is missing.
local function standIn(ctx)
	-- the hills at dusk
	ctx:part({
		size = Vector3.new(220, 1, 220),
		at = Vector3.new(0, -0.5, 0),
		color = Color3.fromRGB(92, 74, 52),
		material = Enum.Material.Ground,
	})
	for k = 1, 9 do
		local a = math.rad(k * 40)
		ctx:part({
			size = Vector3.new(60, 18 + (k % 3) * 8, 40),
			at = Vector3.new(math.cos(a) * 90, 0, math.sin(a) * 90 - 20),
			rot = Vector3.new(0, k * 23, 0),
			color = Color3.fromRGB(70, 56, 40),
			material = Enum.Material.Ground,
			shape = "Ball",
		})
	end
	for _, b in ipairs({
		{ Vector3.new(-9, 1.6, 6), 4 },
		{ Vector3.new(7, 1.2, -12), 3 },
		{ Vector3.new(-14, 2.2, -10), 5 },
	}) do
		ctx:part({
			size = Vector3.new(b[2] * 1.4, b[2], b[2] * 1.2),
			at = b[1],
			rot = Vector3.new(10, b[2] * 20, 6),
			color = Color3.fromRGB(150, 134, 112),
			material = Enum.Material.Rock,
		})
	end
	-- the sky: a wall of dusk round everything, gold low, brown-grey high
	local sky = ctx:part({ size = Vector3.new(400, 160, 1), at = Vector3.new(0, 60, -150), color = DUSK, cast = false })
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.LightInfluence = 0
	g.Parent = sky
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 80, 74)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(176, 136, 90)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(236, 196, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 90, 66)),
	})
	grad.Parent = f
	for _, side in ipairs({
		{ Vector3.new(1, 160, 400), Vector3.new(-150, 60, 0) },
		{ Vector3.new(1, 160, 400), Vector3.new(150, 60, 0) },
		{ Vector3.new(400, 160, 1), Vector3.new(0, 60, 150) },
	}) do
		local p = ctx:part({ size = side[1], at = side[2], color = Color3.fromRGB(150, 118, 84), cast = false })
		local copy = g:Clone()
		copy.Face = if side[2].X < 0
			then Enum.NormalId.Right
			elseif side[2].X > 0 then Enum.NormalId.Left
			else Enum.NormalId.Front
		copy.Parent = p
	end
	ctx:part({
		size = Vector3.new(400, 1, 400),
		at = Vector3.new(0, 140, 0),
		color = Color3.fromRGB(86, 78, 72),
		cast = false,
	})
	ctx:light(Vector3.new(-30, 20, -60), Color3.fromRGB(255, 200, 140), 120, 2.4, true)
	ctx:light(Vector3.new(6, 10, 10), Color3.fromRGB(200, 180, 160), 30, 0.8)
end

local function build(ctx)
	if ctx:set() then
		-- (the desert, modelled: art/scripts/maps/venues/scenes/sam.py, under the dusk sun of its look; a warm
		-- bounce off the ground on the faces)
		ctx:light(Vector3.new(2, 2, -2.5), Color3.fromRGB(255, 200, 150), 10, 0.35)
	else
		standIn(ctx)
	end
	-- the two of them
	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -5)), "sceneSamVictim")
	-- (Raiden in his marketplace cyborg armour, white hair and visor: Cast)
	local killer = ctx:actor("cast:raiden", CFrame.lookAt(Vector3.new(0, 0, -5), Vector3.zero), "sceneSamKiller")
	if killer then
		-- the white hair swept back into its tail and the visor, the long blade with its red edge (modelled:
		-- props_scenes)
		ctx:wear(killer, "cyborgHead")
		local sword = ctx:wear(killer, "murasama")
		local arm = ctx:limb(killer, "Right Arm")
		if sword and arm then
			-- the red trail runs from the blade's hilt to its tip, on the arm that swings it
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = arm.CFrame:PointToObjectSpace(ctx:pointOf(sword, "murasama", "tip"))
			a1.Position = arm.CFrame:PointToObjectSpace(ctx:pointOf(sword, "murasama", "base"))
			a0.Parent, a1.Parent = arm, arm
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Color = ColorSequence.new(RED)
			trail.LightEmission = 1
			trail.Lifetime = 0.25
			trail.Transparency = NumberSequence.new(0.1, 1)
			trail.FaceCamera = true
			trail.Parent = arm
		end
	end
	if victim then
		ctx:wear(victim, "redBlade")
	end
	local function chest(): Vector3
		local t = victim and ctx:limb(victim, "Torso")
		return if t then ctx.origin:PointToObjectSpace(t.Position) else Vector3.new(0, 3.5, 0)
	end
	local function killerAt(): Vector3
		local t = killer and ctx:limb(killer, "Torso")
		return if t then ctx.origin:PointToObjectSpace(t.Position) else Vector3.new(0, 3.5, -5)
	end

	-- the HUD: the energy bars top left, the HITS counter at the right
	local hud = ctx:layer(3)
	local function bar(y: number, color: Color3, w: number)
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		b.BackgroundColor3 = color
		b.Position = UDim2.fromScale(0.04, y)
		b.Size = UDim2.fromScale(w, 0.012)
		b.Parent = hud
	end
	bar(0.14, Color3.fromRGB(240, 150, 40), 0.24)
	bar(0.158, Color3.fromRGB(80, 220, 240), 0.2)
	local hits = Instance.new("TextLabel")
	hits.BackgroundColor3 = Color3.fromRGB(240, 150, 40)
	hits.BorderSizePixel = 0
	hits.Position = UDim2.fromScale(0.78, 0.3)
	hits.Size = UDim2.fromScale(0.08, 0.035)
	hits.Font = Enum.Font.GothamBlack
	hits.TextScaled = true
	hits.Text = "1 HITS"
	hits.Parent = hud
	local count = 1

	-- 0.25 over the killer's shoulder: the combo across the victim
	ctx:shot(0.0, Vector3.new(-3.4, 6.4, -10.5), Vector3.new(0, 3.6, 0), 50, { eye = Vector3.new(-3.1, 6.3, -10.0) })
	ctx:say(0.2, "Just getting started", 1.1)
	local function cut(t: number, from: Vector3, to: Vector3)
		ctx:at(t, function()
			local c = chest()
			Vfx.Beams.line(
				ctx:world(c + from),
				ctx:world(c + to),
				{ tex = "VfxRingBand", color = RED, width = 0.22, light = 1, bright = 2.4 }
			)
			local _, fade = Vfx.Beams.line(ctx:world(c + from), ctx:world(c + to), {
				tex = "VfxRingBand",
				color = RED,
				width = 0.12,
				light = 1,
				bright = 2.4,
			})
			task.delay(0.12, function()
				fade(0.15)
			end)
			Vfx.Emit.burst(ctx:world(c + Vector3.new(0, 0, -0.5)), {
				tex = "VfxStreak",
				color = Color3.fromRGB(255, 220, 160),
				size = { { 0, 0.1 }, { 1, 0.02 } },
				squash = -2,
				life = { 0.15, 0.3 },
				speed = { 10, 18 },
				spread = 70,
				face = "along",
				light = 1,
				bright = 2,
			}, 10)
			count += 1
			hits.Text = count .. " HITS"
		end)
	end
	cut(0.4, Vector3.new(-1.5, 1.2, -0.6), Vector3.new(1.5, -1.0, -0.6))
	cut(0.75, Vector3.new(1.5, 1.0, -0.6), Vector3.new(-1.5, -0.8, -0.6))
	cut(1.05, Vector3.new(-1.6, 0.2, -0.6), Vector3.new(1.6, 0.4, -0.6))
	cut(1.3, Vector3.new(0.2, 2.2, -0.6), Vector3.new(-0.2, -2.0, -0.6))
	-- 1.5 the white brush kanji, painted on
	local kanji: TextLabel? = nil
	ctx:at(1.5, function()
		local k = Instance.new("TextLabel")
		k.BackgroundTransparency = 1
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Position = UDim2.fromScale(0.74, 0.45)
		k.Size = UDim2.fromScale(0.32, 0.62)
		k.SizeConstraint = Enum.SizeConstraint.RelativeYY
		k.Font = Enum.Font.GothamBlack
		k.TextScaled = true
		k.Text = "斬"
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Rotation = -4
		local paint = Instance.new("UIGradient")
		paint.Rotation = 0
		paint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		paint.Offset = Vector2.new(-1, 0)
		paint.Parent = k
		k.Parent = hud
		ctx:tween(paint, 0.3, { Offset = Vector2.new(0.5, 0) })
		for s = 1, 9 do
			local drop = Instance.new("Frame")
			drop.BorderSizePixel = 0
			drop.BackgroundColor3 = Color3.new(1, 1, 1)
			drop.AnchorPoint = Vector2.new(0.5, 0.5)
			drop.Position = UDim2.fromScale(0.62 + (s % 5) * 0.05, 0.2 + (s % 4) * 0.17)
			drop.Size = UDim2.fromScale(0.01 + (s % 3) * 0.006, 0.014 + (s % 2) * 0.01)
			drop.Rotation = s * 33
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = drop
			drop.Parent = hud
			ctx:atNow(3.2, function()
				drop:Destroy()
			end)
		end
		kanji = k
	end)
	ctx:at(3.2, function()
		if kanji then
			kanji:Destroy()
		end
	end)
	ctx:at(1.48, function()
		Cinema.flash(Color3.new(1, 1, 1), 0.5, 0.25)
	end)
	-- 1.75 BLADE MODE: blue, from behind the killer's left
	ctx:grade(
		1.6,
		3.25,
		{ Saturation = -0.25, Contrast = 0.22, Brightness = -0.06, TintColor = Color3.fromRGB(100, 145, 255) },
		0.12
	)
	ctx:shot(
		1.75,
		Vector3.new(-3.6, 4.2, -9.4),
		Vector3.new(0.2, 4.0, -1.5),
		48,
		{ eye = Vector3.new(-3.3, 4.3, -9.0) }
	)
	-- the blade-mode screen: a cool blue wash over the whole picture (under the 斬 and the lock-on), as the game's
	ctx:at(1.6, function()
		local wash = ctx:layer(2)
		local blue = Instance.new("Frame")
		blue.BorderSizePixel = 0
		blue.BackgroundColor3 = Color3.fromRGB(40, 96, 255)
		blue.BackgroundTransparency = 1
		blue.Size = UDim2.fromScale(1, 1)
		blue.Parent = wash
		ctx:tween(blue, 0.12, { BackgroundTransparency = 0.72 })
		ctx:atNow(3.25, function()
			wash:Destroy()
		end)
	end)
	-- 2.5 over the killer's shoulder, close on the victim: the lock-on box, the green cut line
	ctx:shot(2.5, Vector3.new(-2.6, 6.0, -9.4), Vector3.new(0, 3.9, 0), 38)
	local lock: Frame? = nil
	local line: BasePart? = nil
	ctx:at(2.5, function()
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Size = UDim2.fromScale(0.09, 0.15)
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 110, 140)
		s.Thickness = 3
		s.Parent = box
		for _, spec in ipairs({ { 0.5, 0.5, 0.25, 0.006 }, { 0.5, 0.5, 0.006, 0.25 } }) do
			local x = Instance.new("Frame")
			x.BorderSizePixel = 0
			x.BackgroundColor3 = Color3.fromRGB(255, 110, 140)
			x.AnchorPoint = Vector2.new(0.5, 0.5)
			x.Position = UDim2.fromScale(spec[1], spec[2])
			x.Size = UDim2.fromScale(spec[3], spec[4])
			x.Parent = box
		end
		box.Parent = hud
		lock = box
		local c = chest()
		line = ctx:part({
			size = Vector3.new(0.08, 3.4, 0.08),
			at = c + Vector3.new(0.1, 0, -0.62),
			rot = Vector3.new(0, 0, 8),
			color = Color3.fromRGB(80, 255, 140),
			glow = true,
			cast = false,
		})
	end)
	ctx:during(2.5, 3.25, function()
		if lock then
			local p = ctx:screen(ctx:world(chest() + Vector3.new(0, 0.3, 0)))
			lock.Position = UDim2.fromScale(p.X, p.Y)
		end
	end)
	-- 3.25 the cut: sparks at the chest; the red cuts glow on him from now
	ctx:at(3.25, function()
		if lock then
			lock:Destroy()
		end
		if line then
			line:Destroy()
		end
		local c = ctx:world(chest())
		Vfx.Emit.burst(c, {
			{
				{
					tex = "VfxFlare",
					color = Color3.fromRGB(255, 200, 140),
					size = { { 0, 0.5 }, { 0.2, 4 }, { 1, 0 } },
					life = 0.2,
					rot = { 0, 360 },
					bright = 2.4,
					z = 2,
				},
				1,
			},
			{
				{
					tex = "VfxStreak",
					color = { { 0, Color3.fromRGB(255, 230, 180) }, { 1, Color3.fromRGB(255, 110, 40) } },
					size = { { 0, 0.16 }, { 1, 0.03 } },
					squash = -2.2,
					life = { 0.3, 0.6 },
					speed = { 12, 26 },
					drag = 3,
					accel = Vector3.new(0, -25, 0),
					spread = 180,
					face = "along",
					light = 1,
					bright = 2,
				},
				50,
			},
		})
		Vfx.Light.flash(c, Color3.fromRGB(255, 150, 90), 26, 5, 0.3)
		if victim then
			for i, spec in ipairs({ { 0.2, 0.3, 30 }, { -0.1, -0.2, -40 }, { 0.05, 0.6, 70 } }) do
				ctx:attach(victim, "Torso", {
					size = Vector3.new(0.08, 1.8, 0.05),
					at = Vector3.new(spec[1], spec[2], -0.53),
					rot = Vector3.new(0, 0, spec[3]),
					color = RED,
					glow = true,
					name = "Cut" .. i,
				})
			end
		end
	end)
	ctx:shot(3.3, Vector3.new(6.5, 4.4, -2.6), Vector3.new(0, 3.5, -2.0), 50)
	ctx:shot(3.5, Vector3.new(4.2, 2.6, 4.4), Vector3.new(0.4, 3.0, 0.8), 46)
	ctx:shot(4.2, Vector3.new(7.5, 4.2, -6), Vector3.new(0, 4.2, -3), 52)
	-- 5.0 grabbed: over the victim's shoulder (his back to us), the killer behind him facing us
	ctx:at(5.0, function()
		if killer then
			killer:PivotTo(ctx.origin * CFrame.lookAt(Vector3.new(0, 3, -2.2), Vector3.new(0, 3, 0)))
		end
	end)
	ctx:shot(5.0, Vector3.new(1.3, 5.2, 3.4), Vector3.new(-0.2, 4.8, -2.4), 42, { eye = Vector3.new(1.1, 5.1, 3.0) })
	ctx:say(5.2, "Play time's over.", 2.2)
	ctx:at(6.8, function()
		Cinema.flash(RED, 0.35, 0.25)
		Vfx.Emit.burst(ctx:world(chest()), {
			tex = "VfxFlare",
			color = RED,
			size = { { 0, 0.5 }, { 0.2, 3.5 }, { 1, 0 } },
			life = 0.25,
			rot = { 0, 360 },
			bright = 2.4,
			z = 2,
		}, 1)
	end)
	-- 7.25 over the killer's back: the blade through him, sparks at the wound
	ctx:shot(7.25, Vector3.new(-2.8, 6.2, -6.8), Vector3.new(0, 3.9, 0), 40, { eye = Vector3.new(-2.5, 6.0, -6.4) })
	ctx:during(7.25, 11.0, function()
		if math.random() < 0.3 then
			Vfx.Emit.burst(ctx:world(chest() + Vector3.new(0, 0.1, -0.5)), {
				tex = "VfxStreak",
				color = Color3.fromRGB(255, 120, 60),
				size = { { 0, 0.1 }, { 1, 0.02 } },
				squash = -2,
				life = { 0.15, 0.3 },
				speed = { 6, 12 },
				spread = 60,
				face = "along",
				light = 1,
				bright = 2,
			}, 4)
		end
	end)
	ctx:at(11.0, function()
		Vfx.Emit.burst(ctx:world(chest()), {
			tex = "VfxFlare",
			color = RED,
			size = { { 0, 0.5 }, { 0.2, 3 }, { 1, 0 } },
			life = 0.25,
			rot = { 0, 360 },
			bright = 2.2,
			z = 2,
		}, 1)
		if killer then
			killer:PivotTo(ctx.origin * CFrame.lookAt(Vector3.new(-0.5, 3, -4.5), Vector3.new(0, 3, 0)))
		end
	end)
	-- 11.75 wide, side on: the stagger away; 12.5 the overhead; 13 both standing; black
	ctx:shot(11.75, Vector3.new(9, 4.2, -1.5), Vector3.new(0.3, 3.6, -1.5), 48)
	ctx:at(13.75, function()
		local black = Instance.new("Frame")
		black.BackgroundColor3 = Color3.new(0, 0, 0)
		black.BackgroundTransparency = 1
		black.BorderSizePixel = 0
		black.Size = UDim2.fromScale(1, 1)
		black.ZIndex = 6
		black.Parent = hud
		ctx:tween(black, 0.25, { BackgroundTransparency = 0 })
	end)
	ctx:grade(0, nil, { Saturation = -0.1, Contrast = 0.12, TintColor = Color3.fromRGB(255, 236, 214) }, 0.1)
	local _ = killerAt
end

return { length = 14, build = build }
