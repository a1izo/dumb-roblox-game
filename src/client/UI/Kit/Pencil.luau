--!strict
-- Pencil: the OMORI look on every line (the user, 2026-11-10: "almost everything should have the wobbly pencil
-- drawn look like in OMORI ... like 2 or more images are going back and forth like an animation, and it looks
-- scribbled by hand"). Every outline (a UIStroke round a box) and every rule (a thin filled frame) under the
-- watched root is drawn again as a pencil line: three drawings of it (art/scripts/ui/textures.py, UiPencilBox1..3
-- and UiPencilLine1..3) swapped 8 times a second, each line on a beat of its own so a screen never swaps in step.
-- Kit/Boil does the same for the text.
--
--   Pencil.watch(playerGui)
--
-- The code that made a stroke keeps using it (its colour, see-through, Enabled and thickness are followed): the
-- stroke itself is only drawn 0 thick while its pencil line shows. Left alone: anything under NoBoil or NoPencil
-- (the emote wheel, the title), round things (a corner rounder than 8 px), text strokes, boxes too small for a
-- drawn corner. Until the drawings are loaded (or if they failed) the plain lines stay.

local Motion = require(script.Parent.Parent.Core.Motion)
local Textures = require(script.Parent.Textures)

local Pencil = {}

local FPS = 8
-- Each swap is spread over this many steps, and only lines on screen are swapped (as Kit/Boil does).
local SLICES = 4
local BOXES = { "UiPencilBox1", "UiPencilBox2", "UiPencilBox3" }
local LINES = { "UiPencilLine1", "UiPencilLine2", "UiPencilLine3" }
-- the drawings' measures (textures.py): the box's slice and where its line runs, the rule's slice and height
local BOX_SLICE = Rect.new(40, 40, 216, 216)
local BOX_CORNER = 40
local BOX_INSET = 18
local BOX_WIDTH = 4.6
local LINE_SLICE = Rect.new(64, 0, 448, 48)
local LINE_HEIGHT = 48
local LINE_WIDTH = 4.4
local ROUND = 8 -- px: a corner rounder than this is a round thing (a dot, a pill): left alone
local RULE = 3 -- px: a filled frame this thin and at least RULE_LONG long is a rule
local RULE_LONG = 24

type Drawn = { images: { string }, phase: number, slot: number, shown: boolean }

local drawn: { [ImageLabel]: Drawn } = setmetatable({}, { __mode = "k" }) :: any
local frame = 0

local function still(item: Instance): boolean
	local node: Instance? = item
	while node do
		if node:GetAttribute("NoBoil") or node:GetAttribute("NoPencil") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function hasLayout(gui: Instance): boolean
	return gui:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

local function overlay(name: string, images: { string }): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Slice
	image.Active = false
	image.Interactable = false
	image:SetAttribute("PaperKeep", true) -- (it follows its line's colour, already swapped onto paper)
	image:SetAttribute("NoBoil", true)
	local phase = math.random(0, 2)
	image.Image = Textures.id(images[(frame + phase) % 3 + 1])
	drawn[image] = { images = images, phase = phase, slot = math.random(0, SLICES - 1), shown = true }
	return image
end

-- An outline -----------------------------------------------------------------------------------------------------

local function edge(stroke: UIStroke)
	local host = stroke.Parent
	if not host or not host:IsA("GuiObject") or host:GetAttribute("PencilEdge") or still(host) then
		return
	end
	if
		(host:IsA("TextLabel") or host:IsA("TextButton") or host:IsA("TextBox"))
		and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
	then
		return -- (a stroke round the letters)
	end
	local corner = host:FindFirstChildOfClass("UICorner")
	if corner and (corner.CornerRadius.Scale > 0.02 or corner.CornerRadius.Offset > ROUND) then
		return
	end
	if host.Rotation ~= 0 then
		return
	end
	-- (inside the box, or beside it when the box lays out its children or scrolls them)
	local inside = not hasLayout(host) and not host:IsA("ScrollingFrame")
	local parent = host.Parent
	if not inside and (not parent or not parent:IsA("GuiObject") or hasLayout(parent)) then
		return
	end
	host:SetAttribute("PencilEdge", true)

	local image = overlay("PencilEdge", BOXES)
	image.SliceCenter = BOX_SLICE
	local thickness = stroke.Thickness
	local wroteThickness = 0
	local function update()
		local size = host.AbsoluteSize
		local side = math.min(size.X, size.Y)
		local width = math.max(1.6, thickness * 1.6)
		local scale = math.min(width / BOX_WIDTH, side / (2 * BOX_CORNER))
		local show = stroke.Enabled and side >= 10 and host.Parent ~= nil
		image.Visible = show and (inside or host.Visible)
		local zero = if show then 0 else thickness
		if stroke.Thickness ~= zero then
			wroteThickness = zero
			stroke.Thickness = zero
		end
		if not show then
			return
		end
		image.SliceScale = scale
		image.ImageColor3 = stroke.Color
		image.ImageTransparency = stroke.Transparency
		-- the line's middle sits where the stroke's did: just outside the edge (inside it if the box clips)
		local centre = if host.ClipsDescendants and inside then -width / 2 else thickness / 2
		local out = centre + BOX_INSET * scale
		if inside then
			local padding = host:FindFirstChildOfClass("UIPadding")
			local l, t, r, b = 0, 0, 0, 0
			if padding then
				l, t = padding.PaddingLeft.Offset, padding.PaddingTop.Offset
				r, b = padding.PaddingRight.Offset, padding.PaddingBottom.Offset
			end
			image.AnchorPoint = Vector2.zero
			image.Position = UDim2.fromOffset(-out - l, -out - t)
			image.Size = UDim2.new(1, 2 * out + l + r, 1, 2 * out + t + b)
			image.ZIndex = host.ZIndex
		else
			local anchor = host.AnchorPoint
			image.AnchorPoint = anchor
			image.Position = host.Position + UDim2.fromOffset(out * (2 * anchor.X - 1), out * (2 * anchor.Y - 1))
			image.Size = host.Size + UDim2.fromOffset(2 * out, 2 * out)
			image.ZIndex = host.ZIndex + 1
			image.LayoutOrder = host.LayoutOrder
		end
	end
	stroke.Changed:Connect(function(prop: string)
		if prop == "Thickness" then
			if math.abs(stroke.Thickness - wroteThickness) < 1e-3 then
				return
			end
			thickness = stroke.Thickness -- (its maker changed it: a hover, a choice)
		end
		update()
	end)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	if not inside then
		for _, prop in ipairs({ "Position", "Size", "AnchorPoint", "Visible", "ZIndex" }) do
			host:GetPropertyChangedSignal(prop):Connect(update)
		end
	end
	update()
	image.Parent = if inside then host else parent
	stroke.AncestryChanged:Connect(function()
		if stroke.Parent ~= host then
			drawn[image] = nil
			image:Destroy()
			host:SetAttribute("PencilEdge", nil)
		end
	end)
	host.Destroying:Once(function()
		image:Destroy()
	end)
end

-- A rule --------------------------------------------------------------------------------------------------------

local function rule(gui: Frame)
	if gui:GetAttribute("PencilRule") or gui.Rotation ~= 0 or still(gui) then
		return
	end
	if gui.BackgroundTransparency >= 0.95 or gui:FindFirstChildWhichIsA("GuiObject") then
		return
	end
	if gui:FindFirstChildOfClass("UIStroke") or gui:FindFirstChildOfClass("UIGradient") then
		return
	end
	local size = gui.Size
	local across = size.Y.Scale == 0
		and size.Y.Offset > 0
		and size.Y.Offset <= RULE
		and (size.X.Scale > 0 or size.X.Offset >= RULE_LONG)
	local down = size.X.Scale == 0
		and size.X.Offset > 0
		and size.X.Offset <= RULE
		and (size.Y.Scale > 0 or size.Y.Offset >= RULE_LONG)
	if not across and not down then
		return
	end
	gui:SetAttribute("PencilRule", true)
	local image = overlay("PencilRule", LINES)
	image.SliceCenter = LINE_SLICE
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	local wanted = gui.BackgroundTransparency
	local function update()
		local abs = gui.AbsoluteSize
		local thin = if across then abs.Y else abs.X
		local long = if across then abs.X else abs.Y
		local width = math.max(1.6, thin * 1.5)
		local scale = math.min(width / LINE_WIDTH, long / 128)
		image.SliceScale = scale
		image.ImageColor3 = gui.BackgroundColor3
		image.ImageTransparency = wanted
		image.ZIndex = gui.ZIndex
		if across then
			image.Rotation = 0
			image.Size = UDim2.new(1, 0, 0, LINE_HEIGHT * scale)
		else
			image.Rotation = 90
			image.Size = UDim2.fromOffset(long, LINE_HEIGHT * scale)
		end
	end
	gui:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		if gui.BackgroundTransparency ~= 1 then
			wanted = gui.BackgroundTransparency -- (its maker changed it: a fade)
			gui.BackgroundTransparency = 1
		end
		update()
	end)
	for _, prop in ipairs({ "AbsoluteSize", "BackgroundColor3", "ZIndex" }) do
		gui:GetPropertyChangedSignal(prop):Connect(update)
	end
	update()
	gui.BackgroundTransparency = 1
	image.Parent = gui
end

-- Watching ------------------------------------------------------------------------------------------------------

local function consider(item: Instance)
	if item:IsA("UIStroke") then
		-- (once its maker has set it up and parented it where it belongs)
		task.defer(function()
			if item.Parent then
				edge(item)
			end
		end)
	elseif item.ClassName == "Frame" then
		task.defer(function()
			if item.Parent then
				rule(item :: Frame)
			end
		end)
	end
end

-- Every outline and rule under `root` is drawn in pencil, now and as they are added (once the drawings are in).
function Pencil.watch(root: Instance)
	Textures.whenReady(function()
		if not Textures.has(BOXES[1]) or not Textures.has(LINES[1]) then
			return
		end
		for _, item in ipairs(root:GetDescendants()) do
			consider(item)
		end
		root.DescendantAdded:Connect(consider)
	end)
end

local cost = 0
local step = 0

-- What one step of a swap costs, in milliseconds of script time (a running average; for the performance checks).
function Pencil.cost(): number
	return cost
end

-- On screen at all: it and every frame above it visible, its screen enabled.
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

task.spawn(function()
	while true do
		task.wait(1 / (FPS * SLICES))
		local slot = step % SLICES
		if slot == 0 then
			frame = (frame + 1) % 3
		end
		-- (which lines are on screen is looked up twice a second)
		local look = (step // SLICES) % 4 == 0
		step += 1
		local started = os.clock()
		local reduced = Motion.isReduced()
		for image, entry in pairs(drawn) do
			if entry.slot ~= slot then
				continue
			end
			if look then
				entry.shown = onScreen(image)
			end
			if entry.shown then
				local index = if reduced then 1 else (frame + entry.phase) % 3 + 1
				image.Image = Textures.id(entry.images[index])
			end
		end
		cost += ((os.clock() - started) * 1000 - cost) * 0.1
	end
end)

return Pencil
