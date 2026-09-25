--!strict
-- Forensics: a word from the Grimoire's page in someone's hand. Every hand slants and sits its
-- letters its own way; pick the sample written by the same hand. Answer: the chosen sample.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Handwriting",
	title = "Handwriting",
	hint = "Pick the sample written by the same hand: the same slant, letter by letter.",
}

Def.WORDS = { "NAMES", "WRITE", "SEALED", "PAGES", "RULES", "QUILL", "OMEN", "TOMB", "RAVEN", "CANDLE" }
Def.SLANTS = { -14, -7, 0, 7, 14 }
Def.RISES = { -4, 0, 4 }

-- A hand: per letter, a slant index and a rise index.
local function hand(length: number, rng: Random)
	local letters = {}
	for i = 1, length do
		letters[i] = { rng:NextInteger(1, #Def.SLANTS), rng:NextInteger(1, #Def.RISES) }
	end
	return letters
end

local function variant(letters, rng: Random)
	local copy = {}
	for i, letter in ipairs(letters) do
		copy[i] = { letter[1], letter[2] }
	end
	for _, index in ipairs(PuzzleKit.pickDistinct(math.min(2, #copy), 1, #copy, rng)) do
		copy[index][1] = (copy[index][1] + rng:NextInteger(1, #Def.SLANTS - 1) - 1) % #Def.SLANTS + 1
	end
	return copy
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local word = Def.WORDS[rng:NextInteger(1, #Def.WORDS)]
	local sample = hand(#word, rng)
	local decoys = { variant(sample, rng), variant(sample, rng), variant(sample, rng) }
	local choices, correct = PuzzleKit.lineup(sample, decoys, rng)
	return { word = word, sample = sample, choices = choices, correct = correct }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, #puzzle.choices) and answer == puzzle.correct
end

function Def.solve(puzzle)
	return puzzle.correct
end

return Def
