--!strict
-- The Grimoire design system's tokens: every colour, type size, spacing step, stroke and motion
-- the UI uses. Screens never write a Color3 or a font by hand; they ask for a token.
--
-- Look: a black notebook in candlelight. Pages are near-black with faint rules, text is bone
-- white, red ink marks what matters (and only that), parchment is for the Agency's paperwork,
-- and pure white belongs to Zero alone. Titles are inked blackletter, names and notes are
-- scrawled by hand, and everything you read for longer than a glance is a calm serif.

local Tokens = {}

local rgb = Color3.fromRGB

-- Colour --------------------------------------------------------------------------------------

Tokens.color = {
	-- surfaces, back to front
	void = rgb(7, 7, 9), -- behind everything, scrims
	page = rgb(18, 16, 21), -- the black notebook page
	raised = rgb(28, 25, 32), -- cards and rows on a page
	lifted = rgb(40, 36, 45), -- hover, selected rows
	rule = rgb(236, 230, 218), -- ruled lines and hairlines (used at high transparency)
	-- text
	bone = rgb(236, 230, 218), -- main text on black
	dim = rgb(154, 148, 138), -- secondary text
	faint = rgb(98, 93, 88), -- disabled, placeholders
	ink = rgb(20, 18, 22), -- text on parchment and white
	inkDim = rgb(84, 76, 70),
	-- ink colours
	blood = rgb(142, 14, 22), -- dark red: fills, pressed states
	red = rgb(224, 32, 43), -- primary action, focus, the Hand
	parchment = rgb(216, 205, 180), -- case files, the Agency's documents
	parchmentDark = rgb(170, 156, 128),
	white = rgb(246, 246, 244), -- Zero's screen only
	candle = rgb(217, 164, 65), -- coins, rare things, warm light
	steel = rgb(111, 143, 181), -- the Agency
	specter = rgb(156, 200, 214), -- ghosts
	-- feedback
	good = rgb(112, 178, 120),
	warn = rgb(222, 170, 70),
	bad = rgb(224, 32, 43),
	secret = rgb(170, 110, 220),
}

-- Rarity edges for shop cards (desaturated to sit on black).
Tokens.rarity = {
	Common = rgb(150, 146, 138),
	Uncommon = rgb(112, 170, 120),
	Rare = rgb(104, 144, 210),
	Epic = rgb(168, 110, 214),
	Legendary = rgb(217, 164, 65),
	Mythic = rgb(224, 32, 43),
}

-- Transparency steps for layered surfaces.
Tokens.alpha = {
	scrim = 0.35, -- dimmed backdrop behind a modal
	glass = 0.12, -- HUD pieces over the world
	rule = 0.9, -- ruled lines
	hairline = 0.8,
	disabled = 0.55,
}

-- Type ---------------------------------------------------------------------------------------

-- Glyph faces (Kit/GlyphText) for lettering; each has a Roblox font to fall back on.
Tokens.face = {
	display = "Gothic", -- Death's Gambit Gothic: titles, phases, role names
	hand = "Scrawl", -- Specter Scrawl: names, captions, notes
}

local MERRIWEATHER = "rbxasset://fonts/families/Merriweather.json"
local SPECIAL_ELITE = "rbxasset://fonts/families/SpecialElite.json"
local ROBOTO_MONO = "rbxasset://fonts/families/RobotoMono.json"
local GRENZE = "rbxasset://fonts/families/GrenzeGotisch.json"
local AMATIC = "rbxasset://fonts/families/AmaticSC.json"

-- Real fonts for text that is read, not admired.
Tokens.font = {
	body = Font.new(MERRIWEATHER, Enum.FontWeight.Regular),
	bodyBold = Font.new(MERRIWEATHER, Enum.FontWeight.Bold),
	bodyItalic = Font.new(MERRIWEATHER, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	label = Font.new(MERRIWEATHER, Enum.FontWeight.Bold), -- small caps labels (upper-cased)
	document = Font.new(SPECIAL_ELITE), -- typewritten case files
	mono = Font.new(ROBOTO_MONO, Enum.FontWeight.Medium), -- timers, counts
	-- fallbacks for the glyph faces
	display = Font.new(GRENZE, Enum.FontWeight.Bold),
	hand = Font.new(AMATIC, Enum.FontWeight.Bold),
}

-- Type scale (px at desktop size).
Tokens.size = {
	micro = 12,
	small = 14,
	body = 16,
	lead = 20,
	title = 26,
	heading = 34,
	display = 48,
	hero = 72,
}

-- Space and shape ------------------------------------------------------------------------------

Tokens.space = {
	xxs = 2,
	xs = 4,
	s = 8,
	m = 12,
	l = 16,
	xl = 24,
	xxl = 32,
	xxxl = 48,
}

Tokens.radius = {
	paper = 0, -- pages, cards, banners
	key = 2, -- keycaps, small controls
	round = 999, -- seals, dots
}

Tokens.stroke = {
	hair = 1,
	line = 2,
	bold = 3,
}

-- Minimum size of anything you tap or click.
Tokens.touch = 48

-- Rule spacing on notebook pages (px).
Tokens.ruleGap = 30

-- Motion --------------------------------------------------------------------------------------

Tokens.motion = {
	quick = 0.12,
	base = 0.2,
	slow = 0.35,
	scene = 0.6,
}

-- Named easings: "ink" spreads in, "page" turns with a small overshoot, "slam" hits hard.
Tokens.ease = {
	ink = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
	page = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
	slam = { Enum.EasingStyle.Exponential, Enum.EasingDirection.In },
	fade = { Enum.EasingStyle.Sine, Enum.EasingDirection.InOut },
}

-- Layers inside one ScreenGui (ZIndex with Sibling behaviour).
Tokens.z = {
	base = 1,
	raised = 5,
	overlay = 20,
	top = 50,
}

-- Modal window sizes at desktop scale.
Tokens.modal = {
	S = Vector2.new(420, 300), -- dialogs
	sheet = Vector2.new(500, 440), -- a single sheet of paper (notes, the tip box)
	M = Vector2.new(620, 560), -- one page
	L = Vector2.new(1040, 640), -- a book spread
}

-- Roles and sides (public names come from Terms; these are only colours).
Tokens.side = {
	Team = Tokens.color.steel,
	Kira = Tokens.color.red,
}

return Tokens
