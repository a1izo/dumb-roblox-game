-- The vote: remove one living player or skip, changeable until time runs out. The names are
-- written on ruled lines; yours is checked in red, and "voted" follows everyone who has
-- voted. Zero also gets a button to the warrant window here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Glitch = require(script.Parent.Core.Glitch)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Toasts = require(script.Parent.Toasts)

local VoteRemote = Net.event("Vote")
local WarrantRemote = Net.event("Warrant")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local VotePanel = {}

local panel: Frame
local voteGlitch: any
local renderChoices: (any, any?, boolean?) -> { any }
local statusLabel: TextLabel
local warrantButton: TextButton
local firstButton: GuiObject? = nil

local renderWarrantSuspects: (any, any?, boolean?) -> { any }
local warrantBox: TextBox
local warrantStatus: TextLabel
local serveButton: TextButton

local myVote: any = nil
local voted: { [number]: boolean } = {}
local warrantSuspect: number? = nil

-- Vote -------------------------------------------------------------------------------------

local function rebuild()
	local living = ClientState.isLiving()
	local options = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(options, {
				id = entry.userId,
				text = entry.alias,
				sub = if voted[entry.userId] then "voted" else nil,
			})
		end
	end
	table.insert(options, { id = "skip", text = "Skip" })
	local lines = renderChoices(options, myVote, living)
	firstButton = if lines[1] then lines[1].button else nil

	local count = 0
	for _ in pairs(voted) do
		count += 1
	end
	statusLabel.Text = if living
		then string.format("%d voted  ·  you can change your vote until time runs out", count)
		else string.format("%d voted  ·  only living players vote", count)
	local private = ClientState.private
	warrantButton.Visible = ClientState.role() == "L" and living and not private.warrantUsed
	if warrantButton.Visible then
		Kit.setText(warrantButton, if private.warrantBlocked then "Warrant blocked this round" else "Serve a warrant")
		Kit.setEnabled(warrantButton, not private.warrantBlocked)
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
	local win = Kit.window({ name = "warrant", title = Terms.f("{Zero}'s warrant"), size = "M" })
	local body = win.body
	warrantStatus = Kit.label({ size = "small", color = C.dim, Parent = body })
	local suspects = Kit.scroll({
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -(52 + 130)),
		Parent = body,
	})
	renderWarrantSuspects = Kit.pickGrid(suspects, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		warrantSuspect = id
		refreshWarrant()
	end)
	local _, box = Kit.field({
		placeholder = "The suspect's full real name",
		font = "document",
		maxLength = Config.NAME_MAX_LENGTH,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -70),
		Size = UDim2.new(1, 0, 0, T.touch + 4),
		Parent = body,
	})
	warrantBox = box
	serveButton = Kit.hold(
		{
			text = "Hold to serve the warrant",
			icon = "cuffs",
			variant = "primary",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 56),
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
	Kit.register(win, {
		allowed = function(view)
			return view.living and view.phase == "Vote" and view.role == "L" and not view.private.warrantUsed
		end,
		show = function()
			refreshWarrant()
		end,
		hide = function(reason)
			if reason == "rule" then
				warrantSuspect = nil
				warrantBox.Text = ""
			end
		end,
	})
end

-- Setup ------------------------------------------------------------------------------------

function VotePanel.init()
	local page, content = Kit.page({
		Name = "Vote",
		tone = "black",
		padding = T.space.l,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, T.space.l, 0.5, 20),
		Size = UDim2.new(0.34, 0, 0.66, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	Kit.Base.make("UISizeConstraint", {
		MaxSize = Vector2.new(440, 480),
		MinSize = Vector2.new(300, 320),
		Parent = panel,
	})
	-- The loud header: the title and its Japanese accent glitch every couple of seconds.
	local header = Kit.Base.make("CanvasGroup", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.7, 0, 0, 44),
		Parent = content,
	}) :: any
	Kit.text({ face = "Head", text = "The vote", size = T.size.heading, color = C.bone, Parent = header })
	Kit.label({
		Text = "投票",
		font = "label",
		size = "small",
		color = C.g5,
		TextWrapped = false,
		Position = UDim2.fromOffset(176, 18),
		Parent = header,
	})
	voteGlitch = Glitch.attach(header, { loop = true, enter = false })
	-- The clock, in equal-width digits; red in the last ten seconds.
	local timer = Kit.num({
		text = "",
		size = 30,
		color = C.bone,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Parent = content,
	})
	Clock.bind(timer, function(seconds: number): string
		timer:setColor(if seconds <= 10 then C.danger else C.bone)
		return Clock.format(seconds)
	end)
	statusLabel = Kit.label({
		size = "micro",
		color = C.dim,
		Position = UDim2.fromOffset(0, 46),
		Parent = content,
	})
	local grid = Kit.scroll({
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -(76 + 60)),
		Parent = content,
	})
	renderChoices = Kit.pickGrid(grid, UDim2.new(0.5, -T.space.s, 0, 48), function(choice)
		if ClientState.isLiving() then
			myVote = choice
			VoteRemote:FireServer(choice)
			rebuild()
		end
	end)
	warrantButton = Kit.button({
		text = "Serve a warrant",
		icon = "cuffs",
		variant = "secondary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		Parent = content,
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
	local function refreshOpen()
		if Router.isOpen("vote") then
			rebuild()
		end
		if Router.isOpen("warrant") then
			refreshWarrant()
		end
	end
	ClientState.PublicChanged:Connect(refreshOpen)
	ClientState.PrivateChanged:Connect(refreshOpen)

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
			voteGlitch:enter()
			rebuild()
		end,
		hide = function()
			panel.Visible = false
		end,
		firstSelection = function()
			return firstButton
		end,
	})
end

return VotePanel
