--!strict
-- Win checks run after every removal from the match.
--   Bureau wins: Diavolo (role id "Kira") is removed (voted out, arrested or gone).
--   Coven wins: living Coven players (Diavolo and Muertos) equal or outnumber the living Bureau.
-- The Bureau's task bar is the other way to win; TaskBarService declares it when it fills.

local WinConditions = {}

export type Entry = { role: string, alive: boolean }

-- Returns "Team" or "Kira" and a short code, or nil when the match goes on.
function WinConditions.evaluate(entries: { Entry }): (string?, string?)
	local hasKira = false
	local kiraAlive = false
	local kiraSide = 0
	local team = 0
	for _, entry in ipairs(entries) do
		local isKiraSide = entry.role == "Kira" or entry.role == "Follower"
		if entry.role == "Kira" then
			hasKira = true
			kiraAlive = entry.alive
		end
		if entry.alive then
			if isKiraSide then
				kiraSide += 1
			else
				team += 1
			end
		end
	end
	if hasKira and not kiraAlive then
		return "Team", "KiraRemoved"
	end
	if hasKira and kiraSide >= team then
		return "Kira", "Parity"
	end
	return nil, nil
end

-- How many case files fill the task bar for a match that started with this many Bureau players.
function WinConditions.taskTotal(bureauCount: number, perBureau: number): number
	return math.max(1, bureauCount * perBureau)
end

return WinConditions
