--!strict
-- Fingerprint: brush the dust off the glass to bring up a print, then pick the card that matches it. The other
-- cards are one feature off, so most of the print has to show first. Answer: the chosen card.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Dust",
	title = "Dust and lift",
	hint = "Brush off the dust, then pick the matching card.",
}

Def.SIZE = 8 -- the dust is SIZE x SIZE patches
Def.REVEAL = 0.75 -- how much of the glass must be brushed before the cards can be picked
Def.CARDS = 3

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local print_ = PuzzleKit.print(rng)
	local taken = { [PuzzleKit.printKey(print_)] = true }
	local decoys = {}
	for _ = 1, Def.CARDS - 1 do
		table.insert(decoys, PuzzleKit.printVariant(print_, rng, taken))
	end
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
