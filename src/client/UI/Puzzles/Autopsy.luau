-- Forensics / Autopsy chart: the coroner's report on the left, three marks on the body, and the chart on the
-- right, drawn from the front (a face) or the back (the spine). Left and right in the report are the body's own.
-- Pick each part the report names; each found line is ticked off.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle

	local report =
		Common.card({ Name = "Report", fill = Common.SHEET, Size = UDim2.new(0.42, -8, 1, 0), Parent = ctx.area })
	Common.caption(report, "coroner's report", { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 18) })
	local lines = {}
	for i, text in ipairs(def.report(puzzle)) do
		local y = 40 + (i - 1) * 52
		lines[i] = Common.text(
			report,
			text,
			{ size = "lead", Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 40) }
		)
		Common.rule(report, UDim2.new(0, 14, 0, y + 44), UDim2.new(1, -28, 0, 1))
	end
	Common.text(report, "Left and right are the body's own.", {
		size = "small",
		color = Common.GREY,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -10),
		Size = UDim2.new(1, -28, 0, 40),
	})

	local chartCard = Common.card({
		Name = "Chart",
		fill = Common.CARD,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.58, -8, 1, 0),
		Parent = ctx.area,
	})
	Common.caption(chartCard, if puzzle.back then "seen from the back" else "seen from the front", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 18),
	})
	local chart = Kit.frame({
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.new(1, -20, 1, -38),
		Parent = chartCard,
	})
	Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = 0.62, Parent = chart })

	local wanted = {}
	for i, id in ipairs(puzzle.marks) do
		wanted[id] = i
	end
	local found = {}
	for _, region in ipairs(def.REGIONS) do
		local r = def.rect(puzzle, region.id)
		local part
		part = Common.target(ctx, {
			Name = "Part",
			fill = Common.SHEET,
			Position = UDim2.fromScale(r[1], r[2]),
			Size = UDim2.fromScale(r[3], r[4]),
			ZIndex = 3,
			Parent = chart,
		}, function()
			local line = wanted[region.id]
			if not line then
				ctx.miss(part, "The report doesn't name that.")
				return
			end
			if found[region.id] then
				return
			end
			found[region.id] = true
			Common.ring(part, nil, 0.9)
			lines[line].TextColor3 = Common.SOFT
			Common.rule(lines[line], UDim2.fromScale(0, 0.5), UDim2.new(1, 0, 0, 2), Common.RED)
			local list = {}
			for id in pairs(found) do
				table.insert(list, id)
			end
			if #list == def.MARKS then
				ctx.submit(list)
			end
		end)
		Kit.Base.make("UICorner", { CornerRadius = UDim.new(if region.id == 1 then 0.5 else 0.25, 0), Parent = part })
		local border = part:FindFirstChild("Border")
		if border then
			Kit.Base.make(
				"UICorner",
				{ CornerRadius = UDim.new(if region.id == 1 then 0.5 else 0.25, 0), Parent = border }
			)
		end
		if region.id == 1 then
			-- which way the body faces: a face from the front, the back of the head from behind
			if puzzle.back then
				Common.rule(part, UDim2.fromScale(0.3, 0.3), UDim2.new(0.4, 0, 0, 2), Common.SOFT)
			else
				Common.dot(part, 0.35, 0.45, 5, Common.INK, 5)
				Common.dot(part, 0.65, 0.45, 5, Common.INK, 5)
				Common.rule(part, UDim2.fromScale(0.38, 0.72), UDim2.new(0.24, 0, 0, 2), Common.INK)
			end
			ctx.first(part)
		elseif puzzle.back and (region.id == 3 or region.id == 4) then
			Common.rule(part, UDim2.new(0.5, -1, 0.05, 0), UDim2.new(0, 2, 0.9, 0), Common.SOFT)
		end
	end
end
