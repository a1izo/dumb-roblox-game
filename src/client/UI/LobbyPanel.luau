-- The lobby, drawn as the first page of the Grimoire: the INKBOUND wordmark and tagline, a red
-- READY stamp with the queue status under it, a handwritten table of contents (I. Quests,
-- II. Shop...) and, on the right, your card: rank seal, XP, coins, and the way to your
-- profile and the leaderboards. How to Play lives in Settings (and on H). Shown to everyone
-- not playing in the current match. The HUD's phase banner is hidden here, so the queue
-- status lives on this page.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local DirectorPanel = require(script.Parent.DirectorPanel)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local ReadyRemote = Net.event("Ready")

local LobbyPanel = {}

local NUMERALS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" }

local MENU = {
	{ text = "Quests", screen = "quests" },
	{ text = "Shop", screen = "shop" },
	{ text = "Party", screen = "party" },
	{ text = "Settings", screen = "settings" },
	{ text = "Private server", screen = "director" },
}

local menu: Frame
local wordmark: any
local tagline: any
local contents: Frame
local profileCard: Frame
local rankSeal: Frame
local rankText: any
local setXp: (number, boolean?) -> ()
local xpLabel: TextLabel
local coinsLabel: TextLabel
local statusLabel: TextLabel
local readyHolder: Frame
local readyButton: TextButton
local saveWarning: TextLabel
local links: Frame
local linksLayout: UIListLayout
local profileButton: TextButton
local boardsButton: TextButton
local lastCoins: number? = nil
local lastReady: boolean? = nil
local lastRank = ""

local function updateProfile()
	local profile = ClientState.profile
	if not profile then
		rankText:set("…")
		return
	end
	if profile.rankName ~= lastRank then
		lastRank = profile.rankName
		rankText:set(profile.rankName)
		Kit.clear(rankSeal)
		Kit.seal({ size = 64, color = C.blood, text = string.sub(profile.rankName, 1, 1), Parent = rankSeal })
	end
	local function coinsText(value: number): string
		return string.format("%d coins", math.floor(value + 0.5))
	end
	if lastCoins and lastCoins ~= profile.coins then
		Motion.countUp(coinsLabel, lastCoins, profile.coins, 0.6, coinsText)
	else
		coinsLabel.Text = coinsText(profile.coins)
	end
	lastCoins = profile.coins
	if profile.nextRankXp then
		local span = math.max(1, profile.nextRankXp - profile.rankXp)
		setXp((profile.xp - profile.rankXp) / span, true)
		xpLabel.Text = string.format("%d / %d XP  ·  next: %s", profile.xp, profile.nextRankXp, profile.nextRankName)
	else
		setXp(1, true)
		xpLabel.Text = string.format("%d XP  ·  the highest rank", profile.xp)
	end
	saveWarning.Visible = profile.persistent == false
end

local function onReady()
	local lobby = ClientState.lobby
	ReadyRemote:FireServer(not (lobby and lobby.ready))
end

local function buildReady(ready: boolean)
	if readyButton then
		readyButton:Destroy()
	end
	readyButton = Kit.button({
		text = if ready then "Cancel ready" else "Ready",
		icon = if ready then "cross" else "play",
		variant = if ready then "secondary" else "primary",
		size = "l",
		Size = UDim2.fromOffset(if Kit.Layout.isPhone() then 260 else 320, 60),
		Parent = readyHolder,
	}, onReady)
end

local function updateLobby()
	local lobby = ClientState.lobby
	local visible = not ClientState.isParticipant()
	menu.Visible = visible
	profileCard.Visible = visible
	if not lobby then
		statusLabel.Text = "Connecting…"
		return
	end
	local status
	if lobby.searching then
		status = "Searching other servers for players…"
	elseif lobby.countdown then
		status = string.format("The case opens in %d…", lobby.countdown)
	elseif lobby.matchRunning then
		status = "A match is running. Ready up for the next one."
	else
		status = string.format(
			"%d of %d ready  ·  next case: %s",
			lobby.readyCount,
			lobby.needed,
			tostring(lobby.nextMap or "?")
		)
	end
	statusLabel.Text = status
	statusLabel.TextColor3 = if lobby.countdown then C.red else C.dim
	local ready = lobby.ready == true
	if ready ~= lastReady then
		lastReady = ready
		buildReady(ready)
	end
end

local function buildContents(phone: boolean)
	contents:ClearAllChildren()
	if phone then
		Kit.grid(contents, UDim2.fromOffset(190, 44), T.space.xs)
	else
		Kit.list(contents, 0)
	end
	local shown = 0
	for _, item in ipairs(MENU) do
		local vip = item.screen ~= "director" or DirectorPanel.state.vip
		if vip then
			shown += 1
		end
		local entry = Kit.entry({
			text = item.text,
			numeral = NUMERALS[shown],
			size = if phone then 26 else 32,
			seed = shown,
			Size = if phone then nil else UDim2.new(1, 0, 0, 44),
			LayoutOrder = shown,
			Visible = vip,
			Parent = contents,
		}, function()
			Router.toggle(item.screen)
		end)
		local _ = entry
	end
end

local function buildMenu()
	menu = Kit.frame({
		Name = "LobbyMenu",
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Kit.list(menu, T.space.s)
	-- A dark wash behind the menu, so the world never fights the text.
	local wash = Kit.Base.make("Frame", {
		Name = "Wash",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.5, 0, 1, 0),
		ZIndex = 0,
		Parent = Screens.hud,
	})
	Kit.Base.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = wash,
	})
	menu:GetPropertyChangedSignal("Visible"):Connect(function()
		wash.Visible = menu.Visible
	end)
	wordmark = Kit.text({
		face = "Gothic",
		text = Terms.GAME,
		size = T.size.hero + 12,
		color = C.bone,
		LayoutOrder = 1,
		Parent = menu,
	})
	tagline = Kit.text({
		face = "Scrawl",
		text = Terms.TAGLINE,
		size = 30,
		color = C.red,
		maxWidth = 440,
		LayoutOrder = 2,
		Parent = menu,
	})
	Kit.frame({ Name = "Gap", Size = UDim2.new(1, 0, 0, T.space.m), LayoutOrder = 3, Parent = menu })
	readyHolder = Kit.frame({ Name = "Ready", Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 4, Parent = menu })
	statusLabel = Kit.label({
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		LayoutOrder = 5,
		Parent = menu,
	})
	Kit.rule({ color = C.red, transparency = 0.4, thickness = 2, LayoutOrder = 6, Parent = menu })
	contents = Kit.frame({
		Name = "Contents",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 7,
		Parent = menu,
	})
	DirectorPanel.Changed:Connect(function()
		buildContents(Kit.Layout.isPhone())
	end)
end

local function buildProfile()
	local page, content = Kit.page({
		Name = "ProfileCard",
		tone = "raised",
		padding = T.space.l,
		autoHeight = true,
		Size = UDim2.fromOffset(320, 0),
		Parent = Screens.hud,
	})
	profileCard = page
	Kit.list(content, T.space.xs)
	local top = Kit.frame({ Name = "Top", Size = UDim2.new(1, 0, 0, 68), LayoutOrder = 1, Parent = content })
	rankSeal = Kit.frame({ Name = "RankSeal", Size = UDim2.fromOffset(64, 64), Parent = top })
	Kit.label({
		Text = Players.LocalPlayer.DisplayName,
		font = "bodyBold",
		size = "lead",
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(78, 4),
		Size = UDim2.new(1, -78, 0, 26),
		Parent = top,
	})
	rankText = Kit.text({
		face = "Gothic",
		text = "",
		size = T.size.title,
		color = C.red,
		Position = UDim2.fromOffset(76, 32),
		Parent = top,
	})
	local _bar
	_bar, setXp = Kit.meter({ color = C.red, height = 5, LayoutOrder = 2, Parent = content })
	xpLabel = Kit.label({ font = "mono", size = "micro", color = C.dim, LayoutOrder = 3, Parent = content })
	local coinsRow = Kit.frame({ Name = "Coins", Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 4, Parent = content })
	Kit.list(coinsRow, T.space.s, true)
	Kit.icon({ name = "coin", size = 22, color = C.candle, LayoutOrder = 1, Parent = coinsRow })
	coinsLabel = Kit.label({
		font = "bodyBold",
		size = "body",
		color = C.candle,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = coinsRow,
	})
	saveWarning = Kit.label({
		Text = "Progress is not being saved in this session.",
		size = "micro",
		color = C.red,
		Visible = false,
		LayoutOrder = 5,
		Parent = content,
	})
	-- Your profile and the leaderboards open from the card: side by side, or stacked on phones.
	links = Kit.frame({ Name = "Links", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 6, Parent = content })
	linksLayout = Kit.list(links, T.space.s, true)
	linksLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	profileButton = Kit.button({
		text = "Profile",
		variant = "secondary",
		size = "s",
		Size = UDim2.new(0.5, -T.space.xs, 0, 40),
		LayoutOrder = 1,
		Parent = links,
	}, function()
		Router.toggle("profile")
	end)
	boardsButton = Kit.button({
		text = "Leaderboards",
		variant = "secondary",
		size = "s",
		Size = UDim2.new(0.5, -T.space.xs, 0, 40),
		LayoutOrder = 2,
		Parent = links,
	}, function()
		Router.toggle("leaderboards")
	end)
end

local function layout(class: string)
	local phone = class == "phone"
	wordmark:setSize(if phone then T.size.display + 8 else T.size.hero + 12)
	tagline:setSize(if phone then 24 else 30)
	if phone then
		menu.AnchorPoint = Vector2.new(0, 0)
		menu.Position = UDim2.fromOffset(T.space.l, T.space.s)
		menu.Size = UDim2.fromOffset(400, 0)
		profileCard.AnchorPoint = Vector2.new(1, 0)
		profileCard.Position = UDim2.new(1, -T.space.l, 0, T.space.s)
		profileCard.Size = UDim2.fromOffset(260, 0)
	else
		Kit.Layout.place(menu, "bottomLeft", Vector2.new(T.space.l, -T.space.l))
		menu.Size = UDim2.fromOffset(460, 0)
		Kit.Layout.place(profileCard, "bottomRight", Vector2.new(-T.space.l, -T.space.l))
		profileCard.Size = UDim2.fromOffset(340, 0)
	end
	linksLayout.FillDirection = if phone then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	links.Size = UDim2.new(1, 0, 0, if phone then 40 * 2 + T.space.s + T.space.xs else 48)
	local buttonSize = if phone then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -T.space.xs, 0, 40)
	profileButton.Size = buttonSize
	boardsButton.Size = buttonSize
	buildContents(phone)
	lastReady = nil
	updateLobby()
end

function LobbyPanel.init()
	buildMenu()
	buildProfile()
	ClientState.ProfileChanged:Connect(updateProfile)
	ClientState.LobbyChanged:Connect(updateLobby)
	ClientState.PublicChanged:Connect(updateLobby)
	Kit.Layout.watch(layout)
	updateProfile()
	updateLobby()
end

-- The READY button, for gamepad selection.
function LobbyPanel.readyButton(): TextButton
	return readyButton
end

return LobbyPanel
