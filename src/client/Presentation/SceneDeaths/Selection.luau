-- Dead by selection (art/refs/deaths/selection.md, 14 s). Redone 2026-11-10 (the user: "redo the death by selection
-- cutscene entirely because the way you drew those lines looks completely made by AI - instead make the character
-- look at the phone at the second image then up to the starry night sky in contempt with dramatic camera shots").
--
-- An old cemetery at night in fog, under the stars (the user's second picture, 2026-11-11: the angel on her tall
-- pedestal, leaning stones crowding round, bare trees; the set: maps/venues/scenes/selection.py; the sky:
-- SkySceneNight); at the angel's foot heaps of melted wax with candles burning on them (the first picture). The
-- victim stands among the graves reading their phone: on it the chart (scene_pictures.py's
-- SelectionChart, a picture drawn by hand, never lines grown from bars): every blue arrow goes to the top three, none
-- to the ringed dot at the bottom, which is theirs. It lands. The phone comes down, the head comes up to the stars, a
-- slow shake of it, chin high; the hand opens and the phone falls to the roof; they stand so, grey, and go to dust
-- that rises into the sky; the phone's screen goes out. (Not suicide: they are deselected.) No words, no faces.
--
--   0.0   over the shoulder: the lit phone in the hand, the city beyond, soft
--   2.4   the screen itself, filling the frame; a push in to the ringed dot
--   4.6   the face from below, lit by the phone; the phone sinks and its light leaves the face
--   6.6   from low behind: the head comes up, and the camera goes up past it to the Milky Way
--   8.2   from above, the sky's side: the face turned up to the lens, the slow shake of the head
--   9.7   the roof: the phone falls into frame and lands, still lit; the feet beyond
--   10.6  the wide: a small figure against the galaxy, greying, going to dust; up to the sky

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))

local Vfx = require(script.Parent.Parent.Vfx)

local RED = Color3.fromRGB(214, 40, 52)
local BLUE = Color3.fromRGB(40, 108, 220)
local PAPER = Color3.fromRGB(246, 244, 237)
local APP = Color3.fromRGB(14, 16, 22)
local SCREEN_LIGHT = Color3.fromRGB(206, 220, 255)
-- The candles on the wax heaps (scene space: x, base height, z, height; the set's selection.py CANDLES): a flame on
-- each tip.
local CANDLES = {
	{ 2.2, 0.6, -4.3, 0.9 },
	{ 2.8, 0.6, -4.6, 1.25 },
	{ 2.55, 0.6, -3.95, 0.6 },
	{ 1.95, 0.42, -4.75, 0.5 },
	{ 5.05, 1.15, -4.75, 0.8 },
	{ 5.95, 0.52, -4.3, 1.05 },
	{ -3.1, 0.5, -3.5, 0.7 },
	{ -3.55, 0.5, -3.85, 1.1 },
}
-- where the phone lands (scene space): at the victim's right, a little ahead
local LANDING = Vector3.new(1.7, 0.06, -0.6)
local DROP = 9.7

local function ui(parent: Instance, class: string, props: { [string]: any }): any
	local item = Instance.new(class)
	for k, v in pairs(props) do
		item[k] = v
	end
	item.Parent = parent
	return item
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The chart, into `parent` (filling it): the drawn picture, or before the import that carries it the same chart in
-- plain dots (no lines at all rather than the old bars).
local function chart(parent: Instance)
	local id = Assets.texture("SelectionChart")
	if id ~= "" then
		ui(parent, "ImageLabel", {
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
		})
		return
	end
	for side = 0, 1 do
		for k = 0, 4 do
			local dot = ui(parent, "Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if side == 0 then RED else BLUE,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.22 + side * 0.56, 0.13 + k * 0.184),
				Size = UDim2.fromScale(0.1, 0.08),
			})
			ui(dot, "UICorner", { CornerRadius = UDim.new(1, 0) })
			if side == 0 and k == 4 then
				ui(dot, "UIStroke", { Color = Color3.fromRGB(80, 80, 86), Thickness = 3 })
			end
		end
	end
end

-- The phone's screen as the app draws it, into `parent`: a dark app, the post's head (a round picture, two bars for
-- a name: no words anywhere), the chart on its paper, the row under it.
local function appScreen(parent: Instance)
	local screen = ui(parent, "Frame", { BackgroundColor3 = APP, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) })
	-- the status bar: a clock's bar at the left, signal and battery at the right
	ui(screen, "Frame", {
		BackgroundColor3 = Color3.fromRGB(190, 196, 208),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.07, 0.03),
		Size = UDim2.fromScale(0.12, 0.012),
	})
	for k = 0, 2 do
		ui(screen, "Frame", {
			BackgroundColor3 = Color3.fromRGB(190, 196, 208),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0.74 + k * 0.03, 0.042),
			Size = UDim2.fromScale(0.018, 0.006 + k * 0.004),
		})
	end
	local battery = ui(screen, "Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.86, 0.028),
		Size = UDim2.fromScale(0.07, 0.016),
	})
	ui(battery, "UIStroke", { Color = Color3.fromRGB(190, 196, 208), Thickness = 1 })
	ui(battery, "Frame", {
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.08, 0.15),
		Size = UDim2.fromScale(0.18, 0.7),
	})
	-- the post's head
	local face = ui(screen, "Frame", {
		BackgroundColor3 = Color3.fromRGB(70, 76, 92),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.06, 0.09),
		Size = UDim2.fromScale(0.13, 0.065),
	})
	ui(face, "UICorner", { CornerRadius = UDim.new(1, 0) })
	for k, w in ipairs({ 0.34, 0.2 }) do
		local bar = ui(screen, "Frame", {
			BackgroundColor3 = if k == 1 then Color3.fromRGB(150, 156, 170) else Color3.fromRGB(84, 90, 104),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.23, 0.1 + (k - 1) * 0.03),
			Size = UDim2.fromScale(w, 0.014),
		})
		ui(bar, "UICorner", { CornerRadius = UDim.new(1, 0) })
	end
	-- the picture: the chart on its paper (512 x 640)
	local paper = ui(screen, "Frame", {
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.06, 0.2),
		Size = UDim2.fromScale(0.88, 0.55),
		ClipsDescendants = true,
	})
	ui(paper, "UICorner", { CornerRadius = UDim.new(0.03, 0) })
	chart(paper)
	-- the row under it: three round marks and their bars, and the bar to write in
	for k = 0, 2 do
		local mark = ui(screen, "Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.07 + k * 0.2, 0.785),
			Size = UDim2.fromScale(0.07, 0.035),
		})
		ui(mark, "UICorner", { CornerRadius = UDim.new(1, 0) })
		ui(mark, "UIStroke", { Color = Color3.fromRGB(150, 156, 170), Thickness = 2 })
		local count = ui(screen, "Frame", {
			BackgroundColor3 = Color3.fromRGB(84, 90, 104),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.155 + k * 0.2, 0.797),
			Size = UDim2.fromScale(0.07, 0.011),
		})
		ui(count, "UICorner", { CornerRadius = UDim.new(1, 0) })
	end
	local write = ui(screen, "Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 31, 40),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.06, 0.87),
		Size = UDim2.fromScale(0.88, 0.05),
	})
	ui(write, "UICorner", { CornerRadius = UDim.new(1, 0) })
	return screen
end

local function build(ctx)
	-- the cemetery (modelled: art/scripts/maps/venues/scenes/selection.py); before its import, bare grass
	local built = ctx:set() ~= nil
	if not built then
		ctx:part({
			size = Vector3.new(60, 1, 60),
			at = Vector3.new(0, -0.5, -4),
			color = Color3.fromRGB(52, 58, 48),
			material = Enum.Material.Grass,
		})
	end
	-- the moon's cold light from high behind the angel, a faint fill toward the victim's face
	ctx:light(Vector3.new(10, 26, -24), Color3.fromRGB(150, 168, 210), 60, 0.9)
	ctx:light(Vector3.new(-3, 7, 5), Color3.fromRGB(110, 124, 160), 16, 0.3)
	-- the candles: a living flame on every wick, their warm light on the wax and the stones (the set's own wax and
	-- candles; nothing floats before its import)
	if built then
		for i, c in ipairs(CANDLES) do
			local wick = ctx:part({
				size = Vector3.new(0.05, 0.05, 0.05),
				at = Vector3.new(c[1], c[2] + c[4] + 0.06, c[3]),
				alpha = 1,
				cast = false,
				name = "Wick",
			})
			-- (only every other flame carries a light: eight lights in a heap only burn white)
			Vfx.Recipes.flame(wick, { kind = "candle", scale = 0.28, lit = true, light = i % 2 == 1 } :: any)
		end
		ctx:light(Vector3.new(2.6, 2.2, -4.0), Color3.fromRGB(255, 176, 110), 14, 1.1)
		ctx:light(Vector3.new(-3.3, 1.9, -3.4), Color3.fromRGB(255, 176, 110), 11, 0.8)
	end

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneSelectionVictim")
	local function head(): Vector3
		local h = victim and ctx:limb(victim, "Head")
		return if h then ctx.origin:PointToObjectSpace(h.Position) else Vector3.new(0, 4.6, 0)
	end

	-- the phone in the reading hand (Costumes.phone, solved on the clip's reading pose): the Core phone, its red
	-- summons screen put out; over it the screen this scene shows, with its own light
	local phone: Model? = if victim then ctx:wear(victim, "phone") else nil
	local glass: BasePart? = nil
	local glow: PointLight? = nil
	local arm = victim and ctx:limb(victim, "Right Arm")
	if phone and arm then
		local k = phone:GetAttribute("CostumeScale") or 1
		for _, item in ipairs(phone:GetDescendants()) do
			if item:IsA("BasePart") and string.find(item.Name, "_Glow", 1, true) then
				item.Material = Enum.Material.SmoothPlastic
				item.Color = APP
			elseif item:IsA("Light") then
				item:Destroy()
			end
		end
		-- (the model's +Y is its screen and +Z its top: the glass lies on it turned about, so its picture's top is
		-- the phone's top)
		local g = ctx:part({ size = Vector3.new(0.46, 0.012, 0.92) * k, color = APP, cast = false, name = "Glass" })
		g.Anchored = false
		g.Massless = true
		g.CFrame = phone:GetPivot() * CFrame.new(0, 0.052 * k, 0) * CFrame.Angles(0, math.pi, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arm
		weld.Part1 = g
		weld.Parent = g
		g.Parent = phone
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(460, 920)
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = g
		appScreen(gui)
		local light = Instance.new("PointLight")
		light.Color = SCREEN_LIGHT
		light.Range = 7
		light.Brightness = 1.7
		light.Shadows = false
		light.Parent = g
		glass, glow = g, light
	end
	local function phoneAt(): Vector3
		return if glass then ctx.origin:PointToObjectSpace(glass.Position) else Vector3.new(0.4, 3.6, -1)
	end

	-- 2.4 the screen itself: drawn flat over the frame (sharp, upright whatever the hand does), drifting a little as a
	-- held phone does; a thumb's scroll; then the push in to the ringed dot
	ctx:at(2.4, function()
		local layer = ctx:layer(4)
		ui(
			layer,
			"Frame",
			{ BackgroundColor3 = Color3.fromRGB(4, 5, 8), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }
		)
		local body = ui(layer, "Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(10, 10, 12),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(1, 1.3),
			Rotation = -3,
		})
		ui(body, "UIAspectRatioConstraint", { AspectRatio = 0.5, DominantAxis = Enum.DominantAxis.Height })
		ui(body, "UICorner", { CornerRadius = UDim.new(0.07, 0) })
		ui(body, "UIStroke", { Color = Color3.fromRGB(70, 74, 84), Thickness = 3 })
		local zoom = ui(body, "UIScale", { Scale = 1 })
		local inner = ui(body, "Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.03, 0.015),
			Size = UDim2.fromScale(0.94, 0.97),
			ClipsDescendants = true,
		})
		ui(inner, "UICorner", { CornerRadius = UDim.new(0.06, 0) })
		appScreen(inner)
		-- the glass's shine: a pale band across it
		local shine = ui(inner, "Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(-0.2, 0.1),
			Size = UDim2.fromScale(1.6, 0.16),
			Rotation = -24,
			ZIndex = 3,
		})
		-- the lens's dark corners
		local dark = ui(
			layer,
			"Frame",
			{ BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5 }
		)
		ui(dark, "UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.3, 1),
				NumberSequenceKeypoint.new(0.7, 1),
				NumberSequenceKeypoint.new(1, 0.25),
			}),
		})
		-- (the ringed dot from the phone's middle, in screen heights, at scale 1: see appScreen's layout)
		local DOT = Vector2.new(-0.16, 0.232)
		ctx:during(2.4, 4.6, function(t)
			local height = layer.AbsoluteSize.Y
			-- the hand: a slow drift; the thumb's scroll at 3.0 (the page jumps up a little and settles back)
			local drift = Vector2.new(math.sin(t * 1.3) * 0.006, math.sin(t * 0.9 + 1) * 0.008)
			local scroll = if t > 3.0 and t < 3.5 then -0.03 * math.sin((t - 3.0) / 0.5 * math.pi) else 0
			-- the push in: from the whole screen to the ringed dot
			local u = smooth((t - 3.5) / 1.0)
			local s = 1 + 1.25 * u
			zoom.Scale = s
			local to = -DOT * s * u
			body.Position =
				UDim2.new(0.5, (drift.X + to.X) * height, 0.56 - 0.06 * u, (drift.Y + scroll + to.Y) * height)
			body.Rotation = -3 + 3 * u
			shine.Position = UDim2.fromScale(-0.2 + 0.1 * math.sin(t * 0.8), 0.1 + 0.05 * math.sin(t * 0.6))
		end)
		ctx:atNow(4.6, function()
			layer:Destroy()
		end)
	end)

	-- 9.7 the hand opens: the phone falls, turning, lands on the roof face up, a small bounce; its screen stays lit
	-- until the end, then goes out
	ctx:at(DROP, function()
		if not phone then
			return
		end
		for _, item in ipairs(phone:GetDescendants()) do
			if item:IsA("WeldConstraint") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		local from = phone:GetPivot()
		local to = ctx.origin * CFrame.new(LANDING) * CFrame.Angles(0, math.rad(28), 0)
		ctx:during(DROP, DROP + 0.95, function(t)
			local u = math.clamp((t - DROP) / 0.42, 0, 1)
			local at = from.Position:Lerp(to.Position, u)
			-- (falling: slow off the hand, fast into the roof)
			at = Vector3.new(at.X, from.Position.Y + (to.Position.Y - from.Position.Y) * u * u, at.Z)
			local turn = from.Rotation:Lerp(to.Rotation, u)
				* CFrame.Angles(math.sin(u * math.pi) * 2.2, 0, math.sin(u * math.pi) * 0.7)
			if u >= 1 then
				-- the bounce: up a hand's width, a corner lifting, down
				local v = math.clamp((t - DROP - 0.42) / 0.4, 0, 1)
				local hop = math.sin(v * math.pi) * (1 - v)
				at += Vector3.new(0, 0.34 * hop, 0)
				turn = to.Rotation * CFrame.Angles(0.3 * hop, 0, -0.2 * hop)
			end
			phone:PivotTo(CFrame.new(at) * turn)
		end)
	end)
	ctx:at(DROP + 0.42, function()
		Vfx.Emit.burst(ctx:world(LANDING), {
			tex = "VfxDust",
			color = Color3.fromRGB(120, 120, 128),
			size = { { 0, 0.08 }, { 1, 0.2 } },
			alpha = { { 0, 0.5 }, { 1, 1 } },
			life = { 0.4, 0.8 },
			speed = { 0.6, 2 },
			spread = 80,
			lit = 0.6,
		}, 10)
	end)
	ctx:at(12.9, function()
		if glow then
			ctx:tween(glow, 0.5, { Brightness = 0 })
		end
		local gui = glass and glass:FindFirstChildOfClass("SurfaceGui")
		if gui then
			ctx:tween(gui, 0.5, { Brightness = 0 })
		end
	end)

	-- 10.6 the colour drains out of them; 11.7 they go to dust, from the feet up, and the dust RISES
	local function parts(): { BasePart }
		local list = {}
		if victim then
			for _, p in ipairs(victim:GetDescendants()) do
				if
					p:IsA("BasePart")
					and p.Transparency < 1
					and p.Name ~= "HumanoidRootPart"
					and not p:IsDescendantOf(phone or script)
				then
					table.insert(list, p)
				end
			end
		end
		return list
	end
	ctx:at(10.6, function()
		for _, p in ipairs(parts()) do
			local _, _, v = p.Color:ToHSV()
			ctx:tween(p, 1.1, { Color = Color3.fromHSV(0, 0, v * 0.7) })
			-- (a worn thing keeps its picture: its texture is let go so the grey shows)
			if p:IsA("MeshPart") and p.TextureID ~= "" then
				task.delay(0.6, function()
					p.TextureID = ""
				end)
			end
		end
	end)
	ctx:at(11.7, function()
		local list = parts()
		table.sort(list, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
		-- cold ash, from the feet up, lifting and carried off toward the sky (2026-11-12: the old dust was "ugly")
		Vfx.Recipes.dissolve(list, 1.4, {
			tint = Color3.fromRGB(150, 156, 172),
			glow = Color3.fromRGB(196, 214, 255),
			wind = Vector3.new(0.8, 0, -1.6),
			rise = 3.2,
			fade = 0.7,
		})
	end)

	-- cameras
	-- 0.0 over the right shoulder: the phone lit in the hand, the city soft beyond; a slow push
	ctx:camera(0, 2.4, function(t)
		local u = t / 2.4
		local eye = Vector3.new(1.75 - 0.25 * u, 5.15, 2.9 - 0.5 * u)
		return CFrame.lookAt(eye, phoneAt():Lerp(head(), 0.25)), 36 - 2 * u
	end)
	ctx:focus(0, 2.4, 3.4, 5)
	-- 2.4 (the screen is drawn over this) the same, held
	ctx:camera(2.4, 4.6, function()
		return CFrame.lookAt(Vector3.new(1.5, 5.15, 2.4), phoneAt():Lerp(head(), 0.25)), 34
	end)
	-- 4.6 the face from below, lit by the phone; the camera sinks a little as the phone does
	ctx:camera(4.6, 6.6, function(t)
		local u = smooth((t - 4.6) / 2.0)
		local h = head()
		local eye = h + Vector3.new(-0.95 + 0.3 * u, -1.0 - 0.15 * u, -2.3)
		return CFrame.lookAt(eye, h + Vector3.new(0, -0.1, 0)), 34
	end)
	ctx:focus(4.6, 6.6, 2.6, 4)
	-- 6.6 from low behind: as the head comes up the camera goes up past it to the Milky Way, opening wide
	ctx:camera(6.6, 8.2, function(t)
		local u = smooth((t - 6.7) / 1.3)
		local eye = Vector3.new(0.9 - 0.3 * u, 1.3 + 0.5 * u, 3.6 - 0.4 * u)
		local look = (head() + Vector3.new(0, 0.2, 0)):Lerp(Vector3.new(-2, 30, -26), u)
		return CFrame.lookAt(eye, look), 38 + 16 * u
	end)
	-- 8.2 from the sky's side: down on the face turned up to the lens, the slow shake of the head; closing in
	ctx:camera(8.2, DROP, function(t)
		local u = (t - 8.2) / (DROP - 8.2)
		local h = head()
		local eye = h + Vector3.new(0.5 - 0.2 * u, 3.3 - 0.7 * u, -2.6 + 0.5 * u)
		return CFrame.lookAt(eye, h), 32 - 3 * u
	end)
	ctx:focus(8.2, DROP, 4.0, 5)
	-- 9.7 the roof: the phone falls into frame and lands; the feet beyond
	ctx:camera(DROP, 10.6, function(t)
		local u = (t - DROP) / 0.9
		local eye = LANDING + Vector3.new(1.5 - 0.15 * u, 0.3, -1.2)
		return CFrame.lookAt(eye, LANDING + Vector3.new(-0.2, 0.25, 0.1)), 40
	end)
	ctx:focus(DROP, 10.6, 2.0, 3)
	-- 10.6 the wide: small against the galaxy; the camera sinks back and, as they go, goes up to the sky
	ctx:camera(10.6, 14, function(t)
		local u = (t - 10.6) / 3.4
		local up = smooth((t - 12.3) / 1.7)
		local eye = Vector3.new(-3.8 - 0.8 * u, 1.5 - 0.3 * u, 9.5 + 1.2 * u)
		local look = Vector3.new(0, 7.5, -4):Lerp(Vector3.new(1, 34, -22), up)
		return CFrame.lookAt(eye, look), 46 + 6 * up
	end)
	ctx:grade(0, nil, { Saturation = -0.08, Contrast = 0.12, TintColor = Color3.fromRGB(226, 234, 255) }, 0.1)
	ctx:grade(10.6, nil, { Saturation = -0.3, Contrast = 0.16, TintColor = Color3.fromRGB(220, 228, 250) }, 1.2)
end

return { length = 14, build = build }
