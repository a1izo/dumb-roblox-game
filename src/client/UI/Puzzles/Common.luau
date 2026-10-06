-- Building blocks for the puzzle views: tiles you tap, dials with - / + (so gamepads and
-- touch work everywhere), dot boards and quick flashes (red for wrong, pale for right).

local Kit = require(script.Parent.Parent.Kit)
local Motion = require(script.Parent.Parent.Core.Motion)

local C = Kit.color
local T = Kit.Tokens

local Common = {}

export type Context = {
	area: Frame,
	puzzle: any,
	def: any,
	-- Checks the answer here first; returns true when it is right (the task is then solved).
	submit: (any) -> boolean,
	hint: (string) -> (),
	first: (GuiObject) -> (), -- what a gamepad selects first
	practice: boolean,
}

-- A square-ish tappable tile on a dark raised card. Returns the button.
function Common.tile(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local button = Kit.Base.hit({
		Name = props.Name or "Tile",
		BackgroundColor3 = props.color or C.raised,
		BackgroundTransparency = 0,
		Size = props.Size or UDim2.fromOffset(80, 80),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 3,
		Parent = props.Parent,
	})
	Kit.Base.stroke(button, C.rule, 1, 0.8)
	Kit.Controls.focusable(button)
	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		if button.Active then
			button.BackgroundColor3 = base:Lerp(C.bone, 0.08)
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = base
	end)
	if onClick then
		button.Activated:Connect(function()
			if button.Active then
				onClick()
			end
		end)
	end
	button:SetAttribute("BaseColor", base)
	return button
end

-- Flashes a tile red (wrong) or green (right) for a moment.
function Common.flash(gui: GuiObject, good: boolean)
	local base = gui:GetAttribute("BaseColor") or gui.BackgroundColor3
	gui.BackgroundColor3 = if good then C.good:Lerp(C.page, 0.35) else C.blood
	task.delay(0.28, function()
		if gui.Parent then
			Motion.tween(gui, { BackgroundColor3 = base }, T.motion.base)
		end
	end)
	if not good then
		local position = gui.Position
		gui.Position = position + UDim2.fromOffset(4, 0)
		Motion.tween(gui, { Position = position }, 0.18, Enum.EasingStyle.Elastic)
	end
end

-- Marks a tile as used (right answer already taken).
function Common.lock(gui: GuiObject, color: Color3?)
	gui:SetAttribute("BaseColor", color or C.good:Lerp(C.page, 0.5))
	gui.BackgroundColor3 = color or C.good:Lerp(C.page, 0.5)
	if gui:IsA("GuiButton") then
		gui.Active = false
		gui.Selectable = false
	end
end

-- A small caption in capitals.
function Common.caption(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local p = props or {}
	return Kit.label({
		Text = string.upper(text),
		font = "label",
		size = "micro",
		color = p.color or C.dim,
		TextXAlignment = p.align or Enum.TextXAlignment.Left,
		Position = p.Position,
		Size = p.Size or UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 3,
		LayoutOrder = p.LayoutOrder,
		Parent = parent,
	})
end

-- A dial: label, - button, value, + button. Returns the row and set(value).
function Common.dial(
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
		Name = "Dial_" .. label,
		Size = p.Size or UDim2.new(1, 0, 0, T.touch),
		Position = p.Position,
		LayoutOrder = p.LayoutOrder,
		Parent = parent,
	})
	Kit.label({
		Text = string.upper(label),
		font = "label",
		size = "small",
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.4, 0, 1, 0),
		ZIndex = 3,
		Parent = row,
	})
	local current = value
	local shown = Kit.label({
		Text = "",
		font = "mono",
		size = "lead",
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.7, 0),
		Size = UDim2.new(0, 60, 1, 0),
		ZIndex = 3,
		Parent = row,
	})
	local function set(v: number, notify: boolean?)
		current = math.clamp(v, min, max)
		shown.Text = tostring(current)
		if notify then
			onChanged(current)
		end
	end
	local minus = Common.tile({
		Name = "Minus",
		Size = UDim2.fromOffset(T.touch, T.touch),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.7, -36, 0, 0),
		Parent = row,
	}, function()
		set(current - 1, true)
	end)
	Kit.label({
		Text = "−",
		font = "mono",
		size = "title",
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = minus,
	})
	local plus = Common.tile({
		Name = "Plus",
		Size = UDim2.fromOffset(T.touch, T.touch),
		Position = UDim2.new(0.7, 36, 0, 0),
		Parent = row,
	}, function()
		set(current + 1, true)
	end)
	Kit.label({
		Text = "+",
		font = "mono",
		size = "title",
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = plus,
	})
	set(value, false)
	return row, function(v: number)
		set(v, false)
	end
end

-- A grid of cells (bits: 1 = ridge) drawn inside `parent`, `n` per side.
function Common.bitGrid(parent: GuiObject, bits: { number }, n: number, ink: Color3?, paper: Color3?)
	local holder = Kit.frame({
		Name = "Bits",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.82),
		ZIndex = (parent.ZIndex or 3) + 1,
		Parent = parent,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = holder })
	Kit.grid(holder, UDim2.new(1 / n, -2, 1 / n, -2), 2)
	for i = 1, n * n do
		Kit.Base.make("Frame", {
			BackgroundColor3 = if bits[i] == 1 then (ink or C.ink) else (paper or C.parchment),
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
	end
	return holder
end

-- A round dot at a fraction of a board.
function Common.dot(parent: Instance, x: number, y: number, size: number, color: Color3, z: number?): Frame
	local dot = Kit.Base.make("Frame", {
		Name = "Dot",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 4,
		Parent = parent,
	})
	Kit.Base.round(dot)
	return dot
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

return Common
