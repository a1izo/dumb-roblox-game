-- Small UI kit: styled frames, labels, buttons, text boxes and modals.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

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

function Widgets.corner(parent: Instance, radius: number?)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
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

-- Dark rounded panel with a light border.
function Widgets.panel(props: { [string]: any }?): Frame
	local frame = Create(
		"Frame",
		merge({
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
		}, props)
	)
	Widgets.corner(frame, 10)
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
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 20),
			Text = "",
		}, props)
	)
end

function Widgets.button(props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local button = Create(
		"TextButton",
		merge({
			AutoButtonColor = true,
			BackgroundColor3 = Theme.colors.button,
			BorderSizePixel = 0,
			Font = Theme.fonts.bold,
			TextColor3 = Theme.colors.text,
			TextSize = 16,
			TextWrapped = true,
			Size = UDim2.fromOffset(140, 38),
			Text = "",
		}, props)
	)
	Widgets.corner(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
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
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 40),
			Text = "",
		}, props)
	)
	Widgets.corner(box, 8)
	Widgets.padding(box, 6, 10)
	return box
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

-- Centered modal window. Returns the window, its body and the close button.
function Widgets.modal(parent: Instance, title: string, maxSize: Vector2, onClose: (() -> ())?)
	local window = Widgets.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		Visible = false,
		Parent = parent,
	})
	Widgets.sizeLimit(window, maxSize)
	local titleLabel = Widgets.label({
		Name = "Title",
		Font = Theme.fonts.black,
		TextSize = 20,
		Text = string.upper(title),
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -70, 0, 26),
		Parent = window,
	})
	local close = Widgets.button({
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Theme.colors.panelLight,
		Parent = window,
	}, function()
		window.Visible = false
		if onClose then
			onClose()
		end
	end)
	local body = Widgets.frame({
		Name = "Body",
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 1, -66),
		Parent = window,
	})
	return window, body, close, titleLabel
end

return Widgets
