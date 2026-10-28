-- Cosmetic catalog. Item ids never change (they are saved in profiles).
--
--   kind    grimoire (the cover of the Manual
--           Diavolo holds while writing), specter (your form as a Deathsinger: `form` names what it wears),
--           title (shown in the lobby and on the results screen only), writing (how Diavolo's
--           names go into the Manual: `style`), verdict (how Ace's arrest lands: `style`), death
--           (what becomes of you when you die: `style`), emote (`emote` is its clip, `category` its
--           section in the shop: dance, pose, prop, stroll or duo; `lobbyOnly` when it looks like a
--           game signal, a death, an arrest or the Eyes, so it is never played in a match), seat (how you sit
--           at the war table for a meeting: `clip`, Shared/Seating), chair (what your place at the table
--           becomes, for everyone: `model`), win (a win cutscene: `side`, `cut`; worn in its side's `slot`),
--           reason (a custom death: `cause` is what Diavolo can write as the cause of death once it is worn, and
--           `style` the effect that plays on the body as it falls, Presentation/CustomDeaths)
--   rarity  common, rare, epic, legendary, godhood (shown as Scrawl, Penned, Sealed, Condemned, Godhood:
--           Shared/Rarity)
--   source  shop (always for sale), rotation (for sale on days it is featured), free (everyone's), vip
--           (free with the VIP pass), rank / achievement / streak / mastery (earned), season (a
--           reward of the Season ledger), set (a title: every piece of a set, Shared/Sets),
--           collection (a title: owning so many emotes, Progression/Collection)
--   price   coins; nil when it cannot be bought
--   later   sold only from a day on, on the days it is in Today's hand: { from = "YYYY-MM-DD", price } (a
--           season's emote once its season is over, Progression/Ledger)
--
-- Role neutrality: nothing here may show or hide what role someone has. A Manual cover only
-- shows while Diavolo writes, when he is in plain sight anyway, and ghosts are only ever
-- seen by other ghosts. A writing or verdict style is never a public attribute: during a case
-- only its owner sees it, and everyone once that identity is out (the server sends it in the
-- cues). A death style is the victim's and plays for everyone.

local Rarity = require(script.Parent.Rarity)
local Terms = require(script.Parent.Terms)

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
	-- Manual covers (Diavolo's book, seen whenever he writes)
	{
		id = "book_red",
		kind = "grimoire",
		name = "Oxblood Hide",
		blurb = "Cracked red leather with a heartbeat glow.",
		tell = "Pulses red, faster as you write.",
		rarity = "rare",
		source = "shop",
		price = 250,
		style = "oxblood",
		color = Color3.fromRGB(96, 16, 22),
	},
	{
		id = "book_gold",
		kind = "grimoire",
		name = "Gilded Requiem",
		blurb = "Black and gold. Every name throws off gold flecks.",
		tell = "Gold flecks rise as you write.",
		rarity = "legendary",
		source = "rotation",
		price = 1000,
		style = "gilded",
		color = Color3.fromRGB(200, 160, 60),
	},
	{
		id = "book_ash",
		kind = "grimoire",
		name = "Burnt Edition",
		blurb = "Charred edges that drop embers.",
		tell = "Embers fall as you write.",
		rarity = "common",
		source = "shop",
		price = 200,
		style = "burnt",
		color = Color3.fromRGB(40, 30, 24),
	},
	{
		id = "book_case",
		kind = "grimoire",
		name = "Case File",
		blurb = "A Bureau folder that spills loose pages.",
		tell = "Loose pages slip out when it opens.",
		rarity = "rare",
		source = "shop",
		price = 300,
		style = "casefile",
		color = Color3.fromRGB(196, 170, 112),
	},
	{
		id = "book_iron",
		kind = "grimoire",
		name = "Iron Ledger",
		blurb = "Riveted iron with a padlock that sparks open.",
		tell = "The iron glows red as you write.",
		rarity = "epic",
		source = "shop",
		price = 550,
		style = "iron",
		color = Color3.fromRGB(46, 48, 52),
	},
	{
		id = "book_scale",
		kind = "grimoire",
		name = "Death God's Hide",
		blurb = "Scaled hide with a blinking red eye.",
		tell = "The eye on the cover blinks red.",
		rarity = "epic",
		source = "shop",
		price = 650,
		style = "scale",
		color = Color3.fromRGB(70, 72, 66),
	},
	{
		id = "book_glass",
		kind = "grimoire",
		name = "Black Mirror",
		blurb = "Cracked black glass that frosts over.",
		tell = "The glass frosts over as you write.",
		rarity = "legendary",
		source = "shop",
		price = 1100,
		style = "mirror",
		color = Color3.fromRGB(12, 12, 16),
	},

	-- Specter outlines (seen by other ghosts only)
	{
		id = "specter_ember",
		kind = "specter",
		name = "Ember Wraith",
		blurb = "A drifting shape that sheds embers.",
		rarity = "rare",
		source = "shop",
		price = 300,
		color = Color3.fromRGB(255, 120, 60),
		form = "embers",
	},
	{
		id = "specter_violet",
		kind = "specter",
		name = "Veil of Dusk",
		blurb = "Grey veils trail behind you.",
		rarity = "epic",
		source = "rotation",
		price = 600,
		color = Color3.fromRGB(170, 100, 255),
		form = "veil",
	},
	{
		id = "specter_blood",
		kind = "specter",
		name = "Crimson Revenant",
		blurb = "Chains and a red glow.",
		rarity = "legendary",
		source = "vip",
		color = RED,
		form = "chains",
	},
	{
		id = "specter_crow",
		kind = "specter",
		name = "Crow Shroud",
		blurb = "Crow feathers and a crow on each shoulder.",
		rarity = "epic",
		source = "shop",
		price = 650,
		color = Color3.fromRGB(60, 62, 74),
		form = "crows",
	},
	{
		id = "specter_marionette",
		kind = "specter",
		name = "Cut Marionette",
		blurb = "A puppet with cut strings.",
		rarity = "legendary",
		source = "shop",
		price = 1200,
		color = Color3.fromRGB(214, 200, 176),
		form = "marionette",
	},
	{
		id = "specter_moth",
		kind = "specter",
		name = "Moth Lantern",
		blurb = "Pale moths circle a light in your chest.",
		rarity = "rare",
		source = "shop",
		price = 350,
		color = Color3.fromRGB(214, 228, 240),
		form = "moths",
	},
	-- Writing styles (Diavolo's names going into the Manual)
	{
		id = "writing_quill",
		kind = "writing",
		name = "Smouldering Quill",
		blurb = "Strokes that smoulder as they dry.",
		rarity = "rare",
		source = "shop",
		price = 350,
		style = "quill",
		color = Color3.fromRGB(150, 14, 26),
	},
	{
		id = "writing_typewriter",
		kind = "writing",
		name = "Night Typewriter",
		blurb = "Typed out, one letter at a time.",
		rarity = "rare",
		source = "shop",
		price = 300,
		style = "typewriter",
		color = Color3.fromRGB(214, 210, 200),
	},
	{
		id = "writing_fire",
		kind = "writing",
		name = "Burning Letters",
		blurb = "Letters burn into the page.",
		rarity = "epic",
		source = "shop",
		price = 650,
		style = "fire",
		color = Color3.fromRGB(255, 140, 60),
	},
	{
		id = "writing_knife",
		kind = "writing",
		name = "The Knife",
		blurb = "The name is carved into the page.",
		rarity = "legendary",
		source = "mastery",
		style = "knife",
		color = Color3.fromRGB(196, 198, 206),
	},
	{
		id = "writing_chalk",
		kind = "writing",
		name = "Chalk Line",
		blurb = "Written in chalk.",
		rarity = "common",
		source = "shop",
		price = 200,
		style = "chalk",
		color = Color3.fromRGB(236, 232, 222),
	},
	{
		id = "writing_frost",
		kind = "writing",
		name = "Frost Script",
		blurb = "Letters frost onto the page.",
		rarity = "epic",
		source = "shop",
		price = 600,
		style = "frost",
		color = Color3.fromRGB(150, 200, 235),
	},

	-- Verdict styles (Ace's arrest)
	{
		id = "verdict_gavel",
		kind = "verdict",
		name = "Final Gavel",
		blurb = "One strike of the gavel.",
		rarity = "rare",
		source = "shop",
		price = 300,
		style = "gavel",
		color = Color3.fromRGB(120, 78, 50),
	},
	{
		id = "verdict_cuffs",
		kind = "verdict",
		name = "Iron Cuffs",
		blurb = "Cuffs snap shut with a spark.",
		rarity = "rare",
		source = "shop",
		price = 350,
		style = "cuffs",
		color = Color3.fromRGB(190, 194, 204),
	},
	{
		id = "verdict_checkmate",
		kind = "verdict",
		-- (renamed so it doesn't share a name with the Bureau's Godhood win cutscene)
		name = "Endgame",
		blurb = "The king falls and cracks.",
		rarity = "epic",
		source = "shop",
		price = 650,
		style = "checkmate",
		color = Color3.fromRGB(40, 40, 44),
	},
	{
		id = "verdict_sugar",
		kind = "verdict",
		name = "Sugar Cubes",
		blurb = "The top sugar cube gets flicked off.",
		rarity = "legendary",
		source = "mastery",
		style = "sugar",
		color = Color3.fromRGB(244, 242, 236),
	},
	{
		id = "verdict_stamp",
		kind = "verdict",
		name = "Guilty Stamp",
		blurb = "GUILTY, stamped on their file.",
		rarity = "common",
		source = "shop",
		price = 200,
		style = "stamp",
		color = Color3.fromRGB(150, 152, 158),
	},
	{
		id = "verdict_lamp",
		kind = "verdict",
		name = "Interrogation Lamp",
		blurb = "One lamp, one chair, everything else dark.",
		rarity = "epic",
		source = "shop",
		price = 600,
		style = "lamp",
		color = Color3.fromRGB(255, 236, 190),
	},

	-- Death styles (what becomes of you, after the collapse)
	{
		id = "death_ash",
		kind = "death",
		name = "Ash to Ash",
		blurb = "Crumble into ash.",
		rarity = "rare",
		source = "shop",
		price = 300,
		style = "ash",
		color = Color3.fromRGB(120, 116, 112),
	},
	{
		id = "death_strings",
		kind = "death",
		name = "Cut Strings",
		blurb = "Drop like a puppet as the strings snap.",
		rarity = "epic",
		source = "shop",
		price = 550,
		style = "strings",
		color = Color3.fromRGB(214, 200, 176),
	},
	{
		id = "death_crows",
		kind = "death",
		name = "Murder of Crows",
		blurb = "Burst into a flock of crows.",
		rarity = "epic",
		source = "shop",
		price = 650,
		style = "crows",
		color = Color3.fromRGB(30, 30, 36),
	},
	{
		id = "death_stone",
		kind = "death",
		name = "Petrified",
		blurb = "Turn to stone, then crumble.",
		rarity = "legendary",
		source = "shop",
		price = 1200,
		style = "stone",
		color = Color3.fromRGB(150, 148, 142),
	},
	{
		id = "death_glass",
		kind = "death",
		name = "Shattered",
		blurb = "Shatter like glass.",
		rarity = "rare",
		source = "shop",
		price = 350,
		style = "glass",
		color = Color3.fromRGB(196, 214, 222),
	},

	-- Custom deaths (2026-10-25): a cause of death of your own to write in the Manual. Worn, it joins the three plain
	-- causes when you write; the death plays its own effect on the body as it falls, and the cause is read out.
	{
		id = "reason_fall",
		kind = "reason",
		name = "A Long Fall",
		blurb = "They trip on nothing.",
		cause = "A long fall",
		rarity = "common",
		source = "shop",
		price = 200,
		style = "fall",
		color = Color3.fromRGB(150, 146, 140),
	},
	{
		id = "reason_heart",
		kind = "reason",
		name = "A Broken Heart",
		blurb = "Their heart glows, cracks and goes out.",
		cause = "A broken heart",
		rarity = "rare",
		source = "shop",
		price = 400,
		style = "heart",
		color = Color3.fromRGB(205, 40, 60),
	},
	{
		id = "reason_frost",
		kind = "reason",
		name = "Frozen Where They Stood",
		blurb = "Frozen solid, then shattered.",
		cause = "Frozen where they stood",
		rarity = "rare",
		source = "shop",
		price = 450,
		style = "frost",
		color = Color3.fromRGB(170, 215, 245),
	},
	{
		id = "reason_chandelier",
		kind = "reason",
		name = "The Chandelier",
		blurb = "Crystal and dust from above.",
		cause = "A chandelier, from above",
		rarity = "rare",
		source = "shop",
		price = 450,
		style = "chandelier",
		color = Color3.fromRGB(235, 220, 170),
	},
	{
		id = "reason_drown",
		kind = "reason",
		name = "Drowned on Dry Land",
		blurb = "They drown in water that isn't there.",
		cause = "Drowned on dry land",
		rarity = "epic",
		source = "shop",
		price = 650,
		style = "drown",
		color = Color3.fromRGB(80, 150, 200),
	},
	{
		id = "reason_lightning",
		kind = "reason",
		name = "Struck by Lightning",
		blurb = "A bolt from a clear sky.",
		cause = "Struck by lightning",
		rarity = "epic",
		source = "shop",
		price = 700,
		style = "lightning",
		color = Color3.fromRGB(200, 225, 255),
	},
	{
		id = "reason_pages",
		kind = "reason",
		name = "A Thousand Paper Cuts",
		blurb = "A storm of torn pages.",
		cause = "A thousand paper cuts",
		rarity = "epic",
		source = "shop",
		price = 700,
		style = "pages",
		color = Color3.fromRGB(240, 234, 214),
	},
	{
		id = "reason_burn",
		kind = "reason",
		name = "Burned From Within",
		blurb = "Embers, then smoke.",
		cause = "Burned from within",
		rarity = "legendary",
		source = "shop",
		price = 1000,
		style = "burn",
		color = Color3.fromRGB(255, 120, 50),
	},
	{
		id = "reason_chip",
		kind = "reason",
		name = "Choked on a Potato Chip",
		blurb = "One crunch too many.",
		cause = "Choked on a potato chip",
		rarity = "legendary",
		source = "shop",
		price = 1100,
		style = "chip",
		color = Color3.fromRGB(240, 196, 90),
	},
	{
		id = "reason_clock",
		kind = "reason",
		name = "Their Time Ran Out",
		blurb = "The clock hits forty and stops.",
		cause = "Their time ran out",
		rarity = "legendary",
		source = "shop",
		price = 1200,
		style = "clock",
		color = Color3.fromRGB(210, 200, 170),
	},
	{
		id = "reason_dark",
		kind = "reason",
		name = "Taken by the Dark",
		blurb = "Shadows swallow them whole.",
		cause = "Taken by the dark",
		rarity = "legendary",
		source = "shop",
		price = 1500,
		style = "dark",
		color = Color3.fromRGB(150, 20, 34),
	},

	-- Emotes (`emote` is the clip). The Emote Pack pass still unlocks its four (`pass`).
	{
		id = "emote_groove",
		kind = "emote",
		category = "dance",
		name = "Groove",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "dance2",
		pass = "emotes",
	},
	{
		id = "emote_spin",
		kind = "emote",
		category = "dance",
		name = "Spin",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "dance3",
		pass = "emotes",
	},
	{
		id = "emote_chip",
		kind = "emote",
		category = "pose",
		name = "Potato chip",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "chip",
		pass = "emotes",
	},
	{
		id = "emote_think",
		kind = "emote",
		category = "pose",
		name = "Thinker",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "think",
		pass = "emotes",
	},
	{
		id = "emote_coin",
		kind = "emote",
		category = "prop",
		name = "Coin Flip",
		rarity = "common",
		source = "shop",
		price = 150,
		emote = "coinFlip",
	},
	{
		id = "emote_apple",
		kind = "emote",
		category = "prop",
		name = "Apple Bite",
		rarity = "rare",
		source = "shop",
		price = 300,
		emote = "appleBite",
	},
	{
		id = "emote_puppet",
		kind = "emote",
		category = "dance",
		name = "Puppet Dance",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "puppetDance",
	},
	{
		id = "emote_air",
		kind = "emote",
		category = "pose",
		name = "Write in the Air",
		rarity = "epic",
		source = "shop",
		price = 500,
		emote = "writeAir",
	},
	{
		id = "emote_crouch",
		kind = "emote",
		category = "pose",
		name = Terms.f("{Zero}'s Crouch"),
		rarity = "epic",
		source = "shop",
		price = 500,
		emote = "aceCrouch",
	},
	-- The emote pack (2026-10-14): dances. `added` dates them for the shop's "New" ribbon.
	{
		id = "emote_office_party",
		kind = "emote",
		category = "dance",
		name = "Office Party",
		rarity = "rare",
		source = "shop",
		price = 450,
		emote = "officeParty",
		added = "2026-10-14",
	},
	{
		id = "emote_two_legged_bop",
		kind = "emote",
		category = "dance",
		name = "Two-Legged Bop",
		rarity = "rare",
		source = "shop",
		price = 300,
		emote = "twoLeggedBop",
		added = "2026-10-14",
	},
	{
		id = "emote_boat_aura",
		kind = "emote",
		category = "dance",
		name = "Boat Aura",
		rarity = "rare",
		source = "rotation",
		price = 400,
		emote = "boatAura",
		face = "deadpan",
		added = "2026-10-14",
	},
	{
		id = "emote_jackpot_shuffle",
		kind = "emote",
		category = "dance",
		name = "Jackpot Shuffle",
		rarity = "rare",
		source = "rotation",
		price = 400,
		emote = "jackpotShuffle",
		added = "2026-10-14",
	},
	{
		id = "emote_the_classic",
		kind = "emote",
		category = "dance",
		name = "The Classic",
		rarity = "common",
		source = "shop",
		price = 200,
		emote = "theClassic",
		added = "2026-10-14",
	},
	{
		-- (sold as Floss for a few hours on 2026-10-14: the id stays, the owner swapped the dance)
		id = "emote_floss",
		kind = "emote",
		category = "dance",
		name = "The Smiling Lord",
		rarity = "rare",
		source = "shop",
		price = 400,
		emote = "smilingLord",
		added = "2026-10-14",
	},
	{
		id = "emote_bounce_pump",
		kind = "emote",
		category = "dance",
		name = "Bounce Pump",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "bouncePump",
		added = "2026-10-14",
	},
	{
		id = "emote_rat_dance",
		kind = "emote",
		category = "dance",
		name = "Rat Dance",
		rarity = "rare",
		source = "rotation",
		price = 300,
		emote = "ratDance",
		added = "2026-10-14",
	},
	{
		id = "emote_bunny_ears",
		kind = "emote",
		category = "dance",
		name = "Bunny Ears",
		rarity = "rare",
		source = "rotation",
		price = 300,
		emote = "bunnyEars",
		added = "2026-10-14",
	},
	{
		id = "emote_puppet_pop",
		kind = "emote",
		category = "dance",
		name = "Puppet Pop",
		rarity = "rare",
		source = "shop",
		price = 450,
		emote = "puppetPop",
		added = "2026-10-14",
	},
	{
		-- (sold as Jumpstyle for a few hours on 2026-10-14: the id stays, the owner swapped the dance)
		id = "emote_jumpstyle",
		kind = "emote",
		category = "dance",
		name = "Excuse Me, Sir",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "excuseMeSir",
		face = "smug",
		added = "2026-10-14",
	},
	{
		id = "emote_glitch_step",
		kind = "emote",
		category = "dance",
		name = "Glitch Step",
		rarity = "rare",
		source = "rotation",
		price = 350,
		emote = "glitchStep",
		added = "2026-10-14",
	},
	{
		id = "emote_goal_celebration",
		kind = "emote",
		category = "dance",
		name = "Goal Celebration",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "goalCelebration",
		added = "2026-10-14",
	},
	{
		id = "emote_take_the_l",
		kind = "emote",
		category = "dance",
		name = "Take the L",
		rarity = "common",
		source = "shop",
		price = 200,
		emote = "takeTheL",
		added = "2026-10-14",
	},
	{
		id = "emote_two_weeks_notice",
		kind = "emote",
		category = "dance",
		name = "Two Weeks' Notice",
		rarity = "common",
		source = "rotation",
		price = 250,
		emote = "twoWeeksNotice",
		added = "2026-10-14",
	},
	-- The emote pack: poses. `stance`: also a stance (stand still and you fall into it, push 5); `face`: an
	-- expression put on the head while it plays (Shared/EmoteMedia FACES).
	{
		id = "emote_impossible_lean",
		kind = "emote",
		category = "pose",
		name = "Impossible Lean",
		rarity = "rare",
		source = "shop",
		price = 400,
		emote = "impossibleLean",
		added = "2026-10-14",
	},
	{
		id = "emote_nah_id_win",
		kind = "emote",
		category = "pose",
		name = "Nah, I'd Win",
		rarity = "common",
		source = "shop",
		price = 250,
		emote = "nahIdWin",
		face = "smirk",
		stance = true,
		added = "2026-10-14",
	},
	{
		id = "emote_jawline_check",
		kind = "emote",
		category = "pose",
		name = "Jawline Check",
		rarity = "common",
		source = "shop",
		price = 200,
		emote = "jawlineCheck",
		face = "smug",
		added = "2026-10-14",
	},
	{
		id = "emote_the_eyebrow",
		kind = "emote",
		category = "pose",
		name = "The Eyebrow",
		rarity = "common",
		source = "shop",
		price = 200,
		emote = "theEyebrow",
		face = "raisedBrow",
		added = "2026-10-14",
	},
	{
		id = "emote_its_you",
		kind = "emote",
		category = "pose",
		name = "It's You",
		rarity = "rare",
		source = "mastery",
		emote = "itsYou",
		added = "2026-10-14",
	},
	{
		id = "emote_menacing_pose",
		kind = "emote",
		category = "pose",
		name = "Menacing Pose",
		rarity = "epic",
		source = "rotation",
		price = 500,
		emote = "menacingPose",
		added = "2026-10-14",
	},
	{
		-- (sold as Sus Lean for a few hours on 2026-10-14: the id stays, the owner swapped the dance)
		id = "emote_sus_lean",
		kind = "emote",
		category = "dance",
		name = "Animatronic Welcome",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "animatronicWelcome",
		face = "wideGrin",
		added = "2026-10-14",
	},
	{
		id = "emote_low_battery",
		kind = "emote",
		category = "pose",
		name = "Low Battery",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "lowBattery",
		lobbyOnly = true,
		added = "2026-10-14",
	},
	{
		id = "emote_deducing",
		kind = "emote",
		category = "pose",
		name = "Deducing",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "deducing",
		stance = true,
		added = "2026-10-14",
	},
	{
		id = "emote_just_as_planned",
		kind = "emote",
		category = "pose",
		name = "Just As Planned",
		rarity = "godhood",
		source = "mastery",
		emote = "justAsPlanned",
		face = "smirk",
		added = "2026-10-14",
	},
	{
		id = "emote_reapers_cackle",
		kind = "emote",
		category = "pose",
		name = "Reaper's Cackle",
		rarity = "rare",
		source = "mastery",
		emote = "reapersCackle",
		face = "wideGrin",
		added = "2026-10-14",
	},
	{
		id = "emote_final_breakdown",
		kind = "emote",
		category = "pose",
		name = "Final Breakdown",
		-- (Godhood, with its private cutscene, at 1500 since 2026-10-17: it was 650, and whoever bought it keeps it)
		rarity = "godhood",
		source = "shop",
		price = 1500,
		emote = "finalBreakdown",
		face = "wideGrin",
		added = "2026-10-14",
	},
	{
		id = "emote_new_world",
		kind = "emote",
		category = "pose",
		name = "New World",
		rarity = "godhood",
		source = "season",
		emote = "newWorld",
		added = "2026-10-14",
		-- (the Season ledger's last tier until season 1 ends; then in Today's hand)
		later = { from = "2026-11-25", price = 1200 },
	},
	{
		id = "emote_reapers_eyes",
		kind = "emote",
		category = "pose",
		name = "Reaper's Eyes",
		-- (Godhood, with its private cutscene, at 1500 since 2026-10-17: it was 600, and whoever bought it keeps it)
		rarity = "godhood",
		source = "shop",
		price = 1500,
		emote = "reapersEyes",
		face = "stare",
		lobbyOnly = true,
		added = "2026-10-14",
	},
	{
		id = "emote_foot_scratch",
		kind = "emote",
		category = "pose",
		name = "Foot Scratch",
		rarity = "common",
		source = "shop",
		price = 150,
		emote = "footScratch",
		stance = true,
		added = "2026-10-14",
	},
	{
		id = "emote_hair_twirl",
		kind = "emote",
		category = "pose",
		name = "Hair Twirl",
		rarity = "common",
		source = "shop",
		price = 200,
		emote = "hairTwirl",
		stance = true,
		added = "2026-10-14",
	},
	-- The emote pack: with props (Anim/EmoteProps). `alt`: another ending the server picks now and then
	-- (`altChance` of the time).
	{
		id = "emote_pre_dawn_bonk",
		kind = "emote",
		category = "prop",
		name = "Pre-Dawn Bonk",
		rarity = "epic",
		source = "rotation",
		price = 550,
		emote = "preDawnBonk",
		added = "2026-10-14",
	},
	{
		id = "emote_blindfold_lift",
		kind = "emote",
		category = "prop",
		name = "Blindfold Lift",
		rarity = "epic",
		source = "shop",
		price = 650,
		emote = "blindfoldLift",
		face = "stare",
		added = "2026-10-14",
	},
	{
		id = "emote_chair_perch",
		kind = "emote",
		category = "prop",
		name = "Chair Perch",
		rarity = "epic",
		source = "shop",
		price = 600,
		emote = "chairPerch",
		added = "2026-10-14",
	},
	{
		id = "emote_two_finger_grip",
		kind = "emote",
		category = "prop",
		name = "Two-Finger Grip",
		rarity = "rare",
		source = "shop",
		price = 350,
		emote = "twoFingerGrip",
		stance = true,
		added = "2026-10-14",
	},
	{
		id = "emote_sugar_tower",
		kind = "emote",
		category = "prop",
		name = "Sugar Tower",
		rarity = "epic",
		source = "shop",
		price = 550,
		emote = "sugarTower",
		added = "2026-10-14",
	},
	{
		id = "emote_chip_and_pen",
		kind = "emote",
		category = "prop",
		name = "Chip and Pen",
		rarity = "epic",
		source = "shop",
		price = 650,
		emote = "chipAndPen",
		added = "2026-10-14",
	},
	{
		id = "emote_furious_scribbling",
		kind = "emote",
		category = "prop",
		name = "Furious Scribbling",
		rarity = "rare",
		source = "shop",
		price = 400,
		emote = "furiousScribbling",
		alt = "furiousScribblingSlash",
		altChance = 1 / 3,
		added = "2026-10-14",
	},
	{
		id = "emote_apple_toss",
		kind = "emote",
		category = "prop",
		name = "Apple Toss",
		rarity = "rare",
		source = "achievement",
		emote = "appleToss",
		added = "2026-10-14",
	},
	{
		id = "emote_strawberry_on_top",
		kind = "emote",
		category = "prop",
		name = "Strawberry on Top",
		rarity = "epic",
		source = "mastery",
		emote = "strawberryOnTop",
		added = "2026-10-14",
	},
	{
		id = "emote_dice_tower",
		kind = "emote",
		category = "prop",
		name = "Dice Tower",
		rarity = "epic",
		source = "shop",
		price = 500,
		emote = "diceTower",
		added = "2026-10-14",
	},
	{
		id = "emote_chocolate_snap",
		kind = "emote",
		category = "prop",
		name = "Chocolate Snap",
		rarity = "rare",
		source = "shop",
		price = 400,
		emote = "chocolateSnap",
		added = "2026-10-14",
	},
	{
		id = "emote_forty_seconds",
		kind = "emote",
		category = "prop",
		name = "Forty Seconds",
		rarity = "rare",
		source = "mastery",
		emote = "fortySeconds",
		face = "stare",
		added = "2026-10-14",
	},
	-- The emote pack: strolls (`stroll`: your walk while it lasts, walking by itself at `pace`; the clip
	-- `<emote>Walk` is its walk).
	{
		id = "emote_the_long_climb",
		kind = "emote",
		category = "stroll",
		name = "The Long Climb",
		rarity = "legendary",
		source = "shop",
		price = 1000,
		emote = "theLongClimb",
		stroll = true,
		pace = 5, -- studs a second it walks by itself (Controllers/StrollWalker)
		face = "deadpan",
		added = "2026-10-14",
	},
	{
		id = "emote_parade_march",
		kind = "emote",
		category = "stroll",
		name = "Parade March",
		rarity = "legendary",
		source = "shop",
		price = 900,
		emote = "paradeMarch",
		stroll = true,
		pace = 5.5, -- studs a second it walks by itself (Controllers/StrollWalker)
		added = "2026-10-14",
	},
	{
		id = "emote_griddy",
		kind = "emote",
		category = "stroll",
		name = "Griddy",
		rarity = "legendary",
		source = "shop",
		price = 900,
		emote = "griddy",
		stroll = true,
		pace = 9, -- studs a second it walks by itself (Controllers/StrollWalker)
		added = "2026-10-14",
	},
	{
		id = "emote_mushroom_stroll",
		kind = "emote",
		category = "stroll",
		name = "Mushroom Stroll",
		rarity = "legendary",
		source = "shop",
		price = 1000,
		emote = "mushroomStroll",
		stroll = true,
		pace = 4.5, -- studs a second it walks by itself (Controllers/StrollWalker)
		added = "2026-10-14",
	},
	{
		id = "emote_not_my_problem",
		kind = "emote",
		category = "stroll",
		name = "Not My Problem",
		rarity = "legendary",
		source = "shop",
		price = 900,
		emote = "notMyProblem",
		stroll = true,
		pace = 4, -- studs a second it walks by itself (Controllers/StrollWalker)
		added = "2026-10-14",
	},
	-- The emote pack: duos (`duo`: played with the nearest player, who is asked first; DuoService).
	{
		id = "emote_match_point",
		kind = "emote",
		category = "duo",
		name = "Match Point",
		rarity = "legendary",
		source = "shop",
		price = 1200,
		emote = "matchPointServe",
		duo = true,
		added = "2026-10-14",
	},
	{
		id = "emote_cuffed_together",
		kind = "emote",
		category = "duo",
		name = "Cuffed Together",
		rarity = "legendary",
		source = "shop",
		price = 1100,
		emote = "cuffedLead",
		duo = true,
		lobbyOnly = true,
		added = "2026-10-14",
	},

	-- Win cutscenes (shop overhaul, 2026-10-21): what the ending shows when your side wins and you lead it (Diavolo
	-- for the Coven, Ace for the Bureau: for everyone), or on your own screen when another of your side leads. Each
	-- side has its own (`side`, worn in its own slot, `slot`); the free one is the ending as it always was. `cut` is
	-- the cutscene (Shared/Cinema/WinCuts), `clip` its star's move (the shop card's mannequin). Each paid one is told
	-- for the other side too (`cross`, the user's ask of 2026-10-27: a scene for both Ace and the Coven): it plays when
	-- the other side wins and its slot holds no paid scene of its own (CosmeticsService.winCut).
	{
		id = "win_coven_default",
		kind = "win",
		name = "The Coven's Night",
		rarity = "common",
		source = "free",
		side = "coven",
		slot = "winCoven",
		pose = "laugh", -- (its card's picture: Diavolo's pose in the ending, ActingController.endingPose)
		blurb = "The classic ending.",
		added = "2026-10-21",
	},
	{
		id = "win_coven_page",
		kind = "win",
		name = "The Final Page",
		rarity = "epic",
		source = "shop",
		price = 750,
		side = "coven",
		slot = "winCoven",
		cut = "finalPage",
		cross = "finalPageBureau",
		clip = "winFinalPage",
		card = 3.5, -- (the shop card's moment)
		blurb = "The Manual snaps shut and the candles go out.",
		added = "2026-10-21",
	},
	{
		id = "win_coven_god",
		kind = "win",
		name = "God of the New World",
		rarity = "godhood",
		source = "shop",
		price = 1500,
		side = "coven",
		slot = "winCoven",
		cut = "newWorld",
		cross = "newWorldBureau",
		clip = "winNewWorld",
		card = 7.0, -- (the shop card's moment)
		blurb = "A rooftop, a red sky, a city going dark.",
		added = "2026-10-21",
	},
	{
		id = "win_bureau_default",
		kind = "win",
		name = "The Bureau's Morning",
		rarity = "common",
		source = "free",
		side = "bureau",
		slot = "winBureau",
		pose = "cheer", -- (its card's picture: a winner's pose in the ending, Activities.VICTORY)
		blurb = Terms.f("The classic ending, with {Zero} in the spotlight."),
		added = "2026-10-21",
	},
	{
		id = "win_bureau_closed",
		kind = "win",
		name = "Case Closed",
		rarity = "epic",
		source = "shop",
		price = 750,
		side = "bureau",
		slot = "winBureau",
		cut = "caseClosed",
		cross = "caseClosedCoven",
		clip = "winCaseClosed",
		card = 6.8, -- (the shop card's moment)
		blurb = "The red string leads to one photo. Stamped.",
		added = "2026-10-21",
	},
	{
		id = "win_bureau_mate",
		kind = "win",
		name = "Checkmate",
		rarity = "godhood",
		source = "shop",
		price = 1500,
		side = "bureau",
		slot = "winBureau",
		cut = "checkmate",
		cross = "checkmateCoven",
		clip = "winCheckmate",
		card = 3.9, -- (the shop card's moment)
		blurb = "One finger tips the king over.",
		added = "2026-10-21",
	},

	-- Seats (shop overhaul, 2026-10-21): how you sit at the war table for a meeting and the vote (`clip`, a loop made
	-- for the war chair's seat, Shared/Seating), and the chair your place there becomes for everyone (`model`, a Core
	-- prop built to the same seat; `core` the Core version it came in: an older import keeps the war chair).
	{
		id = "seat_plain",
		kind = "seat",
		name = "Plain Seat",
		rarity = "common",
		source = "free",
		clip = "seatPlain",
		blurb = "Sit straight.",
		added = "2026-10-21",
	},
	{
		id = "seat_composed",
		kind = "seat",
		name = "The Calculating Seat",
		rarity = "rare",
		source = "shop",
		price = 300,
		clip = "seatComposed",
		blurb = "Arms folded, eyes on everyone.",
		added = "2026-10-21",
	},
	{
		id = "seat_ease",
		kind = "seat",
		name = "At Ease",
		rarity = "rare",
		source = "shop",
		price = 350,
		clip = "seatEase",
		blurb = "Lean back, legs crossed.",
		added = "2026-10-21",
	},
	{
		id = "seat_steepled",
		kind = "seat",
		name = "Steepled",
		rarity = "epic",
		source = "shop",
		price = 550,
		clip = "seatSteepled",
		blurb = "Fingertips together, perfectly still.",
		added = "2026-10-21",
	},
	{
		id = "seat_perched",
		kind = "seat",
		name = "Perched",
		rarity = "epic",
		source = "shop",
		price = 650,
		clip = "seatPerched",
		blurb = Terms.f("Crouch on the seat like {Zero}."),
		added = "2026-10-21",
	},
	{
		id = "seat_chin",
		kind = "seat",
		name = "Chin on Fist",
		rarity = "legendary",
		source = "shop",
		price = 900,
		clip = "seatChin",
		blurb = "Chin on fist, bored of everyone.",
		added = "2026-10-21",
	},
	{
		id = "chair_office",
		kind = "chair",
		name = "Bureau Office Chair",
		rarity = "rare",
		source = "shop",
		price = 400,
		model = "ChairOffice",
		core = 11,
		blurb = "A worn night shift swivel chair.",
		added = "2026-10-21",
	},
	{
		id = "chair_crate",
		kind = "chair",
		name = "Death God's Crate",
		rarity = "epic",
		source = "shop",
		price = 600,
		model = "ChairCrate",
		core = 11,
		blurb = "An apple crate with claw marks.",
		added = "2026-10-21",
	},
	{
		id = "chair_bone",
		kind = "chair",
		name = "Bone Chair",
		rarity = "legendary",
		source = "shop",
		price = 1000,
		model = "ChairBone",
		core = 11,
		blurb = "A chair made of bone.",
		added = "2026-10-21",
	},
	{
		id = "chair_throne",
		kind = "chair",
		name = Terms.f("{Hand}'s Throne"),
		rarity = "legendary",
		source = "shop",
		price = 1200,
		model = "ChairThrone",
		core = 11,
		blurb = "A black stone throne with a skull.",
		added = "2026-10-21",
	},

	-- Titles (lobby and results only)
	{ id = "title_trainee", kind = "title", name = "Trainee", rarity = "common", source = "achievement" },
	{ id = "title_detective", kind = "title", name = "Detective", rarity = "common", source = "shop", price = 150 },
	{ id = "title_insomniac", kind = "title", name = "Insomniac", rarity = "rare", source = "rotation", price = 300 },
	{ id = "title_vip", kind = "title", name = "Patron of the Arts", rarity = "epic", source = "vip" },
	-- Earned: a whole set (Shared/Sets)
	{ id = "title_set_noir", kind = "title", name = "Film Noir", rarity = "rare", source = "set" },
	{ id = "title_set_ivory", kind = "title", name = "Ivory Tower", rarity = "epic", source = "set" },
	{ id = "title_set_gilded", kind = "title", name = "Gilded Age", rarity = "legendary", source = "set" },
	{ id = "title_set_red", kind = "title", name = "Seeing Red", rarity = "epic", source = "set" },
	{ id = "title_set_ninelives", kind = "title", name = "Nine Lives", rarity = "legendary", source = "set" },
	-- (the emote sets)
	{ id = "title_set_desk", kind = "title", name = "Sweet Tooth", rarity = "epic", source = "set" },
	{ id = "title_set_successors", kind = "title", name = "Next in Line", rarity = "rare", source = "set" },
	{ id = "title_set_main", kind = "title", name = "Main Character", rarity = "legendary", source = "set" },
	{ id = "title_set_online", kind = "title", name = "Terminally Online", rarity = "legendary", source = "set" },
	{ id = "title_set_floor", kind = "title", name = "Floor Filler", rarity = "epic", source = "set" },
	-- Earned: the Season ledger (Progression/Ledger)
	{ id = "title_s1_bookkeeper", kind = "title", name = "Bookkeeper", rarity = "rare", source = "season" },
	{ id = "title_s1_accountant", kind = "title", name = "Death's Accountant", rarity = "epic", source = "season" },
	-- Earned: owning so many emotes (Progression/Collection)
	{ id = "title_c_mover", kind = "title", name = "Mover", rarity = "rare", source = "collection" },
	{ id = "title_c_showstopper", kind = "title", name = "Showstopper", rarity = "epic", source = "collection" },
	{
		id = "title_c_living_legend",
		kind = "title",
		name = "Living Legend",
		rarity = "legendary",
		source = "collection",
	},

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
	{ id = "title_inkstained", kind = "title", name = "Writer's Callus", rarity = "epic", source = "achievement" },
	{ id = "title_handcuffs", kind = "title", name = "Handcuffs", rarity = "epic", source = "achievement" },
	-- Earned: the seven grey apples hidden in the lobby
	{ id = "title_realmwalker", kind = "title", name = "Realm Walker", rarity = "rare", source = "achievement" },
	-- Earned: role mastery (levels 5 and 10)
	{ id = "title_m_hand", kind = "title", name = "Diavolo Incarnate", rarity = "epic", source = "mastery" },
	{ id = "title_m_cultist", kind = "title", name = "High Muerto", rarity = "epic", source = "mastery" },
	{ id = "title_m_zero", kind = "title", name = "Ace's Equal", rarity = "epic", source = "mastery" },
	{ id = "title_m_butler", kind = "title", name = "Head Butler", rarity = "epic", source = "mastery" },
	{ id = "title_m_agent", kind = "title", name = "Senior Operative", rarity = "epic", source = "mastery" },
	-- Level 10 of each role's mastery (the ties it gave left the game, 2026-10-21: the owner's drops)
	{ id = "title_m10_hand", kind = "title", name = "Diavolo Ascendant", rarity = "legendary", source = "mastery" },
	{ id = "title_m10_cultist", kind = "title", name = "The Last Devotee", rarity = "legendary", source = "mastery" },
	{ id = "title_m10_zero", kind = "title", name = "Ace of Aces", rarity = "legendary", source = "mastery" },
	{ id = "title_m10_butler", kind = "title", name = "The Butler Who Knew", rarity = "legendary", source = "mastery" },
	{ id = "title_m10_agent", kind = "title", name = "Operative of Record", rarity = "legendary", source = "mastery" },
	-- Earned: ranks
	{ id = "title_rank_2", kind = "title", name = "Patrol Officer", rarity = "common", source = "rank" },
	{ id = "title_rank_3", kind = "title", name = "Constable", rarity = "common", source = "rank" },
	{ id = "title_rank_4", kind = "title", name = "Inspector", rarity = "rare", source = "rank" },
	{ id = "title_rank_5", kind = "title", name = "Detective", rarity = "rare", source = "rank" },
	{ id = "title_rank_6", kind = "title", name = "Senior Detective", rarity = "epic", source = "rank" },
	{ id = "title_rank_7", kind = "title", name = "Chief Inspector", rarity = "epic", source = "rank" },
	{ id = "title_rank_8", kind = "title", name = "Legendary Detective", rarity = "legendary", source = "rank" },
} :: { Item }

Cosmetics.KINDS = {
	"grimoire",
	"specter",
	"title",
	"writing",
	"verdict",
	"death",
	"reason",
	"emote",
	"win",
	"seat",
	"chair",
}

Cosmetics.KIND_NAMES = {
	grimoire = "Manual covers",
	specter = "Deathsinger forms",
	title = "Titles",
	writing = "Writing styles",
	verdict = "Verdict styles",
	death = "Death styles",
	reason = "Custom deaths",
	emote = "Emotes",
	win = "Win cutscenes",
	seat = "Seats",
	chair = "Chairs",
}

-- The shop's suits ("Death's hand": the shop is a table of cards dealt by Death), in order, each with
-- its icon and the kinds it deals. Today's hand is the day's rotation (dealt face down, turned by
-- the player); Sets are the matching sets; Robux shows only once a product is on sale.
export type Suit = { id: string, name: string, icon: string, kinds: { string }? }
Cosmetics.SUITS = {
	{ id = "today", name = "Today's hand", icon = "cards" },
	{ id = "fate", name = "Fate", icon = "dice" },
	{ id = "ledger", name = "Ledger", icon = "note" },
	{ id = "wishlist", name = "Wishlist", icon = "heart" },
	{ id = "diavolo", name = Terms.f("{Hand}"), icon = "quill", kinds = { "writing", "grimoire" } },
	{ id = "ace", name = Terms.f("{Zero}"), icon = "zero", kinds = { "verdict" } },
	{ id = "dead", name = "The dead", icon = "skull", kinds = { "death", "specter" } },
	{ id = "reasons", name = "Custom deaths", icon = "grimoire", kinds = { "reason" } },
	{ id = "emotes", name = "Emotes", icon = "palm", kinds = { "emote" } },
	{ id = "wins", name = "Win cutscenes", icon = "flag", kinds = { "win" } },
	{ id = "seats", name = "Seats", icon = "podium", kinds = { "seat", "chair" } },
	{ id = "titles", name = "Titles", icon = "trophy", kinds = { "title" } },
	{ id = "sets", name = "Sets", icon = "set" },
	{ id = "robux", name = "Robux", icon = "coin" },
} :: { Suit }

-- The Emotes suit's sections, in order (an emote's `category`).
Cosmetics.EMOTE_CATEGORIES = {
	{ id = "dance", name = "Dances" },
	{ id = "pose", name = "Poses" },
	{ id = "prop", name = "With props" },
	{ id = "stroll", name = "Strolls" },
	{ id = "duo", name = "Duo" },
} :: { { id: string, name: string } }

-- One item of a kind ("Epic · Manual cover").
Cosmetics.KIND_SINGULAR = {
	hat = "Hat",
	tie = "Tie",
	grimoire = "Manual cover",
	specter = "Deathsinger form",
	title = "Title",
	writing = "Writing style",
	verdict = "Verdict style",
	death = "Death style",
	reason = "Custom death",
	emote = "Emote",
	win = "Win cutscene",
	seat = "Seat",
	chair = "Chair",
}

-- (the tiers, their names and colours live in Shared/Rarity)
Cosmetics.RARITIES = Rarity.ORDER
Cosmetics.RARITY_COLORS = Rarity.COLORS

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

-- A suit by id, or nil.
function Cosmetics.suit(id: string): Suit?
	for _, suit in ipairs(Cosmetics.SUITS) do
		if suit.id == id then
			return suit
		end
	end
	return nil
end

-- The suit an item is dealt in (by its kind), or nil.
function Cosmetics.suitOf(item: Item): Suit?
	for _, suit in ipairs(Cosmetics.SUITS) do
		if suit.kinds and table.find(suit.kinds, item.kind) then
			return suit
		end
	end
	return nil
end

-- The profile's `equipped` key an item is worn under: its kind, or its own slot (a win cutscene: one per side).
function Cosmetics.slotOf(item: Item): string
	return if type(item.slot) == "string" then item.slot else item.kind
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

-- The custom death worn with this style (its `cause` is what can be written), or nil.
function Cosmetics.reason(style: string?): Item?
	if not style then
		return nil
	end
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.kind == "reason" and item.style == style then
			return item
		end
	end
	return nil
end

-- The custom death whose cause is this text, or nil (a plain cause: heart attack, disease, accident).
function Cosmetics.reasonByCause(cause: string?): Item?
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.kind == "reason" and item.cause == cause then
			return item
		end
	end
	return nil
end

-- The emote item for a clip id (its own clip or its other ending, `alt`), or nil (the free emotes have none).
function Cosmetics.emote(clip: string): Item?
	for _, item in ipairs(Cosmetics.ITEMS) do
		if item.kind == "emote" and (item.emote == clip or item.alt == clip) then
			return item
		end
	end
	return nil
end

-- A thing sold only later (`later`): its price from its day on, else nil.
function Cosmetics.laterPrice(item: Item, unixTime: number): number?
	local later = item.later
	if type(later) ~= "table" or type(later.from) ~= "string" then
		return nil
	end
	local year, month, day = string.match(later.from, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
	if not year then
		return nil
	end
	local from = DateTime.fromUniversalTime(
		tonumber(year) :: number,
		tonumber(month) :: number,
		tonumber(day) :: number
	).UnixTimestamp
	return if unixTime >= from then later.price else nil
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
