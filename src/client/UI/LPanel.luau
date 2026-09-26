-- Zero's private desk (role id "L"), on white paper, the colour that belongs to Zero alone: the
-- suspicion meter on the left page and the inbox of anonymous tips and reports on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Toasts = require(script.Parent.Toasts)

local C = Kit.color
local T = Kit.Tokens

local LPanel = {}

local meterList: ScrollingFrame
local inbox: ScrollingFrame
local meterNote: TextLabel
local inboxCount = 0
local lastMeter = nil

local function renderMeter()
	Kit.clear(meterList)
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
		local row = Kit.frame({ Name = "Line", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = index, Parent = meterList })
		Kit.label({
			Text = tostring(item.alias),
			font = "bodyBold",
			size = "small",
			color = C.ink,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0.3, 0, 1, 0),
			Parent = row,
		})
		local value = math.clamp(tonumber(item.value) or 0, 0, 100)
		local _, setFill = Kit.meter({
			color = C.candle:Lerp(C.red, value / 100),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.32, 0.5),
			Size = UDim2.new(0.56, 0, 0, 8),
			Parent = row,
		})
		setFill(value / 100)
		Kit.label({
			Text = tostring(math.floor(value)),
			font = "mono",
			size = "small",
			color = C.inkDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
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
		header = string.format("R%s %s  ·  ANONYMOUS TIP", tostring(payload.round), tostring(payload.clock))
	else
		header = string.format(
			"R%s %s  ·  REPORT: suspects %s",
			tostring(payload.round),
			tostring(payload.clock),
			tostring(payload.suspect)
		)
	end
	local slip = Kit.card({
		Name = if isTip then "Tip" else "Report",
		tone = "parchment",
		padding = T.space.s,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -inboxCount,
		Parent = inbox,
	})
	Kit.list(slip, T.space.xxs)
	Kit.label({
		Text = header,
		font = "label",
		size = "micro",
		color = if isTip then C.blood else C.steel:Lerp(C.ink, 0.35),
		LayoutOrder = 1,
		Parent = slip,
	})
	local text = tostring(payload.text or "")
	if #text > 0 then
		Kit.label({ Text = text, font = "document", color = C.ink, LayoutOrder = 2, Parent = slip })
	end
end

function LPanel.toggle()
	Router.toggle("zeroDesk")
end

function LPanel.init()
	local win = Kit.window({ name = "zeroDesk", title = Terms.f("{ZeroDesk}"), tone = "white", size = "L" })
	local body = win.body
	local left = Kit.frame({ Name = "Meter", Size = UDim2.new(0.5, -T.space.l, 1, 0), Parent = body })
	Kit.heading({ text = "Suspicion meter", ink = C.ink, Parent = left })
	meterNote = Kit.label({
		size = "micro",
		color = C.inkDim,
		Position = UDim2.fromOffset(0, 52),
		Parent = left,
	})
	meterList = Kit.scroll({
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 1, -90),
		ScrollBarImageColor3 = C.inkDim,
		Parent = left,
	})
	Kit.list(meterList, T.space.xs)

	local right = Kit.frame({
		Name = "Inbox",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -T.space.l, 1, 0),
		Parent = body,
	})
	Kit.heading({ text = "Inbox", detail = "tips and reports", ink = C.ink, Parent = right })
	inbox = Kit.scroll({
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		ScrollBarImageColor3 = C.inkDim,
		Parent = right,
	})
	Kit.list(inbox, T.space.s)
	Kit.pad(inbox, T.space.xs, T.space.xs)

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
			Kit.clear(inbox)
			inboxCount = 0
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return view.participant and view.role == "L"
		end,
		show = function()
			renderMeter()
		end,
	})
end

return LPanel
