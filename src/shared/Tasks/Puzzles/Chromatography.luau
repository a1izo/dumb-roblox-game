--!strict
-- Forensics: the pigment from the Grimoire's page, separated into coloured bands. Pick the pen
-- whose pigment shows the same bands. Answer: the chosen pen. (No "ink" in its words: the owner, 2026-10-24.)

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Chromatography",
	title = "Pen chromatography",
	hint = "Pick the pen whose bands match the sample.",
}

-- Band tones, darkest first (the view draws them in the ink ramp's greys).
Def.TONES = 4
Def.BANDS = 4
Def.HEIGHTS = 9

local function strip(rng: Random)
	local bands = {}
	for i, height in ipairs(PuzzleKit.pickDistinct(Def.BANDS, 1, Def.HEIGHTS, rng)) do
		bands[i] = { rng:NextInteger(1, Def.TONES), height }
	end
	return bands
end

local function key(bands): string
	local parts = {}
	for _, band in ipairs(bands) do
		table.insert(parts, band[1] .. ":" .. band[2])
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function variant(bands, rng: Random)
	local copy = {}
	for i, band in ipairs(bands) do
		copy[i] = { band[1], band[2] }
	end
	local index = rng:NextInteger(1, #copy)
	if rng:NextNumber() < 0.5 then
		copy[index][1] = (copy[index][1] + rng:NextInteger(1, Def.TONES - 1) - 1) % Def.TONES + 1
		return copy
	end
	-- (a band moved one step up or down, onto a height no other band has)
	local used = {}
	for _, band in ipairs(copy) do
		used[band[2]] = true
	end
	for _, step in ipairs(if rng:NextNumber() < 0.5 then { 1, -1, 2, -2 } else { -1, 1, -2, 2 }) do
		local height = copy[index][2] + step
		if height >= 1 and height <= Def.HEIGHTS and not used[height] then
			copy[index][2] = height
			return copy
		end
	end
	copy[index][1] = copy[index][1] % Def.TONES + 1
	return copy
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local sample = strip(rng)
	local taken = { [key(sample)] = true }
	local decoys = {}
	while #decoys < 3 do
		local candidate = variant(sample, rng)
		if not taken[key(candidate)] then
			taken[key(candidate)] = true
			table.insert(decoys, candidate)
		end
	end
	local pens, correct = PuzzleKit.lineup(sample, decoys, rng)
	return { sample = sample, pens = pens, correct = correct }
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isInt(answer, 1, #puzzle.pens) and answer == puzzle.correct
end

function Def.solve(puzzle)
	return puzzle.correct
end

return Def
