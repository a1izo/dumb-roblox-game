-- Removes a player from the living: Death Note deaths, the shinigami deal, votes,
-- arrests and players who leave. Win checks listen to Match.Eliminated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local CharacterService = require(script.Parent.CharacterService)
local Match = require(script.Parent.Match)

local EliminationRemote = Net.event("Elimination")

local Elimination = {}

-- kind: "dead", "voted", "arrested" or "left". cause is shown publicly for deaths.
-- context carries extra facts for the win check, for example { byKira = true }.
function Elimination.eliminate(ps, kind: string, cause: string?, text: string, context: { [string]: any }?): boolean
	if not ps.alive or not Match.active then
		return false
	end
	ps.alive = false
	ps.status = kind
	ps.cause = cause
	ps.eliminatedRound = Match.round
	ps.taskStation = nil

	EliminationRemote:FireAllClients({
		userId = ps.userId,
		alias = ps.alias,
		kind = kind,
		cause = cause,
		text = text,
	})

	-- Listeners run first so they still see the character where it fell.
	Match.Eliminated:Fire(ps, kind, context or {})
	CharacterService.setWriting(ps.player, false)
	CharacterService.onEliminated(ps, kind)
	Match.pushState()
	Match.pushPrivate(ps)
	return true
end

return Elimination
