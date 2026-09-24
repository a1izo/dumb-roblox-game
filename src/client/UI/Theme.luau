-- Design tokens for the noir UI: colours, fonts, type sizes, spacing, corner radii and
-- motion timings. Every panel reads from here; nothing else should hard-code a colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Terms = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terms"))

local Theme = {}

Theme.colors = {
	-- surfaces, from the back to the front
	backdrop = Color3.fromRGB(5, 5, 8),
	panel = Color3.fromRGB(15, 15, 20),
	panelLight = Color3.fromRGB(28, 28, 36),
	raised = Color3.fromRGB(38, 38, 48),
	button = Color3.fromRGB(38, 38, 48),
	buttonHover = Color3.fromRGB(54, 54, 66),
	stroke = Color3.fromRGB(66, 64, 78),
	strokeStrong = Color3.fromRGB(120, 112, 96),
	-- text
	text = Color3.fromRGB(238, 233, 224),
	muted = Color3.fromRGB(150, 145, 138),
	faint = Color3.fromRGB(96, 92, 88),
	-- accents
	accent = Color3.fromRGB(190, 28, 42), -- ink red
	accentHover = Color3.fromRGB(214, 44, 58),
	gold = Color3.fromRGB(214, 182, 110),
	focus = Color3.fromRGB(236, 206, 132),
	team = Color3.fromRGB(96, 156, 240),
	hand = Color3.fromRGB(215, 35, 50),
	good = Color3.fromRGB(96, 198, 128),
	bad = Color3.fromRGB(232, 84, 74),
	warn = Color3.fromRGB(232, 172, 72),
	secret = Color3.fromRGB(200, 132, 250),
	-- paper and ink documents
	paper = Color3.fromRGB(240, 233, 214),
	paperDark = Color3.fromRGB(221, 210, 186),
	ink = Color3.fromRGB(26, 24, 22),
	inkMuted = Color3.fromRGB(88, 80, 70),
	deathNote = Color3.fromRGB(9, 9, 11),
}

Theme.fonts = {
	body = Enum.Font.Gotham,
	medium = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	black = Enum.Font.GothamBlack,
	typewriter = Enum.Font.SpecialElite,
	mono = Enum.Font.Code,
	gothic = Enum.Font.GrenzeGotisch,
	hand = Enum.Font.Kalam,
}

-- Type scale in pixels (before the per-device UIScale).
Theme.text = {
	caption = 12,
	small = 13,
	body = 15,
	bodyLarge = 17,
	title = 20,
	heading = 28,
	display = 44,
}

Theme.space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }

Theme.radius = { sm = 4, md = 8, lg = 12, pill = 999 }

-- Seconds; Motion turns them to 0 when the player asks for reduced motion.
Theme.motion = { fast = 0.12, base = 0.2, slow = 0.35 }

-- Display names live in Terms; these aliases keep older panels working.
Theme.PHASE_NAMES = Terms.PHASE
Theme.STATUS_NAMES = Terms.STATUS

Theme.TONES = {
	neutral = Theme.colors.text,
	danger = Theme.colors.bad,
	team = Theme.colors.team,
	kira = Theme.colors.hand,
}

Theme.TOAST_COLORS = {
	info = Theme.colors.text,
	good = Theme.colors.good,
	bad = Theme.colors.bad,
	secret = Theme.colors.secret,
}

return Theme
