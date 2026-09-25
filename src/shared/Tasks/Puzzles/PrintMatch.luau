--!strict
-- Fingerprint: three samples; each time pick the print that matches, out of four.
-- Answer: the three chosen positions.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "PrintMatch",
	title = "Match the print",
	hint = "Pick the print that matches the sample. Three samples.",
}

Def.ROUNDS = 3

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local rounds = {}
	for r = 1, Def.ROUNDS do
		local sample = PuzzleKit.bits(16, rng)
		local decoys = {}
		for _ = 1, 3 do
			table.insert(decoys, PuzzleKit.flipped(sample, 3, rng))
		end
		local choices, correct = PuzzleKit.lineup(sample, decoys, rng)
		rounds[r] = { sample = sample, choices = choices, correct = correct }
	end
	return { rounds = rounds }
end

function Def.check(puzzle, answer): boolean
	if not PuzzleKit.isIntArray(answer, Def.ROUNDS, 1, 4) then
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
