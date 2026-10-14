-- "Join?": a card near the top of the screen when someone near asks you to a duo emote (DuoService), with
-- Join and No, and the seconds left to answer on its line. It goes by itself when the time is up.

local Kit = require(script.Parent.Kit)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local DuoPanel = {}

local card: Frame? = nil
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
	local box = Kit.card({
		Name = "DuoAsk",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(360, 132),
		Parent = Screens.panels,
	})
	card = box
	Kit.label({
		Text = string.format("%s asks you to %s.", from, emote),
		font = "bodyBold",
		size = "body",
		color = C.white,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = box,
	})
	local line = Kit.label({
		Text = "",
		font = "bodyItalic",
		size = "body",
		color = C.dim,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = box,
	})
	local row = Kit.frame({
		Name = "Answers",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = box,
	})
	Kit.list(row, T.space.s, true)
	local function reply(yes: boolean)
		if token ~= mine then
			return
		end
		DuoPanel.close()
		answer(yes)
	end
	Kit.button(
		{ text = "Join", variant = "primary", size = "s", Size = UDim2.new(0.5, -T.space.s / 2, 1, 0), Parent = row },
		function()
			reply(true)
		end
	)
	Kit.button(
		{ text = "No", variant = "ghost", size = "s", Size = UDim2.new(0.5, -T.space.s / 2, 1, 0), Parent = row },
		function()
			reply(false)
		end
	)
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
