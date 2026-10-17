--!strict
-- Death's Gambit's design tokens: every colour, type size, spacing step, stroke and motion the UI uses.
-- Screens never write a Color3 or a font by hand; they ask for a token.
--
-- Look ("Notch"): black and cold grey panels with one clipped corner, white for what you act on, and
-- red ONLY for danger (deaths, Diavolo, Death's Gambit, the vote target, the last 10 seconds, warnings).
-- Big titles are Aktura, headings and numbers are Melodrama (both drawn from glyph atlases because
-- Roblox cannot load custom fonts), and small text is Montserrat, which Roblox ships. Ace's surfaces
-- (desk, feed, warrant) are the only black-on-white panels in the game.

local Tokens = {}

local rgb = Color3.fromRGB

-- Colour --------------------------------------------------------------------------------------

Tokens.color = {
	-- the grey ramp, dark to light (cold, to sit with the night maps)
	g0 = rgb(8, 9, 11),
	g1 = rgb(15, 17, 21),
	g2 = rgb(23, 26, 32),
	g3 = rgb(35, 39, 47),
	g4 = rgb(58, 64, 75),
	g5 = rgb(107, 115, 128),
	g6 = rgb(163, 170, 181),
	white = rgb(244, 245, 247), -- text, selection, the main button; Ace's panels
	-- meaning
	accent = rgb(244, 245, 247), -- what you act on or what is selected (white, never red)
	danger = rgb(225, 17, 43), -- danger only
	dangerDark = rgb(125, 10, 24),

	-- Names from the older kit, kept so every screen keeps working. Prefer the ramp above.
	void = rgb(8, 9, 11), -- behind everything, scrims
	page = rgb(15, 17, 21), -- a panel
	raised = rgb(23, 26, 32), -- cards and rows on a panel
	lifted = rgb(35, 39, 47), -- hover, selected rows
	rule = rgb(244, 245, 247), -- hairlines (used at high transparency)
	bone = rgb(244, 245, 247), -- main text on dark
	dim = rgb(163, 170, 181), -- secondary text
	faint = rgb(107, 115, 128), -- disabled, placeholders
	ink = rgb(8, 9, 11), -- text on white (Ace) and on the light puzzle paper
	inkDim = rgb(91, 99, 112),
	blood = rgb(125, 10, 24), -- dark red: danger fills, pressed danger
	red = rgb(225, 17, 43), -- DANGER ONLY
	parchment = rgb(190, 196, 205), -- the light paper inside puzzles (documents, prints)
	parchmentDark = rgb(150, 158, 170),
	candle = rgb(163, 170, 181), -- coins and rare things (no gold any more)
	steel = rgb(163, 170, 181), -- the Bureau
	specter = rgb(163, 170, 181), -- Deathsingers
	-- feedback
	good = rgb(244, 245, 247),
	warn = rgb(225, 17, 43),
	bad = rgb(225, 17, 43),
	secret = rgb(163, 170, 181),
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
-- font size in px. Melodrama is only drawn at 22 px and up (GlyphText.MIN_ATLAS); below that the same
-- text is a real Montserrat label (Core/FontMirror and GlyphText switch over by themselves).
Tokens.face = {
	title = "Title", -- Aktura: the game title, CASE CLOSED, big slams. Mixed case only, never all caps.
	display = "Head", -- Melodrama Bold: headings, buttons, menu items, names, numbers
	hand = "Semi", -- Melodrama Semibold: the lighter heading weight
}

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

-- Real fonts: all text under 22 px, typing, chat, and the stand-in until the glyph atlases are imported.
-- SemiBold reads cleanly on the dark panels at small sizes.
Tokens.font = {
	body = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
	bodyBold = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
	bodyItalic = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold, Enum.FontStyle.Italic),
	label = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold), -- labels and tabs
	document = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold), -- reading text and fields
	mono = Font.new(MONTSERRAT, Enum.FontWeight.Bold), -- counts; the HUD uses Kit.num digits instead
	-- fallbacks for the glyph faces
	title = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
	display = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
	hand = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
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

-- Modal window sizes at desktop scale.
Tokens.modal = {
	S = Vector2.new(420, 300), -- dialogs
	sheet = Vector2.new(500, 440), -- a single sheet (notes, the tip box)
	M = Vector2.new(620, 560), -- one page
	L = Vector2.new(1040, 640), -- a spread
}

-- Roles and sides (public names come from Terms; these are only colours).
Tokens.side = {
	Team = Tokens.color.g6,
	Kira = Tokens.color.danger,
}

return Tokens
