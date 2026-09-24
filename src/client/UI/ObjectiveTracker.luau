-- The "what now?" list in the HUD: one to three short lines for your role and the current
-- phase, ticked off as you do them. Built from your own state only (Objectives module).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Objectives = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Objectives"))

local ClientState = require(script.Parent.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Motion = require(script.Parent.Core.Motion)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ObjectiveTracker = {}

local lastKey = ""

local function render()
	local container = Hud.objectives()
	local view = ClientState.private
	local lines = if ClientState.isParticipant()
		then Objectives.lines(ClientState.role(), ClientState.phase(), view, ClientState.isLiving())
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
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Theme.colors.backdrop,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = container,
		})
		Widgets.corner(row, Theme.radius.md)
		Widgets.padding(row, Theme.space.xs + 2, Theme.space.sm + 2)
		Widgets.label({
			Text = (if entry.done then "✓  " else "›  ") .. entry.text,
			Font = if entry.done then Theme.fonts.body else Theme.fonts.medium,
			TextSize = Theme.text.small,
			TextColor3 = if entry.done then Theme.colors.good else Theme.colors.text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = row,
		})
		if index == 1 then
			Motion.slideIn(row, Vector2.new(-10, 0), 0.25)
		end
	end
end

function ObjectiveTracker.init()
	ClientState.PublicChanged:Connect(render)
	ClientState.PrivateChanged:Connect(render)
	render()
end

return ObjectiveTracker
