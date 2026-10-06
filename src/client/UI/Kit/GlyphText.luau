--!strict
-- Text set in Death's Gambit's lettering: one image per glyph from the atlases art/scripts/ui/fonts.py draws
-- from the two Fontshare fonts (Roblox cannot load custom fonts). Faces:
--   "Title"    Aktura: the game title, CASE CLOSED, big slams. Mixed case; its capitals are ornate, so
--              `plainCaps` sets A H I J K N as lower case at capital height (default on for this face),
--              and a word written all in capitals (HQ, ACE) is drawn in Melodrama Bold at Aktura's
--              capital height, so it reads.
--   "Head"     Melodrama Bold: headings, buttons, names, numbers (18 px and up)
--   "Semi"     Melodrama Semibold: the lighter heading weight
--   "RnLight", "RnMedium": letters only, for the ransom note (Kit.ransom)
-- The old names still work: "Gothic" is "Head" and "Scrawl" is "Semi".
-- Text is kerned with the font's own pair kerning. With `tabular = true` every digit gets the same slot
-- width (Melodrama's digits are proportional), so a clock does not shift as it counts.
-- Until the atlases are imported and loaded the same text shows in Montserrat, and it switches over by
-- itself once they are.
--
--   local title = GlyphText.new({ face = "Title", text = "Death's Gambit", size = 96,
--       color = Tokens.color.bone, align = "center", Parent = frame })
--   title:set("Diavolo Wins")         -- new text
--   title:write(1.2)                  -- letters cut in one by one
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
	face: string?, -- "Head" (default), "Title", "Semi" (see the top of the file)
	text: string?,
	size: number?, -- px per em
	color: Color3?,
	transparency: number?,
	align: string?, -- "left" | "center" | "right"
	maxWidth: number?, -- wrap lines wider than this (px)
	lineHeight: number?, -- times the size
	tracking: number?, -- extra px between letters
	tabular: boolean?, -- digits in equal slots
	plainCaps: boolean?, -- Title only: A H I J K N as lower case at capital height
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

export type Face = {
	em: number,
	ascent: number,
	descent: number,
	lineGap: number,
	digit: number,
	atlases: { string },
	fallback: string,
	kern: { [string]: { [string]: number } },
	glyphs: { [string]: { number } },
}

local LEGACY = { Gothic = "Head", Scrawl = "Semi" }
-- Which Roblox font stands in for each face until its atlas loads.
local STAND_IN = { Title = "title", Head = "display", Semi = "hand", RnLight = "hand", RnMedium = "hand" }
-- Aktura capitals that are hard to read; they are set as lower case scaled up to capital height.
local PLAIN_CAPS = { A = true, H = true, I = true, J = true, K = true, N = true }
local PLAIN_CAP_SCALE = 1.3
-- Marks a character of an all-capitals word inside an Aktura line (drawn in Melodrama instead).
local ALT = "\1"

local function faceOf(name: string?): (Face, string)
	local key = LEGACY[name or ""] or name or "Head"
	local face = (GlyphFonts :: any)[key]
	if not face then
		key = "Head"
		face = (GlyphFonts :: any).Head
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

local function glyphOf(face: Face, char: string): { number }
	return face.glyphs[char] or face.glyphs[string.upper(char)] or face.glyphs["?"] or face.glyphs[" "]
end

local function isDigit(char: string): boolean
	return #char == 1 and char >= "0" and char <= "9"
end

-- Where each drawn character of a line sits (px at `scale`) and the line's width. Pairs are kerned; a
-- space adds its advance and breaks the pair.
local function place(
	face: Face,
	chars: { string },
	scale: number,
	tracking: number,
	tabular: boolean,
	alt: Face?,
	altScale: number?
)
	local out: { { char: string, glyph: { number }, x: number, slot: boolean, alt: boolean? } } = {}
	local x = 0
	local previous: string? = nil
	for _, char in ipairs(chars) do
		if alt and altScale and string.sub(char, 1, 1) == ALT then
			-- A letter of an all-capitals word: Melodrama, scaled to Aktura's capital height.
			local real = string.sub(char, 2)
			local glyph = glyphOf(alt, real)
			table.insert(out, { char = real, glyph = glyph, x = x, slot = false, alt = true })
			x += (glyph[8] or glyph[1]) * altScale + tracking
			previous = nil
			continue
		end
		local glyph = glyphOf(face, char)
		if char == " " then
			x += glyph[1] * scale + tracking
			previous = nil
		else
			if previous then
				local row = face.kern[previous]
				local pair = row and row[char]
				if pair then
					x += pair * scale
				end
			end
			local slot = tabular and isDigit(char)
			local advance = if slot then face.digit else (glyph[8] or glyph[1])
			table.insert(out, { char = char, glyph = glyph, x = x, slot = slot })
			x += advance * scale + tracking
			previous = char
		end
	end
	return out, x
end

-- A word of two or more letters with no lower-case letter ("HQ", "ACE").
local function allCaps(word: string): boolean
	local letters = string.gsub(word, "[^%a]", "")
	return #letters >= 2 and string.upper(letters) == letters
end

-- Lays text out into lines: { { chars, width } }, wrapping at maxWidth. With `alt`, the characters of an
-- all-capitals word are marked to be drawn in that face.
local function layout(
	face: Face,
	text: string,
	scale: number,
	tracking: number,
	maxWidth: number?,
	tabular: boolean,
	alt: Face?,
	altScale: number?
)
	local lines = {}
	for _, paragraph in ipairs(string.split(text, "\n")) do
		local words = string.split(paragraph, " ")
		local current: { string }, width = {}, 0
		local space = glyphOf(face, " ")[1] * scale + tracking
		for index, word in ipairs(words) do
			local chars = characters(word)
			if alt and allCaps(word) then
				for i, char in ipairs(chars) do
					if string.match(char, "^%a$") then
						chars[i] = ALT .. char
					end
				end
			end
			local _, wordWidth = place(face, chars, scale, tracking, tabular, alt, altScale)
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

-- The width of `text` in a face at a size (px), without building anything. Used by the ransom note.
function GlyphText.measure(faceName: string, text: string, size: number, tracking: number?, tabular: boolean?): number
	local face = faceOf(faceName)
	local _, width = place(face, characters(text), size / face.em, tracking or 0, tabular == true)
	return width
end

-- Face data (metrics and atlas names) by face name.
function GlyphText.face(faceName: string?): Face
	return (faceOf(faceName))
end

-- The atlas content ids of a face, or nil while any is missing.
function GlyphText.atlases(faceName: string?): { string }?
	return atlasIds((faceOf(faceName)))
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
	local face, faceKey = faceOf(props.face)
	local size = props.size or Tokens.size.display
	local color = props.color or Tokens.color.bone
	local transparency = props.transparency or 0
	local text = if props.upper then string.upper(self.text) else self.text
	local zIndex = props.ZIndex or 1
	local tabular = props.tabular == true
	local ids = atlasIds(face)
	if not ids then
		-- Montserrat stands in until the atlases load.
		local label = Create("TextLabel", {
			Name = "Fallback",
			BackgroundTransparency = 1,
			FontFace = (Tokens.font :: any)[STAND_IN[faceKey] or "display"],
			Text = text,
			TextSize = size * 0.92,
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
		-- The stand-in is ours: FontMirror must not redraw it.
		label:SetAttribute("KeepFont", true)
		table.insert(self.glyphs, label)
		self.frame.AutomaticSize = Enum.AutomaticSize.XY
		self.frame.Size = UDim2.fromOffset(0, 0)
		-- A first guess, then the real measurement (in design pixels, before UI scaling).
		local lines = string.split(text, "\n")
		local longest = 0
		for _, line in ipairs(lines) do
			longest = math.max(longest, utf8.len(line) or #line)
		end
		self.width = math.min(longest * label.TextSize * 0.55, props.maxWidth or math.huge)
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
	local plainCaps = if props.plainCaps == nil then faceKey == "Title" else props.plainCaps
	-- In Aktura, all-capitals words are drawn in Melodrama Bold at Aktura's capital height (the height a
	-- plain capital reaches: the x-height times PLAIN_CAP_SCALE).
	local alt: Face? = nil
	local altScale: number? = nil
	local altIds: { string }? = nil
	if faceKey == "Title" then
		local head = (faceOf("Head"))
		local headIds = atlasIds(head)
		local xGlyph = face.glyphs["x"]
		local capGlyph = head.glyphs["H"]
		if headIds and xGlyph and capGlyph and #xGlyph >= 8 and #capGlyph >= 8 and capGlyph[7] > 0 then
			alt = head
			altIds = headIds
			altScale = scale * (xGlyph[7] * PLAIN_CAP_SCALE) / capGlyph[7]
		end
	end
	local lines = layout(face, text, scale, tracking, props.maxWidth, tabular, alt, altScale)
	local widest = 0
	for _, line in ipairs(lines) do
		widest = math.max(widest, line.width)
	end
	local height = lineHeight * math.max(#lines - 1, 0) + (face.ascent + face.descent) * scale
	for index, line in ipairs(lines) do
		local shift = 0
		if props.align == "center" then
			shift = (widest - line.width) / 2
		elseif props.align == "right" then
			shift = widest - line.width
		end
		local baseline = face.ascent * scale + lineHeight * (index - 1)
		local items = place(face, line.chars, scale, tracking, tabular, alt, altScale)
		for _, item in ipairs(items) do
			local v = item.glyph
			if #v >= 8 then
				local glyphScale = scale
				local glyph = v
				local atlas = ids
				if item.alt and altIds and altScale then
					glyphScale = altScale
					atlas = altIds
				elseif plainCaps and PLAIN_CAPS[item.char] and face.glyphs[string.lower(item.char)] then
					-- A plain capital: the lower-case letter, enlarged to the height of a capital.
					glyph = face.glyphs[string.lower(item.char)]
					glyphScale = scale * PLAIN_CAP_SCALE
				end
				local left = if item.slot
					then item.x + (face.digit / 2 - glyph[4] / 2) * scale
					else item.x + glyph[6] * glyphScale
				local image = Create("ImageLabel", {
					Name = "Glyph",
					BackgroundTransparency = 1,
					Image = atlas[glyph[1]],
					ImageRectOffset = Vector2.new(glyph[2], glyph[3]),
					ImageRectSize = Vector2.new(glyph[4], glyph[5]),
					ImageColor3 = color,
					ImageTransparency = transparency,
					Size = UDim2.fromOffset(glyph[4] * glyphScale, glyph[5] * glyphScale),
					Position = UDim2.fromOffset(shift + left, baseline - glyph[7] * glyphScale),
					ZIndex = zIndex,
					Parent = self.frame,
				})
				table.insert(self.glyphs, image)
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

-- Draws the text again (after changing props such as `upper` by hand).
function GlyphText.refresh(self: GlyphText)
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

-- Cuts the text in: each letter blinks on in turn (a hard cut, no fade), flashing `flashColor` (white by
-- default) for a moment before it takes the text colour. Returns the time it takes.
function GlyphText.write(self: GlyphText, duration: number?, flashColor: Color3?): number
	local total = duration or 0.8
	local count = #self.glyphs
	if count == 0 or Motion.isReduced() then
		return 0
	end
	local color = self.props.color or Tokens.color.bone
	local target = self.props.transparency or 0
	local flash = flashColor or Tokens.color.white
	local step = total / count
	for index, glyph in ipairs(self.glyphs) do
		if glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = 1
			task.delay(step * (index - 1), function()
				if glyph.Parent then
					glyph.ImageColor3 = flash
					glyph.ImageTransparency = target
					task.delay(0.09, function()
						if glyph.Parent then
							glyph.ImageColor3 = color
						end
					end)
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
