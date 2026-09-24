-- Lobby panel: rank, experience, coins, the READY button, shop and party.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local PartyPanel = require(script.Parent.PartyPanel)
local Screens = require(script.Parent.Screens)
local ShopPanel = require(script.Parent.ShopPanel)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ReadyRemote = Net.event("Ready")

local LobbyPanel = {}

local panel: Frame
local rankLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel
local coinsLabel: TextLabel
local statusLabel: TextLabel
local readyButton: TextButton
local saveWarning: TextLabel

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		rankLabel.Text = "Loading profile..."
		return
	end
	rankLabel.Text = string.upper(profile.rankName)
	coinsLabel.Text = string.format("Coins: %d", profile.coins)
	if profile.nextRankXp then
		local span = math.max(1, profile.nextRankXp - profile.rankXp)
		local progress = math.clamp((profile.xp - profile.rankXp) / span, 0, 1)
		xpFill.Size = UDim2.fromScale(progress, 1)
		xpLabel.Text = string.format("%d / %d XP  (next: %s)", profile.xp, profile.nextRankXp, profile.nextRankName)
	else
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = string.format("%d XP  (top rank)", profile.xp)
	end
	saveWarning.Visible = profile.persistent == false
end

local function updateLobby()
	local lobby = ClientState.lobby
	-- Match players (alive or dead) see the match UI; the lobby panel returns after the reveal.
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
		Size = UDim2.fromOffset(290, 392),
		Parent = Screens.hud,
	})
	Widgets.padding(panel, 14)
	Widgets.list(panel, 8)
	Widgets.label({
		Font = Theme.fonts.gothic,
		TextSize = 34,
		Text = Terms.GAME,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 1,
		Parent = panel,
	})
	Widgets.label({
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.muted,
		TextSize = 14,
		Text = Players.LocalPlayer.DisplayName,
		LayoutOrder = 2,
		Parent = panel,
	})
	rankLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextColor3 = Theme.colors.gold,
		TextSize = 18,
		LayoutOrder = 3,
		Parent = panel,
	})
	local bar = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.panelLight,
		Size = UDim2.new(1, 0, 0, 10),
		LayoutOrder = 4,
		Parent = panel,
	})
	Widgets.corner(bar, 5)
	xpFill = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.gold,
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	})
	Widgets.corner(xpFill, 5)
	xpLabel = Widgets.label({
		TextSize = 13,
		TextColor3 = Theme.colors.muted,
		LayoutOrder = 5,
		Parent = panel,
	})
	coinsLabel = Widgets.label({
		Font = Theme.fonts.bold,
		LayoutOrder = 6,
		Parent = panel,
	})
	statusLabel = Widgets.label({
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 7,
		Parent = panel,
	})
	readyButton = Widgets.button({
		Text = "READY",
		TextSize = 20,
		Font = Theme.fonts.black,
		BackgroundColor3 = Theme.colors.accent,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 8,
		Parent = panel,
	}, function()
		local lobby = ClientState.lobby
		ReadyRemote:FireServer(not (lobby and lobby.ready))
	end)
	local row = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 9,
		Parent = panel,
	})
	Widgets.button({
		Text = "SHOP",
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = row,
	}, ShopPanel.toggle)
	Widgets.button({
		Text = "PARTY",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = row,
	}, PartyPanel.toggle)
	saveWarning = Widgets.label({
		TextSize = 12,
		TextColor3 = Theme.colors.bad,
		Text = "Progress is not being saved in this session.",
		Visible = false,
		LayoutOrder = 10,
		Parent = panel,
	})

	ClientState.ProfileChanged:Connect(updateProfile)
	ClientState.LobbyChanged:Connect(updateLobby)
	ClientState.PublicChanged:Connect(updateLobby)
	updateProfile()
	updateLobby()
end

return LobbyPanel
