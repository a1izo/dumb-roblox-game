-- The HUD, "angular manga" style:
--   phase ribbon  (top left)   a black slanted block with the phase, a red one with the
--                              timer, and round bars underneath
--   objectives    under the ribbon (filled in by the objective tracker)
--   role card     (bottom left) your role on a tilted paper-white card
--   action bar    (bottom right) black slanted buttons with red key tags
-- On touch screens the role card moves to the left middle and the action bar to the right
-- edge, clear of the thumbstick and the jump button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local Actions = require(script.Parent.Parent.Input.Actions)
local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Motion = require(script.Parent.Core.Motion)
local Responsive = require(script.Parent.Core.Responsive)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local C = Theme.colors

local Hud = {}

-- Phase ribbon
local ribbon: Frame
local phaseLabel: TextLabel
local timerBlock: Frame
local timerLabel: TextLabel
local roundRow: Frame
local roundLabel: TextLabel
local bars: Frame
local infoLabel: TextLabel

-- Role card
local badge: Frame
local roleLabel: TextLabel
local aliasLabel: TextLabel
local alliesLabel: TextLabel
local chipsLabel: TextLabel
local cardHint: TextLabel

-- Objectives and actions
local objectives: Frame
local actionBar: Frame
local actionKey = ""

local lastPhase = ""

-- Phase ribbon -----------------------------------------------------------------------------

local function renderBars(round: number, maxRounds: number)
	Widgets.clear(bars)
	for i = 1, maxRounds do
		local bar = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = if i < round then C.paper elseif i == round then C.accent else C.panelLight,
			Size = UDim2.fromOffset(if i == round then 22 else 14, 8),
			LayoutOrder = i,
			Parent = bars,
		})
		Widgets.slant(bar, 0.2)
	end
end

local function updateRibbon()
	local state = ClientState.public
	ribbon.Visible = state.active == true
	if state.active then
		phaseLabel.Text = string.upper(Terms.phase(state.phase))
		timerBlock.Visible = true
		local round = state.round or 0
		roundRow.Visible = round > 0
		roundLabel.Text = string.format("ROUND %d / %d", round, state.maxRounds or 5)
		renderBars(round, state.maxRounds or 5)
		if not ClientState.isLiving() then
			infoLabel.Text = if ClientState.isParticipant() then "YOU ARE OUT  ·  SPECTATING" else "SPECTATING"
			infoLabel.TextColor3 = C.accent
		else
			infoLabel.Text = string.upper(state.mapName or "")
			infoLabel.TextColor3 = C.muted
		end
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			Motion.slideIn(ribbon, Vector2.new(-30, 0), 0.3)
		end
		return
	end
	lastPhase = "Lobby"
	phaseLabel.Text = "LOBBY"
	roundRow.Visible = false
	infoLabel.TextColor3 = C.muted
	local lobby = ClientState.lobby
	if lobby and lobby.countdown then
		timerBlock.Visible = true
		timerLabel.Text = Clock.format(lobby.countdown)
		infoLabel.Text = string.format("MATCH STARTING  ·  %d READY", lobby.readyCount)
	elseif lobby then
		timerBlock.Visible = false
		infoLabel.Text = if lobby.matchRunning
			then "A MATCH IS RUNNING"
			else string.format(
				"%d / %d READY  ·  NEXT: %s",
				lobby.readyCount,
				lobby.needed,
				string.upper(tostring(lobby.nextMap))
			)
	else
		timerBlock.Visible = false
		infoLabel.Text = "CONNECTING..."
	end
end

local function timerText(seconds: number): string
	if not ClientState.public.active then
		return timerLabel.Text
	end
	-- The timer block turns paper-white for the last ten seconds.
	local urgent = seconds <= 10
	timerBlock.BackgroundColor3 = if urgent then C.paper else C.accent
	timerLabel.TextColor3 = if urgent then C.accent else C.paper
	return Clock.format(seconds)
end

-- Role card --------------------------------------------------------------------------------

local function alliesText(private): string
	local parts = {}
	for _, ally in ipairs(private.allies or {}) do
		local info = Roles.get(ally.role)
		table.insert(parts, string.format("%s: %s%s", info.display, ally.alias, if ally.alive then "" else " (dead)"))
	end
	return table.concat(parts, "   ")
end

local function chips(private, phase: string): string
	local list = {}
	if private.hood then
		table.insert(list, "HOOD ON")
	end
	if private.carrying == "blank" then
		table.insert(list, "BLANK SHEET")
	elseif private.carrying == "note" then
		table.insert(list, "WRITTEN NOTE")
	end
	if private.eyes then
		table.insert(
			list,
			string.upper(Terms.f("{Eyes}: {reads} reads, {rounds} round(s) left", {
				reads = private.eyes.readsLeft,
				rounds = private.eyes.countdown,
			}))
		)
	end
	if private.role == "L" then
		table.insert(
			list,
			if private.warrantUsed
				then "WARRANT USED"
				elseif private.warrantBlocked then "WARRANT BLOCKED"
				else "WARRANT READY IN THE VOTE"
		)
	end
	if private.role == "Follower" and private.canTamper and phase == "Investigation" then
		table.insert(list, "CAN RIG A FLASH (HOLD T)")
	end
	return table.concat(list, "  ·  ")
end

local function updateBadge()
	local participant = ClientState.isParticipant()
	local phase = ClientState.phase()
	badge.Visible = participant and phase ~= "Vote" and not Actions.CUTSCENE_PHASES[phase]
	if not participant then
		return
	end
	local private = ClientState.private
	local me = ClientState.me()
	local info = Roles.get(private.role or "TaskForce")
	roleLabel.Text = if private.inMatch then info.display else ""
	roleLabel.TextColor3 = if private.role == "Kira" or private.role == "Follower" then C.accent else C.ink
	local status = if me then string.upper(Terms.status(me.status)) else ""
	aliasLabel.Text =
		string.format("%s  ·  %s", string.upper(tostring(private.alias or (me and me.alias) or "")), status)
	alliesLabel.Text = alliesText(private)
	alliesLabel.Visible = alliesLabel.Text ~= ""
	chipsLabel.Text = chips(private, phase)
	chipsLabel.Visible = chipsLabel.Text ~= ""
	cardHint.Text = if Responsive.isTouch() then "PRESS AND HOLD FOR YOUR ROLE CARD" else "HOLD C FOR YOUR ROLE CARD"
end

-- Action bar -------------------------------------------------------------------------------

local function renderActions()
	local view = Router.view()
	local touch = Responsive.isTouch()
	-- The meeting panel carries its own buttons; keys still work while the bar is hidden.
	local hideForMeeting = view.phase == "Meeting"
		or view.phase == "Vote"
		or Actions.CUTSCENE_PHASES[view.phase] == true
	local available = if view.participant and not hideForMeeting then Actions.available(view) else {}
	-- Rebuild only when the buttons, their labels or the key hints change.
	local parts = {}
	for _, action in ipairs(available) do
		table.insert(parts, action.id .. "=" .. action.label(view) .. "=" .. Actions.hint(action))
	end
	local key = table.concat(parts, "|") .. (if touch then "|touch" else "")
	if key == actionKey then
		return
	end
	actionKey = key
	Widgets.clear(actionBar)
	for index, action in ipairs(available) do
		local hint = Actions.hint(action)
		Widgets.button({
			Text = action.label(view),
			Key = if hint ~= "" then hint else nil,
			TextSize = Theme.text.body,
			Variant = if action.variant == "primary" then "primary" else "secondary",
			Size = if touch then UDim2.fromOffset(150, 50) else UDim2.fromOffset(0, 42),
			AutomaticSize = if touch then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			LayoutOrder = index,
			Parent = actionBar,
		}, action.run)
	end
end

-- Layout -----------------------------------------------------------------------------------

local function layout()
	local touch = Responsive.isTouch()
	local listLayout = actionBar:FindFirstChildOfClass("UIListLayout")
	if touch then
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 14, 0.5, 0)
		actionBar.AnchorPoint = Vector2.new(1, 0.5)
		actionBar.Position = UDim2.new(1, -12, 0.42, 0)
		actionBar.Size = UDim2.fromOffset(150, 0)
		if listLayout then
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		end
	else
		badge.AnchorPoint = Vector2.new(0, 1)
		badge.Position = UDim2.new(0, 22, 1, -22)
		actionBar.AnchorPoint = Vector2.new(1, 1)
		actionBar.Position = UDim2.new(1, -22, 1, -22)
		actionBar.Size = UDim2.new(0.62, 0, 0, 42)
		if listLayout then
			listLayout.FillDirection = Enum.FillDirection.Horizontal
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
	end
	actionKey = ""
	renderActions()
end

-- Setup ------------------------------------------------------------------------------------

local function buildRibbon()
	ribbon = Widgets.frame({
		Name = "PhaseRibbon",
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = Screens.hud,
	})
	Widgets.list(ribbon, 6)
	local top = Widgets.frame({
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = ribbon,
	})
	local row = Widgets.list(top, 0, true)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local phaseBlock = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.ink,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = top,
	})
	Widgets.slant(phaseBlock, 0.06)
	Widgets.padding(phaseBlock, 0, 22)
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Position = UDim2.fromOffset(-12, 0),
		Size = UDim2.new(0, 5, 1, 0),
		Parent = phaseBlock,
	})
	phaseLabel = Widgets.display({
		TextSize = Theme.text.title,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = phaseBlock,
	})
	timerBlock = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Size = UDim2.fromOffset(104, 44),
		LayoutOrder = 2,
		Parent = top,
	})
	Widgets.slant(timerBlock, 0.12)
	timerLabel = Widgets.display({
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = timerBlock,
	})
	roundRow = Widgets.frame({
		Size = UDim2.fromOffset(260, 16),
		LayoutOrder = 2,
		Visible = false,
		Parent = ribbon,
	})
	roundLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.small,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(0, 100, 1, 0),
		Parent = roundRow,
	})
	bars = Widgets.frame({
		Position = UDim2.fromOffset(108, 4),
		Size = UDim2.fromOffset(150, 8),
		Parent = roundRow,
	})
	Widgets.list(bars, 4, true)
	infoLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.caption,
		TextColor3 = C.muted,
		Size = UDim2.fromOffset(320, 16),
		LayoutOrder = 3,
		Parent = ribbon,
	})
	Clock.bind(timerLabel, timerText)
end

local function buildBadge()
	badge = Widgets.card({
		Name = "RoleBadge",
		Rotation = -2,
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.hud,
	})
	Widgets.sizeLimit(badge, Vector2.new(340, 400), Vector2.new(220, 0))
	Widgets.padding(badge, Theme.space.md, Theme.space.lg)
	Widgets.list(badge, 2)
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		Size = UDim2.new(0, 36, 0, 4),
		LayoutOrder = 0,
		Parent = badge,
	})
	roleLabel = Widgets.display({
		TextSize = 30,
		TextColor3 = C.ink,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 1,
		Parent = badge,
	})
	aliasLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.body,
		TextColor3 = C.ink,
		LayoutOrder = 2,
		Parent = badge,
	})
	alliesLabel = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = C.inkMuted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = badge,
	})
	chipsLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.caption,
		TextColor3 = C.accent,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = badge,
	})
	cardHint = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = 11,
		TextColor3 = C.inkMuted,
		LayoutOrder = 5,
		Parent = badge,
	})
end

function Hud.init()
	buildRibbon()
	buildBadge()
	objectives = Widgets.frame({
		Name = "Objectives",
		Position = UDim2.fromOffset(18, 108),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Widgets.list(objectives, Theme.space.xs)
	actionBar = Widgets.frame({ Name = "ActionBar", Parent = Screens.hud })
	Widgets.list(actionBar, Theme.space.sm, true)

	local function refresh()
		updateRibbon()
		updateBadge()
		renderActions()
	end
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	ClientState.LobbyChanged:Connect(updateRibbon)
	UserInputService.LastInputTypeChanged:Connect(renderActions)
	Responsive.Changed:Connect(layout)
	layout()
	refresh()
end

-- The container the objective tracker fills with lines.
function Hud.objectives(): Frame
	return objectives
end

-- The role card on the HUD; pressing and holding it shows the full role card.
function Hud.badge(): Frame
	return badge
end

return Hud
