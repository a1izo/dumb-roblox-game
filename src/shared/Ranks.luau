--!strict
-- Detective ranks unlocked with experience.

local Ranks = {}

export type Rank = { name: string, xp: number }

Ranks.LIST = {
	{ name = "Rookie", xp = 0 },
	{ name = "Patrol Officer", xp = 150 },
	{ name = "Constable", xp = 400 },
	{ name = "Inspector", xp = 900 },
	{ name = "Detective", xp = 1700 },
	{ name = "Senior Detective", xp = 3000 },
	{ name = "Chief Inspector", xp = 5000 },
	{ name = "Legendary Detective", xp = 8000 },
} :: { Rank }

-- Returns the rank index, the rank and the next rank (nil at the top).
function Ranks.forXp(xp: number): (number, Rank, Rank?)
	local index = 1
	for i, rank in ipairs(Ranks.LIST) do
		if xp >= rank.xp then
			index = i
		end
	end
	return index, Ranks.LIST[index], Ranks.LIST[index + 1]
end

return Ranks
