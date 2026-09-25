--!strict
-- Fingerprint: brush the dust off the glass to bring up a print, then pick the matching card.
-- Answer: the chosen card.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Dust",
	title = "Dust and lift",
	hint = "Brush the dust away to reveal the print, then pick the card that matches.",
}

Def.SIZE = 5 -- the print is SIZE x SIZE cells
Def.REVEAL = 0.8 -- how much of the glass must be brushed before the cards can be picked

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local print_ = PuzzleKit.bits(Def.SIZE * Def.SIZE, rng)
	local decoys = { PuzzleKit.flipped(print_, 4, rng), PuzzleKit.flipped(print_, 4, rng) }
	local cards, correct = PuzzleKit.lineup(print_, decoys, rng)
	return { print = print_, cards = cards, correct = correct }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, #puzzle.cards) and answer == puzzle.correct
end

function Def.solve(puzzle)
	return puzzle.correct
end

return Def
