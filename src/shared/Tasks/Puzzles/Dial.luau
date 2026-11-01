--!strict
-- Phone: the burner's call log and a note saying which call to return (the longest, the last, the first unknown
-- caller, the shortest). Find that call in the log and dial its number. Answer: the 11 digits dialled.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Dial",
	title = "Call back",
	hint = "Find the call on the note, then dial it.",
}

Def.ENTRIES = 5
Def.PREFIX = "090"
Def.NAMES = { "Office", "Taxi", "Mika", "Ren", "Hotel", "Aya", "Kenji", "Mom" }
Def.UNKNOWN = "Unknown"
Def.RULES = {
	"Call back the longest call.",
	"Call back the last call.",
	"Call back the first unknown caller.",
	"Call back the shortest call.",
}

local function number(rng: Random): string
	local digits = { Def.PREFIX }
	for _ = 1, 8 do
		table.insert(digits, tostring(rng:NextInteger(0, 9)))
	end
	return table.concat(digits)
end

-- The entry the rule points at.
local function pick(entries, rule: number)
	local best
	for _, entry in ipairs(entries) do
		if rule == 1 then
			if not best or entry.duration > best.duration then
				best = entry
			end
		elseif rule == 2 then
			if not best or entry.time > best.time then
				best = entry
			end
		elseif rule == 3 then
			if entry.name == Def.UNKNOWN and (not best or entry.time < best.time) then
				best = entry
			end
		elseif not best or entry.duration < best.duration then
			best = entry
		end
	end
	return best
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local entries = {}
	local used = {}
	local times = PuzzleKit.pickDistinct(Def.ENTRIES, 0, 179, rng) -- minutes after 21:00
	local durations = PuzzleKit.pickDistinct(Def.ENTRIES, 4, 70, rng) -- in units of 5 s
	local names = PuzzleKit.shuffle(table.clone(Def.NAMES), rng)
	-- (two or three unknown callers, so "the first unknown" means something)
	local unknowns = rng:NextInteger(2, 3)
	for i = 1, Def.ENTRIES do
		local value
		repeat
			value = number(rng)
		until not used[value]
		used[value] = true
		table.insert(entries, {
			number = value,
			name = if i <= unknowns then Def.UNKNOWN else names[i],
			time = 21 * 3600 + times[i] * 60 + rng:NextInteger(0, 59),
			duration = durations[i] * 5 + rng:NextInteger(0, 4),
		})
	end
	PuzzleKit.shuffle(entries, rng)
	local rule = rng:NextInteger(1, #Def.RULES)
	return { entries = entries, rule = rule, number = pick(entries, rule).number }
end

-- "090-1234-5678"
function Def.format(digits: string): string
	local out = string.sub(digits, 1, 3)
	if #digits > 3 then
		out ..= "-" .. string.sub(digits, 4, 7)
	end
	if #digits > 7 then
		out ..= "-" .. string.sub(digits, 8, 11)
	end
	return out
end

-- "3:42"
function Def.duration(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "string" and answer == puzzle.number
end

function Def.solve(puzzle)
	return puzzle.number
end

Def.pick = pick

return Def
