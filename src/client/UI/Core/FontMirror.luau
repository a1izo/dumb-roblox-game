-- Melodrama everywhere. Roblox cannot load custom fonts, so every text the game sets in the plain stand-in
-- font (Montserrat: labels, lists, tips, toasts, name tags, the signs and boards built in the world) is
-- redrawn here in Melodrama from the glyph atlases, the way the titles are:
--   * the label keeps its Text, layout and everything code does with it, but stops drawing its own letters
--     (MaxVisibleGraphemes = 0); a GlyphText inside it draws them instead, Semibold (Bold for bold text),
--     never under MIN_SIZE px;
--   * colour, transparency, alignment, wrapping, TextScaled, truncation ("…"), text stroke (a dark copy
--     underneath) and simple rich text (tags dropped, <s> struck through, <b> in Bold) follow the label;
--   * a label that sized itself to its text (AutomaticSize) is sized to the Melodrama letters instead;
--   * a text box keeps what you type in the stand-in font (Roblox draws typing and its cursor); only its
--     grey hint is redrawn.
-- Left alone: anything tagged KeepFont (or inside something tagged so: the debug panel, GlyphText's own
-- stand-in while its atlas loads), and text with a character the atlases do not have (the Japanese accents).
-- Chat and Roblox's own menus are out of reach.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Base = require(script.Parent.Parent.Kit.Base)
local GlyphText = require(script.Parent.Parent.Kit.GlyphText)

local FontMirror = {}

local MIN_SIZE = 14
local LINE = 1.15 -- line height, times the size (GlyphText's default)

type Mirror = {
	label: GuiObject,
	glyph: any?,
	shadow: any?,
	strike: Frame?,
	key: string,
	autoX: boolean,
	autoY: boolean,
	pending: boolean,
	width: number,
	connections: { RBXScriptConnection },
}

local mirrors: { [Instance]: Mirror } = setmetatable({}, { __mode = "k" }) :: any
local semi = GlyphText.face("Semi")

local function isStandIn(label: Instance): boolean
	local ok, family = pcall(function()
		return (label :: any).FontFace.Family
	end)
	return ok and type(family) == "string" and string.find(family, "Montserrat", 1, true) ~= nil
end

local function kept(item: Instance): boolean
	local node: Instance? = item
	while node do
		if node:GetAttribute("KeepFont") or CollectionService:HasTag(node, "KeepFont") then
			return true
		end
		node = node.Parent
	end
	return false
end

local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }

-- The plain text of a label, and whether it was struck through or bold (rich text, roughly).
local function plain(text: string, rich: boolean): (string, boolean, boolean)
	if not rich then
		return text, false, false
	end
	local strike = string.find(text, "<s>", 1, true) ~= nil
	local bold = string.find(text, "<b>", 1, true) ~= nil
	local out = string.gsub(text, "<br%s*/?>", "\n")
	out = string.gsub(out, "<[^>]*>", "")
	out = string.gsub(out, "&(%a+);", function(name: string): string
		return ENTITIES[name] or ("&" .. name .. ";")
	end)
	return out, strike, bold
end

-- True when every character has a Melodrama glyph (else the label keeps its own font).
local function covered(text: string): boolean
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		if char ~= "\n" and char ~= " " and not semi.glyphs[char] then
			return false
		end
	end
	return true
end

local function padding(label: GuiObject): (number, number, number, number)
	local pad = label:FindFirstChildOfClass("UIPadding")
	if not pad then
		return 0, 0, 0, 0
	end
	return pad.PaddingLeft.Offset, pad.PaddingRight.Offset, pad.PaddingTop.Offset, pad.PaddingBottom.Offset
end

-- The largest size at which `text` fits a box (TextScaled), wrapping when the label wraps.
local function fitSize(face: string, text: string, width: number, height: number, wrapped: boolean): number
	local best = MIN_SIZE
	for size = 100, MIN_SIZE, -2 do
		local fits
		if wrapped then
			local lines = 0
			for _, paragraph in ipairs(string.split(text, "\n")) do
				local w = GlyphText.measure(face, paragraph, size)
				lines += math.max(1, math.ceil(w / math.max(width, 1)))
			end
			fits = lines * size * LINE <= height
		else
			local longest = 0
			for _, paragraph in ipairs(string.split(text, "\n")) do
				longest = math.max(longest, GlyphText.measure(face, paragraph, size))
			end
			fits = longest <= width and #string.split(text, "\n") * size * LINE <= height
		end
		if fits then
			best = size
			break
		end
	end
	return best
end

-- `text` cut to fit `width` with an ellipsis (one line).
local function truncate(face: string, text: string, size: number, width: number): string
	if GlyphText.measure(face, text, size) <= width then
		return text
	end
	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	local low, high = 0, #chars
	while low < high do
		local mid = (low + high + 1) // 2
		local candidate = table.concat(chars, "", 1, mid) .. "…"
		if GlyphText.measure(face, candidate, size) <= width then
			low = mid
		else
			high = mid - 1
		end
	end
	return table.concat(chars, "", 1, low) .. "…"
end

local ALIGN_X = {
	[Enum.TextXAlignment.Left] = { 0, "left" },
	[Enum.TextXAlignment.Center] = { 0.5, "center" },
	[Enum.TextXAlignment.Right] = { 1, "right" },
}
local ALIGN_Y = {
	[Enum.TextYAlignment.Top] = 0,
	[Enum.TextYAlignment.Center] = 0.5,
	[Enum.TextYAlignment.Bottom] = 1,
}

local function clear(m: Mirror)
	if m.glyph then
		m.glyph.frame:Destroy()
		m.glyph = nil
	end
	if m.shadow then
		m.shadow.frame:Destroy()
		m.shadow = nil
	end
	if m.strike then
		m.strike:Destroy()
		m.strike = nil
	end
	m.key = ""
end

local function render(m: Mirror)
	m.pending = false
	local label = m.label :: any
	if not label.Parent then
		return
	end
	local isBox = label:IsA("TextBox")
	local raw = label.Text
	local color = label.TextColor3
	local transparency = label.TextTransparency
	if isBox then
		-- Only the grey hint of an empty box is redrawn.
		if label.Text ~= "" or label:IsFocused() then
			clear(m)
			return
		end
		raw = tostring(label:GetAttribute("FontMirrorHint") or "")
		color = label.PlaceholderColor3
	end
	local text, struck, bold = plain(raw, label.RichText)
	if text == "" then
		clear(m)
		return
	end
	local weight = label.FontFace.Weight
	local face = if bold
			or weight == Enum.FontWeight.Bold
			or weight == Enum.FontWeight.ExtraBold
			or weight == Enum.FontWeight.Heavy
		then "Head"
		else "Semi"
	local scale = Base.scaleOf(label)
	local left, right, top, bottom = padding(label)
	local boxWidth = label.AbsoluteSize.X / scale - left - right
	local boxHeight = label.AbsoluteSize.Y / scale - top - bottom
	local size = math.max(label.TextSize, MIN_SIZE)
	if label.TextScaled then
		size = fitSize(face, text, boxWidth, boxHeight, label.TextWrapped)
	end
	local maxWidth = if label.TextWrapped and not m.autoX and boxWidth > 0 then boxWidth else nil
	if label.TextTruncate ~= Enum.TextTruncate.None and not label.TextWrapped and not m.autoX and boxWidth > 0 then
		text = truncate(face, text, size, boxWidth)
	end
	local alignX = ALIGN_X[label.TextXAlignment] or ALIGN_X[Enum.TextXAlignment.Center]
	local alignY = ALIGN_Y[label.TextYAlignment] or 0.5
	local stroked = label.TextStrokeTransparency < 1
	local key = table.concat({ face, tostring(size), tostring(maxWidth), alignX[2], tostring(stroked) }, "|")
	if key ~= m.key then
		clear(m)
		m.key = key
		local props = {
			face = face,
			text = text,
			size = size,
			color = color,
			transparency = transparency,
			align = alignX[2],
			maxWidth = maxWidth,
			AnchorPoint = Vector2.new(alignX[1], alignY),
			Position = UDim2.fromScale(alignX[1], alignY),
			ZIndex = label.ZIndex,
			Parent = label,
		}
		if stroked then
			local shadowProps = table.clone(props)
			shadowProps.color = label.TextStrokeColor3
			shadowProps.transparency = math.max(label.TextStrokeTransparency, transparency)
			shadowProps.Position = props.Position + UDim2.fromOffset(1, 1)
			m.shadow = GlyphText.new(shadowProps)
		end
		local glyph = GlyphText.new(props)
		m.glyph = glyph
		glyph.Changed:Connect(function()
			if m.glyph == glyph then
				FontMirror.schedule(m.label)
			end
		end)
	else
		m.glyph:set(text)
		m.glyph:setColor(color)
		m.glyph:setTransparency(transparency)
		if m.shadow then
			m.shadow:set(text)
			m.shadow:setTransparency(math.max(label.TextStrokeTransparency, transparency))
		end
	end
	local glyph = m.glyph
	-- A label that sized itself to its text takes the Melodrama letters' size.
	if m.autoX or m.autoY then
		local current = label.Size
		local w = math.ceil(glyph.width) + left + right
		local h = math.ceil(glyph.height) + top + bottom
		local wanted = UDim2.new(
			if m.autoX then 0 else current.X.Scale,
			if m.autoX then w else current.X.Offset,
			if m.autoY then 0 else current.Y.Scale,
			if m.autoY then h else current.Y.Offset
		)
		if wanted ~= current then
			label.Size = wanted
		end
	end
	if struck and not m.strike then
		m.strike = Base.make("Frame", {
			Name = "MirrorStrike",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = label.ZIndex + 1,
			Parent = glyph.frame,
		})
	elseif not struck and m.strike then
		m.strike:Destroy()
		m.strike = nil
	end
end

-- Renders a label's mirror once, after the property changes of this frame have settled.
function FontMirror.schedule(label: Instance)
	local m = mirrors[label]
	if not m or m.pending then
		return
	end
	m.pending = true
	task.defer(render, m)
end

local function detach(label: Instance)
	local m = mirrors[label]
	if not m then
		return
	end
	mirrors[label] = nil
	for _, connection in ipairs(m.connections) do
		connection:Disconnect()
	end
	clear(m)
	local gui = label :: any
	if not gui:IsA("TextBox") then
		gui.MaxVisibleGraphemes = -1
	else
		local hint = gui:GetAttribute("FontMirrorHint")
		if hint then
			gui.PlaceholderText = hint
			gui:SetAttribute("FontMirrorHint", nil)
		end
	end
end

local function attach(label: Instance)
	if mirrors[label] or not label.Parent or not isStandIn(label) or kept(label) then
		return
	end
	local gui = label :: any
	local isBox = gui:IsA("TextBox")
	local sample = if isBox then gui.PlaceholderText else plain(gui.Text, gui.RichText)
	if gui:IsA("TextButton") and sample == "" then
		-- A bare clickable area (its look is drawn by other things): only if it ever gets text.
		local watch
		watch = gui:GetPropertyChangedSignal("Text"):Connect(function()
			if gui.Text ~= "" then
				watch:Disconnect()
				attach(label)
			end
		end)
		return
	end
	if not covered(sample) then
		-- Not now (a Japanese accent, a check mark...); look again when the text changes.
		local watch
		watch = gui:GetPropertyChangedSignal(if isBox then "PlaceholderText" else "Text"):Connect(function()
			if covered(if isBox then gui.PlaceholderText else plain(gui.Text, gui.RichText)) then
				watch:Disconnect()
				attach(label)
			end
		end)
		return
	end
	local auto = gui.AutomaticSize
	local m: Mirror = {
		label = gui,
		glyph = nil,
		shadow = nil,
		strike = nil,
		key = "",
		autoX = auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY,
		autoY = auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY,
		pending = false,
		width = 0,
		connections = {},
	}
	mirrors[label] = m
	if m.autoX or m.autoY then
		gui.AutomaticSize = Enum.AutomaticSize.None
	end
	if isBox then
		gui:SetAttribute("FontMirrorHint", gui.PlaceholderText)
		gui.PlaceholderText = ""
	else
		gui.MaxVisibleGraphemes = 0
	end
	local function on(property: string, handler: (() -> ())?)
		table.insert(
			m.connections,
			gui:GetPropertyChangedSignal(property):Connect(handler or function()
				FontMirror.schedule(gui)
			end)
		)
	end
	for _, property in ipairs({
		"Text",
		"TextColor3",
		"TextTransparency",
		"TextSize",
		"TextWrapped",
		"TextScaled",
		"TextXAlignment",
		"TextYAlignment",
		"TextTruncate",
		"TextStrokeTransparency",
		"RichText",
	}) do
		on(property)
	end
	on("AbsoluteSize", function()
		-- Only a new width (wrapping, centring) needs a redraw; the height is ours.
		local width = math.floor(gui.AbsoluteSize.X)
		if width ~= m.width or gui.TextScaled then
			m.width = width
			FontMirror.schedule(gui)
		end
	end)
	on("FontFace", function()
		if not isStandIn(gui) then
			detach(gui)
		else
			FontMirror.schedule(gui)
		end
	end)
	if isBox then
		on("PlaceholderText", function()
			-- Code sets a new hint now and then ("Pick a suspect first"): keep it, draw it ourselves.
			if gui.PlaceholderText ~= "" then
				gui:SetAttribute("FontMirrorHint", gui.PlaceholderText)
				gui.PlaceholderText = ""
				FontMirror.schedule(gui)
			end
		end)
		on("PlaceholderColor3")
		table.insert(
			m.connections,
			gui.Focused:Connect(function()
				FontMirror.schedule(gui)
			end)
		)
		table.insert(
			m.connections,
			gui.FocusLost:Connect(function()
				FontMirror.schedule(gui)
			end)
		)
	end
	table.insert(
		m.connections,
		gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(game) then
				detach(gui)
			end
		end)
	)
	FontMirror.schedule(gui)
end

local function consider(item: Instance)
	if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
		-- After this frame, so the properties set right after parenting are in place.
		task.defer(attach, item)
	end
end

local function watchTree(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		consider(item)
	end
	root.DescendantAdded:Connect(consider)
end

function FontMirror.init()
	watchTree(Players.LocalPlayer:WaitForChild("PlayerGui"))
	watchTree(workspace)
end

return FontMirror
