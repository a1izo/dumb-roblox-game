--!strict
-- Phone: two call logs, one number in both. Find it. Some numbers differ by a single digit.
-- Answer: the number.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "CallLog",
	title = "Call logs",
	hint = "One number appears in both call logs. Tap it.",
}

Def.PER_LOG = 6

local function number(rng: Random): string
	local digits = { "0", "9", "0" }
	for _ = 1, 8 do
		table.insert(digits, tostring(rng:NextInteger(0, 9)))
	end
	return table.concat(digits)
end

-- The number with one digit (after the prefix) changed.
local function nearly(value: string, rng: Random): string
	local index = rng:NextInteger(4, #value)
	local digit = tonumber(string.sub(value, index, index)) :: number
	local other = (digit + rng:NextInteger(1, 9)) % 10
	return string.sub(value, 1, index - 1) .. other .. string.sub(value, index + 1)
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local used = {}
	local function fresh(candidate: string): string
		while used[candidate] do
			candidate = number(rng)
		end
		used[candidate] = true
		return candidate
	end
	local shared = fresh(number(rng))
	local left, right = { shared }, { shared }
	-- A near miss of the shared number on the right, to punish a quick glance.
	table.insert(right, fresh(nearly(shared, rng)))
	while #left < Def.PER_LOG do
		table.insert(left, fresh(number(rng)))
	end
	while #right < Def.PER_LOG do
		local base = left[rng:NextInteger(2, #left)]
		table.insert(right, fresh(if rng:NextNumber() < 0.5 then nearly(base, rng) else number(rng)))
	end
	return { left = PuzzleKit.shuffle(left, rng), right = PuzzleKit.shuffle(right, rng), shared = shared }
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "string" and answer == puzzle.shared
end

function Def.solve(puzzle)
	return puzzle.shared
end

return Def
