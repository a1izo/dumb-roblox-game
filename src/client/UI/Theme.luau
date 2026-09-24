-- Colours, fonts and display names for the noir UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Terms = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Terms"))

local Theme = {}

Theme.colors = {
	backdrop = Color3.fromRGB(6, 6, 9),
	panel = Color3.fromRGB(20, 20, 26),
	panelLight = Color3.fromRGB(34, 34, 43),
	button = Color3.fromRGB(44, 44, 55),
	buttonHover = Color3.fromRGB(60, 60, 74),
	stroke = Color3.fromRGB(78, 78, 92),
	text = Color3.fromRGB(236, 234, 228),
	muted = Color3.fromRGB(152, 150, 145),
	accent = Color3.fromRGB(200, 38, 50),
	team = Color3.fromRGB(90, 160, 255),
	good = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(235, 85, 75),
	secret = Color3.fromRGB(205, 130, 255),
	gold = Color3.fromRGB(220, 188, 110),
	paper = Color3.fromRGB(242, 236, 220),
	ink = Color3.fromRGB(28, 26, 24),
	deathNote = Color3.fromRGB(10, 10, 12),
}

Theme.fonts = {
	body = Enum.Font.Gotham,
	medium = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	black = Enum.Font.GothamBlack,
	typewriter = Enum.Font.SpecialElite,
	mono = Enum.Font.Code,
	gothic = Enum.Font.GrenzeGotisch,
}

-- Display names live in Terms; these aliases keep older panels working.
Theme.PHASE_NAMES = Terms.PHASE
Theme.STATUS_NAMES = Terms.STATUS

Theme.TONES = {
	neutral = Color3.fromRGB(236, 234, 228),
	danger = Color3.fromRGB(235, 70, 70),
	team = Color3.fromRGB(110, 175, 255),
	kira = Color3.fromRGB(215, 35, 50),
}

Theme.TOAST_COLORS = {
	info = Color3.fromRGB(236, 234, 228),
	good = Color3.fromRGB(110, 215, 140),
	bad = Color3.fromRGB(240, 100, 90),
	secret = Color3.fromRGB(210, 145, 255),
}

return Theme
