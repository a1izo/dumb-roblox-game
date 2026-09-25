--!strict
-- Fingerprint: a clear film with a print lies over the reference, turned and shifted. Turn and
-- slide it until every point sits on the reference. Answer: { turns, dx, dy } applied to it.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Overlay",
	title = "Overlay",
	hint = "Turn and slide the film until its points sit on the reference print.",
}

Def.GRID = 7 -- points live on a GRID x GRID board, centred at (3, 3)
Def.SHIFT = 2 -- the film starts up to this far off in each direction
Def.POINTS = 8

-- Turns a point (x, y) by quarter turns about the board's centre.
function Def.turn(x: number, y: number, turns: number): (number, number)
	local c = (Def.GRID - 1) / 2
	local dx, dy = x - c, y - c
	for _ = 1, turns % 4 do
		dx, dy = -dy, dx
	end
	return dx + c, dy + c
end

local function key(x: number, y: number): string
	return x .. ":" .. y
end

-- True when some other turn and shift would also line the points up.
local function ambiguous(points): boolean
	local set = {}
	for _, p in ipairs(points) do
		set[key(p[1], p[2])] = true
	end
	for turns = 0, 3 do
		for sx = -4, 4 do
			for sy = -4, 4 do
				if turns ~= 0 or sx ~= 0 or sy ~= 0 then
					local all = true
					for _, p in ipairs(points) do
						local x, y = Def.turn(p[1], p[2], turns)
						if not set[key(x + sx, y + sy)] then
							all = false
							break
						end
					end
					if all then
						return true
					end
				end
			end
		end
	end
	return false
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local points
	repeat
		points = {}
		for _, cell in ipairs(PuzzleKit.pickDistinct(Def.POINTS, 0, Def.GRID * Def.GRID - 1, rng)) do
			table.insert(points, { cell % Def.GRID, cell // Def.GRID })
		end
	until not ambiguous(points)
	local turns, sx, sy
	repeat
		turns = rng:NextInteger(0, 3)
		sx = rng:NextInteger(-Def.SHIFT, Def.SHIFT)
		sy = rng:NextInteger(-Def.SHIFT, Def.SHIFT)
	until turns ~= 0 or sx ~= 0 or sy ~= 0
	return { points = points, turns = turns, sx = sx, sy = sy }
end

-- Lined up when the player's turns undo the film's and the shifts cancel.
function Def.aligned(puzzle, turns: number, dx: number, dy: number): boolean
	return (puzzle.turns + turns) % 4 == 0 and puzzle.sx + dx == 0 and puzzle.sy + dy == 0
end

function Def.check(puzzle, answer): boolean
	if
		type(answer) ~= "table"
		or not PuzzleKit.isInt(answer[1], 0, 3)
		or not PuzzleKit.isInt(answer[2], -Def.SHIFT * 2, Def.SHIFT * 2)
		or not PuzzleKit.isInt(answer[3], -Def.SHIFT * 2, Def.SHIFT * 2)
	then
		return false
	end
	return Def.aligned(puzzle, answer[1], answer[2], answer[3])
end

function Def.solve(puzzle)
	return { (4 - puzzle.turns) % 4, -puzzle.sx, -puzzle.sy }
end

return Def
