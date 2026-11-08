-- Blackwall gateway (art/refs/deaths/blackwall.md, 23.3 s): FIRST PERSON from the hacker's eye (never seen) in an
-- underground car park: the victim stands before us arms crossed, two bystanders behind at the left, a blue car on a
-- lift at the right. Scan mode (dark teal-green, red wire outlines); the quickhack menu (RAM bar, the list stepping
-- down to BLACKWALL GATEWAY, the panel); the upload (green data streams, the red quickhack icon with its bar over the
-- victim's head); out of scan with the picture tearing in red and cyan; red glitch FIGURES climbing onto the victim
-- and overtaking them, red-orange glitch fire; the white-red pillar of light; burning, staggering, down. Our own HUD
-- drawing (the layout copied).

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local DeathScreen = require(script.Parent.Parent.DeathScreen)
local Vfx = require(script.Parent.Parent.Vfx)

local CYAN = Color3.fromRGB(94, 246, 255)
local RED = Color3.fromRGB(255, 52, 64)
local EMBER = Color3.fromRGB(255, 110, 40)
local GREEN = Color3.fromRGB(80, 255, 140)

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
		local b = ctx:actor("figure", CFrame.lookAt(at, Vector3.new(0, 0, -9)), "sceneBlackwallBystander")
		if b then
			ctx:dress(b, {
				head = Color3.fromRGB(150, 110, 84),
				torso = if i == 1 then Color3.fromRGB(110, 70, 40) else Color3.fromRGB(60, 70, 50),
				arms = if i == 1 then Color3.fromRGB(110, 70, 40) else Color3.fromRGB(60, 70, 50),
				legs = Color3.fromRGB(40, 50, 70),
			})
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

	-- the HUD
	local hud = ctx:layer(3)
	local hp = ui(
		hud,
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.2, 0.03) }
	)
	ui(hp, "Frame", {
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.85, 0.5),
		Position = UDim2.fromScale(0.1, 0.25),
	})
	text(hp, "79", 0, 0, 0.09, 1, CYAN)
	local map = ui(hud, "Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 20),
		BackgroundTransparency = 0.2,
		Position = UDim2.fromScale(0.86, 0.14),
		Size = UDim2.fromScale(0.11, 0.14),
	})
	ui(map, "UIStroke", { Color = CYAN, Thickness = 1 })
	for k = 1, 5 do
		ui(map, "Frame", {
			BackgroundColor3 = if k == 3 then RED else CYAN,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.1 + k * 0.12, 0.2 + (k % 3) * 0.2),
			Size = UDim2.fromScale(0.3, 0.02),
			Rotation = k * 30,
		})
	end
	for k = 0, 4 do
		local slot = ui(hud, "Frame", {
			BackgroundColor3 = Color3.fromRGB(10, 30, 36),
			BackgroundTransparency = 0.3,
			Position = UDim2.fromScale(0.03 + k * 0.035, 0.8),
			Size = UDim2.fromScale(0.03, 0.045),
		})
		ui(slot, "UIStroke", { Color = CYAN, Thickness = 1 })
	end
	local subtitle = text(hud, "", 0.2, 0.84, 0.6, 0.03, Color3.fromRGB(240, 240, 240), Enum.TextXAlignment.Center)

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
		text(m, "AVAILABLE QUICKHACKS:", 0.09, 0.3, 0.2, 0.025, CYAN)
		for i, spec in ipairs(listNames) do
			local row = ui(m, "Frame", {
				BackgroundColor3 = Color3.fromRGB(8, 34, 40),
				BackgroundTransparency = 0.25,
				Position = UDim2.fromScale(0.1, 0.34 + (i - 1) * 0.055),
				Size = UDim2.fromScale(0.22, 0.045),
			})
			local stroke = ui(row, "UIStroke", { Color = CYAN, Thickness = 1 })
			local name = text(row, spec[1], 0.05, 0.1, 0.7, 0.8, CYAN)
			text(row, tostring(spec[2]), 0.82, 0.1, 0.15, 0.8, CYAN)
			rows[i] = { frame = row, stroke = stroke, name = name }
		end
		local panel = ui(m, "Frame", {
			BackgroundColor3 = Color3.fromRGB(14, 14, 24),
			BackgroundTransparency = 0.15,
			Position = UDim2.fromScale(0.68, 0.3),
			Size = UDim2.fromScale(0.2, 0.36),
		})
		ui(panel, "UIStroke", { Color = CYAN, Thickness = 1 })
		local desc = text(panel, "", 0.06, 0.04, 0.88, 0.9, Color3.fromRGB(230, 230, 236))
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextScaled = false
		desc.TextSize = 13
		desc.TextWrapped = true
		desc.Name = "Desc"
		menu = m
	end)
	local descs = {
		"PING\nReveals enemies and devices connected to the local network.",
		"SONIC SHOCK\nDeafens the target. Cuts off their communication with allies.",
		"OVERHEAT\nSets the target on fire, dealing damage over time.",
		"SHORT CIRCUIT\nDeals electrical damage to the target's cyberware.",
		"BLACKWALL GATEWAY\nUltimate quickhack. Spreads to enemies nearby, causing lethal damage to cyberware and neural systems. Whatever lies beyond the Blackwall comes through.",
	}
	local function selectRow(i: number)
		for k, r in ipairs(rows) do
			local on = k == i
			r.frame.BackgroundColor3 = if on then Color3.fromRGB(20, 90, 100) else Color3.fromRGB(8, 34, 40)
			r.stroke.Thickness = if on then 2 else 1
		end
		local desc = menu and menu:FindFirstChild("Desc", true)
		if desc then
			desc.Text = descs[i]
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
			text(tag, "◆ " .. string.upper(ctx.victimName), 0, 0, 1, 1, CYAN, Enum.TextXAlignment.Center)
			table.insert(ctx.cleanups, function()
				tag:Destroy()
			end)
		end
	end)
	-- the upload: green data streaming at them, glitch blocks, the red icon with its bar over every head
	local streams = {}
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
				text(sq, "⚠", 0.1, 0.05, 0.8, 0.9, RED, Enum.TextXAlignment.Center)
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
		for _ = 1, math.random(3, 7) do
			local red = math.random() < 0.55
			ui(tear, "Frame", {
				BackgroundColor3 = if red then RED else CYAN,
				BackgroundTransparency = 0.55 + math.random() * 0.35 * strength,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(math.random() * 0.4 - 0.2, math.random()),
				Size = UDim2.fromScale(0.4 + math.random() * 0.9, 0.003 + math.random() * 0.012),
			})
		end
	end)
	-- 14.75 the red glitch figures climb onto them and overtake them; glitch fire; the line
	local function glitchFigure(m: Model)
		local torso = ctx:limb(m, "Torso")
		if not torso then
			return
		end
		DeathScreen.ghost(m, if math.random() < 0.7 then RED else EMBER, 0.35, 0.25)
		local folder = workspace.CurrentCamera:FindFirstChild("DeathGhost")
		if folder then
			local shift = Vector3.new(math.random() * 1.6 - 0.8, math.random() * 0.8 - 0.2, math.random() * 1.6 - 0.8)
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") then
					p.CFrame = p.CFrame + shift + Vector3.new(math.random() * 0.4 - 0.2, 0, math.random() * 0.4 - 0.2)
				end
			end
			folder.Name = "DeathGhostDone"
		end
	end
	ctx:during(14.75, 21.8, function(t)
		local rate = if t < 16.3 then 0.35 else 0.18
		for _, m in ipairs(everyone) do
			if math.random() < rate then
				glitchFigure(m)
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
	-- 16.25 the white-red pillar of light out of the victim; sparks in a sphere
	ctx:at(16.25, function()
		local torso = victim and ctx:limb(victim, "Torso")
		local at = if torso then ctx.origin:PointToObjectSpace(torso.Position) else Vector3.new(0, 3.5, 0)
		local core = ctx:part({
			size = Vector3.new(60, 1.2, 1.2),
			at = at + Vector3.new(0, 30, 0),
			rot = Vector3.new(0, 0, 90),
			color = Color3.new(1, 1, 1),
			glow = true,
			shape = "Cylinder",
			cast = false,
		})
		local glow = ctx:part({
			size = Vector3.new(60, 3.6, 3.6),
			at = at + Vector3.new(0, 30, 0),
			rot = Vector3.new(0, 0, 90),
			color = RED,
			glow = true,
			alpha = 0.45,
			shape = "Cylinder",
			cast = false,
		})
		ctx:tween(core, 1.4, { Transparency = 1 })
		ctx:tween(glow, 1.6, { Transparency = 1 })
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
	end)
	ctx:grade(13.0, nil, { Saturation = 0.15, Contrast = 0.12, TintColor = Color3.fromRGB(255, 236, 230) }, 0.3)
end

return { length = 23.3, build = build }
