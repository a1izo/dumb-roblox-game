--!strict
-- The red pointing hand (OMORI's): one for the whole game. Whatever is chosen right now (the button under the
-- mouse, the gamepad's selection, a picked tab) gets it beside it, bobbing, and it jumps when the choice moves. The
-- button itself never changes look when chosen; the hand says it.
--
-- The hand (Assets.images.PointerHand, art/scripts/ui/cursors.py) points with its index finger alone, and it never
-- lies over anything else on its screen (the user's picture of 2026-11-03: chosen, SKIP had it over the end of BEGIN
-- beside it). It goes to the left of what it points at, else above it, to its right or below it, whichever side is
-- clear, turned to point that way; the left when none is.
--
--   Pointer.point(button)   -- the hand goes to `button`
--   Pointer.release(button) -- and leaves, if it is still there

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Screens = require(script.Parent.Parent.Screens)
local Base = require(script.Parent.Base)
local Boil = require(script.Parent.Boil)
local Icon = require(script.Parent.Icon)
local Tokens = require(script.Parent.Tokens)

local Pointer = {}

local SIZE = 48 -- the hand's square cell on the screen (design px); pointing right, the hand fills 44 x 25 of it
local CELL = 96 -- a cell of the picture, px
local GAP = 6 -- px between the fingertip and what it points at
local BOB = 4 -- px it draws back every other beat
local BEAT = 0.25
local RECHECK = 0.4 -- seconds between looks for a clear side while the same thing stays chosen
local BACKDROP = 0.25 -- anything covering more than this share of the screen is a backdrop, not in the way

-- A side of what is pointed at: the picture's cell for it, where the fingertip and the hand itself lie in the cell
-- (shares of it: the cell pointing right turned or mirrored, as art/scripts/ui/cursors.py lays the sheet out), the
-- way the hand draws back as it bobs, and the stand-in icon's turn.
type Side = {
	cell: Vector2,
	tip: Vector2,
	low: Vector2,
	high: Vector2,
	away: Vector2,
	turn: number,
}
local SIDES: { Side } = {
	-- left of it, pointing right
	{
		cell = Vector2.new(0, 0),
		tip = Vector2.new(0.958, 0.5),
		low = Vector2.new(0.056, 0.353),
		high = Vector2.new(0.96, 0.88),
		away = Vector2.new(-1, 0),
		turn = 90,
	},
	-- above it, pointing down
	{
		cell = Vector2.new(0, 1),
		tip = Vector2.new(0.5, 0.958),
		low = Vector2.new(0.119, 0.056),
		high = Vector2.new(0.647, 0.96),
		away = Vector2.new(0, -1),
		turn = 180,
	},
	-- right of it, pointing left
	{
		cell = Vector2.new(1, 0),
		tip = Vector2.new(0.042, 0.5),
		low = Vector2.new(0.04, 0.353),
		high = Vector2.new(0.944, 0.88),
		away = Vector2.new(1, 0),
		turn = -90,
	},
	-- below it, pointing up
	{
		cell = Vector2.new(1, 1),
		tip = Vector2.new(0.5, 0.042),
		low = Vector2.new(0.353, 0.042),
		high = Vector2.new(0.88, 0.944),
		away = Vector2.new(0, 1),
		turn = 0,
	},
}

local hand: Frame
local picture: GuiObject
local drawn = false -- the picture is the uploaded sheet (else the stand-in icon)
local target: GuiObject? = nil
local side: Side = SIDES[1]
local chosenFor: GuiObject? = nil
local lastLook = 0

local function build()
	hand = Base.frame({
		Name = "Pointer",
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = false,
		ZIndex = 1000,
		Parent = Screens.system,
	})
	local sheet = Assets.images.PointerHand or ""
	if sheet ~= "" then
		local image = Base.make("ImageLabel", {
			Name = "Hand",
			BackgroundTransparency = 1,
			Image = Assets.contentId(sheet),
			ImageRectSize = Vector2.new(CELL, CELL),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1000,
			Parent = hand,
		})
		Boil.attach(image, 1)
		picture = image
		drawn = true
	else
		-- (until the picture is uploaded: the icon atlas's hand, in red, turned to point the side's way)
		local icon = Icon.new({
			name = "hand",
			size = 28,
			color = Tokens.color.danger,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 1000,
			Parent = hand,
		})
		Boil.attach(icon, 1)
		picture = icon
	end
end

local function turnTo(next: Side)
	side = next
	if drawn and picture:IsA("ImageLabel") then
		picture.ImageRectOffset = next.cell * CELL
	else
		picture.Rotation = next.turn
	end
end

-- Where the hand's cell would sit (its top left and size, absolute px) to point at `gui` from `s`, `back` px further
-- off.
local function cellFor(gui: GuiObject, s: Side, back: number, scale: number): (Vector2, number)
	local size = SIZE * scale
	local at, extent = gui.AbsolutePosition, gui.AbsoluteSize
	local tip = at + extent * Vector2.new(0.5, 0.5) + extent * s.away * 0.5 + s.away * (GAP + back) * scale
	return tip - s.tip * size, size
end

local function overlaps(aLow: Vector2, aHigh: Vector2, bLow: Vector2, bHigh: Vector2): boolean
	return aLow.X < bHigh.X and bLow.X < aHigh.X and aLow.Y < bHigh.Y and bLow.Y < aHigh.Y
end

-- Whether something on the screen would be under the hand there: a button, a field, words or a picture, on the same
-- screen, shown (and not clipped away), and neither what is pointed at, inside it, nor round it.
local function inTheWay(item: GuiObject, current: GuiObject, low: Vector2, high: Vector2, screen: Vector2): boolean
	-- (the cheap tests first: most of a screen is nowhere near the hand)
	local at, extent = item.AbsolutePosition, item.AbsoluteSize
	if not overlaps(low, high, at, at + extent) or extent.X * extent.Y > screen.X * screen.Y * BACKDROP then
		return false
	end
	local shown = false
	if item:IsA("GuiButton") or item:IsA("TextBox") then
		shown = true
	elseif item:IsA("TextLabel") then
		shown = item.Text ~= "" and item.TextTransparency < 0.8
	elseif item:IsA("ImageLabel") then
		shown = item.Image ~= "" and item.ImageTransparency < 0.8
	end
	if not shown then
		return false
	end
	if item == current or item:IsDescendantOf(current) or current:IsDescendantOf(item) or item:IsDescendantOf(hand) then
		return false
	end
	-- (shown only if everything it sits in is, and inside whatever clips it)
	local node: Instance? = item
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
			if node ~= item and node.ClipsDescendants then
				local clipAt = node.AbsolutePosition
				if not overlaps(at, at + extent, clipAt, clipAt + node.AbsoluteSize) then
					return false
				end
			end
		end
		node = node.Parent
	end
	return true
end

-- The first side of `current` where the hand lies on the screen and over nothing; else the first where it lies over
-- nothing though a little off the screen's edge; the left when there is none.
local function choose(current: GuiObject, scale: number): Side
	local layer = current:FindFirstAncestorWhichIsA("LayerCollector")
	local camera = workspace.CurrentCamera
	if not layer or not camera then
		return SIDES[1]
	end
	local screen = camera.ViewportSize
	local items = layer:GetDescendants()
	local offEdge: Side? = nil
	for _, s in ipairs(SIDES) do
		local corner, size = cellFor(current, s, BOB, scale)
		local low, high = corner + s.low * size, corner + s.high * size
		local clear = true
		for _, item in ipairs(items) do
			if item:IsA("GuiObject") and inTheWay(item, current, low, high, screen) then
				clear = false
				break
			end
		end
		if clear then
			if low.X >= 0 and low.Y >= 0 and high.X <= screen.X and high.Y <= screen.Y then
				return s
			end
			offEdge = offEdge or s
		end
	end
	return offEdge or SIDES[1]
end

-- Puts the hand beside `gui`.
function Pointer.point(gui: GuiObject)
	target = gui
end

-- Takes the hand away from `gui` (nothing happens if it has moved on).
function Pointer.release(gui: GuiObject)
	if target == gui then
		target = nil
	end
end

build()

local beat = 0
RunService.RenderStepped:Connect(function(dt)
	local current = target
	if not current or not current.Parent or not current:IsDescendantOf(game) then
		hand.Visible = false
		target = nil
		return
	end
	-- (hidden when it, or anything it sits in, is hidden: a closed window leaves its buttons Visible)
	local node: Instance? = current
	while node and not node:IsA("LayerCollector") do
		if node:IsA("GuiObject") and not node.Visible then
			hand.Visible = false
			return
		end
		node = node.Parent
	end
	-- (hidden when what it points at sits in a screen that is hidden)
	local layer = current:FindFirstAncestorWhichIsA("LayerCollector")
	if layer and layer:IsA("ScreenGui") and not layer.Enabled then
		hand.Visible = false
		return
	end
	local scale = Base.scaleOf(hand)
	-- The side: looked for again when the choice moves, and now and then while it stays (things open and move).
	local now = os.clock()
	if current ~= chosenFor or now - lastLook > RECHECK then
		chosenFor, lastLook = current, now
		local next = choose(current, scale)
		if next ~= side then
			turnTo(next)
		end
	end
	beat += dt
	local back = if math.floor(beat / BEAT) % 2 == 1 then BOB else 0
	local corner = cellFor(current, side, back, scale)
	local origin = (hand.Parent :: GuiObject).AbsolutePosition
	local at = (corner - origin) / scale
	hand.Position = UDim2.fromOffset(math.floor(at.X), math.floor(at.Y))
	hand.Visible = true
end)

turnTo(SIDES[1])

return Pointer
