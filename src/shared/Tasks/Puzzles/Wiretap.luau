--!strict
-- Phone: tune the wiretap's frequency and gain until the live waveform matches the recording.
-- Answer: { frequency, gain }.

local PuzzleKit = require(script.Parent.Parent.PuzzleKit)

local Def = {
	id = "Wiretap",
	title = "Wiretap",
	hint = "Tune frequency and gain until your waveform matches the recording.",
}

Def.MAX_FREQUENCY = 6
Def.MAX_GAIN = 5
Def.START = { 3, 3 }

function Def.generate(seed: number)
	local rng = PuzzleKit.rng(seed)
	local frequency, gain
	repeat
		frequency = rng:NextInteger(1, Def.MAX_FREQUENCY)
		gain = rng:NextInteger(1, Def.MAX_GAIN)
	until frequency ~= Def.START[1] or gain ~= Def.START[2]
	return { frequency = frequency, gain = gain, phase = rng:NextNumber() * math.pi * 2 }
end

function Def.check(puzzle, answer): boolean
	return type(answer) == "table"
		and #answer == 2
		and PuzzleKit.isInt(answer[1], 1, Def.MAX_FREQUENCY)
		and PuzzleKit.isInt(answer[2], 1, Def.MAX_GAIN)
		and answer[1] == puzzle.frequency
		and answer[2] == puzzle.gain
end

function Def.solve(puzzle)
	return { puzzle.frequency, puzzle.gain }
end

return Def
