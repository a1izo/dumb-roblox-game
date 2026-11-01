-- Forensics / Handwriting: a word from the page in someone's hand, and the same word in four hands below. Each
-- hand leans and lifts its letters its own way; the wrong ones differ in two letters. Pick the same hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

-- Writes `word` one letter at a time with each letter's slant and rise, on a pencil line.
local function written(parent: GuiObject, word: string, letters, slants, rises, size: number)
	local holder = Kit.frame({
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.new(0, size * 0.75 * #word, 0, size * 1.3),
		Parent = parent,
	})
	Common.rule(holder, UDim2.new(-0.05, 0, 0.82, 0), UDim2.new(1.1, 0, 0, 1))
	local count = #word
	for i = 1, count do
		local letter = letters[i]
		Kit.label({
			Text = string.sub(word, i, i),
			font = "hand",
			size = size,
			color = Common.INK,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((i - 0.5) / count, 0, 0.5, -rises[letter[2]] * size / 40),
			Size = UDim2.fromOffset(size * 0.7, size * 1.2),
			Rotation = slants[letter[1]],
			ZIndex = 3,
			Parent = holder,
		})
	end
	return holder
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local page =
		Common.card({ Name = "Page", fill = Common.SHEET, Size = UDim2.new(1, 0, 0.38, -6), Parent = ctx.area })
	Common.caption(
		page,
		Terms.f("from the page of {grimoire}"),
		{ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18) }
	)
	written(page, puzzle.word, puzzle.sample, def.SLANTS, def.RISES, 56)
	local samples = Common.grid(ctx.area, 2, 2, 10, {
		Name = "Samples",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.62, -6),
	})
	for index, letters in ipairs(puzzle.choices) do
		local tile
		tile = Common.target(ctx, { Name = "Sample", LayoutOrder = index, Parent = samples }, function()
			if ctx.submit(index) then
				Common.ring(tile, nil, 0.98)
			else
				ctx.miss(tile, "Not the same writer.")
			end
		end)
		Common.caption(
			tile,
			"sample " .. index,
			{ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18) }
		)
		written(tile, puzzle.word, letters, def.SLANTS, def.RISES, 40)
		if index == 1 then
			ctx.first(tile)
		end
	end
end
