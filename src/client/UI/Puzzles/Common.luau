-- Building blocks for the puzzle views, drawn the concept A way (paper, ink, blood): cards with an ink frame that
-- boils, targets the red hand points at, steppers made of OMORI buttons, red rings and crosses for a pick that is
-- right or wrong, and fingerprints drawn from their features (Shared/Tasks/PuzzleKit.print).
--
-- Everything is written for the dark like every screen (C.bone is the ink, C.g0 the sheet); the task window's
-- paper sheet turns it to ink on paper (Kit/Paper). Red is only for a pick: right (a ring) or wrong (a cross).

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent.Kit)
local Motion = require(script.Parent.Parent.Core.Motion)

local C = Kit.color
local T = Kit.Tokens

local Common = {}

-- The colours a puzzle draws with (dark names; on the sheet they read as noted).
Common.INK = C.bone -- ink
Common.GREY = C.dim -- dark pencil
Common.SOFT = C.faint -- pencil
Common.FAINT = C.g4 -- light pencil
Common.SHEET = C.g0 -- the sheet itself
Common.CARD = C.g1 -- a card a shade off the sheet
Common.SHADE = C.g3 -- a shaded area
Common.RED = C.danger

export type Context = {
	area: Frame,
	puzzle: any,
	def: any,
	-- Checks the answer here first; returns true when it is right (the task is then solved).
	submit: (any) -> boolean,
	hint: (string) -> (),
	first: (GuiObject) -> (), -- what a gamepad selects first
	-- A wrong pick: a red cross on `gui`, a short line, and a beat where nothing can be picked (so guessing costs).
	miss: (GuiObject?, string?) -> (),
	-- True while a miss is being shown or once the puzzle is solved.
	busy: () -> boolean,
	practice: boolean,
}

-- Text ------------------------------------------------------------------------------------------

-- A line in the hand. Props: size (a Tokens.size key or px), color, align, plus label properties.
function Common.text(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	local label = Kit.label({
		Text = text,
		font = p.font or "body",
		size = p.size or "body",
		color = p.color or Common.INK,
		TextXAlignment = p.align or Enum.TextXAlignment.Left,
		TextYAlignment = p.valign or Enum.TextYAlignment.Center,
		TextWrapped = if p.wrap == nil then true else p.wrap,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		Size = p.Size or UDim2.new(1, 0, 0, 24),
		LayoutOrder = p.LayoutOrder,
		ZIndex = p.ZIndex,
		Parent = parent,
	})
	return label
end

-- Data in Roboto Mono (times, numbers, letters to compare).
function Common.mono(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	p.font = "mono"
	return Common.text(parent, text, p)
end

-- A small caption in capitals.
function Common.caption(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	p.font = "label"
	p.size = p.size or "micro"
	p.color = p.color or Common.GREY
	p.Size = p.Size or UDim2.new(1, 0, 0, 18)
	p.wrap = false
	return Common.text(parent, string.upper(text), p)
end

-- Surfaces ----------------------------------------------------------------------------------------

-- The drawn ink frame inside a card (it boils; the card itself stays put so what is in it reads).
local function border(parent: GuiObject, thickness: number?, color: Color3?): Frame
	local frame = Kit.Base.make("Frame", {
		Name = "Border",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = parent,
	})
	Kit.Base.stroke(frame, color or Common.INK, thickness or 2, 0)
	Kit.Boil.attach(frame, 1)
	return frame
end
Common.border = border

-- A card: a fill a shade off the sheet and a boiling ink frame. Props: fill, line (frame px), plus frame properties.
function Common.card(props: { [string]: any }): Frame
	local p = table.clone(props)
	local fill, line = p.fill, p.line
	p.fill, p.line = nil, nil
	local card = Kit.Base.make("Frame", {
		Name = "Card",
		BackgroundColor3 = fill or Common.CARD,
		BorderSizePixel = 0,
	}, p)
	if line ~= 0 then
		border(card, line)
	end
	return card
end

-- Something to pick: a card the red hand points at when hovered or selected, its frame thicker while it is.
-- `onClick` runs only while the puzzle is not busy (a miss being shown, or solved). Props: fill, line, plus frame
-- properties.
function Common.target(ctx: Context, props: { [string]: any }, onClick: (() -> ())?): TextButton
	local p = table.clone(props)
	local fill, line = p.fill, p.line or 2
	p.fill, p.line = nil, nil
	local button = Kit.Base.hit(p)
	button.BackgroundColor3 = fill or Common.CARD
	button.BackgroundTransparency = if fill == false then 1 else 0
	button.Selectable = true
	Kit.Controls.focusable(button)
	local frame = border(button, line)
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	local function chosen(on: boolean)
		stroke.Thickness = if on and button.Active then line + 1 else line
		if on and button.Active then
			Kit.Pointer.point(button)
		else
			Kit.Pointer.release(button)
		end
	end
	button.MouseEnter:Connect(function()
		chosen(true)
	end)
	button.MouseLeave:Connect(function()
		chosen(false)
	end)
	button.SelectionGained:Connect(function()
		chosen(true)
	end)
	button.SelectionLost:Connect(function()
		chosen(false)
	end)
	button.Destroying:Once(function()
		Kit.Pointer.release(button)
	end)
	if onClick then
		button.Activated:Connect(function()
			if button.Active and not ctx.busy() then
				onClick()
			end
		end)
	end
	return button
end

-- Moves a gamepad's selection to `gui` (when what it was on has been rebuilt).
function Common.select(gui: GuiObject)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = gui
	end
end

-- Lets a target be picked, or greys it out (faded under a sheet-coloured veil, skipped by the gamepad).
function Common.setEnabled(button: GuiObject, enabled: boolean)
	if button:IsA("GuiButton") then
		button.Active = enabled
		button.Selectable = enabled
	end
	local veil = button:FindFirstChild("Veil") :: Frame?
	if not veil then
		veil = Kit.Base.make("Frame", {
			Name = "Veil",
			BackgroundColor3 = Common.SHEET,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Parent = button,
		})
	end
	(veil :: Frame).Visible = not enabled
	if not enabled then
		Kit.Pointer.release(button)
	end
end

-- A grid of cards: `count` cells of `cols` columns filling `parent`, with `gap` px between. Returns the frame.
function Common.grid(parent: Instance, cols: number, rows: number, gap: number?, props: { [string]: any }?): Frame
	local g = gap or T.space.m
	local holder = Kit.frame(props or {})
	holder.Parent = parent
	Kit.grid(holder, UDim2.new(1 / cols, -g * (cols - 1) / cols, 1 / rows, -g * (rows - 1) / rows), g)
	return holder
end

-- Marks ------------------------------------------------------------------------------------------

-- A red ring drawn round `gui` (a right pick, or what the report points at). Returns it.
function Common.ring(gui: GuiObject, color: Color3?, scale: number?): Frame
	local s = scale or 1.18
	local ring = Kit.Base.make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(s, s),
		ZIndex = 30,
		Parent = gui,
	})
	Kit.Base.make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
	Kit.Base.stroke(ring, color or Common.RED, 3, 0)
	Kit.Boil.attach(ring, 1)
	return ring
end

-- A red cross over `gui` (a wrong pick). Returns it.
function Common.cross(gui: GuiObject): Frame
	local holder = Kit.Base.make("Frame", {
		Name = "Cross",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 31,
		Parent = gui,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = holder })
	for _, angle in ipairs({ 45, -45 }) do
		Kit.Base.make("Frame", {
			BackgroundColor3 = Common.RED,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1.2, 0, 0, 4),
			Rotation = angle,
			ZIndex = 31,
			Parent = holder,
		})
	end
	Kit.Boil.attach(holder, 1)
	return holder
end

-- A short sideways shake (a wrong pick).
function Common.shake(gui: GuiObject)
	if Motion.isReduced() then
		return
	end
	local position = gui.Position
	gui.Position = position + UDim2.fromOffset(6, 0)
	Motion.tween(gui, { Position = position }, 0.3, Enum.EasingStyle.Elastic)
end

-- A small red number in a card's corner (the order something was picked in).
function Common.badge(gui: GuiObject, text: string): TextLabel
	return Common.mono(gui, text, {
		size = "lead",
		color = Common.RED,
		align = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 32,
	})
end

-- Controls ----------------------------------------------------------------------------------------

-- A stepper: its name, a "-" button, the value in mono, a "+" button. Returns the row and set(value) (which does
-- not call onChanged).
function Common.stepper(
	ctx: Context,
	parent: Instance,
	label: string,
	value: number,
	min: number,
	max: number,
	onChanged: (number) -> (),
	props: { [string]: any }?
): (Frame, (number) -> ())
	local p = props or {}
	local row = Kit.frame({
		Name = "Stepper_" .. label,
		Size = p.Size or UDim2.new(1, 0, 0, T.touch),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.LayoutOrder,
		Parent = parent,
	})
	Common.caption(row, label, {
		size = "small",
		color = Common.INK,
		Size = UDim2.new(1, -(T.touch * 2 + 64), 1, 0),
	})
	local current = value
	local shown = Common.mono(row, "", {
		size = "lead",
		align = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -T.touch, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
	})
	local function set(v: number, notify: boolean?)
		current = math.clamp(v, min, max)
		shown.Text = tostring(current)
		if notify then
			onChanged(current)
		end
	end
	local minus = Kit.button({
		Name = "Minus",
		text = "-",
		variant = "secondary",
		size = "s",
		Size = UDim2.fromOffset(T.touch, T.touch),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(T.touch + 56), 0, 0),
		Parent = row,
	}, function()
		if not ctx.busy() then
			set(current - 1, true)
		end
	end)
	Kit.button({
		Name = "Plus",
		text = "+",
		variant = "secondary",
		size = "s",
		Size = UDim2.fromOffset(T.touch, T.touch),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = row,
	}, function()
		if not ctx.busy() then
			set(current + 1, true)
		end
	end)
	if p.first then
		ctx.first(minus)
	end
	set(value, false)
	return row, function(v: number)
		set(v, false)
	end
end

-- Drawing ---------------------------------------------------------------------------------------

-- A thin pencil rule.
function Common.rule(parent: Instance, position: UDim2, size: UDim2, color: Color3?): Frame
	return Kit.Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = color or Common.FAINT,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 2,
		Parent = parent,
	})
end

-- A round dot at a fraction of a board. `size` is px, or a fraction of the board's width when below 1.
function Common.dot(parent: Instance, x: number, y: number, size: number, color: Color3, z: number?): Frame
	local dot = Kit.Base.make("Frame", {
		Name = "Dot",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = if size < 1 then UDim2.fromScale(size, size) else UDim2.fromOffset(size, size),
		ZIndex = z or 4,
		Parent = parent,
	})
	if size < 1 then
		Kit.Base.make("UIAspectRatioConstraint", { Parent = dot })
	end
	Kit.Base.round(dot)
	return dot
end

-- A hollow ring at a fraction of a board (px size).
function Common.hoop(parent: Instance, x: number, y: number, size: number, color: Color3, z: number?): Frame
	local hoop = Kit.Base.make("Frame", {
		Name = "Hoop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 4,
		Parent = parent,
	})
	Kit.Base.round(hoop)
	Kit.Base.stroke(hoop, color, 2, 0)
	return hoop
end

-- A thin line from (x1, y1) to (x2, y2) in pixels inside `parent`.
function Common.line(
	parent: Instance,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	width: number,
	color: Color3,
	z: number?
): Frame
	local dx, dy = x2 - x1, y2 - y1
	return Kit.Base.make("Frame", {
		Name = "Line",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + width * 0.5, width),
		Rotation = math.deg(math.atan2(dy, dx)),
		ZIndex = z or 4,
		Parent = parent,
	})
end

-- A line between two points given as fractions of `parent` (redrawn when it changes size).
function Common.scaleLine(
	parent: GuiObject,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	width: number,
	color: Color3,
	z: number?
): Frame
	local line = Common.line(parent, 0, 0, 1, 0, width, color, z)
	local function place()
		local size = parent.AbsoluteSize / Kit.Base.scaleOf(parent)
		local ax, ay, bx, by = x1 * size.X, y1 * size.Y, x2 * size.X, y2 * size.Y
		local dx, dy = bx - ax, by - ay
		line.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
		line.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + width * 0.5, width)
		line.Rotation = math.deg(math.atan2(dy, dx))
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	return line
end

-- An outline shape (a circle or a pill) at a centre and size in fractions of its parent.
local function shape(
	parent: Instance,
	cx: number,
	cy: number,
	w: number,
	h: number,
	color: Color3,
	px: number,
	z: number
)
	local f = Kit.Base.make("Frame", {
		Name = "Ridge",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(w, h),
		ZIndex = z,
		Parent = parent,
	})
	Kit.Base.make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	Kit.Base.stroke(f, color, px, 0)
	return f
end

local SCARS = { -40, -15, 15, 40 }
-- (a print's pad is this wide for its height)
Common.PRINT_ASPECT = 0.78

-- A fingerprint drawn from its features (PuzzleKit.print): ridges round its core (closed rings for a whorl, hairpins
-- for a loop, arcs for an arch), a scar cut across them and three islands. Props: fill (what the scar shows, the
-- colour under the print), mirror (as lifted from glass), color, plus frame properties. Returns the pad.
function Common.print(parent: Instance, spec: any, props: { [string]: any }?): Frame
	local p = table.clone(props or {})
	local fill, mirror, color = p.fill or Common.CARD, p.mirror, p.color or Common.INK
	p.fill, p.mirror, p.color = nil, nil, nil
	local pad = Kit.Base.make("Frame", {
		Name = "Print",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
	}, p)
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = Common.PRINT_ASPECT, Parent = pad })
	pad.Parent = parent
	local A = Common.PRINT_ASPECT
	local function fx(x: number): number
		return if mirror then 1 - x else x
	end
	local cx, cy = fx(0.5 + (spec.core - 2) * 0.1), 0.46
	local z = 2
	-- the pad's edge
	shape(pad, 0.5, 0.5, 0.98, 0.99, Common.FAINT, 1, z)
	local step = 0.072 -- between ridges, in pad heights
	for i = 1, spec.rings do
		local r = 0.05 + (i - 1) * step -- radius in pad heights
		if spec.kind == 1 then
			-- whorl: closed rings a little taller than wide
			shape(pad, cx, cy, (2 * r) / A * 0.92, 2 * r * 1.05, color, 2, z)
		elseif spec.kind == 2 then
			-- loop: hairpins opening downwards (a tall pill whose bottom is past the pad's edge)
			local h = 1.4
			shape(pad, cx, cy - r + h / 2, (2 * r) / A, h, color, 2, z)
		else
			-- arch: arcs of big circles centred far below
			local top = cy - 0.06 + (i - 1) * step * 0.9
			local R = 1.35 - (i - 1) * step * 0.25
			shape(pad, fx(0.5 + (spec.core - 2) * 0.06), top + R, (2 * R) / A, 2 * R, color, 2, z)
		end
	end
	-- (a few ridges past the pattern, so the pad is full)
	for i = 1, 2 do
		local r = 0.05 + (spec.rings + i - 1) * step + 0.02
		if spec.kind ~= 3 then
			shape(pad, cx, cy + 0.08, (2 * r) / A * 1.1, 2 * r * 1.1, Common.SOFT, 1, z)
		end
	end
	if spec.scar > 0 then
		Kit.Base.make("Frame", {
			Name = "Scar",
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(0.95, 0.04),
			Rotation = if mirror then -SCARS[spec.scar] else SCARS[spec.scar],
			ZIndex = z + 1,
			Parent = pad,
		})
	end
	for _, d in ipairs(spec.dots) do
		Common.dot(pad, fx(0.18 + d[1] * 0.16), 0.16 + d[2] * 0.15, 0.065, color, z + 2)
	end
	return pad
end

-- Film grain over a picture (a still, a feed), so it reads as a print-out of the tape.
function Common.grain(parent: GuiObject, transparency: number?)
	local id = Kit.Textures.id("UiGrain")
	if id == "" then
		return
	end
	Kit.Base.make("ImageLabel", {
		Name = "Grain",
		BackgroundTransparency = 1,
		Image = id,
		ImageColor3 = Common.INK,
		ImageTransparency = transparency or 0.8,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 25,
		Parent = parent,
	})
end

-- A small drawn person (a head, a body, legs; a hat, a coat and what they carry are features). `look` is
-- { hat (1 no, 2 yes), coat (1 light, 2 dark), carry (1 nothing, 2 bag, 3 umbrella), facing (1 or -1) }.
function Common.person(parent: Instance, look: { number }, color: Color3?): Frame
	local ink = color or Common.INK
	local holder = Kit.Base.make("Frame", {
		Name = "Person",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.62, 0.82),
		Parent = parent,
	})
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = 0.55, Parent = holder })
	local facing = look[4] or 1
	local function x(v: number): number
		return if facing < 0 then 1 - v else v
	end
	local function box(cx, cy, w, h, filled, round, z)
		local f = Kit.Base.make("Frame", {
			BackgroundColor3 = ink,
			BackgroundTransparency = if filled then 0 else 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x(cx), cy),
			Size = UDim2.fromScale(w, h),
			ZIndex = z or 3,
			Parent = holder,
		})
		if round then
			Kit.Base.make("UICorner", { CornerRadius = UDim.new(round, 0), Parent = f })
		end
		if not filled then
			Kit.Base.stroke(f, ink, 2, 0)
		end
		return f
	end
	-- head
	box(0.5, 0.12, 0.34, 0.17, false, 0.5)
	if look[1] == 2 then
		box(0.5, 0.04, 0.38, 0.06, true, nil, 4) -- crown
		box(0.5, 0.07, 0.62, 0.025, true, nil, 4) -- brim
	end
	-- coat (dark is filled in)
	box(0.5, 0.42, 0.56, 0.42, look[2] == 2, 0.12)
	-- legs
	box(0.4, 0.78, 0.12, 0.3, true)
	box(0.6, 0.78, 0.12, 0.3, true)
	if look[3] == 2 then
		-- a bag at the hip
		box(0.86, 0.6, 0.24, 0.16, false, 0.15, 4)
		box(0.8, 0.5, 0.03, 0.08, true, nil, 4)
	elseif look[3] == 3 then
		-- a closed umbrella held down, its hook up
		box(0.9, 0.62, 0.035, 0.5, true, nil, 4)
		box(0.9, 0.82, 0.12, 0.16, true, 0.5, 4)
		box(0.86, 0.36, 0.1, 0.05, false, 0.5, 4)
	end
	return holder
end

return Common
