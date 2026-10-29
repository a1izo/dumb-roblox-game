--!strict
-- A notification (concept A): a log line, not a box. The time in mono, a thin rule that boils, then the message in
-- bold capitals over the world; bad news and warnings sit on a red strip. Right-aligned, newest on top (UI/Toasts).

local Base = require(script.Parent.Base)
local Boil = require(script.Parent.Boil)
local Tokens = require(script.Parent.Tokens)

local Slip = {}

local C = Tokens.color

-- kind -> on a red strip
Slip.KINDS = {
	info = false,
	good = false,
	bad = true,
	warn = true,
	secret = false,
	coin = false,
} :: { [string]: boolean }

export type Props = {
	text: string,
	kind: string?,
	icon: string?,
	width: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	ZIndex: number?,
}

-- Returns the line (a CanvasGroup, so it fades as one piece; as tall as its text).
function Slip.new(props: Props): CanvasGroup
	local danger = Slip.KINDS[props.kind or "info"] == true
	local width = props.width or Tokens.notice.width
	local group = Base.make("CanvasGroup", {
		Name = "Slip",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	}) :: CanvasGroup
	local row = Base.frame({
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = group,
	})
	local list = Base.list(row, Tokens.space.m, true, Enum.HorizontalAlignment.Right)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	Base.label({
		Text = os.date("%H:%M") :: string,
		font = "mono",
		size = "small",
		color = C.g6,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 1,
		Parent = row,
	})
	Boil.attach(Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(2, 22),
		LayoutOrder = 2,
		Parent = row,
	}))
	local holder = Base.make("Frame", {
		Name = "Message",
		BackgroundColor3 = C.danger,
		BackgroundTransparency = if danger then 0 else 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 3,
		Parent = row,
	})
	if danger then
		Base.pad(holder, 3, 8)
	end
	local message = Base.label({
		Text = string.upper(props.text),
		font = "label",
		size = "body",
		color = C.white,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = holder,
	})
	-- (long messages wrap rather than run off the screen: the time and rule take about 70 px)
	local cap = Base.make("UISizeConstraint", { MaxSize = Vector2.new(width - 70, math.huge), Parent = message })
	local _ = cap
	if not danger then
		message.TextStrokeColor3 = C.g0
		message.TextStrokeTransparency = 0.55
	end
	return group
end

return Slip
