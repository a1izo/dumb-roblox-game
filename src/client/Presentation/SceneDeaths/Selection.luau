-- Dead by selection (art/refs/deaths/selection.md, 12 s): a dim room, a big dark board; the chart the user sent,
-- redrawn as dots and lines (no figures, no words): two columns of five dots, red on the left, blue on the right. The
-- red lines fan out evenly from every left dot; the blue lines from every right dot all bend to the top three on the
-- left. The victim is the ringed bottom-left dot: no blue line reaches it; it flickers and goes grey, and so do they,
-- crumbling to grey dust. (Not suicide: they are deselected.)

local SceneDeaths = require(script.Parent)
local Vfx = require(script.Parent.Parent.Vfx)

local RED = Color3.fromRGB(214, 40, 52)
local BLUE = Color3.fromRGB(40, 170, 230)
local BOARD = Vector3.new(0, 5.5, -6)

local LEFT = {
	Vector2.new(0.2, 0.12),
	Vector2.new(0.2, 0.31),
	Vector2.new(0.2, 0.5),
	Vector2.new(0.2, 0.69),
	Vector2.new(0.2, 0.88),
}
local RIGHT = {
	Vector2.new(0.8, 0.12),
	Vector2.new(0.8, 0.31),
	Vector2.new(0.8, 0.5),
	Vector2.new(0.8, 0.69),
	Vector2.new(0.8, 0.88),
}
local ME = 5 -- the victim's dot (bottom left)

local function build(ctx)
	SceneDeaths.box(
		ctx,
		Vector3.new(40, 16, 40),
		Vector3.new(0, 0, -2),
		Color3.fromRGB(24, 24, 28),
		Enum.Material.Concrete
	)
	local board = ctx:part({ size = Vector3.new(12, 7.5, 0.3), at = BOARD, color = Color3.fromRGB(14, 16, 20) })
	ctx:part({
		size = Vector3.new(0.3, 2.2, 0.3),
		at = BOARD + Vector3.new(-3, -4.8, 0.3),
		color = Color3.fromRGB(40, 40, 44),
		material = Enum.Material.Metal,
	})
	ctx:part({
		size = Vector3.new(0.3, 2.2, 0.3),
		at = BOARD + Vector3.new(3, -4.8, 0.3),
		color = Color3.fromRGB(40, 40, 44),
		material = Enum.Material.Metal,
	})
	local glow = ctx:light(BOARD + Vector3.new(0, 0, 3), Color3.fromRGB(170, 190, 230), 18, 0)
	ctx:light(Vector3.new(0, 12, 4), Color3.fromRGB(150, 150, 170), 26, 0.5)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(1200, 750)
	gui.LightInfluence = 0
	gui.Parent = board
	local canvas = Instance.new("Frame")
	canvas.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui

	local W, H = 1200, 750
	local function px(p: Vector2): Vector2
		return Vector2.new(p.X * W, p.Y * H)
	end
	-- a line from a to b, grown over `seconds`
	local function line(a: Vector2, b: Vector2, color: Color3, seconds: number)
		local pa, pb = px(a), px(b)
		local d = pb - pa
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.Position = UDim2.fromOffset(pa.X, pa.Y)
		f.Size = UDim2.fromOffset(0, 5)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
		f.ZIndex = 1
		f.Parent = canvas
		ctx:tween(f, seconds, { Size = UDim2.fromOffset(d.Magnitude, 5) })
		-- the arrowhead at the end
		task.delay(seconds, function()
			local head = Instance.new("Frame")
			head.BorderSizePixel = 0
			head.BackgroundColor3 = color
			head.AnchorPoint = Vector2.new(0.5, 0.5)
			head.Position = UDim2.fromOffset(pb.X - d.Unit.X * 22, pb.Y - d.Unit.Y * 22)
			head.Size = UDim2.fromOffset(16, 16)
			head.Rotation = 45 + math.deg(math.atan2(d.Y, d.X))
			head.ZIndex = 1
			head.Parent = canvas
		end)
		return f
	end
	local dots = {}
	ctx:at(0.6, function()
		ctx:tween(glow, 1.2, { Brightness = 1.6 })
		canvas.BackgroundTransparency = 0
		for side, list in ipairs({ LEFT, RIGHT }) do
			for i, p in ipairs(list) do
				local d = Instance.new("Frame")
				d.BorderSizePixel = 0
				d.BackgroundColor3 = if side == 1 then RED else BLUE
				d.AnchorPoint = Vector2.new(0.5, 0.5)
				d.Position = UDim2.fromOffset(px(p).X, px(p).Y)
				d.Size = UDim2.fromOffset(46, 46)
				d.ZIndex = 2
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(1, 0)
				c.Parent = d
				d.Parent = canvas
				if side == 1 then
					dots[i] = d
				end
			end
		end
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromOffset(px(LEFT[ME]).X, px(LEFT[ME]).Y)
		ring.Size = UDim2.fromOffset(78, 78)
		ring.ZIndex = 2
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = ring
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(240, 240, 240)
		s.Thickness = 4
		s.Parent = ring
		ring.Parent = canvas
	end)
	-- the red web: every left dot to three right dots, evenly
	local k = 0
	for i = 1, 5 do
		for _, j in ipairs({ ((i + 0) % 5) + 1, ((i + 1) % 5) + 1, ((i + 3) % 5) + 1 }) do
			k += 1
			ctx:at(2.0 + k * 0.18, function()
				line(LEFT[i] + Vector2.new(0.03, 0), RIGHT[j] - Vector2.new(0.03, 0), RED, 0.35)
			end)
		end
	end
	-- the blue funnel: every right dot to the top three left dots
	k = 0
	for i = 1, 5 do
		for j = 1, 3 do
			k += 1
			ctx:at(5.0 + k * 0.17, function()
				line(RIGHT[i] - Vector2.new(0.03, 0), LEFT[j] + Vector2.new(0.03, 0), BLUE, 0.3)
			end)
		end
	end
	-- 8.0 the victim's dot: nothing reaches it; it flickers; goes grey
	ctx:during(8.0, 9.0, function(t)
		local d = dots[ME]
		if d then
			d.BackgroundTransparency = if math.floor(t * 10) % 2 == 0 then 0 else 0.7
		end
	end)
	ctx:at(9.0, function()
		local d = dots[ME]
		if d then
			d.BackgroundTransparency = 0
			ctx:tween(d, 1.4, { BackgroundColor3 = Color3.fromRGB(80, 80, 84) })
		end
	end)

	-- the victim, before the board
	local victim = ctx:actor(
		ctx.victim or "figure",
		CFrame.lookAt(Vector3.new(0, 0, 2), Vector3.new(0, 0, -6)),
		"sceneSelectionVictim"
	)
	local function head(): Vector3
		local h = victim and ctx:limb(victim, "Head")
		return if h then ctx.origin:PointToObjectSpace(h.Position) else Vector3.new(0, 4.6, 2)
	end
	-- the colour drains out of them, and they crumble to grey dust
	ctx:at(9.0, function()
		if not victim then
			return
		end
		ctx:face(victim, "sad")
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				local h, s, v = p.Color:ToHSV()
				local _ = h + s
				ctx:tween(p, 1.4, { Color = Color3.fromHSV(0, 0, v * 0.7) })
			end
		end
	end)
	ctx:at(10.5, function()
		if not victim then
			return
		end
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				Vfx.Emit.burst(p.Position, {
					tex = "VfxDust",
					color = Color3.fromRGB(150, 150, 154),
					size = { { 0, 0.2 }, { 1, 0.08 } },
					life = { 1, 1.8 },
					speed = { 0.5, 2 },
					spread = 180,
					accel = Vector3.new(0, -4, 0),
					lit = 0.6,
				}, 18, p.Size)
			end
		end
		ctx:fadeOut(victim, 1.2)
		local d = dots[ME]
		if d then
			ctx:tween(d, 1.0, { BackgroundTransparency = 1 })
		end
	end)
	-- cameras
	ctx:shot(0.0, Vector3.new(2.2, 5.4, 6.4), BOARD, 50)
	ctx:shot(2.0, Vector3.new(0, 5.5, 4.5), BOARD, 48, { eye = Vector3.new(0, 5.5, 3.8) })
	ctx:shot(8.0, Vector3.new(-2.2, 4.0, -2.6), BOARD + Vector3.new(-3.4, -2.6, 0), 34)
	ctx:shot(9.0, function()
		return head() + Vector3.new(0.4, -0.2, -2.6)
	end, function()
		return head()
	end, 38)
	ctx:shot(10.5, Vector3.new(3.4, 4.2, -2.8), Vector3.new(0, 3.0, 2), 46)
	ctx:grade(0, nil, { Saturation = -0.2, Contrast = 0.15, TintColor = Color3.fromRGB(220, 228, 240) }, 0.1)
end

return { length = 12, build = build }
