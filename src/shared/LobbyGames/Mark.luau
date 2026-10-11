--!strict
-- Death's mark: tag, for the wait. Whoever touches the bell is in. One of them carries the mark and can
-- pass it by coming close to another; when the bell tolls, the one carrying it drops where they stand,
-- gets up a moment later, and the mark jumps to someone else. It never ends: people come and go, and
-- the score is how many tolls in a row you were not the one carrying it.
--
-- Pure rules over a small state (ids are whatever the caller uses for a player); the server holds the
-- state and asks these.

local Mark = {}

Mark.TOLL = 45 -- seconds between tolls
Mark.DOWN = 3 -- seconds the carrier lies down after a toll
Mark.RANGE = 5.5 -- studs within which the mark passes
Mark.NO_TAGBACK = 2 -- seconds before the mark can go straight back to whoever passed it
Mark.CARRIER_SPEED = 1.1 -- the carrier walks this much faster (it has to catch someone)
Mark.MIN_PLAYERS = 2

export type State = {
	members: { any },
	carrier: any?,
	-- Who had it just before, and when it passed (no tag-backs).
	from: any?,
	passedAt: number,
	nextToll: number?,
	streaks: { [any]: number },
}

function Mark.new(): State
	return { members = {}, carrier = nil, from = nil, passedAt = 0, nextToll = nil, streaks = {} }
end

function Mark.isMember(state: State, id: any): boolean
	return table.find(state.members, id) ~= nil
end

-- Is a game on (enough players, someone carrying the mark)?
function Mark.running(state: State): boolean
	return #state.members >= Mark.MIN_PLAYERS and state.carrier ~= nil
end

local function pick(state: State, pickIndex: (number) -> number, except: any?): any?
	local pool = {}
	for _, id in ipairs(state.members) do
		if id ~= except then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(pickIndex(#pool), 1, #pool)]
end

-- Starts the game when there are enough players and nobody carries the mark; stops it when there are not.
local function settle(state: State, now: number, pickIndex: (number) -> number)
	if #state.members < Mark.MIN_PLAYERS then
		state.carrier = nil
		state.from = nil
		state.nextToll = nil
		return
	end
	if state.carrier == nil then
		state.carrier = pick(state, pickIndex, nil)
		state.from = nil
		state.passedAt = now
		state.nextToll = now + Mark.TOLL
	end
end

-- A player joins. pickIndex(n) picks 1..n (the server's random). Returns false if they were in already.
function Mark.join(state: State, id: any, now: number, pickIndex: (number) -> number): boolean
	if Mark.isMember(state, id) then
		return false
	end
	table.insert(state.members, id)
	state.streaks[id] = 0
	settle(state, now, pickIndex)
	return true
end

-- A player leaves (walked off, left the game, called to a case). The mark does not leave with them.
function Mark.leave(state: State, id: any, now: number, pickIndex: (number) -> number): boolean
	local index = table.find(state.members, id)
	if not index then
		return false
	end
	table.remove(state.members, index)
	state.streaks[id] = nil
	if state.from == id then
		state.from = nil
	end
	if state.carrier == id then
		state.carrier = nil
	end
	settle(state, now, pickIndex)
	return true
end

-- May the mark pass from `from` to `to` now, `distance` studs apart?
function Mark.canPass(state: State, from: any, to: any, now: number, distance: number): boolean
	if not Mark.running(state) or state.carrier ~= from or from == to or not Mark.isMember(state, to) then
		return false
	end
	if distance > Mark.RANGE then
		return false
	end
	if state.from == to and now - state.passedAt < Mark.NO_TAGBACK then
		return false
	end
	return true
end

function Mark.pass(state: State, to: any, now: number)
	state.from = state.carrier
	state.carrier = to
	state.passedAt = now
end

-- Is it time for the bell?
function Mark.due(state: State, now: number): boolean
	return Mark.running(state) and state.nextToll ~= nil and now >= state.nextToll
end

-- The bell tolls: the carrier goes down (their streak ends), everyone else's streak grows, and the mark
-- jumps to someone else. Returns who went down, and the streaks after it.
function Mark.toll(state: State, now: number, pickIndex: (number) -> number): (any?, { [any]: number })
	local down = state.carrier
	if not Mark.running(state) or down == nil then
		return nil, state.streaks
	end
	for _, id in ipairs(state.members) do
		state.streaks[id] = if id == down then 0 else (state.streaks[id] or 0) + 1
	end
	state.carrier = pick(state, pickIndex, down)
	state.from = down
	state.passedAt = now + Mark.DOWN
	state.nextToll = now + Mark.TOLL
	return down, state.streaks
end

-- Is `new` a better best than `old`? More tolls survived in a row is better.
function Mark.isBetter(old: number, new: number): boolean
	return new > old
end

return Mark
