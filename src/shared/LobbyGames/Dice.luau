--!strict
-- Bone dice at the dice rock: four stools, two dice. Everyone seated rolls once a round; the highest
-- total wins (a tie shares it). Alone, you roll against the realm's own dice. A win-streak counts
-- the rounds you won running. The server rolls; the client only shows it. Pure rules, tested in
-- LobbyGames.spec.

local Dice = {}

Dice.SEATS = 4
Dice.WINDOW = 6 -- seconds the table waits for the others once the first has rolled
Dice.COOLDOWN = 0.8

-- Two six-sided dice.
function Dice.roll(rng: Random): (number, number)
	return rng:NextInteger(1, 6), rng:NextInteger(1, 6)
end

export type Outcome = { winners: { any }, losers: { any }, push: boolean }

-- Who won a round. totals: [player] = their total. house: the realm's total when only one player is
-- seated (they must beat it; equal is a push). With several players the highest wins; if all are
-- equal nobody wins (a push).
function Dice.settle(totals: { [any]: number }, house: number?): Outcome
	local entries = {}
	for who, total in pairs(totals) do
		table.insert(entries, { who = who, total = total })
	end
	local outcome: Outcome = { winners = {}, losers = {}, push = false }
	if #entries == 0 then
		return outcome
	end
	if house ~= nil and #entries == 1 then
		local entry = entries[1]
		if entry.total > house then
			table.insert(outcome.winners, entry.who)
		elseif entry.total == house then
			outcome.push = true
		else
			table.insert(outcome.losers, entry.who)
		end
		return outcome
	end
	local best, worst = -1, math.huge
	for _, entry in ipairs(entries) do
		best = math.max(best, entry.total)
		worst = math.min(worst, entry.total)
	end
	if best == worst then
		outcome.push = true
		return outcome
	end
	for _, entry in ipairs(entries) do
		table.insert(if entry.total == best then outcome.winners else outcome.losers, entry.who)
	end
	return outcome
end

-- The streak after a round: a win adds one, a loss resets it, a push leaves it.
function Dice.streak(previous: number, result: string): number
	if result == "win" then
		return previous + 1
	elseif result == "lose" then
		return 0
	end
	return previous
end

return Dice
