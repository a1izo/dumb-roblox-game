-- The reveal: winner, every role and real name, a replay of the key events and rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local RevealScreen = {}

local root: Frame
local winnerLabel: TextLabel
local reasonLabel: TextLabel
local roster: ScrollingFrame
local timeline: ScrollingFrame
local rewardsLabel: TextLabel
local token = 0

local function fillRoster(players)
	Widgets.clear(roster)
	for index, entry in ipairs(players) do
		local info = Roles.get(entry.role)
		local row = Widgets.frame({
			Size = UDim2.new(1, -8, 0, 44),
			LayoutOrder = index,
			Parent = roster,
		})
		Widgets.label({
			Text = string.format("%s  (%s)", tostring(entry.alias), tostring(entry.displayName)),
			Font = Theme.fonts.bold,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Size = UDim2.new(0.62, 0, 0, 20),
			Parent = row,
		})
		Widgets.label({
			Text = string.upper(tostring(entry.realName)),
			Font = Theme.fonts.typewriter,
			TextSize = 14,
			TextColor3 = Theme.colors.paper,
			Position = UDim2.fromOffset(0, 21),
			Size = UDim2.new(0.62, 0, 0, 20),
			Parent = row,
		})
		Widgets.label({
			Text = info.display,
			Font = Theme.fonts.black,
			TextSize = 15,
			TextColor3 = info.color,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.62, 0),
			Size = UDim2.new(0.38, 0, 0, 20),
			Parent = row,
		})
		local status = Theme.STATUS_NAMES[entry.status] or tostring(entry.status)
		if entry.cause then
			status ..= " - " .. tostring(entry.cause)
		end
		Widgets.label({
			Text = status,
			TextSize = 12,
			TextColor3 = Theme.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.62, 0, 0, 21),
			Size = UDim2.new(0.38, 0, 0, 20),
			Parent = row,
		})
	end
end

local function playTimeline(events, myToken: number)
	Widgets.clear(timeline)
	for index, event in ipairs(events) do
		if token ~= myToken then
			return
		end
		local isKira = event.kind == "kill"
			or event.kind == "eyes"
			or event.kind == "burn"
			or event.kind == "fake"
			or event.kind == "tamper"
		Widgets.label({
			Text = string.format("R%s %s   %s", tostring(event.round), tostring(event.time), tostring(event.text)),
			Font = if event.kind == "role" then Theme.fonts.body else Theme.fonts.medium,
			TextSize = 14,
			TextColor3 = if isKira
				then Theme.colors.bad
				elseif event.kind == "role" then Theme.colors.muted
				else Theme.colors.text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -10, 0, 0),
			LayoutOrder = index,
			Parent = timeline,
		})
		timeline.CanvasPosition = Vector2.new(0, 1e6)
		task.wait(if event.kind == "role" then 0.08 else 0.4)
	end
end

function RevealScreen.show(payload)
	token += 1
	local myToken = token
	local teamWon = payload.winner == "Team"
	winnerLabel.Text = if teamWon then Terms.f("{AGENCY} WINS") else Terms.f("{HAND} WINS")
	winnerLabel.TextColor3 = if teamWon then Theme.TONES.team else Theme.TONES.kira
	reasonLabel.Text = tostring(payload.reason or "")
	fillRoster(payload.players or {})
	local rewards = payload.rewards
	if type(rewards) == "table" then
		local lines = {
			string.format(
				"%s   +%d coins   +%d XP",
				if rewards.won then "VICTORY" else "DEFEAT",
				rewards.coins,
				rewards.xp
			),
		}
		for _, line in ipairs(rewards.lines or {}) do
			table.insert(lines, string.format("%s: +%d coins, +%d XP", tostring(line.label), line.coins, line.xp))
		end
		rewardsLabel.Text = table.concat(lines, "\n")
	else
		rewardsLabel.Text = "You watched this case from the lobby."
	end
	root.Visible = true
	Router.setBlocking("reveal", true)
	task.spawn(playTimeline, payload.events or {}, myToken)
end

function RevealScreen.init()
	root = Widgets.frame({
		Name = "Reveal",
		BackgroundTransparency = 0.12,
		BackgroundColor3 = Theme.colors.backdrop,
		Visible = false,
		Parent = Screens.overlay,
	})
	local window = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.92),
		Parent = root,
	})
	Widgets.sizeLimit(window, Vector2.new(1100, 700))
	winnerLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = window,
	})
	reasonLabel = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = window,
	})
	local left = Widgets.panel({
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(0.45, -8, 1, -150),
		Parent = window,
	})
	Widgets.label({
		Text = "ROLES AND REAL NAMES",
		Font = Theme.fonts.black,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = left,
	})
	roster = Widgets.scroll({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 1, -44),
		Parent = left,
	})
	Widgets.list(roster, 6)
	local right = Widgets.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 90),
		Size = UDim2.new(0.55, -8, 1, -150),
		Parent = window,
	})
	Widgets.label({
		Text = "CASE REPLAY",
		Font = Theme.fonts.black,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = right,
	})
	timeline = Widgets.scroll({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 1, -44),
		Parent = right,
	})
	Widgets.list(timeline, 4)
	rewardsLabel = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = 14,
		TextColor3 = Theme.colors.gold,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, -140, 0, 54),
		Parent = window,
	})
	Widgets.button({
		Text = "CLOSE",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(120, 40),
		Parent = window,
	}, function()
		token += 1
		root.Visible = false
		Router.setBlocking("reveal", false)
	end)

	Net.event("Reveal").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			RevealScreen.show(payload)
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase == "Briefing" then
			token += 1
			root.Visible = false
			Router.setBlocking("reveal", false)
		end
	end)
end

return RevealScreen
