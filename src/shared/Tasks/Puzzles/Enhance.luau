--!strict
-- Camera: a grainy still of a street with ten people in it, and the witness's description (hat or not, a light
-- or dark coat, what they carry). Exactly one person fits all three; several fit two. Pick them.
-- Answer: the person's position.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Enhance",
	title = "Enhance",
	hint = "Find the person the witness saw.",
}

Def.COLS, Def.ROWS = 5, 2
-- Each person: { hat, coat, carry }. The words are the witness's.
Def.HAT = { "No hat", "Hat" }
Def.COAT = { "Light coat", "Dark coat" }
Def.CARRY = { "Nothing in hand", "Bag", "Umbrella" }
Def.NEAR = 4 -- people who fit two of the three, at least

local function same(a, b): boolean
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local function fits(a, b): number
	return (if a[1] == b[1] then 1 else 0) + (if a[2] == b[2] then 1 else 0) + (if a[3] == b[3] then 1 else 0)
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local count = Def.COLS * Def.ROWS
	local wanted = { rng:NextInteger(1, #Def.HAT), rng:NextInteger(1, #Def.COAT), rng:NextInteger(1, #Def.CARRY) }
	local people = {}
	for i = 1, count - 1 do
		local person
		repeat
			person = { rng:NextInteger(1, #Def.HAT), rng:NextInteger(1, #Def.COAT), rng:NextInteger(1, #Def.CARRY) }
			-- (the first few are near misses: one feature off)
			local ok = not same(person, wanted) and (i > Def.NEAR or fits(person, wanted) == 2)
		until ok
		person[4] = if rng:NextNumber() < 0.5 then 1 else -1 -- which way they face (only looks)
		people[i] = person
	end
	local target = rng:NextInteger(1, count)
	local person = table.clone(wanted)
	person[4] = if rng:NextNumber() < 0.5 then 1 else -1
	table.insert(people, target, person)
	PuzzleKit.shuffle(people, rng)
	for i, p in ipairs(people) do
		if same(p, wanted) then
			target = i
		end
	end
	return { people = people, wanted = wanted, target = target }
end

-- The witness's description, one line per feature.
function Def.describe(puzzle): { string }
	local w = puzzle.wanted
	return { Def.HAT[w[1]], Def.COAT[w[2]], Def.CARRY[w[3]] }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, Def.COLS * Def.ROWS) and answer == puzzle.target
end

function Def.solve(puzzle)
	return puzzle.target
end

Def.fits = fits

return Def
