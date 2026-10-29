--!strict
-- Menus are paper sheets (concept A): Paper.apply(root) turns everything under `root` that was written for the
-- dark (paper-coloured lettering, ink-ramp panels) into ink on paper, by swapping each colour of the ink ramp
-- for its partner on the paper ramp (Tokens.color.gN -> Tokens.paper.gN). Red is left alone. It keeps doing so
-- as things are added or recoloured later (a list rebuilt, a hover tint), so no screen has to be rewritten.
--
-- Anything with the attribute PaperKeep (or inside something that has it) keeps its own colours: the OMORI
-- buttons (an ink box on paper, like OMORI's), item art, portraits.

local Tokens = require(script.Parent.Tokens)

local Paper = {}

local C = Tokens.color
local P = Tokens.paper

local function key(color: Color3): string
	return color:ToHex()
end

local SWAP: { [string]: Color3 } = {}
local function pair(dark: Color3, light: Color3)
	SWAP[key(dark)] = light
end
pair(C.g0, P.g0)
pair(C.g1, P.g1)
pair(C.g2, P.g2)
pair(C.g3, P.g3)
pair(C.g4, P.g4)
pair(C.g5, P.g5)
pair(C.g6, P.g6)
pair(C.white, P.white)

local PROPS: { [string]: { string } } = {
	TextLabel = { "TextColor3", "BackgroundColor3", "TextStrokeColor3" },
	TextButton = { "TextColor3", "BackgroundColor3" },
	TextBox = { "TextColor3", "BackgroundColor3", "PlaceholderColor3" },
	ImageLabel = { "ImageColor3", "BackgroundColor3" },
	ImageButton = { "ImageColor3", "BackgroundColor3" },
	Frame = { "BackgroundColor3" },
	CanvasGroup = { "BackgroundColor3", "GroupColor3" },
	ScrollingFrame = { "BackgroundColor3", "ScrollBarImageColor3" },
	UIStroke = { "Color" },
}

-- The paper partner of a dark-ramp colour, or nil for any other colour.
function Paper.swap(color: Color3): Color3?
	return SWAP[key(color)]
end

local function kept(item: Instance, root: Instance): boolean
	local node: Instance? = item
	while node and node ~= root do
		if node:GetAttribute("PaperKeep") then
			return true
		end
		node = node.Parent
	end
	return false
end

-- What Paper itself last wrote to each property: the paper ramp mirrors the ink ramp (paper is the ink ramp's
-- lightest colour), so a written colour is itself a key; it must never be swapped again, or two swaps loop.
local written: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function swapProp(item: Instance, prop: string)
	local object = item :: any
	local now = key(object[prop])
	local mine = written[item]
	if mine and mine[prop] == now then
		return
	end
	local light = SWAP[now]
	if light then
		mine = mine or {}
		written[item] = mine
		mine[prop] = key(light)
		object[prop] = light
	end
end

local function convert(item: Instance, root: Instance)
	local props = PROPS[item.ClassName]
	if not props or kept(item, root) then
		return
	end
	for _, prop in ipairs(props) do
		swapProp(item, prop)
	end
	if wired[item] then
		return
	end
	wired[item] = true
	-- (recoloured later, say by a hover or a list rebuilt: swap that too)
	for _, prop in ipairs(props) do
		item:GetPropertyChangedSignal(prop):Connect(function()
			if not kept(item, root) then
				swapProp(item, prop)
			end
		end)
	end
end

-- Turns everything under `root` into ink on paper, now and from now on.
function Paper.apply(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		convert(item, root)
	end
	root.DescendantAdded:Connect(function(item)
		-- (once its maker has set its colours)
		task.defer(convert, item, root)
	end)
end

-- Marks `gui` (and all inside it) as keeping its own colours on a sheet.
function Paper.keep(gui: Instance)
	gui:SetAttribute("PaperKeep", true)
end

return Paper
