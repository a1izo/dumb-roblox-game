-- Camera / Enhance: the witness's note on the left (hat, coat, what they carry) and the grainy still on the right,
-- ten people on the street. The one hovered or selected is enhanced (drawn in full ink, the rest stay faint).
-- Pick the person on the note.

local Common = require(script.Parent.Common)

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle

	local note = Common.card({
		Name = "Note",
		fill = Common.SHEET,
		Size = UDim2.new(0.26, -8, 1, 0),
		Parent = ctx.area,
	})
	Common.caption(note, "the witness saw", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 18) })
	for i, line in ipairs(def.describe(puzzle)) do
		Common.text(note, line, {
			size = "lead",
			Position = UDim2.fromOffset(14, 40 + (i - 1) * 40),
			Size = UDim2.new(1, -28, 0, 34),
		})
		Common.rule(note, UDim2.new(0, 14, 0, 74 + (i - 1) * 40), UDim2.new(1, -28, 0, 1))
	end

	local still = Common.card({
		Name = "Still",
		fill = Common.CARD,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.74, -8, 1, 0),
		Parent = ctx.area,
	})
	Common.caption(still, "cam 03   street", { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18) })
	local street = Common.grid(still, def.COLS, def.ROWS, 6, {
		Name = "Street",
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 1, -40),
	})
	for position, look in ipairs(puzzle.people) do
		local cell
		cell = Common.target(
			ctx,
			{ Name = "Person", fill = false, line = 1, LayoutOrder = position, Parent = street },
			function()
				if ctx.submit(position) then
					Common.ring(cell, nil, 1.02)
				else
					ctx.miss(cell, "Not them.")
				end
			end
		)
		local figure = Common.person(cell, look, Common.SOFT)
		-- the pavement under them
		Common.rule(cell, UDim2.fromScale(0.1, 0.95), UDim2.new(0.8, 0, 0, 1))
		local function enhance(on: boolean)
			for _, part in ipairs(figure:GetDescendants()) do
				if part:IsA("Frame") then
					part.BackgroundColor3 = if on then Common.INK else Common.SOFT
				elseif part:IsA("UIStroke") then
					part.Color = if on then Common.INK else Common.SOFT
				end
			end
		end
		cell.MouseEnter:Connect(function()
			enhance(true)
		end)
		cell.MouseLeave:Connect(function()
			enhance(false)
		end)
		cell.SelectionGained:Connect(function()
			enhance(true)
		end)
		cell.SelectionLost:Connect(function()
			enhance(false)
		end)
		if position == 1 then
			ctx.first(cell)
		end
	end
	Common.grain(still, 0.82)
end
