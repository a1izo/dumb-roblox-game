-- The anonymous tip box. Only L reads the tips and never learns who sent them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local TipRemote = Net.event("Tip")

local TipPanel = {}

local window: Frame
local box: TextBox
local sendButton: TextButton

function TipPanel.open()
	Router.open("tip")
end

function TipPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Anonymous tip box", Vector2.new(460, 320), function()
		Router.close("tip", "user")
	end)
	Widgets.label({
		Text = Terms.f("Only {zero} reads these tips, and never sees who sent them."),
		TextSize = 14,
		TextColor3 = Theme.colors.muted,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = body,
	})
	box = Widgets.textbox({
		PlaceholderText = Terms.f("Your tip for {zero}..."),
		Font = Theme.fonts.typewriter,
		TextColor3 = Theme.colors.ink,
		BackgroundColor3 = Theme.colors.paper,
		PlaceholderColor3 = Theme.colors.inkMuted,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -86),
		Parent = body,
	})
	Widgets.limitLength(box, Config.TIP_MAX_LENGTH)
	sendButton = Widgets.button({
		Text = "DROP THE TIP",
		Font = Theme.fonts.black,
		Variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 46),
		Parent = body,
	}, function()
		if #box.Text > 0 then
			TipRemote:FireServer(box.Text)
			Router.close("tip", "user")
		end
	end)
	Router.register("tip", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return view.living and view.phase == "Investigation"
		end,
		show = function()
			box.Text = ""
			window.Visible = true
		end,
		hide = function()
			window.Visible = false
		end,
		firstSelection = function()
			return sendButton
		end,
	})
end

return TipPanel
