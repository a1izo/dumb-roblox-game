--!strict
-- Primitive building blocks with the design tokens applied: frames, text, layouts, padding,
-- strokes and scrolling lists. Every other Kit component is made from these.
--
-- Props are the instance's own properties, plus a few shorthands on labels:
--   font  = a Tokens.font key ("body", "bodyBold", "label", "document", "mono"...)
--   size  = a Tokens.size key or a number
--   color = a Color3 (TextColor3)
--   upper = true to upper-case the text

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Create"))

local Tokens = require(script.Parent.Tokens)

local Base = {}

type Props = { [string]: any }

local SHORTHANDS = { font = true, size = true, color = true, upper = true }

local function merge(defaults: Props, props: Props?): Props
	local out = table.clone(defaults)
	if props then
		for key, value in pairs(props) do
			if not SHORTHANDS[key] then
				out[key] = value
			end
		end
	end
	return out
end

-- Creates `class` with `defaults`, overridden by `props`.
function Base.make(class: string, defaults: Props, props: Props?): any
	return Create(class, merge(defaults, props))
end

function Base.frame(props: Props?): Frame
	return Base.make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, props)
end

local function textSize(value: any): number
	if type(value) == "number" then
		return value
	end
	return (Tokens.size :: any)[value or "body"] or Tokens.size.body
end

local function applyText(label: any, props: Props?)
	local p = props or {}
	label.FontFace = (Tokens.font :: any)[p.font or "body"] or Tokens.font.body
	label.TextSize = textSize(p.size)
	label.TextColor3 = p.color or label.TextColor3
	if p.upper and type(label.Text) == "string" then
		label.Text = string.upper(label.Text)
	end
end

-- A text label: left-aligned, wrapping, growing to fit its text vertically.
function Base.label(props: Props?): TextLabel
	local label = Base.make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextColor3 = Tokens.color.bone,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		RichText = false,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = "",
	}, props)
	applyText(label, props)
	return label
end

-- A clickable area with no look of its own (the component draws it).
function Base.hit(props: Props?): TextButton
	return Base.make("TextButton", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}, props)
end

-- Layouts ----------------------------------------------------------------------------------

function Base.list(parent: Instance, gap: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Create("UIListLayout", {
		Padding = UDim.new(0, gap or Tokens.space.s),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Base.grid(parent: Instance, cell: UDim2, gap: number?): UIGridLayout
	return Create("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(gap or Tokens.space.s, gap or Tokens.space.s),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Base.pad(parent: Instance, all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
		Parent = parent,
	})
end

function Base.corner(parent: Instance, radius: number?): UICorner
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or Tokens.radius.key), Parent = parent })
end

function Base.round(parent: Instance): UICorner
	return Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Base.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Create("UIStroke", {
		Color = color or Tokens.color.rule,
		Thickness = thickness or Tokens.stroke.hair,
		Transparency = transparency or Tokens.alpha.hairline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Base.maxSize(parent: Instance, size: Vector2): UISizeConstraint
	return Create("UISizeConstraint", { MaxSize = size, Parent = parent })
end

-- A vertical scrolling list that grows its canvas to fit.
function Base.scroll(props: Props?): ScrollingFrame
	return Base.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Tokens.color.dim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Selectable = false,
	}, props)
end

-- Removes every child except layouts, padding and constraints.
function Base.clear(parent: Instance)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- Hands out increasing LayoutOrder numbers for screens that add rows in sequence.
function Base.counter(): () -> number
	local n = 0
	return function(): number
		n += 1
		return n
	end
end

return Base
