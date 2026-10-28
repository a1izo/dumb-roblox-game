-- "Join?": a card near the top of the screen when someone near asks you to a duo emote (DuoService), with
-- Join and No, and the seconds left to answer on its line. It goes by itself when the time is up.

local Kit = require(script.Parent.Kit)
local Screens = require(script.Parent.Screens)

local C = Kit.color

local DuoPanel = {}

local card: GuiObject? = nil
local token = 0

function DuoPanel.close()
	token += 1
	if card then
		card:Destroy()
		card = nil
	end
end

-- Asks; answer(true) for Join, answer(false) for No (also when the time runs out unanswered: nothing is sent).
function DuoPanel.ask(from: string, emote: string, seconds: number, answer: (boolean) -> ())
	DuoPanel.close()
	local mine = token
	local function reply(yes: boolean)
		if token ~= mine then
			return
		end
		DuoPanel.close()
		answer(yes)
	end
	-- A notice (Kit/Notice): who asks and what, the seconds left, then Join and No.
	local notice = Kit.notice({
		Name = "DuoAsk",
		kind = "info",
		eyebrow = "Duo emote",
		icon = "palm",
		title = from,
		body = string.format("Asks you to %s.", emote),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		actions = {
			{
				text = "Join",
				onClick = function()
					reply(true)
				end,
			},
			{
				text = "No",
				onClick = function()
					reply(false)
				end,
			},
		},
		Parent = Screens.panels,
	})
	card = notice.group
	local line = Kit.label({ size = "small", color = C.dim, LayoutOrder = 1, Parent = notice.slot })
	task.spawn(function()
		for left = math.floor(seconds), 1, -1 do
			if token ~= mine then
				return
			end
			line.Text = string.format("%d seconds to answer", left)
			task.wait(1)
		end
		if token == mine then
			DuoPanel.close()
		end
	end)
end

-- For checks: whether a question is up.
function DuoPanel.isOpen(): boolean
	return card ~= nil
end

return DuoPanel
