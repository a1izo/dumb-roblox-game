-- Camera · Timeline: tap the six feeds in time order.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local grid = Kit.frame({ Parent = ctx.area })
	Kit.grid(grid, UDim2.new(1 / 3, -8, 0.5, -8), 8)
	local picked = {}
	for position, frame in ipairs(ctx.puzzle.frames) do
		local seconds = frame.time
		local stamp = string.format("%02d:%02d:%02d", (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
		local tile
		tile = Common.tile({ color = Color3.fromRGB(16, 22, 34), LayoutOrder = position, Parent = grid }, function()
			if frame.rank == #picked + 1 then
				table.insert(picked, position)
				Common.lock(tile, C.steel:Lerp(C.page, 0.55))
				Kit.label({
					Text = tostring(#picked),
					font = "mono",
					size = "micro",
					color = C.bone,
					Position = UDim2.fromOffset(8, 6),
					Size = UDim2.fromOffset(20, 14),
					AutomaticSize = Enum.AutomaticSize.None,
					ZIndex = 5,
					Parent = tile,
				})
				if #picked == 6 then
					ctx.submit(picked)
				end
			else
				Common.flash(tile, false)
			end
		end)
		if position == 1 then
			ctx.first(tile)
		end
		Common.caption(tile, string.format("cam %02d", frame.cam), {
			Position = UDim2.new(0, 0, 0.18, 0),
			align = Enum.TextXAlignment.Center,
		})
		Kit.label({
			Text = stamp,
			font = "mono",
			size = "lead",
			color = Color3.fromRGB(150, 200, 255),
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromScale(0, 0.42),
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 4,
			Parent = tile,
		})
	end
end
