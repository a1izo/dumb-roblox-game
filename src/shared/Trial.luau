--!strict
-- The Trial: the game taught by doing, in the lobby's Academy. A new player is offered it once (a wisp
-- waits at the foot of the terrace's steps); anyone can begin it at the Academy's gate. It walks through the
-- things a case turns on, in the order a case tells them, using the Academy's own drills:
--
--   card     read your role card: an alias for everyone to see, a real name to keep
--   file     work a case file, and see three letters of your real name leak
--   write    write a full real name in the Manual
--   warrant  serve a warrant: the right suspect, the full real name
--   ready    press READY
--
-- The steps run on the player's client (like the drills); the server keeps three facts in the profile's
-- `trial`: done, skipped (the offer was turned down: it is not made again) and paid. Finishing pays the
-- Academy's one reward once per profile. That reward used to be paid for finishing all seven drills:
-- whoever finished them under that rule has been paid and is not paid again. (Finishing the drills no
-- longer pays; a profile that finishes them now is marked `training.unrewarded`, which is how the two are
-- told apart without touching old profiles.)
--
-- The rules here are pure (and tested); Onboarding/TrialController plays them on the client and
-- Services/ProfileService applies them on the server.

local Terms = require(script.Parent.Terms)

local Trial = {}

-- drill: the Academy drill whose completion is the step (nil: the step is done in the Trial's own card).
export type Step = { id: string, line: string, drill: string? }

local RAW: { { id: string, line: string, drill: string? } } = {
	{ id = "card", line = "Read your role card" },
	{ id = "file", line = "Work a case file", drill = "fingerprint" },
	{ id = "write", line = "Write a name in {grimoire}", drill = "grimoire" },
	{ id = "warrant", line = "Serve a warrant", drill = "warrant" },
	{ id = "ready", line = "Press READY" },
}

Trial.STEPS = {} :: { Step }
Trial.BY_ID = {} :: { [string]: Step }
for _, raw in ipairs(RAW) do
	local step: Step = { id = raw.id, line = Terms.f(raw.line), drill = raw.drill }
	table.insert(Trial.STEPS, step)
	Trial.BY_ID[step.id] = step
end

-- The practice identity on the Trial's role card (an alias and a real name from nobody's case).
Trial.ALIAS = "Raven"
Trial.REAL_NAME = "Akira Noda"

-- What a profile's `trial` holds.
function Trial.defaults(): { done: boolean, skipped: boolean, paid: boolean }
	return { done = false, skipped = false, paid = false }
end

-- The first step not done yet, in order (nil when all are).
function Trial.next(done: { [string]: boolean }): Step?
	for _, step in ipairs(Trial.STEPS) do
		if not done[step.id] then
			return step
		end
	end
	return nil
end

function Trial.complete(done: { [string]: boolean }): boolean
	return Trial.next(done) == nil
end

-- The step a finished Academy drill counts for (nil: a drill the Trial does not use).
function Trial.stepForDrill(drill: string): Step?
	for _, step in ipairs(Trial.STEPS) do
		if step.drill == drill then
			return step
		end
	end
	return nil
end

-- Is this profile (as the client has it) offered the Trial on arriving in the lobby? Only someone who has
-- never played a case, has not done it and has not turned it down.
function Trial.offered(profile: any): boolean
	if type(profile) ~= "table" then
		return false
	end
	local stats, trial = profile.stats, profile.trial
	if type(stats) ~= "table" or type(trial) ~= "table" then
		return false
	end
	return (tonumber(stats.matches) or 0) == 0 and trial.done ~= true and trial.skipped ~= true
end

-- The offer was turned down. Returns whether anything changed.
function Trial.skip(data: any): boolean
	if type(data.trial) ~= "table" or data.trial.skipped or data.trial.done then
		return false
	end
	data.trial.skipped = true
	return true
end

-- Has this profile had the Academy's reward: for the Trial, or (before the Trial existed) for all seven drills?
function Trial.paid(data: any): boolean
	local trial, training = data.trial, data.training
	if type(trial) == "table" and trial.paid == true then
		return true
	end
	return type(training) == "table" and training.done == true and training.unrewarded ~= true
end

-- All seven drills were just finished (for the first time), now that they pay nothing by themselves.
function Trial.drillsFinished(data: any)
	local training = data.training
	if type(training) == "table" and not training.done then
		training.done = true
		training.unrewarded = true
	end
end

-- The Trial was finished: marks it done and pays `reward` coins if this profile was never paid. Returns the
-- coins paid (0 when it was paid before).
function Trial.finish(data: any, reward: number): number
	local trial = data.trial
	if type(trial) ~= "table" then
		return 0
	end
	local before = Trial.paid(data)
	trial.done = true
	trial.paid = true
	if before then
		return 0
	end
	data.coins = (tonumber(data.coins) or 0) + reward
	return reward
end

return Trial
