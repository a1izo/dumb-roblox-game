-- Camera · Enhance: the still is too grainy to read; the magnifier (3 x 3 cells) shows what is
-- there. Hovering or selecting a cell moves the magnifier; tapping a revealed cell picks it.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local cols, rows = def.COLS, def.ROWS
	local board = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = cols / rows, Parent = board })
	Kit.grid(board, UDim2.new(1 / cols, -3, 1 / rows, -3), 3)
	local rng = Random.new(puzzle.target * 31)
	local cells = {}
	local centre = 0
	local function reveal(index: number)
		centre = index
		local cx, cy = (index - 1) % cols, (index - 1) // cols
		for i, cell in ipairs(cells) do
			local x, y = (i - 1) % cols, (i - 1) // cols
			local shown = math.abs(x - cx) <= 1 and math.abs(y - cy) <= 1
			cell.noise.Visible = not shown
			cell.thing.Visible = shown
			cell.tile.BackgroundColor3 = if shown then Color3.fromRGB(34, 38, 44) else Color3.fromRGB(22, 22, 26)
		end
	end
	for i = 1, cols * rows do
		local tile
		tile = Common.tile({ color = Color3.fromRGB(22, 22, 26), LayoutOrder = i, Parent = board }, function()
			local cx, cy = (centre - 1) % cols, (centre - 1) // cols
			local x, y = (i - 1) % cols, (i - 1) // cols
			if centre == 0 or math.abs(x - cx) > 1 or math.abs(y - cy) > 1 then
				reveal(i)
				return
			end
			if not ctx.submit(i) then
				Common.flash(tile, false)
				ctx.hint("No red scarf there. Keep looking.")
			end
		end)
		-- Grain: a few specks at random.
		local noise = Kit.frame({ Name = "Noise", ZIndex = 4, Parent = tile })
		for _ = 1, 5 do
			Kit.Base.make("Frame", {
				BackgroundColor3 = C.bone,
				BackgroundTransparency = rng:NextNumber(0.6, 0.9),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(rng:NextNumber(0.05, 0.9), rng:NextNumber(0.05, 0.9)),
				Size = UDim2.fromOffset(rng:NextInteger(2, 6), rng:NextInteger(2, 4)),
				ZIndex = 4,
				Parent = noise,
			})
		end
		local thing = Kit.frame({ Name = "Thing", Visible = false, ZIndex = 4, Parent = tile })
		local kind = puzzle.cells[i]
		if kind ~= "" then
			Kit.icon({
				name = kind,
				size = 30,
				color = C.bone,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				ZIndex = 5,
				Parent = thing,
			})
			if i == puzzle.target then
				-- The red scarf.
				Kit.Base.make("Frame", {
					BackgroundColor3 = C.red,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.6),
					Size = UDim2.fromOffset(18, 4),
					ZIndex = 6,
					Parent = thing,
				})
			end
		end
		tile.MouseEnter:Connect(function()
			reveal(i)
		end)
		tile.SelectionGained:Connect(function()
			reveal(i)
		end)
		cells[i] = { tile = tile, noise = noise, thing = thing }
		if i == 1 then
			ctx.first(tile)
		end
	end
end
