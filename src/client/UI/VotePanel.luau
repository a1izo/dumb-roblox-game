-- The vote: remove one living player or skip, changeable until time runs out. The names are
-- written on ruled lines; yours is checked in red, and "voted" follows everyone who has
-- voted. Whoever holds Ace's title also gets a button to the arrest window here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local MeetingPanel = require(script.Parent.MeetingPanel)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Toasts = require(script.Parent.Toasts)

local VoteRemote = Net.event("Vote")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local VotePanel = {}

local panel: Frame
local voteGlitch: any
local renderChoices: (any, any?, boolean?) -> { any }
local statusLabel: TextLabel
local arrestButton: TextButton
local firstButton: GuiObject? = nil

local myVote: any = nil
local voted: { [number]: boolean } = {}

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
		then string.format("%d voted. You can change your vote.", count)
		else string.format("%d voted", count)
	local private = ClientState.private
	arrestButton.Visible = private.isAce == true and living and private.arrestUsed ~= true
end

-- Setup ------------------------------------------------------------------------------------

function VotePanel.init()
	local page, content = Kit.page({
		Name = "Vote",
		tone = "black",
		-- (a paper sheet beside the table, so the room stays in view: concept A)
		fillColor = T.paper.g0,
		padding = T.space.l,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, T.space.l, 0.5, 20),
		Size = UDim2.new(0.34, 0, 0.66, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	page.Rotation = -0.4
	Kit.Base.make("UISizeConstraint", {
		MaxSize = Vector2.new(440, 480),
		MinSize = Vector2.new(300, 320),
		Parent = panel,
	})
	-- The title, big and lowercase like every sheet's, boiling.
	local header = Kit.frame({ Name = "Header", Size = UDim2.new(0.7, 0, 0, 44), Parent = content })
	local title = Kit.label({
		Text = "who did it.",
		font = "title",
		size = 44,
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, -6),
	})
	title:SetAttribute("KeepFont", true)
	title.Parent = header
	Kit.Boil.attach(title, 1, 0.2)
	voteGlitch = { enter = function() end }
	-- The clock, in equal-width digits; red in the last ten seconds.
	local timer = Kit.num({
		text = "",
		size = 40,
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
		font = "mono",
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
	arrestButton = Kit.button({
		text = "Arrest someone",
		icon = "cuffs",
		variant = "secondary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, T.touch),
		Visible = false,
		Parent = content,
	}, MeetingPanel.openArrest)

	-- Everything on the sheet in ink (Kit/Paper); the sheet's own paper stays paper.
	local surface = page:FindFirstChild("Surface")
	if surface then
		Kit.Paper.keep(surface)
	end
	Kit.Paper.apply(page)

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
