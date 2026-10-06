-- The "what now?" list at the top left: one to three short lines for your role and
-- the current phase, struck through (in grey) as you do them. Built from your own state only
-- (Objectives module). Part of the guide: hidden when the player turns the guide off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Objectives = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Objectives"))

local ClientState = require(script.Parent.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Kit = require(script.Parent.Kit)
local Settings = require(script.Parent.Core.Settings)

local C = Kit.color

local ObjectiveTracker = {}

local lastKey = ""

local function line(parent: Instance, entry, index: number)
	local width = parent:IsA("GuiObject") and parent.Size.X.Offset or 320
	local row = Kit.frame({
		Name = "Objective" .. index,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = index,
		Parent = parent,
	})
	-- A square mark: hollow while to do, filled once done.
	local mark = Kit.Base.make("Frame", {
		Name = "Mark",
		BackgroundColor3 = if entry.done then C.g6 else C.g5,
		BackgroundTransparency = if entry.done then 0 else 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(10, 10),
		Parent = row,
	})
	if not entry.done then
		Kit.Base.stroke(mark, C.g5, 1.5, 0)
	end
	local label = Kit.label({
		Text = if entry.done then "<s>" .. entry.text .. "</s>" else entry.text,
		size = "small",
		color = if entry.done then C.faint else C.bone,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(0, math.max(width - 64, 120), 0, 0),
		Parent = row,
	})
	label.RichText = true
end

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
	Kit.clear(container)
	for index, entry in ipairs(lines) do
		line(container, entry, index)
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
	Kit.Layout.Changed:Connect(function()
		lastKey = ""
		render()
	end)
	render()
end

return ObjectiveTracker
