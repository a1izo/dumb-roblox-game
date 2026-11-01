--!strict
-- Line boil (OMORI's hand-drawn wobble): a drawn thing redraws a hair differently 8 times a second, cycling
-- three states. Each attached object gets its own three small offsets (and a hair of rotation), so a screen
-- full of frames never moves in step. Lines and frames boil; of the text, only big headers and a button's text
-- while it is hovered (the owner, 2026-11-01: on small text it "makes small text unreadable"). The case summary
-- at the end stays still altogether (NoBoil on it).
--
--   Boil.attach(frame)          -- 1 px, the default for frames, rules and the hand
--   Boil.attach(title, 2, 0.4)  -- 2 px and up to 0.4 degrees, for big lettering
--   Boil.watch(playerGui)       -- big headers and button text under it, now and later (Boil.text on each)
--
-- When other code moves the object (a layout, a tween), its new place becomes the one it boils around.
-- Text boils letter by letter (the owner: "letter independent not word independent"): Roblox cannot move one
-- letter, so a copy over the label sets each letter a pixel or two larger or smaller in each state. Anything with the attribute NoBoil (or inside something
-- that has it) stays still: the emote wheel, text boxes being typed in.

local Motion = require(script.Parent.Parent.Core.Motion)

local Boil = {}

local FPS = 8
local STATES = 3

type Entry = {
	base: UDim2,
	rot: number,
	offsets: { Vector2 },
	turns: { number },
	-- what Boil itself last wrote: change events arrive after the change (deferred), so a flag set around the
	-- write is gone by then; an event carrying the value Boil wrote is its own and is ignored, or the wobble would
	-- become the new home and the thing would walk off
	wrotePosition: UDim2?,
	wroteRotation: number?,
	-- inside something marked NoBoil (looked up once it is first shown)
	still: boolean?,
}

local entries: { [GuiObject]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local frame = 0

local function place(gui: GuiObject, entry: Entry)
	local index = frame + 1
	local offset = if Motion.isReduced() then Vector2.zero else entry.offsets[index]
	local turn = if Motion.isReduced() then 0 else entry.turns[index]
	local position = entry.base + UDim2.fromOffset(offset.X, offset.Y)
	local rotation = entry.rot + turn
	entry.wrotePosition = position
	entry.wroteRotation = rotation
	gui.Position = position
	gui.Rotation = rotation
end

-- Makes `gui` boil: `amount` px of wander (default 1) and `turn` degrees of tilt at most (default 0).
function Boil.attach(gui: GuiObject, amount: number?, turn: number?)
	if entries[gui] then
		return
	end
	local px = amount or 1
	local tilt = turn or 0
	local random = Random.new()
	local offsets, turns = {}, {}
	for index = 1, STATES do
		-- (the first state sits home, so a still frame is where the layout put it)
		if index == 1 then
			offsets[index] = Vector2.zero
			turns[index] = 0
		else
			offsets[index] = Vector2.new(random:NextInteger(-px, px), random:NextInteger(-px, px))
			turns[index] = random:NextNumber(-tilt, tilt)
		end
	end
	local entry: Entry = { base = gui.Position, rot = gui.Rotation, offsets = offsets, turns = turns }
	entries[gui] = entry
	gui:GetPropertyChangedSignal("Position"):Connect(function()
		if gui.Position ~= entry.wrotePosition then
			entry.base = gui.Position
		end
	end)
	gui:GetPropertyChangedSignal("Rotation"):Connect(function()
		-- (a rotation reads back at lower precision than it was written: compare loosely)
		local wrote = entry.wroteRotation
		if wrote == nil or math.abs(gui.Rotation - wrote) > 1e-3 then
			entry.rot = gui.Rotation
		end
	end)
	gui.Destroying:Once(function()
		entries[gui] = nil
	end)
end

-- Stops `gui` boiling and puts it back where it belongs.
function Boil.detach(gui: GuiObject)
	local entry = entries[gui]
	if entry then
		entries[gui] = nil
		gui.Position = entry.base
		gui.Rotation = entry.rot
	end
end

-- Text --------------------------------------------------------------------------------------------

type TextEntry = {
	copy: TextLabel,
	-- whether it boils now: a header always, a button's text while the button is hovered
	active: boolean,
	-- the copy's text in each state, worked out again when the label's text changes
	states: { string },
	shown: boolean,
	drawn: number?,
}

local texts: { [GuiObject]: TextEntry } = setmetatable({}, { __mode = "k" }) :: any

local function still(item: Instance): boolean
	local node: Instance? = item
	while node do
		if node:GetAttribute("NoBoil") then
			return true
		end
		node = node.Parent
	end
	return false
end

local ESCAPE = { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;", ['"'] = "&quot;", ["'"] = "&apos;" }
local LONGEST = 400 -- letters: longer text (a page of reading) keeps still
local HEADER = 32 -- px: text this big or bigger is a header and always boils

-- The label's text with each letter at its own size, one string per state (the first at the label's size).
local function letterStates(text: string, rich: boolean, size: number, seed: number): { string }
	local random = Random.new(seed)
	local swing = math.max(1, math.floor(size * 0.07 + 0.5))
	-- (cut into tags, entities and letters; only letters change size)
	local pieces: { { text: string, letter: boolean } } = {}
	local at = 1
	local length = #text
	while at <= length do
		local char = string.sub(text, at, at)
		if rich and char == "<" then
			local close = string.find(text, ">", at, true) or length
			table.insert(pieces, { text = string.sub(text, at, close), letter = false })
			at = close + 1
		elseif rich and char == "&" and string.find(text, "^&%a+;", at) then
			local close = string.find(text, ";", at, true) :: number
			table.insert(pieces, { text = string.sub(text, at, close), letter = true })
			at = close + 1
		else
			local nextAt = utf8.offset(text, 2, at) or (length + 1)
			local letter = string.sub(text, at, nextAt - 1)
			if string.match(letter, "^%s$") then
				table.insert(pieces, { text = letter, letter = false })
			else
				table.insert(pieces, { text = if rich then letter else (ESCAPE[letter] or letter), letter = true })
			end
			at = nextAt
		end
	end
	local states = {}
	for index = 1, STATES do
		local out = table.create(#pieces)
		for _, piece in ipairs(pieces) do
			if piece.letter and index > 1 then
				local grow = random:NextInteger(-swing, swing)
				if grow ~= 0 then
					table.insert(out, string.format('<font size="%d">%s</font>', size + grow, piece.text))
					continue
				end
			end
			table.insert(out, piece.text)
		end
		states[index] = table.concat(out)
	end
	return states
end

local MIRRORED = {
	"FontFace",
	"TextSize",
	"TextColor3",
	"TextTransparency",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"TextXAlignment",
	"TextYAlignment",
	"TextWrapped",
	"LineHeight",
	"ZIndex",
}

-- Makes a label's letters boil, each on its own: a copy over it draws the text with every letter at a size of
-- its own in each state, while the label itself (which code keeps using: its text, fades, layout) is hidden.
function Boil.text(label: GuiObject)
	local source = label :: any
	if texts[label] or label:IsA("TextBox") or source.TextScaled or still(label) then
		return
	end
	if label:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return -- (a button laying out its icon and text: a copy in there would be laid out too)
	end
	local old = label:FindFirstChild("BoilLetters")
	if old then
		old:Destroy() -- (a clone of a boiling label)
	end
	local hide = label:FindFirstChildOfClass("UIGradient")
	if hide and hide.Name ~= "BoilHide" then
		return -- (its own gradient: leave it be)
	end
	if source.BackgroundTransparency < 1 then
		return -- (the hiding gradient would take its fill too)
	end
	-- (a button's text, whatever its size, only while the button is hovered; other text only if it is a header)
	local button: GuiButton? = if label:IsA("GuiButton")
		then label :: any
		else label:FindFirstAncestorWhichIsA("GuiButton")
	local header = button == nil and source.TextSize >= HEADER
	if not header and not button then
		return
	end
	local copy = Instance.new("TextLabel")
	copy.Name = "BoilLetters"
	copy.BackgroundTransparency = 1
	-- No height, and a pixel narrower than the label: a label that sizes itself to what it holds counts its
	-- children (and adds its padding on top), so a full-size copy would hold it open and grow it every frame.
	-- Its text still draws (a label's text is not cut to its box), set on the line its alignment calls for.
	copy.Size = UDim2.new(1, -1, 0, 0)
	copy.TextTruncate = Enum.TextTruncate.None
	copy.RichText = true
	local function align()
		local y = source.TextYAlignment
		copy.Position = if y == Enum.TextYAlignment.Top
			then UDim2.new()
			elseif y == Enum.TextYAlignment.Bottom then UDim2.new(0, 0, 1, -1)
			else UDim2.fromScale(0, 0.5)
	end
	align()
	label:GetPropertyChangedSignal("TextYAlignment"):Connect(align)
	copy:SetAttribute("PaperKeep", true) -- (it follows the label's colours, already on paper)
	copy:SetAttribute("KeepFont", true)
	copy:SetAttribute("NoBoil", true) -- (or the watcher would boil the copy, and its copy, and on)
	local entry: TextEntry = { copy = copy, states = {}, shown = false, active = header }
	if not header and button then
		button.MouseEnter:Connect(function()
			entry.active = true
		end)
		button.MouseLeave:Connect(function()
			entry.active = false
		end)
	end
	local seed = math.random(1, 1e6)
	local function restate()
		local text = source.Text
		if utf8.len(text) and (utf8.len(text) :: number) > LONGEST then
			entry.states = { text, text, text }
		else
			local ok, states = pcall(letterStates, text, source.RichText, source.TextSize, seed)
			entry.states = if ok then states else { text, text, text }
		end
		entry.drawn = nil
		copy.Text = entry.states[frame + 1]
	end
	for _, prop in ipairs(MIRRORED) do
		(copy :: any)[prop] = source[prop]
		label:GetPropertyChangedSignal(prop):Connect(function()
			(copy :: any)[prop] = source[prop]
			if prop == "TextSize" then
				restate()
			end
		end)
	end
	label:GetPropertyChangedSignal("Text"):Connect(restate)
	label:GetPropertyChangedSignal("RichText"):Connect(restate)
	-- (the label's own letters hidden by a see-through gradient, which leaves its size, text and fades alone;
	-- hiding them with MaxVisibleGraphemes would size a self-sizing label as if it were empty)
	copy.MaxVisibleGraphemes = source.MaxVisibleGraphemes
	label:GetPropertyChangedSignal("MaxVisibleGraphemes"):Connect(function()
		copy.MaxVisibleGraphemes = source.MaxVisibleGraphemes
	end)
	restate()
	if not hide then
		local gradient = Instance.new("UIGradient")
		gradient.Name = "BoilHide"
		gradient.Transparency = NumberSequence.new(1)
		gradient.Parent = label
	end
	copy.Parent = label
	texts[label] = entry
	label.Destroying:Once(function()
		texts[label] = nil
	end)
end

-- Every text under `root` boils, now and as it is added.
function Boil.watch(root: Instance)
	local function consider(item: Instance)
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			-- (once its maker has set it up and parented it where it belongs)
			task.defer(function()
				if item.Parent then
					Boil.text(item)
				end
			end)
		end
	end
	for _, item in ipairs(root:GetDescendants()) do
		consider(item)
	end
	root.DescendantAdded:Connect(consider)
end

-- Whether a label is on screen at all (it and every frame above it visible, its screen enabled).
local function onScreen(gui: GuiObject): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local beat = 0

task.spawn(function()
	while true do
		task.wait(1 / FPS)
		frame = (frame + 1) % STATES
		beat += 1
		for gui, entry in pairs(entries) do
			if gui.Parent and gui.Visible then
				if entry.still == nil then
					entry.still = still(gui)
				end
				if not entry.still then
					place(gui, entry)
				end
			end
		end
		-- (which texts are on screen is looked up twice a second; only those are redrawn)
		local look = beat % 4 == 0
		local reduced = Motion.isReduced()
		for label, entry in pairs(texts) do
			if look then
				entry.shown = onScreen(label)
			end
			local state = if reduced or not entry.active then 1 else frame + 1
			if entry.shown and entry.drawn ~= state then
				entry.drawn = state
				entry.copy.Text = entry.states[state]
			end
		end
	end
end)

return Boil
