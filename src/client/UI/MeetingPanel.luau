-- Meeting panel: the feed of Zero's anonymous screen, and Zero's input for it. Opens for
-- every participant during the meeting and the vote, as a page in the lower right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local LScreenRemote = Net.event("LScreen")

local C = Kit.color
local T = Kit.Tokens

local MeetingPanel = {}

local panel: Frame
local feed: ScrollingFrame
local inputRow: Frame
local inputBox: TextBox
local deskButton: TextButton
local messageCount = 0

local function addMessage(text: string, clock: string?)
	messageCount += 1
	Kit.label({
		Text = string.format("[%s]  %s", clock or "--:--", text),
		font = "document",
		color = C.white,
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
	local page, content = Kit.page({
		Name = "Meeting",
		tone = "raised",
		padding = T.space.l,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -T.space.l, 1, -T.space.l),
		Size = UDim2.new(0.3, 0, 0.62, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	Kit.Base.make("UISizeConstraint", {
		MaxSize = Vector2.new(400, 380),
		MinSize = Vector2.new(280, 300),
		Parent = panel,
	})
	Kit.text({ face = "Gothic", text = Terms.f("{Meeting}"), size = T.size.title, color = C.bone, Parent = content })
	Kit.label({
		Text = "Free chat is open. Messages with a living player's full real name are blocked.",
		size = "micro",
		color = C.dim,
		Position = UDim2.fromOffset(0, 36),
		Parent = content,
	})
	local buttons = Kit.frame({
		Name = "Buttons",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = content,
	})
	Kit.list(buttons, T.space.s, true)
	Kit.button(
		{ text = "Evidence", icon = "evidence", variant = "secondary", size = "s", LayoutOrder = 1, Parent = buttons },
		function()
			Router.toggle("evidence")
		end
	)
	deskButton = Kit.button({
		text = Terms.f("{ZeroDesk}"),
		icon = "zero",
		variant = "secondary",
		size = "s",
		LayoutOrder = 2,
		Visible = false,
		Parent = buttons,
	}, function()
		Router.toggle("zeroDesk")
	end)
	-- Zero's screen: white type on black, like the screen in the meeting room.
	local screen = Kit.card({
		Name = "ZeroScreen",
		tone = "page",
		padding = T.space.s,
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 1, -124),
		Parent = content,
	})
	Kit.label({
		Text = string.upper(Terms.f("{ZERO_SCREEN}")),
		font = "label",
		size = "micro",
		color = C.white,
		Parent = screen,
	})
	feed = Kit.scroll({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 1, -20), Parent = screen })
	Kit.list(feed, T.space.xs)
	inputRow = Kit.frame({
		Name = "Input",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		ZIndex = 2,
		Parent = content,
	})
	local field
	field, inputBox = Kit.field({
		placeholder = Terms.f("Speak as {zero} (anonymous)"),
		size = "body",
		Size = UDim2.new(1, -96, 1, 0),
		ZIndex = 2,
		Parent = inputRow,
	})
	local _ = field
	Kit.button({
		text = "Send",
		variant = "primary",
		size = "s",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(88, 40),
		ZIndex = 2,
		Parent = inputRow,
	}, send)
	inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			send()
		end
	end)
	-- While Zero can type, the feed makes room for the input.
	inputRow:GetPropertyChangedSignal("Visible"):Connect(function()
		screen.Size = UDim2.new(1, 0, 1, if inputRow.Visible then -(124 + T.touch + T.space.s) else -124)
	end)

	Net.event("LScreenMsg").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			addMessage(payload.text, payload.clock)
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.public.active then
			Kit.clear(feed)
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
