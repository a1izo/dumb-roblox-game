-- This is... requiem (art/refs/deaths/requiem.md, 16.5 s): "Take this!", the lunge in a burst of speed lines, the fist
-- rushing the lens, stopped a hand short of the killer (a tall shadow edged in pale gold light); then the rewind: a
-- diagonal row of copies of the victim stretching back from the killer through a violet-green star void, every one
-- twisted round to look back at us, shocked; the extreme close on the mouth ("Wha—"), the row again, "What is this?".

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local DeathScreen = require(script.Parent.Parent.DeathScreen)
local Vfx = require(script.Parent.Parent.Vfx)

local VIOLET = Color3.fromRGB(140, 70, 230)
local MAGENTA = Color3.fromRGB(230, 70, 200)
local GREEN = Color3.fromRGB(70, 220, 150)
local GOLD = Color3.fromRGB(255, 232, 170)

local KILLER = CFrame.lookAt(Vector3.new(0, 0, -3.6), Vector3.new(0, 0, 0)) -- facing the victim
local VICTIM = CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(0, 0, -3.6)) -- facing the killer
local COPIES = 6

local function build(ctx)
	-- The void: a vast dark violet box, star dust streaming past (the rewind), nebula clouds that change colour.
	-- (the sky is the scene's own, SkyScene* from the import; a dark box only without it)
	if not ctx:imported() then
		SceneDeaths.box(ctx, Vector3.new(400, 260, 400), Vector3.new(0, -90, 0), Color3.fromRGB(10, 6, 22))
	end
	local stars = SceneDeaths.emit(ctx, Vector3.new(0, 4, 0), Vector3.new(70, 40, 70), {
		tex = "VfxEmber",
		color = Color3.new(1, 1, 1),
		size = { { 0, 0.05 }, { 0.5, 0.16 }, { 1, 0.05 } },
		life = { 3, 5 },
		speed = { 0.2, 0.6 },
		spread = 180,
		bright = 2.4,
		light = 1,
		rate = 260,
	})
	local nebula = SceneDeaths.emit(ctx, Vector3.new(0, 4, 18), Vector3.new(90, 50, 30), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = { { 0, VIOLET }, { 0.5, MAGENTA }, { 1, VIOLET } },
		size = { { 0, 18 }, { 1, 30 } },
		alpha = { { 0, 1 }, { 0.3, 0.8 }, { 0.7, 0.84 }, { 1, 1 } },
		life = { 6, 9 },
		speed = { 0.4, 1.2 },
		spread = 180,
		rot = { 0, 360 },
		spin = { -8, 8 },
		light = 1,
		bright = 0.55,
		rate = 10,
	})
	nebula:Emit(14)
	stars:Emit(300)
	local nebulaGreen = SceneDeaths.emit(ctx, Vector3.new(-20, 0, 25), Vector3.new(40, 30, 20), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = GREEN,
		size = { { 0, 14 }, { 1, 24 } },
		alpha = { { 0, 1 }, { 0.3, 0.7 }, { 0.7, 0.75 }, { 1, 1 } },
		life = { 6, 9 },
		speed = { 0.3, 0.8 },
		spread = 180,
		rot = { 0, 360 },
		light = 1,
		bright = 1,
		rate = 3,
	})
	nebulaGreen:Emit(5)
	ctx:light(Vector3.new(3, 9, 4), Color3.fromRGB(220, 200, 255), 40, 2.2)
	ctx:light(Vector3.new(-6, 4, -8), VIOLET, 30, 1.6)

	-- The killer: a tall shadow, no face, edged in pale gold light.
	local killer = ctx:actor("figure", KILLER, "sceneRequiemKiller", 0, 1.3)
	if killer then
		ctx:dress(killer, {
			head = Color3.fromRGB(8, 6, 12),
			torso = Color3.fromRGB(8, 6, 12),
			arms = Color3.fromRGB(8, 6, 12),
			legs = Color3.fromRGB(8, 6, 12),
			face = false,
		})
		local rim = Instance.new("Highlight")
		rim.FillColor = GOLD
		rim.FillTransparency = 0.92
		rim.OutlineColor = GOLD
		rim.OutlineTransparency = 0
		rim.DepthMode = Enum.HighlightDepthMode.Occluded
		rim.Parent = killer
		local torso = ctx:limb(killer, "Torso")
		if torso then
			local glow = Instance.new("PointLight")
			glow.Color = GOLD
			glow.Range = 14
			glow.Brightness = 2.5
			glow.Parent = torso
			Vfx.Emit.make(torso, {
				tex = "VfxGlow",
				color = GOLD,
				size = { { 0, 4 }, { 1, 6 } },
				alpha = { { 0, 0.85 }, { 1, 1 } },
				life = 0.6,
				speed = 0.01,
				light = 1,
				bright = 1.4,
				rate = 6,
				z = -1,
			})
		end
	end

	-- The victim (the nearest of the row once it is rewound).
	local victim = ctx:actor(ctx.victim or "figure", VICTIM, "sceneRequiemVictim")
	if victim then
		ctx:face(victim, "shout")
		ctx:at(2.45, function()
			ctx:face(victim, "shock")
		end)
	end
	local head = function(): Vector3
		local h = victim and ctx:limb(victim, "Head")
		return if h then ctx.origin:PointToObjectSpace(h.Position) else Vector3.new(0, 4.6, 0)
	end
	local hand = function(): Vector3
		local h = victim and ctx:limb(victim, "Right Arm")
		return if h
			then ctx.origin:PointToObjectSpace((h.CFrame * CFrame.new(0, -1, 0)).Position)
			else Vector3.new(0.5, 4, -1.5)
	end

	-- 0.0 "Take this, ...!": close on the shouting face; violet lightning cracks above
	ctx:shot(0.0, function()
		return head() + Vector3.new(1.4, -0.25, -2.1)
	end, function()
		return head()
	end, 40)
	ctx:say(0.0, "Take this, Giorno Giovanna!", 1.6)
	ctx:at(0.05, function()
		for k = 1, 3 do
			local from = ctx:world(Vector3.new(-6 + k * 4, 14, -2 + k))
			Vfx.Beams.bolt(from, from + Vector3.new(math.random(-3, 3), -6, math.random(-2, 2)), 0.25, {
				color = Color3.fromRGB(220, 200, 255),
				width = 0.4,
				bright = 2,
				light = 1,
				pieces = 8,
			})
		end
	end)

	-- 0.25 the wind-up: low from the front-left, a burst of white speed lines behind (on near-black)
	local lines = {}
	ctx:at(0.25, function()
		for k = 1, 46 do
			local a = k / 46 * math.pi * 2
			local p = ctx:part({
				size = Vector3.new(0.06, 0.06, 1),
				at = Vector3.new(0, 4, 6),
				color = Color3.new(1, 1, 1),
				glow = true,
				cast = false,
			})
			table.insert(lines, { part = p, angle = a, len = 4 + (k % 5) * 2.4 })
		end
	end)
	ctx:during(0.25, 1.24, function(t)
		local center = ctx:world(Vector3.new(0, 3.6, 3.5))
		local camera = workspace.CurrentCamera
		local toward = (camera.CFrame.Position - center).Unit
		local right = toward:Cross(Vector3.yAxis).Unit
		local up = right:Cross(toward).Unit
		for i, l in ipairs(lines) do
			local flick = 0.6 + 0.4 * math.sin(t * 60 + i * 1.7)
			local inner, len = 3.2 + (i % 3), l.len * flick
			local dir = right * math.cos(l.angle) + up * math.sin(l.angle)
			local mid = center + dir * (inner + len / 2) - toward * 0.5
			l.part.Size = Vector3.new(0.05 + (i % 2) * 0.05, 0.05, len)
			l.part.CFrame = CFrame.lookAt(mid, mid + dir)
		end
	end)
	ctx:at(1.24, function()
		for _, l in ipairs(lines) do
			l.part:Destroy()
		end
	end)
	ctx:shot(0.25, Vector3.new(-2.6, 2.0, -4.6), Vector3.new(0, 3.4, 0), 56, { eye = Vector3.new(-2.2, 2.2, -4.2) })
	-- 1.25 the fist rushes the lens: a white smear
	ctx:shot(1.25, function()
		return hand() + Vector3.new(0.4, 0.2, -1.6)
	end, function()
		return hand() + Vector3.new(0, 0, 4)
	end, 70)
	ctx:at(1.27, function()
		Cinema.flash(Color3.new(1, 1, 1), 0.85, 0.3)
	end)
	-- 1.5 over the victim's shoulder: the fist arriving at the killer's face, stopped a hand short
	ctx:shot(1.5, Vector3.new(1.5, 5.6, 2.6), Vector3.new(-0.2, 5.0, -3.6), 46, { eye = Vector3.new(1.3, 5.5, 2.2) })
	ctx:at(2.0, function()
		local at = ctx:world(Vector3.new(0, 5.3, -2.4))
		Vfx.Beams.wave(CFrame.lookAt(at, at + Vector3.zAxis) * CFrame.Angles(math.rad(90), 0, 0), 0.3, 4, 0.5, {
			tex = "VfxRingBand",
			color = GOLD,
			width = 0.35,
			light = 1,
			bright = 1.6,
		})
		Cinema.still(VIOLET, 0.18)
	end)
	-- 2.5 close profile: wide eye, sweat; the stopped fist past it
	ctx:shot(2.5, function()
		return head() + Vector3.new(2.1, 0.05, 0.3)
	end, function()
		return head() + Vector3.new(0, -0.1, -0.4)
	end, 36)

	-- 3.25 the rewind: the row of copies stretching back from the killer, all looking back at us
	local copies = {}
	ctx:at(3.25, function()
		for k = 1, COPIES do
			local at = Vector3.new(0.95 * k, 0, 1.7 * k)
			local c =
				ctx:actor(ctx.victim or "figure", CFrame.lookAt(at, at + Vector3.new(0, 0, -1)), "sceneRequiemCopy", 0)
			if c then
				ctx:face(c, "shock")
				table.insert(copies, { model = c, base = at, k = k })
			end
		end
		Cinema.flash(VIOLET, 0.45, 0.35)
	end)
	-- every copy's face turned to the lens (each twisted round to look back over the shoulder)
	local eyeRow = Vector3.new(4.6, 5.4, -3.0)
	ctx:during(3.3, 16.5, function(t)
		local cam = workspace.CurrentCamera.CFrame.Position
		local list = table.clone(copies)
		if victim then
			table.insert(list, { model = victim, base = Vector3.zero, k = 0 })
		end
		for _, c in ipairs(list) do
			local h = ctx:limb(c.model, "Head")
			local root = c.model.PrimaryPart or ctx:limb(c.model, "HumanoidRootPart")
			if h and root then
				local want = Vector3.new(cam.X - h.Position.X, 0, cam.Z - h.Position.Z)
				local have = Vector3.new(h.CFrame.LookVector.X, 0, h.CFrame.LookVector.Z)
				if want.Magnitude > 0.1 and have.Magnitude > 0.1 then
					local turn = math.atan2(have.X, have.Z) - math.atan2(want.X, want.Z)
					turn = (turn + math.pi) % (2 * math.pi) - math.pi
					local slide = Vector3.new(0, 0, 0.05 * (t - 3.3))
					local pos = c.model:GetPivot().Position
					local target = ctx:world(c.base + slide)
					c.model:PivotTo(
						CFrame.new(Vector3.new(target.X, pos.Y, target.Z))
							* (c.model:GetPivot().Rotation * CFrame.Angles(0, turn * 0.25, 0))
					)
				end
			end
		end
	end)
	-- the stutters of the rewind: the whole row flickers back a little, an afterimage left behind
	for _, t in ipairs({ 4.1, 5.6, 7.3, 10.4, 12.2, 14.0, 15.4 }) do
		ctx:at(t, function()
			for _, c in ipairs(copies) do
				DeathScreen.ghost(c.model, if c.k % 2 == 0 then VIOLET else GREEN, 0.45, 0.55)
			end
			if victim then
				DeathScreen.ghost(victim, MAGENTA, 0.45, 0.55)
			end
		end)
	end
	-- the nebula's colours cycle (violet, pink, green) as the row is rewound
	ctx:during(3.3, 16.5, function(t)
		local u = (t - 3.3) / 13.2
		local a = VIOLET:Lerp(MAGENTA, math.clamp(u * 2, 0, 1))
		local b = MAGENTA:Lerp(GREEN, math.clamp(u * 2 - 1, 0, 1))
		nebula.Color = ColorSequence.new(a, b)
	end)
	ctx:shot(
		3.3,
		eyeRow,
		Vector3.new(2.0, 4.0, 3.2),
		46,
		{ eye = Vector3.new(5.4, 5.2, -2.2), look = Vector3.new(2.4, 4.0, 3.8) }
	)
	ctx:say(6.0, "Wha—", 2.6)
	-- 8.75 the extreme close: eyes and mouth, dark red streaks round it
	ctx:shot(8.75, function()
		return head() + Vector3.new(0.9, 0, -1.2)
	end, function()
		return head()
	end, 26)
	local streaks: Frame? = nil
	ctx:at(8.75, function()
		local layer = ctx:layer(2)
		streaks = layer
		for k = 1, 22 do
			local x = if k <= 11 then (k - 1) / 11 * 0.22 else 0.78 + (k - 12) / 11 * 0.22
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if k % 3 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(70, 6, 10)
			f.BackgroundTransparency = if k % 3 == 0 then 0.6 else 0.15
			f.Position = UDim2.fromScale(x, 0)
			f.Size = UDim2.fromScale(0.012 + (k % 4) * 0.006, 1)
			f.Parent = layer
		end
	end)
	ctx:during(8.75, 9.5, function(t)
		if streaks then
			for i, f in ipairs(streaks:GetChildren()) do
				if f:IsA("Frame") then
					f.BackgroundTransparency = math.clamp(0.2 + 0.4 * math.sin(t * 40 + i), 0, 0.9)
				end
			end
		end
	end)
	ctx:at(9.5, function()
		if streaks then
			streaks:Destroy()
			streaks = nil
		end
	end)
	ctx:say(9.0, "Wha—", 7.0)
	ctx:shot(9.75, Vector3.new(4.2, 5.3, -2.4), Vector3.new(1.8, 4.1, 3.0), 44, {
		eye = Vector3.new(5.2, 5.1, -1.2),
		look = Vector3.new(2.2, 4.1, 3.8),
	})
	-- 16.25 the close profile in dark blue: "What is this?"
	ctx:shot(16.2, function()
		return head() + Vector3.new(-1.9, 0.1, 0.5)
	end, function()
		return head()
	end, 34)
	ctx:say(16.2, "What is this?", 1.0)
	ctx:grade(0, nil, { Saturation = 0.1, Contrast = 0.18, TintColor = Color3.fromRGB(236, 226, 255) }, 0.1)
	ctx:grade(16.2, nil, { TintColor = Color3.fromRGB(170, 190, 255), Brightness = -0.06 }, 0.1)
end

return { length = 16.5, build = build }
