-- Meeting panel: the feed of Zero's anonymous screen, and Zero's input for it. Opens for
-- every participant during the meeting and the vote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local LScreenRemote = Net.event("LScreen")

local MeetingPanel = {}

local panel: Frame
local feed: ScrollingFrame
local inputRow: Frame
local inputBox: TextBox
local deskButton: TextButton
local messageCount = 0

local function addMessage(text: string, clock: string?)
	messageCount += 1
	Widgets.label({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		Font = Theme.fonts.typewriter,
		TextSize = Theme.text.body,
		Text = string.format("[%s]  %s", clock or "--:--", text),
		LayoutOrder = -messageCount,
		Parent = feed,
	})
end

local function refresh()
	local isZero = ClientState.role() == "L"
	inputRow.Visible = isZero and ClientState.isLiving()
	deskButton.Visible = isZero
end

local function send()
	local text = inputBox.Text
	if #text == 0 then
		return
	end
	LScreenRemote:FireServer(string.sub(text, 1, Config.L_SCREEN_MAX_LENGTH * 4))
	inputBox.Text = ""
end

function MeetingPanel.init()
	panel = Widgets.panel({
		Name = "Meeting",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0.3, 0, 0.6, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(390, 360), Vector2.new(260, 0))
	Widgets.label({
		Text = Terms.f("{MEETING}"),
		Font = Theme.fonts.black,
		TextSize = Theme.text.bodyLarge,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 22),
		Parent = panel,
	})
	Widgets.label({
		Text = "Free chat is open. Messages with a living player's full real name are blocked.",
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -32, 0, 30),
		Parent = panel,
	})
	local buttons = Widgets.frame({
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 0, 32),
		Parent = panel,
	})
	Widgets.list(buttons, Theme.space.sm, true)
	Widgets.button({
		Text = "Evidence",
		TextSize = Theme.text.small,
		Variant = "ghost",
		Size = UDim2.fromOffset(110, 32),
		LayoutOrder = 1,
		Parent = buttons,
	}, function()
		Router.toggle("evidence")
	end)
	deskButton = Widgets.button({
		Text = Terms.f("{ZeroDesk}"),
		TextSize = Theme.text.small,
		Variant = "team",
		Size = UDim2.fromOffset(120, 32),
		LayoutOrder = 2,
		Visible = false,
		Parent = buttons,
	}, function()
		Router.toggle("zeroDesk")
	end)
	Widgets.header({
		Text = Terms.f("{ZERO_SCREEN}"),
		TextColor3 = Theme.colors.gold,
		Position = UDim2.fromOffset(16, 110),
		Size = UDim2.new(1, -32, 0, 16),
		Parent = panel,
	})
	feed = Widgets.scroll({
		Position = UDim2.fromOffset(16, 130),
		Size = UDim2.new(1, -32, 1, -190),
		Parent = panel,
	})
	Widgets.list(feed, 6)
	inputRow = Widgets.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(1, -32, 0, 44),
		Visible = false,
		Parent = panel,
	})
	inputBox = Widgets.textbox({
		PlaceholderText = Terms.f("Speak as {zero} (anonymous)"),
		TextSize = Theme.text.body,
		Size = UDim2.new(1, -78, 1, 0),
		Parent = inputRow,
	})
	Widgets.button({
		Text = "Send",
		Variant = "team",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 70, 1, 0),
		Parent = inputRow,
	}, send)
	inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)

	Net.event("LScreenMsg").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			addMessage(payload.text, payload.clock)
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.public.active then
			Widgets.clear(feed)
			messageCount = 0
		end
	end)
	ClientState.PrivateChanged:Connect(refresh)
	local function inMeeting(view): boolean
		return view.participant and (view.phase == "Meeting" or view.phase == "Vote")
	end
	Router.register("meeting", {
		layer = "panel",
		window = panel,
		auto = inMeeting,
		allowed = inMeeting,
		show = function()
			refresh()
			panel.Visible = true
		end,
		hide = function()
			panel.Visible = false
		end,
	})
end

return MeetingPanel
