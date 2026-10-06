--!strict
-- Death's wager: a Deathsinger (dead, still in the case, in it or waiting in the lobby) may bet on who Diavolo
-- is and on who the next vote removes. Pure rules, used by the server (WagerService) and the client panels,
-- and tested in Wager.spec.
--   * "diavolo": one guess per case, not for Diavolo's side (they know who it is); paid when the case closes.
--   * "vote": one guess per round, made before the vote opens (so never after the ballots are seen); the
--     guess is a living player or NOBODY (no one removed); settled at that round's verdict.
-- Every bet is locked once made.

local Wager = {}

Wager.DIAVOLO_COINS = 30
Wager.VOTE_COINS = 10
Wager.NOBODY = 0 -- a vote guess that no one is removed

-- The phases in which a vote guess may still be made (before the vote opens).
Wager.VOTE_PHASES = { Investigation = true, DeathNote = true, Meeting = true }

export type Bettor = {
	dead: boolean, -- out of the case but still in it (not left)
	kiraSide: boolean, -- Diavolo or a Muerto
}

export type Book = {
	diavolo: number?, -- the userId guessed as Diavolo
	votes: { [number]: number }, -- round -> userId guessed (NOBODY for no one)
}

export type Situation = {
	active: boolean,
	phase: string,
	round: number,
	living: { [number]: boolean }, -- userIds still alive
	inCase: { [number]: boolean }, -- userIds in the case
}

function Wager.newBook(): Book
	return { diavolo = nil, votes = {} }
end

-- Why `bettor` cannot place this bet now (nil when they can).
function Wager.blocker(
	bettor: Bettor,
	book: Book,
	kind: string,
	target: number,
	situation: Situation,
	self: number
): string?
	if not situation.active or situation.phase == "Reveal" or situation.phase == "Outro" then
		return "No case to bet on."
	elseif not bettor.dead then
		return "Only Deathsingers can wager."
	end
	if kind == "diavolo" then
		if bettor.kiraSide then
			return "You already know who Diavolo is."
		elseif book.diavolo ~= nil then
			return "Your Diavolo guess is locked."
		elseif target == self or not situation.inCase[target] then
			return "Pick someone in the case."
		end
		return nil
	elseif kind == "vote" then
		if not Wager.VOTE_PHASES[situation.phase] then
			return "Guesses close when the vote opens."
		elseif book.votes[situation.round] ~= nil then
			return "Your guess for this vote is locked."
		elseif target ~= Wager.NOBODY and not situation.living[target] then
			return "Pick a living player, or no one."
		end
		return nil
	end
	return "Unknown wager."
end

-- Whether a vote guess was right: `removed` is the userId voted out, or nil when nobody was removed.
function Wager.voteRight(guess: number?, removed: number?): boolean
	if guess == nil then
		return false
	end
	if removed == nil then
		return guess == Wager.NOBODY
	end
	return guess == removed
end

function Wager.diavoloRight(guess: number?, diavolo: number?): boolean
	return guess ~= nil and diavolo ~= nil and guess == diavolo
end

return Wager
