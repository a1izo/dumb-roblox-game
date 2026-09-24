-- The public evidence board: every completed case file with alias, station, time and clue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local EvidencePanel = {}

local window: Frame
local list: ScrollingFrame
local emptyLabel: TextLabel
local entries = {}

local function addRow(entry)
	local row = Widgets.panel({
		BackgroundColor3 = Theme.colors.panelLight,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -8, 0, 0),
		LayoutOrder = -(tonumber(entry.id) or 0),
		Parent = list,
	})
	Widgets.padding(row, 8, 10)
	Widgets.list(row, 2)
	Widgets.label({
		Font = Theme.fonts.bold,
		TextSize = 14,
		TextColor3 = Theme.colors.gold,
		Text = string.format(
			"R%s  %s   %s  @  %s",
			tostring(entry.round),
			tostring(entry.clock),
			tostring(entry.alias),
			tostring(entry.station)
		),
		LayoutOrder = 1,
		Parent = row,
	})
	Widgets.label({
		Font = Theme.fonts.typewriter,
		TextSize = 16,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = tostring(entry.clue),
		LayoutOrder = 2,
		Parent = row,
	})
	emptyLabel.Visible = false
end

local function rebuild()
	Widgets.clear(list)
	emptyLabel = Widgets.label({
		Text = "No evidence yet. Finished case files appear here.",
		TextColor3 = Theme.colors.muted,
		LayoutOrder = 1000000,
		Parent = list,
	})
	for _, entry in ipairs(entries) do
		addRow(entry)
	end
end

local function refreshFromServer()
	local ok, result = pcall(function()
		return Net.func("GetEvidence"):InvokeServer()
	end)
	if ok and type(result) == "table" then
		entries = result
		if window.Visible then
			rebuild()
		end
	end
end

function EvidencePanel.toggle()
	window.Visible = not window.Visible
	if window.Visible then
		rebuild()
		task.spawn(refreshFromServer)
	end
end

function EvidencePanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Evidence board", Vector2.new(640, 560))
	list = Widgets.scroll({ Parent = body })
	Widgets.list(list, 8)
	emptyLabel = Widgets.label({ Parent = list })

	Net.event("Evidence").OnClientEvent:Connect(function(entry)
		if type(entry) ~= "table" then
			return
		end
		table.insert(entries, entry)
		if window.Visible then
			addRow(entry)
		end
		if ClientState.isParticipant() then
			Toasts.show(
				string.format("New evidence from %s at %s.", tostring(entry.alias), tostring(entry.station)),
				"info"
			)
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if not ClientState.public.active then
			entries = {}
			window.Visible = false
		end
	end)
end

return EvidencePanel
