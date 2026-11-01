-- Fingerprint / Overlay: the reference print's points in ink on the board, and a clear film over it whose points
-- are red rings, turned and shifted. Turn and slide the film until every ring sits on an ink point.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local T = Kit.Tokens

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local grid = def.GRID
	local limit = def.SHIFT * 2
	local turns, dx, dy = 0, 0, 0

	local board =
		Common.card({ Name = "Board", fill = Common.SHEET, Size = UDim2.fromScale(0.6, 1), Parent = ctx.area })
	Kit.Base.make("UIAspectRatioConstraint", { Parent = board })
	local inner = Kit.Base.make("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.04, 0.04),
		Size = UDim2.fromScale(0.92, 0.92),
		Parent = board,
	})
	for i = 1, grid - 1 do
		Common.rule(inner, UDim2.fromScale(i / grid, 0), UDim2.new(0, 1, 1, 0))
		Common.rule(inner, UDim2.fromScale(0, i / grid), UDim2.new(1, 0, 0, 1))
	end
	local function at(x: number, y: number): (number, number)
		return (x + 0.5) / grid, (y + 0.5) / grid
	end
	for _, p in ipairs(puzzle.points) do
		local x, y = at(p[1], p[2])
		Common.dot(inner, x, y, 0.06, Common.INK, 4)
	end
	local film = Kit.frame({ Name = "Film", ZIndex = 5, Parent = inner })
	local done = false
	local function draw()
		Kit.clear(film)
		local on = 0
		for _, p in ipairs(puzzle.points) do
			local x, y = def.turn(p[1], p[2], puzzle.turns + turns)
			x, y = x + puzzle.sx + dx, y + puzzle.sy + dy
			local fx, fy = at(x, y)
			Common.hoop(film, fx, fy, 24, Common.RED, 6)
			for _, q in ipairs(puzzle.points) do
				if q[1] == x and q[2] == y then
					on += 1
				end
			end
		end
		ctx.hint(string.format("Line the film up. %d of %d points on.", on, #puzzle.points))
		if not done and def.aligned(puzzle, turns, dx, dy) then
			done = true
			ctx.submit({ turns % 4, dx, dy })
		end
	end

	local controls = Kit.frame({
		Name = "Controls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, -16, 1, 0),
		Parent = ctx.area,
	})
	Common.text(controls, "Turn it first, then slide it.", { color = Common.GREY, Size = UDim2.new(1, 0, 0, 30) })
	local pad = Kit.frame({
		Name = "Pad",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(T.touch * 3 + 24, T.touch * 3 + 24),
		Parent = controls,
	})
	local function move(text: string, col: number, row: number, act: () -> ()): TextButton
		return Kit.button({
			text = text,
			variant = if text == "Turn" then "primary" else "secondary",
			size = "s",
			Size = UDim2.fromOffset(if text == "Turn" then T.touch * 3 + 24 else T.touch, T.touch),
			Position = UDim2.fromOffset(col * (T.touch + 12), row * (T.touch + 12)),
			Parent = pad,
		}, function()
			if not done and not ctx.busy() then
				act()
				draw()
			end
		end)
	end
	local turn = move("Turn", 0, 3, function()
		turns = (turns + 1) % 4
	end)
	move("^", 1, 0, function()
		dy = math.max(dy - 1, -limit)
	end)
	move("<", 0, 1, function()
		dx = math.max(dx - 1, -limit)
	end)
	move(">", 2, 1, function()
		dx = math.min(dx + 1, limit)
	end)
	move("v", 1, 2, function()
		dy = math.min(dy + 1, limit)
	end)
	pad.Size = UDim2.fromOffset(T.touch * 3 + 24, T.touch * 4 + 36)
	ctx.first(turn)
	draw()
end
