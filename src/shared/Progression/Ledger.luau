--!strict
-- The Season ledger (the shop's Ledger suit): seasons of WEEKS weeks, each of TIERS tiers. Every case played
-- writes points in it (more for a win, more for each quest finished in that case: ProgressRules.apply), each
-- PER_TIER points is a tier, and a tier pays the moment it is reached. Every third tier is a thing (the user,
-- 2026-11-10: "the rewards being more tempting"): pieces from the shop given free, the season's own titles, a
-- custom death near the end and the season's best thing at the last; tiers 10 and 20 are purses; the rest pay
-- more coins the higher they are. A thing already owned pays its worth in coins instead (Ledger.instead). A new
-- season starts the ledger again at 0. Only this free line exists; a paid one would stay hidden until a Robux
-- product is set up (Shared/Products).
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
Ledger.PLAY = 15
Ledger.WIN = 15
Ledger.QUEST = 15
-- The purses: tiers that pay a heap of coins.
Ledger.PURSES = { [10] = 750, [20] = 1000 } :: { [number]: number }
-- What a thing already owned pays instead, by rarity (when it has no price of its own).
local WORTH = { common = 150, rare = 300, epic = 600, legendary = 1000, godhood = 1500 }

local DAY = 86400
local LENGTH = Ledger.WEEKS * 7 * DAY

export type Season = { name: string, items: { [number]: string } }
export type Reward = { coins: number?, item: string? }
export type Record = { season: number, points: number, tier: number }

-- Each season's name and the tiers that give a thing instead of coins.
Ledger.SEASONS = {
	[1] = {
		name = "The Season of Names",
		items = {
			[3] = "seat_composed",
			[6] = "specter_moth",
			[9] = "title_s1_bookkeeper",
			[12] = "writing_frost",
			[15] = "book_iron",
			[18] = "chair_crate",
			[21] = "verdict_lamp",
			[24] = "title_s1_accountant",
			[27] = "reason_clock",
			[30] = "emote_new_world",
		},
	},
	[2] = {
		name = "The Season of Ash",
		items = {
			[3] = "writing_quill",
			[6] = "specter_ember",
			[9] = "title_s2_scribe",
			[12] = "seat_steepled",
			[15] = "book_scale",
			[18] = "verdict_checkmate",
			[21] = "specter_crow",
			[24] = "title_s2_witness",
			[27] = "reason_chip",
			[30] = "win_bureau_mate",
		},
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

-- What a tier of a season pays: its thing, a purse, or coins (more the higher it is).
function Ledger.reward(season: number, tier: number): Reward
	local known = Ledger.SEASONS[season]
	local item = if known then known.items[tier] else nil
	if item then
		return { item = item }
	end
	return { coins = Ledger.PURSES[tier] or (60 + 6 * tier) }
end

-- The coins a thing pays when it is already owned: its price, else its rarity's worth.
function Ledger.instead(item: any): number
	if type(item) ~= "table" then
		return WORTH.rare
	end
	return tonumber(item.price) or WORTH[item.rarity] or WORTH.rare
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
