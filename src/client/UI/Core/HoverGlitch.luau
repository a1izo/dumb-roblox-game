--!strict
-- A hovered (or gamepad-selected) button glitches hard and fast for as long as the pointer is on it; a tap on a
-- touch screen plays a short burst instead. Like every glitch it belongs to the lobby: while Glitch is turned off
-- (in a match) nothing happens and buttons stay calm.
--
-- A button sitting alone in a CanvasGroup marked with the attribute `GlitchWrap` (the lobby menu) glitches
-- through that wrapper, so it also blinks; any other button gets the split and the tears on itself.

local Glitch = require(script.Parent.Glitch)

local HoverGlitch = {}

local active: { [GuiObject]: any } = setmetatable({}, { __mode = "k" }) :: any

local function targetOf(gui: GuiObject): GuiObject
	local parent = gui.Parent
	if parent and parent:IsA("CanvasGroup") and parent:GetAttribute("GlitchWrap") == true then
		return parent
	end
	return gui
end

function HoverGlitch.begin(gui: GuiObject)
	if active[gui] or not Glitch.isEnabled() or not gui.Parent then
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

-- A short burst (a tap on a touch screen, where there is no hover).
function HoverGlitch.burst(gui: GuiObject, seconds: number?)
	HoverGlitch.begin(gui)
	task.delay(seconds or 0.3, HoverGlitch.finish, gui)
end

-- Wires a button: glitch while hovered or selected, a burst when tapped.
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
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			HoverGlitch.burst(button)
		end
	end)
	button.AncestryChanged:Connect(function()
		if not button:IsDescendantOf(game) then
			HoverGlitch.finish(button)
		end
	end)
end

return HoverGlitch
