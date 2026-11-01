-- Fingerprint / Minutiae: the file print on the left has twelve points, five of them marked in red by the report.
-- The lift on the right is the same print mirrored (a print on glass is reversed). Pick the same five points on it.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local grid = def.GRID

	local function panel(name: string, title: string, anchor: number, mirror: boolean): Frame
		local card = Common.card({
			Name = name,
			fill = Common.SHEET,
			AnchorPoint = Vector2.new(anchor, 0),
			Position = UDim2.fromScale(anchor, 0),
			Size = UDim2.new(0.5, -8, 1, 0),
			Parent = ctx.area,
		})
		Common.caption(card, title, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18) })
		local holder = Kit.frame({
			Name = "Holder",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 32),
			Size = UDim2.new(1, -24, 1, -44),
			Parent = card,
		})
		Kit.Base.make("UIAspectRatioConstraint", { AspectRatio = Common.PRINT_ASPECT, Parent = holder })
		Common.print(holder, puzzle.print, {
			fill = Common.SHEET,
			mirror = mirror,
			color = Common.FAINT,
			Size = UDim2.fromScale(1, 1),
		})
		return holder
	end
	local file = panel("File", "file print", 0, false)
	local lift = panel("Lift", "lift, mirrored", 1, true)

	local function at(p: { number }, mirror: boolean): (number, number)
		local x, y = (p[1] + 0.5) / grid, (p[2] + 0.5) / grid
		return if mirror then 1 - x else x, y
	end
	local marked = {}
	for _, index in ipairs(puzzle.marked) do
		marked[index] = true
	end
	for index, p in ipairs(puzzle.points) do
		local x, y = at(p, false)
		Common.dot(file, x, y, 0.045, Common.INK, 6)
		if marked[index] then
			Common.hoop(file, x, y, 26, Common.RED, 7)
		end
	end

	local found = {}
	local first = true
	for index, p in ipairs(puzzle.points) do
		local x, y = at(p, true)
		local point
		point = Common.target(ctx, {
			Name = "Point",
			fill = false,
			line = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 8,
			Parent = lift,
		}, function()
			if not marked[index] then
				ctx.miss(point, "That point isn't marked.")
				return
			end
			if found[index] then
				return
			end
			found[index] = true
			Common.ring(point, nil, 0.85)
			point.Active = false
			point.Selectable = false
			local list = {}
			for i in pairs(found) do
				table.insert(list, i)
			end
			if #list == def.MARKED then
				ctx.submit(list)
			end
		end)
		Common.dot(point, 0.5, 0.5, 0.4, Common.INK, 9)
		if first then
			first = false
			ctx.first(point)
		end
	end
end
