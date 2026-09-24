-- The lobby menu: title, rank and experience, coins, the READY button and the menu
-- (shop, party, settings). Shown to everyone who is not playing in the current match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ReadyRemote = Net.event("Ready")

local LobbyPanel = {}

local panel: Frame
local rankLabel: TextLabel
local setXp: (number) -> ()
local xpLabel: TextLabel
local coinsLabel: TextLabel
local statusLabel: TextLabel
local readyButton: TextButton
local saveWarning: TextLabel
local lastCoins: number? = nil

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		rankLabel.Text = "Loading profile..."
		return
	end
	rankLabel.Text = string.upper(profile.rankName)
	if lastCoins and lastCoins ~= profile.coins then
		Motion.countUp(coinsLabel, lastCoins, profile.coins, 0.6, function(value)
			return string.format("%d coins", math.floor(value + 0.5))
		end)
	else
		coinsLabel.Text = string.format("%d coins", profile.coins)
	end
	lastCoins = profile.coins
	if profile.nextRankXp then
		local span = math.max(1, profile.nextRankXp - profile.rankXp)
		setXp((profile.xp - profile.rankXp) / span)
		xpLabel.Text = string.format("%d / %d XP  ·  next: %s", profile.xp, profile.nextRankXp, profile.nextRankName)
	else
		setXp(1)
		xpLabel.Text = string.format("%d XP  ·  top rank", profile.xp)
	end
	saveWarning.Visible = profile.persistent == false
end

local function updateLobby()
	local lobby = ClientState.lobby
	panel.Visible = not ClientState.isParticipant()
	if not lobby then
		statusLabel.Text = "Connecting..."
		return
	end
	local status
	if lobby.searching then
		status = "Searching other servers for players..."
	elseif lobby.countdown then
		status = string.format("Match starts in %d seconds.", lobby.countdown)
	elseif lobby.matchRunning then
		status = "A match is running. Ready up for the next one, or spectate."
	else
		status = string.format("%d of %d players ready.", lobby.readyCount, lobby.needed)
	end
	statusLabel.Text = status
	if lobby.ready then
		readyButton.Text = "CANCEL READY"
		readyButton.BackgroundColor3 = Theme.colors.button
	else
		readyButton.Text = "READY"
		readyButton.BackgroundColor3 = Theme.colors.accent
	end
end

function LobbyPanel.init()
	panel = Widgets.panel({
		Name = "LobbyPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Widgets.padding(panel, Theme.space.lg)
	Widgets.list(panel, Theme.space.sm)
	Widgets.label({
		Font = Theme.fonts.gothic,
		TextSize = 40,
		Text = Terms.GAME,
		Size = UDim2.new(1, 0, 0, 42),
		LayoutOrder = 1,
		Parent = panel,
	})
	Widgets.label({
		Font = Theme.fonts.typewriter,
		TextColor3 = Theme.colors.gold,
		TextSize = Theme.text.small,
		Text = Terms.TAGLINE,
		LayoutOrder = 2,
		Parent = panel,
	})
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.stroke,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 3,
		Parent = panel,
	})
	Widgets.label({
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.muted,
		TextSize = Theme.text.small,
		Text = Players.LocalPlayer.DisplayName,
		LayoutOrder = 4,
		Parent = panel,
	})
	rankLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.gold,
		TextSize = Theme.text.bodyLarge,
		LayoutOrder = 5,
		Parent = panel,
	})
	local bar
	bar, setXp = Widgets.progressBar({ LayoutOrder = 6, Parent = panel })
	bar.Name = "XpBar"
	xpLabel = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		LayoutOrder = 7,
		Parent = panel,
	})
	coinsLabel = Widgets.label({
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.text,
		LayoutOrder = 8,
		Parent = panel,
	})
	statusLabel = Widgets.label({
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 9,
		Parent = panel,
	})
	readyButton = Widgets.button({
		Text = "READY",
		TextSize = 22,
		Font = Theme.fonts.black,
		Variant = "primary",
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = 10,
		Parent = panel,
	}, function()
		local lobby = ClientState.lobby
		ReadyRemote:FireServer(not (lobby and lobby.ready))
	end)
	local menu = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 88),
		LayoutOrder = 11,
		Parent = panel,
	})
	Widgets.grid(menu, UDim2.new(0.5, -4, 0, 40), Theme.space.sm)
	for index, item in ipairs({
		{ text = "HOW TO PLAY", screen = "howToPlay" },
		{ text = "SHOP", screen = "shop" },
		{ text = "PARTY", screen = "party" },
		{ text = "SETTINGS", screen = "settings" },
	}) do
		Widgets.button({
			Text = item.text,
			TextSize = Theme.text.small,
			Variant = "ghost",
			LayoutOrder = index,
			Parent = menu,
		}, function()
			Router.toggle(item.screen)
		end)
	end
	saveWarning = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.bad,
		Text = "Progress is not being saved in this session.",
		Visible = false,
		LayoutOrder = 12,
		Parent = panel,
	})

	ClientState.ProfileChanged:Connect(updateProfile)
	ClientState.LobbyChanged:Connect(updateLobby)
	ClientState.PublicChanged:Connect(updateLobby)
	updateProfile()
	updateLobby()
end

-- The READY button, for gamepad selection.
function LobbyPanel.readyButton(): TextButton
	return readyButton
end

return LobbyPanel
