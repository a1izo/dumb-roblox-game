--!strict
-- How long a voiced cutscene lasts: its shot's own length (art/scripts/cinema/shots: the line's reading time and a
-- beat before it), or longer once its voice slot has a clip longer than the line's time in the shot. Then the whole
-- shot stretches by the same share, so the line still fits it from its first word to its last. The server works it
-- out for each role cutscene (Services/RoundService: the briefing lasts the longest one and a hold) and sends it with
-- the cutscene, so the screen plays exactly that long (Presentation/ShotPlayer).

local CutLength = {}

-- Where the shot's spoken line ends (shot time): its last word, and the half second it takes to say it.
function CutLength.lineEnd(shot: any): number?
	local finish: number? = nil
	for _, event in ipairs(shot.events or {}) do
		if event.kind == "line" and type(event.words) == "table" then
			local last = event.words[#event.words]
			local at = event.t + (if last then tonumber(last[2]) or 0 else 0) + 0.5
			finish = math.max(finish or 0, at)
		end
	end
	return finish
end

-- The length to play `shot` for, given its voice clip's length in seconds (nil or 0 while the slot is empty).
function CutLength.of(shot: any, clipSeconds: number?): number
	local length = tonumber(shot.length) or 0
	local sound = shot.sound
	if not clipSeconds or clipSeconds <= 0 or type(sound) ~= "table" or type(sound.voice) ~= "string" then
		return length
	end
	local voiceAt = tonumber(sound.voiceAt) or 0
	local span = (CutLength.lineEnd(shot) or length) - voiceAt
	if span <= 0 then
		return length
	end
	return length * math.max(1, clipSeconds / span)
end

return CutLength
