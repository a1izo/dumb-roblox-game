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
local COPIES = 6
-- the row: back and to the side of the victim, close enough that the bodies overlap as in the reference
local function copyAt(k: number): Vector3
	return Vector3.new(0.85 * k, 0, 1.25 * k)
end
local TURN_FIRST = 3.75 -- the victim looks back first (sceneRequiemVictim), then each copy, this far apart
local TURN_EVERY = 0.62

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
	local lines = {}
	for k = 1, 90 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Parent = gui
		table.insert(lines, { frame = f, angle = (k + math.random() * 0.6) / 90 * math.pi * 2, seed = math.random() })
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
		local beat = math.floor(t * 24)
		for i, l in ipairs(lines) do
			local r = math.random(1000) / 1000
			local len = if (beat + i) % 2 == 0 then 120 + 260 * ((l.seed + r * 0.4) % 1) else 90 + 220 * l.seed
			local inner = 130 + 60 * ((i * 7) % 5) / 5
			local mid = inner + len / 2
			l.frame.Size = UDim2.fromOffset(len, 2 + (i % 3) * 2)
			l.frame.Position = UDim2.fromOffset(400 + math.cos(l.angle) * mid, 400 + math.sin(l.angle) * mid)
			l.frame.Rotation = math.deg(l.angle)
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
		Vfx.Beams.wave(CFrame.lookAt(at, at + Vector3.zAxis) * CFrame.Angles(math.rad(90), 0, 0), 0.4, 6, 0.6, {
			tex = "VfxRingBand",
			color = GOLD,
			width = 0.3,
			light = 1,
			bright = 1.4,
		})
		Cinema.still(VIOLET, 0.18)
	end)
	-- 2.5 close profile from the right: the wide eye, the stopped fist past it (aimed by the head)
	local eye2, look2 = onFace(0.3, 2.0, 0.05)
	ctx:shot(2.5, eye2, look2, 36)

	-- 3.25 the rewind: the row of copies stretching back from the victim, packed close, each looking back in turn
	local copies = {}
	ctx:at(3.25, function()
		for k = 1, COPIES do
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
			end
		end
		Cinema.flash(VIOLET, 0.45, 0.35)
		stream.Rate = 220
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
