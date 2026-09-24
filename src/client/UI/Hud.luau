-- The in-match and lobby HUD:
--   phase pill    (top center)  phase, round dots and the timer
--   role badge    your role, alias, status, allies and short status chips
--   objectives    what to do right now (filled in by the Guide)
--   action bar    buttons for the actions available right now, with their key hints
-- On touch screens the badge moves to the top left and the action bar to the right edge,
-- clear of the thumbstick and the jump button.

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

local Hud = {}

-- Phase pill
local pill: Frame
local phaseLabel: TextLabel
local infoLabel: TextLabel
local timerLabel: TextLabel
local dots: Frame
local spectatingTag: TextLabel

-- Role badge
local badge: Frame
local roleLabel: TextLabel
local aliasLabel: TextLabel
local alliesLabel: TextLabel
local chipsLabel: TextLabel

-- Objectives and actions
local objectives: Frame
local actionBar: Frame
local actionKey = ""

local lastPhase = ""

-- Phase pill -------------------------------------------------------------------------------

local function renderDots(round: number, maxRounds: number)
	Widgets.clear(dots)
	for i = 1, maxRounds do
		local dot = Widgets.frame({
			BackgroundTransparency = 0,
			BackgroundColor3 = if i < round
				then Theme.colors.muted
				elseif i == round then Theme.colors.accent
				else Theme.colors.panelLight,
			Size = UDim2.fromOffset(if i == round then 14 else 8, 8),
			LayoutOrder = i,
			Parent = dots,
		})
		Widgets.corner(dot, Theme.radius.pill)
	end
end

local function updatePill()
	local state = ClientState.public
	if state.active then
		phaseLabel.Text = string.upper(Terms.phase(state.phase))
		phaseLabel.TextColor3 = Theme.colors.text
		infoLabel.Text = state.mapName
		timerLabel.Visible = true
		dots.Visible = (state.round or 0) > 0
		renderDots(state.round or 0, state.maxRounds or 5)
		spectatingTag.Visible = not ClientState.isLiving()
		spectatingTag.Text = if ClientState.isParticipant() then "YOU ARE OUT  ·  SPECTATING" else "SPECTATING"
		if state.phase ~= lastPhase then
			lastPhase = state.phase
			Motion.pulse(pill)
		end
		return
	end
	lastPhase = "Lobby"
	phaseLabel.Text = "LOBBY"
	phaseLabel.TextColor3 = Theme.colors.gold
	dots.Visible = false
	spectatingTag.Visible = false
	local lobby = ClientState.lobby
	if lobby and lobby.countdown then
		timerLabel.Visible = true
		timerLabel.Text = Clock.format(lobby.countdown)
		infoLabel.Text = string.format("Match starting  ·  %d ready", lobby.readyCount)
	elseif lobby then
		timerLabel.Visible = false
		infoLabel.Text = if lobby.matchRunning
			then "A match is running"
			else string.format("%d/%d ready  ·  next: %s", lobby.readyCount, lobby.needed, lobby.nextMap)
	else
		timerLabel.Visible = false
		infoLabel.Text = "Connecting..."
	end
end

local function timerText(seconds: number): string
	if not ClientState.public.active then
		return timerLabel.Text
	end
	local warn = seconds <= 10
	timerLabel.TextColor3 = if warn then Theme.colors.bad else Theme.colors.text
	return Clock.format(seconds)
end

-- Role badge -------------------------------------------------------------------------------

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
		table.insert(list, "Hood on")
	end
	if private.carrying == "blank" then
		table.insert(list, "Blank sheet")
	elseif private.carrying == "note" then
		table.insert(list, "Written note")
	end
	if private.eyes then
		table.insert(
			list,
			Terms.f("{Eyes}: {reads} reads, {rounds} round(s) left", {
				reads = private.eyes.readsLeft,
				rounds = private.eyes.countdown,
			})
		)
	end
	if private.role == "L" then
		table.insert(
			list,
			if private.warrantUsed
				then "Warrant used"
				elseif private.warrantBlocked then "Warrant blocked this round"
				else "Warrant ready in the vote"
		)
	end
	if private.role == "Follower" and private.canTamper and phase == "Investigation" then
		table.insert(list, "Can rig a flash (hold T)")
	end
	return table.concat(list, "  ·  ")
end

local function updateBadge()
	local participant = ClientState.isParticipant()
	local phase = ClientState.phase()
	badge.Visible = participant and phase ~= "Vote"
	if not participant then
		return
	end
	local private = ClientState.private
	local me = ClientState.me()
	local info = Roles.get(private.role or "TaskForce")
	roleLabel.Text = if private.inMatch then info.display else ""
	roleLabel.TextColor3 = info.color
	local status = if me then Terms.status(me.status) else ""
	aliasLabel.Text = string.format("%s  ·  %s", tostring(private.alias or (me and me.alias) or ""), status)
	alliesLabel.Text = alliesText(private)
	alliesLabel.Visible = alliesLabel.Text ~= ""
	chipsLabel.Text = chips(private, phase)
	chipsLabel.Visible = chipsLabel.Text ~= ""
end

-- Action bar -------------------------------------------------------------------------------

local function renderActions()
	local view = Router.view()
	local touch = Responsive.isTouch()
	-- The meeting panel carries its own buttons; keys still work while the bar is hidden.
	local hideForMeeting = view.phase == "Meeting" or view.phase == "Vote"
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
		local text = action.label(view)
		local button = Widgets.button({
			Text = if hint ~= "" then string.format("%s  [%s]", text, hint) else text,
			TextSize = if touch then Theme.text.small else Theme.text.small,
			Variant = action.variant or "secondary",
			Size = if touch then UDim2.fromOffset(132, 52) else UDim2.fromOffset(0, 40),
			AutomaticSize = if touch then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			LayoutOrder = index,
			Parent = actionBar,
		}, action.run)
		if not touch then
			Widgets.padding(button, 0, Theme.space.md)
		end
	end
end

-- Layout -----------------------------------------------------------------------------------

local function layout()
	local touch = Responsive.isTouch()
	local listLayout = actionBar:FindFirstChildOfClass("UIListLayout")
	if touch then
		badge.AnchorPoint = Vector2.new(0, 0)
		badge.Position = UDim2.fromOffset(12, 10)
		objectives.Position = UDim2.fromOffset(12, 104)
		actionBar.AnchorPoint = Vector2.new(1, 0.5)
		actionBar.Position = UDim2.new(1, -12, 0.42, 0)
		actionBar.Size = UDim2.fromOffset(132, 0)
		if listLayout then
			listLayout.FillDirection = Enum.FillDirection.Vertical
			listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		end
	else
		badge.AnchorPoint = Vector2.new(0, 1)
		badge.Position = UDim2.new(0, 16, 1, -16)
		objectives.Position = UDim2.fromOffset(16, 16)
		actionBar.AnchorPoint = Vector2.new(1, 1)
		actionBar.Position = UDim2.new(1, -16, 1, -16)
		actionBar.Size = UDim2.new(0.6, 0, 0, 40)
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

local function buildPill()
	pill = Widgets.panel({
		Name = "PhasePill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(320, 60),
		Parent = Screens.hud,
	})
	phaseLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = Theme.text.bodyLarge,
		Position = UDim2.fromOffset(16, 9),
		Size = UDim2.new(1, -120, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = pill,
	})
	infoLabel = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Position = UDim2.fromOffset(16, 32),
		Size = UDim2.new(1, -120, 0, 16),
		Parent = pill,
	})
	timerLabel = Widgets.label({
		Font = Theme.fonts.mono,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(100, 36),
		Parent = pill,
	})
	dots = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(200, 8),
		Parent = pill,
	})
	local dotLayout = Widgets.list(dots, 5, true, Enum.HorizontalAlignment.Center)
	dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	spectatingTag = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.secret,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 18),
		Size = UDim2.new(1, 0, 0, 16),
		Visible = false,
		Parent = pill,
	})
	Clock.bind(timerLabel, timerText)
end

local function buildBadge()
	badge = Widgets.panel({
		Name = "RoleBadge",
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.hud,
	})
	Widgets.sizeLimit(badge, Vector2.new(360, 400), Vector2.new(220, 0))
	Widgets.padding(badge, Theme.space.md, Theme.space.lg)
	Widgets.list(badge, 2)
	roleLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = Theme.text.title,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 1,
		Parent = badge,
	})
	aliasLabel = Widgets.label({
		Font = Theme.fonts.bold,
		TextSize = Theme.text.small,
		LayoutOrder = 2,
		Parent = badge,
	})
	alliesLabel = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = badge,
	})
	chipsLabel = Widgets.label({
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.gold,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = badge,
	})
end

function Hud.init()
	buildPill()
	buildBadge()
	objectives = Widgets.frame({
		Name = "Objectives",
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = Screens.hud,
	})
	Widgets.list(objectives, Theme.space.xs)
	actionBar = Widgets.frame({ Name = "ActionBar", Parent = Screens.hud })
	Widgets.list(actionBar, Theme.space.sm, true)

	local function refresh()
		updatePill()
		updateBadge()
		renderActions()
	end
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	ClientState.LobbyChanged:Connect(updatePill)
	UserInputService.LastInputTypeChanged:Connect(renderActions)
	Responsive.Changed:Connect(layout)
	layout()
	refresh()
end

-- The container the Guide fills with objective lines.
function Hud.objectives(): Frame
	return objectives
end

return Hud
