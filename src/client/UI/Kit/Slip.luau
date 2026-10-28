--!strict
-- A toast: a notice with only its icon and the message (Kit/Notice), the accent in the kind's colour (red only
-- for bad news and warnings).

local Notice = require(script.Parent.Notice)

local Slip = {}

Slip.KINDS = Notice.KINDS

export type Props = {
	text: string,
	kind: string?,
	icon: string?,
	width: number?,
	Parent: Instance?,
	LayoutOrder: number?,
	ZIndex: number?,
}

-- Returns the toast (a CanvasGroup, so it fades as one piece; its height fits the text).
function Slip.new(props: Props): CanvasGroup
	local notice = Notice.new({
		Name = "Slip",
		kind = props.kind or "info",
		icon = props.icon,
		body = props.text,
		width = props.width,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	return notice.group
end

return Slip
