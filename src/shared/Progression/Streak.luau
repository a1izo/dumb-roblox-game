--!strict
-- The daily login streak: claim once per UTC day in the lobby. Missing a day starts over.
-- Rewards grow over a 7-day cycle; day 7 also gives a streak cosmetic (once).

local Streak = {}

export type State = { day: number, count: number, best: number }
export type Reward = { coins: number, itemId: string? }

Streak.COINS = { 20, 30, 40, 50, 60, 80, 120 }
Streak.CYCLE = #Streak.COINS
Streak.ITEM = "title_nightowl"

-- Can the streak be claimed today?
function Streak.canClaim(state: State, today: number): boolean
	return state.day ~= today
end

-- The streak count if claimed today.
function Streak.nextCount(state: State, today: number): number
	if state.day == today - 1 then
		return state.count + 1
	end
	return 1
end

-- Claims today's reward. Returns the new state and the reward (nil if already claimed).
function Streak.advance(state: State, today: number): (State, Reward?)
	if not Streak.canClaim(state, today) then
		return state, nil
	end
	local count = Streak.nextCount(state, today)
	local cycleDay = ((count - 1) % Streak.CYCLE) + 1
	local reward: Reward = { coins = Streak.COINS[cycleDay] }
	if cycleDay == Streak.CYCLE then
		reward.itemId = Streak.ITEM
	end
	return { day = today, count = count, best = math.max(state.best, count) }, reward
end

return Streak
