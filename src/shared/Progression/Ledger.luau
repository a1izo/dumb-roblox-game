--!strict
-- The Season ledger (the shop's Ledger suit): seasons of WEEKS weeks, each of TIERS tiers. Every case played
-- writes points in it (more for a win, more for each quest finished in that case: ProgressRules.apply), each
-- PER_TIER points is a tier, and a tier pays the moment it is reached: coins on most, the season's titles on
-- some, and its emote at the last. A new season starts the ledger again at 0. Only this free line exists; a
-- paid one would stay hidden until a Robux product is set up (Shared/Products).
--
-- Season 1 began on the day the ledger came (2026-10-14). A season's emote is only earned here while it
-- lasts; once it is over the emote joins Today's hand (Cosmetics `later`: from that day, at that price).
-- Seasons past the ones written below pay coins only, until the next is written.

local Ledger = {}

Ledger.START = DateTime.fromUniversalTime(2026, 10, 14).UnixTimestamp
Ledger.WEEKS = 6
Ledger.TIERS = 30
Ledger.PER_TIER = 100
-- Points: a case played, a win on top, each quest finished in it.
Ledger.PLAY = 10
Ledger.WIN = 10
Ledger.QUEST = 15

local DAY = 86400
local LENGTH = Ledger.WEEKS * 7 * DAY

export type Season = { name: string, items: { [number]: string } }
export type Reward = { coins: number?, item: string? }
export type Record = { season: number, points: number, tier: number }

-- Each season's name and the tiers that give a thing instead of coins.
Ledger.SEASONS = {
	[1] = {
		name = "The Season of Names",
		items = { [10] = "title_s1_bookkeeper", [25] = "title_s1_accountant", [30] = "emote_new_world" },
	},
} :: { [number]: Season }

-- The season at a time (1 from START on; 0 before it).
function Ledger.season(unixTime: number): number
	if unixTime < Ledger.START then
		return 0
	end
	return math.floor((unixTime - Ledger.START) / LENGTH) + 1
end

-- When a season starts and ends (unix times).
function Ledger.bounds(season: number): (number, number)
	local start = Ledger.START + (season - 1) * LENGTH
	return start, start + LENGTH
end

function Ledger.name(season: number): string
	local known = Ledger.SEASONS[season]
	return if known then known.name else string.format("Season %d", season)
end

-- The tier reached with these points (0 to TIERS).
function Ledger.tierOf(points: number): number
	return math.clamp(math.floor(points / Ledger.PER_TIER), 0, Ledger.TIERS)
end

-- What a tier of a season pays: its thing, or coins (a little more the higher it is).
function Ledger.reward(season: number, tier: number): Reward
	local known = Ledger.SEASONS[season]
	local item = if known then known.items[tier] else nil
	if item then
		return { item = item }
	end
	return { coins = 30 + 2 * tier }
end

-- The profile's ledger as it stands in `season` (a record of another season counts as empty).
function Ledger.view(record: any, season: number): Record
	if type(record) == "table" and record.season == season then
		return { season = season, points = tonumber(record.points) or 0, tier = tonumber(record.tier) or 0 }
	end
	return { season = season, points = 0, tier = 0 }
end

-- Writes points into the profile's ledger (starting it again in a new season). Returns the tiers reached by
-- them, in order, each with its reward (to be paid by the caller).
function Ledger.add(record: any, season: number, points: number): { { tier: number, reward: Reward } }
	if record.season ~= season then
		record.season = season
		record.points = 0
		record.tier = 0
	end
	record.points += math.max(0, points)
	local reached = {}
	local tier = Ledger.tierOf(record.points)
	for step = record.tier + 1, tier do
		table.insert(reached, { tier = step, reward = Ledger.reward(season, step) })
	end
	record.tier = math.max(record.tier, tier)
	return reached
end

-- The points a case is worth.
function Ledger.pointsFor(won: boolean, quests: number): number
	return Ledger.PLAY + (if won then Ledger.WIN else 0) + Ledger.QUEST * quests
end

return Ledger
