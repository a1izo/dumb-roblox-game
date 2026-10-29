-- The global leaderboards, kept like a ledger: all-time wins, experience, this week's wins, and the
-- lobby's own games (the Spire Ascent, the rune courtyard, the spirit trial). Top 10 each, refreshed every
-- few minutes by the server; your own line is lit. Only Most Wins is also written in the world (on its
-- slab beside the throne): every other board lives here. The boards are a column of tabs on a desktop and
-- a row to swipe on a phone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local LastBreath =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames"):WaitForChild("LastBreath"))
local Parkour = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames"):WaitForChild("Parkour"))

local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens
local LocalPlayer = Players.LocalPlayer

local LeaderboardPanel = {}

local TABS = {
	{ id = "wins", label = "Most wins", icon = "trophy" },
	{ id = "xp", label = "Experience", icon = "xp" },
	{ id = "weekly", label = "This week", icon = "streak" },
	{ id = "parkour", label = "Ascent" },
	{ id = "runes", label = "Runes" },
	{ id = "rift", label = "Last breath" },
	{ id = "spirit", label = "Spirit trial", icon = "eye" },
}
-- Boards whose score is a time, kept in hundredths of a second.
local TIMED = { parkour = true, spirit = true }
local TABS_WIDTH = 190
local GAP = 16

local list: ScrollingFrame
local boards: { [string]: { any } } = {}
local current = "wins"

local function ledgerLine(entry, order: number)
	local mine = entry.userId == LocalPlayer.UserId
	local row = Kit.frame({ Name = "Line", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, Parent = list })
	if mine then
		row.BackgroundColor3 = C.g1
		row.BackgroundTransparency = 0.4
	end
	Kit.label({
		Text = tostring(entry.rank),
		font = "mono",
		size = "lead",
		color = if entry.rank <= 3 then C.white else C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 36, 1, 0),
		Parent = row,
	})
	-- Display names can be in any script, so they are set in the body face, not the ink.
	Kit.label({
		Text = tostring(entry.name),
		font = "bodyBold",
		size = "lead",
		color = if mine then C.white else C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -(52 + 130), 1, 0),
		Parent = row,
	})
	Kit.label({
		-- (The rift's score is the gap left above the roof, in hundredths of a stud.)
		Text = if TIMED[current]
			then Parkour.formatCentis(entry.value)
			elseif current == "rift" then LastBreath.formatScore(entry.value)
			else tostring(entry.value),
		font = "mono",
		size = "lead",
		color = C.bone,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -T.space.s, 0, 0),
		Size = UDim2.new(0, 110, 1, 0),
		Parent = row,
	})
	Kit.rule({ Position = UDim2.new(0, 0, 1, -1), Parent = row })
end

local function rebuild()
	Kit.clear(list)
	local entries = boards[current] or {}
	if #entries == 0 then
		Kit.label({
			Text = "No scores yet.",
			font = "bodyItalic",
			color = C.dim,
			Parent = list,
		})
		return
	end
	for index, entry in ipairs(entries) do
		ledgerLine(entry, index)
	end
end

function LeaderboardPanel.init()
	local win = Kit.window({ name = "leaderboards", title = "Leaderboards", size = "M" })
	-- Two tab strips share one selection (as in the shop): a column for desktops, a scrolling row for phones.
	local syncing = false
	local selectColumn: (string) -> () = function(_id: string) end
	local selectRow: (string) -> () = function(_id: string) end
	local function onTab(id: string)
		if syncing then
			return
		end
		syncing = true
		selectColumn(id)
		selectRow(id)
		syncing = false
		current = id
		rebuild()
	end
	local column
	column, selectColumn = Kit.tabs({
		items = TABS,
		selected = current,
		vertical = true,
		Size = UDim2.new(0, TABS_WIDTH, 1, 0),
		Parent = win.body,
	}, onTab)
	local rowScroll = Kit.Base.make("ScrollingFrame", {
		Name = "TabRow",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, T.touch),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Visible = false,
		Parent = win.body,
	}) :: ScrollingFrame
	local rowTabs
	rowTabs, selectRow = Kit.tabs({
		items = TABS,
		selected = current,
		Size = UDim2.fromOffset(0, T.touch),
		Parent = rowScroll,
	}, onTab)
	rowTabs.AutomaticSize = Enum.AutomaticSize.X
	list = Kit.scroll({ Parent = win.body })
	Kit.list(list, 0)
	Kit.pad(list, 0, T.space.xs)
	Kit.Layout.watch(function(class: string)
		local phone = class == "phone"
		column.Visible = not phone
		rowScroll.Visible = phone
		if phone then
			list.Position = UDim2.fromOffset(0, T.touch + T.space.m)
			list.Size = UDim2.new(1, 0, 1, -(T.touch + T.space.m))
		else
			list.Position = UDim2.fromOffset(TABS_WIDTH + GAP, 0)
			list.Size = UDim2.new(1, -(TABS_WIDTH + GAP), 1, 0)
		end
	end)
	Net.event("Leaderboard").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			boards = payload
			if Router.isOpen("leaderboards") then
				rebuild()
			end
		end
	end)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			rebuild()
		end,
	})
end

return LeaderboardPanel
