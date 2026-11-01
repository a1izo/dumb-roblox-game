--!strict
-- Camera: six stills from different cameras, seconds apart. Half the cameras keep a 24 hour clock and half a 12 hour
-- one, so the times have to be read, not just compared. Pick them in time order, earliest first.
-- Answer: the six still positions in the order picked.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Timeline",
	title = "Timeline",
	hint = "Pick the stills in order, earliest first.",
}

Def.COUNT = 6

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	-- (late evening, so a 12 hour clock reads PM and the hour has to be turned round)
	local t = rng:NextInteger(20 * 3600, 23 * 3600 - 600)
	local twelve = PuzzleKit.order(Def.COUNT, rng)
	local cams = PuzzleKit.pickDistinct(Def.COUNT, 1, 24, rng)
	local items = {}
	for rank = 1, Def.COUNT do
		-- mostly close together, sometimes over a minute, so seconds and minutes both matter
		t += if rng:NextNumber() < 0.7 then rng:NextInteger(3, 40) else rng:NextInteger(50, 160)
		table.insert(items, { time = t, cam = cams[rank], rank = rank, twelve = twelve[rank] % 2 == 0 })
	end
	return { frames = PuzzleKit.shuffle(items, rng) }
end

function Def.stamp(frame): string
	return PuzzleKit.clock(frame.time, frame.twelve)
end

function Def.check(puzzle, answer): boolean
	if not PuzzleKit.isIntArray(answer, Def.COUNT, 1, Def.COUNT) then
		return false
	end
	for k = 1, Def.COUNT do
		if puzzle.frames[answer[k]].rank ~= k then
			return false
		end
	end
	return true
end

function Def.solve(puzzle)
	local answer = {}
	for position, frame in ipairs(puzzle.frames) do
		answer[frame.rank] = position
	end
	return answer
end

return Def
