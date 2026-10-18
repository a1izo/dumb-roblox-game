-- Meeting panel: a page in the lower right for every participant during the meeting and the vote.
-- It says how to talk (free chat at the table, no real names) and where the task bar stands. For
-- whoever holds Ace's title it also carries the arrest: one per match, pointing at a living player
-- in the "arrest" window. A Coven player handed the title by mistake sees the same button and
-- knows it is worthless.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Toasts = require(script.Parent.Toasts)

local ArrestRemote = Net.event("Arrest")
local LocalPlayer = Players.LocalPlayer

local C = Kit.color
local T = Kit.Tokens

local MeetingPanel = {}

local panel: Frame
local barLabel: TextLabel
local aceNote: TextLabel
local arrestButton: TextButton

local renderSuspects: (any, any?, boolean?) -> { any }
local arrestNote: TextLabel
local suspect: number? = nil

local function canArrest(view): boolean
	return view.living
		and (view.phase == "Meeting" or view.phase == "Vote")
		and view.private.isAce == true
		and view.private.arrestUsed ~= true
end

local function refresh()
	local private = ClientState.private
	local bar = ClientState.public.taskBar
	barLabel.Text = if bar and (bar.total or 0) > 0
		then string.format("Case files: %d of %d done", bar.done or 0, bar.total)
		else ""
	local ace = private.isAce == true and ClientState.isLiving()
	aceNote.Visible = ace
	arrestButton.Visible = ace and private.arrestUsed ~= true
	if ace then
		aceNote.Text = if private.fakeAce
			then Terms.f("You hold a fake {zero} title. An arrest will fail and expose you.")
			elseif private.arrestUsed then "Your arrest is spent."
			else Terms.f(
				"You are {zero}. One arrest per match: a {cultist} or {hand} is removed; an innocent costs you your life."
			)
	end
end

-- The arrest window -------------------------------------------------------------------------

local function refreshArrest()
	local options = {}
	for _, entry in ipairs(ClientState.living()) do
		if entry.userId ~= LocalPlayer.UserId then
			table.insert(options, { id = entry.userId, text = entry.alias })
		end
	end
	renderSuspects(options, suspect)
	arrestNote.Text = "Arresting reveals that you are Ace. Pick carefully."
end

local function buildArrest()
	local win = Kit.window({ name = "arrest", title = Terms.f("{Zero}'s arrest"), size = "M" })
	local body = win.body
	arrestNote = Kit.label({ size = "small", color = C.dim, Parent = body })
	local list = Kit.scroll({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -(44 + 70)),
		Parent = body,
	})
	renderSuspects = Kit.pickGrid(list, UDim2.new(1 / 3, -T.space.s, 0, 48), function(id)
		suspect = id
		refreshArrest()
	end)
	Kit.button({
		text = "Arrest",
		icon = "cuffs",
		variant = "primary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = body,
	}, function()
		if not suspect then
			Toasts.show("Choose who to arrest first.", "bad")
			return
		end
		ArrestRemote:FireServer(suspect)
		Router.close("arrest", "user")
	end)
	Kit.register(win, {
		allowed = canArrest,
		show = refreshArrest,
		hide = function(reason)
			if reason == "rule" then
				suspect = nil
			end
		end,
	})
end

-- Opens the arrest window (the vote panel has a button for it too).
function MeetingPanel.openArrest()
	Router.open("arrest")
end

function MeetingPanel.init()
	local page, content = Kit.page({
		Name = "Meeting",
		tone = "raised",
		padding = T.space.l,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -T.space.l, 1, -T.space.l),
		Size = UDim2.new(0.3, 0, 0, 0),
		autoHeight = true,
		Visible = false,
		Parent = Screens.panels,
	})
	panel = page
	Kit.Base.make("UISizeConstraint", {
		MaxSize = Vector2.new(400, 380),
		MinSize = Vector2.new(280, 0),
		Parent = panel,
	})
	Kit.list(content, T.space.s)
	Kit.text({
		face = "Head",
		text = Terms.f("{Meeting}"),
		size = T.size.title,
		color = C.bone,
		LayoutOrder = 1,
		Parent = content,
	})
	Kit.label({
		Text = "Talk in chat. Messages with a living player's full real name are blocked.",
		size = "micro",
		color = C.dim,
		LayoutOrder = 2,
		Parent = content,
	})
	barLabel = Kit.label({ size = "small", color = C.bone, LayoutOrder = 3, Parent = content })
	aceNote = Kit.label({ size = "small", color = C.dim, Visible = false, LayoutOrder = 4, Parent = content })
	arrestButton = Kit.button({
		text = "Arrest someone",
		icon = "cuffs",
		variant = "secondary",
		size = "s",
		Visible = false,
		LayoutOrder = 5,
		Parent = content,
	}, MeetingPanel.openArrest)
	buildArrest()

	local function refreshOpen()
		if Router.isOpen("meeting") then
			refresh()
		end
		if Router.isOpen("arrest") then
			refreshArrest()
		end
	end
	ClientState.PrivateChanged:Connect(refreshOpen)
	ClientState.PublicChanged:Connect(refreshOpen)
	local function inMeeting(view): boolean
		return view.participant and (view.phase == "Meeting" or view.phase == "Vote")
	end
	Router.register("meeting", {
		layer = "panel",
		window = panel,
		auto = inMeeting,
		allowed = inMeeting,
		show = function()
			refresh()
			panel.Visible = true
		end,
		hide = function()
			panel.Visible = false
		end,
	})
end

return MeetingPanel
