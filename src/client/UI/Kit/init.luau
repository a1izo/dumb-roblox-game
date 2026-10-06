--!strict
-- The Death's Gambit design system ("Notch"): tokens, lettering, surfaces, controls, windows and layout.
-- Screens require this one module:
--
--   local Kit = require(UI.Kit)
--   local page, content = Kit.page({ tone = "black", Parent = x })
--   Kit.button({ text = "Play", variant = "primary" }, onClick)
--
-- See each child module for details. Kit.Textures.init() runs once at start.

local Base = require(script.Base)
local Controls = require(script.Controls)
local GlyphText = require(script.GlyphText)
local Icon = require(script.Icon)
local Layout = require(script.Layout)
local Ransom = require(script.Ransom)
local Slip = require(script.Slip)
local Surfaces = require(script.Surfaces)
local Textures = require(script.Textures)
local Tokens = require(script.Tokens)
local Window = require(script.Window)
local Glitch = require(script.Parent.Core.Glitch)

local Kit = {
	Base = Base,
	Controls = Controls,
	GlyphText = GlyphText,
	Icon = Icon,
	Layout = Layout,
	Ransom = Ransom,
	Glitch = Glitch,
	Slip = Slip,
	Surfaces = Surfaces,
	Textures = Textures,
	Tokens = Tokens,
	Window = Window,

	color = Tokens.color,
	size = Tokens.size,
	space = Tokens.space,

	-- primitives
	frame = Base.frame,
	label = Base.label,
	list = Base.list,
	grid = Base.grid,
	pad = Base.pad,
	scroll = Base.scroll,
	clear = Base.clear,
	counter = Base.counter,
	-- lettering and icons
	text = GlyphText.new,
	-- digits in equal slots (clocks, counts): the glyph text with `tabular` on
	num = function(props: { [string]: any })
		local p = table.clone(props)
		p.tabular = true
		p.face = p.face or "Head"
		return GlyphText.new(p)
	end,
	-- Aktura is set in mixed case (its capitals are ornate): "ROUND 2" becomes "Round 2"
	mixedCase = function(text: string): string
		if text ~= string.upper(text) then
			return text
		end
		return (
			string.gsub(text, "(%a)(%a*)", function(first: string, rest: string): string
				return string.upper(first) .. string.lower(rest)
			end)
		)
	end,
	-- ransom-note lettering (the game title and CASE CLOSED only)
	ransom = Ransom.new,
	-- the videotape glitch on loud elements
	glitch = Glitch.attach,
	icon = Icon.new,
	-- surfaces
	page = Surfaces.page,
	card = Surfaces.card,
	heading = Surfaces.heading,
	banner = Surfaces.banner,
	seal = Surfaces.seal,
	stamp = Surfaces.stamp,
	rule = Surfaces.rule,
	vignette = Surfaces.vignette,
	notch = Surfaces.notch,
	texture = Surfaces.texture,
	-- controls
	button = Controls.button,
	hold = Controls.hold,
	iconButton = Controls.iconButton,
	actionChip = Controls.actionChip,
	keycap = Controls.keycap,
	tabs = Controls.tabs,
	nameLine = Controls.nameLine,
	pickGrid = Controls.pickGrid,
	entry = Controls.entry,
	field = Controls.field,
	slider = Controls.slider,
	toggle = Controls.toggle,
	meter = Controls.meter,
	setEnabled = Controls.setEnabled,
	setText = Controls.setText,
	-- windows
	window = Window.new,
	register = Window.register,
	confirm = Window.confirm,
	slip = Slip.new,
}

return Kit
