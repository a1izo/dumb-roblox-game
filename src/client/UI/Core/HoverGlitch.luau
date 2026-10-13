--!strict
-- A hovered (or gamepad-selected) button on the lobby's own page (READY, the menu, the card's two buttons)
-- blips once as the pointer arrives, then stays still and readable. Like every glitch it belongs to the
-- lobby: while Glitch is turned off (in a match) nothing happens and buttons stay calm.
--
-- Inside a window or a pop-up nothing glitches: what you are about to press has to stay readable, and the
-- control's own hover look (a lighter fill, a nudge) is the whole answer there. A tap never glitches either:
-- a touch screen has no hover, the effect only hid the label under the finger, and it could stick.
--
-- A button sitting alone in a CanvasGroup marked with the attribute `GlitchWrap` (the lobby menu) glitches
-- through that wrapper, so it also blinks; any other button gets the split and the tears on itself.

local UserInputService = game:GetService("UserInputService")

local Glitch = require(script.Parent.Glitch)
local Screens = require(script.Parent.Parent.Screens)

local HoverGlitch = {}

local active: { [GuiObject]: any } = setmetatable({}, { __mode = "k" }) :: any

local function targetOf(gui: GuiObject): GuiObject
	local parent = gui.Parent
	if parent and parent:IsA("CanvasGroup") and parent:GetAttribute("GlitchWrap") == true then
		return parent
	end
	return gui
end

-- Only the lobby's page is loud; windows and pop-ups live in the layers above the HUD.
function HoverGlitch.isLoud(gui: GuiObject): boolean
	return gui:IsDescendantOf(Screens.hud)
end

function HoverGlitch.begin(gui: GuiObject)
	if active[gui] or not Glitch.isEnabled() or not gui.Parent then
		return
	end
	if not HoverGlitch.isLoud(gui) or UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
		return
	end
	local handle = Glitch.attach(targetOf(gui), { loop = false, enter = false })
	active[gui] = handle
	handle:hover(true)
end

function HoverGlitch.finish(gui: GuiObject)
	local handle = active[gui]
	if handle then
		active[gui] = nil
		handle:hover(false)
		handle:destroy()
	end
end

-- Wires a button: one blip when hovered or selected.
function HoverGlitch.wire(button: GuiButton)
	button.MouseEnter:Connect(function()
		HoverGlitch.begin(button)
	end)
	button.MouseLeave:Connect(function()
		HoverGlitch.finish(button)
	end)
	button.SelectionGained:Connect(function()
		HoverGlitch.begin(button)
	end)
	button.SelectionLost:Connect(function()
		HoverGlitch.finish(button)
	end)
	button.AncestryChanged:Connect(function()
		if not button:IsDescendantOf(game) then
			HoverGlitch.finish(button)
		end
	end)
end

return HoverGlitch
