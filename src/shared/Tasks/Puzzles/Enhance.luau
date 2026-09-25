--!strict
-- Camera: a grainy still. Move the magnifier over it to see what is there, and tap the
-- figure in the red scarf. Answer: the cell index.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Enhance",
	title = "Enhance",
	hint = "Sweep the magnifier over the still and tap the figure in the red scarf.",
}

Def.COLS, Def.ROWS = 6, 4
-- What can be in a cell (icon names); "" is empty street.
Def.THINGS = { "profile", "rain", "key", "phone", "mail", "clock", "" }

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local count = Def.COLS * Def.ROWS
	local cells = {}
	for i = 1, count do
		cells[i] = Def.THINGS[rng:NextInteger(1, #Def.THINGS)]
	end
	local target = rng:NextInteger(1, count)
	cells[target] = "profile"
	-- A few other figures, without the scarf.
	for _, index in ipairs(PuzzleKit.pickDistinct(3, 1, count, rng)) do
		if index ~= target then
			cells[index] = "profile"
		end
	end
	return { cells = cells, target = target }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, Def.COLS * Def.ROWS) and answer == puzzle.target
end

function Def.solve(puzzle)
	return puzzle.target
end

return Def
