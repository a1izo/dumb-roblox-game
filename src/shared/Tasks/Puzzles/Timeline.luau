--!strict
-- Camera: six feeds with timestamps; tap them in time order, earliest first.
-- Answer: the six feed positions in the order tapped.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Timeline",
	title = "Timeline",
	hint = "Tap the camera feeds in time order, earliest first.",
}

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local t = rng:NextInteger(20 * 3600, 23 * 3600)
	local items = {}
	for rank = 1, 6 do
		t += rng:NextInteger(20, 420)
		table.insert(items, { time = t, cam = rng:NextInteger(1, 24), rank = rank })
	end
	return { frames = PuzzleKit.shuffle(items, rng) }
end

function Def.check(puzzle, answer): boolean
	if not PuzzleKit.isIntArray(answer, 6, 1, 6) then
		return false
	end
	for k = 1, 6 do
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
