-- Cosmetic catalog. Item ids never change (they are saved in profiles).
--
--   kind    hat, trail, tie (the noir tie in matches), grimoire (the notebook cover in the
--           Grimoire phase), victory (your pose when your side wins), specter (your
--           outline as a ghost), title (shown in the lobby and on the results screen only)
--   rarity  common, rare, epic, legendary
--   source  shop (always for sale), rotation (for sale on days it is featured), vip
--           (free with the VIP pass), rank / achievement / streak / mastery (earned)
--   price   coins; nil when it cannot be bought
--
-- Role neutrality: nothing here may show or hide what role someone has. Everyone holds a
-- notebook and writes in the Grimoire phase whatever they own, and ghosts are only ever
-- seen by other ghosts.

local Cosmetics = {}

export type Item = {
	id: string,
	kind: string,
	name: string,
	rarity: string,
	source: string,
	price: number?,
	[string]: any,
}

local RED = Color3.fromRGB(209, 26, 42)

Cosmetics.ITEMS = {
	-- Hats
	{
		id = "hat_cap",
		kind = "hat",
		name = "Agency Cap",
		rarity = "common",
		source = "shop",
		price = 100,
		style = "cap",
		color = Color3.fromRGB(30, 45, 80),
		accent = Color3.fromRGB(220, 190, 90),
	},
	{
		id = "hat_fedora",
		kind = "hat",
		name = "Noir Fedora",
		rarity = "common",
		source = "shop",
		price = 150,
		style = "fedora",
		color = Color3.fromRGB(35, 35, 40),
		accent = Color3.fromRGB(120, 20, 25),
	},
	{
		id = "hat_deerstalker",
		kind = "hat",
		name = "Deerstalker",
		rarity = "rare",
		source = "shop",
		price = 250,
		style = "deerstalker",
		color = Color3.fromRGB(125, 100, 65),
		accent = Color3.fromRGB(90, 70, 45),
	},
	{
		id = "hat_fedora_white",
		kind = "hat",
		name = "Ivory Fedora",
		rarity = "rare",
		source = "shop",
		price = 300,
		style = "fedora",
		color = Color3.fromRGB(225, 220, 205),
		accent = Color3.fromRGB(30, 30, 30),
	},
	{
		id = "hat_tophat",
		kind = "hat",
		name = "Gentleman's Top Hat",
		rarity = "epic",
		source = "shop",
		price = 450,
		style = "tophat",
		color = Color3.fromRGB(20, 20, 24),
		accent = Color3.fromRGB(150, 25, 35),
	},
	{
		id = "hat_fedora_crimson",
		kind = "hat",
		name = "Crimson Fedora",
		rarity = "epic",
		source = "rotation",
		price = 600,
		style = "fedora",
		color = Color3.fromRGB(120, 16, 26),
		accent = Color3.fromRGB(20, 20, 22),
	},
	{
		id = "hat_tophat_ink",
		kind = "hat",
		name = "Inkwell Top Hat",
		rarity = "legendary",
		source = "rotation",
		price = 1200,
		style = "tophat",
		color = Color3.fromRGB(8, 8, 10),
		accent = Color3.fromRGB(244, 241, 234),
	},
	{
		id = "hat_cap_vip",
		kind = "hat",
		name = "Velvet Cap",
		rarity = "epic",
		source = "vip",
		style = "cap",
		color = Color3.fromRGB(60, 12, 20),
		accent = Color3.fromRGB(230, 200, 120),
	},

	-- Trails
	{
		id = "trail_ink",
		kind = "trail",
		name = "Ink Trail",
		rarity = "common",
		source = "shop",
		price = 200,
		colors = { Color3.fromRGB(15, 15, 18), Color3.fromRGB(90, 90, 100) },
	},
	{
		id = "trail_crimson",
		kind = "trail",
		name = "Crimson Trail",
		rarity = "rare",
		source = "shop",
		price = 350,
		colors = { Color3.fromRGB(200, 20, 35), Color3.fromRGB(60, 0, 10) },
	},
	{
		id = "trail_ice",
		kind = "trail",
		name = "Ice Trail",
		rarity = "rare",
		source = "shop",
		price = 450,
		colors = { Color3.fromRGB(190, 235, 255), Color3.fromRGB(60, 140, 220) },
	},
	{
		id = "trail_gold",
		kind = "trail",
		name = "Gold Leaf Trail",
		rarity = "epic",
		source = "shop",
		price = 600,
		colors = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(170, 110, 20) },
	},
	{
		id = "trail_smoke",
		kind = "trail",
		name = "Cigarette Smoke",
		rarity = "rare",
		source = "rotation",
		price = 400,
		colors = { Color3.fromRGB(200, 200, 205), Color3.fromRGB(60, 60, 66) },
	},
	{
		id = "trail_neon",
		kind = "trail",
		name = "Neon Rain",
		rarity = "legendary",
		source = "rotation",
		price = 1100,
		colors = { Color3.fromRGB(255, 80, 200), Color3.fromRGB(80, 220, 255) },
	},

	-- Ties (the noir tie everyone wears in matches)
	{
		id = "tie_black",
		kind = "tie",
		name = "Funeral Tie",
		rarity = "common",
		source = "shop",
		price = 120,
		color = Color3.fromRGB(14, 14, 16),
	},
	{
		id = "tie_navy",
		kind = "tie",
		name = "Agency Navy",
		rarity = "common",
		source = "shop",
		price = 120,
		color = Color3.fromRGB(28, 44, 90),
	},
	{
		id = "tie_gold",
		kind = "tie",
		name = "Gold Silk",
		rarity = "rare",
		source = "rotation",
		price = 300,
		color = Color3.fromRGB(210, 170, 70),
	},
	{
		id = "tie_white",
		kind = "tie",
		name = "White Lie",
		rarity = "epic",
		source = "rotation",
		price = 500,
		color = Color3.fromRGB(240, 238, 232),
	},
	{
		id = "tie_vip",
		kind = "tie",
		name = "Velvet Tie",
		rarity = "epic",
		source = "vip",
		color = Color3.fromRGB(90, 16, 40),
	},

	-- Grimoire covers (every living player holds a notebook in the Grimoire phase)
	{
		id = "book_red",
		kind = "grimoire",
		name = "Blood Leather",
		rarity = "rare",
		source = "shop",
		price = 250,
		color = Color3.fromRGB(110, 14, 22),
	},
	{
		id = "book_white",
		kind = "grimoire",
		name = "Bone Vellum",
		rarity = "rare",
		source = "rotation",
		price = 350,
		color = Color3.fromRGB(230, 224, 208),
	},
	{
		id = "book_gold",
		kind = "grimoire",
		name = "Gilded Cover",
		rarity = "legendary",
		source = "rotation",
		price = 1000,
		color = Color3.fromRGB(200, 160, 60),
	},

	-- Victory poses
	{
		id = "win_fist",
		kind = "victory",
		name = "Fist of Justice",
		rarity = "rare",
		source = "shop",
		price = 400,
		pose = "victoryFist",
	},
	{
		id = "win_bow",
		kind = "victory",
		name = "Curtain Call",
		rarity = "epic",
		source = "rotation",
		price = 700,
		pose = "victoryBow",
	},

	-- Specter outlines (seen by other ghosts only)
	{
		id = "specter_ember",
		kind = "specter",
		name = "Ember Wraith",
		rarity = "rare",
		source = "shop",
		price = 300,
		color = Color3.fromRGB(255, 120, 60),
	},
	{
		id = "specter_violet",
		kind = "specter",
		name = "Violet Shade",
		rarity = "epic",
		source = "rotation",
		price = 600,
		color = Color3.fromRGB(170, 100, 255),
	},
	{
		id = "specter_blood",
		kind = "specter",
		name = "Crimson Revenant",
		rarity = "legendary",
		source = "vip",
		color = RED,
	},

	-- Titles (lobby and results only)
	{ id = "title_trainee", kind = "title", name = "Trainee", rarity = "common", source = "achievement" },
	{ id = "title_detective", kind = "title", name = "Detective", rarity = "common", source = "shop", price = 150 },
	{ id = "title_insomniac", kind = "title", name = "Insomniac", rarity = "rare", source = "rotation", price = 300 },
	{ id = "title_vip", kind = "title", name = "Patron of the Arts", rarity = "epic", source = "vip" },

	-- Earned: the 7-day streak
	{ id = "title_nightowl", kind = "title", name = "Night Owl", rarity = "rare", source = "streak" },
	-- Earned: achievements
	{ id = "title_veteran", kind = "title", name = "Veteran", rarity = "rare", source = "achievement" },
	{ id = "title_lifer", kind = "title", name = "Lifer", rarity = "legendary", source = "achievement" },
	{ id = "title_unbeaten", kind = "title", name = "Unbeaten", rarity = "epic", source = "achievement" },
	{ id = "title_archivist", kind = "title", name = "Archivist", rarity = "rare", source = "achievement" },
	{ id = "title_papertrail", kind = "title", name = "Paper Trail", rarity = "epic", source = "achievement" },
	{ id = "title_sharpeye", kind = "title", name = "Sharp Eye", rarity = "epic", source = "achievement" },
	{ id = "title_unwritten", kind = "title", name = "Unwritten", rarity = "epic", source = "achievement" },
	{ id = "title_shepherd", kind = "title", name = "Shepherd of Souls", rarity = "epic", source = "achievement" },
	{ id = "title_inkstained", kind = "title", name = "Ink-Stained", rarity = "epic", source = "achievement" },
	{ id = "title_handcuffs", kind = "title", name = "Handcuffs", rarity = "epic", source = "achievement" },
	-- Earned: role mastery (levels 5 and 10)
	{ id = "title_m_hand", kind = "title", name = "Master of the Hand", rarity = "epic", source = "mastery" },
	{ id = "title_m_cultist", kind = "title", name = "High Cultist", rarity = "epic", source = "mastery" },
	{ id = "title_m_zero", kind = "title", name = "Zero's Equal", rarity = "epic", source = "mastery" },
	{ id = "title_m_butler", kind = "title", name = "Head Butler", rarity = "epic", source = "mastery" },
	{ id = "title_m_agent", kind = "title", name = "Senior Agent", rarity = "epic", source = "mastery" },
	{
		id = "tie_m_hand",
		kind = "tie",
		name = "Hand's Crimson",
		rarity = "legendary",
		source = "mastery",
		color = Color3.fromRGB(150, 0, 18),
	},
	{
		id = "tie_m_cultist",
		kind = "tie",
		name = "Cult Candle",
		rarity = "legendary",
		source = "mastery",
		color = Color3.fromRGB(230, 140, 40),
	},
	{
		id = "tie_m_zero",
		kind = "tie",
		name = "Zero's White",
		rarity = "legendary",
		source = "mastery",
		color = Color3.fromRGB(250, 250, 250),
	},
	{
		id = "tie_m_butler",
		kind = "tie",
		name = "Butler's Grey",
		rarity = "legendary",
		source = "mastery",
		color = Color3.fromRGB(120, 120, 126),
	},
	{
		id = "tie_m_agent",
		kind = "tie",
		name = "Agency Blue",
		rarity = "legendary",
		source = "mastery",
		color = Color3.fromRGB(40, 90, 200),
	},
	-- Earned: ranks
	{ id = "title_rank_2", kind = "title", name = "Patrol Officer", rarity = "common", source = "rank" },
	{ id = "title_rank_3", kind = "title", name = "Constable", rarity = "common", source = "rank" },
	{ id = "title_rank_4", kind = "title", name = "Inspector", rarity = "rare", source = "rank" },
	{ id = "title_rank_5", kind = "title", name = "Detective", rarity = "rare", source = "rank" },
	{ id = "title_rank_6", kind = "title", name = "Senior Detective", rarity = "epic", source = "rank" },
	{ id = "title_rank_7", kind = "title", name = "Chief Inspector", rarity = "epic", source = "rank" },
	{ id = "title_rank_8", kind = "title", name = "Legendary Detective", rarity = "legendary", source = "rank" },
} :: { Item }

Cosmetics.KINDS = { "hat", "trail", "tie", "grimoire", "victory", "specter", "title" }

Cosmetics.KIND_NAMES = {
	hat = "Hats",
	trail = "Trails",
	tie = "Ties",
	grimoire = "Notebooks",
	victory = "Victory poses",
	specter = "Specter forms",
	title = "Titles",
}

Cosmetics.RARITIES = { "common", "rare", "epic", "legendary" }

Cosmetics.RARITY_COLORS = {
	common = Color3.fromRGB(150, 146, 138),
	rare = Color3.fromRGB(62, 139, 255),
	epic = Color3.fromRGB(176, 108, 255),
	legendary = Color3.fromRGB(255, 176, 46),
}

local byId: { [string]: Item } = {}
for _, item in ipairs(Cosmetics.ITEMS) do
	byId[item.id] = item
end

function Cosmetics.byId(id: string?): Item?
	if not id then
		return nil
	end
	return byId[id]
end

function Cosmetics.ofKind(kind: string): { Item }
	local list = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.kind == kind then
			table.insert(list, item)
		end
	end
	return list
end

-- Items that can appear in the daily rotation.
function Cosmetics.rotationPool(): { Item }
	local list = {}
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.source == "rotation" then
			table.insert(list, item)
		end
	end
	return list
end

return Cosmetics
