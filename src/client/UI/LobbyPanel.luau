-- The lobby, the loud side of the design. At the top centre, the Death's Gambit ransom-note title with the
-- quote under it ("Diavolo" in red Aktura, the only word of it that glitches; the rest floats very gently).
-- On the left, from a quarter of the way down: the READY button, a quieter SPECTATE button while a case is
-- running, the queue status, and the menu (Quests, Shop...) in a zigzag, each entry floating on its own beat.
-- On the right, your card: rank seal, XP, coins, and the way to your profile and the leaderboards.
--
-- The title, READY, the menu and the profile buttons blip every couple of seconds; hovered buttons glitch
-- hard (Core/HoverGlitch). The lobby comes in from black (UI/LobbyIntro) on joining and on coming back from a
-- case, then plays its entrance: the title cards fall in, everything else glitches in over 1.5 s. The VHS
-- look belongs to the lobby only, so this page turns Glitch off while you are in a case or watching one.
-- How to Play lives in Settings (and on H). The HUD's phase banner is hidden here, so the queue status
-- lives on this page.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local DirectorPanel = require(script.Parent.DirectorPanel)
local Glitch = require(script.Parent.Core.Glitch)
local Kit = require(script.Parent.Kit)
local LobbyIntro = require(script.Parent.LobbyIntro)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local ReadyRemote = Net.event("Ready")
local WatchRemote = Net.event("Watch")

local LobbyPanel = {}

local MENU = {
	{ text = "Quests", screen = "quests" },
	{ text = "Shop", screen = "shop" },
	{ text = "Party", screen = "party" },
	{ text = "Settings", screen = "settings" },
	{ text = "Private server", screen = "director" },
}

-- The zigzag: every other menu entry is pushed this far right.
local ZIGZAG = { pc = 40, phone = 20 }
-- Where the left column starts, down from the top of the screen.
local COLUMN_TOP = { pc = 0.25, phone = 0.18 }
local DIAVOLO = "Diavolo"
-- Where the title's letters come to rest, from the top of the screen (level with Roblox's buttons).
local TITLE_TOP = 6

local menu: Frame
local titleBlock: Frame
local wordmark: any
local wordmarkHolder: CanvasGroup
local quoteGroup: CanvasGroup
local quoteFloat: Frame
local quoteGlitch: any
local diavoloGlitch: any
local contents: Frame
local menuRows: { { wrap: CanvasGroup, glitch: any } } = {}
local profileGroup: CanvasGroup
local profileGlitch: any
local rankSeal: Frame
local rankText: any
local setXp: (number, boolean?) -> ()
local xpLabel: TextLabel
local coinsLabel: TextLabel
local statusGroup: CanvasGroup
local statusGlitch: any
local statusLabel: TextLabel
local readyHolder: CanvasGroup
local readyGlitch: any
local readyButton: TextButton
local spectateButton: TextButton
local saveWarning: TextLabel
local links: Frame
local linksLayout: UIListLayout
local linkWraps: { CanvasGroup } = {}
local lastCoins: number? = nil
local lastReady: boolean? = nil
local lastRank = ""
-- The lobby stays hidden behind the intro's black until its entrance plays.
local introHidden = true
local lastVisible: boolean? = nil
local returning = false

local columnShare = COLUMN_TOP.pc
-- Two invisible probes: one filling the full-screen layer, one at the corner of the HUD layer (which starts
-- under Roblox's top bar). Between them they say how tall the screen is and where the HUD layer begins.
local screenProbe: Frame
local hudProbe: Frame

-- The column starts `columnShare` of the way down the whole screen.
local function placeColumn()
	if not menu or not screenProbe or not hudProbe then
		return
	end
	local inset = hudProbe.AbsolutePosition.Y - screenProbe.AbsolutePosition.Y
	local top = columnShare * screenProbe.AbsoluteSize.Y - inset
	menu.AnchorPoint = Vector2.new(0, 0)
	menu.Position = UDim2.fromOffset(T.space.l, math.floor(top / Kit.Base.scaleOf(menu)))
end

local function lobbyView(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

local function applyVisibility()
	local shown = lobbyView() and not introHidden
	menu.Visible = shown
	profileGroup.Visible = shown
	titleBlock.Visible = shown
end

-- A transparent CanvasGroup the glitch can blink; marked so a hovered button inside glitches through it.
local function wrapper(props: { [string]: any }): CanvasGroup
	local group = Kit.Base.make("CanvasGroup", {
		Name = props.Name or "Wrap",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}) :: CanvasGroup
	group:SetAttribute("GlitchWrap", true)
	return group
end

-- A list places its items itself, so a glitch could not shake one sideways. A glitching element in a list
-- therefore sits in a slot of its own size: the list places the slot, the glitch shakes what is inside it.
local function slot(group: GuiObject, order: number, parent: Instance)
	local holder = Kit.frame({ Name = group.Name .. "Slot", Size = group.Size, LayoutOrder = order, Parent = parent })
	group.Position = UDim2.new()
	group.Parent = holder
	group:GetPropertyChangedSignal("Size"):Connect(function()
		holder.Size = group.Size
	end)
end

-- A very slight, endless up-and-down drift (nothing under reduced motion).
local function float(gui: GuiObject, amplitude: number, seconds: number, delay: number)
	if Motion.isReduced() then
		return
	end
	local base = gui.Position
	gui.Position = base + UDim2.fromOffset(0, -amplitude)
	task.delay(delay, function()
		if gui.Parent then
			TweenService:Create(
				gui,
				TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = base + UDim2.fromOffset(0, amplitude) }
			):Play()
		end
	end)
end

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
		Kit.seal({ size = 64, color = C.white, text = string.sub(profile.rankName, 1, 1), Parent = rankSeal })
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
		Size = UDim2.fromOffset(if Kit.Layout.isPhone() then 260 else 320, if Kit.Layout.isPhone() then 48 else 60),
		Parent = readyHolder,
	}, onReady)
end

-- SPECTATE: only while a case is running, and not while you are queued for the next one.
local function updateSpectate(lobby)
	local running = ClientState.public.active == true and lobby ~= nil and lobby.matchRunning == true
	spectateButton.Visible = running
	if running then
		local queued = lobby.ready == true
		Kit.setText(spectateButton, if queued then "Unready to watch" else "Spectate  ·  case in progress")
		Kit.setEnabled(spectateButton, not queued)
	end
end

-- The lobby's entrance, once the intro's black has gone: the title cards fall in, in line, and everything
-- else glitches in over about 1.5 s, a little apart.
function LobbyPanel.playEntrance()
	introHidden = false
	applyVisibility()
	if not menu.Visible then
		return
	end
	if wordmark then
		wordmark:play()
	end
	local order: { { any } } = {
		{ quoteGroup, quoteGlitch },
		{ readyHolder, readyGlitch },
		{ statusGroup, statusGlitch },
	}
	for _, row in ipairs(menuRows) do
		table.insert(order, { row.wrap, row.glitch })
	end
	table.insert(order, { profileGroup, profileGlitch })
	for index, item in ipairs(order) do
		local group, glitch = item[1], item[2]
		-- Hidden until its turn; if glitching is off (reduced motion) it simply appears then.
		group.GroupTransparency = 1
		task.delay(0.35 + (index - 1) * 0.07, function()
			group.GroupTransparency = 0
			glitch:enter(true)
		end)
	end
end

-- Coming back from a case (or from watching one): the lobby waits behind black until the results are
-- closed, then comes in through the intro.
local function returnToLobby()
	if returning then
		return
	end
	returning = true
	introHidden = true
	applyVisibility()
	task.spawn(function()
		while Router.isBlocking() do
			task.wait(0.2)
		end
		returning = false
		if lobbyView() then
			LobbyIntro.play(LobbyPanel.playEntrance)
		else
			introHidden = false
			applyVisibility()
		end
	end)
end

local function updateLobby()
	local lobby = ClientState.lobby
	local visible = lobbyView()
	-- The VHS look belongs to the lobby: in a case (or watching one) nothing glitches.
	Glitch.setEnabled(visible)
	if visible and lastVisible == false then
		returnToLobby()
	end
	lastVisible = visible
	applyVisibility()
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
		status = "A case is running. Watch it, or ready up for the next one."
	else
		status = string.format(
			"%d of %d ready  ·  next case: %s",
			lobby.readyCount,
			lobby.needed,
			tostring(lobby.nextMap or "?")
		)
	end
	statusLabel.Text = status
	statusLabel.TextColor3 = if lobby.countdown then C.white else C.dim
	updateSpectate(lobby)
	local ready = lobby.ready == true
	if ready ~= lastReady then
		lastReady = ready
		buildReady(ready)
	end
end

-- The menu: one row per entry, every other one pushed right (the zigzag). Each entry sits in a floating
-- frame, inside a wrapper the glitch blinks.
local function buildContents(phone: boolean)
	for _, row in ipairs(menuRows) do
		row.glitch:destroy()
	end
	table.clear(menuRows)
	contents:ClearAllChildren()
	Kit.list(contents, 0)
	local rowHeight = 44
	local shown = 0
	for _, item in ipairs(MENU) do
		local vip = item.screen ~= "director" or DirectorPanel.state.vip
		if not vip then
			continue
		end
		shown += 1
		local indent = if shown % 2 == 0 then (if phone then ZIGZAG.phone else ZIGZAG.pc) else 0
		local row = Kit.frame({
			Name = item.text,
			Size = UDim2.new(1, 0, 0, rowHeight),
			LayoutOrder = shown,
			Parent = contents,
		})
		local drift = Kit.frame({
			Name = "Float",
			Position = UDim2.fromOffset(indent, 0),
			Size = UDim2.new(1, -indent, 1, 0),
			Parent = row,
		})
		local wrap = wrapper({ Name = "Wrap", Size = UDim2.new(0, if phone then 240 else 300, 1, 0), Parent = drift })
		Kit.entry({
			text = item.text,
			size = if phone then 26 else 32,
			seed = shown,
			Size = UDim2.fromScale(1, 1),
			Parent = wrap,
		}, function()
			Router.toggle(item.screen)
		end)
		table.insert(
			menuRows,
			{ wrap = wrap, glitch = Glitch.attach(wrap, { loop = true, enter = false, band = false }) }
		)
		float(drift, 2, 2.6 + (shown % 3) * 0.45, shown * 0.55)
	end
end

-- The quote: the lead words, "Diavolo" in red Aktura (in its own glitching wrapper) and the rest, set on
-- one baseline. The whole line floats very gently; only "Diavolo" glitches.
local function buildQuote(phone: boolean)
	if diavoloGlitch then
		diavoloGlitch:destroy()
		diavoloGlitch = nil
	end
	Kit.clear(quoteFloat)
	local tagline = Terms.TAGLINE
	local at = string.find(tagline, DIAVOLO, 1, true)
	local leadText = if at then string.gsub(string.sub(tagline, 1, at - 1), "%s+$", "") else tagline
	local tailText = if at then string.gsub(string.sub(tagline, at + #DIAVOLO), "^%s+", "") else ""
	local size = if phone then 16 else 22
	local wordSize = if phone then 22 else 30
	local lead = Kit.text({ face = "Semi", text = leadText, size = size, color = C.bone, Parent = quoteFloat })
	local word: any = nil
	local wordHolder: CanvasGroup? = nil
	if at then
		local holder = Kit.Base.make("CanvasGroup", {
			Name = "Diavolo",
			BackgroundTransparency = 1,
			Parent = quoteFloat,
		}) :: CanvasGroup
		word = Kit.text({ face = "Title", text = DIAVOLO, size = wordSize, color = C.danger, Parent = holder })
		wordHolder = holder
	end
	local tail = Kit.text({ face = "Semi", text = tailText, size = size, color = C.bone, Parent = quoteFloat })
	local semi = Kit.GlyphText.face("Semi")
	local title = Kit.GlyphText.face("Title")
	local function place()
		local gap = size * 0.3
		local semiAscent = semi.ascent * size / semi.em
		local titleAscent = if word then title.ascent * wordSize / title.em else 0
		local baseline = math.max(semiAscent, titleAscent)
		local x = 0
		lead.frame.Position = UDim2.fromOffset(x, baseline - semiAscent)
		x += lead.width
		local height = baseline - semiAscent + lead.height
		if word and wordHolder then
			x += gap
			wordHolder.Size = UDim2.fromOffset(math.ceil(word.width), math.ceil(word.height))
			wordHolder.Position = UDim2.fromOffset(x, baseline - titleAscent)
			x += word.width
			height = math.max(height, baseline - titleAscent + word.height)
		end
		if tailText ~= "" then
			x += gap
		end
		tail.frame.Position = UDim2.fromOffset(x, baseline - semiAscent)
		x += tail.width
		-- Room above and below for the float.
		quoteGroup.Size = UDim2.fromOffset(math.ceil(x), math.ceil(height) + 8)
	end
	lead.Changed:Connect(place)
	tail.Changed:Connect(place)
	if word then
		word.Changed:Connect(place)
	end
	place()
	if wordHolder then
		diavoloGlitch = Glitch.attach(wordHolder, { loop = true, enter = false, band = false })
	end
end

local function buildTitle()
	-- The title block sits in the full-screen layer so it can rise level with Roblox's own buttons.
	titleBlock = Kit.frame({
		Name = "LobbyTitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TITLE_TOP),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 10,
		Visible = false,
		Parent = Screens.world,
	})
	Kit.list(titleBlock, T.space.xs, false, Enum.HorizontalAlignment.Center)
	-- The ransom letters are built into this by layout() (they are cut at a size per device).
	wordmarkHolder = Kit.Base.make("CanvasGroup", {
		Name = "Wordmark",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = titleBlock,
	}) :: CanvasGroup
	slot(wordmarkHolder, 1, titleBlock)
	Glitch.attach(wordmarkHolder, { loop = true, enter = false })
	quoteGroup = Kit.Base.make("CanvasGroup", {
		Name = "Quote",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = titleBlock,
	}) :: CanvasGroup
	slot(quoteGroup, 2, titleBlock)
	quoteFloat = Kit.frame({ Name = "Float", Position = UDim2.fromOffset(0, 4), Parent = quoteGroup })
	-- The rest of the quote never glitches; this handle only plays its entrance.
	quoteGlitch = Glitch.attach(quoteGroup, { loop = false, enter = false })
	float(quoteFloat, 2, 2.4, 0)
end

local function buildMenu()
	menu = Kit.frame({
		Name = "LobbyMenu",
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.hud,
	})
	Kit.list(menu, T.space.s)
	readyHolder = wrapper({ Name = "Ready", Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 1, Parent = menu })
	slot(readyHolder, 1, menu)
	readyGlitch = Glitch.attach(readyHolder, { loop = true, enter = false })
	spectateButton = Kit.button({
		text = "Spectate  ·  case in progress",
		icon = "eye",
		variant = "secondary",
		size = "s",
		Size = UDim2.fromOffset(320, 48),
		Visible = false,
		LayoutOrder = 2,
		Parent = menu,
	}, function()
		WatchRemote:FireServer({ action = "watch" })
	end)
	-- The status line and the rule under it glitch in together.
	statusGroup = wrapper({ Name = "Status", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3, Parent = menu })
	slot(statusGroup, 3, menu)
	statusLabel = Kit.label({
		font = "label",
		size = "small",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = statusGroup,
	})
	Kit.rule({
		color = C.white,
		transparency = 0.5,
		thickness = 2,
		Position = UDim2.new(0, 0, 1, -4),
		Parent = statusGroup,
	})
	statusGlitch = Glitch.attach(statusGroup, { loop = false, enter = false })
	contents = Kit.frame({
		Name = "Contents",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = menu,
	})
	DirectorPanel.Changed:Connect(function()
		buildContents(Kit.Layout.isPhone())
	end)
end

local function buildProfile()
	-- The card sits in a CanvasGroup so it can glitch in with the rest.
	profileGroup = Kit.Base.make("CanvasGroup", {
		Name = "ProfileGroup",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.hud,
	}) :: CanvasGroup
	profileGlitch = Glitch.attach(profileGroup, { loop = false, enter = false })
	local _, content = Kit.page({
		Name = "ProfileCard",
		tone = "raised",
		padding = T.space.l,
		autoHeight = true,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = profileGroup,
	})
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
		face = "Head",
		text = "",
		size = T.size.title,
		color = C.white,
		Position = UDim2.fromOffset(76, 32),
		Parent = top,
	})
	local _bar
	_bar, setXp = Kit.meter({ height = 5, LayoutOrder = 2, Parent = content })
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
	-- Your profile and the leaderboards open from the card, side by side. Each sits in
	-- a wrapper that blips like the rest of the lobby.
	links = Kit.frame({ Name = "Links", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 6, Parent = content })
	linksLayout = Kit.list(links, T.space.s, true)
	linksLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	for index, item in ipairs({ { "Profile", "profile" }, { "Leaderboards", "leaderboards" } }) do
		local wrap =
			wrapper({ Name = item[1], Size = UDim2.new(0.5, -T.space.xs, 0, 40), LayoutOrder = index, Parent = links })
		Kit.button({
			text = item[1],
			variant = "secondary",
			size = "s",
			Size = UDim2.fromScale(1, 1),
			Parent = wrap,
		}, function()
			Router.toggle(item[2])
		end)
		Glitch.attach(wrap, { loop = true, enter = false, band = false })
		linkWraps[index] = wrap
	end
end

local function layout(class: string)
	local phone = class == "phone"
	-- The ransom letters are cut at a size, so the title is built again for the device. Its wrapper takes
	-- the letters' size (a fixed size, so the glitch's ghosts never make it grow).
	Kit.clear(wordmarkHolder)
	-- On a phone the title stays small enough to clear Roblox's buttons at the top left.
	local size = if phone then 26 else 58
	-- The letters fall in from above and start larger, so the wrapper (which clips) leaves room around them;
	-- the block is raised by the same amount so the letters still come to rest at the top of the screen.
	local padTop, padSide = math.ceil(size * 1.1), math.ceil(size * 0.7)
	wordmark = Kit.ransom({
		text = Terms.GAME,
		size = size,
		Position = UDim2.fromOffset(padSide, padTop),
		Parent = wordmarkHolder,
	})
	titleBlock.Position = UDim2.new(0.5, 0, 0, TITLE_TOP - padTop)
	local letters = wordmark.frame
	local function fit()
		local width = letters.AbsoluteSize.X / Kit.Base.scaleOf(letters)
		wordmarkHolder.Size = UDim2.fromOffset(math.ceil(width) + 2 * padSide, math.ceil(wordmark.height) + padTop + 6)
	end
	letters:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	if titleBlock.Visible then
		wordmark:play()
	end
	buildQuote(phone)
	columnShare = if phone then COLUMN_TOP.phone else COLUMN_TOP.pc
	placeColumn()
	menu.Size = UDim2.fromOffset(if phone then 300 else 460, 0)
	readyHolder.Size = UDim2.new(1, 0, 0, if phone then 48 else 60)
	-- The card sits at the bottom right on every device (the top right is where pop-ups like the daily streak go).
	Kit.Layout.place(profileGroup, "bottomRight", Vector2.new(-T.space.l, -T.space.l))
	profileGroup.Size = UDim2.fromOffset(if phone then 260 else 340, 0)
	-- Side by side on every device, so the card stays short (on a phone it must clear the pop-ups above it).
	linksLayout.FillDirection = Enum.FillDirection.Horizontal
	links.Size = UDim2.new(1, 0, 0, 48)
	for _, wrap in ipairs(linkWraps) do
		wrap.Size = UDim2.new(0.5, -T.space.xs, 0, 40)
	end
	spectateButton.Size = UDim2.fromOffset(if phone then 260 else 320, 48)
	buildContents(phone)
	lastReady = nil
	updateLobby()
end

function LobbyPanel.init()
	screenProbe = Kit.frame({ Name = "LobbyScreenProbe", Parent = Screens.world })
	hudProbe = Kit.frame({ Name = "LobbyHudProbe", Size = UDim2.fromOffset(0, 0), Parent = Screens.hud })
	buildTitle()
	buildMenu()
	buildProfile()
	ClientState.ProfileChanged:Connect(updateProfile)
	ClientState.LobbyChanged:Connect(updateLobby)
	ClientState.PublicChanged:Connect(updateLobby)
	ClientState.WatchChanged:Connect(updateLobby)
	Kit.Layout.watch(layout)
	screenProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeColumn)
	hudProbe:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeColumn)
	placeColumn()
	updateProfile()
	updateLobby()
end

-- The READY button, for gamepad selection.
function LobbyPanel.readyButton(): TextButton
	return readyButton
end

return LobbyPanel
