-- Forensics · Handwriting: the same word in four hands. Each hand leans and lifts its letters its
-- own way; pick the one that matches the page, letter by letter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

-- Writes `word` one letter at a time with each letter's slant and rise.
local function written(parent: GuiObject, word: string, letters, slants, rises, size: number, color: Color3)
	local holder = Kit.frame({ Name = "Word", ZIndex = (parent.ZIndex or 3) + 1, Parent = parent })
	local count = #word
	for i = 1, count do
		local letter = letters[i]
		Kit.label({
			Text = string.sub(word, i, i),
			font = "hand",
			size = size,
			color = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((i - 0.5) / count, 0, 0.5, -rises[letter[2]]),
			Size = UDim2.fromOffset(size * 0.7, size * 1.2),
			Rotation = slants[letter[1]],
			ZIndex = holder.ZIndex,
			Parent = holder,
		})
	end
	return holder
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local page = Kit.Base.make("Frame", {
		Name = "Page",
		BackgroundColor3 = C.page,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.36, 0),
		Parent = ctx.area,
	})
	Kit.Base.stroke(page, C.red, 1, 0.5)
	Common.caption(page, Terms.f("from the page of {grimoire}"), { Position = UDim2.fromOffset(8, 4), color = C.red })
	written(page, puzzle.word, puzzle.sample, def.SLANTS, def.RISES, 52, C.bone)
	local samples =
		Kit.frame({ Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(1, 0.58), Parent = ctx.area })
	Kit.grid(samples, UDim2.new(0.5, -6, 0.5, -6), 6)
	for index, letters in ipairs(puzzle.choices) do
		local tile
		tile = Common.tile({ color = C.parchment, LayoutOrder = index, Parent = samples }, function()
			if not ctx.submit(index) then
				Common.flash(tile, false)
			end
		end)
		written(tile, puzzle.word, letters, def.SLANTS, def.RISES, 36, C.ink)
		if index == 1 then
			ctx.first(tile)
		end
	end
end
