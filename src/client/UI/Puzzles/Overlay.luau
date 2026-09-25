-- Fingerprint · Overlay: the reference print (pale dots) and a film (red dots) turned and
-- shifted over it. Turn and slide the film until every red dot sits on a pale one.

local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Common)

local C = Kit.color

return function(ctx: Common.Context)
	local def, puzzle = ctx.def, ctx.puzzle
	local grid = def.GRID
	local turns, dx, dy = 0, 0, 0
	local board = Kit.Base.make("Frame", {
		Name = "Board",
		BackgroundColor3 = C.parchment,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.58, 1),
		ClipsDescendants = true,
		Parent = ctx.area,
	})
	Kit.Base.make("UIAspectRatioConstraint", { Parent = board })
	local function at(x: number, y: number): (number, number)
		return (x + 0.5) / grid, (y + 0.5) / grid
	end
	for _, p in ipairs(puzzle.points) do
		local x, y = at(p[1], p[2])
		Common.dot(board, x, y, 16, C.inkDim, 4)
	end
	local film = Kit.frame({ Name = "Film", ZIndex = 5, Parent = board })
	local done = false
	local function draw()
		Kit.clear(film)
		for _, p in ipairs(puzzle.points) do
			local x, y = def.turn(p[1], p[2], puzzle.turns + turns)
			local fx, fy = at(x + puzzle.sx + dx, y + puzzle.sy + dy)
			Common.dot(film, fx, fy, 10, C.red, 6)
		end
		if not done and def.aligned(puzzle, turns, dx, dy) then
			done = true
			ctx.submit({ turns % 4, dx, dy })
		end
	end
	local controls =
		Kit.frame({ Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.38, 1), Parent = ctx.area })
	Kit.grid(controls, UDim2.new(0.5, -6, 0, Kit.Tokens.touch), 6)
	local moves = {
		{
			"Turn",
			function()
				turns = (turns + 1) % 4
			end,
		},
		{
			"Up",
			function()
				dy = math.max(dy - 1, -def.SHIFT * 2)
			end,
		},
		{
			"Left",
			function()
				dx = math.max(dx - 1, -def.SHIFT * 2)
			end,
		},
		{
			"Right",
			function()
				dx = math.min(dx + 1, def.SHIFT * 2)
			end,
		},
		{
			"Down",
			function()
				dy = math.min(dy + 1, def.SHIFT * 2)
			end,
		},
	}
	for index, move in ipairs(moves) do
		local button = Kit.button(
			{ text = move[1], size = "s", Size = UDim2.fromScale(1, 1), LayoutOrder = index, Parent = controls },
			function()
				if not done then
					move[2]()
					draw()
				end
			end
		)
		if index == 1 then
			ctx.first(button)
		end
	end
	draw()
end
