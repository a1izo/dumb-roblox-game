-- Meeting panel: the anonymous L screen feed, and L's input for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local EvidencePanel = require(script.Parent.EvidencePanel)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local LScreenRemote = Net.event("LScreen")

local MeetingPanel = {}

local panel: Frame
local feed: ScrollingFrame
local inputRow: Frame
local inputBox: TextBox
local messageCount = 0

local function addMessage(text: string, clock: string?)
	messageCount += 1
	Widgets.label({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		Font = Theme.fonts.typewriter,
		TextSize = 16,
		Text = string.format("[%s]  %s", clock or "--:--", text),
		LayoutOrder = -messageCount,
		Parent = feed,
	})
end

local function refresh()
	local phase = ClientState.phase()
	local inMeeting = phase == "Meeting" or phase == "Vote"
	panel.Visible = inMeeting and ClientState.isParticipant()
	inputRow.Visible = inMeeting and ClientState.role() == "L" and ClientState.isLiving()
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
		Size = UDim2.new(0.3, 0, 0, 330),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(380, 330), Vector2.new(250, 0))
	Widgets.label({
		Text = Terms.f("{MEETING}"),
		Font = Theme.fonts.black,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 22),
		Parent = panel,
	})
	Widgets.label({
		Text = "Free chat is open. Messages with a living player's full real name are blocked.",
		TextSize = 13,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = panel,
	})
	Widgets.label({
		Text = Terms.f("{ZERO_SCREEN}"),
		Font = Theme.fonts.bold,
		TextSize = 13,
		TextColor3 = Theme.colors.gold,
		Position = UDim2.fromOffset(12, 72),
		Size = UDim2.new(0.5, 0, 0, 18),
		Parent = panel,
	})
	Widgets.button({
		Text = "Evidence [B]",
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 68),
		Size = UDim2.fromOffset(110, 26),
		Parent = panel,
	}, EvidencePanel.toggle)
	feed = Widgets.scroll({
		Position = UDim2.fromOffset(12, 98),
		Size = UDim2.new(1, -24, 1, -160),
		Parent = panel,
	})
	Widgets.list(feed, 6)
	inputRow = Widgets.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 44),
		Visible = false,
		Parent = panel,
	})
	inputBox = Widgets.textbox({
		PlaceholderText = Terms.f("Speak as {zero} (anonymous)"),
		TextSize = 15,
		Size = UDim2.new(1, -78, 1, 0),
		Parent = inputRow,
	})
	Widgets.button({
		Text = "Send",
		BackgroundColor3 = Theme.colors.team,
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
		refresh()
	end)
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	refresh()
end

return MeetingPanel
