--!strict
-- Ransom-note lettering: every letter is its own cut-out box (white, black or grey; Aktura or Melodrama),
-- tilted a few degrees, with a hard shadow. Used for the game's title and for CASE CLOSED only.
--
--   local title = Ransom.new({ text = Terms.GAME, size = 62, Parent = frame })
--   title:play()                     -- the letters fall into place, one after another
--   Ransom.new({ text = "Case Closed", size = 58, hand = true })   -- two letters turn red
--
-- The arrangement is deterministic (the same text always looks the same) and follows the rules written at
-- the top of art/scripts/ui/wordmark.py, which draws the same title as an image for the lobby monolith.
-- KEEP THE TWO IN STEP.

local Create = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Create"))

local Motion = require(script.Parent.Parent.Core.Motion)
local GlyphText = require(script.Parent.GlyphText)
local Tokens = require(script.Parent.Tokens)

local Ransom = {}
Ransom.__index = Ransom

local C = Tokens.color

-- { box colour, letter colour, face, light outline } - the same seven as the style board.
local STYLES = {
	{ C.white, C.g0, "Title", false },
	{ C.g0, C.white, "Head", true },
	{ C.g3, C.white, "Title", true },
	{ C.white, C.g0, "RnLight", false },
	{ C.g5, C.g0, "Head", false },
	{ C.g0, C.white, "Title", true },
	{ C.g6, C.g0, "RnMedium", false },
}

local FNV_PRIME_LOW = 403 -- 16777619 = 2^24 + 403
local MOD = 4294967296

export type Props = {
	text: string,
	size: number?, -- the em the letters are cut at (px)
	hand: boolean?, -- two letters turn red: Diavolo's side won
	seed: string?,
	Name: string?,
	Parent: Instance?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Visible: boolean?,
}

export type Ransom = typeof(setmetatable(
	{} :: {
		frame: Frame,
		letters: { { holder: CanvasGroup, scale: UIScale, rotation: number, dy: number } },
		size: number,
		width: number,
		height: number,
	},
	Ransom
))

-- FNV-1a of the text's UTF-8 bytes, then xorshift32; rnd() = x / 2^32.
local function newRandom(text: string): () -> number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * FNV_PRIME_LOW) % MOD
	end
	local x = if h == 0 then 1 else h
	return function()
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		return x / MOD
	end
end

type Spec = { char: string, style: number, rot: number, scale: number, dy: number, red: boolean }

-- The per-letter choices in order; false marks a space.
local function arrange(text: string, hand: boolean, seed: string): { Spec | boolean }
	local rnd = newRandom(text .. seed)
	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	local letters = 0
	for _, char in ipairs(chars) do
		if char ~= " " then
			letters += 1
		end
	end
	local redA, redB = -1, -1
	if hand and letters > 0 then
		redA = math.floor(rnd() * letters)
		redB = (redA + 3 + math.floor(rnd() * math.max(1, letters - 4))) % letters
	end
	local out: { Spec | boolean } = {}
	local last, n = -1, 0
	for _, char in ipairs(chars) do
		if char == " " then
			table.insert(out, false)
		else
			local k = math.floor(rnd() * #STYLES)
			if k == last then
				k = (k + 1) % #STYLES
			end
			last = k
			local rot = rnd() * 12 - 6
			local scale = 0.86 + rnd() * 0.3
			local dy = math.floor(rnd() * 8 - 4 + 0.5)
			local upper = n == 0 or rnd() < 0.55
			if STYLES[k + 1][3] == "Title" then
				upper = false -- Aktura's capitals are ornate; its lower case is the readable blackletter
			end
			table.insert(out, {
				char = if upper then string.upper(char) else string.lower(char),
				style = k + 1,
				rot = rot,
				scale = scale,
				dy = dy,
				red = n == redA or n == redB,
			})
			n += 1
		end
	end
	return out
end

function Ransom.new(props: Props): Ransom
	local size = props.size or 62
	local em = size
	local specs = arrange(props.text, props.hand == true, props.seed or "")
	local shadowOf = function(s: number): number
		return math.max(1, math.floor(0.06 * s + 0.5))
	end
	-- Room for the tallest box, its shadow and the vertical wobble.
	local rowHeight = math.ceil(1.10 * em * 1.16 + shadowOf(em * 1.16) + 2 * 4 * em / 62)
	local frame = Create("Frame", {
		Name = props.Name or "Ransom",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, rowHeight),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, math.floor(0.05 * em + 0.5)),
		Parent = frame,
	})
	local letters = {}
	local order = 0
	local self = setmetatable({
		frame = frame,
		letters = letters,
		size = size,
		width = 0,
		height = rowHeight,
	}, Ransom)
	for _, spec in ipairs(specs) do
		order += 1
		if type(spec) ~= "table" then
			Create("Frame", {
				Name = "Space",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(math.floor(0.32 * em + 0.5), 1),
				LayoutOrder = order,
				Parent = frame,
			})
		else
			local box = STYLES[spec.style]
			local bg, fg, faceName, outline = box[1], box[2], box[3], box[4]
			if spec.red then
				bg, fg, outline = C.danger, C.white, false
			end
			local s = em * spec.scale
			local advance = GlyphText.measure(faceName, spec.char, s)
			local boxW, boxH = math.floor(advance + 0.24 * s + 0.5), math.floor(1.10 * s + 0.5)
			local shadow = shadowOf(s)
			local slot = Create("Frame", {
				Name = "Letter",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(boxW + shadow, rowHeight),
				LayoutOrder = order,
				Parent = frame,
			})
			local holder = Create("CanvasGroup", {
				Name = "Holder",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, spec.dy * em / 62),
				Size = UDim2.fromOffset(boxW + shadow, boxH + shadow),
				Rotation = spec.rot,
				Parent = slot,
			})
			local scale = Create("UIScale", { Scale = 1, Parent = holder })
			Create("Frame", {
				Name = "Shadow",
				BackgroundColor3 = C.g0,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(shadow, shadow),
				Size = UDim2.fromOffset(boxW, boxH),
				Parent = holder,
			})
			local body = Create("Frame", {
				Name = "Box",
				BackgroundColor3 = if outline then C.g6 else bg,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(boxW, boxH),
				Parent = holder,
			})
			if outline then
				local ring = math.max(1, math.floor(0.05 * s + 0.5))
				Create("Frame", {
					Name = "Face",
					BackgroundColor3 = bg,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(ring, ring),
					Size = UDim2.new(1, -2 * ring, 1, -2 * ring),
					Parent = body,
				})
			end
			-- The letter's top sits half-leading below the box's padding; the glyphs hang from there.
			local face = GlyphText.face(faceName)
			local ascent, descent = face.ascent / face.em, face.descent / face.em
			local top = 0.06 * s + ((1 - (ascent + descent)) / 2) * s
			GlyphText.new({
				face = faceName,
				text = spec.char,
				size = s,
				color = fg,
				plainCaps = false,
				Position = UDim2.fromOffset(0.12 * s, top),
				ZIndex = 2,
				Parent = body,
			})
			table.insert(letters, { holder = holder, scale = scale, rotation = spec.rot, dy = spec.dy * em / 62 })
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self.width = frame.AbsoluteSize.X
	end)
	return self
end

-- Drops every letter in turn: each starts large, tilted and see-through above its place and snaps in with
-- a small overshoot (340 ms, 45 ms apart). Honours reduced motion (letters just stay put).
function Ransom.play(self: Ransom)
	if Motion.isReduced() then
		return
	end
	for index, letter in ipairs(self.letters) do
		local holder, scale = letter.holder, letter.scale
		holder.GroupTransparency = 1
		holder.Rotation = letter.rotation - 18
		holder.Position = UDim2.new(0.5, 0, 0.5, letter.dy - 0.9 * self.size)
		scale.Scale = 2.2
		task.delay((index - 1) * 0.045, function()
			if holder.Parent then
				Motion.tween(holder, { GroupTransparency = 0 }, 0.12)
				Motion.tween(holder, { Rotation = letter.rotation }, 0.34, Enum.EasingStyle.Back)
				Motion.tween(holder, { Position = UDim2.new(0.5, 0, 0.5, letter.dy) }, 0.34, Enum.EasingStyle.Back)
				Motion.tween(scale, { Scale = 1 }, 0.34, Enum.EasingStyle.Back)
			end
		end)
	end
end

-- Hides the letters (ready for play()).
function Ransom.hide(self: Ransom)
	for _, letter in ipairs(self.letters) do
		letter.holder.GroupTransparency = 1
	end
end

function Ransom.destroy(self: Ransom)
	self.frame:Destroy()
end

return Ransom
