-- The "what now?" list under the phase ribbon: one to three short lines for your role and
-- the current phase, ticked off as you do them. Built from your own state only (Objectives
-- module). Part of the guide: hidden when the player turns the guide off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Objectives = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Objectives"))

local ClientState = require(script.Parent.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Settings = require(script.Parent.Core.Settings)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors

local ObjectiveTracker = {}

local lastKey = ""

local function render()
	local container = Hud.objectives()
	local guideOn = Settings.get("hints") == true
	local lines = if ClientState.isParticipant() and guideOn
		then Objectives.lines(ClientState.role(), ClientState.phase(), ClientState.private, ClientState.isLiving())
		else {}
	local parts = {}
	for _, entry in ipairs(lines) do
		table.insert(parts, (if entry.done then "1" else "0") .. entry.text)
	end
	local key = table.concat(parts, "|")
	if key == lastKey then
		return
	end
	lastKey = key
	Widgets.clear(container)
	for index, entry in ipairs(lines) do
		local row = Widgets.frame({
			BackgroundTransparency = 0.1,
			BackgroundColor3 = C.ink,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = container,
		})
		Widgets.slant(row, 0.02)
		Widgets.padding(row, Theme.space.xs + 2, Theme.space.lg)
		Widgets.label({
			Text = (if entry.done then "✓  " else "▶  ") .. string.upper(entry.text),
			FontFace = Theme.faces.displayMedium,
			TextSize = Theme.text.small,
			TextColor3 = if entry.done then C.muted else C.paper,
			AutomaticSize = Enum.AutomaticSize.Y,
			RichText = false,
			Parent = row,
		})
	end
end

function ObjectiveTracker.init()
	ClientState.PublicChanged:Connect(render)
	ClientState.PrivateChanged:Connect(render)
	Settings.Changed:Connect(function(key)
		if key == "hints" then
			render()
		end
	end)
	render()
end

return ObjectiveTracker
