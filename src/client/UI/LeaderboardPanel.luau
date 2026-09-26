-- The global leaderboards, kept like a ledger: all-time wins, experience, and this week's
-- wins (top 10 each, refreshed every few minutes by the server). Your own line is in red.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

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
}

local list: ScrollingFrame
local boards: { [string]: { any } } = {}
local current = "wins"

local function ledgerLine(entry, order: number)
	local mine = entry.userId == LocalPlayer.UserId
	local row = Kit.frame({ Name = "Line", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, Parent = list })
	if mine then
		row.BackgroundColor3 = C.lifted
		row.BackgroundTransparency = 0.4
	end
	Kit.label({
		Text = tostring(entry.rank),
		font = "mono",
		size = "lead",
		color = if entry.rank <= 3 then C.red else C.dim,
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
		color = if mine then C.red else C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, -(52 + 130), 1, 0),
		Parent = row,
	})
	Kit.label({
		Text = tostring(entry.value),
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
			Text = "No scores yet. Boards refresh every few minutes.",
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
	local tabs = Kit.tabs({ items = TABS, selected = current, Parent = win.body }, function(id)
		current = id
		rebuild()
	end)
	local _ = tabs
	list = Kit.scroll({
		Position = UDim2.fromOffset(0, T.touch + T.space.m),
		Size = UDim2.new(1, 0, 1, -(T.touch + T.space.m)),
		Parent = win.body,
	})
	Kit.list(list, 0)
	Kit.pad(list, 0, T.space.xs)
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
