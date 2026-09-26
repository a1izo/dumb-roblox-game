-- Quick-chat phrases and emotes: the only way to talk outside meetings. A page rises above
-- the bottom of the screen with the phrases in a grid and the emotes beneath.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Actions = require(script.Parent.Parent.Input.Actions)
local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local QuickChatRemote = Net.event("QuickChat")

local C = Kit.color
local T = Kit.Tokens

local QuickChatPanel = {}

local HEIGHT = 300

local panel: Frame
local firstButton: TextButton? = nil

function QuickChatPanel.toggle()
	Router.toggle("quickChat")
end

function QuickChatPanel.close()
	Router.close("quickChat", "user")
end

local function caption(text: string, y: number, parent: Instance)
	Kit.label({
		Text = string.upper(text),
		font = "label",
		size = "micro",
		color = C.dim,
		Position = UDim2.fromOffset(0, y),
		Parent = parent,
	})
end

function QuickChatPanel.init()
	local page, content = Kit.page({
		Name = "QuickChat",
		tone = "raised",
		padding = T.space.l,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.new(0.9, 0, 0, HEIGHT),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	Kit.Base.maxSize(panel, Vector2.new(680, HEIGHT))
	caption("Quick chat", 0, content)
	local phrases = Kit.frame({
		Name = "Phrases",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 144),
		Parent = content,
	})
	Kit.grid(phrases, UDim2.new(0.25, -T.space.s, 0, 40), T.space.s)
	for index, phrase in ipairs(QuickChat.PHRASES) do
		local button = Kit.button({
			text = phrase,
			variant = "secondary",
			size = "s",
			upper = false,
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = index,
			Parent = phrases,
		}, function()
			QuickChatRemote:FireServer(index)
			QuickChatPanel.close()
		end)
		firstButton = firstButton or button
	end
	caption("Emotes", 176, content)
	local emotes = Kit.frame({
		Name = "Emotes",
		Position = UDim2.fromOffset(0, 198),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})
	Kit.list(emotes, T.space.s, true)
	local passEmotes: { [TextButton]: string } = {}
	for index, emote in ipairs(QuickChat.EMOTES) do
		local button = Kit.button({
			text = emote.name,
			variant = "ghost",
			size = "s",
			LayoutOrder = index,
			Parent = emotes,
		}, function()
			EmoteController.play(emote.id)
			QuickChatPanel.close()
		end)
		if emote.pass then
			passEmotes[button] = emote.pass
		end
	end
	local function refreshPassEmotes()
		local passes = if ClientState.profile then ClientState.profile.passes or {} else {}
		for button, pass in pairs(passEmotes) do
			button.Visible = table.find(passes, pass) ~= nil
		end
	end
	ClientState.ProfileChanged:Connect(refreshPassEmotes)
	refreshPassEmotes()
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
