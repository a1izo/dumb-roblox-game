-- Forensics · Autopsy chart: mark on the body chart the three places the coroner's report
-- lists. The chart faces you, so the body's left is on your right.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local report = Kit.Base.make("Frame", {
		Name = "Report",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.4, 1),
		Parent = ctx.area,
	})
	Kit.pad(report, Kit.space.m)
	Kit.list(report, Kit.space.s)
	Kit.label({
		Text = "CORONER'S REPORT",
		font = "label",
		size = "small",
		color = C.ink,
		LayoutOrder = 1,
		Parent = report,
	})
	for index, id in ipairs(puzzle.marks) do
		Kit.label({
			Text = string.format("%d. Bruising, %s.", index, def.REGIONS[id].name),
			font = "document",
			size = "body",
			color = C.ink,
			LayoutOrder = index + 1,
			Parent = report,
		})
	end
	local chart = Kit.Base.make("Frame", {
		Name = "Chart",
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.56, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = 0.7, Parent = chart })
	local chosen: { number } = {}
	local tiles = {}
	local function reset()
		chosen = {}
		for _, tile in ipairs(tiles) do
			tile.BackgroundColor3 = tile:GetAttribute("BaseColor")
			local mark = tile:FindFirstChild("Mark")
			if mark then
				mark:Destroy()
			end
		end
	end
	for index, region in ipairs(def.REGIONS) do
		local r = region.rect
		local tile
		tile = Common.tile({
			Name = "Region_" .. region.id,
			color = Color3.fromRGB(120, 114, 104),
			Position = UDim2.fromScale(r[1], r[2]),
			Size = UDim2.fromScale(r[3], r[4]),
			Parent = chart,
		}, function()
			local at = table.find(chosen, region.id)
			if at then
				table.remove(chosen, at)
				local mark = tile:FindFirstChild("Mark")
				if mark then
					mark:Destroy()
				end
				return
			end
			table.insert(chosen, region.id)
			Kit.icon({
				Name = "Mark",
				name = "cross",
				size = 22,
				color = C.white,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 6,
				Parent = tile,
			})
			if #chosen == def.MARKS then
				if not ctx.submit(table.clone(chosen)) then
					ctx.hint("Those are not the three places in the report. The chart faces you.")
					Common.flash(chart, false)
					reset()
				end
			end
		end)
		table.insert(tiles, tile)
		if index == 1 then
			ctx.first(tile)
		end
	end
end
