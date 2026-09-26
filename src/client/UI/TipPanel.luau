-- The anonymous tip box. Only Zero reads the tips and never learns who sent them. The tip is
-- typed on a parchment slip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local TipRemote = Net.event("Tip")

local C = Kit.color
local T = Kit.Tokens

local TipPanel = {}

local box: TextBox
local sendButton: TextButton

function TipPanel.open()
	Router.open("tip")
end

function TipPanel.init()
	local win = Kit.window({ name = "tip", title = "Anonymous tip box", size = "sheet", footer = true })
	Kit.label({
		Text = Terms.f("Only {zero} reads these tips, and never sees who sent them."),
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		Parent = win.body,
	})
	local sheet = Kit.card({
		Name = "Sheet",
		tone = "parchment",
		padding = T.space.m,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		Parent = win.body,
	})
	local _, field = Kit.field({
		placeholder = Terms.f("Your tip for {zero}…"),
		font = "document",
		size = "body",
		multiline = true,
		paper = true,
		maxLength = Config.TIP_MAX_LENGTH,
		Size = UDim2.fromScale(1, 1),
		Parent = sheet,
	})
	box = field
	sendButton = Kit.button(
		{ text = "Drop the tip", icon = "mail", variant = "primary", Parent = win.footer },
		function()
			if #box.Text > 0 then
				TipRemote:FireServer(box.Text)
				Router.close("tip", "user")
			end
		end
	)
	Kit.register(win, {
		allowed = function(view)
			return view.living and view.phase == "Investigation"
		end,
		show = function()
			box.Text = ""
		end,
		firstSelection = function()
			return sendButton
		end,
	})
end

return TipPanel
