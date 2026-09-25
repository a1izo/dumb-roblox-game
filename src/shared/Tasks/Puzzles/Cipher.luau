--!strict
-- Phone: an intercepted text in a shifted alphabet. Turn the cipher wheel until it reads, then
-- pick the word. Answer: the word.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Cipher",
	title = "Cipher wheel",
	hint = "Turn the wheel until the intercepted text reads, then pick the word.",
}

Def.WORDS = {
	"ARCHIVE",
	"LANTERN",
	"HARBOR",
	"LEDGER",
	"STATION",
	"CANDLE",
	"SHADOW",
	"MIDNIGHT",
	"ORCHARD",
	"TUNNEL",
	"RAVEN",
	"VIOLET",
	"MARKET",
	"CHAPEL",
	"BRIDGE",
	"WINTER",
}

-- Shifts every capital letter `shift` places along the alphabet.
function Def.shift(text: string, shift: number): string
	return (
		string.gsub(text, "%u", function(letter: string): string
			return string.char((string.byte(letter) - 65 + shift) % 26 + 65)
		end)
	)
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local picks = PuzzleKit.pickDistinct(4, 1, #Def.WORDS, rng)
	local word = Def.WORDS[picks[1]]
	local options = {}
	for _, index in ipairs(picks) do
		table.insert(options, Def.WORDS[index])
	end
	local key = rng:NextInteger(3, 22)
	return { word = word, key = key, encoded = Def.shift(word, key), options = PuzzleKit.shuffle(options, rng) }
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "string" and answer == puzzle.word
end

function Def.solve(puzzle)
	return puzzle.word
end

return Def
