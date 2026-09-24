-- The global leaderboards: all-time wins, experience, and this week's wins (top 10 each,
-- refreshed every few minutes by the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors
local LocalPlayer = Players.LocalPlayer

local LeaderboardPanel = {}

local TABS = { { "wins", "Most wins" }, { "xp", "Experience" }, { "weekly", "This week" } }

local window: Frame
local tabRow: Frame
local list: ScrollingFrame
local boards: { [string]: { any } } = {}
local current = "wins"

local rebuild: () -> ()

local function buildTabs()
	Widgets.clear(tabRow)
	for index, tab in ipairs(TABS) do
		Widgets.button({
			Text = tab[2],
			TextSize = Theme.text.small,
			Variant = if tab[1] == current then "primary" else "ghost",
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
			LayoutOrder = index,
			Parent = tabRow,
		}, function()
			current = tab[1]
			rebuild()
		end)
	end
end

function rebuild()
	buildTabs()
	Widgets.clear(list)
	local entries = boards[current] or {}
	if #entries == 0 then
		Widgets.label({
			Text = "No scores yet. Boards refresh every few minutes.",
			TextColor3 = C.muted,
			Size = UDim2.new(1, -8, 0, 24),
			Parent = list,
		})
		return
	end
	for index, entry in ipairs(entries) do
		local mine = entry.userId == LocalPlayer.UserId
		local row = Widgets.panel({
			BackgroundColor3 = if mine then C.accent else C.panelLight,
			Size = UDim2.new(1, -8, 0, 40),
			LayoutOrder = index,
			Parent = list,
		})
		Widgets.display({
			Text = tostring(entry.rank),
			TextSize = Theme.text.title,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.fromOffset(40, 28),
			Parent = row,
		})
		Widgets.label({
			Text = tostring(entry.name),
			FontFace = Theme.faces.displayMedium,
			TextSize = Theme.text.bodyLarge,
			Position = UDim2.fromOffset(58, 9),
			Size = UDim2.new(1, -180, 0, 22),
			Parent = row,
		})
		Widgets.display({
			Text = tostring(entry.value),
			TextSize = Theme.text.title,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(110, 28),
			Parent = row,
		})
	end
end

function LeaderboardPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Leaderboards", Vector2.new(540, 560), function()
		Router.close("leaderboards", "user")
	end)
	tabRow = Widgets.frame({ Size = UDim2.new(1, 0, 0, 36), Parent = body })
	Widgets.list(tabRow, 6, true)
	list = Widgets.scroll({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), Parent = body })
	Widgets.list(list, 6)
	Net.event("Leaderboard").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			boards = payload
			if Router.isOpen("leaderboards") then
				rebuild()
			end
		end
	end)
	Router.register("leaderboards", {
		layer = "modal",
		window = window,
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			window.Visible = true
			rebuild()
		end,
		hide = function()
			window.Visible = false
		end,
	})
end

return LeaderboardPanel
