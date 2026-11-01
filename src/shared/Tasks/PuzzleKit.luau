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
	-- the least time anyone could really solve it in, seconds (PuzzleSet.MIN_SECONDS when not given): the server refuses
	-- a quicker answer (an exploit's instant solve)
	minSeconds: number?,
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

-- Fingerprints ---------------------------------------------------------------------------------
-- A print is a few features the views draw (UI/Puzzles/Common.print): the pattern (1 whorl, 2 loop, 3 arch), how
-- many ridges, where its core sits (1 left, 2 middle, 3 right), a scar across it (0 none, else one of four angles)
-- and three islands (small ridge dots) on a 5 x 5 grid.

PuzzleKit.PRINT = { KINDS = 3, MIN_RINGS = 4, MAX_RINGS = 6, CORES = 3, SCARS = 4, GRID = 5, DOTS = 3 }

export type Print = { kind: number, rings: number, core: number, scar: number, dots: { { number } } }

function PuzzleKit.print(rng: Random): Print
	local P = PuzzleKit.PRINT
	local dots = {}
	for _, cell in ipairs(PuzzleKit.pickDistinct(P.DOTS, 0, P.GRID * P.GRID - 1, rng)) do
		table.insert(dots, { cell % P.GRID, cell // P.GRID })
	end
	return {
		kind = rng:NextInteger(1, P.KINDS),
		rings = rng:NextInteger(P.MIN_RINGS, P.MAX_RINGS),
		core = rng:NextInteger(1, P.CORES),
		scar = rng:NextInteger(0, P.SCARS),
		dots = dots,
	}
end

-- A key that is the same for two prints exactly when they look the same.
function PuzzleKit.printKey(p: Print): string
	local cells = {}
	for _, dot in ipairs(p.dots) do
		table.insert(cells, dot[2] * PuzzleKit.PRINT.GRID + dot[1])
	end
	table.sort(cells)
	return string.format("%d/%d/%d/%d/%s", p.kind, p.rings, p.core, p.scar, table.concat(cells, ","))
end

local function copyPrint(p: Print): Print
	local dots = {}
	for i, dot in ipairs(p.dots) do
		dots[i] = { dot[1], dot[2] }
	end
	return { kind = p.kind, rings = p.rings, core = p.core, scar = p.scar, dots = dots }
end

-- The print with exactly one feature changed (a ridge more or less, the core moved, another scar, or one island
-- moved a cell), and none of the prints already in `taken` (keys from printKey; the new one is added).
function PuzzleKit.printVariant(p: Print, rng: Random, taken: { [string]: boolean }): Print
	local P = PuzzleKit.PRINT
	for _ = 1, 50 do
		local copy = copyPrint(p)
		local which = rng:NextInteger(1, 4)
		if which == 1 then
			copy.rings = if copy.rings == P.MIN_RINGS
				then copy.rings + 1
				elseif copy.rings == P.MAX_RINGS then copy.rings - 1
				else copy.rings + (if rng:NextNumber() < 0.5 then -1 else 1)
		elseif which == 2 then
			copy.core = (copy.core + rng:NextInteger(1, P.CORES - 1) - 1) % P.CORES + 1
		elseif which == 3 then
			copy.scar = (copy.scar + rng:NextInteger(1, P.SCARS)) % (P.SCARS + 1)
		else
			local dot = copy.dots[rng:NextInteger(1, #copy.dots)]
			local moves = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
			PuzzleKit.shuffle(moves, rng)
			for _, move in ipairs(moves) do
				local x, y = dot[1] + move[1], dot[2] + move[2]
				local free = x >= 0 and y >= 0 and x < P.GRID and y < P.GRID
				for _, other in ipairs(copy.dots) do
					if other[1] == x and other[2] == y then
						free = false
					end
				end
				if free then
					dot[1], dot[2] = x, y
					break
				end
			end
		end
		local key = PuzzleKit.printKey(copy)
		if not taken[key] then
			taken[key] = true
			return copy
		end
	end
	error("no print variant left")
end

-- A clock time (seconds into the day) as 24 h "22:41:07", or 12 h "10:41:07 PM".
function PuzzleKit.clock(seconds: number, twelve: boolean?): string
	local h, m, s = (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60
	if twelve then
		local hour = h % 12
		return string.format("%d:%02d:%02d %s", if hour == 0 then 12 else hour, m, s, if h < 12 then "AM" else "PM")
	end
	return string.format("%02d:%02d:%02d", h, m, s)
end

return PuzzleKit
