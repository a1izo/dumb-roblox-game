-- Fingerprint / Match the print: the lifted print on the left, four print cards on the right. One card is the
-- same print; the others are one thing off (a ridge, the core, the scar or an island). Two lifts to match.

local Common = require(script.Parent.Common)

local LETTERS = { "A", "B", "C", "D" }

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local answer = {}

	local lift = Common.card({ Name = "Lift", fill = Common.SHEET, Size = UDim2.new(0.3, -8, 1, 0), Parent = ctx.area })
	local liftTitle = Common.caption(lift, "", { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 18) })
	local liftHolder = Common.card({
		Name = "Glass",
		fill = Common.SHEET,
		line = 1,
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -48),
		Parent = lift,
	})
	local cards = Common.grid(ctx.area, def.CARDS, 1, 10, {
		Name = "Cards",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.7, -8, 1, 0),
	})

	local function round(r: number)
		local data = puzzle.rounds[r]
		for _, child in ipairs(liftHolder:GetChildren()) do
			if child.Name == "Print" then
				child:Destroy()
			end
		end
		for _, child in ipairs(cards:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		liftTitle.Text = string.format("LIFT %d OF %d", r, def.ROUNDS)
		Common.print(liftHolder, data.sample, { fill = Common.SHEET })
		for position, spec in ipairs(data.choices) do
			local card
			card = Common.target(
				ctx,
				{ Name = "Card", fill = Common.CARD, LayoutOrder = position, Parent = cards },
				function()
					if position ~= data.correct then
						ctx.miss(card, "Not the same print.")
						return
					end
					answer[r] = position
					Common.ring(card, nil, 0.9)
					if r == def.ROUNDS then
						ctx.submit(answer)
					else
						for _, other in ipairs(cards:GetChildren()) do
							if other:IsA("GuiButton") then
								other.Active = false
							end
						end
						task.delay(0.5, function()
							if card.Parent then
								round(r + 1)
							end
						end)
					end
				end
			)
			Common.caption(card, "card " .. LETTERS[position], {
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -20, 0, 18),
			})
			Common.print(card, spec, {
				fill = Common.CARD,
				Position = UDim2.new(0.5, 0, 0.5, 10),
				Size = UDim2.new(0.86, 0, 0.86, -24),
			})
			if position == 1 then
				ctx.first(card)
				if r > 1 then
					Common.select(card)
				end
			end
		end
	end
	round(1)
end
