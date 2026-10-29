--!strict
-- Windows are paper sheets over the darkened, blurred world (concept A, 2026-10-29): a huge lowercase title with a
-- full stop, an ink rule, a Back button, a body and an optional footer. Screens write
-- for the dark as before and Kit/Paper turns the sheet to ink on paper. Each frees the mouse while it is open.
-- Windows never glitch: what is in them has to be read.
--
--   local win = Window.new({ name = "settings", title = "Settings", size = "M" })
--   ... build into win.body, put buttons in win.footer ...
--   Window.register(win, { allowed = function(view) return true end })
--   Router.open("settings")
--
-- Dialogs ask one question on top of everything: Window.confirm({ ... }).

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Motion = require(script.Parent.Parent.Core.Motion)
local Router = require(script.Parent.Parent.Core.Router)
local Screens = require(script.Parent.Parent.Screens)
local Base = require(script.Parent.Base)
local Controls = require(script.Parent.Controls)
local GlyphText = require(script.Parent.GlyphText)
local Layout = require(script.Parent.Layout)
local Boil = require(script.Parent.Boil)
local Paper = require(script.Parent.Paper)
local Surfaces = require(script.Parent.Surfaces)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Window = {}

export type Options = {
	name: string,
	title: string?,
	size: string?, -- "S", "sheet", "M" (default) or "L"
	tone: string?, -- "black" (default), "white" (Ace's windows only); "parchment" is the same as "black"
	jp: string?, -- a small grey Japanese accent beside the title (Roblox draws it with its CJK fallback font)
	glow: boolean?, -- lit softly from the top, with scanlines and grain (the shop: the owner's direction A)
	loud: boolean?, -- an Aktura title with a red stroke (Death's Manual, the case report)
	closable: boolean?, -- default true
	onClose: (() -> ())?, -- default: Router.close(name)
	footer: boolean?, -- reserve a footer row for actions
	ruled: boolean?,
	margin: boolean?,
	parent: Instance?,
}

export type Window = {
	name: string,
	root: Frame,
	page: Frame,
	header: Frame,
	body: Frame,
	footer: Frame,
	title: any,
	close: TextButton?,
	setTitle: (string) -> (),
	options: Options,
}

local HEADER = 128
local FOOTER = 72
local TITLE_SIZE = 88

-- How wide a window's sheet runs at most (design px).
local WIDTHS = { S = 560, sheet = 620, M = 940, L = 1220 }

-- A title the way concept A sets it: lowercase, ending on a full stop ("shop.").
local function titled(text: string): string
	local lower = string.lower(text)
	if lower == "" or string.find(lower, "[%.%?!]$") then
		return lower
	end
	return lower .. "."
end

function Window.new(options: Options): Window
	local root = Base.frame({
		Name = "Window_" .. options.name,
		Visible = false,
		ZIndex = 2,
		Parent = options.parent or Screens.modal,
	})
	local limit = Base.maxSize(root, Vector2.new(WIDTHS[options.size or "M"] or WIDTHS.M, 900))
	-- Frees the mouse (first person, shift lock) while the window shows.
	Base.make("TextButton", {
		Name = "MouseUnlock",
		Modal = true,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromOffset(0, 0),
		Selectable = false,
		Parent = root,
	})
	-- The sheet: paper, a hair off square, with toner grain over it. Everything in it is turned to ink on paper
	-- (Kit/Paper), so screens written for the dark need no changes.
	local page = Base.make("Frame", {
		Name = "Sheet",
		BackgroundColor3 = Tokens.paper.g0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Rotation = -0.4,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = root,
	}) :: Frame
	Surfaces.redrawWhenReady(page, function()
		local old = page:FindFirstChild("Toner")
		if old then
			old:Destroy()
		end
		local grain = Textures.id("UiGrain")
		if grain ~= "" then
			Base.make("ImageLabel", {
				Name = "Toner",
				BackgroundTransparency = 1,
				Image = grain,
				ImageColor3 = Tokens.paper.white,
				ImageTransparency = 0.82,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(256, 256),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				Parent = page,
			})
		end
	end)
	local inset = Tokens.space.xxl
	local content = Base.frame({ Name = "Content", ZIndex = 3, Parent = page })
	local ink = Tokens.color.bone -- (written for the dark like every screen; Paper turns it to ink)
	local header = Base.make("CanvasGroup", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		ZIndex = 3,
		Parent = content,
	}) :: any
	-- The title: huge, lowercase, whole (never cut by the sheet's edge), boiling.
	local titleLabel = Base.label({
		Text = titled(options.title or ""),
		font = "title",
		size = TITLE_SIZE,
		color = if options.loud then Tokens.color.danger else ink,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(inset - 4, Tokens.space.m),
		ZIndex = 4,
	})
	-- (marked before it is parented: the font mirror would otherwise redraw it in Melodrama as it lands)
	titleLabel:SetAttribute("KeepFont", true)
	titleLabel.Parent = header
	Boil.attach(titleLabel, 1, 0.25)
	if options.jp then
		local accent = Base.label({
			Text = options.jp,
			font = "mono",
			size = "small",
			color = Tokens.color.g6,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			ZIndex = 4,
			Parent = header,
		})
		local function placeAccent()
			accent.Position = UDim2.fromOffset(inset + titleLabel.AbsoluteSize.X / Base.scaleOf(titleLabel) + 8, 62)
		end
		titleLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAccent)
		placeAccent()
	end
	-- The ink rule under the header, across the sheet.
	Boil.attach(Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, inset, 1, 0),
		Size = UDim2.new(1, -inset * 2, 0, 2),
		ZIndex = 4,
		Parent = header,
	}))
	local close: TextButton? = nil
	if options.closable ~= false then
		close = Controls.button({
			Name = "Back",
			text = "Back",
			variant = "secondary",
			size = "s",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -inset, 0, Tokens.space.l),
			ZIndex = 5,
			Parent = header,
		}, function()
			if options.onClose then
				options.onClose()
			else
				Router.close(options.name, "user")
			end
		end)
	end
	local footerHeight = if options.footer then FOOTER else 0
	local body = Base.frame({
		Name = "Body",
		Position = UDim2.fromOffset(inset, HEADER + Tokens.space.l),
		Size = UDim2.new(1, -inset * 2, 1, -(HEADER + Tokens.space.l + footerHeight + Tokens.space.l)),
		ZIndex = 3,
		Parent = content,
	})
	local footer = Base.frame({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, inset, 1, -Tokens.space.m),
		Size = UDim2.new(1, -inset * 2, 0, footerHeight - Tokens.space.m),
		Visible = options.footer == true,
		ZIndex = 3,
		Parent = content,
	})
	Base.list(footer, Tokens.space.m, true, Enum.HorizontalAlignment.Right)
	Paper.apply(page)

	local function arrange(class: string)
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Position = UDim2.fromScale(0.5, 0.5)
		if class == "phone" then
			root.Size = UDim2.new(1, -Tokens.space.l * 2, 1, -Tokens.space.l * 2)
			limit.MaxSize = Vector2.new(math.huge, math.huge)
		else
			root.Size = UDim2.new(1, -Tokens.space.xxxl * 2, 1, -Tokens.space.xxl * 2)
			limit.MaxSize = Vector2.new(WIDTHS[options.size or "M"] or WIDTHS.M, 900)
		end
	end
	Layout.watch(arrange)

	local title = {
		set = function(_, text: string)
			titleLabel.Text = titled(text)
		end,
		label = titleLabel,
	}
	local win: Window
	win = {
		name = options.name,
		root = root,
		page = page,
		header = header,
		body = body,
		footer = footer,
		title = title,
		close = close,
		options = options,
		setTitle = function(text: string)
			titleLabel.Text = titled(text)
		end,
	}
	return win
end

export type Spec = {
	layer: string?,
	allowed: ((any) -> boolean)?,
	auto: ((any) -> boolean)?,
	show: ((any?) -> ())?,
	hide: ((string) -> ())?,
	firstSelection: (() -> GuiObject?)?,
	stay: boolean?, -- a click outside it never closes it (Router)
}

-- Registers the window with the Router. show/hide run after it appears/before it goes.
function Window.register(win: Window, spec: Spec?)
	local s = spec or {}
	Router.register(win.name, {
		layer = s.layer or "modal",
		window = win.root,
		stay = s.stay,
		allowed = s.allowed,
		auto = s.auto,
		firstSelection = s.firstSelection or function()
			return win.close
		end,
		show = function(args)
			win.root.Visible = true
			Motion.slideIn(win.root, Vector2.new(0, 24), Tokens.motion.base)
			if s.show then
				s.show(args)
			end
		end,
		hide = function(reason)
			if s.hide then
				s.hide(reason)
			end
			win.root.Visible = false
		end,
	})
end

export type ConfirmOptions = {
	title: string,
	body: string,
	confirm: string,
	cancel: string?,
	variant: string?, -- the confirm button ("primary" or "danger")
	onConfirm: () -> (),
	onCancel: (() -> ())?,
}

-- One question over everything else. Returns a function that dismisses it.
function Window.confirm(options: ConfirmOptions): () -> ()
	local shade = Base.hit({
		Name = "Confirm",
		BackgroundColor3 = Tokens.color.void,
		BackgroundTransparency = Tokens.alpha.scrim,
		Selectable = false,
		ZIndex = Tokens.z.top,
		Parent = Screens.overlay,
	})
	local box, content = Surfaces.page({
		tone = "black",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 260),
		ZIndex = Tokens.z.top + 1,
		Parent = shade,
	})
	Base.maxSize(box, Tokens.modal.S + Vector2.new(60, 0))
	Base.list(content, Tokens.space.m)
	GlyphText.new({
		face = "Head",
		text = options.title,
		size = Tokens.size.title,
		color = Tokens.color.bone,
		LayoutOrder = 1,
		ZIndex = Tokens.z.top + 2,
		Parent = content,
	})
	Base.label({
		Text = options.body,
		color = Tokens.color.dim,
		LayoutOrder = 2,
		ZIndex = Tokens.z.top + 2,
		Parent = content,
	})
	local row = Base.frame({
		Size = UDim2.new(1, 0, 0, Tokens.touch),
		LayoutOrder = 3,
		ZIndex = Tokens.z.top + 2,
		Parent = content,
	})
	Base.list(row, Tokens.space.m, true, Enum.HorizontalAlignment.Right)
	local done = false
	local function dismiss()
		if done then
			return
		end
		done = true
		shade:Destroy()
	end
	local cancel = Controls.button({
		text = options.cancel or "Cancel",
		variant = "ghost",
		LayoutOrder = 1,
		ZIndex = Tokens.z.top + 3,
		Parent = row,
	}, function()
		dismiss()
		if options.onCancel then
			options.onCancel()
		end
	end)
	local confirmProps = {
		text = options.confirm,
		variant = options.variant or "primary",
		LayoutOrder = 2,
		ZIndex = Tokens.z.top + 3,
		Parent = row,
	}
	local function confirmed()
		dismiss()
		options.onConfirm()
	end
	Controls.button(confirmProps, confirmed)
	-- Size the page to its text.
	task.defer(function()
		if box.Parent then
			local height = 0
			local scale = Base.scaleOf(content)
			for _, child in ipairs(content:GetChildren()) do
				if child:IsA("GuiObject") then
					height += child.AbsoluteSize.Y / scale + Tokens.space.m
				end
			end
			box.Size = UDim2.new(0.92, 0, 0, height + Tokens.space.xl * 2)
		end
	end)
	-- (a click on the box itself, between its buttons, is not a no)
	shade.Activated:Connect(function(input: InputObject?)
		if not Router.inside(box, input) then
			dismiss()
		end
	end)
	Motion.pop(box)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = cancel
	end
	return dismiss
end

return Window
