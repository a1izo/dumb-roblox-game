--!strict
-- A torn paper slip: the look of notifications (toasts). A small raised page with an ink mark
-- in the kind's colour, an icon and the message.

local Base = require(script.Parent.Base)
local Icon = require(script.Parent.Icon)
local Surfaces = require(script.Parent.Surfaces)
local Tokens = require(script.Parent.Tokens)

local Slip = {}

-- kind -> { mark colour, icon }
Slip.KINDS = {
	info = { Tokens.color.bone, "note" },
	good = { Tokens.color.good, "check" },
	bad = { Tokens.color.red, "cross" },
	warn = { Tokens.color.warn, "bell" },
	secret = { Tokens.color.secret, "eye" },
	coin = { Tokens.color.candle, "coin" },
} :: { [string]: { any } }

export type Props = {
	text: string,
	kind: string?,
	icon: string?,
	width: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	ZIndex: number?,
}

-- Returns the slip's frame (its height fits the text).
function Slip.new(props: Props): Frame
	local kind = Slip.KINDS[props.kind or "info"] or Slip.KINDS.info
	local width = props.width or 340
	local frame, content = Surfaces.page({
		Name = "Slip",
		tone = "raised",
		padding = Tokens.space.m,
		Size = UDim2.fromOffset(width, 60),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	Base.make("Frame", {
		Name = "Mark",
		BackgroundColor3 = kind[1],
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.new(0, 3, 1, -20),
		ZIndex = z + 2,
		Parent = frame,
	})
	Icon.new({
		name = props.icon or kind[2],
		size = 22,
		color = kind[1],
		Position = UDim2.fromOffset(Tokens.space.xs, 0),
		ZIndex = z + 2,
		Parent = content,
	})
	local label = Base.label({
		Text = props.text,
		size = "small",
		color = Tokens.color.bone,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -34, 0, 0),
		ZIndex = z + 2,
		Parent = content,
	})
	-- Fit the slip to the text once it has been laid out.
	local function fit()
		frame.Size = UDim2.fromOffset(width, math.max(48, label.AbsoluteSize.Y + Tokens.space.m * 2 + 4))
	end
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	return frame
end

return Slip
