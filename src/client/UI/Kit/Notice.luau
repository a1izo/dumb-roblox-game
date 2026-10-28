--!strict
-- A notice: the one card for everything small over the world (toasts, the guide's tips, the Trial's step, the
-- daily streak). Every notice has the same parts in the same places, from Tokens.notice:
--
--   | [icon] EYEBROW                         X |   a small label row (optional), the X closes
--   | Title                                    |   Melodrama (optional)
--   | Body text, one or two short lines.       |   Montserrat body (optional)
--   | [extra slot]                             |   anything the screen adds (a meter, a held button)
--   | [ PRIMARY ]  [ ghost ]                   |   the actions (optional)
--
-- The accent line down the left is the kind's colour: white for most, red only for bad news and warnings.
-- It lives in a CanvasGroup so it fades and slides as one piece.

local Base = require(script.Parent.Base)
local Controls = require(script.Parent.Controls)
local GlyphText = require(script.Parent.GlyphText)
local Icon = require(script.Parent.Icon)
local Layout = require(script.Parent.Layout)
local Surfaces = require(script.Parent.Surfaces)
local Tokens = require(script.Parent.Tokens)

local C = Tokens.color
local N = Tokens.notice

local Notice = {}

-- kind -> { accent colour, default icon }
Notice.KINDS = {
	info = { C.g6, "note" },
	good = { C.white, "check" },
	bad = { C.danger, "cross" },
	warn = { C.danger, "bell" },
	secret = { C.g6, "eye" },
	coin = { C.white, "real" },
	guide = { C.white, "help" },
} :: { [string]: { any } }

export type Action = { text: string, variant: string?, icon: string?, onClick: (() -> ())? }

export type Props = {
	Name: string?,
	kind: string?,
	eyebrow: string?,
	icon: string?,
	title: string?,
	body: string?,
	close: (() -> ())?,
	actions: { Action }?,
	width: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Visible: boolean?,
}

export type Notice = {
	group: CanvasGroup,
	page: Frame,
	content: Frame,
	slot: Frame,
	actions: Frame,
	buttons: { TextButton },
	closeButton: TextButton?,
	setEyebrow: (self: Notice, text: string?) -> (),
	setTitle: (self: Notice, text: string?) -> (),
	setBody: (self: Notice, text: string?) -> (),
	setKind: (self: Notice, kind: string) -> (),
	setWidth: (self: Notice, width: number) -> (),
	[string]: any,
}

-- The width a notice takes on this device.
function Notice.width(): number
	return if Layout.isPhone() then N.phoneWidth else N.width
end

function Notice.new(props: Props): Notice
	local width = props.width or Notice.width()
	local kind = Notice.KINDS[props.kind or "info"] or Notice.KINDS.info
	local group = Base.make("CanvasGroup", {
		Name = props.Name or "Notice",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	}) :: CanvasGroup
	local function makePage(accent: Color3): (Frame, Frame)
		return Surfaces.page({
			Name = "Card",
			tone = "raised",
			alpha = N.alpha,
			edgeColor = accent,
			edgeWidth = N.edge,
			padding = N.padding,
			autoHeight = true,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = group,
		})
	end
	local page, content = makePage(kind[1])
	Base.list(content, N.gap)

	local self = { group = group, page = page, content = content } :: any

	-- Eyebrow: icon and a small capitals label (room is left on the right for the X).
	local eyebrowRow = Base.frame({
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Visible = false,
		Parent = content,
	})
	local eyebrowIcon = Icon.new({
		name = props.icon or kind[2],
		size = 18,
		color = kind[1],
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Parent = eyebrowRow,
	})
	local eyebrowLabel = Base.label({
		font = "bodyBold",
		size = "micro",
		color = C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -26 - (if props.close then 28 else 0), 1, 0),
		Parent = eyebrowRow,
	})

	-- Title.
	local title = GlyphText.new({
		face = "Head",
		text = "",
		size = N.titleSize,
		color = C.white,
		maxWidth = width - 2 * N.padding - (if props.close then 28 else 0),
		LayoutOrder = 2,
		Parent = content,
	})
	title.frame.Visible = false

	-- Body. A notice with only a body (a toast) leads with its icon beside the text instead of an eyebrow.
	local bodyRow = Base.frame({
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Visible = false,
		Parent = content,
	})
	local bodyIcon = Icon.new({
		name = props.icon or kind[2],
		size = 20,
		color = kind[1],
		Position = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = bodyRow,
	})
	local bodyLabel = Base.label({ size = "body", color = C.bone, Parent = bodyRow })

	local slot = Base.frame({
		Name = "Slot",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = content,
	})
	Base.list(slot, N.gap)

	local actions = Base.frame({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, N.actionHeight),
		LayoutOrder = 5,
		Visible = false,
		Parent = content,
	})
	Base.list(actions, Tokens.space.s, true)
	local buttons = {}
	for index, action in ipairs(props.actions or {}) do
		buttons[index] = Controls.button({
			text = action.text,
			icon = action.icon,
			variant = action.variant or (if index == 1 then "primary" else "ghost"),
			size = "s",
			LayoutOrder = index,
			Parent = actions,
		}, action.onClick)
		actions.Visible = true
	end

	if props.close then
		local close = props.close
		self.closeButton = Controls.iconButton({
			Name = "Close",
			icon = "cross",
			size = 28,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			ZIndex = page.ZIndex + 3,
			Parent = page,
		}, close)
	end

	self.slot = slot
	self.actions = actions
	self.buttons = buttons

	-- With no eyebrow or title, the body carries the icon (a toast).
	local function arrange()
		local lone = not eyebrowRow.Visible and not title.frame.Visible
		bodyIcon.Visible = lone
		bodyLabel.Position = UDim2.fromOffset(if lone then 30 else 0, 0)
		bodyLabel.Size = UDim2.new(1, if lone then -30 else 0, 0, 0)
	end

	function self.setEyebrow(_: Notice, text: string?)
		eyebrowLabel.Text = if text then string.upper(text) else ""
		eyebrowRow.Visible = text ~= nil and text ~= ""
		arrange()
	end
	function self.setTitle(_: Notice, text: string?)
		title:set(text or "")
		title.frame.Visible = text ~= nil and text ~= ""
		arrange()
	end
	function self.setBody(_: Notice, text: string?)
		bodyLabel.Text = text or ""
		bodyRow.Visible = text ~= nil and text ~= ""
		arrange()
	end
	function self.setKind(_: Notice, name: string)
		local k = Notice.KINDS[name] or Notice.KINDS.info
		eyebrowIcon.ImageColor3 = k[1]
		bodyIcon.ImageColor3 = k[1]
		local edge = page:FindFirstChild("Edge", true)
		if edge and edge:IsA("Frame") then
			edge.BackgroundColor3 = k[1]
		end
	end
	function self.setWidth(_: Notice, w: number)
		if group.Size.X.Offset == w then
			return
		end
		group.Size = UDim2.fromOffset(w, 0)
		title.props.maxWidth = w - 2 * N.padding - (if props.close then 28 else 0)
		title:refresh()
	end
	self.title = title
	self.bodyLabel = bodyLabel

	self:setEyebrow(props.eyebrow)
	self:setTitle(props.title)
	self:setBody(props.body)
	return self :: Notice
end

return Notice
