--!strict
-- Where Roblox's jump button is on this screen, in the pixels every AbsolutePosition uses. The lobby keeps
-- its card above it (the HUD draws over Roblox's touch controls, so a card left there takes the jump tap).
--
-- The button is read from Roblox's own TouchGui, because its size and place change with the screen and with
-- Roblox's versions. Until that exists the engine's default place stands in (Shared/UI/TouchSafe). On a
-- device without touch controls there is no button and `jump` returns nil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Signal"))
local TouchSafe = require(Shared:WaitForChild("UI"):WaitForChild("TouchSafe"))

local Responsive = require(script.Parent.Responsive)
local Screens = require(script.Parent.Parent.Screens)

local TouchControls = {}

-- Fired when the button appears, moves or changes size, and when the device class changes.
TouchControls.Changed = Signal.new()

local button: GuiObject? = nil
-- Fills the full-screen layer: the whole screen, for the default place.
local probe: Frame? = nil

-- The jump button's rectangle on screen, or nil where there are no touch controls.
function TouchControls.jump(): Rect?
	if not Responsive.isTouch() then
		return nil
	end
	local found = button
	if found and found.Parent then
		local at, size = found.AbsolutePosition, found.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			return Rect.new(at, at + size)
		end
	end
	local screen = probe
	if not screen then
		return nil
	end
	local rect = TouchSafe.defaultJump(screen.AbsoluteSize)
	return Rect.new(screen.AbsolutePosition + rect.Min, screen.AbsolutePosition + rect.Max)
end

local function changed()
	TouchControls.Changed:Fire()
end

local function adopt(found: GuiObject)
	if button == found then
		return
	end
	button = found
	found:GetPropertyChangedSignal("AbsolutePosition"):Connect(changed)
	found:GetPropertyChangedSignal("AbsoluteSize"):Connect(changed)
	changed()
end

local function watch(touchGui: Instance)
	local function look(item: Instance)
		if item.Name == "JumpButton" and item:IsA("GuiObject") then
			adopt(item)
		end
	end
	for _, item in ipairs(touchGui:GetDescendants()) do
		look(item)
	end
	touchGui.DescendantAdded:Connect(look)
end

function TouchControls.init()
	local frame = Instance.new("Frame")
	frame.Name = "TouchProbe"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Active = false
	frame.Parent = Screens.world
	probe = frame
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(changed)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("TouchGui")
	if existing then
		watch(existing)
	end
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == "TouchGui" then
			watch(child)
		end
	end)
	Responsive.Changed:Connect(changed)
end

return TouchControls
