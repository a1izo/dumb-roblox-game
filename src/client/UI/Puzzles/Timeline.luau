-- Camera / Timeline: six stills, each with its camera's clock (some 24 hour, some 12 hour). Pick them earliest
-- first; each pick gets its red number and fills the strip above. A pick out of order starts the strip again.

local Common = require(script.Parent.Common)

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local count = def.COUNT

	-- the strip: one box per place in the order, filled with the camera picked for it
	local strip = Common.grid(ctx.area, count, 1, 8, { Name = "Strip", Size = UDim2.new(1, 0, 0, 44) })
	local slots = {}
	for i = 1, count do
		local slot = Common.card({ LayoutOrder = i, fill = Common.SHEET, line = 1, Parent = strip })
		Common.mono(slot, tostring(i), {
			size = "micro",
			color = Common.SOFT,
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(16, 16),
		})
		slots[i] =
			Common.mono(slot, "", { size = "body", align = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	end

	local board = Common.grid(ctx.area, 3, 2, 12, {
		Name = "Stills",
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
	})
	local picked = {}
	local marks = {}
	local tiles = {}
	local function reset()
		for _, mark in ipairs(marks) do
			mark:Destroy()
		end
		table.clear(marks)
		table.clear(picked)
		for _, slot in ipairs(slots) do
			slot.Text = ""
		end
		for _, tile in ipairs(tiles) do
			Common.setEnabled(tile, true)
		end
	end
	for position, frame in ipairs(puzzle.frames) do
		local tile
		tile = Common.target(ctx, { Name = "Still", LayoutOrder = position, Parent = board }, function()
			if frame.rank == #picked + 1 then
				table.insert(picked, position)
				table.insert(marks, Common.badge(tile, tostring(#picked)))
				slots[#picked].Text = string.format("CAM %02d", frame.cam)
				Common.setEnabled(tile, false)
				if #picked == count then
					ctx.submit(picked)
				end
			else
				ctx.miss(tile, "Not the next one. Start again.")
				reset()
			end
		end)
		tiles[position] = tile
		if position == 1 then
			ctx.first(tile)
		end
		-- the still: a screen with the camera's name and its clock burnt in
		local screen = Common.card({
			Name = "Screen",
			fill = Common.SHADE,
			line = 0,
			Position = UDim2.fromScale(0.07, 0.12),
			Size = UDim2.fromScale(0.86, 0.76),
			Parent = tile,
		})
		Common.grain(screen, 0.7)
		Common.caption(screen, string.format("cam %02d", frame.cam), {
			color = Common.INK,
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 18),
		})
		Common.mono(screen, def.stamp(frame), {
			size = "title",
			align = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0, 0.38),
			Size = UDim2.new(1, 0, 0.4, 0),
		})
	end
end
