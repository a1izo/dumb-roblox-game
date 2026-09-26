--!strict
-- Who may watch the running match from the lobby. Pure rules, used by the server (GhostService)
-- and tested in SpectateRules.spec.

local SpectateRules = {}

export type Situation = {
	active: boolean, -- a case is running
	phase: string, -- its phase id
	participant: boolean, -- this player is in the case (alive or a Specter)
	queued: boolean, -- this player is readied up for the next case
}

-- Why a player cannot start watching (nil when they can).
function SpectateRules.blocker(situation: Situation): string?
	if not situation.active or situation.phase == "Reveal" then
		return "No case is running right now."
	elseif situation.participant then
		return "You are in this case."
	elseif situation.queued then
		return "Leave the queue to watch."
	end
	return nil
end

-- Readying up is party-wide: when `readier` readies, a party member who is watching is
-- brought back to the lobby and queued too. The readier themself must leave first.
function SpectateRules.pullOnReady(member: any, readier: any, memberWatching: boolean): boolean
	return memberWatching and member ~= readier
end

return SpectateRules
