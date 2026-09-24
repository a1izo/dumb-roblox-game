-- Server-timed presentation cues. The server decides what happens and when; every client
-- plays the matching cutscene locally, starting at the same server time (`at`), so all
-- screens stay in step. Cues only carry information that is already public.
--
-- Holds: a cue can ask the match loop to wait (for example so a death or an arrest finishes
-- playing before the next round or the ending starts). Holds never delay gameplay that is
-- already running; the loop only checks them between phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Match = require(script.Parent.Match)

local CueRemote = Net.event("Cue")

local Cues = {}

local counter = 0
local holdUntil = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

export type Options = {
	to: { Player }?, -- only these players (everyone by default)
	lead: number?, -- seconds from now until the cue starts (0.35 by default)
	hold: number?, -- keep the match loop waiting this long after the cue starts
}

-- kind: "intro", "death", "verdict", "arrest", "eyesDeal", "outro"
function Cues.fire(kind: string, data: { [string]: any }?, options: Options?): number
	counter += 1
	local lead = if options and options.lead then options.lead else 0.35
	local payload = {
		id = counter,
		matchId = Match.id,
		kind = kind,
		at = now() + lead,
		data = data or {},
	}
	if options and options.to then
		for _, player in ipairs(options.to) do
			if player.Parent then
				CueRemote:FireClient(player, payload)
			end
		end
	else
		CueRemote:FireAllClients(payload)
	end
	if options and options.hold then
		Cues.hold(lead + options.hold)
	end
	return counter
end

function Cues.hold(seconds: number)
	holdUntil = math.max(holdUntil, now() + seconds)
end

-- Waits until every hold has run out, but never longer than maxWait seconds.
function Cues.waitHolds(maxWait: number)
	local started = now()
	while now() < holdUntil and now() - started < maxWait do
		task.wait(0.1)
	end
end

function Cues.reset()
	holdUntil = 0
end

return Cues
