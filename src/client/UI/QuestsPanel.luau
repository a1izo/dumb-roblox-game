-- Quests and the daily streak. Three daily and three weekly quests (the same for everyone), three
-- Deathsinger quests a day (they only progress in cases you end as a Deathsinger),
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
local LobbyChrome = require(script.Parent.Core.LobbyChrome)
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
local popup: CanvasGroup
local popupNotice: any -- the streak's notice (Kit/Notice)
local heldByCinema = false -- the pop-up wanted to show while a cutscene's frame was up
local popupShown = false

local function formatTime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	if hours >= 24 then
		return string.format("%dd %dh", math.floor(hours / 24), hours % 24)
	end
	return string.format("%dh %02dm", hours, math.floor((seconds % 3600) / 60))
end

-- A drawn box that boils (a checklist's box, or a streak day): filled ink when `filled`, ringed red when `ring`.
local function drawnBox(
	parent: Instance,
	size: number,
	filled: boolean,
	ring: boolean,
	props: { [string]: any }?
): Frame
	local p = props or {}
	local box = Kit.Base.make("Frame", {
		Name = "Box",
		BackgroundColor3 = C.bone,
		BackgroundTransparency = if filled then 0 else 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.LayoutOrder,
		Parent = parent,
	})
	Kit.Base.stroke(box, if ring then C.danger else C.bone, 2, 0)
	Kit.Boil.attach(box, 1)
	return box
end

-- A quest as a checklist line (the concept A plan): a drawn box, ticked red when done; the quest; how far along and
-- what it pays in mono; Swap where a swap is free; a thin rule under it.
local function questCard(item, canSwap: boolean, order: number)
	local quest = Quests.byId(item.id)
	if not quest then
		return
	end
	local line = Kit.frame({ Name = "Quest", Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order, Parent = list })
	local box = drawnBox(line, 22, false, false, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
	})
	if item.done then
		local tick = Kit.icon({
			name = "check",
			size = 26,
			color = C.danger,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.6, 0.4),
			Parent = box,
		})
		Kit.Boil.attach(tick, 1)
	end
	Kit.label({
		Text = quest.text,
		font = "body",
		size = "lead",
		color = if item.done then C.g5 else C.bone,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, -2),
		Size = UDim2.new(1, -(40 + SIDE + 90), 0, 30),
		Parent = line,
	})
	Kit.label({
		Text = string.format("%d/%d   +%d R  +%d XP", item.progress, quest.goal, quest.coins, quest.xp),
		font = "mono",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(if canSwap and not item.done then 96 else 0), 0.5, 0),
		Size = UDim2.fromOffset(SIDE + 80, 20),
		Parent = line,
	})
	if canSwap and not item.done then
		Kit.button({
			text = "Swap",
			variant = "secondary",
			size = "s",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Parent = line,
		}, function()
			ProfileRequest:FireServer({ action = "reroll", quest = item.id })
		end)
	end
	Kit.rule({ color = C.bone, transparency = 0.75, Position = UDim2.new(0, 0, 1, -1), Parent = line })
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
	-- The streak as seven day boxes (the concept A plan): the days of this week's run filled, today's ringed red.
	local streakRow =
		Kit.frame({ Name = "Streak", Size = UDim2.new(1, 0, 0, 92), LayoutOrder = nextOrder(), Parent = list })
	local done = if claimable then (nextCount - 1) % Streak.CYCLE else ((streak.count - 1) % Streak.CYCLE) + 1
	for day = 1, Streak.CYCLE do
		local x = (day - 1) * 52
		drawnBox(streakRow, 38, day <= done, claimable and day == done + 1, { Position = UDim2.fromOffset(x, 6) })
		Kit.label({
			Text = tostring(day),
			font = "mono",
			size = "small",
			color = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(x, 48),
			Size = UDim2.fromOffset(38, 18),
			Parent = streakRow,
		})
	end
	Kit.label({
		Text = if claimable
			then string.format("Day %d: +%d Reál. Day 7 unlocks Night Owl.", nextCount, Streak.COINS[cycleDay])
			else string.format("Day %d claimed. Next in %s.", streak.count, formatTime(profile.nextDayIn or 0)),
		font = "body",
		color = C.dim,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, -160, 0, 0),
		Parent = streakRow,
	})
	local claim = Kit.button({
		text = if claimable then "Claim" else "Claimed",
		icon = if claimable then "real" else "check",
		variant = if claimable then "primary" else "secondary",
		size = "s",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Parent = streakRow,
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
	local ghost = profile.quests.ghost
	if type(ghost) == "table" and type(ghost.items) == "table" and #ghost.items > 0 then
		Kit.heading({
			text = "Deathsinger",
			detail = "Deathsinger only. New in " .. formatTime(profile.nextDayIn or 0),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		for _, item in ipairs(ghost.items) do
			questCard(item, false, nextOrder())
		end
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
	popupNotice:setTitle(string.format("Day %d streak", nextCount))
	popupNotice:setBody(string.format("+%d Reál to claim", Streak.COINS[cycleDay]))
	-- (never over a cutscene, the shop's Preview of a scene death included: it waits for the frame to go)
	if Screens.hud:GetAttribute("Cinematic") == true then
		heldByCinema = true
	else
		popup.Visible = true
	end
end

local function buildPopup()
	popupNotice = Kit.notice({
		Name = "StreakPopup",
		kind = "coin",
		icon = "streak",
		eyebrow = "Daily reward",
		AnchorPoint = Vector2.new(1, 1),
		Visible = false,
		actions = {
			{
				text = "Claim",
				icon = "real",
				onClick = function()
					ProfileRequest:FireServer({ action = "streak" })
					popup.Visible = false
				end,
			},
			{
				text = "Later",
				onClick = function()
					popup.Visible = false
				end,
			},
		},
		Parent = Screens.panels,
	})
	popup = popupNotice.group
	-- It sits just above your card at the bottom right, so it never covers the card (or the title above).
	-- The card lives in another layer, so its top is read on screen and turned into this layer's units
	-- (a probe marks where this layer starts).
	local card = LobbyPanel.profileCard()
	local probe = Kit.frame({ Name = "StreakProbe", Size = UDim2.fromOffset(0, 0), Parent = Screens.panels })
	local GAP = 16
	-- The Trial's card at the top right, when it is on screen.
	local function trialCard(): GuiObject?
		local found = Screens.hud:FindFirstChild("TrialObjective", true)
		local node: Instance? = found
		while node and node ~= Screens.hud do
			if node:IsA("GuiObject") and not node.Visible then
				return nil
			end
			node = node.Parent
		end
		return if found and found:IsA("GuiObject") then found else nil
	end
	local function place()
		popupNotice:setWidth(Kit.Notice.width())
		local scale = Kit.Base.scaleOf(popup)
		local bottom = (card.AbsolutePosition.Y - probe.AbsolutePosition.Y) / scale - GAP
		-- (over the card it would reach up into the Trial's card on a short screen, a phone's or a small window's,
		-- 2026-11-12: then it goes to the bottom middle, between a phone's thumbstick and jump button)
		local trial = trialCard()
		local top = card.AbsolutePosition.Y - GAP * scale - popup.AbsoluteSize.Y
		local crowded = trial ~= nil and top < trial.AbsolutePosition.Y + trial.AbsoluteSize.Y + 8 * scale
		if Kit.Layout.isPhone() or crowded then
			popup.AnchorPoint = Vector2.new(0.5, 1)
			popup.Position = UDim2.new(0.5, 0, 1, -T.space.l)
			return
		end
		popup.AnchorPoint = Vector2.new(1, 1)
		popup.Position = UDim2.new(1, -T.space.l, 0, math.floor(bottom))
	end
	-- (looked at again twice a second while it is up: the Trial's card comes and goes, grows, and is hidden with the
	-- lobby's intro, and none of that tells this card)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if popup.Visible then
				place()
			end
		end
	end)
	-- Hide UI hides the pop-up too; it comes back with the rest if it was still waiting.
	local waiting = false
	LobbyChrome.Changed:Connect(function(hidden: boolean)
		if hidden then
			waiting = popup.Visible
			popup.Visible = false
		elseif waiting then
			waiting = false
			if Screens.hud:GetAttribute("Cinematic") == true then
				heldByCinema = true
			else
				popup.Visible = true
			end
		end
	end)
	-- A cutscene's frame (Cinema.letterbox) hides it the same way, 2026-11-09: it showed over the scene deaths when the
	-- shop previewed one in the lobby.
	Screens.hud:GetAttributeChangedSignal("Cinematic"):Connect(function()
		if Screens.hud:GetAttribute("Cinematic") == true then
			heldByCinema = heldByCinema or popup.Visible
			popup.Visible = false
		elseif heldByCinema then
			heldByCinema = false
			if not LobbyChrome.isHidden() then
				popup.Visible = true
			else
				waiting = true
			end
		end
	end)
	card:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	popup:GetPropertyChangedSignal("Visible"):Connect(place)
	popup:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	Kit.Layout.watch(function()
		place()
	end)
	place()
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
