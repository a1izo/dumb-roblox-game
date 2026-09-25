-- Fingerprint · Dust and lift: brush the glass (drag across it, or tap or select cells) to clear
-- the dust; once most of the print shows, pick the card that matches it.

local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local n = def.SIZE
	local glass = Kit.Base.make("Frame", {
		Name = "Glass",
		BackgroundColor3 = Color3.fromRGB(30, 34, 40),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.46, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = glass })
	Kit.grid(glass, UDim2.new(1 / n, -2, 1 / n, -2), 2)
	local cleared, total = 0, n * n
	local dust = {}
	local cards = {}
	local meterLabel = Common.caption(ctx.area, "", {
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 0, 16),
	})
	local function progress()
		meterLabel.Text = string.format("glass brushed: %d%%", math.floor(cleared / total * 100))
		local ready = cleared / total >= def.REVEAL
		for _, card in ipairs(cards) do
			card.Active = ready
			card.Selectable = ready
			card.BackgroundTransparency = if ready then 0 else 0.6
		end
		if ready then
			meterLabel.Text = "Now pick the matching card."
		end
	end
	local function brush(index: number)
		local cx, cy = (index - 1) % n, (index - 1) // n
		for i, cell in ipairs(dust) do
			local x, y = (i - 1) % n, (i - 1) // n
			if cell.Visible and math.abs(x - cx) <= 1 and math.abs(y - cy) <= 1 then
				cell.Visible = false
				cleared += 1
			end
		end
		progress()
	end
	local brushing = false
	for i = 1, total do
		local cell = Common.tile({
			Name = "Cell",
			color = if puzzle.print[i] == 1 then Color3.fromRGB(28, 26, 30) else Color3.fromRGB(190, 196, 204),
			LayoutOrder = i,
			Parent = glass,
		}, function()
			brush(i)
		end)
		cell:SetAttribute("BaseColor", cell.BackgroundColor3)
		local cover = Kit.Base.make("Frame", {
			Name = "Dust",
			BackgroundColor3 = Color3.fromRGB(120, 116, 110),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = cell,
		})
		dust[i] = cover
		cell.MouseEnter:Connect(function()
			if brushing then
				brush(i)
			end
		end)
		cell.SelectionGained:Connect(function()
			brush(i)
		end)
		if i == 1 then
			ctx.first(cell)
		end
	end
	local down = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			brushing = true
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
		up:Disconnect()
	end)
	local row = Kit.frame({
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.new(0.5, 0, 1, -22),
		Parent = ctx.area,
	})
	Kit.grid(row, UDim2.new(1 / 3, -6, 0.8, 0), 6)
	for position, bits in ipairs(puzzle.cards) do
		local card
		card = Common.tile({ color = C.parchment, LayoutOrder = position, Parent = row }, function()
			if not ctx.submit(position) then
				Common.flash(card, false)
			end
		end)
		Common.bitGrid(card, bits, n)
		table.insert(cards, card)
	end
	progress()
end
