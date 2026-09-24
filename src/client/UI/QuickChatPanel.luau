-- Quick-chat phrases and emotes: the only way to talk outside meetings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local QuickChatRemote = Net.event("QuickChat")

local QuickChatPanel = {}

local panel: Frame

function QuickChatPanel.toggle()
	panel.Visible = not panel.Visible
end

function QuickChatPanel.close()
	panel.Visible = false
end

function QuickChatPanel.init()
	panel = Widgets.panel({
		Name = "QuickChat",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.9, 0, 0, 238),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(620, 238))
	Widgets.label({
		Text = "QUICK CHAT  (Q)",
		Font = Theme.fonts.black,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = panel,
	})
	local phrases = Widgets.frame({
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 128),
		Parent = panel,
	})
	Widgets.grid(phrases, UDim2.new(0.25, -6, 0, 36), 6)
	for index, phrase in ipairs(QuickChat.PHRASES) do
		Widgets.button({
			Text = phrase,
			TextSize = 14,
			LayoutOrder = index,
			Parent = phrases,
		}, function()
			QuickChatRemote:FireServer(index)
			panel.Visible = false
		end)
	end
	Widgets.label({
		Text = "EMOTES",
		Font = Theme.fonts.black,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 166),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = panel,
	})
	local emotes = Widgets.frame({
		Position = UDim2.fromOffset(12, 188),
		Size = UDim2.new(1, -24, 0, 36),
		Parent = panel,
	})
	Widgets.list(emotes, 6, true)
	for index, emote in ipairs(QuickChat.EMOTES) do
		Widgets.button({
			Text = emote.name,
			TextSize = 14,
			BackgroundColor3 = Theme.colors.panelLight,
			Size = UDim2.new(0.2, -6, 1, 0),
			LayoutOrder = index,
			Parent = emotes,
		}, function()
			EmoteController.play(emote.id)
			panel.Visible = false
		end)
	end
end

return QuickChatPanel
