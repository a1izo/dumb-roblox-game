--!strict
-- Forensics: the coroner's report lists three marks on the body. Tap each one on the chart.
-- Answer: the three region ids.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Autopsy",
	title = "Autopsy chart",
	hint = "Mark the three places the coroner's report lists on the body chart.",
}

-- Body regions and where they are on the chart (x, y, w, h as fractions of the chart). "Left"
-- is the body's own left, which is on the right of a chart that faces you.
Def.REGIONS = {
	{ id = 1, name = "head", rect = { 0.4, 0.02, 0.2, 0.14 } },
	{ id = 2, name = "neck", rect = { 0.44, 0.16, 0.12, 0.05 } },
	{ id = 3, name = "chest", rect = { 0.34, 0.21, 0.32, 0.16 } },
	{ id = 4, name = "stomach", rect = { 0.36, 0.37, 0.28, 0.13 } },
	{ id = 5, name = "right arm", rect = { 0.2, 0.21, 0.13, 0.26 } },
	{ id = 6, name = "left arm", rect = { 0.67, 0.21, 0.13, 0.26 } },
	{ id = 7, name = "right hand", rect = { 0.17, 0.47, 0.14, 0.08 } },
	{ id = 8, name = "left hand", rect = { 0.69, 0.47, 0.14, 0.08 } },
	{ id = 9, name = "right leg", rect = { 0.36, 0.5, 0.13, 0.46 } },
	{ id = 10, name = "left leg", rect = { 0.51, 0.5, 0.13, 0.46 } },
}
Def.MARKS = 3

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	return { marks = PuzzleKit.pickDistinct(Def.MARKS, 1, #Def.REGIONS, rng) }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isIntArray(answer, Def.MARKS, 1, #Def.REGIONS) and PuzzleKit.sameSet(answer, puzzle.marks)
end

function Def.solve(puzzle)
	return table.clone(puzzle.marks)
end

return Def
