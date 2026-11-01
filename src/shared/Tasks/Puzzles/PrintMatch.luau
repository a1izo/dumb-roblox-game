--!strict
-- Fingerprint: two lifted prints; for each, pick the print card that matches it out of four. The other cards are
-- one feature off (a ridge more or less, the core moved, another scar, an island moved).
-- Answer: the two chosen positions.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "PrintMatch",
	title = "Match the print",
	hint = "Pick the card that matches the lifted print.",
}

Def.ROUNDS = 2
Def.CARDS = 4

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local rounds = {}
	for r = 1, Def.ROUNDS do
		local sample = PuzzleKit.print(rng)
		local taken = { [PuzzleKit.printKey(sample)] = true }
		local decoys = {}
		for _ = 1, Def.CARDS - 1 do
			table.insert(decoys, PuzzleKit.printVariant(sample, rng, taken))
		end
		local choices, correct = PuzzleKit.lineup(sample, decoys, rng)
		rounds[r] = { sample = sample, choices = choices, correct = correct }
	end
	return { rounds = rounds }
end

function Def.check(puzzle, answer): boolean
	if not PuzzleKit.isIntArray(answer, Def.ROUNDS, 1, Def.CARDS) then
		return false
	end
	for r = 1, Def.ROUNDS do
		if answer[r] ~= puzzle.rounds[r].correct then
			return false
		end
	end
	return true
end

function Def.solve(puzzle)
	local answer = {}
	for r, round in ipairs(puzzle.rounds) do
		answer[r] = round.correct
	end
	return answer
end

return Def
