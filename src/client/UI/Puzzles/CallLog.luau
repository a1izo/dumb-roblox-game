-- Phone · Call logs: two logs side by side; tap the one number that is in both.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

local function format(digits: string): string
	return string.sub(digits, 1, 3) .. "-" .. string.sub(digits, 4, 7) .. "-" .. string.sub(digits, 8, 11)
end

return function(ctx: Common.Context)
	local puzzle = ctx.puzzle
	local firstSet = false
	for column, list in ipairs({ puzzle.left, puzzle.right }) do
		local holder = Kit.frame({
			Position = UDim2.fromScale(if column == 1 then 0 else 0.52, 0),
			Size = UDim2.fromScale(0.48, 1),
			Parent = ctx.area,
		})
		Common.caption(holder, if column == 1 then "carrier log" else "tower log", { LayoutOrder = 0 })
		Kit.list(holder, 4)
		for index, number in ipairs(list) do
			local tile
			tile = Common.tile({
				Size = UDim2.new(1, 0, 0, 38),
				LayoutOrder = index,
				Parent = holder,
			}, function()
				if not ctx.submit(number) then
					Common.flash(tile, false)
				end
			end)
			Kit.label({
				Text = format(number),
				font = "mono",
				size = "body",
				color = C.bone,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				Parent = tile,
			})
			if not firstSet then
				firstSet = true
				ctx.first(tile)
			end
		end
	end
end
