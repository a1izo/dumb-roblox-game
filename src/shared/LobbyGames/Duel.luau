--!strict
-- The name duel: two players at the two stones under the ribs. Each is given an invented name (from the
-- same pools the cases use), and each one's name leaks to the other a few letters at a time, the way a
-- name leaks in a case. The first to write the other's whole name wins. A wrong name costs a few seconds;
-- if nobody has it when the time is up, it is a draw.
--
-- Pure rules over a small state; the server holds the state and never sends a name, only its mask.

local LetterReveal = require(script.Parent.Parent.LetterReveal)
local NamePools = require(script.Parent.Parent.NamePools)
local NameUtil = require(script.Parent.Parent.NameUtil)
local Util = require(script.Parent.Parent.Util)

local Duel = {}

Duel.LEAK = 2.5 -- seconds between leaks
Duel.LETTERS = 3 -- letters of each name shown by a leak
Duel.LOCKOUT = 3 -- seconds a wrong name costs
Duel.LIMIT = 60 -- seconds until a draw
Duel.MAX_GUESS = 40 -- characters of a written name that are read

export type Side = {
	name: string,
	revealed: { [number]: boolean },
	-- The positions shown so far, in order.
	shown: { number },
	lockedUntil: number,
}

export type State = {
	sides: { Side },
	startedAt: number,
	nextLeak: number,
	over: boolean,
}

-- Two different invented names.
function Duel.names(rng: Random): (string, string)
	local firsts, lasts = NamePools.FIRST_NAMES, NamePools.LAST_NAMES
	local a = NameUtil.fullName(firsts[rng:NextInteger(1, #firsts)], lasts[rng:NextInteger(1, #lasts)])
	local b = a
	while b == a do
		b = NameUtil.fullName(firsts[rng:NextInteger(1, #firsts)], lasts[rng:NextInteger(1, #lasts)])
	end
	return a, b
end

local function side(name: string): Side
	return { name = name, revealed = {}, shown = {}, lockedUntil = 0 }
end

function Duel.new(nameA: string, nameB: string, now: number): State
	return { sides = { side(nameA), side(nameB) }, startedAt = now, nextLeak = now + Duel.LEAK, over = false }
end

-- The other side's number (1 or 2).
function Duel.other(index: number): number
	return if index == 1 then 2 else 1
end

-- Is it time for the next leak?
function Duel.due(state: State, now: number): boolean
	return not state.over and now >= state.nextLeak
end

-- Is the time up?
function Duel.expired(state: State, now: number): boolean
	return not state.over and now - state.startedAt >= Duel.LIMIT
end

-- The letters of a side's name that have not been shown yet.
function Duel.hidden(state: State, index: number): number
	local mine = state.sides[index]
	return #LetterReveal.letterIndices(mine.name) - #mine.shown
end

-- A leak: each name shows a few letters more (never one already shown).
function Duel.leak(state: State, now: number, rng: Random)
	for _, mine in ipairs(state.sides) do
		local fresh = {}
		for _, at in ipairs(LetterReveal.letterIndices(mine.name)) do
			if not mine.revealed[at] then
				table.insert(fresh, at)
			end
		end
		Util.shuffle(fresh, rng)
		for n = 1, math.min(Duel.LETTERS, #fresh) do
			mine.revealed[fresh[n]] = true
			table.insert(mine.shown, fresh[n])
		end
		table.sort(mine.shown)
	end
	state.nextLeak = now + Duel.LEAK
end

-- A side's name as the other side sees it: "K _ N _ _   _ O _ _".
function Duel.mask(state: State, index: number): string
	local mine = state.sides[index]
	return LetterReveal.mask(mine.name, mine.shown)
end

-- Side `index` writes a name for the other side. Returns "win" (it is the name: the duel is over), "miss"
-- (it is not: they are locked out for a moment), "locked" (still locked out) or "over".
function Duel.guess(state: State, index: number, text: string, now: number): string
	if state.over then
		return "over"
	end
	local mine = state.sides[index]
	if now < mine.lockedUntil then
		return "locked"
	end
	local theirs = state.sides[Duel.other(index)]
	local written = string.sub(text, 1, Duel.MAX_GUESS)
	if NameUtil.normalize(written) == NameUtil.normalize(theirs.name) then
		state.over = true
		return "win"
	end
	mine.lockedUntil = now + Duel.LOCKOUT
	return "miss"
end

return Duel
