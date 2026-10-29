--!strict
-- Death's Gambit's design tokens: every colour, type size, spacing step, stroke and motion the UI uses.
-- Screens never write a Color3 or a font by hand; they ask for a token.
--
-- Look (concept A, "paper, ink, blood", the owner's pick 2026-10-29): the HUD is ink over the world, menus are paper
-- sheets with ink lettering (Kit/Paper turns a window's dark ramp into the paper one), and red is used for danger, the
-- pointing hand and a chosen target only. Drawn lines and big lettering boil (Kit/Boil). Big titles are lowercase
-- Gotham Heavy with a full stop, names are Melodrama, text is Arimo and data is Roboto Mono (both built into Roblox).

local Tokens = {}

local rgb = Color3.fromRGB

-- Colour --------------------------------------------------------------------------------------

Tokens.color = {
	-- the ink ramp, darkest to lightest (warm, like toner on paper)
	g0 = rgb(14, 14, 14),
	g1 = rgb(24, 23, 22),
	g2 = rgb(33, 32, 30),
	g3 = rgb(47, 46, 43),
	g4 = rgb(74, 72, 68),
	g5 = rgb(122, 118, 111),
	g6 = rgb(167, 162, 154),
	white = rgb(232, 228, 220), -- paper: text on the dark, the main button's frame, menu sheets
	-- meaning
	accent = rgb(232, 228, 220), -- what you act on (paper on the dark, ink on paper; never red)
	danger = rgb(210, 30, 30), -- danger, the pointing hand, the chosen target
	dangerDark = rgb(120, 14, 16),

	-- Names from the older kit, kept so every screen keeps working. Prefer the ramp above.
	void = rgb(14, 14, 14),
	page = rgb(24, 23, 22),
	raised = rgb(33, 32, 30),
	lifted = rgb(47, 46, 43),
	rule = rgb(232, 228, 220),
	bone = rgb(232, 228, 220),
	dim = rgb(167, 162, 154),
	faint = rgb(122, 118, 111),
	ink = rgb(18, 18, 18),
	inkDim = rgb(80, 77, 72),
	blood = rgb(120, 14, 16),
	red = rgb(210, 30, 30),
	parchment = rgb(222, 218, 209),
	parchmentDark = rgb(196, 191, 180),
	candle = rgb(167, 162, 154),
	steel = rgb(167, 162, 154),
	specter = rgb(167, 162, 154),
	-- feedback
	good = rgb(232, 228, 220),
	warn = rgb(210, 30, 30),
	bad = rgb(210, 30, 30),
	secret = rgb(167, 162, 154),
}

-- The same ramp on paper (a menu sheet), lightest to darkest: Kit/Paper swaps each ink-ramp colour for its partner
-- here, so a screen written for the dark reads as ink on paper without being rewritten.
Tokens.paper = {
	g0 = rgb(232, 228, 220), -- the sheet itself
	g1 = rgb(222, 218, 209),
	g2 = rgb(212, 207, 197),
	g3 = rgb(196, 191, 180),
	g4 = rgb(160, 155, 146),
	g5 = rgb(120, 116, 109),
	g6 = rgb(80, 77, 72),
	white = rgb(18, 18, 18), -- ink
}

-- (Rarity's colours and names, and how a shop card wears each tier, are in Shared/Rarity and UI/Shop/Card.)

-- Transparency steps for layered surfaces.
Tokens.alpha = {
	scrim = 0.35, -- dimmed backdrop behind a modal
	glass = 0.14, -- HUD panels over the world
	rule = 0.88, -- hairlines
	hairline = 0.76,
	disabled = 0.55,
	scan = 0.94, -- the scanline texture over a panel
	grain = 0.93, -- the film-grain texture over a panel
}

-- Type ---------------------------------------------------------------------------------------

-- Glyph faces (Kit/GlyphText), each an atlas drawn from a Fontshare font. Every size is the on-screen
-- font size in px. Melodrama is only drawn at 30 px and up (GlyphText.MIN_ATLAS); below that the same
-- text is a real Montserrat label (Core/FontMirror and GlyphText switch over by themselves).
Tokens.face = {
	title = "Title", -- Aktura: the game title, CASE CLOSED, big slams. Mixed case only, never all caps.
	display = "Head", -- Melodrama Bold: headings, buttons, menu items, names, numbers
	hand = "Semi", -- Melodrama Semibold: the lighter heading weight
}

local ARIMO = "rbxasset://fonts/families/Arimo.json"
local MONO = "rbxasset://fonts/families/RobotoMono.json"
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"

-- Real fonts: all text under 30 px (GlyphText.MIN_ATLAS), typing, chat, and the stand-in until the glyph atlases are
-- imported. Arimo for reading, Roboto Mono for data (clocks, counts, captions), Gotham Heavy for big lowercase titles.
Tokens.font = {
	body = Font.new(ARIMO, Enum.FontWeight.Bold),
	bodyBold = Font.new(ARIMO, Enum.FontWeight.Bold),
	bodyItalic = Font.new(ARIMO, Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	label = Font.new(ARIMO, Enum.FontWeight.Bold), -- labels, tabs, buttons (spaced capitals)
	document = Font.new(ARIMO, Enum.FontWeight.Regular), -- reading text and fields
	mono = Font.new(MONO, Enum.FontWeight.Regular), -- data: clocks, counts, captions, timestamps
	monoBold = Font.new(MONO, Enum.FontWeight.Bold),
	-- big lowercase titles ("shop."), and every heading under 30 px
	title = Font.new(GOTHAM, Enum.FontWeight.Heavy),
	display = Font.new(GOTHAM, Enum.FontWeight.Heavy),
	hand = Font.new(ARIMO, Enum.FontWeight.Bold),
}

-- Type scale (px at desktop size).
Tokens.size = {
	micro = 13,
	small = 15,
	body = 17,
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

-- Everything is square-edged; clipped corners come from the Notch images, not from rounding.
Tokens.radius = {
	paper = 0, -- panels, cards, banners
	key = 0, -- keycaps, small controls
	round = 999, -- dots
}

Tokens.stroke = {
	hair = 1,
	line = 2,
	bold = 3,
}

-- Minimum size of anything you tap or click.
Tokens.touch = 48

-- The clipped corner of each Notch shape (px on screen); the images are drawn to match.
Tokens.notch = {
	panel = 14, -- bottom right
	button = 12, -- top right
	window = 18, -- top right and bottom left
}

-- Motion --------------------------------------------------------------------------------------

Tokens.motion = {
	quick = 0.12,
	base = 0.2,
	slow = 0.35,
	scene = 0.6,
}

-- The videotape glitch on the few loud lobby elements: a stepped entrance, then a short blip every few seconds.
Tokens.glitch = {
	enter = 0.5, -- seconds of the entrance
	blip = 0.15, -- seconds of one loop glitch
	period = 6, -- average seconds between blips (each element varies about 5 to 6.6)
	shift = 9, -- px of sideways jitter at most
}

-- Named easings: hard cuts for the glitch, "snap" for things that land, "slam" for the biggest hits.
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

-- Notices: every small card over the world (toasts, the guide's tips, the Trial's step, the daily streak,
-- the lobby's profile card) has one width, one padding, one solid surface and one accent edge, so the right
-- column lines up and nothing reads as a different kit (Kit/Notice).
Tokens.notice = {
	width = 340,
	phoneWidth = 280,
	padding = Tokens.space.xl, -- (inside the OMORI frame, which sits 6 px in)
	gap = Tokens.space.s,
	edge = 3, -- px of the accent line down the left
	alpha = 0, -- solid: text must read over bright snow
	titleSize = 24,
	actionHeight = 40,
}

-- Modal window sizes at desktop scale.
Tokens.modal = {
	S = Vector2.new(420, 300), -- dialogs
	sheet = Vector2.new(500, 440), -- a single sheet (notes)
	M = Vector2.new(620, 560), -- one page
	L = Vector2.new(1040, 640), -- a spread
}

-- Roles and sides (public names come from Terms; these are only colours).
Tokens.side = {
	Team = Tokens.color.g6,
	Kira = Tokens.color.danger,
}

return Tokens
