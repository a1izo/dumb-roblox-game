--!strict
-- Text set in Death's Gambit's own lettering (Death's Gambit Gothic, Specter Scrawl): one image per glyph
-- from the atlases art/scripts/ui/fonts.py draws. Handwriting has several versions of each
-- letter, used in turn, so a word never repeats a letter exactly. Until the atlases are
-- imported and loaded the same text shows in the Roblox font the face is based on, and it
-- switches over by itself once they are.
--
--   local title = GlyphText.new({ face = "Gothic", text = "The Grimoire", size = 48,
--       color = Tokens.color.bone, align = "center", Parent = frame })
--   title:set("Investigation")        -- new text
--   title:write(1.2)                  -- letters appear one by one, as if written
--
-- The handle's frame is sized to the text (offset pixels); place it with Position and
-- AnchorPoint like any other frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local GlyphFonts = require(Shared:WaitForChild("UI"):WaitForChild("GlyphFonts"))

local Motion = require(script.Parent.Parent.Core.Motion)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local GlyphText = {}
GlyphText.__index = GlyphText

export type Props = {
	face: string?, -- "Gothic" (default) or "Scrawl"
	text: string?,
	size: number?, -- px per em
	color: Color3?,
	transparency: number?,
	align: string?, -- "left" | "center" | "right"
	maxWidth: number?, -- wrap lines wider than this (px)
	lineHeight: number?, -- times the size
	tracking: number?, -- extra px between letters
	seed: number?, -- which handwriting versions to start from
	upper: boolean?,
	Name: string?,
	Parent: Instance?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Visible: boolean?,
}

export type GlyphText = typeof(setmetatable(
	{} :: {
		frame: Frame,
		props: Props,
		text: string,
		width: number,
		height: number,
		glyphs: { GuiObject },
		readyConnection: any,
		changed: BindableEvent,
		Changed: RBXScriptSignal,
		version: number,
	},
	GlyphText
))

type Face = {
	em: number,
	ascent: number,
	descent: number,
	lineGap: number,
	atlases: { string },
	fallback: string,
	glyphs: { [string]: { { number } } },
}

local function faceOf(name: string?): (Face, string)
	local key = name or "Gothic"
	local face = (GlyphFonts :: any)[key]
	if not face then
		key = "Gothic"
		face = (GlyphFonts :: any).Gothic
	end
	return face, key
end

local function atlasIds(face: Face): { string }?
	local ids = {}
	for _, name in ipairs(face.atlases) do
		local id = Textures.id(name)
		if id == "" then
			return nil
		end
		table.insert(ids, id)
	end
	return ids
end

-- Splits text into characters (UTF-8 aware, so "·" and "—" stay whole).
local function characters(text: string): { string }
	local out = {}
	for _, code in utf8.codes(text) do
		table.insert(out, utf8.char(code))
	end
	return out
end

local function versionsFor(face: Face, char: string): { { number } }
	return face.glyphs[char] or face.glyphs[string.upper(char)] or face.glyphs["?"]
end

-- Lays text out into lines: { { chars, width } }, measuring with advances at `scale`.
local function layout(face: Face, text: string, scale: number, tracking: number, maxWidth: number?)
	local lines = {}
	for _, paragraph in ipairs(string.split(text, "\n")) do
		local words = string.split(paragraph, " ")
		local current, width = {}, 0
		local space = (versionsFor(face, " ")[1][1] :: number) * scale
		for index, word in ipairs(words) do
			local chars = characters(word)
			local wordWidth = 0
			for _, char in ipairs(chars) do
				local v = versionsFor(face, char)[1]
				wordWidth += (v[8] or v[1]) * scale + tracking
			end
			local needed = if #current > 0 then space + wordWidth else wordWidth
			if maxWidth and #current > 0 and width + needed > maxWidth then
				table.insert(lines, { chars = current, width = width })
				current, width = {}, 0
				needed = wordWidth
			end
			if #current > 0 then
				table.insert(current, " ")
			end
			for _, char in ipairs(chars) do
				table.insert(current, char)
			end
			width += needed
			if index == #words then
				table.insert(lines, { chars = current, width = width })
			end
		end
		if #words == 0 then
			table.insert(lines, { chars = {}, width = 0 })
		end
	end
	return lines
end

function GlyphText.new(props: Props): GlyphText
	local frame = Create("Frame", {
		Name = props.Name or "GlyphText",
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	local changed = Instance.new("BindableEvent")
	local self = setmetatable({
		frame = frame,
		props = props,
		text = props.text or "",
		width = 0,
		height = 0,
		glyphs = {},
		readyConnection = nil,
		-- Fires after the text is laid out again (new text, size, or the atlases arriving).
		changed = changed,
		Changed = changed.Event,
		version = 0,
	}, GlyphText)
	self:_render()
	if not Textures.isReady() then
		self.readyConnection = Textures.Ready:Connect(function()
			if frame.Parent then
				self:_render()
			end
		end)
	end
	frame.Destroying:Once(function()
		if self.readyConnection then
			self.readyConnection:Disconnect()
			self.readyConnection = nil
		end
		changed:Destroy()
	end)
	return self
end

function GlyphText._clear(self: GlyphText)
	for _, glyph in ipairs(self.glyphs) do
		glyph:Destroy()
	end
	table.clear(self.glyphs)
end

function GlyphText._render(self: GlyphText)
	self:_clear()
	local props = self.props
	local face = faceOf(props.face)
	local size = props.size or Tokens.size.display
	local color = props.color or Tokens.color.bone
	local transparency = props.transparency or 0
	local text = if props.upper then string.upper(self.text) else self.text
	local zIndex = props.ZIndex or 1
	local ids = atlasIds(face)
	if not ids then
		-- The Roblox font this face is drawn from, until the atlases load.
		local label = Create("TextLabel", {
			Name = "Fallback",
			BackgroundTransparency = 1,
			FontFace = if props.face == "Scrawl" then Tokens.font.hand else Tokens.font.display,
			Text = text,
			TextSize = size * (if props.face == "Scrawl" then 1.05 else 0.92),
			TextColor3 = color,
			TextTransparency = transparency,
			TextWrapped = props.maxWidth ~= nil,
			TextXAlignment = if props.align == "center"
				then Enum.TextXAlignment.Center
				elseif props.align == "right" then Enum.TextXAlignment.Right
				else Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = zIndex,
			Parent = self.frame,
		})
		if props.maxWidth then
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.Size = UDim2.fromOffset(props.maxWidth, 0)
		end
		table.insert(self.glyphs, label)
		self.frame.AutomaticSize = Enum.AutomaticSize.XY
		self.frame.Size = UDim2.fromOffset(0, 0)
		-- A first guess, then the real measurement (in design pixels, before UI scaling).
		local lines = string.split(text, "\n")
		local longest = 0
		for _, line in ipairs(lines) do
			longest = math.max(longest, utf8.len(line) or #line)
		end
		self.width = math.min(longest * label.TextSize * 0.5, props.maxWidth or math.huge)
		self.height = #lines * label.TextSize * 1.2
		self.version += 1
		local version = self.version
		task.spawn(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = label.Text
			params.Font = label.FontFace
			params.Size = label.TextSize
			params.Width = props.maxWidth or 100000
			local ok, bounds = pcall(function()
				return TextService:GetTextBoundsAsync(params)
			end)
			if ok and self.version == version and label.Parent then
				self.width = bounds.X
				self.height = bounds.Y
				self.changed:Fire()
			end
		end)
		self.changed:Fire()
		return
	end
	self.version += 1
	self.frame.AutomaticSize = Enum.AutomaticSize.None
	local scale = size / face.em
	local tracking = props.tracking or 0
	local lineHeight = size * (props.lineHeight or 1.15)
	local lines = layout(face, text, scale, tracking, props.maxWidth)
	local widest = 0
	for _, line in ipairs(lines) do
		widest = math.max(widest, line.width)
	end
	local height = lineHeight * math.max(#lines - 1, 0) + (face.ascent + face.descent) * scale
	local counters: { [string]: number } = {}
	local seed = props.seed or 0
	for index, line in ipairs(lines) do
		local x = 0
		if props.align == "center" then
			x = (widest - line.width) / 2
		elseif props.align == "right" then
			x = widest - line.width
		end
		local baseline = face.ascent * scale + lineHeight * (index - 1)
		for _, char in ipairs(line.chars) do
			local versions = versionsFor(face, char)
			local n = (counters[char] or 0) + seed
			counters[char] = (counters[char] or 0) + 1
			local v = versions[(n % #versions) + 1]
			if #v >= 8 then
				local image = Create("ImageLabel", {
					Name = "Glyph",
					BackgroundTransparency = 1,
					Image = ids[v[1]],
					ImageRectOffset = Vector2.new(v[2], v[3]),
					ImageRectSize = Vector2.new(v[4], v[5]),
					ImageColor3 = color,
					ImageTransparency = transparency,
					Size = UDim2.fromOffset(v[4] * scale, v[5] * scale),
					Position = UDim2.fromOffset(x + v[6] * scale, baseline - v[7] * scale),
					ZIndex = zIndex,
					Parent = self.frame,
				})
				table.insert(self.glyphs, image)
				x += v[8] * scale + tracking
			else
				x += v[1] * scale + tracking
			end
		end
	end
	self.width = widest
	self.height = height
	self.frame.Size = UDim2.fromOffset(math.ceil(widest), math.ceil(height))
	self.changed:Fire()
end

-- Changes the lettering size (px per em).
function GlyphText.setSize(self: GlyphText, size: number)
	if self.props.size == size then
		return
	end
	self.props.size = size
	self:_render()
end

-- Replaces the text.
function GlyphText.set(self: GlyphText, text: string)
	if text == self.text then
		return
	end
	self.text = text
	self:_render()
end

function GlyphText.setColor(self: GlyphText, color: Color3)
	self.props.color = color
	for _, glyph in ipairs(self.glyphs) do
		if glyph:IsA("ImageLabel") then
			glyph.ImageColor3 = color
		elseif glyph:IsA("TextLabel") then
			glyph.TextColor3 = color
		end
	end
end

function GlyphText.setTransparency(self: GlyphText, transparency: number)
	self.props.transparency = transparency
	for _, glyph in ipairs(self.glyphs) do
		if glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = transparency
		elseif glyph:IsA("TextLabel") then
			glyph.TextTransparency = transparency
		end
	end
end

-- Writes the text in: each letter appears in turn, starting as a red blot that settles into
-- the text colour. Returns the time it takes.
function GlyphText.write(self: GlyphText, duration: number?, inkColor: Color3?): number
	local total = duration or 0.8
	local count = #self.glyphs
	if count == 0 or Motion.isReduced() then
		return 0
	end
	local color = self.props.color or Tokens.color.bone
	local target = self.props.transparency or 0
	local step = total / count
	for index, glyph in ipairs(self.glyphs) do
		if glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = 1
			glyph.ImageColor3 = inkColor or Tokens.color.red
			task.delay(step * (index - 1), function()
				if glyph.Parent then
					Motion.tween(glyph, { ImageTransparency = target }, step * 2.5)
					Motion.tween(glyph, { ImageColor3 = color }, 0.5)
				end
			end)
		elseif glyph:IsA("TextLabel") then
			glyph.MaxVisibleGraphemes = 0
			local graphemes = utf8.len(glyph.Text) or 0
			for n = 1, graphemes do
				task.delay(total * n / graphemes, function()
					if glyph.Parent then
						glyph.MaxVisibleGraphemes = n
					end
				end)
			end
		end
	end
	return total
end

function GlyphText.destroy(self: GlyphText)
	self.frame:Destroy()
end

return GlyphText
