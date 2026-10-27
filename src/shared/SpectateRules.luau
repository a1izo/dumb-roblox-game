--!strict
-- Who may watch the running match from the lobby: only a player with a friend or a party member in it. Pure rules, used by the server (GhostService)
-- and tested in SpectateRules.spec.

local SpectateRules = {}

export type Situation = {
	active: boolean, -- a case is running
	phase: string, -- its phase id
	participant: boolean, -- this player is in the case (alive or a Specter)
	queued: boolean, -- this player is readied up for the next case
	-- someone in the case is this player's Roblox friend or in their party (only they may watch it: a stranger watching
	-- from the lobby could pass on what they saw, 2026-10-27)
	knowsSomeone: boolean,
}

-- Why a player cannot start watching (nil when they can).
function SpectateRules.blocker(situation: Situation): string?
	if not situation.active or situation.phase == "Reveal" then
		return "No case is running right now."
	elseif situation.participant then
		return "You are in this case."
	elseif situation.queued then
		return "Leave the queue to watch."
	elseif not situation.knowsSomeone then
		return "You can only watch a case a friend or someone in your party is in."
	end
	return nil
end

-- Readying up is party-wide: when `readier` readies, a party member who is watching is
-- brought back to the lobby and queued too. The readier themself must leave first.
function SpectateRules.pullOnReady(member: any, readier: any, memberWatching: boolean): boolean
	return memberWatching and member ~= readier
end

return SpectateRules
