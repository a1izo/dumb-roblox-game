-- Design tokens for the Inkbound UI, "angular manga" style: ink black, paper white and one
-- red, sharp corners, slanted shapes and bold condensed type (Oswald). Every panel reads
-- from here; nothing else should hard-code a colour or a font.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Terms = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terms"))

local Theme = {}

local INK = Color3.fromRGB(11, 11, 13)
local PAPER = Color3.fromRGB(244, 241, 234)
local RED = Color3.fromRGB(209, 26, 42)

Theme.colors = {
	-- surfaces
	backdrop = Color3.fromRGB(6, 6, 8),
	panel = Color3.fromRGB(13, 13, 16),
	panelLight = Color3.fromRGB(28, 28, 34),
	raised = Color3.fromRGB(38, 38, 46),
	button = Color3.fromRGB(18, 18, 22),
	buttonHover = PAPER,
	stroke = Color3.fromRGB(46, 46, 54),
	strokeStrong = PAPER,
	-- text
	text = PAPER,
	muted = Color3.fromRGB(154, 150, 142),
	faint = Color3.fromRGB(96, 92, 88),
	-- accents: red is the only loud colour; the rest are used sparingly
	accent = RED,
	accentHover = Color3.fromRGB(240, 37, 55),
	gold = PAPER,
	focus = RED,
	team = Color3.fromRGB(62, 139, 255),
	hand = RED,
	good = Color3.fromRGB(63, 201, 122),
	bad = Color3.fromRGB(255, 59, 59),
	warn = Color3.fromRGB(255, 176, 46),
	secret = Color3.fromRGB(176, 108, 255),
	-- paper and ink documents
	paper = PAPER,
	paperDark = Color3.fromRGB(226, 220, 205),
	ink = INK,
	inkMuted = Color3.fromRGB(85, 81, 75),
	deathNote = Color3.fromRGB(6, 6, 7),
}

Theme.fonts = {
	body = Enum.Font.Gotham,
	medium = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	-- headings everywhere: condensed and loud
	black = Enum.Font.Oswald,
	display = Enum.Font.Oswald,
	typewriter = Enum.Font.SpecialElite,
	mono = Enum.Font.Code,
	gothic = Enum.Font.GrenzeGotisch,
	hand = Enum.Font.Kalam,
}

-- Font faces with weights, for the loudest text (set FontFace instead of Font).
local OSWALD = "rbxasset://fonts/families/Oswald.json"
Theme.faces = {
	display = Font.new(OSWALD, Enum.FontWeight.Bold),
	displayMedium = Font.new(OSWALD, Enum.FontWeight.Medium),
}

-- Type scale in pixels (before the per-device UIScale).
Theme.text = {
	caption = 12,
	small = 13,
	body = 15,
	bodyLarge = 17,
	title = 22,
	heading = 30,
	display = 48,
}

Theme.space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }

-- The style is sharp-edged: corners are square everywhere.
Theme.radius = { sm = 0, md = 0, lg = 0, pill = 0 }

-- How far panels and buttons lean (the slant), and the tilt of ribbons in degrees.
Theme.slant = 0.035
Theme.tilt = -3

-- Seconds; Motion turns them to 0 when the player asks for reduced motion.
Theme.motion = { fast = 0.12, base = 0.2, slow = 0.35 }

-- Display names live in Terms; these aliases keep older panels working.
Theme.PHASE_NAMES = Terms.PHASE
Theme.STATUS_NAMES = Terms.STATUS

Theme.TONES = {
	neutral = PAPER,
	danger = RED,
	team = Theme.colors.team,
	kira = RED,
}

Theme.TOAST_COLORS = {
	info = PAPER,
	good = Theme.colors.good,
	bad = Theme.colors.bad,
	secret = Theme.colors.secret,
}

return Theme
