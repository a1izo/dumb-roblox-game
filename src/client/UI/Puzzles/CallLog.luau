-- Phone / Call logs: two printed logs side by side, the carrier's and the tower's. One number is in both; some
-- others are a single digit off it. Pick it in either log, and both copies get ringed.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local function format(digits: string): string
	return string.sub(digits, 1, 3) .. "-" .. string.sub(digits, 4, 7) .. "-" .. string.sub(digits, 8, 11)
end

return function(ctx: Common.Context)
	local puzzle = ctx.puzzle
	local copies = {}
	local firstSet = false
	for column, list in ipairs({ puzzle.left, puzzle.right }) do
		local receipt = Common.card({
			Name = if column == 1 then "Carrier" else "Tower",
			fill = Common.SHEET,
			AnchorPoint = Vector2.new(column - 1, 0),
			Position = UDim2.fromScale(column - 1, 0),
			Size = UDim2.new(0.5, -10, 1, 0),
			Parent = ctx.area,
		})
		Common.caption(receipt, if column == 1 then "carrier log" else "tower log", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 18),
		})
		local rows = Kit.frame({
			Name = "Rows",
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 1, -40),
			Parent = receipt,
		})
		Kit.list(rows, 0)
		for index, number in ipairs(list) do
			local row
			row = Common.target(ctx, {
				Name = "Number",
				fill = false,
				line = 0,
				Size = UDim2.new(1, 0, 1 / #list, 0),
				LayoutOrder = index,
				Parent = rows,
			}, function()
				if ctx.submit(number) then
					for _, copy in ipairs(copies[number] or {}) do
						local ring = Common.ring(copy, nil, 1)
						ring.Size = UDim2.new(0.8, 0, 0.9, 0)
					end
				else
					ctx.miss(row, "That one isn't in both.")
				end
			end)
			Common.mono(row, format(number), {
				size = "lead",
				align = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
			})
			Common.mono(row, string.format("%02d", index), {
				size = "micro",
				color = Common.SOFT,
				Position = UDim2.fromOffset(4, 0),
				Size = UDim2.new(0, 24, 1, 0),
			})
			Common.rule(row, UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1))
			copies[number] = copies[number] or {}
			table.insert(copies[number], row)
			if not firstSet then
				firstSet = true
				ctx.first(row)
			end
		end
	end
end
