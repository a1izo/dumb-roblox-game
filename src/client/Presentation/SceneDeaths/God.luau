-- A GOD.. IS NOT... AFRAID OF... (art/refs/deaths/god.md, 16 s): the victim IS the devourer: a colossal serpent of dark
-- armoured segments edged in magenta and cyan, the victim's own head (made huge) at its front, coiling through a violet
-- sky of stars and nebulae. "A GOD DOES NOT FEAR DEATH!" in the chat at the bottom left, then spammed faster and faster
-- while the serpent comes apart a segment at a time from the tail (white flash, a burst of magenta-cyan dust), the
-- head alone cracking with light, and bursting into violet dust.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local MAGENTA = Color3.fromRGB(255, 60, 220)
local CYAN = Color3.fromRGB(60, 230, 255)
local PLATE = Color3.fromRGB(40, 30, 64)
local SEGMENTS = 26
local GAP = 3.4

local function build(ctx)
	-- (the sky is the scene's own, SkyScene* from the import; a dark box only without it)
	if not ctx:imported() then
		SceneDeaths.box(ctx, Vector3.new(500, 400, 500), Vector3.new(0, -150, 0), Color3.fromRGB(44, 16, 86))
	end
	SceneDeaths.emit(ctx, Vector3.new(0, 20, 0), Vector3.new(160, 100, 160), {
		tex = "VfxEmber",
		color = Color3.new(1, 1, 1),
		size = { { 0, 0.1 }, { 0.5, 0.35 }, { 1, 0.1 } },
		life = { 4, 7 },
		speed = { 0.1, 0.3 },
		spread = 180,
		bright = 2.6,
		light = 1,
		rate = 120,
	}):Emit(400)
	-- (glowing clouds far beyond the serpent, on the side every camera looks at: the purple one stood beside the
	-- circling wide's lens and showed as a hard-edged sheet across a third of the frame)
	for i, spec in ipairs({
		{ Vector3.new(-50, 40, -150), MAGENTA },
		{ Vector3.new(60, 15, -140), CYAN },
		{ Vector3.new(10, 70, -190), Color3.fromRGB(140, 60, 255) },
	}) do
		SceneDeaths.emit(ctx, spec[1], Vector3.new(60, 30, 20), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = spec[2],
			size = { { 0, 30 }, { 1, 50 } },
			alpha = { { 0, 1 }, { 0.3, 0.7 }, { 0.7, 0.75 }, { 1, 1 } },
			life = { 8, 12 },
			speed = { 0.2, 0.6 },
			spread = 180,
			rot = { 0, 360 },
			light = 1,
			bright = 1,
			rate = 2,
		}):Emit(6 + i)
	end
	ctx:light(Vector3.new(0, 30, 20), Color3.fromRGB(230, 200, 255), 120, 1.3)
	ctx:light(Vector3.new(-30, 0, -20), MAGENTA, 90, 1.1)
	ctx:light(Vector3.new(30, 10, -20), CYAN, 90, 1.0)

	-- the serpent: segments of dark plate edged in magenta, cyan fins; the victim's head, huge, at the front
	local segments = {}
	for i = 1, SEGMENTS do
		local scale = 1 - (i / SEGMENTS) * 0.45
		local body =
			ctx:part({ size = Vector3.new(4.6, 4.2, 3.2) * scale * 1.6, color = PLATE, material = Enum.Material.Metal })
		local band = ctx:part({
			size = Vector3.new(4.8, 0.5, 3.0) * scale * 1.6,
			color = if i % 2 == 0 then MAGENTA else CYAN,
			glow = true,
			cast = false,
		})
		local finL = ctx:part({
			size = Vector3.new(0.3, 2.4, 1.6) * scale * 1.6,
			color = CYAN,
			glow = true,
			shape = "Wedge",
			cast = false,
		})
		local finR = ctx:part({
			size = Vector3.new(0.3, 2.4, 1.6) * scale * 1.6,
			color = CYAN,
			glow = true,
			shape = "Wedge",
			cast = false,
		})
		segments[i] = { body = body, band = band, finL = finL, finR = finR, scale = scale, gone = false }
	end
	local headModel: Model? = nil
	local headPart: BasePart? = nil
	if ctx.victim then
		local who = game:GetService("Players"):GetPlayerByUserId(ctx.victim)
		local character = who and who.Character
		local h = character and character:FindFirstChild("Head")
		if h and h:IsA("BasePart") then
			local m = Instance.new("Model")
			local copy = h:Clone()
			for _, item in ipairs(copy:GetChildren()) do
				if not (item:IsA("Decal") or item:IsA("SpecialMesh")) then
					item:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.Parent = m
			m.PrimaryPart = copy
			m.Parent = ctx.stage.folder
			m:ScaleTo(8)
			headModel, headPart = m, copy
		end
	end
	if not headPart then
		headPart = ctx:part({
			size = Vector3.new(6, 6, 6),
			color = Color3.fromRGB(70, 50, 110),
			material = Enum.Material.Metal,
			shape = "Ball",
		})
	end
	local crown = {}
	for _ = 1, 6 do
		table.insert(crown, ctx:part({ size = Vector3.new(0.5, 3.4, 0.5), color = MAGENTA, glow = true, cast = false }))
	end
	local jaw = ctx:part({ size = Vector3.new(6.4, 0.6, 3), color = PLATE, material = Enum.Material.Metal })

	-- the path: a slow coil through the sky (scene space), its head leading
	local function path(s: number, t: number): Vector3
		local a = s * 0.11 - t * 0.55
		return Vector3.new(
			math.sin(a) * 34 + math.sin(s * 0.05) * 6,
			14 + math.sin(a * 1.7 + 1) * 9,
			math.cos(a) * 24 - 10
		)
	end
	local headFrame = CFrame.new()
	ctx:during(0, 16, function(t)
		-- (the coil slows as it comes apart)
		local tt = t - math.max(0, t - 8) * 0.6
		for i, seg in ipairs(segments) do
			if not seg.gone then
				local s = i * GAP * 0.62
				local p, q = path(s, tt), path(s - 0.3, tt)
				local cf = CFrame.lookAt(ctx:world(p), ctx:world(q))
				local wiggle = CFrame.Angles(0, 0, math.sin(t * 2 + i * 0.4) * 0.15)
				seg.body.CFrame = cf * wiggle
				seg.band.CFrame = cf * wiggle * CFrame.new(0, 0, 0)
				seg.finL.CFrame = cf
					* wiggle
					* CFrame.new(-4.2 * seg.scale, 1.9 * seg.scale, 0)
					* CFrame.Angles(0, 0, math.rad(30))
				seg.finR.CFrame = cf
					* wiggle
					* CFrame.new(4.2 * seg.scale, 1.9 * seg.scale, 0)
					* CFrame.Angles(0, 0, math.rad(-30))
			end
		end
		local front, ahead = path(0, tt), path(-0.4, tt)
		local throw = if t > 3 and t < 6 then math.sin((t - 3) / 3 * math.pi) * 0.5 else 0
		headFrame = CFrame.lookAt(ctx:world(front), ctx:world(ahead))
			* CFrame.Angles(throw, 0, 0)
			* CFrame.new(0, 0, -2.6)
		if headModel then
			headModel:PivotTo(headFrame)
		elseif headPart then
			headPart.CFrame = headFrame
		end
		jaw.CFrame = headFrame * CFrame.new(0, -3.2, -0.6)
		for k, c in ipairs(crown) do
			local a = (k - 3.5) * 0.35
			c.CFrame = headFrame
				* CFrame.new(math.sin(a) * 3.2, 3.6, math.cos(a) * 0.8 + 0.8)
				* CFrame.Angles(-0.4, 0, -a)
		end
	end)

	-- the chat at the bottom left: the boast, then spammed
	local chat = ctx:layer(3)
	local log = Instance.new("Frame")
	log.BackgroundTransparency = 1
	log.AnchorPoint = Vector2.new(0, 1)
	log.Position = UDim2.fromScale(0.02, 0.86)
	log.Size = UDim2.fromScale(0.5, 0.36)
	log.ClipsDescendants = true
	log.Parent = chat
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = log
	local lines = 0
	local function say(color: Color3)
		lines += 1
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 26)
		l.Font = Enum.Font.Arcade
		l.TextSize = 24
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = "A GOD DOES NOT FEAR DEATH!"
		l.LayoutOrder = lines
		l.Parent = log
		if lines > 14 then
			local oldest
			for _, c in ipairs(log:GetChildren()) do
				if c:IsA("TextLabel") and (not oldest or c.LayoutOrder < oldest.LayoutOrder) then
					oldest = c
				end
			end
			if oldest then
				oldest:Destroy()
			end
		end
	end
	ctx:at(0.4, function()
		say(CYAN)
	end)
	ctx:at(3.2, function()
		say(CYAN)
	end)
	local spam = 6.0
	while spam < 16 do
		local t = spam
		ctx:at(t, function()
			say(if math.floor(t * 2) % 4 == 0 then MAGENTA else CYAN)
		end)
		spam += math.max(0.18, 0.55 - (spam - 6) * 0.04)
	end

	-- 6-14.5 the tail comes apart, segment by segment toward the head
	for i = SEGMENTS, 1, -1 do
		local t = 6 + (SEGMENTS - i) * (8.3 / SEGMENTS)
		ctx:at(t, function()
			local seg = segments[i]
			seg.body.Color = Color3.new(1, 1, 1)
			seg.body.Material = Enum.Material.Neon
			task.delay(0.08, function()
				local at = seg.body.Position
				Vfx.Emit.burst(at, {
					{
						{
							tex = "VfxFlare",
							color = { { 0, Color3.new(1, 1, 1) }, { 1, if i % 2 == 0 then MAGENTA else CYAN } },
							size = { { 0, 1 }, { 0.2, 9 * seg.scale }, { 1, 0 } },
							life = 0.3,
							rot = { 0, 360 },
							bright = 2.4,
							z = 2,
						},
						1,
					},
					{
						{
							tex = "VfxDust",
							color = { { 0, MAGENTA }, { 1, CYAN } },
							size = { { 0, 0.4 }, { 1, 0.15 } },
							life = { 1.2, 2.2 },
							speed = { 3, 9 },
							spread = 180,
							drag = 1,
							accel = Vector3.new(0, 2, 0),
							light = 1,
							bright = 1.8,
						},
						40,
					},
				}, nil, seg.body.Size)
				Vfx.Light.flash(at, if i % 2 == 0 then MAGENTA else CYAN, 30, 4, 0.3)
				seg.gone = true
				for _, p in ipairs({ seg.body, seg.band, seg.finL, seg.finR }) do
					p:Destroy()
				end
			end)
		end)
	end
	-- 12-14.5 the head alone, cracking with light; 14.5 it bursts
	ctx:at(12.2, function()
		for k = 1, 8 do
			local crack =
				ctx:part({ size = Vector3.new(0.18, 2 + k % 3, 0.18), color = CYAN, glow = true, cast = false })
			local offset = CFrame.new(math.random() * 4 - 2, math.random() * 4 - 2, -2.8)
				* CFrame.Angles(0, 0, math.rad(k * 41))
			ctx:during(12.2, 14.5, function()
				crack.CFrame = headFrame * offset
			end)
			ctx:atNow(14.5, function()
				crack:Destroy()
			end)
		end
	end)
	ctx:at(14.5, function()
		local at = headFrame.Position
		Vfx.Emit.burst(at, {
			tex = "VfxDust",
			color = { { 0, Color3.fromRGB(200, 120, 255) }, { 1, MAGENTA } },
			size = { { 0, 0.6 }, { 1, 0.2 } },
			life = { 1.5, 2.6 },
			speed = { 6, 16 },
			spread = 180,
			drag = 1,
			light = 1,
			bright = 2,
		}, 160, Vector3.new(6, 6, 6))
		Vfx.Beams.wave(
			CFrame.new(at),
			1,
			40,
			1.2,
			{ tex = "VfxRingBand", color = MAGENTA, width = 1.4, light = 1, bright = 2 }
		)
		Cinema.flash(Color3.fromRGB(230, 170, 255), 0.6, 0.6)
		if headModel then
			headModel:Destroy()
			headModel = nil
		elseif headPart then
			headPart:Destroy()
		end
		jaw:Destroy()
		for _, c in ipairs(crown) do
			c:Destroy()
		end
	end)

	-- cameras: wide; the head; wide circling; the head alone; wide on the burst
	local function headAt(): Vector3
		return ctx.origin:PointToObjectSpace(headFrame.Position)
	end
	ctx:shot(0.0, Vector3.new(0, 24, 60), Vector3.new(0, 12, -6), 58, { eye = Vector3.new(-14, 22, 56) })
	-- (in front of the face: the body trails behind the head, so nothing of it comes between)
	local function facing(): Vector3
		local v = ctx.origin:VectorToObjectSpace(headFrame.LookVector)
		return Vector3.new(v.X, 0, v.Z).Unit
	end
	ctx:camera(3.0, 6.0, function()
		local h = headAt()
		return CFrame.lookAt(h + facing() * 26 + Vector3.new(0, 5, 0), h), 46
	end)
	ctx:camera(6.0, 12.0, function(t)
		local a = (t - 6) * 0.12
		local eye = Vector3.new(math.sin(a) * 70, 24, math.cos(a) * 70)
		return CFrame.lookAt(eye, Vector3.new(0, 12, -8)), 56
	end)
	ctx:camera(12.0, 14.6, function()
		local h = headAt()
		return CFrame.lookAt(h + facing() * 22 + Vector3.new(0, 4, 0), h), 44
	end)
	ctx:shot(14.6, Vector3.new(0, 24, 60), Vector3.new(0, 14, -6), 56)
	ctx:grade(0, nil, { Saturation = 0.15, Contrast = 0.2, TintColor = Color3.fromRGB(240, 220, 255) }, 0.1)
end

return { length = 16, build = build }
