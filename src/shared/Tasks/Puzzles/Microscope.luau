--!strict
-- Forensics: a fibre from the page under the microscope. Bring it into focus with the focus
-- and light dials, then pick the matching fibre. Answer: { focus, light, choice }.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Microscope",
	title = "Microscope",
	hint = "Turn focus and light until the fibre is sharp, then pick the matching fibre.",
}

Def.MAX = 10
Def.START = 5
Def.KINKS = 6 -- a fibre is drawn as this many bends

local function fibre(rng: Random)
	local bends = {}
	for i = 1, Def.KINKS do
		bends[i] = rng:NextInteger(-3, 3)
	end
	return bends
end

local function variant(bends, rng: Random)
	local copy = table.clone(bends)
	for _, index in ipairs(PuzzleKit.pickDistinct(2, 1, #copy, rng)) do
		local shift = rng:NextInteger(2, 3)
		copy[index] = if copy[index] >= 0 then copy[index] - shift else copy[index] + shift
	end
	return copy
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local focus, light
	repeat
		focus = rng:NextInteger(0, Def.MAX)
		light = rng:NextInteger(0, Def.MAX)
	until math.abs(focus - Def.START) + math.abs(light - Def.START) >= 3
	local sample = fibre(rng)
	local choices, correct = PuzzleKit.lineup(sample, { variant(sample, rng), variant(sample, rng) }, rng)
	return { focus = focus, light = light, sample = sample, choices = choices, correct = correct }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isIntArray(answer, 3, 0, Def.MAX)
		and answer[1] == puzzle.focus
		and answer[2] == puzzle.light
		and answer[3] == puzzle.correct
end

function Def.solve(puzzle)
	return { puzzle.focus, puzzle.light, puzzle.correct }
end

return Def
