-- The UI kit: styled frames, labels, buttons (with hover and press states), text boxes,
-- progress bars, pick grids, hold-to-confirm buttons, sliders, toggles, confirm dialogs and
-- modal windows. Every panel builds from these so the whole game looks the same.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Core.Motion)
local Theme = require(script.Parent.Theme)

local Widgets = {}

local function merge(defaults: { [string]: any }, props: { [string]: any }?): { [string]: any }
	local result = table.clone(defaults)
	if props then
		for key, value in pairs(props) do
			result[key] = value
		end
	end
	return result
end

-- Layout helpers ------------------------------------------------------------------------

function Widgets.corner(parent: Instance, radius: number?)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.radius.md), Parent = parent })
end

function Widgets.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return Create("UIStroke", {
		Color = color or Theme.colors.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0.3,
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

-- Dark rounded panel with a thin border.
function Widgets.panel(props: { [string]: any }?): Frame
	local frame = Create(
		"Frame",
		merge({
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
		}, props)
	)
	Widgets.corner(frame, Theme.radius.lg)
	Widgets.stroke(frame)
	return frame
end

function Widgets.label(props: { [string]: any }?): TextLabel
	return Create(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.fonts.body,
			TextColor3 = Theme.colors.text,
			TextSize = Theme.text.body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 20),
			Text = "",
		}, props)
	)
end

-- A small upper-case section heading.
function Widgets.header(props: { [string]: any }?): TextLabel
	local label = Widgets.label(merge({
		Font = Theme.fonts.black,
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		Size = UDim2.new(1, 0, 0, 18),
	}, props))
	label.Text = string.upper(label.Text)
	return label
end

-- Buttons -------------------------------------------------------------------------------

local VARIANTS = {
	primary = { bg = Theme.colors.accent, text = Theme.colors.text },
	secondary = { bg = Theme.colors.button, text = Theme.colors.text },
	team = { bg = Theme.colors.team, text = Theme.colors.backdrop },
	gold = { bg = Theme.colors.gold, text = Theme.colors.ink },
	good = { bg = Theme.colors.good, text = Theme.colors.ink },
	danger = { bg = Theme.colors.bad, text = Theme.colors.ink },
	ghost = { bg = Theme.colors.panel, text = Theme.colors.text },
	paper = { bg = Theme.colors.paperDark, text = Theme.colors.ink },
}

-- Hover lightens a button and pressing shrinks it a little. Works for any GuiButton.
function Widgets.interactive(button: GuiButton)
	button.AutoButtonColor = false
	local base: Color3? = nil
	local hoverColor: Color3? = nil
	button.MouseEnter:Connect(function()
		if not button.Active then
			return
		end
		base = button.BackgroundColor3
		hoverColor = base:Lerp(Color3.new(1, 1, 1), 0.1)
		button.BackgroundColor3 = hoverColor :: Color3
	end)
	button.MouseLeave:Connect(function()
		if base and button.BackgroundColor3 == hoverColor then
			button.BackgroundColor3 = base
		end
		base, hoverColor = nil, nil
	end)
	local scale = Create("UIScale", { Name = "PressScale", Parent = button })
	button.MouseButton1Down:Connect(function()
		if button.Active then
			Motion.tween(scale, { Scale = 0.96 }, 0.06)
		end
	end)
	local function release()
		Motion.tween(scale, { Scale = 1 }, 0.1)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

-- props may include Variant = "primary" | "secondary" | "team" | "gold" | "good" | "danger"
-- | "ghost" | "paper" (secondary by default).
function Widgets.button(props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local given = table.clone(props or {})
	local variant = VARIANTS[given.Variant or "secondary"] or VARIANTS.secondary
	given.Variant = nil
	local button = Create(
		"TextButton",
		merge({
			BackgroundColor3 = variant.bg,
			BorderSizePixel = 0,
			Font = Theme.fonts.bold,
			TextColor3 = variant.text,
			TextSize = Theme.text.body,
			TextWrapped = true,
			Size = UDim2.fromOffset(140, 40),
			Text = "",
		}, given)
	)
	Widgets.corner(button, Theme.radius.md)
	if (props or {}).Variant == "ghost" then
		Widgets.stroke(button, Theme.colors.strokeStrong, 1, 0.4)
	end
	Widgets.interactive(button)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Greys a button out and blocks clicks, or restores it.
function Widgets.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.55
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.45
	end
end

function Widgets.textbox(props: { [string]: any }?): TextBox
	local box = Create(
		"TextBox",
		merge({
			BackgroundColor3 = Theme.colors.panelLight,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = Theme.fonts.medium,
			PlaceholderColor3 = Theme.colors.muted,
			TextColor3 = Theme.colors.text,
			TextSize = Theme.text.bodyLarge,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
		}, props)
	)
	Widgets.corner(box, Theme.radius.md)
	Widgets.padding(box, 6, 10)
	local stroke = Widgets.stroke(box, Theme.colors.stroke, 1, 0.5)
	box.Focused:Connect(function()
		stroke.Color = Theme.colors.focus
		stroke.Transparency = 0
	end)
	box.FocusLost:Connect(function()
		stroke.Color = Theme.colors.stroke
		stroke.Transparency = 0.5
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
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.colors.stroke,
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

-- A rounded bar. Returns the bar and a function that sets the fill (0 to 1).
function Widgets.progressBar(props: { [string]: any }?, color: Color3?): (Frame, (number) -> ())
	local bar = Widgets.frame(merge({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.panelLight,
		Size = UDim2.new(1, 0, 0, 10),
	}, props))
	Widgets.corner(bar, Theme.radius.pill)
	local fill = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = color or Theme.colors.gold,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	Widgets.corner(fill, Theme.radius.pill)
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
				Font = look.Font or Theme.fonts.bold,
				TextSize = look.TextSize or Theme.text.body,
				Variant = if isSelected then "primary" else (look.Variant or "secondary"),
				LayoutOrder = index,
				Parent = parent,
			}, function()
				onPick(option.id)
			end)
			if isSelected then
				Widgets.stroke(button, Theme.colors.focus, 2, 0)
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
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = button.ZIndex + 1,
		Parent = button,
	})
	Widgets.corner(fill, Theme.radius.md)
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
		Text = label,
		Font = Theme.fonts.medium,
		Size = UDim2.new(0.38, 0, 1, 0),
		Parent = row,
	})
	local valueLabel = Widgets.label({
		Font = Theme.fonts.mono,
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
		BackgroundColor3 = Theme.colors.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.new(0.38, 44, 0.5, -5),
		Size = UDim2.new(0.48, -88, 0, 10),
		Selectable = false,
		Parent = row,
	})
	Widgets.corner(track, Theme.radius.pill)
	local fill = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		Parent = track,
	})
	Widgets.corner(fill, Theme.radius.pill)

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
		Font = Theme.fonts.black,
		Position = UDim2.new(0.38, 0, 0.5, -16),
		Size = UDim2.fromOffset(32, 32),
		Parent = row,
	}, function()
		set(current - step, true)
	end)
	Widgets.button({
		Text = "+",
		Font = Theme.fonts.black,
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
		Text = label,
		Font = Theme.fonts.medium,
		Size = UDim2.new(1, -90, 1, 0),
		Parent = row,
	})
	local current = value
	local switch = Widgets.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(76, 30),
		TextSize = Theme.text.small,
		Parent = row,
	})
	local function set(newValue: boolean)
		current = newValue
		switch.Text = if newValue then "ON" else "OFF"
		switch.BackgroundColor3 = if newValue then Theme.colors.good else Theme.colors.button
		switch.TextColor3 = if newValue then Theme.colors.ink else Theme.colors.muted
	end
	switch.Activated:Connect(function()
		set(not current)
		onChanged(current)
	end)
	set(value)
	return row, set
end

-- Modal windows -------------------------------------------------------------------------

-- Centered modal window. Returns the window, its body, the close button and the title.
-- onClose runs when the X is pressed; without it the window just hides.
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
	local titleLabel = Widgets.label({
		Name = "Title",
		Font = Theme.fonts.black,
		TextSize = Theme.text.title,
		Text = string.upper(title),
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(1, -76, 0, 26),
		Parent = window,
	})
	Widgets.frame({
		Name = "Rule",
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.accent,
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.fromOffset(36, 2),
		Parent = window,
	})
	local close = Widgets.button({
		Name = "Close",
		Text = "X",
		Font = Theme.fonts.black,
		Variant = "ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
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
		Position = UDim2.fromOffset(18, 56),
		Size = UDim2.new(1, -36, 1, -72),
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
		BackgroundTransparency = 0.35,
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
	Widgets.sizeLimit(box, Vector2.new(440, 400))
	Widgets.padding(box, Theme.space.lg)
	Widgets.list(box, Theme.space.md)
	Widgets.label({
		Text = string.upper(title),
		Font = Theme.fonts.black,
		TextSize = Theme.text.title,
		ZIndex = 52,
		LayoutOrder = 1,
		Parent = box,
	})
	Widgets.label({
		Text = body,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 52,
		LayoutOrder = 2,
		Parent = box,
	})
	local row = Widgets.frame({ Size = UDim2.new(1, 0, 0, 42), ZIndex = 52, LayoutOrder = 3, Parent = box })
	local function dismiss()
		shade:Destroy()
	end
	local cancel = Widgets.button({
		Text = "Cancel",
		Size = UDim2.new(0.5, -4, 1, 0),
		ZIndex = 53,
		Parent = row,
	}, dismiss)
	Widgets.button({
		Text = confirmText,
		Variant = variant or "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		ZIndex = 53,
		Parent = row,
	}, function()
		dismiss()
		onConfirm()
	end)
	shade.Activated:Connect(dismiss)
	Motion.pop(box)
	if UserInputService.GamepadEnabled then
		game:GetService("GuiService").SelectedObject = cancel
	end
	return shade
end

return Widgets
