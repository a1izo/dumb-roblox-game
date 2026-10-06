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
local Kit = require(script.Parent.Kit)
local LobbyPanel = require(script.Parent.LobbyPanel)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local ProfileRequest = Net.event("ProfileRequest")

local C = Kit.color
local T = Kit.Tokens

local QuestsPanel = {}

-- Right-hand column of a quest card: the reward, and the swap button under it.
local SIDE = 170

local list: ScrollingFrame
local popup: Frame
local popupText: TextLabel
local popupShown = false

local function formatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	if hours >= 24 then
		return string.format("%dd %dh", math.floor(hours / 24), hours % 24)
	end
	return string.format("%dh %02dm", hours, math.floor((seconds % 3600) / 60))
end

local function questCard(item, canSwap: boolean, order: number)
	local quest = Quests.byId(item.id)
	if not quest then
		return
	end
	local card = Kit.card({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order, Parent = list })
	Kit.label({
		Text = (if item.done then "Done  ·  " else "") .. quest.text,
		font = "bodyBold",
		color = if item.done then C.good else C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -SIDE, 0, 22),
		Parent = card,
	})
	local bar, setProgress = Kit.meter({
		color = if item.done then C.white else C.g6,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, -(SIDE + 80), 0, 6),
		Parent = card,
	})
	bar.Name = "Progress"
	setProgress(item.progress / quest.goal)
	Kit.label({
		Text = string.format("%d / %d", item.progress, quest.goal),
		font = "mono",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.new(1, -(SIDE + 70), 0, 31),
		Size = UDim2.fromOffset(64, 20),
		Parent = card,
	})
	Kit.label({
		Text = string.format("+%d coins  ·  +%d XP", quest.coins, quest.xp),
		font = "label",
		size = "small",
		color = C.candle,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(SIDE, 20),
		Parent = card,
	})
	if canSwap and not item.done then
		Kit.button({
			text = "Swap",
			variant = "ghost",
			size = "s",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Parent = card,
		}, function()
			ProfileRequest:FireServer({ action = "reroll", quest = item.id })
		end)
	end
end

local function canClaim(profile): boolean
	return profile.streak ~= nil and profile.today ~= nil and Streak.canClaim(profile.streak, profile.today)
end

local function rebuild()
	Kit.clear(list)
	local profile = ClientState.profile
	if not profile or not profile.quests then
		return
	end
	local nextOrder = Kit.counter()
	-- Streak
	local streak = profile.streak
	local claimable = canClaim(profile)
	local nextCount = Streak.nextCount(streak, profile.today)
	local cycleDay = ((nextCount - 1) % Streak.CYCLE) + 1
	Kit.heading({
		text = "Daily streak",
		detail = string.format("Best: %d days", streak.best),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	local streakCard = Kit.card({ Size = UDim2.new(1, 0, 0, 76), LayoutOrder = nextOrder(), Parent = list })
	Kit.label({
		Text = if claimable
			then string.format("Day %d is waiting: +%d coins", nextCount, Streak.COINS[cycleDay])
			else string.format(
				"Day %d claimed. Come back in %s.",
				streak.count,
				formatTime(profile.nextDayIn or 0)
			),
		font = "bodyBold",
		Size = UDim2.new(1, -140, 0, 0),
		Parent = streakCard,
	})
	Kit.label({
		Text = "Day 7 of a streak also unlocks the Night Owl title.",
		size = "small",
		color = C.dim,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, -140, 0, 0),
		Parent = streakCard,
	})
	local claim = Kit.button({
		text = if claimable then "Claim" else "Claimed",
		icon = if claimable then "coin" else "check",
		variant = if claimable then "primary" else "secondary",
		size = "s",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Parent = streakCard,
	}, function()
		ProfileRequest:FireServer({ action = "streak" })
	end)
	Kit.setEnabled(claim, claimable)

	local swapFree = profile.quests.rerollDay ~= profile.today
	Kit.heading({
		text = "Daily quests",
		detail = "New in " .. formatTime(profile.nextDayIn or 0),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	for _, item in ipairs(profile.quests.daily.items) do
		questCard(item, swapFree, nextOrder())
	end
	Kit.heading({
		text = "Weekly quests",
		detail = "New in " .. formatTime(profile.nextWeekIn or 0),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	for _, item in ipairs(profile.quests.weekly.items) do
		questCard(item, false, nextOrder())
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

local function buildPopup()
	local page, content = Kit.page({
		Name = "StreakPopup",
		tone = "raised",
		padding = T.space.l,
		autoHeight = true,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(340, 0),
		Visible = false,
		Parent = Screens.panels,
	})
	popup = page
	-- It sits just above your card at the bottom right, so it never covers the card (or the title above).
	local card = LobbyPanel.profileCard()
	local function place()
		local scale = Kit.Base.scaleOf(card)
		local above = math.ceil(card.AbsoluteSize.Y / scale) + T.space.l + T.space.s
		popup.Size = UDim2.fromOffset(if Kit.Layout.isPhone() then 260 else 340, 0)
		popup.Position = UDim2.new(1, -T.space.l, 1, -above)
	end
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	popup:GetPropertyChangedSignal("Visible"):Connect(place)
	place()
	Kit.list(content, T.space.s)
	Kit.text({
		face = "Head",
		text = "Daily streak",
		size = T.size.title,
		color = C.white,
		LayoutOrder = 1,
		Parent = content,
	})
	popupText = Kit.label({ LayoutOrder = 2, Parent = content })
	local row = Kit.frame({ Name = "Actions", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 3, Parent = content })
	Kit.list(row, T.space.s, true)
	Kit.button(
		{ text = "Claim", icon = "coin", variant = "primary", size = "s", LayoutOrder = 1, Parent = row },
		function()
			ProfileRequest:FireServer({ action = "streak" })
			popup.Visible = false
		end
	)
	Kit.button({ text = "Later", variant = "ghost", size = "s", LayoutOrder = 2, Parent = row }, function()
		popup.Visible = false
	end)
end

function QuestsPanel.init()
	local win = Kit.window({ name = "quests", title = "Quests", jp = "任務", size = "M" })
	list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, 0, T.space.xs)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			rebuild()
		end,
	})
	buildPopup()

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
