-- Quests and the daily streak. Three daily and three weekly quests (the same for everyone),
-- progress from finished matches, and one free swap of a daily quest per day. The streak
-- pops up once per session in the lobby when today's reward is waiting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Progression = Shared:WaitForChild("Progression")
local Quests = require(Progression:WaitForChild("Quests"))
local Streak = require(Progression:WaitForChild("Streak"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ProfileRequest = Net.event("ProfileRequest")

local C = Theme.colors

local QuestsPanel = {}

local window: Frame
local list: ScrollingFrame
local popup: Frame
local popupText: TextLabel
local popupShown = false
local order = 0

local function formatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	if hours >= 24 then
		return string.format("%dd %dh", math.floor(hours / 24), hours % 24)
	end
	return string.format("%dh %02dm", hours, math.floor((seconds % 3600) / 60))
end

local function nextOrder(): number
	order += 1
	return order
end

local function header(text: string, detail: string?)
	local row = Widgets.frame({ Size = UDim2.new(1, -8, 0, 30), LayoutOrder = nextOrder(), Parent = list })
	Widgets.header({ Text = text, TextSize = Theme.text.title, Size = UDim2.new(0.6, 0, 1, 0), Parent = row })
	if detail then
		Widgets.label({
			Text = detail,
			TextColor3 = C.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.4, 0, 1, 0),
			Parent = row,
		})
	end
end

local function questRow(item, canSwap: boolean)
	local quest = Quests.byId(item.id)
	if not quest then
		return
	end
	local row = Widgets.panel({
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, -8, 0, 64),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	Widgets.label({
		Text = (if item.done then "DONE  ·  " else "") .. quest.text,
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = if item.done then C.good else C.text,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -150, 0, 22),
		Parent = row,
	})
	local bar, setProgress = Widgets.progressBar({
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -230, 0, 10),
		Parent = row,
	}, if item.done then C.good else C.accent)
	setProgress(item.progress / quest.goal)
	bar.Name = "Progress"
	Widgets.label({
		Text = string.format("%d / %d", item.progress, quest.goal),
		TextSize = Theme.text.small,
		TextColor3 = C.muted,
		Position = UDim2.new(1, -212, 0, 34),
		Size = UDim2.fromOffset(70, 18),
		Parent = row,
	})
	Widgets.label({
		Text = string.format("+%d coins  +%d XP", quest.coins, quest.xp),
		TextSize = Theme.text.small,
		TextColor3 = C.paper,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(130, 18),
		Parent = row,
	})
	if canSwap and not item.done then
		Widgets.button({
			Text = "Swap",
			TextSize = Theme.text.small,
			Variant = "secondary",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 30),
			Size = UDim2.fromOffset(80, 28),
			Parent = row,
		}, function()
			ProfileRequest:FireServer({ action = "reroll", quest = item.id })
		end)
	end
end

local function canClaim(profile): boolean
	return profile.streak ~= nil and profile.today ~= nil and Streak.canClaim(profile.streak, profile.today)
end

local function rebuild()
	Widgets.clear(list)
	order = 0
	local profile = ClientState.profile
	if not profile or not profile.quests then
		return
	end
	-- Streak
	local streak = profile.streak
	local claimable = canClaim(profile)
	local nextCount = Streak.nextCount(streak, profile.today)
	local cycleDay = ((nextCount - 1) % Streak.CYCLE) + 1
	header("Daily streak", string.format("Best: %d days", streak.best))
	local streakRow = Widgets.panel({
		BackgroundColor3 = C.panelLight,
		Size = UDim2.new(1, -8, 0, 64),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	Widgets.label({
		Text = if claimable
			then string.format("Day %d is waiting: +%d coins", nextCount, Streak.COINS[cycleDay])
			else string.format(
				"Day %d claimed. Come back in %s.",
				streak.count,
				formatTime(profile.nextDayIn or 0)
			),
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.bodyLarge,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -150, 0, 22),
		Parent = streakRow,
	})
	Widgets.label({
		Text = "Day 7 of a streak also unlocks the Night Owl title.",
		TextSize = Theme.text.small,
		TextColor3 = C.muted,
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -150, 0, 20),
		Parent = streakRow,
	})
	local claim = Widgets.button({
		Text = if claimable then "Claim" else "Claimed",
		Variant = if claimable then "primary" else "secondary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(110, 36),
		Parent = streakRow,
	}, function()
		ProfileRequest:FireServer({ action = "streak" })
	end)
	Widgets.setEnabled(claim, claimable)

	local swapFree = profile.quests.rerollDay ~= profile.today
	header("Daily quests", "New in " .. formatTime(profile.nextDayIn or 0))
	for _, item in ipairs(profile.quests.daily.items) do
		questRow(item, swapFree)
	end
	header("Weekly quests", "New in " .. formatTime(profile.nextWeekIn or 0))
	for _, item in ipairs(profile.quests.weekly.items) do
		questRow(item, false)
	end
end

-- The streak popup ------------------------------------------------------------------------------

local function maybePopup()
	local profile = ClientState.profile
	if popupShown or not profile or ClientState.isParticipant() or not canClaim(profile) then
		return
	end
	popupShown = true
	local nextCount = Streak.nextCount(profile.streak, profile.today)
	local cycleDay = ((nextCount - 1) % Streak.CYCLE) + 1
	popupText.Text = string.format("Day %d of your streak: +%d coins are waiting.", nextCount, Streak.COINS[cycleDay])
	popup.Visible = true
end

function QuestsPanel.init()
	local body
	window, body = Widgets.modal(Screens.modal, "Quests", Vector2.new(640, 560), function()
		Router.close("quests", "user")
	end)
	list = Widgets.scroll({ Size = UDim2.fromScale(1, 1), Parent = body })
	Widgets.list(list, Theme.space.sm)
	Router.register("quests", {
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

	popup = Widgets.panel({
		Name = "StreakPopup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 90),
		Size = UDim2.fromOffset(340, 118),
		Visible = false,
		Parent = Screens.panels,
	})
	local ribbon = Widgets.ribbon({ Position = UDim2.fromOffset(-10, -12), Parent = popup }, "DAILY STREAK")
	ribbon.ZIndex = 2
	popupText = Widgets.label({
		TextSize = Theme.text.body,
		Position = UDim2.fromOffset(14, 26),
		Size = UDim2.new(1, -28, 0, 40),
		Parent = popup,
	})
	Widgets.button({
		Text = "Claim",
		Variant = "primary",
		Position = UDim2.new(0, 14, 1, -46),
		Size = UDim2.fromOffset(140, 36),
		Parent = popup,
	}, function()
		ProfileRequest:FireServer({ action = "streak" })
		popup.Visible = false
	end)
	Widgets.button({
		Text = "Later",
		Variant = "ghost",
		Position = UDim2.new(0, 164, 1, -46),
		Size = UDim2.fromOffset(110, 36),
		Parent = popup,
	}, function()
		popup.Visible = false
	end)

	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("quests") then
			rebuild()
		end
		maybePopup()
	end)
	ClientState.PhaseChanged:Connect(function()
		if ClientState.isParticipant() then
			popup.Visible = false
		end
	end)
end

return QuestsPanel
