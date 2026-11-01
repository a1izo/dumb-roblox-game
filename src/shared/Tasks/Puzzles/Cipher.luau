--!strict
-- Phone: an intercepted text in a shifted alphabet ("MEET AT THE HARBOR"). Turn the cipher wheel until the text
-- reads, then pick the place. Every place offered has the same length, so it can't be guessed by its shape.
-- Answer: the place.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Cipher",
	title = "Cipher wheel",
	hint = "Turn the wheel until the text reads, then pick the place.",
}

Def.PLACES = {
	"HARBOR",
	"CHAPEL",
	"BRIDGE",
	"MARKET",
	"TUNNEL",
	"GARAGE",
	"TEMPLE",
	"GARDEN",
	"CINEMA",
	"OFFICE",
	"CORNER",
	"PALACE",
	"SCHOOL",
	"CASTLE",
	"ISLAND",
}
Def.OPTIONS = 4
Def.MESSAGE = "MEET AT THE %s"

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
	local picks = PuzzleKit.pickDistinct(Def.OPTIONS, 1, #Def.PLACES, rng)
	local word = Def.PLACES[picks[1]]
	local options = {}
	for _, index in ipairs(picks) do
		table.insert(options, Def.PLACES[index])
	end
	local key = rng:NextInteger(3, 23)
	return {
		word = word,
		key = key,
		encoded = Def.shift(string.format(Def.MESSAGE, word), key),
		options = PuzzleKit.shuffle(options, rng),
	}
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "string" and answer == puzzle.word
end

function Def.solve(puzzle)
	return puzzle.word
end

return Def
