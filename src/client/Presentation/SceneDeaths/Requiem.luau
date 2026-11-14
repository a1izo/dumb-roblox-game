-- This is... requiem (art/refs/deaths/requiem.md, 16.5 s): "Take this!", the lunge before a burst of white speed lines
-- on blue, the fist rushing the lens, stopped a hand short of the killer (Giorno, in his marketplace costume, edged in
-- gold); then the rewind: a tight diagonal row of copies of the victim, overlapping, filling the frame, each turning
-- in its own moment to look back over its shoulder at us (2026-11-10, the user: "looking back 1 by 1", not
-- glitching); the extreme close on the face; the row again; "What is this?". The victim is always the dead player's own
-- avatar; no drawn faces. Close-ups are aimed by where the head itself looks.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local VIOLET = Color3.fromRGB(150, 80, 240)
local GOLD = Color3.fromRGB(255, 232, 170)
local BLUE = Color3.fromRGB(34, 58, 150)

local KILLER = CFrame.lookAt(Vector3.new(0, 0, -3.6), Vector3.new(0, 0, 0)) -- facing the victim
local VICTIM = CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(0, 0, -3.6)) -- facing the killer
-- (2026-11-12, the user: "make more clones": 6 became a row of 16 and a second row of 10 behind it)
local COPIES = 16
local SECOND_ROW = 10
-- the row: back and to the side of the victim, close enough that the bodies overlap as in the reference; the second
-- row further off, beyond the first from the lens, turning in a later wave
local function copyAt(k: number): Vector3
	if k > COPIES then
		local j = k - COPIES
		return Vector3.new(1.7 + 0.85 * j, 0, -0.9 + 1.25 * j)
	end
	return Vector3.new(0.85 * k, 0, 1.25 * k)
end
local TURN_FIRST = 3.75 -- the victim looks back first (sceneRequiemVictim), then each copy, this far apart
-- (2026-11-14: the turn itself is slow now, 1.35 s as in the anime, so the wave runs a little wider apart)
local TURN_EVERY = 0.4

-- A burst of white speed lines on blue, drawn on a plane standing behind the subject and facing the lens (crisp lines
-- at any distance, behind the body, never over it). Returns the plane and its lines.
local function speedBurst(ctx, centre: Vector3, eye: Vector3)
	local plane = ctx:part({
		size = Vector3.new(44, 44, 0.2),
		at = centre,
		alpha = 1,
		cast = false,
	})
	plane.CFrame = CFrame.lookAt(ctx:world(centre), ctx:world(eye))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(800, 800)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = plane
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = BLUE
	back.Parent = gui
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(Color3.fromRGB(150, 180, 255), BLUE)
	glow.Parent = back
	-- (2026-11-14, the user: "make those straight lines better": they were 90 plain bars of one thickness. Now each is a
	-- drawn wedge: wide at the rim of the frame, tapering to a point toward the middle, in three weights (hairs, strokes,
	-- a few heavy blades), some in ink over the white, bunched unevenly round the circle as a hand draws them, and a
	-- white core glowing behind the fist.)
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(520, 520)
	core.BorderSizePixel = 0
	core.BackgroundColor3 = Color3.fromRGB(226, 236, 255)
	core.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = core
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = core
	local lines = {}
	local rng = Random.new(41)
	local angle = 0
	local count = 0
	while angle < math.pi * 2 and count < 150 do
		count += 1
		-- bunched: mostly small steps, now and then a gap
		angle += if rng:NextNumber() < 0.16 then rng:NextNumber(0.09, 0.16) else rng:NextNumber(0.018, 0.06)
		local roll = rng:NextNumber()
		local weight = if roll < 0.08 then 3 elseif roll < 0.4 then 2 else 1
		local ink = weight < 3 and rng:NextNumber() < 0.22
		-- a wedge of three stacked bars: the full length thin, two shorter and wider toward the rim
		local pieces = {}
		for layer = 1, 3 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if ink then Color3.fromRGB(10, 14, 44) else Color3.new(1, 1, 1)
			f.AnchorPoint = Vector2.new(0, 0.5)
			f.Rotation = math.deg(angle)
			f.ZIndex = if ink then 3 else 2
			f.Parent = gui
			local tip = Instance.new("UIGradient")
			tip.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.22, if ink then 0.25 else 0.1),
				NumberSequenceKeypoint.new(1, 0),
			})
			tip.Parent = f
			pieces[layer] = f
		end
		table.insert(lines, {
			pieces = pieces,
			angle = angle,
			seed = rng:NextNumber(),
			weight = weight,
			inner = 150 + rng:NextNumber() * 150,
		})
	end
	return plane, lines
end

local function build(ctx)
	if not ctx:imported() then
		SceneDeaths.box(ctx, Vector3.new(400, 260, 400), Vector3.new(0, -90, 0), Color3.fromRGB(16, 8, 34))
	end
	-- the stars streaming past as time runs backward: long white streaks, away from the lens
	local stream = SceneDeaths.emit(ctx, Vector3.new(4, 6, 2), Vector3.new(60, 30, 4), {
		tex = "VfxStreak",
		color = Color3.new(1, 1, 1),
		size = { { 0, 0.18 }, { 1, 0.05 } },
		squash = -6,
		life = { 0.5, 1.0 },
		speed = { 40, 70 },
		spread = 4,
		bright = 2.2,
		light = 1,
		rate = 0,
		dir = Enum.NormalId.Back,
	})
	ctx:light(Vector3.new(-3, 9, 2), Color3.fromRGB(230, 214, 255), 40, 1.1)
	ctx:light(Vector3.new(4, 5, 8), VIOLET, 30, 0.8)

	-- The killer: Giorno in his costume (Cast), edged in gold light
	local killer = ctx:actor("cast:giorno", KILLER, "sceneRequiemKiller", 0, 1.08)
	if killer then
		local rim = Instance.new("Highlight")
		rim.FillColor = GOLD
		rim.FillTransparency = 0.94
		rim.OutlineColor = GOLD
		rim.OutlineTransparency = 0.35
		rim.DepthMode = Enum.HighlightDepthMode.Occluded
		rim.Parent = killer
		local torso = ctx:limb(killer, "Torso")
		if torso then
			local glow = Instance.new("PointLight")
			glow.Color = GOLD
			glow.Range = 14
			glow.Brightness = 2.2
			glow.Parent = torso
			Vfx.Emit.make(torso, {
				tex = "VfxGlow",
				color = GOLD,
				size = { { 0, 5 }, { 1, 7 } },
				alpha = { { 0, 0.88 }, { 1, 1 } },
				life = 0.8,
				speed = 0.01,
				light = 1,
				bright = 1.2,
				rate = 5,
				z = -1,
			})
			-- Requiem's light rising off him: golden motes drifting up round the body, and glints catching in them
			Vfx.Emit.make(torso, {
				tex = "VfxEmber",
				color = { { 0, Color3.fromRGB(255, 248, 220) }, { 1, GOLD } },
				size = { { 0, 0.12 }, { 0.6, 0.09 }, { 1, 0 } },
				alpha = { { 0, 0.2 }, { 0.7, 0.3 }, { 1, 1 } },
				life = { 1.4, 2.4 },
				speed = { 0.3, 1.0 },
				spread = 180,
				accel = Vector3.new(0, 1.6, 0),
				drag = 0.8,
				light = 1,
				bright = 2.4,
				rate = 26,
				shape = Enum.ParticleEmitterShape.Box,
			})
			Vfx.Emit.make(torso, {
				tex = "VfxFlare",
				color = Color3.fromRGB(255, 244, 210),
				size = { { 0, 0 }, { 0.3, 0.5 }, { 1, 0 } },
				life = { 0.35, 0.6 },
				speed = 0.01,
				rot = { 0, 45 },
				light = 1,
				bright = 2.6,
				rate = 3,
				shape = Enum.ParticleEmitterShape.Box,
			})
		end
	end

	-- The victim (the nearest of the row once it is rewound): the player's own avatar
	local victim = ctx:actor(ctx.victim or "figure", VICTIM, "sceneRequiemVictim")
	local function headOf(model: Model?): CFrame
		local h = model and ctx:limb(model, "Head")
		return if h then ctx.origin:ToObjectSpace(h.CFrame) else CFrame.new(0, 4.6, 0)
	end
	local function hand(): Vector3
		local h = victim and ctx:limb(victim, "Right Arm")
		return if h
			then ctx.origin:PointToObjectSpace((h.CFrame * CFrame.new(0, -1, 0)).Position)
			else Vector3.new(0.5, 4, -1.5)
	end
	-- a camera on the face itself: `out` studs along where the head looks, `side` to its right, `up`
	local function onFace(out: number, side: number, up: number)
		return function()
			local h = headOf(victim)
			return h.Position + h.LookVector * out + h.RightVector * side + h.UpVector * up
		end, function()
			return headOf(victim).Position
		end
	end

	-- 0.0 "Take this, ...!": close and a little low on the shouting face; lightning cracks above
	local eye0, look0 = onFace(2.0, 0.7, -0.35)
	ctx:shot(0.0, eye0, look0, 40)
	ctx:say(0.0, "Take this, Giorno Giovanna!", 1.6)
	ctx:at(0.05, function()
		for k = 1, 3 do
			local from = ctx:world(Vector3.new(-6 + k * 4, 14, -2 + k))
			Vfx.Beams.bolt(from, from + Vector3.new(math.random(-3, 3), -6, math.random(-2, 2)), 0.25, {
				color = Color3.fromRGB(230, 214, 255),
				width = 0.35,
				bright = 2,
				light = 1,
				pieces = 9,
			})
		end
	end)

	-- 0.25 the wind-up, low from the front-left, before a burst of white speed lines on blue
	local EYE1, LOOK1 = Vector3.new(-2.6, 2.0, -4.6), Vector3.new(0, 3.4, 0)
	ctx:shot(0.25, EYE1, LOOK1, 56, { eye = Vector3.new(-2.2, 2.2, -4.2) })
	local burst, lines
	ctx:at(0.25, function()
		burst, lines = speedBurst(ctx, LOOK1 + (LOOK1 - EYE1).Unit * 9, EYE1)
	end)
	ctx:during(0.25, 1.24, function(t)
		if not lines then
			return
		end
		-- (the lines flicker in length on every other frame, as hand-drawn speed lines are redrawn)
		-- redrawn on twos (12 a second), as hand-drawn speed lines are: each redraw the tips jump in and out and the whole
		-- burst closes in on the fist as the punch comes
		local beat = math.floor(t * 12)
		if beat == (ctx :: any).requiemLines then
			return
		end
		(ctx :: any).requiemLines = beat
		local close = math.clamp((t - 0.25) / 0.95, 0, 1)
		local rng = Random.new(beat * 977 + 3)
		for _, l in ipairs(lines) do
			local jitter = rng:NextNumber()
			local inner = l.inner * (1 - 0.38 * close) + (jitter - 0.5) * 90
			local thick = if l.weight == 3 then 26 elseif l.weight == 2 then 9 else 3
			local wobble = (rng:NextNumber() - 0.5) * 0.012
			local c, sn = math.cos(l.angle + wobble), math.sin(l.angle + wobble)
			for layer, f in ipairs(l.pieces) do
				-- layer 1 runs from the tip to past the rim; 2 and 3 start further out and are wider: a taper
				local from = inner + (layer - 1) * (70 + 60 * l.seed)
				f.Size = UDim2.fromOffset(620 - from, math.max(1, thick * layer / 3))
				f.Position = UDim2.fromOffset(400 + c * from, 400 + sn * from)
				f.Rotation = math.deg(l.angle + wobble)
			end
		end
	end)
	ctx:at(1.24, function()
		if burst then
			burst:Destroy()
		end
	end)
	-- 1.25 the fist rushes the lens: a white smear
	ctx:shot(1.25, function()
		return hand() + Vector3.new(0.4, 0.2, -1.6)
	end, function()
		return hand() + Vector3.new(0, 0, 4)
	end, 70)
	ctx:at(1.27, function()
		Cinema.flash(Color3.new(1, 1, 1), 0.85, 0.3)
	end)
	-- 1.5 over the victim's shoulder: the fist arriving at the killer's face, stopped a hand short; time stops
	ctx:shot(1.5, Vector3.new(1.5, 5.6, 2.6), Vector3.new(-0.2, 5.0, -3.6), 46, { eye = Vector3.new(1.3, 5.5, 2.2) })
	ctx:at(2.0, function()
		local at = ctx:world(Vector3.new(0, 5.3, -2.4))
		-- time stops at the fist: three golden rings racing out after each other, a hard flare, gold sparks flung
		for i = 0, 2 do
			Vfx.Clock.after(i * 0.11, function()
				Vfx.Beams.wave(
					CFrame.lookAt(at, at + Vector3.zAxis) * CFrame.Angles(math.rad(90), 0, 0),
					0.3,
					6 + i * 3,
					0.7,
					{
						tex = "VfxRingBand",
						color = if i == 1 then VIOLET else GOLD,
						width = 0.34 - i * 0.07,
						light = 1,
						bright = 1.8,
					}
				)
			end)
		end
		Vfx.Emit.burst(
			at,
			{
				{
					{
						tex = "VfxFlare",
						color = Color3.fromRGB(255, 250, 230),
						size = { { 0, 1 }, { 0.15, 7 }, { 1, 0 } },
						life = 0.45,
						speed = 0.01,
						light = 1,
						bright = 3,
						rot = { 0, 0 },
					},
					1,
				},
				{
					{
						tex = "Spark",
						color = { { 0, Color3.new(1, 1, 1) }, { 1, GOLD } },
						size = { { 0, 0.12 }, { 1, 0.03 } },
						squash = -2,
						face = "along",
						life = { 0.4, 0.9 },
						speed = { 14, 32 },
						drag = 3,
						spread = 180,
						light = 1,
						bright = 2.6,
					},
					70,
				},
			} :: any
		)
		Vfx.Light.flash(at, GOLD, 30, 8, 0.6)
		Vfx.Screen.shake(1.2, 0.35)
		Cinema.still(VIOLET, 0.18)
	end)
	-- 2.5 close profile from the right: the wide eye, the stopped fist past it (aimed by the head)
	local eye2, look2 = onFace(0.3, 2.0, 0.05)
	ctx:shot(2.5, eye2, look2, 36)

	-- 3.25 the rewind: the row of copies stretching back from the victim, packed close, each looking back in turn
	local copies = {}
	ctx:at(3.25, function()
		for k = 1, COPIES + SECOND_ROW do
			local at = copyAt(k)
			-- (each copy's clip turns its head at 1 s of its own time; started so that falls TURN_EVERY after the one
			-- before it)
			local turnAt = TURN_FIRST + TURN_EVERY * k
			local c = ctx:actor(
				ctx.victim or "figure",
				CFrame.lookAt(at, at + Vector3.new(0, 0, -1)),
				"sceneRequiemCopy",
				turnAt - 1.0,
				nil,
				0.3
			)
			if c then
				table.insert(copies, { model = c, base = at, k = k })
				-- each copy flickers in as a violet afterimage, the further back the more of a ghost
				local ghost = Instance.new("Highlight")
				ghost.FillColor = VIOLET
				ghost.OutlineColor = Color3.fromRGB(210, 180, 255)
				ghost.FillTransparency = math.clamp(0.95 - k * 0.012, 0.6, 0.95)
				ghost.OutlineTransparency = math.clamp(0.75 - k * 0.02, 0.35, 0.75)
				ghost.DepthMode = Enum.HighlightDepthMode.Occluded
				ghost.Parent = c
				local torso = ctx:limb(c, "Torso")
				if torso then
					Vfx.Emit.burst(torso.Position, {
						tex = "VfxSmoke",
						color = Color3.fromRGB(170, 120, 255),
						size = { { 0, 1.2 }, { 1, 3 } },
						alpha = { { 0, 0.6 }, { 1, 1 } },
						life = { 0.5, 0.8 },
						speed = { 0.5, 1.5 },
						spread = 180,
						light = 0.6,
						bright = 1.4,
					}, 3)
				end
			end
		end
		Cinema.flash(VIOLET, 0.45, 0.35)
		stream.Rate = 260
		-- time running back: violet motes drifting back along the rows, slow
		SceneDeaths.emit(ctx, Vector3.new(8, 4.5, 10), Vector3.new(16, 6, 22), {
			tex = "VfxGlow",
			color = { { 0, Color3.fromRGB(220, 200, 255) }, { 1, VIOLET } },
			size = { { 0, 0.18 }, { 1, 0.05 } },
			alpha = { { 0, 0.3 }, { 0.8, 0.5 }, { 1, 1 } },
			life = { 2.0, 3.4 },
			speed = { 1.0, 2.2 },
			spread = 10,
			dir = Enum.NormalId.Back,
			light = 1,
			bright = 2,
			rate = 70,
		})
	end)
	-- the rewind's clock: violet rings pulsing out at the far end of the row, as if time were wound back through it
	ctx:during(3.6, 16.2, function(t)
		local beat = math.floor((t - 3.6) / 1.15)
		if beat ~= (ctx :: any).requiemBeat then
			(ctx :: any).requiemBeat = beat
			local at = ctx:world(copyAt(COPIES) + Vector3.new(0, 4.5, 2))
			Vfx.Beams.wave(CFrame.lookAt(at, at + Vector3.new(-0.55, 0, -0.85)), 0.5, 11, 1.1, {
				tex = "VfxRingBand",
				color = VIOLET,
				width = 0.22,
				light = 1,
				bright = 1.4,
			})
		end
	end)
	-- the whole row drifts slowly back along itself (being rewound), smoothly: nothing turns but the heads
	ctx:during(3.3, 16.5, function(t)
		local drift = Vector3.new(0.02, 0, 0.035) * (t - 3.3)
		for _, c in ipairs(copies) do
			local target = ctx:world(c.base + drift * (1 + c.k * 0.15))
			local pivot = c.model:GetPivot()
			c.model:PivotTo(CFrame.new(Vector3.new(target.X, pivot.Position.Y, target.Z)) * pivot.Rotation)
		end
	end)
	-- the row from the side the heads turn to: tight, the faces large, the nearest biggest
	ctx:shot(3.3, Vector3.new(-3.4, 5.0, 0.4), Vector3.new(1.4, 4.4, 3.0), 46, {
		eye = Vector3.new(-3.0, 5.1, 1.2),
		look = Vector3.new(1.8, 4.3, 3.6),
	})
	ctx:say(6.0, "Wha—", 2.6)
	-- 8.75 the extreme close: straight on the face
	local eye3, look3 = onFace(1.25, 0.0, 0.05)
	ctx:shot(8.75, eye3, look3, 30)
	ctx:say(9.0, "Wha—", 7.0)
	ctx:shot(9.75, Vector3.new(-3.0, 5.4, -0.6), Vector3.new(1.6, 4.2, 3.4), 44, {
		eye = Vector3.new(-2.4, 5.2, 0.8),
		look = Vector3.new(2.0, 4.2, 4.0),
	})
	-- 16.2 the close profile, cold: "What is this?"
	local eye4, look4 = onFace(0.4, -1.9, 0.1)
	ctx:shot(16.2, eye4, look4, 34)
	ctx:say(16.2, "What is this?", 1.0)
	ctx:grade(0, nil, { Saturation = 0.18, Contrast = 0.16, TintColor = Color3.fromRGB(240, 232, 255) }, 0.1)
	ctx:grade(16.2, nil, { TintColor = Color3.fromRGB(170, 190, 255), Brightness = -0.06 }, 0.1)
end

return { length = 16.5, build = build }
