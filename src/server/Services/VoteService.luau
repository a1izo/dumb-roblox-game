-- Voting after the meeting: remove one player or skip. The player with the most votes
-- is out; a tie removes nobody. The vote is counted when it closes (tally) and the result
-- is shown in the Verdict phase (present), where the removal lands at the climax.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local VoteCounter = require(Shared:WaitForChild("VoteCounter"))

local Cues = require(script.Parent.Cues)
local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)

local VoteRemote = Net.event("Vote")
local VoteUpdateRemote = Net.event("VoteUpdate")
local VoteResultRemote = Net.event("VoteResult")

local VoteService = {}

local votes: { [number]: string } = {}
local isOpen = false

local function broadcast()
	local voted = {}
	for userId in pairs(votes) do
		table.insert(voted, userId)
	end
	VoteUpdateRemote:FireAllClients({ voted = voted })
end

local function onVote(player: Player, target)
	if not isOpen then
		return
	end
	local ps = Match.getLiving(player)
	if not ps then
		return
	end
	if target == VoteCounter.SKIP then
		votes[ps.userId] = VoteCounter.SKIP
	elseif type(target) == "number" then
		local chosen = Match.getByUserId(target)
		if not chosen or not chosen.alive or chosen == ps then
			return
		end
		votes[ps.userId] = tostring(chosen.userId)
	else
		return
	end
	broadcast()
end

function VoteService.open()
	votes = {}
	isOpen = true
	broadcast()
end

function VoteService.cancel()
	isOpen = false
	votes = {}
end

export type Result = {
	counts: { { name: string, count: number, userId: number? } },
	removed: any?, -- the player state voted out, if any
	votesAgainst: number,
	valid: { [number]: string },
	tie: boolean,
	total: number,
}

-- Counts the votes. Nobody is removed yet: that happens in present(), at the climax of the
-- verdict cutscene.
function VoteService.tally(): Result
	isOpen = false
	-- Only living voters count; votes for players who are gone count as skips.
	local valid: { [number]: string } = {}
	for userId, key in pairs(votes) do
		if Match.isLivingUserId(userId) then
			if key ~= VoteCounter.SKIP then
				local targetId = tonumber(key)
				if not targetId or not Match.isLivingUserId(targetId) then
					key = VoteCounter.SKIP
				end
			end
			valid[userId] = key
		end
	end
	votes = {}

	local result = VoteCounter.tally(valid)
	local counts = {}
	for key, count in pairs(result.counts) do
		if key == VoteCounter.SKIP then
			table.insert(counts, { name = "Skip", count = count })
		else
			local ps = Match.getByUserId(tonumber(key) or 0)
			table.insert(counts, { name = if ps then ps.alias else "?", count = count, userId = tonumber(key) })
		end
	end
	table.sort(counts, function(a, b)
		return a.count > b.count
	end)
	local removed = if result.removed then Match.getByUserId(result.removed) else nil
	return {
		counts = counts,
		removed = removed,
		votesAgainst = if removed then (result.counts[tostring(removed.userId)] or 0) else 0,
		valid = valid,
		tie = result.tie,
		total = result.total,
	}
end

-- Seconds into the verdict at which the result lands.
VoteService.CLIMAX = 3.2

-- Plays the verdict: every client animates the tally, then the player voted out (if any) is
-- removed at the climax.
function VoteService.present(result: Result)
	local removed = result.removed
	VoteResultRemote:FireAllClients({
		counts = result.counts,
		removedUserId = if removed then removed.userId else nil,
		removedAlias = if removed then removed.alias else nil,
		tie = result.tie,
		total = result.total,
	})
	local climax = if Match.phaseLength("Verdict") > 0 then VoteService.CLIMAX else 0
	Cues.fire("verdict", {
		counts = result.counts,
		removedUserId = if removed then removed.userId else nil,
		removedAlias = if removed then removed.alias else nil,
		tie = result.tie,
		total = result.total,
		climax = climax,
	}, { lead = 0.2 })

	local matchId = Match.id
	task.delay(climax + 0.2, function()
		if Match.id ~= matchId or not Match.active then
			return
		end
		if removed and removed.alive then
			if removed.role == "Kira" then
				for voterId, key in pairs(result.valid) do
					if key == tostring(removed.userId) then
						local voter = Match.getByUserId(voterId)
						if voter then
							voter.stats.correctVotes += 1
						end
					end
				end
			end
			EventLog.add(
				string.format(
					"%s (%s) was voted out with %d votes.",
					removed.alias,
					Terms.role(removed.role),
					result.votesAgainst
				),
				"vote"
			)
			Match.announce(
				removed.alias .. " was voted out",
				string.format("%d of %d votes. Their role stays secret.", result.votesAgainst, result.total),
				"neutral"
			)
			Elimination.eliminate(removed, "voted", nil, removed.alias .. " was voted out.", {})
		else
			local subtitle = if result.total == 0
				then "Nobody voted."
				elseif result.tie then "The vote was tied."
				else "Skip won the vote."
			EventLog.add("The vote removed nobody. " .. subtitle, "vote")
			Match.announce("Nobody was voted out", subtitle, "neutral")
		end
	end)
end

function VoteService.init()
	VoteRemote.OnServerEvent:Connect(onVote)
end

return VoteService
