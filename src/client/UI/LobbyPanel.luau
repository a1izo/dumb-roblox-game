-- The lobby menu, "angular manga" style: the INKBOUND title, a staircase of slanted menu
-- buttons (a huge red READY on top), the queue status, and the player's profile on a tilted
-- paper card in the bottom right. Shown to everyone not playing in the current match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Core.Motion)
local DirectorPanel = require(script.Parent.DirectorPanel)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors

local ReadyRemote = Net.event("Ready")

local LobbyPanel = {}

local menu: Frame
local profileCard: Frame
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
		rankLabel.Text = "LOADING PROFILE..."
		return
	end
	rankLabel.Text = string.upper(profile.rankName)
	local function coinsText(value: number): string
		return string.format("%d COINS", math.floor(value + 0.5))
	end
	if lastCoins and lastCoins ~= profile.coins then
		Motion.countUp(coinsLabel, lastCoins, profile.coins, 0.6, coinsText)
	else
		coinsLabel.Text = coinsText(profile.coins)
	end
	lastCoins = profile.coins
	if profile.nextRankXp then
		local span = math.max(1, profile.nextRankXp - profile.rankXp)
		setXp((profile.xp - profile.rankXp) / span)
		xpLabel.Text = string.format(
			"%d / %d XP  ·  NEXT: %s",
			profile.xp,
			profile.nextRankXp,
			string.upper(profile.nextRankName)
		)
	else
		setXp(1)
		xpLabel.Text = string.format("%d XP  ·  TOP RANK", profile.xp)
	end
	saveWarning.Visible = profile.persistent == false
end

local function updateLobby()
	local lobby = ClientState.lobby
	local visible = not ClientState.isParticipant()
	menu.Visible = visible
	profileCard.Visible = visible
	if not lobby then
		statusLabel.Text = "CONNECTING..."
		return
	end
	local status
	if lobby.searching then
		status = "SEARCHING OTHER SERVERS FOR PLAYERS..."
	elseif lobby.countdown then
		status = string.format("MATCH STARTS IN %d", lobby.countdown)
	elseif lobby.matchRunning then
		status = "A MATCH IS RUNNING  ·  READY UP FOR THE NEXT ONE"
	else
		status = string.format("%d OF %d PLAYERS READY", lobby.readyCount, lobby.needed)
	end
	statusLabel.Text = status
	if lobby.ready then
		readyButton.Text = "CANCEL READY"
		readyButton.BackgroundColor3 = C.paper
		readyButton.TextColor3 = C.ink
	else
		readyButton.Text = "READY"
		readyButton.BackgroundColor3 = C.accent
		readyButton.TextColor3 = C.paper
	end
end

local function buildMenu()
	menu = Widgets.frame({
		Name = "LobbyMenu",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -28),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Widgets.list(menu, Theme.space.sm)
	Widgets.display({
		Text = string.upper(Terms.GAME),
		TextSize = 72,
		Size = UDim2.new(1, 0, 0, 78),
		LayoutOrder = 1,
		Parent = menu,
	})
	local tagline = Widgets.ribbon({ LayoutOrder = 2, Parent = menu }, Terms.TAGLINE)
	tagline.Size = UDim2.fromOffset(0, 28)
	local taglineLabel = tagline:FindFirstChildOfClass("TextLabel")
	if taglineLabel then
		taglineLabel.TextSize = Theme.text.body
	end
	Widgets.frame({ Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3, Parent = menu })

	readyButton = Widgets.button({
		Text = "READY",
		TextSize = 40,
		Variant = "primary",
		Size = UDim2.fromOffset(340, 70),
		LayoutOrder = 4,
		Parent = menu,
	}, function()
		local lobby = ClientState.lobby
		ReadyRemote:FireServer(not (lobby and lobby.ready))
	end)
	statusLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.body,
		TextColor3 = C.muted,
		Position = UDim2.fromOffset(8, 0),
		LayoutOrder = 5,
		Parent = menu,
	})
	-- A staircase: every item sits a little further right than the one above.
	for index, item in ipairs({
		{ text = "How to play", screen = "howToPlay" },
		{ text = "Shop", screen = "shop" },
		{ text = "Party", screen = "party" },
		{ text = "Settings", screen = "settings" },
		{ text = "Private server", screen = "director" },
	}) do
		local holder = Widgets.frame({ Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 5 + index, Parent = menu })
		if item.screen == "director" then
			-- Only in private servers.
			holder.Visible = DirectorPanel.state.vip
			DirectorPanel.Changed:Connect(function(state)
				holder.Visible = state.vip
			end)
		end
		Widgets.button({
			Text = item.text,
			TextSize = 26,
			Position = UDim2.fromOffset(index * 14, 0),
			Size = UDim2.fromOffset(280, 46),
			Parent = holder,
		}, function()
			Router.toggle(item.screen)
		end)
	end
end

local function buildProfile()
	profileCard = Widgets.card({
		Name = "ProfileCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -28),
		Rotation = -2,
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Widgets.padding(profileCard, Theme.space.md, Theme.space.lg)
	Widgets.list(profileCard, Theme.space.xs)
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Size = UDim2.fromOffset(36, 4),
		LayoutOrder = 1,
		Parent = profileCard,
	})
	Widgets.display({
		Text = string.upper(Players.LocalPlayer.DisplayName),
		TextColor3 = C.ink,
		TextSize = Theme.text.title,
		LayoutOrder = 2,
		Parent = profileCard,
	})
	rankLabel = Widgets.label({
		FontFace = Theme.faces.display,
		TextColor3 = C.accent,
		TextSize = Theme.text.bodyLarge,
		LayoutOrder = 3,
		Parent = profileCard,
	})
	local bar
	bar, setXp = Widgets.progressBar({ BackgroundColor3 = C.paperDark, LayoutOrder = 4, Parent = profileCard })
	bar.Name = "XpBar"
	xpLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.caption,
		TextColor3 = C.inkMuted,
		LayoutOrder = 5,
		Parent = profileCard,
	})
	coinsLabel = Widgets.display({
		TextColor3 = C.ink,
		TextSize = Theme.text.bodyLarge,
		LayoutOrder = 6,
		Parent = profileCard,
	})
	saveWarning = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = C.accent,
		Text = "Progress is not being saved in this session.",
		Visible = false,
		LayoutOrder = 7,
		Parent = profileCard,
	})
end

function LobbyPanel.init()
	buildMenu()
	buildProfile()
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
