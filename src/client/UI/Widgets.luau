-- The UI kit, "angular manga" style: ink-black panels, paper-white cards, one red, square
-- corners, slanted buttons and ribbon titles in bold condensed type. Every panel builds from
-- these helpers so the whole game looks the same.
--
-- Slants are made with a UIGradient that cuts the left and right edges of a shape along two
-- parallel lines, so a plain Frame or button becomes a parallelogram without any images.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Core.Motion)
local Theme = require(script.Parent.Theme)

local Widgets = {}

local C = Theme.colors

local function merge(defaults: { [string]: any }, props: { [string]: any }?): { [string]: any }
	local result = table.clone(defaults)
	if props then
		for key, value in pairs(props) do
			result[key] = value
		end
	end
	-- Font and FontFace describe the same thing; the one the caller passed wins.
	if props and props.FontFace ~= nil and props.Font == nil then
		result.Font = nil
	elseif props and props.Font ~= nil and props.FontFace == nil then
		result.FontFace = nil
	end
	return result
end

-- Keys that configure a widget but are not Roblox properties.
local function take(props: { [string]: any }, key: string): any
	local value = props[key]
	props[key] = nil
	return value
end

-- Layout helpers ------------------------------------------------------------------------

function Widgets.corner(parent: Instance, radius: number?)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.radius.md), Parent = parent })
end

function Widgets.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return Create("UIStroke", {
		Color = color or C.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Widgets.padding(parent: Instance, all: number, horizontal: number?)
	local h = horizontal or all
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
		Parent = parent,
	})
end

function Widgets.list(parent: Instance, gap: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return Create("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Widgets.grid(parent: Instance, cellSize: UDim2, gap: number)
	return Create("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Widgets.sizeLimit(parent: Instance, maxSize: Vector2, minSize: Vector2?)
	return Create("UISizeConstraint", {
		MaxSize = maxSize,
		MinSize = minSize or Vector2.new(0, 0),
		Parent = parent,
	})
end

-- Turns a shape into a parallelogram leaning right ("/  /"). `amount` is how much of the
-- width each slanted edge takes (Theme.slant by default).
function Widgets.slant(gui: GuiObject, amount: number?): UIGradient
	local cut = math.clamp(amount or Theme.slant, 0.005, 0.2)
	local existing = gui:FindFirstChild("Slant")
	if existing then
		existing:Destroy()
	end
	return Create("UIGradient", {
		Name = "Slant",
		Rotation = 18,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(cut, 1),
			NumberSequenceKeypoint.new(cut + 0.001, 0),
			NumberSequenceKeypoint.new(1 - cut - 0.001, 0),
			NumberSequenceKeypoint.new(1 - cut, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = gui,
	})
end

-- An ink splat (made in Blender) behind a title. Stays empty until the textures are imported;
-- it keeps checking for a little while in case they are still loading.
function Widgets.inkSplat(props: { [string]: any }?, variant: number?): ImageLabel
	local image = Create(
		"ImageLabel",
		merge({
			Name = "InkSplat",
			BackgroundTransparency = 1,
			ImageColor3 = C.ink,
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 0,
		}, props)
	)
	local name = "InkSplat" .. tostring(variant or math.random(1, 3))
	task.spawn(function()
		for _ = 1, 12 do
			local texture = Assets.texture(name)
			if texture ~= "" then
				image.Image = texture
				return
			end
			task.wait(2.5)
		end
	end)
	return image
end

-- Basic elements --------------------------------------------------------------------------

-- Invisible container.
function Widgets.frame(props: { [string]: any }?): Frame
	return Create(
		"Frame",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, props)
	)
end

-- Ink-black panel with square corners and a hairline edge.
function Widgets.panel(props: { [string]: any }?): Frame
	local frame = Create(
		"Frame",
		merge({
			BackgroundColor3 = C.panel,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
		}, props)
	)
	Widgets.stroke(frame, C.stroke, 1, 0)
	return frame
end

-- Paper-white card with ink text inside (use for identity cards, documents).
function Widgets.card(props: { [string]: any }?): Frame
	return Create(
		"Frame",
		merge({
			BackgroundColor3 = C.paper,
			BorderSizePixel = 0,
		}, props)
	)
end

function Widgets.label(props: { [string]: any }?): TextLabel
	return Create(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.fonts.body,
			TextColor3 = C.text,
			TextSize = Theme.text.body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 20),
			Text = "",
		}, props)
	)
end

-- Loud condensed text: titles, numbers, role names.
function Widgets.display(props: { [string]: any }?): TextLabel
	local label = Widgets.label(merge({
		FontFace = Theme.faces.display,
		TextSize = Theme.text.title,
		Size = UDim2.new(1, 0, 0, 28),
	}, props))
	return label
end

-- A section heading: red, bold, upper case.
function Widgets.header(props: { [string]: any }?): TextLabel
	local label = Widgets.label(merge({
		FontFace = Theme.faces.display,
		TextSize = Theme.text.body,
		TextColor3 = C.accent,
		Size = UDim2.new(1, 0, 0, 20),
	}, props))
	label.Text = string.upper(label.Text)
	return label
end

-- A tilted red ribbon with a title in it. Returns the ribbon and its label.
function Widgets.ribbon(props: { [string]: any }?, text: string, color: Color3?): (Frame, TextLabel)
	local ribbon = Create(
		"Frame",
		merge({
			BackgroundColor3 = color or C.accent,
			BorderSizePixel = 0,
			Rotation = Theme.tilt,
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
		}, props)
	)
	Widgets.padding(ribbon, 2, 16)
	local label = Widgets.display({
		Text = string.upper(text),
		TextSize = Theme.text.title,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = ribbon,
	})
	return ribbon, label
end

-- A small red key tag like "[B]", placed at the left of a button.
local function keyTag(parent: GuiObject, key: string, inverted: boolean?)
	local tag = Widgets.frame({
		Name = "KeyTag",
		BackgroundTransparency = 0,
		BackgroundColor3 = if inverted then C.ink else C.accent,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	Widgets.padding(tag, 0, 5)
	Widgets.label({
		Text = key,
		FontFace = Theme.faces.display,
		TextSize = Theme.text.small,
		TextColor3 = C.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = parent.ZIndex + 2,
		Parent = tag,
	})
	return tag
end

-- Buttons -------------------------------------------------------------------------------

-- bg, text, hover bg, hover text
local VARIANTS = {
	primary = { C.accent, C.paper, C.accentHover, C.paper },
	secondary = { C.button, C.paper, C.paper, C.ink },
	ghost = { C.panel, C.paper, C.paper, C.ink },
	inverse = { C.paper, C.ink, C.accent, C.paper },
	team = { C.team, C.paper, C.paper, C.ink },
	gold = { C.paper, C.ink, C.accent, C.paper },
	good = { C.good, C.ink, C.paper, C.ink },
	danger = { C.bad, C.ink, C.paper, C.ink },
	paper = { C.paperDark, C.ink, C.ink, C.paper },
}

-- Hover inverts a button (black turns paper-white, red turns brighter) and pressing shrinks
-- it a little. Works for any GuiButton made by Widgets.button.
function Widgets.interactive(button: GuiButton, variant: string?)
	button.AutoButtonColor = false
	local colors = VARIANTS[variant or "secondary"] or VARIANTS.secondary
	local restBg: Color3? = nil
	local restText: Color3? = nil
	button.MouseEnter:Connect(function()
		if not button.Active then
			return
		end
		restBg = button.BackgroundColor3
		button.BackgroundColor3 = colors[3]
		if button:IsA("TextButton") then
			restText = button.TextColor3
			button.TextColor3 = colors[4]
		end
	end)
	button.MouseLeave:Connect(function()
		if restBg and button.BackgroundColor3 == colors[3] then
			button.BackgroundColor3 = restBg
		end
		if restText and button:IsA("TextButton") and button.TextColor3 == colors[4] then
			button.TextColor3 = restText
		end
		restBg, restText = nil, nil
	end)
	local scale = Create("UIScale", { Name = "PressScale", Parent = button })
	button.MouseButton1Down:Connect(function()
		if button.Active then
			Motion.tween(scale, { Scale = 0.95 }, 0.05)
		end
	end)
	local function release()
		Motion.tween(scale, { Scale = 1 }, 0.1)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.SelectionGained:Connect(function()
		button.BorderSizePixel = 0
		local ring = button:FindFirstChild("SelectRing") or Widgets.stroke(button, C.accent, 3, 0)
		ring.Name = "SelectRing"
	end)
	button.SelectionLost:Connect(function()
		local ring = button:FindFirstChild("SelectRing")
		if ring then
			ring:Destroy()
		end
	end)
end

-- Extra props: Variant ("primary", "secondary", "ghost", "inverse", "team", "gold", "good",
-- "danger", "paper"; secondary by default), Slant (true by default), Key (a key tag such as
-- "B"), Upper (upper-case text, true by default).
function Widgets.button(props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local given = table.clone(props or {})
	local variantName = take(given, "Variant") or "secondary"
	local slanted = take(given, "Slant")
	local key = take(given, "Key")
	local upper = take(given, "Upper")
	local colors = VARIANTS[variantName] or VARIANTS.secondary
	if upper ~= false and type(given.Text) == "string" then
		given.Text = string.upper(given.Text)
	end
	local button = Create(
		"TextButton",
		merge({
			BackgroundColor3 = colors[1],
			BorderSizePixel = 0,
			FontFace = Theme.faces.display,
			TextColor3 = colors[2],
			TextSize = Theme.text.bodyLarge,
			TextWrapped = true,
			Size = UDim2.fromOffset(140, 40),
			Text = "",
		}, given)
	)
	if variantName == "ghost" then
		Widgets.stroke(button, C.paper, 1, 0.55)
	end
	if slanted ~= false then
		Widgets.slant(button)
	end
	local pad = Create("UIPadding", {
		Name = "ButtonPad",
		PaddingLeft = UDim.new(0, if key then 38 else 14),
		PaddingRight = UDim.new(0, 14),
		Parent = button,
	})
	local _ = pad
	if key then
		local tag = keyTag(button, key)
		tag.Position = UDim2.new(0, -26, 0.5, 0)
	end
	Widgets.interactive(button, variantName)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Greys a button out and blocks clicks, or restores it.
function Widgets.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.5
	end
end

-- Paper-white field with ink text; a red edge while typing.
function Widgets.textbox(props: { [string]: any }?): TextBox
	local box = Create(
		"TextBox",
		merge({
			BackgroundColor3 = C.paper,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Theme.fonts.medium,
			PlaceholderColor3 = C.inkMuted,
			TextColor3 = C.ink,
			TextSize = Theme.text.bodyLarge,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
		}, props)
	)
	Widgets.padding(box, 6, 12)
	local stroke = Widgets.stroke(box, C.accent, 2, 1)
	box.Focused:Connect(function()
		stroke.Transparency = 0
	end)
	box.FocusLost:Connect(function()
		stroke.Transparency = 1
	end)
	return box
end

-- Keeps a text box at most `maxLength` characters long.
function Widgets.limitLength(box: TextBox, maxLength: number)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > maxLength then
			box.Text = string.sub(box.Text, 1, maxLength)
		end
	end)
end

function Widgets.scroll(props: { [string]: any }?): ScrollingFrame
	return Create(
		"ScrollingFrame",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.accent,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 1),
		}, props)
	)
end

-- Removes every GUI element inside a container but keeps layouts and padding.
function Widgets.clear(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Composite widgets ---------------------------------------------------------------------

-- A square-edged bar. Returns the bar and a function that sets the fill (0 to 1).
function Widgets.progressBar(props: { [string]: any }?, color: Color3?): (Frame, (number) -> ())
	local bar = Widgets.frame(merge({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, 0, 0, 8),
	}, props))
	local fill = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = color or C.accent,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	return bar, function(progress: number)
		fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	end
end

export type PickOption = { id: any, text: string, detail: string? }

-- A grid of choices where one can be selected. Returns a function that rebuilds it with new
-- options (keeping the selection when that option still exists).
function Widgets.pickGrid(
	parent: GuiObject,
	cellSize: UDim2,
	onPick: (any) -> (),
	style: { [string]: any }?
): ({ PickOption }, any?) -> ()
	Widgets.grid(parent, cellSize, Theme.space.sm)
	local look = style or {}
	return function(options: { PickOption }, selected: any?)
		Widgets.clear(parent)
		for index, option in ipairs(options) do
			local isSelected = option.id == selected
			local button = Widgets.button({
				Text = if option.detail then option.text .. "\n" .. option.detail else option.text,
				Font = look.Font,
				TextSize = look.TextSize or Theme.text.body,
				Variant = if isSelected then "primary" else (look.Variant or "secondary"),
				Upper = look.Upper,
				LayoutOrder = index,
				Parent = parent,
			}, function()
				onPick(option.id)
			end)
			if isSelected then
				Widgets.stroke(button, C.paper, 2, 0)
			end
		end
	end
end

-- A button that has to be held for `seconds` before it fires; a fill shows the progress.
-- Guards irreversible actions (writing a name, serving a warrant) against misclicks.
function Widgets.holdButton(props: { [string]: any }?, seconds: number, onConfirm: () -> ()): TextButton
	local button = Widgets.button(props)
	local fill = Widgets.frame({
		Name = "HoldFill",
		BackgroundTransparency = 0.5,
		BackgroundColor3 = C.paper,
		Size = UDim2.fromScale(0, 1),
		ZIndex = button.ZIndex + 1,
		Parent = button,
	})
	local holding = false
	local function reset()
		holding = false
		fill.Size = UDim2.fromScale(0, 1)
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
				reset()
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
	-- Gamepad and keyboard selection: hold the confirm button.
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

-- A labelled slider with - and + buttons. Returns the row and a setter.
function Widgets.slider(
	props: { [string]: any }?,
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
	local row = Widgets.frame(merge({ Size = UDim2.new(1, 0, 0, 40) }, props))
	Widgets.label({
		Text = string.upper(label),
		FontFace = Theme.faces.displayMedium,
		Size = UDim2.new(0.38, 0, 1, 0),
		Parent = row,
	})
	local valueLabel = Widgets.label({
		FontFace = Theme.faces.display,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.14, 0, 1, 0),
		Parent = row,
	})
	local current = value
	local track = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.new(0.38, 44, 0.5, -4),
		Size = UDim2.new(0.48, -88, 0, 8),
		Selectable = false,
		Parent = row,
	})
	local fill = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Parent = track,
	})

	local function set(newValue: number, notify: boolean?)
		local snapped = math.clamp(math.floor((newValue - min) / step + 0.5) * step + min, min, max)
		current = snapped
		fill.Size = UDim2.fromScale((snapped - min) / (max - min), 1)
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
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	Widgets.button({
		Text = "-",
		Slant = false,
		Position = UDim2.new(0.38, 0, 0.5, -16),
		Size = UDim2.fromOffset(32, 32),
		Parent = row,
	}, function()
		set(current - step, true)
	end)
	Widgets.button({
		Text = "+",
		Slant = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.86, 0, 0.5, -16),
		Size = UDim2.fromOffset(32, 32),
		Parent = row,
	}, function()
		set(current + step, true)
	end)
	set(value, false)
	return row, function(newValue: number)
		set(newValue, false)
	end
end

-- An on/off switch with a label. Returns the row and a setter.
function Widgets.toggle(
	props: { [string]: any }?,
	label: string,
	value: boolean,
	onChanged: (boolean) -> ()
): (Frame, (boolean) -> ())
	local row = Widgets.frame(merge({ Size = UDim2.new(1, 0, 0, 40) }, props))
	Widgets.label({
		Text = string.upper(label),
		FontFace = Theme.faces.displayMedium,
		Size = UDim2.new(1, -96, 1, 0),
		Parent = row,
	})
	local current = value
	local switch = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(84, 32),
		TextSize = Theme.text.body,
		Parent = row,
	})
	local function set(newValue: boolean)
		current = newValue
		switch.Text = if newValue then "ON" else "OFF"
		switch.BackgroundColor3 = if newValue then C.accent else C.button
		switch.TextColor3 = if newValue then C.paper else C.muted
	end
	switch.Activated:Connect(function()
		set(not current)
		onChanged(current)
	end)
	set(value)
	return row, set
end

-- Modal windows -------------------------------------------------------------------------

-- Centered modal window: an ink panel with a red ribbon title. Returns the window, its body,
-- the close button and the title label. onClose runs when the X is pressed.
function Widgets.modal(parent: Instance, title: string, maxSize: Vector2, onClose: (() -> ())?)
	local window = Widgets.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		ZIndex = 2,
		Visible = false,
		Parent = parent,
	})
	Widgets.sizeLimit(window, maxSize)
	-- A red bar along the left edge.
	Widgets.frame({
		Name = "Edge",
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Size = UDim2.new(0, 5, 1, 0),
		Parent = window,
	})
	-- Frees the mouse in first person and shift lock while the window is open.
	Create("TextButton", {
		Name = "MouseUnlock",
		Modal = true,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(0, 0),
		Selectable = false,
		Parent = window,
	})
	local ribbon, titleLabel = Widgets.ribbon({
		Name = "TitleRibbon",
		Position = UDim2.fromOffset(12, -14),
		Parent = window,
	}, title)
	titleLabel.Name = "Title"
	local _ = ribbon
	local close = Widgets.button({
		Name = "Close",
		Text = "X",
		Variant = "inverse",
		Slant = false,
		TextSize = Theme.text.title,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = window,
	}, function()
		if onClose then
			onClose()
		else
			window.Visible = false
		end
	end)
	local body = Widgets.frame({
		Name = "Body",
		Position = UDim2.fromOffset(22, 54),
		Size = UDim2.new(1, -40, 1, -70),
		Parent = window,
	})
	return window, body, close, titleLabel
end

-- A yes/no question on top of everything else. onConfirm runs only on "yes".
function Widgets.confirm(
	parent: Instance,
	title: string,
	body: string,
	confirmText: string,
	onConfirm: () -> (),
	variant: string?
)
	local shade = Create("TextButton", {
		Name = "Confirm",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Selectable = false,
		ZIndex = 50,
		Parent = parent,
	})
	local box = Widgets.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 51,
		Parent = shade,
	})
	Widgets.sizeLimit(box, Vector2.new(460, 400))
	Widgets.padding(box, Theme.space.xl, Theme.space.xl)
	Widgets.list(box, Theme.space.md)
	Widgets.ribbon({ LayoutOrder = 1, Parent = box }, title)
	Widgets.label({
		Text = body,
		TextColor3 = C.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = box,
	})
	local row = Widgets.frame({ Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3, Parent = box })
	local function dismiss()
		shade:Destroy()
	end
	local cancel = Widgets.button({
		Text = "Cancel",
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = row,
	}, dismiss)
	Widgets.button({
		Text = confirmText,
		Variant = variant or "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = row,
	}, function()
		dismiss()
		onConfirm()
	end)
	shade.Activated:Connect(dismiss)
	Motion.pop(box)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = cancel
	end
	return shade
end

return Widgets
