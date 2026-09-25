-- Fingerprint · Match the print: three samples, four prints each; pick the match.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local puzzle = ctx.puzzle
	local answers = {}
	local holder = Kit.frame({ Parent = ctx.area })

	local function round(r: number)
		Kit.clear(holder)
		local data = puzzle.rounds[r]
		local sample = Kit.Base.make("Frame", {
			Name = "Sample",
			BackgroundColor3 = C.parchment,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0.3, 1),
			Parent = holder,
		})
		Common.bitGrid(sample, data.sample, 4)
		Common.caption(sample, string.format("sample %d of %d", r, #puzzle.rounds), {
			align = Enum.TextXAlignment.Center,
			color = C.inkDim,
			Position = UDim2.fromOffset(0, 4),
		})
		local choices =
			Kit.frame({ Position = UDim2.fromScale(0.34, 0), Size = UDim2.fromScale(0.66, 1), Parent = holder })
		Kit.grid(choices, UDim2.new(0.5, -6, 0.5, -6), 6)
		for position, bits in ipairs(data.choices) do
			local tile
			tile = Common.tile(
				{ color = C.parchment:Lerp(C.page, 0.1), LayoutOrder = position, Parent = choices },
				function()
					if position == data.correct then
						answers[r] = position
						if r < #puzzle.rounds then
							round(r + 1)
						else
							ctx.submit(answers)
						end
					else
						Common.flash(tile, false)
					end
				end
			)
			Common.bitGrid(tile, bits, 4)
			if position == 1 then
				ctx.first(tile)
			end
		end
	end

	round(1)
end
