-- Fingerprint / Dust and lift: the glass on the left is under dust. Brush it off (drag across it, or move a
-- gamepad's selection over it) to bring the print up; once most of it shows, pick the card on the right that
-- matches. The other cards are one thing off.

local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

-- (dust in three ramp greys, so the sheet turns it to soft pencil tones)
local DUST = { Kit.color.g4, Kit.color.g5, Kit.color.g3 }

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local n = def.SIZE

	local left = Kit.frame({ Name = "Left", Size = UDim2.new(0.42, -8, 1, 0), Parent = ctx.area })
	local meter = Common.caption(left, "", { Size = UDim2.new(1, 0, 0, 20) })
	local glass = Common.card({
		Name = "Glass",
		fill = Common.SHEET,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		Parent = left,
	})
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = Common.PRINT_ASPECT, Parent = glass })
	Common.print(glass, puzzle.print, { fill = Common.SHEET })
	local cellsFrame = Kit.frame({ Name = "Dust", ZIndex = 10, Parent = glass })
	local dust = {}
	local cleared, total = 0, n * n

	local cards = {}
	local ready = false
	local function progress()
		local share = cleared / total
		ready = share >= def.REVEAL
		meter.Text = if ready
			then "NOW PICK THE MATCHING CARD"
			else string.format("BRUSHED %d%%", math.floor(share * 100))
		for _, card in ipairs(cards) do
			Common.setEnabled(card, ready)
		end
	end
	local function brush(cx: number, cy: number)
		local changed = false
		for y = cy - 1, cy + 1 do
			for x = cx - 1, cx + 1 do
				local cell = if x >= 0 and y >= 0 and x < n and y < n then dust[y * n + x + 1] else nil
				if cell and cell.BackgroundTransparency < 1 then
					cell.BackgroundTransparency = 1
					cleared += 1
					changed = true
				end
			end
		end
		if changed then
			progress()
		end
	end
	for i = 1, total do
		local x, y = (i - 1) % n, (i - 1) // n
		local cell = Kit.Base.hit({
			Name = "Patch",
			BackgroundColor3 = DUST[(x * 7 + y * 3) % 3 + 1],
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(x / n, y / n),
			Size = UDim2.fromScale(1 / n + 0.002, 1 / n + 0.002),
			ZIndex = 10,
			Parent = cellsFrame,
		})
		Kit.Controls.focusable(cell)
		cell.SelectionGained:Connect(function()
			brush(x, y)
		end)
		cell.Activated:Connect(function()
			brush(x, y)
		end)
		dust[i] = cell
		if i == 1 then
			ctx.first(cell)
		end
	end
	-- dragging (mouse or finger) brushes wherever it goes over the glass
	local brushing = false
	local function at(position: Vector3)
		local origin, size = glass.AbsolutePosition, glass.AbsoluteSize
		local fx, fy = (position.X - origin.X) / size.X, (position.Y - origin.Y) / size.Y
		if fx >= 0 and fy >= 0 and fx < 1 and fy < 1 then
			brush(math.floor(fx * n), math.floor(fy * n))
		end
	end
	local down = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			brushing = true
			at(input.Position)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input)
		if
			brushing
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			at(input.Position)
		end
	end)
	local up = UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			brushing = false
		end
	end)
	glass.Destroying:Once(function()
		down:Disconnect()
		moved:Disconnect()
		up:Disconnect()
	end)

	local row = Common.grid(ctx.area, #puzzle.cards, 1, 10, {
		Name = "Cards",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.58, -8, 1, 0),
	})
	for position, spec in ipairs(puzzle.cards) do
		local card
		card = Common.target(ctx, { Name = "Card", LayoutOrder = position, Parent = row }, function()
			if not ready then
				return
			end
			if ctx.submit(position) then
				Common.ring(card, nil, 0.9)
			else
				ctx.miss(card, "Not the same print.")
			end
		end)
		Common.print(card, spec, { fill = Common.CARD })
		table.insert(cards, card)
	end
	progress()
end
