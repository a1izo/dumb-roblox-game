--!strict
-- The Trial: the game taught by doing, in the lobby's Academy. A new player is offered it once (a wisp
-- waits at the foot of the terrace's steps); anyone can begin it at the Academy's gate. It walks through the
-- things a case turns on, in the order a case tells them, one step at a time, using the Academy's own
-- drills:
--
--   card     read your role card: an alias for everyone to see, a real name to keep
--   file     work a case file, and see three letters of your real name leak
--   write    write a full real name in the Manual
--   warrant  serve a warrant: the right suspect, the full real name
--   ready    press READY
--
-- Each step shows one instruction (`line`) and one short line on how to do it (`how`); when it is done, a
-- line on why it matters (`why`) shows for a moment before the next step comes in.
--
-- The steps run on the player's client (like the drills); the server keeps four facts in the profile's
-- `trial`: done, skipped (the offer was turned down: it is not made again), paid, and step (how many steps
-- were done, so a rejoin carries on where it stopped). Finishing pays the Academy's one reward once per
-- profile. That reward used to be paid for finishing all seven drills: whoever finished them under that rule
-- has been paid and is not paid again. (Finishing the drills no longer pays; a profile that finishes them now
-- is marked `training.unrewarded`, which is how the two are told apart without touching old profiles.)
--
-- The rules here are pure (and tested); Onboarding/TrialController plays them on the client and
-- Services/ProfileService applies them on the server.

local Config = require(script.Parent.Config)
local Terms = require(script.Parent.Terms)

local Trial = {}

-- drill: the Academy drill whose completion is the step (nil: done some other way).
-- how and why are Terms templates; `how` may hold {cardKey} (the control for the role card, filled on the
-- client for the input in the player's hands).
export type Step = { id: string, line: string, how: string, why: string, drill: string? }

local RAW: { Step } = {
	{
		id = "card",
		line = "Read your role card",
		how = "{cardKey} to turn it over.",
		why = "Your real name is your life. Others only see your alias.",
	},
	{
		id = "file",
		line = "Work a case file",
		how = "Follow the wisp to the fingerprint altar.",
		why = "In a case, every finished file posts a clue for {agency}.",
		drill = "fingerprint",
	},
	{
		id = "write",
		line = "Write a name in {grimoire}",
		how = "Read Dummy B's leaking letters, then write its name at the Manual's altar.",
		why = "That is how {hand} kills: a real name, written in full.",
		drill = "grimoire",
	},
	{
		id = "warrant",
		line = "Serve a warrant",
		how = "At the warrant's altar, name the one you suspect.",
		why = "{Zero} has one warrant. A wrong name wastes it.",
		drill = "warrant",
	},
	{
		id = "ready",
		line = "Press READY",
		how = "The wisp waits in the candle circle.",
		why = "That is the game: learn real names, guard your own. {players} players open a case.",
	},
}

Trial.STEPS = {} :: { Step }
Trial.BY_ID = {} :: { [string]: Step }
for _, raw in ipairs(RAW) do
	local step: Step = { id = raw.id, line = Terms.f(raw.line), how = raw.how, why = raw.why, drill = raw.drill }
	table.insert(Trial.STEPS, step)
	Trial.BY_ID[step.id] = step
end

-- The offer (a small card where the steps will show).
Trial.OFFER_TITLE = "The Trial"
Trial.OFFER_LINE = string.format("Learn the game in two minutes  ·  +%d coins", Config.TRAINING_REWARD)

-- The practice identity on the Trial's role card (an alias and a real name from nobody's case).
Trial.ALIAS = "Raven"
Trial.REAL_NAME = "Akira Noda"

local NUMBER_WORDS =
	{ "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve" }

-- A step's how or why line, with its placeholders filled ({cardKey} from `vars`).
function Trial.text(template: string, vars: { [string]: any }?): string
	local all: { [string]: any } = { players = NUMBER_WORDS[Config.MIN_PLAYERS] or tostring(Config.MIN_PLAYERS) }
	for key, value in pairs(vars or {}) do
		all[key] = value
	end
	return Terms.f(template, all)
end

-- What a profile's `trial` holds.
function Trial.defaults(): { done: boolean, skipped: boolean, paid: boolean, step: number }
	return { done = false, skipped = false, paid = false, step = 0 }
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

-- How many steps are done, counted in order (the first gap ends the count).
function Trial.count(done: { [string]: boolean }): number
	local count = 0
	for _, step in ipairs(Trial.STEPS) do
		if not done[step.id] then
			break
		end
		count += 1
	end
	return count
end

-- The first `count` steps, as done (what a rejoin starts from).
function Trial.doneUpTo(count: number): { [string]: boolean }
	local done = {}
	for index, step in ipairs(Trial.STEPS) do
		if index > count then
			break
		end
		done[step.id] = true
	end
	return done
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

-- Is the profile (as the client has it) loaded far enough to tell whether the Trial is offered?
function Trial.known(profile: any): boolean
	return type(profile) == "table" and type(profile.stats) == "table" and type(profile.trial) == "table"
end

-- Is this profile (as the client has it) offered the Trial on arriving in the lobby? Only someone who has
-- never played a case, has not done it and has not turned it down.
function Trial.offered(profile: any): boolean
	if not Trial.known(profile) then
		return false
	end
	local stats, trial = profile.stats, profile.trial
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

-- The client reached `count` steps. Progress only moves forward, never past the last step, and stops
-- mattering once the Trial is done. Returns whether anything changed.
function Trial.advance(data: any, count: any): boolean
	local trial = data.trial
	if type(trial) ~= "table" or trial.done or type(count) ~= "number" or count ~= count then
		return false
	end
	local wanted = math.clamp(math.floor(count), 0, #Trial.STEPS)
	local current = tonumber(trial.step) or 0
	if wanted <= current then
		return false
	end
	trial.step = wanted
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
	trial.step = #Trial.STEPS
	if before then
		return 0
	end
	data.coins = (tonumber(data.coins) or 0) + reward
	return reward
end

return Trial
