-- The "what now?" list at the top left: one to three short handwritten lines for your role and
-- the current phase, struck through in red as you do them. Built from your own state only
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
	Kit.icon({
		name = if entry.done then "check" else "quill",
		size = 18,
		color = if entry.done then C.red else C.dim,
		Position = UDim2.fromOffset(0, 6),
		Parent = row,
	})
	local text = Kit.text({
		face = "Scrawl",
		text = entry.text,
		size = 27,
		seed = index,
		maxWidth = width - 30,
		color = if entry.done then C.dim else C.bone,
		Position = UDim2.fromOffset(26, 0),
		Parent = row,
	})
	if entry.done then
		-- Struck through in red.
		local strike = Kit.Base.make("Frame", {
			Name = "Strike",
			BackgroundColor3 = C.red,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Rotation = -1.5,
			Position = UDim2.fromOffset(22, 14),
			Size = UDim2.fromOffset(text.width + 8, 2),
			ZIndex = 3,
			Parent = row,
		})
		text.Changed:Connect(function()
			strike.Size = UDim2.fromOffset(text.width + 8, 2)
		end)
	end
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
