-- The Specter HUD, under the spectate bar: lost souls gathered, jumps between the map and
-- the meeting room, and up/down buttons on touch screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local GhostController = require(script.Parent.Parent.Specter.GhostController)
local Responsive = require(script.Parent.Core.Responsive)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors

local GhostHud = {}

local bar: Frame
local soulsLabel: TextLabel
local liftPad: Frame

local function refresh()
	local show = ClientState.isSpecter()
	bar.Visible = show
	liftPad.Visible = show and Responsive.isTouch()
end

local function holdLift(button: GuiButton, value: number)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			GhostController.setTouchLift(value)
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			GhostController.setTouchLift(0)
		end
	end)
end

function GhostHud.init()
	bar = Widgets.panel({
		Name = "SpecterHud",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(460, 44),
		Visible = false,
		Parent = Screens.hud,
	})
	local ribbon = Widgets.ribbon({ Position = UDim2.fromOffset(-10, -12), Parent = bar }, Terms.f("{SPECTER}"), C.team)
	ribbon.ZIndex = 2
	soulsLabel = Widgets.display({
		Text = "LOST SOULS 0/8",
		TextSize = Theme.text.bodyLarge,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(0, 160, 0, 22),
		Parent = bar,
	})
	Widgets.button({
		Text = "Map",
		TextSize = Theme.text.small,
		Variant = "secondary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -126, 0, 6),
		Size = UDim2.fromOffset(110, 32),
		Parent = bar,
	}, function()
		GhostController.jump("map")
	end)
	Widgets.button({
		Text = "Meeting room",
		TextSize = Theme.text.small,
		Variant = "secondary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(112, 32),
		Parent = bar,
	}, function()
		GhostController.jump("meeting")
	end)

	liftPad = Widgets.frame({
		Name = "SpecterLift",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -200),
		Size = UDim2.fromOffset(70, 150),
		Visible = false,
		Parent = Screens.hud,
	})
	local up = Widgets.button({ Text = "UP", Slant = false, Size = UDim2.fromOffset(70, 70), Parent = liftPad })
	local down = Widgets.button({
		Text = "DOWN",
		Slant = false,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.fromOffset(70, 70),
		Parent = liftPad,
	})
	holdLift(up, 1)
	holdLift(down, -1)

	GhostController.DutiesChanged:Connect(function(done, max)
		soulsLabel.Text = string.format("LOST SOULS %d/%d", done, max)
	end)
	ClientState.PublicChanged:Connect(refresh)
	Responsive.Changed:Connect(refresh)
	refresh()
end

return GhostHud
