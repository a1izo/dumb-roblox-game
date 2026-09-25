--!strict
-- Phone: dial the number from the call log. Answer: the digits typed.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Dial",
	title = "Dial the number",
	hint = "Dial the number from the call log.",
}

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local digits = { "0", "9", "0" }
	for _ = 1, 8 do
		table.insert(digits, tostring(rng:NextInteger(0, 9)))
	end
	return { number = table.concat(digits) }
end

-- "090-1234-5678"
function Def.format(digits: string): string
	return string.sub(digits, 1, 3) .. "-" .. string.sub(digits, 4, 7) .. "-" .. string.sub(digits, 8, 11)
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "string" and answer == puzzle.number
end

function Def.solve(puzzle)
	return puzzle.number
end

return Def
