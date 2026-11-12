-- heh, didja really think- (art/refs/deaths/sans.md, 30 s): a flat battle screen, black everywhere, the victim small
-- and upright in the upper middle in black and white; under him the battle box with the red soul, the HP line and the
-- FIGHT / ACT / ITEM / MERCY buttons. Asleep (Z's) while the soul pushes the box over to FIGHT; FIGHT; he sidesteps the
-- first slash; the speech bubble types "heh, didja really think you would be" and the second slash cuts it off; the
-- red damage number; hunched down holding the wound. Our own pixel lettering and drawing (the layout copied).

local SceneDeaths = require(script.Parent)
local DeathScreen = require(script.Parent.Parent.DeathScreen)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

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

-- Undertale's soul: a 7 x 6 bitmap
local HEART = { ".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..." }
-- the damage font's 9: a chunky two-pixel stroke, 6 x 9
local NINE = { ".XXXX.", "XX..XX", "XX..XX", "XX..XX", ".XXXXX", "....XX", "....XX", "XX..XX", ".XXXX." }

-- A bitmap of square pixels filling `holder` (each "X" one cell), optionally under a one-cell dark outline so it reads
-- over the picture; returns the cells.
local function pixels(holder: Frame, rows: { string }, color: Color3, outline: Color3?)
	local h, w = #rows, #rows[1]
	local cells = {}
	local function cell(col: number, row: number, c: Color3, z: number, grow: number)
		local px = Instance.new("Frame")
		px.BorderSizePixel = 0
		px.BackgroundColor3 = c
		px.Position = UDim2.fromScale((col - 1 - grow) / w, (row - 1 - grow) / h)
		px.Size = UDim2.fromScale((1 + 2 * grow) / w + 0.004, (1 + 2 * grow) / h + 0.004)
		px.ZIndex = z
		px.Parent = holder
		table.insert(cells, px)
	end
	for row, bits in ipairs(rows) do
		for col = 1, w do
			if string.sub(bits, col, col) == "X" then
				if outline then
					cell(col, row, outline, 1, 0.45)
				end
				cell(col, row, color, 2, 0)
			end
		end
	end
	return cells
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
	-- the soul: Undertale's pixel heart (2026-11-10, the user: "pixelated"), a 7 x 6 bitmap of red squares
	local soul = Instance.new("Frame")
	soul.BackgroundTransparency = 1
	soul.AnchorPoint = Vector2.new(0.5, 0.5)
	soul.Size = UDim2.fromScale(0.14, 0.12)
	soul.Position = UDim2.fromScale(0.5, 0.5)
	soul.Parent = battle
	pixels(soul, HEART, RED)
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
	-- the soul walks to the box's left edge first (0-3.5 s); only once it is pressing the edge does the box move with
	-- it, slowly left to FIGHT (3.5-17 s); then it presses the bottom edge and the box drops onto the button (17-19 s)
	-- (2026-11-10, the user: the box moves only when the heart pushes its edges)
	ctx:during(0, 30, function(t)
		local walk = math.clamp(t / 3.5, 0, 1)
		walk = walk * walk * (3 - 2 * walk)
		local soulX = 0.5 - 0.41 * walk + 0.006 * math.sin(t * 7) * (1 - walk)
		local push = math.clamp((t - 3.5) / 13.5, 0, 1)
		local down = math.clamp((t - 16.5) / 0.6, 0, 1)
		local soulY = 0.5 + 0.38 * down
		local drop = math.clamp((t - 17) / 2, 0, 1)
		battle.Position = UDim2.fromScale(0.5 - 0.29 * push, 0.62 + 0.18 * drop)
		soul.Position = UDim2.fromScale(soulX, soulY)
	end)
	ctx:at(19.0, function()
		local b = buttons[1]
		b.stroke.Color = YELLOW
		b.name.TextColor3 = YELLOW
		-- (2026-11-12, the user: the heart stopped being pixelated on FIGHT; it is the same bitmap now)
		b.icon.Text = ""
		local heart = Instance.new("Frame")
		heart.BackgroundTransparency = 1
		heart.AnchorPoint = Vector2.new(0.5, 0.5)
		heart.Position = UDim2.fromScale(0.5, 0.5)
		heart.Size = UDim2.fromScale(0.62, 0.62)
		heart.SizeConstraint = Enum.SizeConstraint.RelativeYY
		heart.Parent = b.icon
		pixels(heart, HEART, RED)
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
	-- the slash (2026-11-12, the user: "make the slashing VFX more dramatic"): Undertale's crescent, built of square
	-- pixels, swept on corner to corner in 0.1 s, white-hot as it goes and red behind, a white flash and a hard shake
	-- as it lands, then it thins from its edges and blinks out
	local function slash(at: Vector2, angle: number, len: number, life: number)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(at.X, at.Y)
		holder.Size = UDim2.fromScale(len, len)
		holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
		holder.Rotation = angle
		holder.Parent = ui
		local G = 30
		local cells = {}
		for i = 0, G - 1 do
			for j = 0, G - 1 do
				local u, v = (i + 0.5) / G, (j + 0.5) / G
				-- along the chord from the top right to the bottom left, and how far off it toward the bulge
				local sAlong = ((u - 0.88) * -0.76 + (v - 0.06) * 0.88) / (0.76 * 0.76 + 0.88 * 0.88)
				local px, py = 0.88 - 0.76 * sAlong, 0.06 + 0.88 * sAlong
				local off = ((u - px) * 0.88 + (v - py) * 0.76) / math.sqrt(0.76 * 0.76 + 0.88 * 0.88)
				if sAlong > 0 and sAlong < 1 then
					local bulge = math.sin(math.pi * sAlong)
					local outer, inner = 0.3 * bulge, 0.3 * bulge - 0.13 * bulge ^ 0.7 - 0.012
					if off <= outer and off >= inner then
						local c = Instance.new("Frame")
						c.BorderSizePixel = 0
						c.BackgroundColor3 = WHITE
						c.Position = UDim2.fromScale(i / G, j / G)
						c.Size = UDim2.fromScale(1 / G + 0.003, 1 / G + 0.003)
						c.Visible = false
						c.Parent = holder
						table.insert(
							cells,
							{ frame = c, s = sAlong, depth = (outer - off) / math.max(outer - inner, 1e-3) }
						)
					end
				end
			end
		end
		local start = ctx:now()
		local landed = false
		ctx:during(start, start + life + 0.4, function(t)
			local k = t - start
			for _, c in ipairs(cells) do
				local shown = k >= c.s * 0.1
				-- thinning: the crescent's edges go first, its middle last
				local gone = k > life * (0.55 + 0.45 * (1 - math.abs(c.depth - 0.5) * 2))
				c.frame.Visible = shown and not gone and (k < life * 0.85 or math.floor(k * 30) % 2 == 0)
				local age = k - c.s * 0.1
				c.frame.BackgroundColor3 = if age < 0.05 then WHITE else RED
			end
			if not landed and k >= 0.1 then
				landed = true
				Cinema.flash(WHITE, 0.45, 0.12)
				Vfx.Screen.shake(1.6, 0.35)
			end
		end)
		task.delay(life + 0.45, function()
			holder:Destroy()
		end)
		return holder
	end
	-- 24.0 the first slash cuts the air where he stood (he sidestepped)
	ctx:at(23.98, function()
		slash(torsoScreen(), 0, 0.3, 0.5)
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
		slash(at, 8, 0.42, 0.6)
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
	-- 27.5 the damage (2026-11-12, the user: "the 9999999 number more accurate to Undertale"): 9999999, seven nines
	-- in the battle's chunky pixel digits, red under a dark rim, hopping up off him and dropping back as the game's do
	local damage: Frame? = nil
	ctx:at(27.5, function()
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 1)
		row.Size = UDim2.fromScale(0.3, 0.075)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0.018, 0)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = row
		for _ = 1, 7 do
			local d = Instance.new("Frame")
			d.BackgroundTransparency = 1
			d.Size = UDim2.fromScale(0.125, 1)
			d.Parent = row
			pixels(d, NINE, RED, Color3.fromRGB(20, 0, 0))
		end
		row.Parent = ui
		damage = row
	end)
	ctx:during(27.5, 30, function(t)
		if damage then
			local p = headScreen()
			local u = math.clamp((t - 27.5) / 0.45, 0, 1)
			local hop = math.sin(math.pi * u) * 0.05
			damage.Position = UDim2.fromScale(p.X, p.Y - 0.06 - hop)
		end
	end)
end

return { length = 30, build = build }
