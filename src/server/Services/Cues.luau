-- Server-timed presentation cues. The server decides what happens and when; every client
-- plays the matching cutscene locally, starting at the same server time (`at`), so all
-- screens stay in step. Cues only carry information that is already public.
--
-- Holds: a cue can ask the match loop to wait (for example so a death or an arrest finishes
-- playing before the next round or the ending starts). Holds never delay gameplay that is
-- already running; the loop only checks them between phases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local Match = require(script.Parent.Match)

local CueRemote = Net.event("Cue")

local Cues = {}

-- Fired as (kind, starts at (server time), hold seconds or nil) for every cue sent (EmoteService stops the case's
-- emotes for the cutscenes everyone sees).
Cues.Started = Signal.new()

local counter = 0
local holdUntil = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

export type Options = {
	to: { Player }?, -- only these players (everyone by default)
	lead: number?, -- seconds from now until the cue starts (0.35 by default)
	hold: number?, -- keep the match loop waiting this long after the cue starts
	-- The id of a cue already sent: this is the same cue in another version (a style only its owner may
	-- see goes in one copy), so every screen draws the same things from it (Presenters/Death's witnesses).
	sameAs: number?,
}

-- kind: "intro", "death", "verdict", "arrest", "eyesDeal", "manualWrite", "outro"
function Cues.fire(kind: string, data: { [string]: any }?, options: Options?): number
	local id = if options and options.sameAs then options.sameAs else counter + 1
	counter = math.max(counter, id)
	local lead = if options and options.lead then options.lead else 0.35
	local payload = {
		id = id,
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
	if not (options and options.sameAs) then
		Cues.Started:Fire(kind, payload.at, if options then options.hold else nil)
	end
	return id
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
