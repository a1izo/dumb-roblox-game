-- Phone · Cipher wheel: turn the wheel until the intercepted text reads as a word, then pick it.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local wheel = 0
	Common.caption(ctx.area, "intercepted text", { Position = UDim2.fromOffset(0, 0) })
	Kit.label({
		Text = puzzle.encoded,
		font = "mono",
		size = "heading",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = ctx.area,
	})
	Common.caption(ctx.area, "through the wheel", { Position = UDim2.fromOffset(0, 60) })
	local decoded = Kit.label({
		Text = "",
		font = "mono",
		size = "heading",
		color = C.bone,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = ctx.area,
	})
	local function show()
		decoded.Text = def.shift(puzzle.encoded, -wheel)
	end
	local row = Common.dial(ctx.area, "Wheel", wheel, 0, 25, function(v)
		wheel = v
		show()
	end, { Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, Kit.Tokens.touch) })
	ctx.first(row:FindFirstChild("Plus") :: GuiObject)
	local options = Kit.frame({
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 1, -184),
		Parent = ctx.area,
	})
	Kit.grid(options, UDim2.new(0.5, -6, 0.5, -6), 6)
	for index, word in ipairs(puzzle.options) do
		local tile
		tile = Common.tile({ LayoutOrder = index, Parent = options }, function()
			if not ctx.submit(word) then
				Common.flash(tile, false)
			end
		end)
		Kit.label({
			Text = word,
			font = "document",
			size = "lead",
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = tile,
		})
	end
	show()
end
