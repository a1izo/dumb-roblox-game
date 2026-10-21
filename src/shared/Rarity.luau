--!strict
-- How rare a thing in the shop is, in one place: five tiers, named for how a name gets into Death's Manual,
-- from a scrawl to a god's own hand. Each keeps the id items have always had (common .. legendary) and the
-- top one is new (godhood: the four emotes with a private cutscene). The shop's cards wear each tier their own
-- way (UI/Shop/Card); its name is always written beside its colour, so rarity never rests on colour alone.
-- Crimson is Godhood's alone: darker than the game's danger red, and only ever a line or a glow, never a fill.
-- (The second tier was "Inked" until 2026-10-21: the owner took ink out of the game.)
--
--   Scrawl     ash          a plain card
--   Penned     slate blue   an underline
--   Sealed     violet       a framed edge
--   Condemned  amber        the frame, page grain and a slow sheen
--   Godhood    crimson      a glowing edge, and motes drifting up (still under reduced motion)

local Rarity = {}

Rarity.ORDER = { "common", "rare", "epic", "legendary", "godhood" }

Rarity.NAMES = {
	common = "Scrawl",
	rare = "Penned",
	epic = "Sealed",
	legendary = "Condemned",
	godhood = "Godhood",
} :: { [string]: string }

Rarity.COLORS = {
	common = Color3.fromRGB(0xA7, 0xA2, 0x9A), -- ash
	rare = Color3.fromRGB(0x6F, 0x93, 0xC2), -- slate blue
	epic = Color3.fromRGB(0x9C, 0x7B, 0xEA), -- violet
	legendary = Color3.fromRGB(0xD9, 0x96, 0x3F), -- amber
	godhood = Color3.fromRGB(0xA3, 0x19, 0x2F), -- crimson
} :: { [string]: Color3 }

local RANK: { [string]: number } = {}
for index, id in ipairs(Rarity.ORDER) do
	RANK[id] = index
end

-- 1 (Scrawl) to 5 (Godhood); an unknown id counts as Scrawl.
function Rarity.rank(id: string?): number
	return if id then RANK[id] or 1 else 1
end

function Rarity.name(id: string?): string
	return Rarity.NAMES[Rarity.ORDER[Rarity.rank(id)]]
end

function Rarity.color(id: string?): Color3
	return Rarity.COLORS[Rarity.ORDER[Rarity.rank(id)]]
end

-- The tier a card counts as in Fate's deck and its odds: Godhood among the Condemned (legendary).
function Rarity.fateGroup(id: string?): string
	local known = Rarity.ORDER[Rarity.rank(id)]
	return if known == "godhood" then "legendary" else known
end

-- Buying something this rare asks to be confirmed first (Condemned and Godhood).
function Rarity.confirms(id: string?): boolean
	return Rarity.rank(id) >= 4
end

return Rarity
