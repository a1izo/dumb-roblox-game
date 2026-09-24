--!strict
-- Vote counting: the target with the most votes is removed; a tie, or "skip" having
-- the most votes, removes nobody.

local VoteCounter = {}

VoteCounter.SKIP = "skip"

export type Result = {
	removed: number?,
	counts: { [string]: number },
	tie: boolean,
	total: number,
}

-- votes maps voter userId -> "skip" or tostring(target userId).
function VoteCounter.tally(votes: { [number]: string }): Result
	local counts: { [string]: number } = {}
	local total = 0
	for _, target in pairs(votes) do
		counts[target] = (counts[target] or 0) + 1
		total += 1
	end
	local bestTarget: string? = nil
	local bestCount = 0
	local tie = false
	for target, count in pairs(counts) do
		if count > bestCount then
			bestTarget = target
			bestCount = count
			tie = false
		elseif count == bestCount then
			tie = true
		end
	end
	local removed: number? = nil
	if bestTarget ~= nil and not tie and bestTarget ~= VoteCounter.SKIP then
		removed = tonumber(bestTarget)
	end
	return {
		removed = removed,
		counts = counts,
		tie = tie,
		total = total,
	}
end

return VoteCounter
