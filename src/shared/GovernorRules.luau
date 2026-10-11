--!strict
-- When frames run slow the game lightens itself, one cut at a time, in this order: distant particles,
-- glow and haze, shadow-casting lamps, the far crowd, the number of footprints. This is the rule for
-- when a cut is made; the client's World/Governor measures the frames and applies it. A cut is never
-- taken back while a round lasts (effects that come and go look worse than fewer effects), and nothing
-- a player reads is ever cut: the crowd near the camera, the fresh end of a trail and every sign stay.

local GovernorRules = {}

-- The cuts in the order they are made: at step n the first n are on.
GovernorRules.CUTS = { "particles", "glow", "shadows", "crowd", "prints" }

-- Slow = under this share of the best rate the device has shown (a phone capped at 30 frames a second
-- is not slow at 28)...
GovernorRules.SLOW_SHARE = 0.72
-- ...but never at this many frames a second or more, and always below the floor.
GovernorRules.SLOW_CEILING = 40
GovernorRules.FLOOR = 18
GovernorRules.HOLD = 6 -- seconds of slow frames, without a break, before a cut
GovernorRules.SETTLE = 4 -- seconds after a cut before judging again (the cut needs time to show)
GovernorRules.WARMUP = 8 -- seconds after a reset that are not judged (a map loading stutters)
GovernorRules.LONGEST_FRAME = 1 -- a frame longer than this is the window in the background, not the game

export type State = {
	step: number, -- how many cuts are on
	rate: number, -- frames a second, averaged over about a second
	best: number, -- the highest rate seen
	slowFor: number, -- seconds the rate has been slow without a break
	wait: number, -- seconds left before judging again
}

function GovernorRules.new(): State
	return { step = 0, rate = 0, best = 0, slowFor = 0, wait = GovernorRules.WARMUP }
end

-- A new round: every cut is taken back, and the first seconds are not judged.
function GovernorRules.reset(state: State)
	state.step = 0
	state.slowFor = 0
	state.wait = GovernorRules.WARMUP
end

function GovernorRules.slow(state: State): boolean
	local limit =
		math.max(GovernorRules.FLOOR, math.min(GovernorRules.SLOW_CEILING, state.best * GovernorRules.SLOW_SHARE))
	return state.rate < limit
end

-- One frame of `dt` seconds. True when it made a cut.
function GovernorRules.advance(state: State, dt: number): boolean
	if dt <= 0 or dt > GovernorRules.LONGEST_FRAME then
		return false
	end
	local now = 1 / dt
	state.rate = if state.rate == 0 then now else state.rate + (now - state.rate) * math.min(dt, 1)
	if state.wait > 0 then
		state.wait -= dt
		return false
	end
	state.best = math.max(state.best, state.rate)
	if state.step >= #GovernorRules.CUTS or not GovernorRules.slow(state) then
		state.slowFor = 0
		return false
	end
	state.slowFor += dt
	if state.slowFor < GovernorRules.HOLD then
		return false
	end
	state.step += 1
	state.slowFor = 0
	state.wait = GovernorRules.SETTLE
	return true
end

-- Whether the cut called `what` is on at `step`.
function GovernorRules.cut(step: number, what: string): boolean
	local index = table.find(GovernorRules.CUTS, what)
	return index ~= nil and index <= step
end

return GovernorRules
