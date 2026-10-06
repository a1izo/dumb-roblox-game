--!strict
-- Windows: a Notch panel (two clipped corners and an outline) centred on the screen, or a sheet
-- that rises from the bottom on phones. Every window has a Melodrama title (Aktura when `loud`), a
-- close mark, a body and an optional footer for its actions, and frees the mouse while it is open.
-- The title glitches in when the window opens (and keeps glitching every couple of seconds if `loud`).
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
local Glitch = require(script.Parent.Parent.Core.Glitch)
local Layout = require(script.Parent.Layout)
local Surfaces = require(script.Parent.Surfaces)
local Tokens = require(script.Parent.Tokens)

local Window = {}

export type Options = {
	name: string,
	title: string?,
	size: string?, -- "S", "sheet", "M" (default) or "L"
	tone: string?, -- "black" (default), "white" (Ace's windows only); "parchment" is the same as "black"
	jp: string?, -- a small grey Japanese accent beside the title (Roblox draws it with its CJK fallback font)
	loud: boolean?, -- an Aktura title that keeps glitching (Death's Manual, the case report)
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
	glitch: Glitch.Handle,
	setTitle: (string) -> (),
	options: Options,
}

local HEADER = 76
local FOOTER = 72

local function inkFor(tone: string?): Color3
	return if tone == "white" then Tokens.color.ink else Tokens.color.bone
end

function Window.new(options: Options): Window
	local root = Base.frame({
		Name = "Window_" .. options.name,
		Visible = false,
		ZIndex = 2,
		Parent = options.parent or Screens.modal,
	})
	local limit = Base.maxSize(root, Tokens.modal[options.size or "M"] or Tokens.modal.M)
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
	local page, content = Surfaces.page({
		tone = options.tone or "black",
		padding = 0,
		window = true,
		ZIndex = 2,
		Parent = root,
	})
	local ink = inkFor(options.tone)
	-- The header is a CanvasGroup so it can blink and split when it glitches in.
	local header = Base.make("CanvasGroup", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		ZIndex = 3,
		Parent = content,
	}) :: any
	local title = GlyphText.new({
		face = if options.loud then "Title" else "Head",
		text = options.title or "",
		size = if options.loud then Tokens.size.display else Tokens.size.heading,
		color = ink,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Tokens.space.xl + 4, 0.5, 2),
		ZIndex = 4,
		Parent = header,
	})
	if options.jp then
		local accent = Base.label({
			Text = options.jp,
			font = "label",
			size = "small",
			color = if options.tone == "white" then Tokens.color.inkDim else Tokens.color.g5,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 4,
			Parent = header,
		})
		local function placeAccent()
			accent.Position = UDim2.new(0, Tokens.space.xl + 4 + title.width + 14, 0.5, 8)
		end
		title.Changed:Connect(placeAccent)
		placeAccent()
	end
	-- A short stroke under the title (white; red only on a danger window).
	Base.make("Frame", {
		Name = "Underline",
		BackgroundColor3 = if options.loud then Tokens.color.danger else ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Tokens.space.xl, 1, -6),
		Size = UDim2.fromOffset(72, 2),
		ZIndex = 4,
		Parent = header,
	})
	local close: TextButton? = nil
	if options.closable ~= false then
		close = Controls.iconButton({
			icon = "cross",
			size = 40,
			color = if options.tone == "white" then Tokens.color.inkDim else Tokens.color.dim,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Tokens.space.m, 0.5, 0),
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
		Position = UDim2.fromOffset(Tokens.space.xl, HEADER + Tokens.space.s),
		Size = UDim2.new(1, -Tokens.space.xl * 2, 1, -(HEADER + Tokens.space.s + footerHeight + Tokens.space.l)),
		ZIndex = 3,
		Parent = content,
	})
	local footer = Base.frame({
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, Tokens.space.xl, 1, -Tokens.space.m),
		Size = UDim2.new(1, -Tokens.space.xl * 2, 0, footerHeight - Tokens.space.m),
		Visible = options.footer == true,
		ZIndex = 3,
		Parent = content,
	})
	Base.list(footer, Tokens.space.m, true, Enum.HorizontalAlignment.Right)

	local function arrange(class: string)
		if class == "phone" then
			-- A sheet rising from the bottom edge, full width.
			root.AnchorPoint = Vector2.new(0.5, 1)
			root.Position = UDim2.new(0.5, 0, 1, 10)
			root.Size = UDim2.fromScale(1, if options.size == "S" then 0.6 else 0.94)
			limit.MaxSize = Vector2.new(900, math.huge)
		else
			root.AnchorPoint = Vector2.new(0.5, 0.5)
			root.Position = UDim2.fromScale(0.5, 0.5)
			root.Size = UDim2.fromScale(0.94, 0.9)
			limit.MaxSize = Tokens.modal[options.size or "M"] or Tokens.modal.M
		end
	end
	Layout.watch(arrange)
	local glitch = Glitch.attach(header, { enter = false, loop = options.loud == true })

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
		glitch = glitch,
		options = options,
		setTitle = function(text: string)
			title:set(text)
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
}

-- Registers the window with the Router. show/hide run after it appears/before it goes.
function Window.register(win: Window, spec: Spec?)
	local s = spec or {}
	Router.register(win.name, {
		layer = s.layer or "modal",
		window = win.root,
		allowed = s.allowed,
		auto = s.auto,
		firstSelection = s.firstSelection or function()
			return win.close
		end,
		show = function(args)
			win.root.Visible = true
			win.glitch:enter()
			if Layout.isPhone() then
				Motion.slideIn(win.root, Vector2.new(0, 260), Tokens.motion.slow)
			end
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
	hold: number?, -- seconds to hold the confirm button (for things that cannot be undone)
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
	if options.hold then
		Controls.hold(confirmProps, options.hold, confirmed)
	else
		Controls.button(confirmProps, confirmed)
	end
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
	shade.Activated:Connect(dismiss)
	Motion.pop(box)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = cancel
	end
	return dismiss
end

return Window
