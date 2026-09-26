--!strict
-- Things you press, pick, drag and type into. Every control is at least Tokens.touch tall,
-- shows a red ink focus mark for gamepads, and can be disabled with Controls.setEnabled.
--
--   Controls.button({ text = "Play", variant = "primary", icon = "play", Parent = x }, onClick)
--   Controls.hold({ text = "Write the name" }, 1.2, onConfirm)
--   Controls.tabs({ items = {{ id = "hats", label = "Hats" }}, selected = "hats" }, onSelect)
--   Controls.nameLine({ text = "Raven", Parent = list }, onClick)
--   Controls.field({ placeholder = "Full name", maxLength = 32, Parent = x })
--   Controls.slider({ Parent = list }, "Music", 0.8, 0, 1, 0.1, onChanged)
--   Controls.toggle({ Parent = list }, "Reduce motion", false, onChanged)
--   Controls.meter({ Parent = x })

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent.Parent.Core.Motion)
local Base = require(script.Parent.Base)
local GlyphText = require(script.Parent.GlyphText)
local Icon = require(script.Parent.Icon)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Controls = {}

type Props = { [string]: any }

local C = Tokens.color

-- The red mark a gamepad's current selection gets.
local focusMark: Frame = Base.make("Frame", {
	Name = "InkFocus",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
})
do
	local stroke = Base.stroke(focusMark, C.red, 2, 0)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Base.make("Frame", {
		Name = "Underline",
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 3),
		Parent = focusMark,
	})
end

function Controls.focusable(button: GuiObject)
	button.SelectionImageObject = focusMark
end

local HEIGHT = { s = 40, m = Tokens.touch, l = 60 }
local TEXT = { s = Tokens.size.small, m = Tokens.size.body, l = Tokens.size.lead }

type Look = {
	bg: Color3?,
	bgHover: Color3?,
	bgPress: Color3?,
	text: Color3,
	textHover: Color3,
	torn: boolean,
	line: boolean,
}

local LOOKS: { [string]: Look } = {
	primary = {
		bg = C.red,
		bgHover = C.red:Lerp(Color3.new(1, 1, 1), 0.12),
		bgPress = C.blood,
		text = C.bone,
		textHover = Color3.new(1, 1, 1),
		torn = true,
		line = false,
	},
	danger = {
		bg = C.blood,
		bgHover = C.red,
		bgPress = C.blood:Lerp(Color3.new(0, 0, 0), 0.3),
		text = C.bone,
		textHover = Color3.new(1, 1, 1),
		torn = true,
		line = false,
	},
	secondary = {
		bg = C.raised,
		bgHover = C.lifted,
		bgPress = C.page,
		text = C.bone,
		textHover = Color3.new(1, 1, 1),
		torn = false,
		line = false,
	},
	ghost = { text = C.dim, textHover = C.bone, torn = false, line = true },
	parchment = {
		bg = C.parchment,
		bgHover = C.parchment:Lerp(Color3.new(1, 1, 1), 0.2),
		bgPress = C.parchmentDark,
		text = C.ink,
		textHover = C.ink,
		torn = true,
		line = false,
	},
}

type ButtonState = { look: Look, enabled: boolean, paint: (string) -> () }
local states: { [GuiObject]: ButtonState } = setmetatable({}, { __mode = "k" }) :: any

-- A button. Props: text, variant ("primary", "danger", "secondary", "ghost", "parchment"),
-- icon (an icon name), key (a key hint such as "E"), size ("s", "m", "l"), width (px), upper
-- (default true), plus frame properties (Size overrides width/size).
function Controls.button(props: Props, onClick: (() -> ())?): TextButton
	local look = LOOKS[props.variant or "secondary"] or LOOKS.secondary
	local sizeKey = props.size or "m"
	local height = HEIGHT[sizeKey] or HEIGHT.m
	local autoWidth = props.Size == nil and props.width == nil
	local button = Base.hit({
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(props.width or 0, height),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	Controls.focusable(button)
	local z = button.ZIndex
	local bg = Base.frame({ Name = "Bg", ZIndex = z, Parent = button })
	local row = Base.frame({
		Name = "Row",
		ZIndex = z + 1,
		Size = if autoWidth then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1),
		AutomaticSize = if autoWidth then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		Parent = button,
	})
	Base.list(row, Tokens.space.s, true, Enum.HorizontalAlignment.Center)
	Base.pad(row, 0, if look.line then Tokens.space.s else Tokens.space.l)
	local icon: ImageLabel? = nil
	if props.icon then
		icon = Icon.new({
			name = props.icon,
			size = TEXT[sizeKey] * 1.35,
			color = look.text,
			LayoutOrder = 1,
			ZIndex = z + 1,
			Parent = row,
		})
	end
	local text = props.text or ""
	local label = Base.label({
		Name = "Label",
		Text = if props.upper == false then text else string.upper(text),
		font = "label",
		size = TEXT[sizeKey],
		color = look.text,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = z + 1,
		Visible = text ~= "",
		Parent = row,
	})
	if props.key and props.key ~= "" then
		Controls.keycap({ text = props.key, LayoutOrder = 3, ZIndex = z + 1, Parent = row })
	end
	if autoWidth then
		-- As wide as the icon, text and key; the fill follows the button (see Base.fit).
		Base.fit(button, row, "X")
	end
	local underline: Frame? = nil
	if look.line then
		underline = Base.make("Frame", {
			Name = "Underline",
			BackgroundColor3 = C.red,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(0, 0, 0, 2),
			ZIndex = z + 1,
			Parent = button,
		})
	end
	local fill: GuiObject? = nil
	local function drawBg()
		Base.clear(bg)
		fill = nil
		if not look.bg then
			return
		end
		local id = if look.torn then Textures.id("UiTorn") else ""
		if id ~= "" then
			fill = Base.make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = look.bg,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(32, 32, 224, 224),
				SliceScale = 0.35,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = bg,
			})
		else
			local frame = Base.make("Frame", {
				BackgroundColor3 = look.bg,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = bg,
			})
			if not look.torn then
				Base.stroke(frame, C.rule, 1, 0.85)
			end
			fill = frame
		end
	end
	drawBg()
	if not Textures.isReady() then
		local connection
		connection = Textures.Ready:Connect(function()
			if button.Parent then
				drawBg()
			end
			connection:Disconnect()
		end)
	end
	local function paint(state: string)
		local enabled = states[button] == nil or states[button].enabled
		local hovered = state == "hover" and enabled
		local pressed = state == "press" and enabled
		local color = if pressed then look.bgPress elseif hovered then look.bgHover else look.bg
		local current = fill
		if current and color then
			if current:IsA("ImageLabel") then
				Motion.tween(current, { ImageColor3 = color }, Tokens.motion.quick)
			else
				Motion.tween(current, { BackgroundColor3 = color }, Tokens.motion.quick)
			end
		end
		local textColor = if hovered or pressed then look.textHover else look.text
		label.TextColor3 = textColor
		if icon then
			icon.ImageColor3 = textColor
		end
		if underline then
			Motion.tween(underline, { Size = UDim2.new(if hovered then 0.8 else 0, 0, 0, 2) }, Tokens.motion.base)
		end
	end
	states[button] = { look = look, enabled = true, paint = paint }
	local scale = Base.make("UIScale", { Name = "PressScale", Parent = button })
	button.MouseEnter:Connect(function()
		paint("hover")
	end)
	button.MouseLeave:Connect(function()
		paint("rest")
		Motion.tween(scale, { Scale = 1 }, Tokens.motion.quick)
	end)
	button.SelectionGained:Connect(function()
		paint("hover")
	end)
	button.SelectionLost:Connect(function()
		paint("rest")
	end)
	button.MouseButton1Down:Connect(function()
		if states[button].enabled then
			paint("press")
			Motion.tween(scale, { Scale = 0.96 }, 0.05)
		end
	end)
	button.MouseButton1Up:Connect(function()
		paint("hover")
		Motion.tween(scale, { Scale = 1 }, Tokens.motion.quick)
	end)
	if onClick then
		button.Activated:Connect(function()
			if states[button].enabled then
				onClick()
			end
		end)
	end
	return button
end

-- Greys a control out and stops it reacting, or brings it back.
function Controls.setEnabled(button: GuiObject, enabled: boolean)
	local state = states[button]
	button.Active = enabled
	if button:IsA("GuiButton") then
		button.Selectable = enabled
	end
	if state then
		state.enabled = enabled
		state.paint("rest")
	end
	for _, item in ipairs(button:GetDescendants()) do
		if item:IsA("TextLabel") then
			item.TextTransparency = if enabled then 0 else Tokens.alpha.disabled
		elseif item:IsA("ImageLabel") then
			item.ImageTransparency = if enabled then 0 else Tokens.alpha.disabled
		end
	end
end

-- Changes a button's text.
function Controls.setText(button: GuiObject, text: string, upper: boolean?)
	local label = button:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = if upper == false then text else string.upper(text)
		label.Visible = text ~= ""
	end
end

-- A button that fires only after being held for `seconds`: ink fills it from the left.
-- Guards things that cannot be undone. Works with mouse, touch, Enter and gamepad A.
function Controls.hold(props: Props, seconds: number, onConfirm: () -> ()): TextButton
	local p = table.clone(props)
	p.variant = p.variant or "primary"
	local button = Controls.button(p)
	local fill = Base.make("Frame", {
		Name = "HoldInk",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = button.ZIndex + 2,
		Parent = button,
	})
	local holding = false
	local function reset()
		holding = false
		Motion.tween(fill, { Size = UDim2.fromScale(0, 1) }, Tokens.motion.quick)
	end
	local function begin()
		if holding or not button.Active then
			return
		end
		holding = true
		local started = os.clock()
		while holding and button.Parent do
			local progress = (os.clock() - started) / seconds
			fill.Size = UDim2.fromScale(math.min(progress, 1), 1)
			if progress >= 1 then
				holding = false
				fill.Size = UDim2.fromScale(0, 1)
				onConfirm()
				return
			end
			RunService.RenderStepped:Wait()
		end
		reset()
	end
	button.MouseButton1Down:Connect(function()
		task.spawn(begin)
	end)
	button.MouseButton1Up:Connect(reset)
	button.MouseLeave:Connect(reset)
	button.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
			task.spawn(begin)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Return then
			reset()
		end
	end)
	return button
end

-- A square icon-only button (close, back, menu). Props: icon, size (px, default 44), color.
function Controls.iconButton(props: Props, onClick: (() -> ())?): TextButton
	local size = props.size or 44
	local button = Base.hit({
		Name = props.Name or "IconButton",
		Size = UDim2.fromOffset(math.max(size, Tokens.touch), math.max(size, Tokens.touch)),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Controls.focusable(button)
	local color = props.color or C.dim
	local icon = Icon.new({
		name = props.icon,
		size = size * 0.55,
		color = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = button.ZIndex + 1,
		Parent = button,
	})
	local function lit(on: boolean)
		Motion.tween(icon, { ImageColor3 = if on then C.bone else color }, Tokens.motion.quick)
	end
	button.MouseEnter:Connect(function()
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A square chip for the match HUD's action bar: an inked icon with its key in the corner. The
-- name shows on a tag above it on hover and gamepad selection; on touch screens the chip is
-- bigger and the name is written under the icon. Props: icon, label, key, variant ("primary"
-- for what to do now), touch, plus frame properties.
function Controls.actionChip(props: Props, onClick: (() -> ())?): TextButton
	local touch = props.touch == true
	local size = if touch then 72 else 56
	local primary = props.variant == "primary"
	local rest = if primary then C.red else C.raised
	local hover = if primary then C.red:Lerp(Color3.new(1, 1, 1), 0.12) else C.lifted
	local press = if primary then C.blood else C.page
	local button = Base.hit({
		Name = props.Name or "ActionChip",
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Controls.focusable(button)
	local z = button.ZIndex
	local fill = Base.make("Frame", {
		Name = "Fill",
		BackgroundColor3 = rest,
		BackgroundTransparency = if primary then 0 else Tokens.alpha.glass,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = button,
	})
	Base.corner(fill, Tokens.radius.key)
	Base.stroke(fill, if primary then C.blood else C.rule, 1, if primary then 0 else 0.8)
	Icon.new({
		name = props.icon or "help",
		size = 28,
		color = C.bone,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if touch then UDim2.new(0.5, 0, 0, 22) else UDim2.fromScale(0.5, 0.5),
		ZIndex = z + 1,
		Parent = button,
	})
	local name = props.label or ""
	local key = props.key or ""
	-- Long gamepad names ("D-Right") go on the tag instead of crowding the icon.
	local shortKey = key ~= "" and #key <= 2
	if shortKey then
		Controls.keycap({
			text = key,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			ZIndex = z + 2,
			Parent = button,
		})
	end
	if touch then
		Base.label({
			Name = "Label",
			Text = name,
			font = "label",
			size = "micro",
			color = C.bone,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, -6, 0, 30),
			ZIndex = z + 1,
			Parent = button,
		})
	end
	-- The name tag sits above the chip, right-aligned so the last chip's tag stays on screen.
	local tag = Base.make("Frame", {
		Name = "Tag",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -Tokens.space.s),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = z + 5,
		Parent = button,
	})
	Base.corner(tag, Tokens.radius.key)
	Base.pad(tag, 0, Tokens.space.s)
	Base.label({
		Text = if key ~= "" and not shortKey then name .. "  ·  " .. key else name,
		font = "label",
		size = "small",
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = z + 6,
		Parent = tag,
	})
	local function lit(on: boolean, pressed: boolean?)
		tag.Visible = on and not touch
		local color = if pressed then press elseif on then hover else rest
		Motion.tween(fill, { BackgroundColor3 = color }, Tokens.motion.quick)
	end
	button.MouseEnter:Connect(function()
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	button.MouseButton1Down:Connect(function()
		lit(true, true)
	end)
	button.MouseButton1Up:Connect(function()
		lit(true)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A key hint ("E", "Q", "LB"...). Hidden on touch screens.
function Controls.keycap(props: Props): Frame
	local text = props.text or ""
	local frame = Base.make("Frame", {
		Name = "Keycap",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 1,
		Visible = text ~= "" and not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled),
		Parent = props.Parent,
	})
	Base.corner(frame, Tokens.radius.key)
	Base.stroke(frame, C.bone, 1, 0.55)
	Base.pad(frame, 0, 6)
	Base.label({
		Name = "Key",
		Text = text,
		font = "mono",
		size = "micro",
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})
	return frame
end

-- Bookmark tabs. Props: items ({ { id, label, icon? } }), selected (id), vertical, plus frame
-- properties. Returns the frame and select(id) (which also calls onSelect).
function Controls.tabs(props: Props, onSelect: (string) -> ()): (Frame, (string) -> ())
	local frame = Base.frame({
		Name = props.Name or "Tabs",
		Size = props.Size or UDim2.new(1, 0, 0, Tokens.touch),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Base.list(frame, Tokens.space.xs, not props.vertical)
	local buttons: { [string]: { button: TextButton, ribbon: Frame, label: TextLabel } } = {}
	local current: string? = nil
	local function paint()
		for id, parts in pairs(buttons) do
			local on = id == current
			Motion.tween(parts.ribbon, { BackgroundTransparency = if on then 0 else 1 }, Tokens.motion.base)
			parts.label.TextColor3 = if on then C.bone else C.dim
		end
	end
	local function choose(id: string)
		current = id
		paint()
		onSelect(id)
	end
	for index, item in ipairs(props.items or {}) do
		local button = Base.hit({
			Name = "Tab_" .. item.id,
			Size = if props.vertical then UDim2.new(1, 0, 0, Tokens.touch) else UDim2.new(0, 0, 1, 0),
			LayoutOrder = index,
			ZIndex = frame.ZIndex,
			Parent = frame,
		})
		Controls.focusable(button)
		local ribbon = Base.make("Frame", {
			Name = "Ribbon",
			BackgroundColor3 = C.blood,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = button.ZIndex,
			Parent = button,
		})
		-- A bookmark's notched end.
		Base.make("Frame", {
			Name = "Notch",
			BackgroundColor3 = C.page,
			BorderSizePixel = 0,
			Rotation = 45,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if props.vertical then UDim2.new(1, 0, 0.5, 0) else UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(14, 14),
			ZIndex = button.ZIndex + 1,
			Parent = ribbon,
		})
		local row = Base.frame({
			ZIndex = button.ZIndex + 2,
			Size = if props.vertical then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1),
			AutomaticSize = if props.vertical then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Parent = button,
		})
		Base.list(
			row,
			Tokens.space.s,
			true,
			if props.vertical then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center
		)
		Base.pad(row, 0, Tokens.space.l)
		if item.icon then
			Icon.new({
				name = item.icon,
				size = 20,
				color = C.bone,
				LayoutOrder = 1,
				ZIndex = button.ZIndex + 2,
				Parent = row,
			})
		end
		local label = Base.label({
			Text = string.upper(item.label),
			font = "label",
			size = "small",
			color = C.dim,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
			ZIndex = button.ZIndex + 2,
			Parent = row,
		})
		if not props.vertical then
			Base.fit(button, row, "X")
		end
		buttons[item.id] = { button = button, ribbon = ribbon, label = label }
		button.MouseEnter:Connect(function()
			if current ~= item.id then
				label.TextColor3 = C.bone
			end
		end)
		button.MouseLeave:Connect(paint)
		button.Activated:Connect(function()
			choose(item.id)
		end)
	end
	current = props.selected
	paint()
	return frame, choose
end

export type NameLine = {
	button: TextButton,
	name: any,
	setMarked: (boolean) -> (),
	setSelected: (boolean) -> (),
	setRight: (string) -> (),
	setEnabled: (boolean) -> (),
}

-- A name written on a ruled line (the vote, the roster, results). Props: text, sub (small
-- print after the name), right (text at the right, in red handwriting), seed, plus frame
-- properties. setMarked draws a red line through the name; setSelected marks it as chosen.
function Controls.nameLine(props: Props, onClick: (() -> ())?): NameLine
	local height = props.height or 56
	local button = Base.hit({
		Name = props.Name or "NameLine",
		Size = props.Size or UDim2.new(1, 0, 0, height),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Controls.focusable(button)
	local z = button.ZIndex
	local rule = Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = z,
		Parent = button,
	})
	local hover = Base.make("Frame", {
		Name = "Hover",
		BackgroundColor3 = C.lifted,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = button,
	})
	local check = Icon.new({
		name = "check",
		size = 26,
		color = C.red,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Visible = false,
		ZIndex = z + 2,
		Parent = button,
	})
	local name = GlyphText.new({
		face = "Scrawl",
		text = props.text or "",
		size = height * 0.62,
		seed = props.seed,
		color = C.bone,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 2),
		ZIndex = z + 1,
		Parent = button,
	})
	local sub = Base.label({
		Name = "Sub",
		Text = props.sub or "",
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Position = UDim2.new(0, 52 + name.width, 0, 0),
		ZIndex = z + 1,
		Visible = (props.sub or "") ~= "",
		Parent = button,
	})
	local right = GlyphText.new({
		face = "Scrawl",
		text = props.right or "",
		size = height * 0.55,
		color = C.red,
		align = "right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 2),
		ZIndex = z + 1,
		Parent = button,
	})
	local strike = Base.make("Frame", {
		Name = "Strike",
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 34, 0.5, 2),
		Rotation = -2,
		Size = UDim2.fromOffset(0, 3),
		ZIndex = z + 3,
		Parent = button,
	})
	local enabled = true
	local line: NameLine
	line = {
		button = button,
		name = name,
		setMarked = function(on: boolean)
			Motion.tween(strike, { Size = UDim2.fromOffset(if on then name.width + 14 else 0, 3) }, Tokens.motion.slow)
		end,
		setSelected = function(on: boolean)
			check.Visible = on
			name:setColor(if on then C.red else C.bone)
		end,
		setRight = function(text: string)
			right:set(text)
		end,
		setEnabled = function(on: boolean)
			enabled = on
			button.Active = on
			button.Selectable = on
			name:setTransparency(if on then 0 else Tokens.alpha.disabled)
		end,
	}
	local function lit(on: boolean)
		Motion.tween(hover, { BackgroundTransparency = if on and enabled then 0.6 else 1 }, Tokens.motion.quick)
		rule.BackgroundTransparency = if on and enabled then 0.5 else 0.8
	end
	button.MouseEnter:Connect(function()
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	if onClick then
		button.Activated:Connect(function()
			if enabled then
				onClick()
			end
		end)
	end
	name.Changed:Connect(function()
		sub.Position = UDim2.new(0, 52 + name.width, 0, 0)
	end)
	return line
end

-- An entry in a table of contents (the lobby menu, How to Play chapters): a small numeral and
-- a handwritten title that turns red and gets underlined on hover. Props: text, numeral,
-- icon, size (lettering px, default 30), selected (stays red and underlined: the open
-- chapter), plus frame properties.
function Controls.entry(props: Props, onClick: (() -> ())?): TextButton
	local size = props.size or 30
	local selected = props.selected == true
	local button = Base.hit({
		Name = props.Name or "Entry",
		Size = props.Size or UDim2.new(1, 0, 0, math.max(Tokens.touch - 6, size * 1.3)),
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		ZIndex = props.ZIndex or 1,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	Controls.focusable(button)
	local z = button.ZIndex
	local x = 0
	if props.numeral then
		Base.label({
			Name = "Numeral",
			Text = props.numeral,
			font = "label",
			size = "small",
			color = C.faint,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, 34, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = z,
			Parent = button,
		})
		x = 44
	elseif props.icon then
		Icon.new({
			name = props.icon,
			size = size * 0.7,
			color = C.dim,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			ZIndex = z,
			Parent = button,
		})
		x = size * 0.7 + 12
	end
	local title = GlyphText.new({
		face = "Scrawl",
		text = props.text or "",
		size = size,
		seed = props.seed,
		color = C.bone,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, x, 0.5, 2),
		ZIndex = z,
		Parent = button,
	})
	local underline = Base.make("Frame", {
		Name = "Underline",
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		Position = UDim2.new(0, x, 1, -6),
		Size = UDim2.fromOffset(0, 2),
		ZIndex = z,
		Parent = button,
	})
	local function lit(on: boolean)
		local shown = on or selected
		title:setColor(if shown then C.red else C.bone)
		Motion.tween(underline, { Size = UDim2.fromOffset(if shown then title.width else 0, 2) }, Tokens.motion.base)
	end
	if selected then
		lit(true)
		title.Changed:Connect(function()
			lit(true)
		end)
	end
	button.MouseEnter:Connect(function()
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A text field written on a line. Props: placeholder, text, maxLength, font ("body" or
-- "document"), size, multiline, plus frame properties. Returns the frame and the TextBox.
function Controls.field(props: Props): (Frame, TextBox)
	local multiline = props.multiline == true
	local frame = Base.frame({
		Name = props.Name or "Field",
		Size = props.Size or UDim2.new(1, 0, 0, if multiline then 120 else Tokens.touch + 4),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local box = Base.make("TextBox", {
		Name = "Box",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = multiline,
		PlaceholderText = props.placeholder or "",
		PlaceholderColor3 = C.faint,
		Text = props.text or "",
		TextColor3 = props.color or C.bone,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = if multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		TextWrapped = multiline,
		Size = UDim2.new(1, 0, 1, -4),
		ZIndex = z,
		Parent = frame,
	})
	box.FontFace = (Tokens.font :: any)[props.font or "body"] or Tokens.font.body
	box.TextSize = (Tokens.size :: any)[props.size or "lead"] or Tokens.size.lead
	Base.pad(box, Tokens.space.s, Tokens.space.m)
	Controls.focusable(box)
	local line = Base.make("Frame", {
		Name = "Line",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = z + 1,
		Parent = frame,
	})
	box.Focused:Connect(function()
		Motion.tween(line, { BackgroundColor3 = C.red, BackgroundTransparency = 0 }, Tokens.motion.quick)
	end)
	box.FocusLost:Connect(function()
		Motion.tween(line, { BackgroundColor3 = C.rule, BackgroundTransparency = 0.6 }, Tokens.motion.base)
	end)
	local maxLength = props.maxLength
	if maxLength then
		local counter = Base.label({
			Name = "Counter",
			Text = "",
			font = "mono",
			size = "micro",
			color = C.faint,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -8),
			Size = UDim2.fromOffset(60, 14),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = z + 1,
			Parent = frame,
		})
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local length = utf8.len(box.Text) or #box.Text
			if length > maxLength then
				box.Text = string.sub(box.Text, 1, (utf8.offset(box.Text, maxLength + 1) or (maxLength + 1)) - 1)
				return
			end
			counter.Text = if length > maxLength * 0.6 then string.format("%d/%d", length, maxLength) else ""
			counter.TextColor3 = if length >= maxLength then C.red else C.faint
		end)
	end
	return frame, box
end

-- A labelled row: the label on the left, `rightWidth` px on the right for a control.
local function labelledRow(props: Props, label: string, height: number?): (Frame, Frame)
	local row = Base.frame({
		Name = props.Name or "Row",
		Size = props.Size or UDim2.new(1, 0, 0, height or Tokens.touch),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Base.label({
		Name = "Label",
		Text = label,
		font = "body",
		size = "body",
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.42, 0, 1, 0),
		ZIndex = row.ZIndex,
		Parent = row,
	})
	local slot = Base.frame({
		Name = "Slot",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.58, 0, 1, 0),
		ZIndex = row.ZIndex,
		Parent = row,
	})
	return row, slot
end

-- A slider: a ruled track with red ink up to the value, and - / + buttons (for gamepads).
-- Returns the row and set(value) (which does not call onChanged).
function Controls.slider(
	props: Props,
	label: string,
	value: number,
	min: number,
	max: number,
	step: number,
	onChanged: (number) -> (),
	format: ((number) -> string)?
): (Frame, (number) -> ())
	local show = format or function(v: number): string
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end
	local row, slot = labelledRow(props, label)
	local z = row.ZIndex
	local current = value
	local valueLabel = Base.label({
		Text = "",
		font = "mono",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = z,
		Parent = slot,
	})
	local track = Base.hit({
		Name = "Track",
		Selectable = false,
		Position = UDim2.new(0, Tokens.touch, 0.5, -12),
		Size = UDim2.new(1, -(Tokens.touch * 2 + 60), 0, 24),
		ZIndex = z,
		Parent = slot,
	})
	Base.make("Frame", {
		Name = "Line",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = z,
		Parent = track,
	})
	local ink = Base.make("Frame", {
		Name = "Ink",
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 0, 0, 3),
		ZIndex = z + 1,
		Parent = track,
	})
	local nib = Base.make("Frame", {
		Name = "Nib",
		BackgroundColor3 = C.bone,
		BorderSizePixel = 0,
		Rotation = 45,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = z + 2,
		Parent = track,
	})
	local function set(newValue: number, notify: boolean?)
		local snapped = math.clamp(math.floor((newValue - min) / step + 0.5) * step + min, min, max)
		current = snapped
		local t = (snapped - min) / math.max(max - min, 1e-6)
		ink.Size = UDim2.new(t, 0, 0, 3)
		nib.Position = UDim2.fromScale(t, 0.5)
		valueLabel.Text = show(snapped)
		if notify then
			onChanged(snapped)
		end
	end
	local function fromX(x: number)
		local t = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		set(min + math.clamp(t, 0, 1) * (max - min), true)
	end
	local dragging = false
	track.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	row.Destroying:Once(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	Controls.iconButton(
		{ icon = "back", size = 32, Position = UDim2.fromScale(0, 0), ZIndex = z, Parent = slot },
		function()
			set(current - step, true)
		end
	)
	local plus = Controls.iconButton({
		icon = "play",
		size = 32,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 0),
		ZIndex = z,
		Parent = slot,
	}, function()
		set(current + step, true)
	end)
	local _ = plus
	set(value, false)
	return row, function(newValue: number)
		set(newValue, false)
	end
end

-- An on/off switch drawn as a wax seal: pressed in red when on, an empty ring when off.
-- Returns the row and set(value) (which does not call onChanged).
function Controls.toggle(
	props: Props,
	label: string,
	value: boolean,
	onChanged: (boolean) -> ()
): (Frame, (boolean) -> ())
	local row, slot = labelledRow(props, label)
	local z = row.ZIndex
	local button = Base.hit({
		Name = "Switch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(Tokens.touch * 2, Tokens.touch),
		ZIndex = z,
		Parent = slot,
	})
	Controls.focusable(button)
	local ring = Base.make("Frame", {
		Name = "Ring",
		BackgroundColor3 = C.red,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = z + 1,
		Parent = button,
	})
	Base.round(ring)
	local stroke = Base.stroke(ring, C.dim, 2, 0)
	local mark = Icon.new({
		name = "check",
		size = 20,
		color = C.bone,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = z + 2,
		Parent = ring,
	})
	local state = value
	local word = Base.label({
		Text = "",
		font = "label",
		size = "micro",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(40, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = z + 1,
		Parent = button,
	})
	local function set(on: boolean, notify: boolean?)
		state = on
		Motion.tween(ring, { BackgroundTransparency = if on then 0 else 1 }, Tokens.motion.base)
		stroke.Color = if on then C.blood else C.dim
		mark.Visible = on
		word.Text = if on then "ON" else "OFF"
		word.TextColor3 = if on then C.bone else C.dim
		if notify then
			onChanged(on)
		end
	end
	button.Activated:Connect(function()
		set(not state, true)
	end)
	set(value, false)
	return row, function(on: boolean)
		set(on, false)
	end
end

-- A thin ink meter. Props: color (red), height (px, 6), plus frame properties. Returns the
-- frame and set(fraction, animate?).
function Controls.meter(props: Props): (Frame, (number, boolean?) -> ())
	local height = props.height or 6
	local frame = Base.make("Frame", {
		Name = props.Name or "Meter",
		BackgroundColor3 = C.rule,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, height),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local fill = Base.make("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.color or C.red,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = frame.ZIndex + 1,
		Parent = frame,
	})
	return frame,
		function(fraction: number, animate: boolean?)
			local target = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			if animate then
				Motion.tween(fill, { Size = target }, Tokens.motion.slow)
			else
				fill.Size = target
			end
		end
end

return Controls
