--!strict
-- The materials screens are made of: Notch panels (a dark panel with one clipped corner, a grey edge line,
-- faint scanlines and grain; white for Ace's screens only), loud header bars, ID seals, stamps and a
-- vignette. Each is drawn from the UI textures when they are loaded, and from plain rectangles until then
-- (redrawn automatically once they arrive).

local Base = require(script.Parent.Base)
local GlyphText = require(script.Parent.GlyphText)
local Icon = require(script.Parent.Icon)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Surfaces = {}

type Props = { [string]: any }

local C = Tokens.color

-- Page tones: the panel colour and the colour of text and lines that sit on it.
local TONES = {
	black = { color = C.page, rule = C.rule },
	raised = { color = C.raised, rule = C.rule },
	parchment = { color = C.raised, rule = C.rule }, -- the old paper tone: reading text is light on dark now
	white = { color = C.white, rule = C.ink }, -- Ace's surfaces, the only black-on-white panels
}

-- The Notch shapes: 9-slice images with a clipped corner (see art/scripts/ui/textures.py).
local SHAPES = {
	panel = { fill = "UiNotch", line = nil, slice = Rect.new(32, 32, 224, 224), scale = 1 },
	button = { fill = "UiNotchBtn", line = "UiNotchBtnLine", slice = Rect.new(32, 32, 224, 224), scale = 1 },
	window = { fill = "UiNotchWin", line = "UiNotchWinLine", slice = Rect.new(48, 48, 208, 208), scale = 0.5 },
}

-- Draws (or redraws) a surface into `holder` once the textures are known.
function Surfaces.redrawWhenReady(holder: Instance, draw: () -> ())
	draw()
	if not Textures.isReady() then
		local connection
		connection = Textures.Ready:Connect(function()
			if holder.Parent then
				draw()
			end
			if connection then
				connection:Disconnect()
			end
		end)
		holder.Destroying:Once(function()
			if connection then
				connection:Disconnect()
			end
		end)
	end
end
local redrawWhenReady = Surfaces.redrawWhenReady

-- A clipped-corner shape filling `parent`. Props: shape ("panel", "button" or "window"), color,
-- transparency, line (true draws only the 1 px outline), scale (multiplies the corner size, for small
-- elements), ZIndex, Name. With no texture it is a plain rectangle (an outline is a stroke).
function Surfaces.notch(parent: Instance, props: Props): GuiObject
	local shape = SHAPES[props.shape or "panel"] or SHAPES.panel
	local name = if props.line then shape.line or shape.fill else shape.fill
	local id = Textures.id(name)
	local z = props.ZIndex or 1
	if id ~= "" then
		return Base.make("ImageLabel", {
			Name = props.Name or "Notch",
			BackgroundTransparency = 1,
			Image = id,
			ImageColor3 = props.color or C.page,
			ImageTransparency = props.transparency or 0,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = shape.slice,
			SliceScale = shape.scale * (props.scale or 1),
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
			Parent = parent,
		}) :: GuiObject
	end
	if props.line then
		local frame = Base.make("Frame", {
			Name = props.Name or "Notch",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
			Parent = parent,
		})
		Base.stroke(frame, props.color or C.rule, 1, props.transparency or 0)
		return frame :: GuiObject
	end
	return Base.make("Frame", {
		Name = props.Name or "Notch",
		BackgroundColor3 = props.color or C.page,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	}) :: GuiObject
end

-- Scanlines and grain over a panel: two faint tiled images (drawn only when the textures are loaded).
function Surfaces.texture(parent: Instance, z: number, tint: Color3?)
	local color = tint or Color3.new(1, 1, 1)
	local scan = Textures.id("UiScan")
	if scan ~= "" then
		Base.make("ImageLabel", {
			Name = "Scan",
			BackgroundTransparency = 1,
			Image = scan,
			ImageColor3 = color,
			ImageTransparency = Tokens.alpha.scan,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(12, 12),
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
			Parent = parent,
		})
	end
	local grain = Textures.id("UiGrain")
	if grain ~= "" then
		Base.make("ImageLabel", {
			Name = "Grain",
			BackgroundTransparency = 1,
			Image = grain,
			ImageColor3 = color,
			ImageTransparency = Tokens.alpha.grain,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(256, 256),
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
			Parent = parent,
		})
	end
end

-- A panel. Props: window (two clipped corners and an outline, used by Window), tone ("black", "raised", "parchment" (the same as raised), "white" (Ace's)), glass
-- (the panel is see-through, for the HUD), edge (the 2 px grey line down the left, default true except on
-- white), texture (scanlines and grain, default true), padding (px, default 24), autoHeight (the panel
-- grows and shrinks with its content; give it a width), plus frame properties. `torn`, `ruled` and
-- `margin` from the old notebook pages are accepted and ignored.
-- Returns the panel frame and its content frame (put layouts in the content frame).
function Surfaces.page(props: Props?): (Frame, Frame)
	local p = props or {}
	local tone = TONES[p.tone or "black"] or TONES.black
	local frame = Base.frame({
		Name = p.Name or "Page",
		Size = p.Size or UDim2.fromScale(1, 1),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		ZIndex = p.ZIndex or 1,
		LayoutOrder = p.LayoutOrder,
		Visible = if p.Visible == nil then true else p.Visible,
		Parent = p.Parent,
	})
	local z = frame.ZIndex
	local surface = Base.frame({ Name = "Surface", ZIndex = z, Parent = frame })
	local isWhite = p.tone == "white"
	local function draw()
		Base.clear(surface)
		frame.BackgroundTransparency = 1
		Surfaces.notch(surface, {
			shape = if p.window then "window" else "panel",
			color = tone.color,
			transparency = if p.glass then Tokens.alpha.glass else 0,
			ZIndex = z,
		})
		if p.window then
			-- A window has two clipped corners and a 1 px outline instead of the edge line and texture.
			Surfaces.notch(surface, {
				shape = "window",
				line = true,
				color = if isWhite then C.g5 else C.rule,
				transparency = 0.76,
				ZIndex = z,
			})
		end
		if p.texture ~= false and not isWhite and not p.window then
			Surfaces.texture(surface, z)
		end
		if p.edge ~= false and not isWhite and not p.window then
			Base.make("Frame", {
				Name = "Edge",
				BackgroundColor3 = C.g5,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 2, 1, 0),
				ZIndex = z,
				Parent = surface,
			})
		end
	end
	redrawWhenReady(surface, draw)
	local padding = p.padding or Tokens.space.xl
	local content = Base.frame({ Name = "Content", ZIndex = z + 1, Parent = frame })
	Base.pad(content, padding, padding)
	if p.autoHeight then
		-- The panel fills its frame, so the frame is measured from its content rather than sized
		-- automatically (see Base.fit).
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		Base.fit(frame, content, "Y")
	end
	return frame, content
end

-- A loud header bar with lettering. Props: text, face ("Head"), size (lettering px), tone (a Color3 for
-- the bar: near-black by default, pass Tokens.color.danger for a danger bar), ink (the lettering colour),
-- plus frame properties. Sized to its text. Returns the frame and the GlyphText.
function Surfaces.banner(props: Props): (Frame, any)
	local frame = Base.frame({
		Name = props.Name or "Banner",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local bar = Base.frame({ Name = "Bar", ZIndex = z, Parent = frame })
	local size = props.size or Tokens.size.heading
	local text = GlyphText.new({
		face = props.face or "Head",
		text = props.text or "",
		size = size,
		color = props.ink or C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = z + 1,
		Parent = frame,
	})
	local function fit()
		frame.Size = UDim2.fromOffset(math.max(text.width, 40) + size * 1.4, math.max(text.height, 20) + size * 0.55)
	end
	local function draw()
		Base.clear(bar)
		local color = props.tone or C.g0
		Surfaces.notch(bar, { shape = "panel", color = color, ZIndex = z })
		Base.make("Frame", {
			Name = "Underline",
			BackgroundColor3 = if color == C.danger or color == C.blood then C.g0 else C.white,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = z,
			Parent = bar,
		})
		fit()
	end
	redrawWhenReady(bar, draw)
	text.Changed:Connect(fit)
	return frame, text
end

-- An ID seal: a dark square with a coloured border and an emblem. Props: size (px, default 64), color
-- (the border and emblem; white by default, danger for Diavolo's side), icon (an icon name) or text (a
-- letter or two), plus frame properties.
function Surfaces.seal(props: Props): Frame
	local size = props.size or 64
	local frame = Base.frame({
		Name = props.Name or "Seal",
		Size = UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local color = props.color or C.white
	local border = Base.make("Frame", {
		Name = "Border",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = frame,
	})
	Base.make("Frame", {
		Name = "Plate",
		BackgroundColor3 = C.g2,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = z,
		Parent = border,
	})
	-- A dark border colour (the old blood red) would vanish on the plate, so the emblem is lightened.
	local emblem = color:Lerp(C.white, 0.35)
	if props.icon then
		Icon.new({
			name = props.icon,
			size = size * 0.46,
			color = emblem,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = z + 1,
			Parent = frame,
		})
	elseif props.text then
		GlyphText.new({
			face = "Head",
			text = props.text,
			size = size * 0.46,
			color = emblem,
			align = "center",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = z + 1,
			Parent = frame,
		})
	end
	return frame
end

-- A stamp: a boxed upper-case word, tilted a few degrees. Props: text, color (danger red; stamps mark
-- danger), rotation (degrees, -3), width (px), plus frame properties.
function Surfaces.stamp(props: Props): Frame
	local width = props.width or 240
	local frame = Base.frame({
		Name = props.Name or "Stamp",
		Size = UDim2.fromOffset(width, width * 0.3),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.rotation or -3,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local color = props.color or C.danger
	local box = Base.frame({ Name = "Border", ZIndex = z, Parent = frame })
	Base.stroke(box, color, 3, 0)
	Base.label({
		Text = string.upper(props.text or ""),
		font = "bodyBold",
		size = width * 0.12,
		color = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(0.86, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		TextScaled = true,
		ZIndex = z + 1,
		Parent = frame,
	})
	return frame
end

-- Darkened screen edges (for cutscenes and the reveal).
function Surfaces.vignette(parent: Instance, strength: number?): Frame
	local holder = Base.frame({ Name = "Vignette", ZIndex = Tokens.z.overlay, Parent = parent })
	local function draw()
		Base.clear(holder)
		local id = Textures.id("UiVignette")
		if id ~= "" then
			Base.make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageTransparency = 1 - (strength or 1),
				Size = UDim2.fromScale(1, 1),
				ZIndex = holder.ZIndex,
				Parent = holder,
			})
		end
	end
	redrawWhenReady(holder, draw)
	return holder
end

-- A flat card for rows and tiles on a panel: a raised fill with a hairline edge. Props: tone
-- ("raised" by default, "lifted", "page", "parchment" (light grey, for Ace's desk)), accent (a Color3 for a mark
-- down the left side; only on cards with a fixed height), padding (px, default 12), plus frame
-- properties. It has no full-size decoration, so AutomaticSize is safe on it. Children go
-- straight inside (the padding is on the card).
local CARD_TONES = {
	raised = C.raised,
	lifted = C.lifted,
	page = C.page,
	parchment = C.parchment, -- the light card on Ace's desk (dark text)
}

function Surfaces.card(props: Props): Frame
	local frame = Base.make("Frame", {
		Name = props.Name or "Card",
		BackgroundColor3 = CARD_TONES[props.tone or "raised"] or C.raised,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 56),
		AutomaticSize = props.AutomaticSize,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	Base.stroke(frame, if props.tone == "parchment" then C.ink else C.rule, 1, Tokens.alpha.hairline)
	local padding = props.padding or Tokens.space.m
	Base.pad(frame, padding, if props.accent then padding + 6 else padding)
	if props.accent then
		Base.make("Frame", {
			Name = "Accent",
			BackgroundColor3 = props.accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, -(padding + 6), 0, -padding),
			Size = UDim2.new(0, 4, 1, padding * 2),
			ZIndex = frame.ZIndex,
			Parent = frame,
		})
	end
	return frame
end

-- A section heading on a panel: a Melodrama title with a short white stroke under it, an optional detail
-- on the right in small type, and a hairline across. Props: text, detail, ink (the lettering colour),
-- plus frame properties. Returns the frame and set(text, detail?).
function Surfaces.heading(props: Props): (Frame, (string, string?) -> ())
	local ink = props.ink or C.bone
	local frame = Base.frame({
		Name = props.Name or "Heading",
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local title = GlyphText.new({
		face = "Head",
		text = props.text or "",
		size = Tokens.size.title,
		color = ink,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -8),
		ZIndex = z,
		Parent = frame,
	})
	local detail = Base.label({
		Name = "Detail",
		Text = props.detail or "",
		font = "label",
		size = "micro",
		upper = true,
		color = if ink == C.ink then C.inkDim else C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -10),
		Size = UDim2.new(0.5, 0, 0, 20),
		ZIndex = z,
		Parent = frame,
	})
	Base.make("Frame", {
		Name = "Hairline",
		BackgroundColor3 = ink,
		BackgroundTransparency = Tokens.alpha.rule,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = z,
		Parent = frame,
	})
	Base.make("Frame", {
		Name = "Stroke",
		BackgroundColor3 = ink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.fromOffset(48, 2),
		ZIndex = z,
		Parent = frame,
	})
	return frame, function(text: string, newDetail: string?)
		title:set(text)
		detail.Text = newDetail or ""
	end
end

-- A thin rule (hairline), optionally coloured.
function Surfaces.rule(props: Props?): Frame
	local p = props or {}
	return Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = p.color or C.rule,
		BackgroundTransparency = p.transparency or 0.82,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, p.thickness or 1),
		LayoutOrder = p.LayoutOrder,
		Position = p.Position,
		Parent = p.Parent,
	})
end

return Surfaces
