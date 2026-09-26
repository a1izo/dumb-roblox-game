--!strict
-- The Grimoire design system: tokens, lettering, surfaces, controls, windows and layout.
-- Screens require this one module:
--
--   local Kit = require(UI.Kit)
--   local page, content = Kit.page({ tone = "parchment", Parent = x })
--   Kit.button({ text = "Play", variant = "primary" }, onClick)
--
-- See each child module for details. Kit.Textures.init() runs once at start.

local Base = require(script.Base)
local Controls = require(script.Controls)
local GlyphText = require(script.GlyphText)
local Icon = require(script.Icon)
local Layout = require(script.Layout)
local Slip = require(script.Slip)
local Surfaces = require(script.Surfaces)
local Textures = require(script.Textures)
local Tokens = require(script.Tokens)
local Window = require(script.Window)

local Kit = {
	Base = Base,
	Controls = Controls,
	GlyphText = GlyphText,
	Icon = Icon,
	Layout = Layout,
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
	icon = Icon.new,
	-- surfaces
	page = Surfaces.page,
	banner = Surfaces.banner,
	seal = Surfaces.seal,
	stamp = Surfaces.stamp,
	rule = Surfaces.rule,
	vignette = Surfaces.vignette,
	-- controls
	button = Controls.button,
	hold = Controls.hold,
	iconButton = Controls.iconButton,
	actionChip = Controls.actionChip,
	keycap = Controls.keycap,
	tabs = Controls.tabs,
	nameLine = Controls.nameLine,
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
