--!strict
-- The red pointing hand (OMORI's): one for the whole game. Whatever is chosen right now (the button under the
-- mouse, the gamepad's selection, a picked tab) gets it just to its left, bobbing, and it jumps when the choice
-- moves. The button itself never changes look when chosen; the hand says it.
--
--   Pointer.point(button)   -- the hand goes to `button`
--   Pointer.release(button) -- and leaves, if it is still there

local RunService = game:GetService("RunService")

local Screens = require(script.Parent.Parent.Screens)
local Base = require(script.Parent.Base)
local Boil = require(script.Parent.Boil)
local Icon = require(script.Parent.Icon)
local Textures = require(script.Parent.Textures)
local Tokens = require(script.Parent.Tokens)

local Pointer = {}

local SIZE = Vector2.new(40, 24)
local GAP = 6 -- px between the fingertip and what it points at
local BOB = 4 -- px it draws back every other beat
local BEAT = 0.25

local hand: GuiObject
local target: GuiObject? = nil

local function build()
	local holder = Base.frame({
		Name = "Pointer",
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		AnchorPoint = Vector2.new(1, 0.5),
		Visible = false,
		ZIndex = 1000,
		Parent = Screens.system,
	})
	-- The drawn hand when its texture is in; until then the icon atlas's hand, in red.
	local function draw()
		Base.clear(holder)
		local id = Textures.id("UiHand")
		if id ~= "" then
			Boil.attach(
				Base.make("ImageLabel", {
					Name = "Hand",
					BackgroundTransparency = 1,
					Image = id,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 1000,
					Parent = holder,
				}),
				1
			)
		else
			local icon = Icon.new({
				name = "hand",
				size = SIZE.Y + 4,
				color = Tokens.color.danger,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				ZIndex = 1000,
				Parent = holder,
			})
			icon.Rotation = 90
			Boil.attach(icon, 1)
		end
	end
	draw()
	Textures.whenReady(draw)
	hand = holder
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
	if not current or not current.Parent or not current.Visible or not current:IsDescendantOf(game) then
		hand.Visible = false
		target = nil
		return
	end
	-- (hidden when what it points at sits in a screen that is hidden)
	local layer = current:FindFirstAncestorWhichIsA("LayerCollector")
	if layer and layer:IsA("ScreenGui") and not layer.Enabled then
		hand.Visible = false
		return
	end
	beat += dt
	local back = if math.floor(beat / BEAT) % 2 == 1 then BOB else 0
	local scale = Base.scaleOf(hand)
	local origin = (hand.Parent :: GuiObject).AbsolutePosition
	local at = current.AbsolutePosition - origin
	local x = at.X / scale - GAP - back
	local y = (at.Y + current.AbsoluteSize.Y / 2) / scale
	hand.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	hand.Visible = true
end)

return Pointer
