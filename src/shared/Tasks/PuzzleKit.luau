--!strict
-- Helpers shared by the puzzle definitions in Tasks/Puzzles. A puzzle is built only from its
-- seed (Random is the same on the server and every client), and answers come from clients, so
-- every check treats them as untrusted: wrong types just fail.

local PuzzleKit = {}

export type Def = {
	id: string,
	title: string, -- shown on the task window
	hint: string, -- one line on what to do
	generate: (seed: number) -> any,
	check: (puzzle: any, answer: any) -> boolean,
	solve: (puzzle: any) -> any, -- a correct answer (bots and specs)
}

function PuzzleKit.rng(seed: number): Random
	return Random.new(seed)
end

function PuzzleKit.shuffle<T>(list: { T }, rng: Random): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- 1..n in a random order.
function PuzzleKit.order(n: number, rng: Random): { number }
	local list = {}
	for i = 1, n do
		list[i] = i
	end
	return PuzzleKit.shuffle(list, rng)
end

function PuzzleKit.isInt(value: any, lo: number, hi: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= lo and value <= hi
end

-- An array of exactly n integers in lo..hi.
function PuzzleKit.isIntArray(value: any, n: number, lo: number, hi: number): boolean
	if type(value) ~= "table" or #value ~= n then
		return false
	end
	for i = 1, n do
		if not PuzzleKit.isInt(value[i], lo, hi) then
			return false
		end
	end
	return true
end

-- The same numbers, in any order, without repeats.
function PuzzleKit.sameSet(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	local seen = {}
	for _, v in ipairs(a) do
		if seen[v] then
			return false
		end
		seen[v] = true
	end
	for _, v in ipairs(b) do
		if not seen[v] then
			return false
		end
	end
	return true
end

-- n distinct integers in lo..hi.
function PuzzleKit.pickDistinct(n: number, lo: number, hi: number, rng: Random): { number }
	local pool = {}
	for v = lo, hi do
		table.insert(pool, v)
	end
	PuzzleKit.shuffle(pool, rng)
	return table.move(pool, 1, n, 1, {})
end

-- Random bits (0/1) of length n.
function PuzzleKit.bits(n: number, rng: Random): { number }
	local out = {}
	for i = 1, n do
		out[i] = if rng:NextNumber() < 0.5 then 1 else 0
	end
	return out
end

-- A copy of bits with `flips` distinct positions flipped.
function PuzzleKit.flipped(bits: { number }, flips: number, rng: Random): { number }
	local copy = table.clone(bits)
	for _, index in ipairs(PuzzleKit.pickDistinct(flips, 1, #bits, rng)) do
		copy[index] = 1 - copy[index]
	end
	return copy
end

function PuzzleKit.equalArrays(a: { any }, b: { any }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- A shuffled list of the target and decoys; returns the list and the target's position.
function PuzzleKit.lineup<T>(target: T, decoys: { T }, rng: Random): ({ T }, number)
	local items = { target }
	for _, decoy in ipairs(decoys) do
		table.insert(items, decoy)
	end
	local positions = PuzzleKit.order(#items, rng)
	local out = {}
	local correct = 1
	for position, index in ipairs(positions) do
		out[position] = items[index]
		if index == 1 then
			correct = position
		end
	end
	return out, correct
end

return PuzzleKit
