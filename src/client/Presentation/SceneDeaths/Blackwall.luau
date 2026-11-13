-- Blackwall gateway (art/refs/deaths/blackwall.md, 23.3 s): FIRST PERSON from the hacker's eye (never seen) in an
-- underground car park: the victim stands before us arms crossed, two bystanders behind at the left, a blue car on a
-- lift at the right. Scan mode (dark teal-green, red wire outlines); the quickhack menu (RAM bar, the list stepping
-- down to BLACKWALL GATEWAY, the panel); the upload (green data streams, the red quickhack icon with its bar over the
-- victim's head); out of scan with the picture tearing in red and cyan; red glitch FIGURES climbing onto the victim
-- and overtaking them, red-orange glitch fire; the white-red pillar of light; burning, staggering, down. Our own HUD
-- drawing (the layout copied).

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local CYAN = Color3.fromRGB(94, 246, 255)
local RED = Color3.fromRGB(255, 52, 64)
local EMBER = Color3.fromRGB(255, 110, 40)
local GREEN = Color3.fromRGB(80, 255, 140)
local HOT = Color3.fromRGB(255, 226, 190)

-- The quickhacks' icons, DRAWN (2026-11-12, the user: "MAKE SURE you dont use emojis": the symbols typed here before
-- came out as coloured emoji): each from a few plain frames in a square holder. 1 ping (rings round a dot), 2 sonic
-- shock (a waveform), 3 overheat (heat rising off a bar), 4 short circuit (a bolt), 5 the gateway (a wall, breached).
local function drawIcon(parent: Instance, kind: number, color: Color3)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.78, 0.78)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.Parent = parent
	local function bar(x: number, y: number, w: number, h: number, turn: number?, c: Color3?)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = c or color
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = turn or 0
		f.Parent = holder
		return f
	end
	local function ring(size: number)
		local f = Instance.new("Frame")
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(size, size)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = f
		local edge = Instance.new("UIStroke")
		edge.Color = color
		edge.Thickness = 1.5
		edge.Parent = f
		f.Parent = holder
	end
	if kind == 1 then
		ring(0.9)
		ring(0.5)
		local dot = bar(0.5, 0.5, 0.18, 0.18)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = dot
	elseif kind == 2 then
		for i, h in ipairs({ 0.3, 0.7, 1.0, 0.55, 0.85, 0.35 }) do
			bar(0.08 + (i - 1) * 0.168, 0.5, 0.09, h)
		end
	elseif kind == 3 then
		bar(0.5, 0.9, 0.9, 0.12)
		for i = 0, 2 do
			local x = 0.22 + i * 0.28
			bar(x + 0.05, 0.62, 0.09, 0.26, 24)
			bar(x - 0.05, 0.4, 0.09, 0.26, -24)
			bar(x + 0.05, 0.18, 0.09, 0.26, 24)
		end
	elseif kind == 4 then
		bar(0.58, 0.24, 0.16, 0.5, 28)
		bar(0.5, 0.5, 0.5, 0.13, -8)
		bar(0.42, 0.76, 0.16, 0.5, 28)
	else
		for row = 0, 2 do
			for col = 0, 2 do
				if not (row == 1 and col == 1) then
					bar(0.18 + col * 0.32 + (row % 2) * 0.05, 0.2 + row * 0.3, 0.26, 0.22)
				end
			end
		end
		bar(0.5, 0.5, 0.2, 0.2, 45, RED)
	end
	return holder
end

-- The glitch is STEPPED (2026-11-10 remake): fourteen hard jumps a second read as data; a smooth move reads as smoke.
local STEP = 14
local LIMBS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
-- A red figure of blocks, about its torso: the arms up and forward, reaching.
local REACH = CFrame.Angles(math.rad(-50), 0, 0)
local FIGURE = {
	{ size = Vector3.new(2, 2, 1), cf = CFrame.new() },
	{ size = Vector3.new(1.2, 1.2, 1.2), cf = CFrame.new(0, 1.6, 0) },
	{ size = Vector3.new(1, 2, 1), cf = CFrame.new(-1.5, 1.64, -0.77) * REACH },
	{ size = Vector3.new(1, 2, 1), cf = CFrame.new(1.5, 1.64, -0.77) * REACH },
	{ size = Vector3.new(1, 2, 1), cf = CFrame.new(-0.5, -2, 0) },
	{ size = Vector3.new(1, 2, 1), cf = CFrame.new(0.5, -2, 0) },
}

local function ui(parent: Instance, class: string, props: { [string]: any }): any
	local item = Instance.new(class)
	for k, v in pairs(props) do
		item[k] = v
	end
	item.Parent = parent
	return item
end

local function text(
	parent: Instance,
	t: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	align: Enum.TextXAlignment?
)
	return ui(parent, "TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextScaled = true,
		TextColor3 = color,
		Text = t,
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left,
	})
end

-- The set of parts (before it was modelled): only when the Scenes import is missing.
local function standIn(ctx)
	-- the car park
	ctx:part({
		size = Vector3.new(60, 1, 60),
		at = Vector3.new(0, -0.5, -6),
		color = Color3.fromRGB(70, 70, 72),
		material = Enum.Material.Concrete,
	})
	ctx:part({
		size = Vector3.new(60, 1, 60),
		at = Vector3.new(0, 12.5, -6),
		color = Color3.fromRGB(46, 46, 48),
		material = Enum.Material.Concrete,
	})
	ctx:part({
		size = Vector3.new(60, 13, 1),
		at = Vector3.new(0, 6, 16),
		color = Color3.fromRGB(56, 58, 60),
		material = Enum.Material.Concrete,
	})
	-- the back wall's roller shutter and a pillar painted with a big 1
	ctx:part({
		size = Vector3.new(14, 9, 0.4),
		at = Vector3.new(6, 4.5, 15.4),
		color = Color3.fromRGB(70, 78, 92),
		material = Enum.Material.CorrodedMetal,
	})
	local pillar = ctx:part({
		size = Vector3.new(2.4, 13, 2.4),
		at = Vector3.new(9, 6, 6),
		color = Color3.fromRGB(96, 92, 84),
		material = Enum.Material.Concrete,
	})
	ctx:part({
		size = Vector3.new(2.45, 2.5, 2.45),
		at = Vector3.new(9, 1.25, 6),
		color = Color3.fromRGB(200, 160, 40),
		material = Enum.Material.Concrete,
	})
	ctx:text(pillar, Enum.NormalId.Front, "1", Color3.fromRGB(30, 140, 150), Enum.Font.GothamBlack, 0.3)
	for _, x in ipairs({ 16, -10 }) do
		ctx:part({
			size = Vector3.new(2.4, 13, 2.4),
			at = Vector3.new(x, 6, 12),
			color = Color3.fromRGB(96, 92, 84),
			material = Enum.Material.Concrete,
		})
	end
	-- the blue car on a lift, at the right
	local car = Vector3.new(-9, 0, 4)
	ctx:part({
		size = Vector3.new(5, 0.3, 9),
		at = car + Vector3.new(0, 4.2, 0),
		color = Color3.fromRGB(70, 70, 74),
		material = Enum.Material.Metal,
	})
	for _, z in ipairs({ -4, 4 }) do
		ctx:part({
			size = Vector3.new(0.5, 9, 0.5),
			at = car + Vector3.new(-2.8, 4.5, z),
			color = Color3.fromRGB(200, 170, 60),
			material = Enum.Material.Metal,
		})
	end
	ctx:part({
		size = Vector3.new(4.4, 1.4, 8.4),
		at = car + Vector3.new(0, 1.2, 0),
		color = Color3.fromRGB(40, 90, 200),
		material = Enum.Material.SmoothPlastic,
	})
	ctx:part({
		size = Vector3.new(4.0, 1.1, 4.4),
		at = car + Vector3.new(0, 2.4, 0.4),
		color = Color3.fromRGB(20, 30, 50),
		material = Enum.Material.Glass,
		alpha = 0.2,
	})
	for _, w in ipairs({
		Vector3.new(-2.2, 0.6, -2.8),
		Vector3.new(2.2, 0.6, -2.8),
		Vector3.new(-2.2, 0.6, 2.8),
		Vector3.new(2.2, 0.6, 2.8),
	}) do
		ctx:part({
			size = Vector3.new(0.6, 1.3, 1.3),
			at = car + w,
			color = Color3.fromRGB(14, 14, 16),
			shape = "Cylinder",
		})
	end
	ctx:part({
		size = Vector3.new(4.4, 1.2, 8.4),
		at = car + Vector3.new(0, 5.2, 0),
		color = Color3.fromRGB(150, 150, 154),
		material = Enum.Material.Metal,
	})
	-- fluorescent tubes, haze
	for _, at in ipairs({ Vector3.new(0, 12, -2), Vector3.new(-8, 12, 6), Vector3.new(8, 12, 6) }) do
		ctx:part({ size = Vector3.new(0.4, 0.2, 5), at = at, color = Color3.fromRGB(240, 246, 230), glow = true })
		ctx:light(at - Vector3.new(0, 1, 0), Color3.fromRGB(232, 236, 214), 22, 1.6, at.X == 0)
	end
end

local function build(ctx)
	if ctx:set() then
		-- (the car park, modelled: art/scripts/maps/venues/scenes/blackwall.py; its fittings light it)
		ctx:light(Vector3.new(-0.5, 7, -4), Color3.fromRGB(236, 232, 214), 14, 0.45)
	else
		standIn(ctx)
	end
	local haze = SceneDeaths.emit(ctx, Vector3.new(0, 3, 4), Vector3.new(30, 6, 24), {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(200, 196, 180),
		size = { { 0, 6 }, { 1, 10 } },
		alpha = { { 0, 1 }, { 0.4, 0.9 }, { 1, 1 } },
		life = { 6, 9 },
		rate = 3,
		speed = { 0.1, 0.3 },
		rot = { 0, 360 },
		lit = 0.6,
	})
	haze:Emit(10)

	-- the victim, arms crossed, facing us; two bystanders behind at the left
	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, -9)), "sceneBlackwallVictim")
	local by = {}
	for i, at in ipairs({ Vector3.new(5.5, 0, 6), Vector3.new(7.2, 0, 8.4) }) do
		-- (the second is caught a moment after the first: not one body twice)
		local b = ctx:actor(
			if i == 1 then "cast:bystanderA" else "cast:bystanderB",
			CFrame.lookAt(at, Vector3.new(0, 0, -9)),
			"sceneBlackwallBystander",
			if i == 2 then 0.35 else 0
		)
		if b then
			table.insert(by, b)
		end
	end
	local everyone = table.clone(by)
	if victim then
		table.insert(everyone, victim)
	end

	-- the hacker's eye: still, a little hand-held sway; turning away at the end
	local eye = Vector3.new(-1.0, 5.2, -9.5)
	ctx:camera(0, 23.3, function(t)
		local sway = Vector3.new(math.sin(t * 0.7) * 0.06, math.sin(t * 1.1) * 0.04, 0)
		local look = Vector3.new(0.4, 4.2, 0)
		if t > 21.8 then
			local u = math.clamp((t - 21.8) / 1.4, 0, 1)
			look = look:Lerp(Vector3.new(-10, 3.8, -4), u * u * (3 - 2 * u))
		end
		return CFrame.lookAt(eye + sway, look + sway), 58
	end)

	-- the HUD, drawn like the game's (2026-11-10, "the on screen UI ... looks extremely low quality"): top left the
	-- health bar (a cyan segmented bar on a dark backing, its number in a box, the stamina bar under it); top centre
	-- the compass strip; top right the clock and the minimap (streets in cyan, the player's wedge); bottom left the
	-- quickhack quick slots with their glyphs; bottom centre the subtitle box
	local hud = ctx:layer(3)
	local DARK = Color3.fromRGB(8, 12, 16)
	local function panel(x: number, y: number, w: number, h: number, alpha: number?): Frame
		local f = ui(hud, "Frame", {
			BackgroundColor3 = DARK,
			BackgroundTransparency = alpha or 0.35,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
		})
		ui(f, "UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.45 })
		return f
	end
	-- health
	local hpBox = panel(0.03, 0.135, 0.032, 0.04, 0.2)
	text(hpBox, "79", 0.05, 0.05, 0.9, 0.9, CYAN, Enum.TextXAlignment.Center)
	local hp = panel(0.066, 0.14, 0.2, 0.022)
	for k = 0, 9 do
		ui(hp, "Frame", {
			BackgroundColor3 = if k < 8 then CYAN else Color3.fromRGB(40, 70, 80),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.02 + k * 0.097, 0.25),
			Size = UDim2.fromScale(0.085, 0.5),
		})
	end
	local stamina = panel(0.066, 0.168, 0.14, 0.01, 0.5)
	ui(stamina, "Frame", {
		BackgroundColor3 = Color3.fromRGB(230, 232, 236),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.9, 1),
		Position = UDim2.fromScale(0.02, 0),
	})
	-- the compass strip
	local compass = panel(0.38, 0.045, 0.24, 0.03, 0.5)
	for k, letter in ipairs({ "W", "NW", "N", "NE", "E" }) do
		text(
			compass,
			letter,
			0.04 + (k - 1) * 0.22,
			0.1,
			0.1,
			0.8,
			if letter == "N" then CYAN else Color3.fromRGB(190, 196, 200),
			Enum.TextXAlignment.Center
		)
		for j = 1, 3 do
			ui(compass, "Frame", {
				BackgroundColor3 = Color3.fromRGB(120, 130, 136),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.09 + (k - 1) * 0.22 + j * 0.05, 0.35),
				Size = UDim2.fromScale(0.004, 0.3),
			})
		end
	end
	ui(compass, "Frame", {
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.498, 0),
		Size = UDim2.fromScale(0.006, 1),
	})
	-- the clock and the minimap
	text(hud, "4:05 PM", 0.86, 0.045, 0.1, 0.025, Color3.fromRGB(220, 224, 228))
	local map = panel(0.85, 0.08, 0.12, 0.2, 0.25)
	for k, spec in ipairs({
		{ 0.1, 0.5, 0.8, 0.02, 0 },
		{ 0.5, 0.1, 0.02, 0.8, 0 },
		{ 0.2, 0.25, 0.5, 0.015, 35 },
		{ 0.6, 0.6, 0.35, 0.015, -20 },
		{ 0.15, 0.75, 0.3, 0.015, 10 },
	}) do
		ui(map, "Frame", {
			BackgroundColor3 = if k == 2 then Color3.fromRGB(230, 200, 60) else CYAN,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(spec[1], spec[2]),
			Size = UDim2.fromScale(spec[3], spec[4]),
			Rotation = spec[5],
		})
	end
	local me = ui(map, "Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.08, 0.05),
		Rotation = 45,
	})
	ui(me, "UICorner", { CornerRadius = UDim.new(0.2, 0) })
	ui(map, "Frame", {
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.58, 0.4),
		Size = UDim2.fromScale(0.06, 0.04),
	})
	-- the quickhack quick slots
	for k = 1, 5 do
		local slot = panel(0.03 + (k - 1) * 0.037, 0.8, 0.032, 0.05, 0.3)
		local top = ui(slot, "Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.05),
			Size = UDim2.fromScale(0.9, 0.6),
		})
		drawIcon(top, k, CYAN)
		text(slot, tostring(k), 0.05, 0.62, 0.9, 0.34, Color3.fromRGB(170, 180, 186), Enum.TextXAlignment.Center)
	end
	local subBox = panel(0.2, 0.83, 0.6, 0.045, 0.45)
	subBox.Visible = false
	local subtitle = text(subBox, "", 0.02, 0.1, 0.96, 0.8, Color3.fromRGB(240, 240, 240), Enum.TextXAlignment.Center)
	subtitle:GetPropertyChangedSignal("Text"):Connect(function()
		subBox.Visible = subtitle.Text ~= ""
	end)

	-- scan mode: teal-green, red wire outlines, red scan lines
	local outlines = {}
	local scan: Frame? = nil
	ctx:at(1.5, function()
		for _, m in ipairs(everyone) do
			local h = Instance.new("Highlight")
			h.FillColor = RED
			h.FillTransparency = 0.85
			h.OutlineColor = RED
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = m
			table.insert(outlines, h)
		end
		local layer = ctx:layer(2)
		for k = 0, 40 do
			ui(layer, "Frame", {
				BackgroundColor3 = RED,
				BackgroundTransparency = 0.88,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, k / 40),
				Size = UDim2.fromScale(1, 0.002),
			})
		end
		-- the scanner's corner brackets and a band sweeping down the picture
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local bracket = ui(layer, "Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(c[1], c[2]),
				Position = UDim2.fromScale(c[1] * 0.98 + 0.01, c[2] * 0.96 + 0.02),
				Size = UDim2.fromScale(0.04, 0.07),
			})
			ui(bracket, "UIStroke", { Color = RED, Thickness = 2, Transparency = 0.3 })
		end
		local band = ui(layer, "Frame", {
			BackgroundColor3 = RED,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.02),
		})
		ctx:during(1.5, 13.0, function(t)
			band.Position = UDim2.fromScale(0, (t * 0.35) % 1)
		end)
		scan = layer
	end)
	ctx:grade(
		1.5,
		13.0,
		{ Saturation = -0.75, Contrast = 0.25, Brightness = -0.12, TintColor = Color3.fromRGB(120, 255, 210) },
		0.2
	)

	-- the quickhack menu
	local menu: Frame? = nil
	local rows = {}
	local ram = {}
	local listNames =
		{ { "PING", 4 }, { "SONIC SHOCK", 4 }, { "OVERHEAT", 6 }, { "SHORT CIRCUIT", 7 }, { "BLACKWALL GATEWAY", 6 } }
	ctx:at(2.5, function()
		local m = ui(hud, "Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		text(m, "CYBERDECK RAM  14/14", 0.38, 0.17, 0.24, 0.025, RED, Enum.TextXAlignment.Center)
		for k = 0, 13 do
			ram[k + 1] = ui(m, "Frame", {
				BackgroundColor3 = CYAN,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.37 + k * 0.0187, 0.2),
				Size = UDim2.fromScale(0.014, 0.04),
			})
		end
		text(m, "AVAILABLE QUICKHACKS", 0.09, 0.3, 0.2, 0.022, CYAN)
		for i, spec in ipairs(listNames) do
			local row = ui(m, "Frame", {
				BackgroundColor3 = Color3.fromRGB(6, 22, 28),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.09, 0.33 + (i - 1) * 0.056),
				Size = UDim2.fromScale(0.24, 0.048),
			})
			local stroke = ui(row, "UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.5 })
			local lead = ui(row, "Frame", {
				BackgroundColor3 = CYAN,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.012, 1),
				BackgroundTransparency = 1,
			})
			local icon = ui(row, "Frame", {
				BackgroundColor3 = Color3.fromRGB(10, 40, 48),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.03, 0.15),
				Size = UDim2.fromScale(0.1, 0.7),
			})
			ui(icon, "UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.4 })
			drawIcon(icon, i, CYAN)
			local name = text(row, spec[1], 0.16, 0.15, 0.6, 0.7, CYAN)
			local cost = ui(row, "Frame", {
				BackgroundColor3 = Color3.fromRGB(10, 40, 48),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.8, 0.2),
				Size = UDim2.fromScale(0.16, 0.6),
			})
			ui(cost, "UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.4 })
			text(cost, tostring(spec[2]), 0.05, 0.05, 0.9, 0.9, CYAN, Enum.TextXAlignment.Center)
			rows[i] = { frame = row, stroke = stroke, name = name, lead = lead }
		end
		local panel = ui(m, "Frame", {
			BackgroundColor3 = Color3.fromRGB(10, 10, 18),
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.67, 0.3),
			Size = UDim2.fromScale(0.22, 0.38),
		})
		ui(panel, "UIStroke", { Color = CYAN, Thickness = 1, Transparency = 0.4 })
		local title = text(panel, "", 0.05, 0.03, 0.9, 0.08, CYAN)
		title.Name = "Title"
		ui(panel, "Frame", {
			BackgroundColor3 = CYAN,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.05, 0.13),
			Size = UDim2.fromScale(0.9, 0.004),
		})
		local desc = text(panel, "", 0.05, 0.16, 0.9, 0.62, Color3.fromRGB(230, 230, 236))
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextScaled = false
		desc.TextSize = 13
		desc.TextWrapped = true
		desc.Name = "Desc"
		ui(panel, "Frame", {
			BackgroundColor3 = CYAN,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.05, 0.82),
			Size = UDim2.fromScale(0.9, 0.004),
		})
		local foot = text(panel, "", 0.05, 0.85, 0.9, 0.1, Color3.fromRGB(170, 190, 196))
		foot.Name = "Foot"
		menu = m
	end)
	local descs = {
		"Reveals enemies and devices connected to the local network.",
		"Deafens the target. Cuts off their communication with allies.",
		"Sets the target on fire, dealing damage over time.",
		"Deals electrical damage to the target's cyberware.",
		"Ultimate quickhack. Spreads to enemies nearby, causing lethal damage to cyberware and neural systems. Whatever lies beyond the Blackwall comes through.",
	}
	local uploads = { "1.2", "2.0", "2.6", "3.1", "4.6" }
	local function selectRow(i: number)
		for k, r in ipairs(rows) do
			local on = k == i
			r.frame.BackgroundColor3 = if on then Color3.fromRGB(16, 78, 92) else Color3.fromRGB(6, 22, 28)
			r.stroke.Transparency = if on then 0 else 0.5
			r.lead.BackgroundTransparency = if on then 0 else 1
		end
		local title = menu and menu:FindFirstChild("Title", true)
		local desc = menu and menu:FindFirstChild("Desc", true)
		local foot = menu and menu:FindFirstChild("Foot", true)
		if title and desc and foot then
			title.Text = listNames[i][1]
			desc.Text = descs[i]
			foot.Text = "UPLOAD TIME  " .. uploads[i] .. " s      RAM  " .. listNames[i][2]
		end
	end
	for i, t in ipairs({ 2.6, 4.0, 5.0, 6.0, 7.0 }) do
		ctx:at(t, function()
			selectRow(i)
			if i == 5 then
				local r = rows[5]
				r.frame.BackgroundColor3 = Color3.fromRGB(110, 14, 22)
				r.stroke.Color = RED
				r.name.TextColor3 = Color3.fromRGB(255, 220, 220)
				for k = 9, 14 do
					if ram[k] then
						ram[k].BackgroundColor3 = RED
					end
				end
			end
		end)
	end
	-- the target's name over the victim
	ctx:at(2.5, function()
		local h = victim and ctx:limb(victim, "Head")
		if h then
			local tag = Instance.new("BillboardGui")
			tag.Adornee = h
			tag.Size = UDim2.fromScale(6, 1)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
			tag.AlwaysOnTop = true
			tag.LightInfluence = 0
			tag.Parent = workspace.CurrentCamera
			text(tag, "// " .. string.upper(ctx.victimName), 0, 0, 1, 1, CYAN, Enum.TextXAlignment.Center)
			table.insert(ctx.cleanups, function()
				tag:Destroy()
			end)
		end
	end)
	-- the upload: green data streaming at them, glitch blocks, the red icon with its bar over every head
	local streams = {}
	local upLabel: TextLabel? = nil
	local function slab(color: Color3): BasePart
		return ctx:part({
			size = Vector3.new(0.5, 0.1, 0.05),
			at = Vector3.new(0, -40, 0),
			color = color,
			glow = true,
			alpha = 1,
			cast = false,
		})
	end
	-- the data itself: packets flying from the eye into each of them, in lanes; the wire outlines fill as it lands
	local packets = {}
	ctx:at(10.0, function()
		if #everyone == 0 then
			return
		end
		for k = 1, 36 do
			packets[k] = {
				part = slab(if k % 4 == 0 then Color3.fromRGB(230, 255, 240) else GREEN),
				u = math.random(),
				lane = k,
				target = everyone[(k % #everyone) + 1],
			}
		end
	end)
	ctx:during(10.0, 12.95, function(t, dt)
		local cam = workspace.CurrentCamera.CFrame
		local from = cam * Vector3.new(0, -1.3, -2.2)
		for _, pk in ipairs(packets) do
			pk.u += dt * (1.1 + (pk.lane % 5) * 0.18)
			if pk.u > 1 then
				pk.u -= 1
			end
			local torso = ctx:limb(pk.target, "Torso")
			if torso then
				local to = torso.Position
					+ Vector3.new(((pk.lane * 37) % 7 - 3) * 0.22, ((pk.lane * 53) % 9 - 4) * 0.3, 0)
				pk.part.Size = Vector3.new(0.05, 0.05, 0.25 + (pk.lane % 3) * 0.22)
				pk.part.CFrame = CFrame.lookAt(from:Lerp(to, pk.u), to)
				pk.part.Transparency = if pk.u < 0.14 then 1 else 0.1
			end
		end
		local u = math.clamp((t - 10.0) / 2.9, 0, 1)
		for _, h in ipairs(outlines) do
			h.FillTransparency = 0.85 - 0.5 * u
		end
		if upLabel then
			upLabel.Text = string.format("QUICKHACK UPLOAD IN PROGRESS  %d%%", math.floor(u * 100))
		end
	end)
	ctx:at(12.95, function()
		for _, pk in ipairs(packets) do
			pk.part:Destroy()
		end
		table.clear(packets)
	end)
	ctx:at(10.0, function()
		for k = 1, 4 do
			local s = SceneDeaths.emit(ctx, Vector3.new(0.6 + k * 0.1, 4.6, -6 + k * 0.3), Vector3.new(1.5, 1.5, 0.5), {
				tex = "VfxDust",
				color = GREEN,
				size = { { 0, 0.12 }, { 1, 0.06 } },
				life = { 0.7, 1.0 },
				speed = { 6, 9 },
				dir = Enum.NormalId.Back,
				spread = 6,
				light = 1,
				bright = 2,
				rate = 90,
			})
			table.insert(streams, s)
		end
		local up = text(
			menu or hud,
			"QUICKHACK UPLOAD IN PROGRESS...",
			0.37,
			0.245,
			0.26,
			0.025,
			RED,
			Enum.TextXAlignment.Center
		)
		up.BackgroundColor3 = Color3.fromRGB(60, 6, 10)
		up.BackgroundTransparency = 0.3
		upLabel = up
		for _, m in ipairs(everyone) do
			local h = ctx:limb(m, "Head")
			if h then
				local icon = Instance.new("BillboardGui")
				icon.Adornee = h
				icon.Size = UDim2.fromScale(1.6, 1.0)
				icon.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
				icon.AlwaysOnTop = true
				icon.LightInfluence = 0
				icon.Parent = workspace.CurrentCamera
				local sq = ui(icon, "Frame", {
					BackgroundColor3 = Color3.fromRGB(70, 6, 12),
					Size = UDim2.fromScale(0.5, 0.7),
					Position = UDim2.fromScale(0.25, 0),
				})
				ui(sq, "UIStroke", { Color = RED, Thickness = 2 })
				-- (the gateway's glyph: a circuit break, three bars and a diagonal through them)
				for k = 0, 2 do
					ui(sq, "Frame", {
						BackgroundColor3 = RED,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.2, 0.25 + k * 0.2),
						Size = UDim2.fromScale(0.6, 0.08),
					})
				end
				ui(sq, "Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 200, 200),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.07),
					Rotation = -40,
				})
				local bar = ui(icon, "Frame", {
					BackgroundColor3 = Color3.fromRGB(40, 4, 8),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.1, 0.8),
					Size = UDim2.fromScale(0.8, 0.12),
				})
				local fill =
					ui(bar, "Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })
				ctx:tween(fill, 4.6, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
				table.insert(ctx.cleanups, function()
					icon:Destroy()
				end)
				ctx:atNow(16.3, function()
					icon:Destroy()
				end)
			end
		end
	end)
	ctx:during(10.0, 12.9, function()
		if math.random() < 0.25 and victim then
			local torso = ctx:limb(victim, "Torso")
			if torso then
				local at = torso.Position
					+ Vector3.new(math.random() * 3 - 1.5, math.random() * 4 - 1.5, math.random() * 2 - 1)
				local block = ctx:part({
					size = Vector3.new(0.6, 0.6, 0.1) * (0.5 + math.random()),
					at = ctx.origin:PointToObjectSpace(at),
					color = if math.random() < 0.5 then GREEN else Color3.fromRGB(230, 255, 240),
					glow = true,
					alpha = 0.3,
					cast = false,
				})
				task.delay(0.12, function()
					block:Destroy()
				end)
			end
		end
	end)
	ctx:at(12.5, function()
		for _, r in ipairs(rows) do
			r.frame.BackgroundColor3 = Color3.fromRGB(110, 14, 22)
			r.stroke.Color = RED
			r.name.TextColor3 = Color3.fromRGB(255, 220, 220)
		end
	end)
	-- scan off: the picture tears in red and cyan
	ctx:at(13.0, function()
		if menu then
			menu:Destroy()
			menu = nil
		end
		if scan then
			scan:Destroy()
			scan = nil
		end
		for _, h in ipairs(outlines) do
			h:Destroy()
		end
		for _, s in ipairs(streams) do
			s.Enabled = false
		end
	end)
	local tear = ctx:layer(2)
	ctx:during(13.0, 23.3, function(t)
		for _, child in ipairs(tear:GetChildren()) do
			child:Destroy()
		end
		local strength = if t < 14.75 then 1 else 0.6
		-- (a burst of tearing every so often, not a steady drizzle: bands of red and cyan, a few wide ones)
		if math.floor(t * 9) % 3 == 0 then
			for _ = 1, math.random(4, 9) do
				local red = math.random() < 0.55
				local wide = math.random() < 0.3
				ui(tear, "Frame", {
					BackgroundColor3 = if red then RED else CYAN,
					BackgroundTransparency = (if wide then 0.75 else 0.5) + math.random() * 0.3 * strength,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(math.random() * 0.5 - 0.25, math.random()),
					Size = UDim2.fromScale(
						0.5 + math.random() * 0.8,
						if wide then 0.03 + math.random() * 0.05 else 0.003 + math.random() * 0.01
					),
				})
			end
		end
	end)
	-- 14.75 the red glitch figures climb onto them and overtake them; glitch fire; the line. Two things on every body,
	-- both stepped: CORRUPTION, thin bars facing the eye that jump about the limbs (red, ember, white-hot, a few black:
	-- the picture missing, not burning); CLIMBERS, two red block figures that rise out of the floor beside the body,
	-- close in with their arms up, and from the pillar on sit ON the body, flickering.
	local corrupt = {}
	local climbers = {}
	ctx:at(14.6, function()
		for _, m in ipairs(everyone) do
			local bars = {}
			for k = 1, 16 do
				bars[k] = slab(if k % 5 == 0 then HOT elseif k % 3 == 0 then EMBER else RED)
			end
			for _ = 1, 3 do
				local b = slab(Color3.new(0, 0, 0))
				b.Material = Enum.Material.SmoothPlastic
				table.insert(bars, b)
			end
			table.insert(corrupt, { model = m, bars = bars })
			for side = -1, 1, 2 do
				local parts = {}
				for i, spec in ipairs(FIGURE) do
					parts[i] = ctx:part({
						size = spec.size,
						at = Vector3.new(0, -40, 0),
						color = if i == 2 then EMBER else RED,
						glow = true,
						alpha = 1,
						cast = false,
					})
				end
				table.insert(climbers, { model = m, parts = parts, side = side })
			end
		end
	end)
	local lastStep = -1
	ctx:during(14.75, 21.8, function(t)
		local step = math.floor(t * STEP)
		if step == lastStep then
			return
		end
		lastStep = step
		local cam = workspace.CurrentCamera.CFrame
		local look = cam.LookVector
		-- (how much of it there is: building to the pillar, full after it, thinning out at the end)
		local gone = if t < 16.25 then 0.55 elseif t < 20.4 then 0.22 else 0.22 + 0.78 * (t - 20.4) / 1.4
		for _, c in ipairs(corrupt) do
			for _, bar in ipairs(c.bars) do
				local limb = ctx:limb(c.model, LIMBS[math.random(#LIMBS)])
				if not limb or math.random() < gone then
					bar.Transparency = 1
				else
					local half = limb.Size / 2
					local off = Vector3.new(
						math.round((math.random() * 2 - 1) * half.X * 1.4 / 0.2) * 0.2,
						math.round((math.random() * 2 - 1) * half.Y * 1.1 / 0.2) * 0.2,
						0
					)
					local wide = math.random()
					bar.Size = Vector3.new(0.3 + wide * 1.5, 0.06 + wide * wide * 0.3, 0.05)
					bar.CFrame = CFrame.new(limb.CFrame:PointToWorldSpace(off) - look * 0.7) * cam.Rotation
					bar.Transparency = 0.05 + math.random() * 0.3
				end
			end
		end
		local u = math.clamp((t - 14.75) / 1.45, 0, 1)
		local near = 1 - u * u * (3 - 2 * u)
		for _, c in ipairs(climbers) do
			local torso = ctx:limb(c.model, "Torso")
			-- (on the body they come and go; climbing they hold, so the climb reads)
			local seen = torso ~= nil and (t < 16.25 or math.random() > math.max(0.45, gone))
			if torso and seen then
				local root = torso.CFrame * CFrame.new(c.side * 2.4 * near, -3.4 * near * near, 1.3 * near)
				local alpha = if t < 16.25 then 0.3 + 0.25 * near else 0.35 + math.random() * 0.3
				for i, part in ipairs(c.parts) do
					-- (a slice of it knocked sideways now and then)
					local dx = if math.random() < 0.3 then math.random(-2, 2) * 0.25 else 0
					part.CFrame = root * FIGURE[i].cf * CFrame.new(dx, 0, 0)
					part.Transparency = alpha
				end
			else
				for _, part in ipairs(c.parts) do
					part.Transparency = 1
				end
			end
		end
	end)
	ctx:at(21.8, function()
		for _, c in ipairs(corrupt) do
			for _, bar in ipairs(c.bars) do
				bar.Transparency = 1
			end
		end
		for _, c in ipairs(climbers) do
			for _, part in ipairs(c.parts) do
				part.Transparency = 1
			end
		end
	end)
	ctx:at(14.75, function()
		subtitle.Text = "UNKNOWN: Target neural network acquired. Data migration to primary matrix - complete."
		subtitle.TextColor3 = Color3.fromRGB(255, 120, 120)
		for _, m in ipairs(everyone) do
			for _, limb in ipairs({ "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
				local p = ctx:limb(m, limb)
				if p then
					Vfx.Emit.make(p, {
						tex = "VfxChunk",
						grid = 2,
						fps = 0,
						startRandom = true,
						color = { { 0, Color3.fromRGB(255, 220, 140) }, { 0.4, EMBER }, { 1, RED } },
						size = { { 0, 0.3 }, { 1, 0.1 } },
						life = { 0.2, 0.5 },
						speed = { 1, 4 },
						spread = 60,
						accel = Vector3.new(0, 6, 0),
						light = 1,
						bright = 2,
						rate = 34,
					})
				end
			end
			local torso = ctx:limb(m, "Torso")
			if torso then
				local fire = Instance.new("PointLight")
				fire.Color = EMBER
				fire.Range = 12
				fire.Brightness = 3
				fire.Parent = torso
				Vfx.Light.flicker(fire, 3, 12, 0.4)
				Vfx.Emit.make(torso, {
					tex = "VfxDust",
					color = { { 0, HOT }, { 0.5, EMBER }, { 1, RED } },
					size = { { 0, 0.09 }, { 1, 0.02 } },
					life = { 0.8, 1.6 },
					speed = { 1, 3 },
					spread = 50,
					accel = Vector3.new(0, 7, 0),
					light = 1,
					bright = 2.5,
					rate = 26,
				})
				Vfx.Emit.make(torso, {
					tex = "VfxSmoke",
					grid = 8,
					mode = "OneShot",
					color = Color3.fromRGB(60, 50, 50),
					size = { { 0, 1 }, { 1, 3 } },
					alpha = { { 0, 0.5 }, { 1, 1 } },
					life = { 1.2, 1.8 },
					speed = { 1, 2 },
					spread = 20,
					accel = Vector3.new(0, 2, 0),
					rate = 6,
				})
			end
			local h = Instance.new("Highlight")
			h.FillColor = EMBER
			h.FillTransparency = 0.45
			h.OutlineColor = RED
			h.OutlineTransparency = 0.2
			h.Parent = m
		end
		subtitle.Visible = true
	end)
	ctx:at(18.0, function()
		subtitle.Text = ""
	end)
	-- (polish, 2026-11-12) the breath before the pillar: the picture holds, drained white-red
	ctx:at(16.17, function()
		Cinema.still(Color3.fromRGB(255, 210, 206), 0.08)
	end)
	-- 16.25 the white-red pillar of light out of the victim; sparks in a sphere
	ctx:at(16.25, function()
		local torso = victim and ctx:limb(victim, "Torso")
		local at = if torso then ctx.origin:PointToObjectSpace(torso.Position) else Vector3.new(0, 3.5, 0)
		-- the column out of the floor under them, a white core through it, two rings across the floor, and it SPREADS:
		-- a red arc from the victim to each of the others
		local floor = CFrame.new(ctx:world(Vector3.new(at.X, 0.1, at.Z)))
		Vfx.Recipes.pillar(floor, { color = RED, height = 46, radius = 1.8, seconds = 1.7 })
		local core = ctx:part({
			size = Vector3.new(60, 0.9, 0.9),
			at = at + Vector3.new(0, 30, 0),
			rot = Vector3.new(0, 0, 90),
			color = Color3.new(1, 1, 1),
			glow = true,
			shape = "Cylinder",
			cast = false,
		})
		ctx:tween(core, 0.9, { Transparency = 1, Size = Vector3.new(60, 0.1, 0.1) })
		Vfx.Beams.wave(floor, 1, 17, 0.95, { color = RED, width = 2.6, bright = 3 })
		Vfx.Beams.wave(floor, 0.5, 9, 0.6, { color = HOT, width = 1.2, bright = 3 })
		if torso then
			for _, b in ipairs(by) do
				local other = ctx:limb(b, "Torso")
				if other then
					Vfx.Beams.bolt(
						torso.Position,
						other.Position,
						0.6,
						{ color = RED, width = 0.55, jag = 1.3, pieces = 9, bright = 3 }
					)
				end
			end
		end
		Vfx.Screen.shake(1.4, 0.8)
		local world = ctx:world(at)
		Vfx.Emit.burst(world, {
			tex = "VfxStreak",
			color = { { 0, Color3.fromRGB(255, 230, 180) }, { 1, EMBER } },
			size = { { 0, 0.18 }, { 1, 0.04 } },
			squash = -2.4,
			life = { 0.5, 1.0 },
			speed = { 18, 34 },
			drag = 2,
			accel = Vector3.new(0, -20, 0),
			spread = 180,
			face = "along",
			light = 1,
			bright = 2,
		}, 140)
		Vfx.Light.flash(world, Color3.fromRGB(255, 120, 110), 60, 8, 0.8)
		Cinema.flash(Color3.fromRGB(255, 200, 196), 0.75, 0.6)
		-- (polish, 2026-11-12) what it leaves: the floor scorched black under them with a dull red rim that cools, the
		-- arcs to the others striking twice more, embers raining back down through the smoke
		local scorch = ctx:part({
			size = Vector3.new(0.06, 7, 7),
			at = Vector3.new(at.X, 0.04, at.Z),
			rot = Vector3.new(0, 0, 90),
			color = Color3.fromRGB(12, 10, 10),
			shape = "Cylinder",
			cast = false,
		})
		scorch.Transparency = 0.15
		local rim = ctx:part({
			size = Vector3.new(0.05, 7.6, 7.6),
			at = Vector3.new(at.X, 0.03, at.Z),
			rot = Vector3.new(0, 0, 90),
			color = RED,
			glow = true,
			shape = "Cylinder",
			cast = false,
		})
		ctx:tween(rim, 4.5, { Transparency = 1, Color = Color3.fromRGB(90, 20, 14) })
		for k = 1, 2 do
			Vfx.Clock.after(0.28 * k, function()
				if not torso then
					return
				end
				for _, b in ipairs(by) do
					local other = ctx:limb(b, "Torso")
					if other then
						Vfx.Beams.bolt(
							torso.Position,
							other.Position,
							0.25,
							{ color = if k == 1 then HOT else RED, width = 0.3, jag = 1.6, pieces = 11, bright = 3 }
						)
					end
				end
			end)
		end
		Vfx.Clock.after(0.9, function()
			Vfx.Emit.burst(ctx:world(Vector3.new(at.X, 13, at.Z)), {
				tex = "VfxEmber",
				color = { { 0, HOT }, { 0.5, EMBER }, { 1, RED } },
				size = { { 0, 0.1 }, { 1, 0.02 } },
				alpha = { { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } },
				life = { 2.2, 3.6 },
				speed = { 0.5, 2 },
				spread = 180,
				accel = Vector3.new(0, -5, 0),
				drag = 0.6,
				light = 1,
				bright = 2.6,
			}, 90, Vector3.new(9, 5, 9))
		end)
	end)
	ctx:grade(13.0, nil, { Saturation = 0.15, Contrast = 0.12, TintColor = Color3.fromRGB(255, 236, 230) }, 0.3)
end

return { length = 23.3, build = build }
