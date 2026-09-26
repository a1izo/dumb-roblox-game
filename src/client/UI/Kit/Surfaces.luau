--!strict
-- The materials screens are made of: notebook pages (black, parchment or white) with torn
-- edges, grain and ruled lines; brush-stroke banners with Gothic lettering; wax seals; rubber
-- stamps; and a vignette. Each is drawn from the UI textures when they are loaded, and from
-- plain frames until then (redrawn automatically once they arrive).

local Base = require(script.Parent.Base)
local GlyphText = require(script.Parent.GlyphText)
local Icon = require(script.Parent.Icon)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Surfaces = {}

type Props = { [string]: any }

local TONES = {
	black = { color = Tokens.color.page, grain = "UiPaper", grainTint = Color3.new(1, 1, 1), rule = Tokens.color.rule },
	raised = {
		color = Tokens.color.raised,
		grain = "UiPaper",
		grainTint = Color3.fromRGB(255, 250, 255),
		rule = Tokens.color.rule,
	},
	parchment = {
		color = Tokens.color.parchment,
		grain = "UiParchment",
		grainTint = Color3.new(1, 1, 1),
		rule = Tokens.color.ink,
	},
	white = {
		color = Tokens.color.white,
		grain = "UiParchment",
		grainTint = Color3.fromRGB(255, 255, 255),
		rule = Tokens.color.ink,
	},
}

-- Draws (or redraws) a surface into `holder` once the textures are known.
local function redrawWhenReady(holder: Instance, draw: () -> ())
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

-- A page. Props: tone ("black", "raised", "parchment", "white"), torn (default true), ruled,
-- margin (a red margin line), padding (px, default 24), autoHeight (the page grows and shrinks
-- with its content; give it a width), plus frame properties.
-- Returns the page frame and its content frame (put layouts in the content frame).
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
	local torn = p.torn ~= false
	local function draw()
		Base.clear(surface)
		frame.BackgroundTransparency = 1
		local edgeId = if torn then Textures.id("UiTorn") else ""
		local grainId = Textures.id(tone.grain)
		if edgeId ~= "" then
			Base.make("ImageLabel", {
				Name = "Edge",
				BackgroundTransparency = 1,
				Image = edgeId,
				ImageColor3 = tone.color,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(32, 32, 224, 224),
				SliceScale = 0.5,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = surface,
			})
		else
			Base.make("Frame", {
				Name = "Fill",
				BackgroundColor3 = tone.color,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = surface,
			})
		end
		if grainId ~= "" then
			local inset = if torn then 9 else 0
			Base.make("ImageLabel", {
				Name = "Grain",
				BackgroundTransparency = 1,
				Image = grainId,
				ImageColor3 = tone.grainTint,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(256, 256),
				Position = UDim2.fromOffset(inset, inset),
				Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
				ZIndex = z,
				Parent = surface,
			})
		end
		if p.ruled then
			local ruleId = Textures.id("UiRuled")
			if ruleId ~= "" then
				Base.make("ImageLabel", {
					Name = "Rules",
					BackgroundTransparency = 1,
					Image = ruleId,
					ImageColor3 = tone.rule,
					ImageTransparency = 0.55,
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromOffset(64, Tokens.ruleGap),
					Position = UDim2.fromOffset(12, (p.padding or Tokens.space.xl) + 8),
					Size = UDim2.new(1, -24, 1, -((p.padding or Tokens.space.xl) + 20)),
					ZIndex = z,
					Parent = surface,
				})
			end
		end
		if p.margin then
			Base.make("Frame", {
				Name = "Margin",
				BackgroundColor3 = Tokens.color.red,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 52, 0, 10),
				Size = UDim2.new(0, 2, 1, -20),
				ZIndex = z,
				Parent = surface,
			})
		end
		if edgeId == "" and grainId == "" then
			Base.stroke(surface:FindFirstChild("Fill") :: Instance, tone.rule, 1, 0.85)
		end
	end
	redrawWhenReady(surface, draw)
	local padding = p.padding or Tokens.space.xl
	local content = Base.frame({ Name = "Content", ZIndex = z + 1, Parent = frame })
	Base.pad(content, padding, if p.margin then padding + 44 else padding)
	if p.autoHeight then
		-- The paper fills the page, so the page is measured from its content rather than
		-- sized automatically (see Base.fit).
		content.Size = UDim2.new(1, 0, 0, 0)
		content.AutomaticSize = Enum.AutomaticSize.Y
		Base.fit(frame, content, "Y")
	end
	return frame, content
end

-- A brush-stroke banner with lettering. Props: text, face ("Gothic"), size (lettering px),
-- tone (a Color3 for the stroke, red by default), ink (the lettering colour), plus frame
-- properties. Sized to its text. Returns the frame and the GlyphText.
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
	local stroke = Base.frame({ Name = "Stroke", ZIndex = z, Parent = frame })
	local text = GlyphText.new({
		face = props.face or "Gothic",
		text = props.text or "",
		size = props.size or Tokens.size.heading,
		color = props.ink or Tokens.color.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = z + 1,
		Parent = frame,
	})
	local function fit()
		local w = math.max(text.width, 40) + (props.size or Tokens.size.heading) * 2.2
		local h = math.max(text.height, 20) + (props.size or Tokens.size.heading) * 0.7
		frame.Size = UDim2.fromOffset(w, h)
	end
	local function draw()
		Base.clear(stroke)
		local id = Textures.id("UiBrush")
		if id ~= "" then
			Base.make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = props.tone or Tokens.color.blood,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = stroke,
			})
		else
			local fill = Base.make("Frame", {
				BackgroundColor3 = props.tone or Tokens.color.blood,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -16, 0.72, 0),
				ZIndex = z,
				Parent = stroke,
			})
			local _ = fill
		end
		fit()
	end
	redrawWhenReady(stroke, draw)
	text.Changed:Connect(fit)
	return frame, text
end

-- A wax seal. Props: size (px, default 64), color (the wax, red by default), icon (an icon
-- name) or text (a Gothic letter or two), plus frame properties.
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
	local wax = props.color or Tokens.color.red
	local body = Base.frame({ Name = "Wax", ZIndex = z, Parent = frame })
	local function draw()
		Base.clear(body)
		local id = Textures.id("UiSeal")
		if id ~= "" then
			Base.make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = wax,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = body,
			})
		else
			local disc = Base.make("Frame", {
				BackgroundColor3 = wax,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.05, 0.05),
				ZIndex = z,
				Parent = body,
			})
			Base.round(disc)
			Base.stroke(disc, wax:Lerp(Color3.new(0, 0, 0), 0.4), 2, 0)
		end
	end
	redrawWhenReady(body, draw)
	local emblemColor = wax:Lerp(Color3.new(0, 0, 0), 0.55)
	if props.icon then
		Icon.new({
			name = props.icon,
			size = size * 0.42,
			color = emblemColor,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = z + 1,
			Parent = frame,
		})
	elseif props.text then
		GlyphText.new({
			face = "Gothic",
			text = props.text,
			size = size * 0.46,
			color = emblemColor,
			align = "center",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			ZIndex = z + 1,
			Parent = frame,
		})
	end
	return frame
end

-- A rubber stamp: a grungy frame with upper-case text, tilted. Props: text, color (red),
-- rotation (degrees, -6), width (px), plus frame properties.
function Surfaces.stamp(props: Props): Frame
	local width = props.width or 240
	local frame = Base.frame({
		Name = props.Name or "Stamp",
		Size = UDim2.fromOffset(width, width * 0.375),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Rotation = props.rotation or -6,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local z = frame.ZIndex
	local color = props.color or Tokens.color.red
	local border = Base.frame({ Name = "Border", ZIndex = z, Parent = frame })
	local function draw()
		Base.clear(border)
		local id = Textures.id("UiStamp")
		if id ~= "" then
			Base.make("ImageLabel", {
				BackgroundTransparency = 1,
				Image = id,
				ImageColor3 = color,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = border,
			})
		else
			Base.stroke(border, color, 4, 0.1)
		end
	end
	redrawWhenReady(border, draw)
	Base.label({
		Text = string.upper(props.text or ""),
		font = "bodyBold",
		size = width * 0.13,
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

-- A thin rule (hairline), optionally red.
function Surfaces.rule(props: Props?): Frame
	local p = props or {}
	return Base.make("Frame", {
		Name = "Rule",
		BackgroundColor3 = p.color or Tokens.color.rule,
		BackgroundTransparency = p.transparency or 0.82,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, p.thickness or 1),
		LayoutOrder = p.LayoutOrder,
		Position = p.Position,
		Parent = p.Parent,
	})
end

return Surfaces
