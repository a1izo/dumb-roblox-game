-- Forensics / Pen chromatography: the pigment from the page, run up a paper strip, has split into bands at its own
-- heights and tones. Pick the pen whose strip split the same way; each wrong pen is one band off (its tone, or a
-- step up or down).

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

-- darkest to lightest
local TONES = { Common.INK, Common.GREY, Common.SOFT, Common.FAINT }

-- A paper strip: the pencil line it was spotted on at the foot, the line the solvent reached at the top, and the
-- bands between.
local function strip(parent: GuiObject, bands, heights: number): Frame
	local paper = Common.card({
		Name = "Strip",
		fill = Common.SHEET,
		line = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0.5, 0, 1, -44),
		Parent = parent,
	})
	Common.rule(paper, UDim2.fromScale(0.1, 0.93), UDim2.new(0.8, 0, 0, 1), Common.GREY)
	Common.rule(paper, UDim2.fromScale(0.1, 0.04), UDim2.new(0.8, 0, 0, 1), Common.FAINT)
	for _, band in ipairs(bands) do
		local blot = Kit.Base.make("Frame", {
			Name = "Band",
			BackgroundColor3 = TONES[band[1]],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.86 - (band[2] - 1) / (heights - 1) * 0.76),
			Size = UDim2.new(0.7, 0, 0, 10),
			ZIndex = 3,
			Parent = paper,
		})
		Kit.Base.make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = blot })
	end
	return paper
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local sample =
		Common.card({ Name = "Sample", fill = Common.CARD, Size = UDim2.new(0.2, -8, 1, 0), Parent = ctx.area })
	Common.caption(sample, "from the page", { align = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10) })
	strip(sample, puzzle.sample, def.HEIGHTS)
	local pens = Common.grid(ctx.area, #puzzle.pens, 1, 10, {
		Name = "Pens",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.8, -16, 1, 0),
	})
	for index, bands in ipairs(puzzle.pens) do
		local tile
		tile = Common.target(ctx, { Name = "Pen", LayoutOrder = index, Parent = pens }, function()
			if ctx.submit(index) then
				Common.ring(tile, nil, 0.95)
			else
				ctx.miss(tile, "Those bands don't match.")
			end
		end)
		Common.caption(
			tile,
			"pen " .. index,
			{ align = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10) }
		)
		strip(tile, bands, def.HEIGHTS)
		if index == 1 then
			ctx.first(tile)
		end
	end
end
