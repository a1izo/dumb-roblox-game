-- heh, didja really think- (art/refs/deaths/sans.md, 30 s): a flat battle screen, black everywhere, the victim small
-- and upright in the upper middle in black and white; under him the battle box with the red soul, the HP line and the
-- FIGHT / ACT / ITEM / MERCY buttons. Asleep (Z's) while the soul pushes the box over to FIGHT; FIGHT; he sidesteps the
-- first slash; the speech bubble types "heh, didja really think you would be" and the second slash cuts it off; the
-- red damage number; hunched down holding the wound. Our own pixel lettering and drawing (the layout copied).

local SceneDeaths = require(script.Parent)
local DeathScreen = require(script.Parent.Parent.DeathScreen)

local RED = Color3.fromRGB(255, 0, 0)
local ORANGE = Color3.fromRGB(255, 127, 39)
local YELLOW = Color3.fromRGB(255, 255, 0)
local WHITE = Color3.new(1, 1, 1)

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number, color: Color3)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.AnchorPoint = Vector2.new(0, 0.5)
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, thick: number)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	f.Parent = parent
	return f, s
end

local function build(ctx)
	SceneDeaths.box(ctx, Vector3.new(220, 80, 220), Vector3.new(0, -30, 0), Color3.new(0, 0, 0))
	ctx:light(Vector3.new(0, 6, -10), WHITE, 30, 3)
	ctx:light(Vector3.new(0, 10, 4), WHITE, 20, 1)
	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1)), "sceneSansVictim")
	if victim then
		ctx:face(victim, "sleep")
		ctx:at(24.0, function()
			ctx:face(victim, "smug")
		end)
		ctx:at(25.85, function()
			ctx:face(victim, "pain")
		end)
	end
	-- the flat camera: far off, a narrow lens, the victim small in the upper middle
	ctx:shot(0, Vector3.new(0, 4.6, -70), Vector3.new(0, 1.4, 0), 11.5)
	ctx:grade(0, nil, { Saturation = -1, Contrast = 0.6, Brightness = 0.05 }, 0.05)

	-- the UI
	local ui = ctx:layer(3)
	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.AnchorPoint = Vector2.new(0.5, 0.5)
	area.Position = UDim2.fromScale(0.5, 0.5)
	area.Size = UDim2.fromScale(1, 1)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 4 / 3
	ratio.Parent = area
	area.Parent = ui
	local battle, _ = box(area, 0.5, 0.62, 0.2, 0.26, WHITE, 3)
	local soul = label(battle, "♥", 0.08, 0.78, 0.16, 0.16, RED)
	soul.Font = Enum.Font.GothamBlack
	soul.TextXAlignment = Enum.TextXAlignment.Center
	label(area, "DEATH   LV 19   HP", 0.14, 0.785, 0.32, 0.035, WHITE)
	local hpBack = Instance.new("Frame")
	hpBack.BorderSizePixel = 0
	hpBack.BackgroundColor3 = RED
	hpBack.Position = UDim2.fromScale(0.47, 0.77)
	hpBack.Size = UDim2.fromScale(0.12, 0.03)
	hpBack.Parent = area
	local hpFill = hpBack:Clone()
	hpFill.BackgroundColor3 = YELLOW
	hpFill.Position = UDim2.fromScale(0, 0)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hpBack
	label(area, "KR  92 / 92", 0.61, 0.785, 0.2, 0.035, WHITE)
	local buttons = {}
	for i, spec in ipairs({ { "FIGHT", "/" }, { "ACT", "*" }, { "ITEM", "&" }, { "MERCY", "x" } }) do
		local x = 0.14 + (i - 1) * 0.2
		local frame, stroke = box(area, x + 0.07, 0.88, 0.145, 0.07, ORANGE, 3)
		local icon = label(frame, spec[2], 0.06, 0.5, 0.22, 0.8, ORANGE)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(frame, spec[1], 0.3, 0.5, 0.66, 0.7, ORANGE)
		buttons[i] = { frame = frame, stroke = stroke, icon = icon, name = name }
	end
	-- the soul pushes the box left, slowly, to FIGHT (0-19 s), and sits on FIGHT
	ctx:during(0, 30, function(t)
		local u = math.clamp(t / 19, 0, 1)
		battle.Position = UDim2.fromScale(0.5 - 0.29 * u, 0.62 + 0.18 * math.clamp((t - 17) / 2, 0, 1))
		soul.Position = UDim2.fromScale(0.08 + 0.02 * math.sin(t * 3), 0.78 + 0.02 * math.cos(t * 2.3))
	end)
	ctx:at(19.0, function()
		local b = buttons[1]
		b.stroke.Color = YELLOW
		b.name.TextColor3 = YELLOW
		b.icon.Text = "♥"
		b.icon.TextColor3 = RED
		b.icon.Font = Enum.Font.GothamBlack
		soul.Visible = false
	end)
	ctx:at(23.75, function()
		local b = buttons[1]
		b.frame.BackgroundTransparency = 0.6
		b.frame.BackgroundColor3 = YELLOW
		task.delay(0.12, function()
			b.frame.BackgroundTransparency = 1
		end)
	end)
	-- Z's off the sleeping head
	ctx:at(0.2, function()
		local h = victim and ctx:limb(victim, "Head")
		if h then
			DeathScreen.zzz(h, 23.5)
		end
	end)

	local function headScreen(): Vector2
		local h = victim and ctx:limb(victim, "Head")
		local p = if h then ctx:screen(h.Position) else Vector2.new(0.5, 0.25)
		return p
	end
	local function torsoScreen(): Vector2
		local h = victim and ctx:limb(victim, "Torso")
		local p = if h then ctx:screen(h.Position) else Vector2.new(0.5, 0.33)
		return p
	end
	local function slash(at: Vector2, angle: number, len: number, life: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = RED
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(at.X, at.Y)
		f.Size = UDim2.new(0, 6, len, 0)
		f.Rotation = angle
		f.Parent = ui
		ctx:tween(f, life * 0.4, { Size = UDim2.new(0, 14, len, 0) })
		task.delay(life, function()
			f:Destroy()
		end)
		return f
	end
	-- 24.0 the first slash cuts the air where he stood (he sidestepped)
	ctx:at(23.98, function()
		slash(torsoScreen(), 0, 0.14, 0.3)
	end)
	-- 24.25 the speech bubble types "heh, didja really think you would be"
	local bubble: Frame? = nil
	local said: TextLabel? = nil
	ctx:at(24.25, function()
		local b = Instance.new("Frame")
		b.BackgroundColor3 = WHITE
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, 0.5)
		b.Size = UDim2.fromScale(0.2, 0.11)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.18, 0)
		corner.Parent = b
		local tail = Instance.new("Frame")
		tail.BackgroundColor3 = WHITE
		tail.BorderSizePixel = 0
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.fromScale(0, 0.5)
		tail.Size = UDim2.fromOffset(16, 16)
		tail.Rotation = 45
		tail.Parent = b
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.07, 0.1)
		text.Size = UDim2.fromScale(0.88, 0.8)
		text.Font = Enum.Font.Arcade
		text.TextScaled = true
		text.TextWrapped = true
		text.TextColor3 = Color3.new(0, 0, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Text = "heh, didja really think you would be"
		text.MaxVisibleGraphemes = 0
		text.Parent = b
		b.Parent = ui
		bubble, said = b, text
	end)
	ctx:during(24.25, 25.8, function(t)
		if bubble and said then
			local p = headScreen()
			bubble.Position = UDim2.fromScale(p.X + 0.06, p.Y)
			said.MaxVisibleGraphemes = math.floor((t - 24.3) / 1.4 * 36)
		end
	end)
	-- 25.8 the second slash: a red cut across his chest, the bubble emptied, a star over his head; the wound stays
	local wound: Frame? = nil
	ctx:at(25.8, function()
		if said then
			said.Text = ""
		end
		local at = torsoScreen()
		slash(at, -48, 0.2, 0.35)
		local star = label(ui, "*", at.X - 0.01, at.Y - 0.12, 0.03, 0.04, WHITE)
		task.delay(0.5, function()
			star:Destroy()
		end)
		local w = Instance.new("Frame")
		w.BorderSizePixel = 0
		w.BackgroundColor3 = RED
		w.AnchorPoint = Vector2.new(0.5, 0.5)
		w.Size = UDim2.new(0, 5, 0.06, 0)
		w.Rotation = -48
		w.Parent = ui
		wound = w
	end)
	ctx:at(26.1, function()
		if bubble then
			bubble:Destroy()
			bubble = nil
		end
	end)
	ctx:during(25.8, 30, function()
		if wound then
			local p = torsoScreen()
			wound.Position = UDim2.fromScale(p.X, p.Y)
		end
	end)
	-- 27.5 the damage: a row of red digits over him
	local damage: Frame? = nil
	ctx:at(27.5, function()
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Size = UDim2.fromScale(0.26, 0.05)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0.01, 0)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = row
		for _ = 1, 7 do
			local d = Instance.new("TextLabel")
			d.BackgroundTransparency = 1
			d.Size = UDim2.fromScale(0.13, 1)
			d.Font = Enum.Font.Arcade
			d.TextScaled = true
			d.TextColor3 = RED
			d.Text = "9"
			local s = Instance.new("UIStroke")
			s.Color = RED
			s.Thickness = 1
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = d
			d.Parent = row
		end
		row.Parent = ui
		damage = row
	end)
	ctx:during(27.5, 30, function()
		if damage then
			local p = headScreen()
			damage.Position = UDim2.fromScale(p.X, p.Y - 0.1)
		end
	end)
end

return { length = 30, build = build }
