-- Phone · Dial: key the number from the call log into the keypad.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local digits = puzzle.number
	local typed = 0
	local log = Kit.label({
		Text = "CALL LOG   " .. def.format(digits),
		font = "mono",
		size = "lead",
		color = C.candle,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = ctx.area,
	})
	local _ = log
	local display = Kit.label({
		Text = "",
		font = "mono",
		size = "lead",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = ctx.area,
	})
	local function show()
		local shown = string.sub(digits, 1, typed) .. string.rep("_", #digits - typed)
		display.Text = "DIALLED    " .. def.format(shown)
	end
	local pad = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0.55, 0, 1, -64),
		Parent = ctx.area,
	})
	Kit.grid(pad, UDim2.new(1 / 3, -6, 0.25, -6), 6)
	for position, key in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#" }) do
		local tile
		tile = Common.tile({ LayoutOrder = position, Parent = pad }, function()
			if typed >= #digits then
				return
			end
			if key == string.sub(digits, typed + 1, typed + 1) then
				typed += 1
				show()
				Common.flash(tile, true)
				if typed == #digits then
					ctx.submit(digits)
				end
			else
				Common.flash(tile, false)
			end
		end)
		Kit.label({
			Text = key,
			font = "mono",
			size = "title",
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = tile,
		})
		if position == 1 then
			ctx.first(tile)
		end
	end
	show()
end
