-- The public evidence board: every finished case file as a parchment slip pinned to the board,
-- newest first, with the round, time, alias, station and the clue in typewriter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Toasts = require(script.Parent.Toasts)

local C = Kit.color
local T = Kit.Tokens

local EvidencePanel = {}

local list: ScrollingFrame
local emptyLabel: TextLabel
local entries = {}

local function addSlip(entry)
	local id = tonumber(entry.id) or 0
	local slip = Kit.card({
		Name = "Slip",
		tone = "parchment",
		padding = T.space.m,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -id,
		Parent = list,
	})
	-- A red pin at the top of every slip.
	local pin = Kit.Base.make("Frame", {
		Name = "Pin",
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -T.space.m + 2),
		Size = UDim2.fromOffset(10, 10),
		ZIndex = 3,
		Parent = slip,
	})
	Kit.Base.round(pin)
	local text = Kit.frame({
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = slip,
	})
	Kit.list(text, T.space.xxs)
	Kit.label({
		Text = string.format(
			"ROUND %s  ·  %s  ·  %s  @  %s",
			tostring(entry.round),
			tostring(entry.clock),
			tostring(entry.alias),
			tostring(entry.station)
		),
		font = "label",
		size = "micro",
		color = C.dim,
		LayoutOrder = 1,
		Parent = text,
	})
	Kit.label({
		Text = tostring(entry.clue),
		font = "document",
		size = "lead",
		color = C.bone,
		LayoutOrder = 2,
		Parent = text,
	})
	emptyLabel.Visible = false
end

local function rebuild()
	Kit.clear(list)
	emptyLabel = Kit.label({
		Text = "No evidence yet. Finished case files appear here.",
		font = "bodyItalic",
		color = C.dim,
		LayoutOrder = 1000000,
		Parent = list,
	})
	for _, entry in ipairs(entries) do
		addSlip(entry)
	end
end

local function refreshFromServer()
	local ok, result = pcall(function()
		return Net.func("GetEvidence"):InvokeServer()
	end)
	if ok and type(result) == "table" then
		entries = result
		if Router.isOpen("evidence") then
			rebuild()
		end
	end
end

function EvidencePanel.init()
	local win = Kit.window({ name = "evidence", title = "Evidence board", jp = "証拠", size = "M" })
	list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.l)
	Kit.pad(list, T.space.s, T.space.xs)
	emptyLabel = Kit.label({ Parent = list })

	Net.event("Evidence").OnClientEvent:Connect(function(entry)
		if type(entry) ~= "table" then
			return
		end
		table.insert(entries, entry)
		if Router.isOpen("evidence") then
			addSlip(entry)
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
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return view.participant
		end,
		show = function()
			rebuild()
			task.spawn(refreshFromServer)
		end,
	})
end

return EvidencePanel
