-- Zero's private desk (role id "L"): the suspicion meter and the inbox of anonymous tips
-- and reports.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local LPanel = {}

local window: Frame
local meterList: ScrollingFrame
local inbox: ScrollingFrame
local meterNote: TextLabel
local inboxCount = 0
local lastMeter = nil

local function renderMeter()
	Widgets.clear(meterList)
	local payload = lastMeter
	if not payload then
		meterNote.Text = "Suspicion rises with reports, fake tasks that were seen, burned notes nearby and idle rounds."
		return
	end
	if not payload.enabled then
		meterNote.Text = Terms.f("{Butler} is dead. You lost the suspicion meter.")
		return
	end
	meterNote.Text = Terms.f("A hint, not proof. {Cultists} can push it with false reports.")
	local values = table.clone(payload.values or {})
	table.sort(values, function(a, b)
		return a.value > b.value
	end)
	for index, item in ipairs(values) do
		local row = Widgets.frame({
			Size = UDim2.new(1, -8, 0, 26),
			LayoutOrder = index,
			Parent = meterList,
		})
		Widgets.label({
			Text = tostring(item.alias),
			Font = Theme.fonts.bold,
			TextSize = 14,
			Size = UDim2.new(0.3, 0, 1, 0),
			Parent = row,
		})
		local bar = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.panelLight,
			Position = UDim2.new(0.32, 0, 0.2, 0),
			Size = UDim2.new(0.56, 0, 0.6, 0),
			Parent = row,
		})
		Widgets.corner(bar, 4)
		local value = math.clamp(tonumber(item.value) or 0, 0, 100)
		local fill = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.colors.accent:Lerp(Theme.colors.gold, 1 - value / 100),
			Size = UDim2.fromScale(value / 100, 1),
			Parent = bar,
		})
		Widgets.corner(fill, 4)
		Widgets.label({
			Text = tostring(math.floor(value)),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.9, 0, 0, 0),
			Size = UDim2.new(0.1, 0, 1, 0),
			Parent = row,
		})
	end
end

local function addInbox(payload)
	inboxCount += 1
	local isTip = payload.kind == "tip"
	local header
	if isTip then
		header = string.format("R%s %s  ANONYMOUS TIP", tostring(payload.round), tostring(payload.clock))
	else
		header = string.format(
			"R%s %s  REPORT: suspects %s",
			tostring(payload.round),
			tostring(payload.clock),
			tostring(payload.suspect)
		)
	end
	local row = Widgets.panel({
		BackgroundColor3 = if isTip then Theme.colors.paper else Theme.colors.panelLight,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = -inboxCount,
		Parent = inbox,
	})
	Widgets.padding(row, 8, 10)
	Widgets.list(row, 2)
	Widgets.label({
		Text = header,
		Font = Theme.fonts.bold,
		TextSize = Theme.text.caption,
		TextColor3 = if isTip then Theme.colors.accent else Theme.colors.team,
		LayoutOrder = 1,
		Parent = row,
	})
	local text = tostring(payload.text or "")
	if #text > 0 then
		Widgets.label({
			Text = text,
			Font = Theme.fonts.typewriter,
			TextSize = Theme.text.body,
			TextColor3 = if isTip then Theme.colors.ink else Theme.colors.text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = row,
		})
	end
end

function LPanel.toggle()
	Router.toggle("zeroDesk")
end

function LPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, Terms.f("{ZeroDesk}"), Vector2.new(720, 520), function()
		Router.close("zeroDesk", "user")
	end)
	local left = Widgets.frame({ Size = UDim2.new(0.5, -8, 1, 0), Parent = body })
	Widgets.header({ Text = "Suspicion meter", Parent = left })
	meterNote = Widgets.label({
		TextSize = 12,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = left,
	})
	meterList = Widgets.scroll({ Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), Parent = left })
	Widgets.list(meterList, 4)

	local right = Widgets.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -8, 1, 0),
		Parent = body,
	})
	Widgets.header({ Text = "Inbox: tips and reports", Parent = right })
	inbox = Widgets.scroll({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), Parent = right })
	Widgets.list(inbox, 6)

	Net.event("Suspicion").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		lastMeter = payload
		if Router.isOpen("zeroDesk") then
			renderMeter()
		end
	end)
	Net.event("LInbox").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		addInbox(payload)
		if payload.kind == "tip" then
			Toasts.show("A new anonymous tip is in the box. Press Z to read it.", "secret")
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.public.active then
			lastMeter = nil
			Widgets.clear(inbox)
			inboxCount = 0
		end
	end)
	Router.register("zeroDesk", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return view.participant and view.role == "L"
		end,
		show = function()
			window.Visible = true
			renderMeter()
		end,
		hide = function()
			window.Visible = false
		end,
	})
end

return LPanel
