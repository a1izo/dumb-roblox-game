--!strict
-- Forensics: the ink from the Grimoire's page, separated into coloured bands. Pick the pen
-- whose ink shows the same bands. Answer: the chosen pen.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Chromatography",
	title = "Ink chromatography",
	hint = "Pick the pen whose ink separates into the same bands as the sample.",
}

-- Band colours (the view draws them).
Def.INKS = {
	Color3.fromRGB(40, 40, 60),
	Color3.fromRGB(140, 20, 30),
	Color3.fromRGB(40, 80, 170),
	Color3.fromRGB(110, 60, 150),
	Color3.fromRGB(40, 120, 90),
	Color3.fromRGB(180, 120, 40),
}
Def.BANDS = 4
Def.HEIGHTS = 9

local function strip(rng: Random)
	local bands = {}
	for i = 1, Def.BANDS do
		bands[i] = { rng:NextInteger(1, #Def.INKS), rng:NextInteger(1, Def.HEIGHTS) }
	end
	return bands
end

local function variant(bands, rng: Random)
	local copy = {}
	for i, band in ipairs(bands) do
		copy[i] = { band[1], band[2] }
	end
	local index = rng:NextInteger(1, #copy)
	if rng:NextNumber() < 0.5 then
		copy[index][1] = (copy[index][1] + rng:NextInteger(1, #Def.INKS - 1) - 1) % #Def.INKS + 1
	else
		copy[index][2] = (copy[index][2] + rng:NextInteger(1, Def.HEIGHTS - 1) - 1) % Def.HEIGHTS + 1
	end
	return copy
end

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local sample = strip(rng)
	local decoys = { variant(sample, rng), variant(sample, rng), variant(sample, rng) }
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
