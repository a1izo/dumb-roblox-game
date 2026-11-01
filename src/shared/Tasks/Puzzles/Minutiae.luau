--!strict
-- Fingerprint: the report marks five points on the file print. Pick the same five points on the lifted print,
-- which is its mirror image (a print on glass is reversed). Answer: five point indexes.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Minutiae",
	title = "Minutiae",
	hint = "Pick the five marked points. The lift is mirrored.",
}

Def.GRID = 8
Def.POINTS = 12
Def.MARKED = 5

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local points = {}
	for _, cell in ipairs(PuzzleKit.pickDistinct(Def.POINTS, 0, Def.GRID * Def.GRID - 1, rng)) do
		table.insert(points, { cell % Def.GRID, cell // Def.GRID })
	end
	local marked = PuzzleKit.pickDistinct(Def.MARKED, 1, Def.POINTS, rng)
	table.sort(marked)
	-- (the ridges drawn under the points: only looks)
	return { points = points, marked = marked, print = PuzzleKit.print(rng) }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isIntArray(answer, Def.MARKED, 1, Def.POINTS) and PuzzleKit.sameSet(answer, puzzle.marked)
end

function Def.solve(puzzle)
	return table.clone(puzzle.marked)
end

return Def
