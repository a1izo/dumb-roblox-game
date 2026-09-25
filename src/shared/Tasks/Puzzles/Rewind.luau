--!strict
-- Camera: scrub the tape and stop on the frame where the figure stands in the doorway.
-- Answer: the frame number.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Rewind",
	title = "Rewind the tape",
	hint = "Scrub the tape to the frame where the figure stands in the lit doorway.",
}

Def.FRAMES = 24

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	return {
		door = rng:NextInteger(22, 78) / 100, -- across the picture, 0..1
		target = rng:NextInteger(4, Def.FRAMES - 3),
		step = rng:NextInteger(26, 40) / 1000 * (if rng:NextNumber() < 0.5 then -1 else 1),
	}
end

-- Where the figure is (0..1 across) on a frame.
function Def.figureAt(puzzle, frame: number): number
	return puzzle.door + (frame - puzzle.target) * puzzle.step
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, Def.FRAMES) and answer == puzzle.target
end

function Def.solve(puzzle)
	return puzzle.target
end

return Def
