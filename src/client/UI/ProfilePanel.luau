-- Your profile: rank, lifetime numbers, every role's record and mastery, and achievements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = Shared:WaitForChild("Progression")
local Achievements = require(Progression:WaitForChild("Achievements"))
local Mastery = require(Progression:WaitForChild("Mastery"))
local Roles = require(Shared:WaitForChild("Roles"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors

local ProfilePanel = {}

local ROLE_ORDER = { "Kira", "Follower", "L", "Watari", "TaskForce" } -- terms:ok (internal ids)

local window: Frame
local list: ScrollingFrame
local order = 0

local function nextOrder(): number
	order += 1
	return order
end

local function header(text: string)
	Widgets.header({
		Text = text,
		TextSize = Theme.text.title,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
end

local function statGrid(entries: { { string } })
	local grid = Widgets.frame({
		Size = UDim2.new(1, -8, 0, math.ceil(#entries / 4) * 60),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	Widgets.grid(grid, UDim2.new(0.25, -6, 0, 54), 6)
	for _, entry in ipairs(entries) do
		local cell = Widgets.panel({ BackgroundColor3 = C.panelLight, Parent = grid })
		Widgets.display({
			Text = entry[2],
			TextSize = Theme.text.title,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 28),
			Parent = cell,
		})
		Widgets.label({
			Text = string.upper(entry[1]),
			TextSize = Theme.text.caption,
			TextColor3 = C.muted,
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 16),
			Parent = cell,
		})
	end
end

local function percent(won: number, played: number): string
	if played <= 0 then
		return "-"
	end
	return string.format("%d%%", math.floor(won / played * 100 + 0.5))
end

local function rebuild()
	Widgets.clear(list)
	order = 0
	local profile = ClientState.profile
	if not profile then
		return
	end
	local stats = profile.stats
	header(string.format("%s  ·  %d XP", profile.rankName, profile.xp))
	local bar, setProgress = Widgets.progressBar({
		Size = UDim2.new(1, -8, 0, 10),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	bar.Name = "RankProgress"
	if profile.nextRankXp then
		setProgress((profile.xp - profile.rankXp) / math.max(1, profile.nextRankXp - profile.rankXp))
	else
		setProgress(1)
	end
	statGrid({
		{ "Matches", tostring(stats.matches) },
		{ "Wins", tostring(stats.wins) },
		{ "Win rate", percent(stats.wins, stats.matches) },
		{ "Survived", tostring(stats.survived or 0) },
		{ "Case files", tostring(stats.tasks) },
		{ "Notes found", tostring(stats.notesFound or 0) },
		{ "Correct votes", tostring(stats.correctVotes or 0) },
		{ "Lost souls", tostring(stats.duties or 0) },
	})

	header("Roles")
	for _, roleId in ipairs(ROLE_ORDER) do
		local info = Roles.get(roleId)
		local record = stats.roles and stats.roles[roleId] or { played = 0, won = 0 }
		local xp = if profile.mastery then profile.mastery[roleId] or 0 else 0
		local level = Mastery.level(xp)
		local row = Widgets.panel({
			BackgroundColor3 = C.panelLight,
			Size = UDim2.new(1, -8, 0, 52),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		Widgets.display({
			Text = string.upper(info.display),
			TextSize = Theme.text.bodyLarge,
			TextColor3 = info.color,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(0.35, 0, 0, 22),
			Parent = row,
		})
		Widgets.label({
			Text = string.format(
				"%d played  ·  %d won  ·  %s",
				record.played,
				record.won,
				percent(record.won, record.played)
			),
			TextSize = Theme.text.small,
			TextColor3 = C.muted,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(0.5, 0, 0, 18),
			Parent = row,
		})
		Widgets.label({
			Text = string.format("MASTERY %d/%d", level, Mastery.MAX),
			FontFace = Theme.faces.display,
			TextSize = Theme.text.small,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 6),
			Size = UDim2.fromOffset(160, 18),
			Parent = row,
		})
		local _, setMastery = Widgets.progressBar({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 30),
			Size = UDim2.fromOffset(160, 8),
			Parent = row,
		}, info.color)
		local toNext = Mastery.toNext(xp)
		if toNext then
			local base = Mastery.LEVELS[level]
			setMastery((xp - base) / math.max(1, Mastery.LEVELS[level + 1] - base))
		else
			setMastery(1)
		end
	end

	header("Achievements")
	local unlocked = profile.achievements or {}
	for _, achievement in ipairs(Achievements.LIST) do
		local done = unlocked[achievement.id] ~= nil
		local row = Widgets.frame({
			Size = UDim2.new(1, -8, 0, 40),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		Widgets.label({
			Text = (if done then "✓  " else "    ") .. achievement.name,
			FontFace = Theme.faces.displayMedium,
			TextColor3 = if done then C.good else C.text,
			Size = UDim2.new(0.45, 0, 0, 20),
			Parent = row,
		})
		Widgets.label({
			Text = achievement.text,
			TextSize = Theme.text.small,
			TextColor3 = C.muted,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(0.7, 0, 0, 18),
			Parent = row,
		})
		if not done then
			Widgets.label({
				Text = string.format(
					"%d / %d",
					math.min(Achievements.value(profile, achievement), achievement.goal),
					achievement.goal
				),
				TextSize = Theme.text.small,
				TextColor3 = C.muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.3, 0, 0, 20),
				Parent = row,
			})
		end
	end
end

function ProfilePanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Profile", Vector2.new(700, 580), function()
		Router.close("profile", "user")
	end)
	list = Widgets.scroll({ Size = UDim2.fromScale(1, 1), Parent = body })
	Widgets.list(list, Theme.space.sm)
	Router.register("profile", {
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
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("profile") then
			rebuild()
		end
	end)
end

return ProfilePanel
