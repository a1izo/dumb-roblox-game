-- Forensics · Ink chromatography: the ink from the page has split into bands on paper. Pick the
-- pen whose ink splits the same way.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

local function strip(parent: GuiObject, bands, inks, heights: number)
	for index, band in ipairs(bands) do
		Kit.Base.make("Frame", {
			Name = "Band",
			BackgroundColor3 = inks[band[1]],
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.1 + (band[2] - 1) / (heights - 1) * 0.8),
			Size = UDim2.new(0.66, 0, 0, 8 + index),
			ZIndex = (parent.ZIndex or 3) + 1,
			Parent = parent,
		})
	end
end

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local sample = Kit.Base.make("Frame", {
		Name = "Sample",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.2, 1),
		Parent = ctx.area,
	})
	Common.caption(
		sample,
		"page ink",
		{ align = Enum.TextXAlignment.Center, color = C.inkDim, Position = UDim2.fromOffset(0, 4) }
	)
	strip(sample, puzzle.sample, def.INKS, def.HEIGHTS)
	local pens = Kit.frame({ Position = UDim2.fromScale(0.26, 0), Size = UDim2.fromScale(0.74, 1), Parent = ctx.area })
	Kit.grid(pens, UDim2.new(0.25, -8, 1, 0), 8)
	for index, bands in ipairs(puzzle.pens) do
		local tile
		tile = Common.tile({ color = C.parchment:Lerp(C.page, 0.08), LayoutOrder = index, Parent = pens }, function()
			if not ctx.submit(index) then
				Common.flash(tile, false)
			end
		end)
		Common.caption(
			tile,
			"pen " .. index,
			{ align = Enum.TextXAlignment.Center, color = C.inkDim, Position = UDim2.fromOffset(0, 4) }
		)
		strip(tile, bands, def.INKS, def.HEIGHTS)
		if index == 1 then
			ctx.first(tile)
		end
	end
end
