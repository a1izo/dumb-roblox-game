-- Fingerprint · Minutiae: the file print (left) has five marked points; tap the same five on
-- the lifted print (right), which is its mirror image.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local grid = def.GRID
	local function at(x: number, y: number): (number, number)
		return (x + 0.5) / grid, (y + 0.5) / grid
	end
	local marked = {}
	for _, index in ipairs(puzzle.marked) do
		marked[index] = true
	end
	local file = Kit.Base.make("Frame", {
		Name = "File",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.48, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = file })
	Common.caption(file, "file print", { Position = UDim2.fromOffset(6, 4), color = C.inkDim })
	for index, p in ipairs(puzzle.points) do
		local x, y = at(p[1], p[2])
		Common.dot(file, x, y, 10, C.inkDim)
		if marked[index] then
			local ring = Common.dot(file, x, y, 24, C.red, 3)
			ring.BackgroundTransparency = 1
			Kit.Base.stroke(ring, C.red, 2, 0)
		end
	end
	local lifted = Kit.Base.make("Frame", {
		Name = "Lifted",
		BackgroundColor3 = Color3.fromRGB(34, 38, 44),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.48, 1),
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = lifted })
	Common.caption(lifted, "lifted print (mirrored)", { Position = UDim2.fromOffset(6, 4) })
	local chosen: { number } = {}
	local buttons = {}
	local function reset()
		chosen = {}
		for _, button in ipairs(buttons) do
			button.BackgroundColor3 = C.bone
		end
	end
	for index, p in ipairs(puzzle.points) do
		local x, y = at(grid - 1 - p[1], p[2])
		local button = Kit.Base.hit({
			Name = "Point",
			BackgroundTransparency = 0,
			BackgroundColor3 = C.bone,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(Kit.Tokens.touch * 0.6, Kit.Tokens.touch * 0.6),
			ZIndex = 4,
			Parent = lifted,
		})
		Kit.Base.round(button)
		Kit.Controls.focusable(button)
		button.Activated:Connect(function()
			local at_ = table.find(chosen, index)
			if at_ then
				table.remove(chosen, at_)
				button.BackgroundColor3 = C.bone
				return
			end
			table.insert(chosen, index)
			button.BackgroundColor3 = C.red
			if #chosen == def.MARKED then
				if not ctx.submit(table.clone(chosen)) then
					ctx.hint("Not those five. Remember: the lifted print is mirrored left to right.")
					Common.flash(lifted, false)
					reset()
				end
			end
		end)
		table.insert(buttons, button)
		if index == 1 then
			ctx.first(button)
		end
	end
end
