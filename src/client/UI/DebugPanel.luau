-- Studio-only test panel (F2): force the next phase, a win, or an elimination, print every
-- role, and add coins or XP. The server only listens in Studio with Config.STUDIO_DEBUG on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DebugPanel = {}

local window: Frame

function DebugPanel.init()
	if not (RunService:IsStudio() and Config.STUDIO_DEBUG) then
		return
	end
	local DebugRemote = Net.event("Debug")

	window = Widgets.panel({
		Name = "DebugPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 90),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.overlay,
	})
	Widgets.padding(window, 10)
	Widgets.list(window, 6)
	Widgets.label({
		Text = "DEBUG (F2)",
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.secret,
		LayoutOrder = 1,
		Parent = window,
	})
	local target = Widgets.textbox({
		PlaceholderText = "Target alias (e.g. Raven)",
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
		Parent = window,
	})

	local order = 2
	local function add(text: string, command: string, needsTarget: boolean?)
		order += 1
		Widgets.button({
			Text = text,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = order,
			Parent = window,
		}, function()
			DebugRemote:FireServer(command, if needsTarget then target.Text else nil)
		end)
	end
	add("Next phase", "nextPhase")
	add(Terms.f("{Agency} wins"), "winTeam")
	add(Terms.f("{Hand} wins"), "winHand")
	add("Kill target", "kill", true)
	add("Vote out target", "voteOut", true)
	add("Print roles to Output", "roster")
	add("+500 coins", "coins")
	add("+500 XP", "xp")

	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.F2 then
			window.Visible = not window.Visible
		end
	end)
end

return DebugPanel
