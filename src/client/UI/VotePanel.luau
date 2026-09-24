-- The vote: remove one living player or skip, changeable until time runs out. Zero also
-- gets a button to the warrant window here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local VoteRemote = Net.event("Vote")
local WarrantRemote = Net.event("Warrant")
local LocalPlayer = Players.LocalPlayer

local VotePanel = {}

local panel: Frame
local grid: ScrollingFrame
local statusLabel: TextLabel
local warrantButton: TextButton
local firstButton: TextButton? = nil

local warrantWindow: Frame
local renderWarrantSuspects: (any, any?) -> ()
local warrantBox: TextBox
local warrantStatus: TextLabel
local serveButton: TextButton

local myVote: any = nil
local voted: { [number]: boolean } = {}
local warrantSuspect: number? = nil

-- Vote -------------------------------------------------------------------------------------

local function rebuild()
	Widgets.clear(grid)
	firstButton = nil
	local living = ClientState.isLiving()
	local order = 0
	local function add(text: string, choice: any, variant: string)
		order += 1
		local button = Widgets.button({
			Text = text,
			TextSize = Theme.text.body,
			Variant = if myVote == choice then "primary" else variant,
			LayoutOrder = order,
			Parent = grid,
		}, function()
			if living then
				myVote = choice
				VoteRemote:FireServer(choice)
				rebuild()
			end
		end)
		Widgets.setEnabled(button, living)
		if myVote == choice then
			Widgets.stroke(button, Theme.colors.focus, 2, 0)
		end
		firstButton = firstButton or button
	end
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			add((if voted[entry.userId] then "✓ " else "") .. entry.alias, entry.userId, "secondary")
		end
	end
	add("SKIP", "skip", "ghost")

	local count = 0
	for _ in pairs(voted) do
		count += 1
	end
	statusLabel.Text = if living
		then string.format("%d voted  ·  ✓ = has voted  ·  you can change your vote", count)
		else string.format("%d voted  ·  only living players vote", count)
	local private = ClientState.private
	warrantButton.Visible = ClientState.role() == "L" and living and not private.warrantUsed
	if warrantButton.Visible then
		warrantButton.Text = if private.warrantBlocked then "WARRANT BLOCKED THIS ROUND" else "SERVE A WARRANT"
		Widgets.setEnabled(warrantButton, not private.warrantBlocked)
	end
end

-- Warrant ----------------------------------------------------------------------------------

local function refreshWarrant()
	local options = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(options, { id = entry.userId, text = entry.alias })
		end
	end
	renderWarrantSuspects(options, warrantSuspect)
	local blocked = ClientState.private.warrantBlocked == true
	serveButton.Visible = not blocked
	warrantStatus.Text = if blocked
		then "Rejected this round. You can try again next round."
		else "One arrest per match. A wrong name blocks you until next round. Arresting an innocent player loses the match."
end

local function buildWarrant()
	local body
	warrantWindow, body = Widgets.modal(Screens.modal, Terms.f("{ZERO}'S WARRANT"), Vector2.new(520, 500), function()
		Router.close("warrant", "user")
	end)
	warrantStatus = Widgets.label({
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	local suspects = Widgets.scroll({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -170),
		Parent = body,
	})
	renderWarrantSuspects = Widgets.pickGrid(suspects, UDim2.new(1 / 3, -6, 0, 38), function(id)
		warrantSuspect = id
		refreshWarrant()
	end)
	warrantBox = Widgets.textbox({
		PlaceholderText = "The suspect's full real name",
		Font = Theme.fonts.typewriter,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -62),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = body,
	})
	Widgets.limitLength(warrantBox, Config.NAME_MAX_LENGTH)
	serveButton = Widgets.holdButton(
		{
			Text = "HOLD TO SERVE THE WARRANT",
			Font = Theme.fonts.black,
			Variant = "team",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = body,
		},
		1.5,
		function()
			if not warrantSuspect then
				Toasts.show("Choose a suspect first.", "bad")
				return
			end
			if #warrantBox.Text == 0 then
				Toasts.show("Type the suspect's full real name.", "bad")
				return
			end
			WarrantRemote:FireServer({ suspect = warrantSuspect, name = warrantBox.Text })
			Router.close("warrant", "user")
		end
	)
end

-- Setup ------------------------------------------------------------------------------------

function VotePanel.init()
	panel = Widgets.panel({
		Name = "Vote",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 20),
		Size = UDim2.new(0.34, 0, 0.66, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	Widgets.sizeLimit(panel, Vector2.new(420, 470), Vector2.new(280, 0))
	Widgets.label({
		Text = "VOTE",
		Font = Theme.fonts.black,
		TextSize = Theme.text.heading,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -110, 0, 30),
		Parent = panel,
	})
	local timer = Widgets.label({
		Font = Theme.fonts.mono,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(90, 30),
		Parent = panel,
	})
	Clock.bind(timer)
	statusLabel = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 30),
		Parent = panel,
	})
	grid = Widgets.scroll({
		Position = UDim2.fromOffset(16, 80),
		Size = UDim2.new(1, -32, 1, -148),
		Parent = panel,
	})
	Widgets.padding(grid, 2)
	Widgets.grid(grid, UDim2.new(0.5, -5, 0, 40), Theme.space.sm)
	warrantButton = Widgets.button({
		Text = "SERVE A WARRANT",
		Font = Theme.fonts.black,
		Variant = "team",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -14),
		Size = UDim2.new(1, -32, 0, 44),
		Visible = false,
		Parent = panel,
	}, function()
		Router.open("warrant")
	end)
	buildWarrant()

	Net.event("VoteUpdate").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.voted) ~= "table" then
			return
		end
		voted = {}
		for _, userId in ipairs(payload.voted) do
			voted[userId] = true
		end
		if Router.isOpen("vote") then
			rebuild()
		end
	end)
	Net.event("VoteResult").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.counts) ~= "table" then
			return
		end
		-- Players in the match watch the tally in the verdict cutscene instead.
		if ClientState.isParticipant() and not Config.STUDIO_SKIP_PRESENTATION then
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
	ClientState.PublicChanged:Connect(function()
		if Router.isOpen("vote") then
			rebuild()
		end
		if Router.isOpen("warrant") then
			refreshWarrant()
		end
	end)
	ClientState.PrivateChanged:Connect(function()
		if Router.isOpen("vote") then
			rebuild()
		end
		if Router.isOpen("warrant") then
			refreshWarrant()
		end
	end)

	local function inVote(view): boolean
		return view.participant and view.phase == "Vote"
	end
	Router.register("vote", {
		layer = "panel",
		window = panel,
		auto = inVote,
		allowed = inVote,
		show = function()
			myVote = nil
			voted = {}
			panel.Visible = true
			rebuild()
		end,
		hide = function()
			panel.Visible = false
		end,
		firstSelection = function()
			return firstButton
		end,
	})
	Router.register("warrant", {
		layer = "modal",
		window = warrantWindow,
		allowed = function(view)
			return view.living and view.phase == "Vote" and view.role == "L" and not view.private.warrantUsed
		end,
		show = function()
			warrantWindow.Visible = true
			refreshWarrant()
		end,
		hide = function(reason)
			warrantWindow.Visible = false
			if reason == "rule" then
				warrantSuspect = nil
				warrantBox.Text = ""
			end
		end,
	})
end

return VotePanel
