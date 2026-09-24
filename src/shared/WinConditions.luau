--!strict
-- Win checks run after every removal from the match.
--   Team wins: Kira is removed (voted out or arrested with a valid warrant).
--   Kira wins: Kira kills L, or living Kira players (Kira + followers) equal or outnumber
--   the living investigation team. Arresting an innocent and surviving round five are
--   handled where they happen.

local WinConditions = {}

export type Entry = { role: string, alive: boolean }

-- Returns "Team" or "Kira" and a short code, or nil when the match goes on.
function WinConditions.evaluate(entries: { Entry }, lKilledByKira: boolean): (string?, string?)
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
	if lKilledByKira then
		return "Kira", "LKilled"
	end
	if hasKira and kiraSide >= team then
		return "Kira", "Parity"
	end
	return nil, nil
end

return WinConditions
