-- Quick-chat phrases and emotes: the only way to talk outside meetings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Actions = require(script.Parent.Parent.Input.Actions)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local QuickChatRemote = Net.event("QuickChat")

local QuickChatPanel = {}

local panel: Frame
local firstButton: TextButton? = nil

function QuickChatPanel.toggle()
	Router.toggle("quickChat")
end

function QuickChatPanel.close()
	Router.close("quickChat", "user")
end

function QuickChatPanel.init()
	panel = Widgets.panel({
		Name = "QuickChat",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0.9, 0, 0, 246),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(640, 246))
	Widgets.label({
		Text = "QUICK CHAT",
		Font = Theme.fonts.black,
		TextSize = Theme.text.small,
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
		local button = Widgets.button({
			Text = phrase,
			TextSize = Theme.text.small,
			LayoutOrder = index,
			Parent = phrases,
		}, function()
			QuickChatRemote:FireServer(index)
			QuickChatPanel.close()
		end)
		firstButton = firstButton or button
	end
	Widgets.label({
		Text = "EMOTES",
		Font = Theme.fonts.black,
		TextSize = Theme.text.small,
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
			TextSize = Theme.text.small,
			Variant = "ghost",
			Size = UDim2.new(0.2, -6, 1, 0),
			LayoutOrder = index,
			Parent = emotes,
		}, function()
			EmoteController.play(emote.id)
			QuickChatPanel.close()
		end)
	end
	Router.register("quickChat", {
		layer = "panel",
		window = panel,
		allowed = function(view)
			return (view.living or view.specter) and not Actions.CUTSCENE_PHASES[view.phase]
		end,
		show = function()
			panel.Visible = true
		end,
		hide = function()
			panel.Visible = false
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return QuickChatPanel
