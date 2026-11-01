--!strict
-- Forensics: the coroner's report lists three marks on the body ("Bruise, left forearm."). Pick each on the chart.
-- Left and right are the body's own, and the chart shows the body from the front or from the back, so the sides
-- have to be worked out. Answer: the three region ids.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Autopsy",
	title = "Autopsy chart",
	hint = "Mark the three spots from the report.",
}

-- Body regions and where they are on a chart seen from the front (x, y, w, h as fractions of the chart). From the
-- front the body's own left is on the right of the chart; from the back it is on the left (Def.rect mirrors).
Def.REGIONS = {
	{ id = 1, name = "head", rect = { 0.4, 0.0, 0.2, 0.13 } },
	{ id = 2, name = "neck", rect = { 0.455, 0.13, 0.09, 0.04 } },
	{ id = 3, name = "chest", rect = { 0.33, 0.17, 0.34, 0.16 } },
	{ id = 4, name = "stomach", rect = { 0.35, 0.33, 0.3, 0.14 } },
	{ id = 5, name = "right upper arm", rect = { 0.2, 0.18, 0.12, 0.15 } },
	{ id = 6, name = "left upper arm", rect = { 0.68, 0.18, 0.12, 0.15 } },
	{ id = 7, name = "right forearm", rect = { 0.17, 0.34, 0.12, 0.15 } },
	{ id = 8, name = "left forearm", rect = { 0.71, 0.34, 0.12, 0.15 } },
	{ id = 9, name = "right hand", rect = { 0.15, 0.5, 0.12, 0.07 } },
	{ id = 10, name = "left hand", rect = { 0.73, 0.5, 0.12, 0.07 } },
	{ id = 11, name = "right thigh", rect = { 0.35, 0.48, 0.14, 0.24 } },
	{ id = 12, name = "left thigh", rect = { 0.51, 0.48, 0.14, 0.24 } },
	{ id = 13, name = "right shin", rect = { 0.36, 0.73, 0.12, 0.25 } },
	{ id = 14, name = "left shin", rect = { 0.52, 0.73, 0.12, 0.25 } },
}
Def.MARKS = 3
Def.WOUNDS = { "Bruise", "Cut", "Burn", "Puncture" }
-- regions with a side (left or right), where the view of the chart matters
local SIDED = { 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local marks
	repeat
		marks = PuzzleKit.pickDistinct(Def.MARKS, 1, #Def.REGIONS, rng)
		local sided = 0
		for _, id in ipairs(marks) do
			if table.find(SIDED, id) then
				sided += 1
			end
		end
	until sided >= 2
	local wounds = {}
	for i = 1, Def.MARKS do
		wounds[i] = rng:NextInteger(1, #Def.WOUNDS)
	end
	return { marks = marks, wounds = wounds, back = rng:NextNumber() < 0.5 }
end

-- The report's lines.
function Def.report(puzzle): { string }
	local lines = {}
	for i, id in ipairs(puzzle.marks) do
		table.insert(lines, Def.WOUNDS[puzzle.wounds[i]] .. ", " .. Def.REGIONS[id].name .. ".")
	end
	return lines
end

-- Where a region is drawn on this chart.
function Def.rect(puzzle, id: number): { number }
	local r = Def.REGIONS[id].rect
	if puzzle.back then
		return { 1 - r[1] - r[3], r[2], r[3], r[4] }
	end
	return r
end

function Def.check(puzzle, answer): boolean
	return PuzzleKit.isIntArray(answer, Def.MARKS, 1, #Def.REGIONS) and PuzzleKit.sameSet(answer, puzzle.marks)
end

function Def.solve(puzzle)
	return table.clone(puzzle.marks)
end

return Def
