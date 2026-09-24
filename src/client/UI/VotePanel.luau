-- The vote: remove one living player or skip. L can also issue the warrant here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local VoteRemote = Net.event("Vote")
local WarrantRemote = Net.event("Warrant")
local LocalPlayer = Players.LocalPlayer

local VotePanel = {}

local panel: Frame
local grid: Frame
local statusLabel: TextLabel
local warrantFrame: Frame
local suspectButton: TextButton
local warrantBox: TextBox
local warrantButton: TextButton
local warrantStatus: TextLabel

local myVote: any = nil
local voted: { [number]: boolean } = {}
local warrantSuspect: number? = nil

local function rebuild()
	Widgets.clear(grid)
	local living = ClientState.isLiving()
	local order = 0
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			order += 1
			local chosen = myVote == entry.userId
			Widgets.button({
				Text = (if voted[entry.userId] then "[x] " else "") .. entry.alias,
				BackgroundColor3 = if chosen then Theme.colors.accent else Theme.colors.button,
				AutoButtonColor = living,
				LayoutOrder = order,
				Parent = grid,
			}, function()
				if living then
					myVote = entry.userId
					VoteRemote:FireServer(entry.userId)
					rebuild()
				end
			end)
		end
	end
	Widgets.button({
		Text = "SKIP",
		BackgroundColor3 = if myVote == "skip" then Theme.colors.accent else Theme.colors.panelLight,
		AutoButtonColor = living,
		LayoutOrder = order + 1,
		Parent = grid,
	}, function()
		if living then
			myVote = "skip"
			VoteRemote:FireServer("skip")
			rebuild()
		end
	end)
	local count = 0
	for _ in pairs(voted) do
		count += 1
	end
	if living then
		statusLabel.Text = string.format("%d voted. You can change your vote until the time runs out. [x] = has voted", count)
	else
		statusLabel.Text = string.format("%d voted. Only living players can vote.", count)
	end
end

local function refreshWarrant()
	local private = ClientState.private
	local show = ClientState.role() == "L" and ClientState.isLiving() and not private.warrantUsed
	warrantFrame.Visible = show
	if not show then
		return
	end
	if private.warrantBlocked then
		warrantStatus.Text = "Rejected this round. Try again next round."
		warrantButton.Visible = false
	else
		warrantStatus.Text = "One arrest per match. A wrong name blocks you until next round."
		warrantButton.Visible = true
	end
	local alias = if warrantSuspect then ClientState.aliasOf(warrantSuspect) else nil
	suspectButton.Text = "Suspect: " .. (alias or "tap to choose")
end

local function cycleSuspect()
	local options = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(options, entry.userId)
		end
	end
	if #options == 0 then
		return
	end
	local index = if warrantSuspect then table.find(options, warrantSuspect) else nil
	warrantSuspect = options[((index or 0) % #options) + 1]
	refreshWarrant()
end

local function open()
	myVote = nil
	voted = {}
	warrantSuspect = nil
	warrantBox.Text = ""
	panel.Visible = true
	rebuild()
	refreshWarrant()
end

function VotePanel.init()
	panel = Widgets.panel({
		Name = "Vote",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 440),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(420, 440), Vector2.new(270, 0))
	Widgets.label({
		Text = "VOTE",
		Font = Theme.fonts.black,
		TextSize = 22,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = panel,
	})
	statusLabel = Widgets.label({
		TextSize = 13,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 34),
		Parent = panel,
	})
	grid = Widgets.frame({
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 170),
		Parent = panel,
	})
	-- Up to 11 other players plus Skip: three columns keep it inside the panel.
	Widgets.grid(grid, UDim2.new(0.333, -4, 0, 30), 6)

	warrantFrame = Widgets.panel({
		BackgroundColor3 = Color3.fromRGB(26, 30, 44),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 176),
		Visible = false,
		Parent = panel,
	})
	Widgets.padding(warrantFrame, 10)
	Widgets.list(warrantFrame, 6)
	Widgets.label({
		Text = "L'S WARRANT",
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.team,
		LayoutOrder = 1,
		Parent = warrantFrame,
	})
	suspectButton = Widgets.button({
		Text = "Suspect: tap to choose",
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
		Parent = warrantFrame,
	}, cycleSuspect)
	warrantBox = Widgets.textbox({
		PlaceholderText = "Suspect's full real name",
		Font = Theme.fonts.typewriter,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 3,
		Parent = warrantFrame,
	})
	warrantButton = Widgets.button({
		Text = "ISSUE WARRANT",
		Font = Theme.fonts.black,
		BackgroundColor3 = Theme.colors.team,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 4,
		Parent = warrantFrame,
	}, function()
		if not warrantSuspect then
			Toasts.show("Choose a suspect first.", "bad")
			return
		end
		if #warrantBox.Text == 0 then
			Toasts.show("Type the suspect's full real name.", "bad")
			return
		end
		WarrantRemote:FireServer({
			suspect = warrantSuspect,
			name = string.sub(warrantBox.Text, 1, Config.NAME_MAX_LENGTH * 4),
		})
	end)
	warrantStatus = Widgets.label({
		TextSize = 12,
		TextColor3 = Theme.colors.muted,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 5,
		Parent = warrantFrame,
	})

	Net.event("VoteUpdate").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.voted) ~= "table" then
			return
		end
		voted = {}
		for _, userId in ipairs(payload.voted) do
			voted[userId] = true
		end
		if panel.Visible then
			rebuild()
		end
	end)
	Net.event("VoteResult").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.counts) ~= "table" then
			return
		end
		local parts = {}
		for _, item in ipairs(payload.counts) do
			table.insert(parts, string.format("%s %d", tostring(item.name), tonumber(item.count) or 0))
		end
		if #parts > 0 then
			Toasts.show("Vote results: " .. table.concat(parts, ", "), "info")
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase == "Vote" and ClientState.isParticipant() then
			open()
		else
			panel.Visible = false
		end
	end)
	ClientState.PublicChanged:Connect(function()
		if panel.Visible then
			rebuild()
			refreshWarrant()
		end
	end)
	ClientState.PrivateChanged:Connect(function()
		if panel.Visible then
			refreshWarrant()
		end
	end)
end

return VotePanel
