--!strict
-- Camera: a rolling, tearing feed. Turn the vertical hold and tracking dials until the
-- picture locks. Answer: { hold, tracking }.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "VSync",
	title = "Vertical hold",
	hint = "Turn the two dials until the rolling picture locks still.",
}

Def.MAX = 10
Def.START = 5

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local hold, tracking
	repeat
		hold = rng:NextInteger(0, Def.MAX)
		tracking = rng:NextInteger(0, Def.MAX)
	until math.abs(hold - Def.START) + math.abs(tracking - Def.START) >= 3
	return { hold = hold, tracking = tracking }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isIntArray(answer, 2, 0, Def.MAX) and answer[1] == puzzle.hold and answer[2] == puzzle.tracking
end

function Def.solve(puzzle)
	return { puzzle.hold, puzzle.tracking }
end

return Def
