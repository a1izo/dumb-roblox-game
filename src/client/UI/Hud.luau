-- The HUD in a match, drawn with the Notch kit. It is the quiet side of the design: steady, grey, and red
-- only for danger (the last ten seconds, Diavolo's side). It glitches once when the phase changes.
--   phase banner  (top centre)   the phase in Melodrama on a dark bar; under it a panel with the
--                                clock (equal-width digits), a tick per round and the place
--   objectives    (top left)     lines, filled in by the objective tracker
--   identity      (bottom left)  your ID seal, role, alias and, one per line, what you
--                                carry and can do
--   actions       (bottom right) square chips with an icon and a key, from Input/Actions;
--                                the name shows on hover
-- On touch screens the identity card moves to the left middle and the actions become a grid
-- of bigger chips on the right edge, clear of the thumbstick and the jump button. Between
-- matches the lobby panel takes over and the HUD stays out of the way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local Actions = require(script.Parent.Parent.Input.Actions)
local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Glitch = require(script.Parent.Core.Glitch)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Kit = require(script.Parent.Kit)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local Hud = {}

-- Seal emblem per role (the seal is only on your own screen).
local ROLE_ICON = {
	Kira = "hand",
	Follower = "cultist",
	L = "zero",
	Watari = "butler",
	TaskForce = "agency",
}

-- Icon per action id.
local ACTION_ICON = {
	evidence = "evidence",
	privateScreen = "grimoire",
	quickChat = "chat",
	note = "note",
	drop = "mail",
	eyesDeal = "eye",
	eyesRead = "eye",
	scratchpad = "quill",
	help = "help",
	zeroDesk = "zero",
}

-- Phase banner
local banner: Frame
local bannerText: any
local clockLabel: any
local bannerGlitch: any
local clockIcon: ImageLabel
local marks: Frame
local infoLabel: TextLabel
local bannerExtra: Frame

-- Identity
local badge: Frame
local seal: Frame
local sealHolder: Frame
local roleText: any
local aliasLabel: TextLabel
local abilities: Frame
local alliesLabel: TextLabel
local cardHint: TextLabel

-- Objectives and actions
local objectives: Frame
local actionBar: Frame
local actionKey = ""

local lastPhase = ""
local lastRole = ""
local lastAbilities = ""

-- Touch screens: chips per row in the action grid.
local TOUCH_COLUMNS = 3
local TOUCH_CHIP = 72

-- Phase banner --------------------------------------------------------------------------------

local function renderMarks(round: number, maxRounds: number)
	Kit.clear(marks)
	for i = 1, maxRounds do
		Kit.Base.make("Frame", {
			Name = "Round" .. i,
			BackgroundColor3 = if i <= round then C.white else C.g4,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(14, 6),
			LayoutOrder = i,
			Parent = marks,
		})
	end
end

local function updateBanner()
	local state = ClientState.public
	banner.Visible = state.active == true
	if not state.active then
		lastPhase = "Lobby"
		return
	end
	local phase = state.phase
	if phase ~= lastPhase then
		lastPhase = phase
		bannerText:set(Terms.phase(phase))
		bannerGlitch:enter()
		Motion.slideIn(banner, Vector2.new(0, -24), T.motion.slow)
	end
	local round = state.round or 0
	marks.Visible = round > 0
	renderMarks(round, state.maxRounds or 5)
	if not ClientState.isLiving() then
		infoLabel.Text = if ClientState.isParticipant() then "You are out  ·  watching" else "Watching"
		infoLabel.TextColor3 = C.white
	else
		infoLabel.Text = tostring(state.mapName or "")
		infoLabel.TextColor3 = C.dim
	end
end

local function clockText(seconds: number): string
	if not ClientState.public.active then
		return clockLabel.text
	end
	-- The last ten seconds are in red (danger).
	local urgent = seconds <= 10
	clockLabel:setColor(if urgent then C.danger else C.bone)
	clockIcon.ImageColor3 = if urgent then C.danger else C.dim
	return Clock.format(seconds)
end

-- Identity -------------------------------------------------------------------------------------

local function alliesText(private): string
	local parts = {}
	for _, ally in ipairs(private.allies or {}) do
		local info = Roles.get(ally.role)
		table.insert(parts, string.format("%s: %s%s", info.display, ally.alias, if ally.alive then "" else " (dead)"))
	end
	return table.concat(parts, "   ")
end

-- What you carry and what you can do right now, one line each.
local function abilityLines(private, phase: string): { string }
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
				elseif private.warrantBlocked then "Warrant blocked"
				else "Warrant ready in the vote"
		)
	end
	if private.role == "Follower" and private.canTamper and phase == "Investigation" then
		table.insert(list, "Can rig a flash (hold T)")
	end
	return list
end

local function renderAbilities(list: { string })
	local key = table.concat(list, "|")
	if key == lastAbilities then
		return
	end
	lastAbilities = key
	Kit.clear(abilities)
	for index, text in ipairs(list) do
		local line = Kit.frame({
			Name = "Ability",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = abilities,
		})
		-- A small grey square marks each line.
		Kit.Base.make("Frame", {
			Name = "Mark",
			BackgroundColor3 = C.dim,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(5, 10),
			Size = UDim2.fromOffset(6, 6),
			Parent = line,
		})
		Kit.label({
			Text = text,
			size = "small",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -16, 0, 0),
			Parent = line,
		})
	end
	abilities.Visible = #list > 0
end

local function rebuildSeal(role: string, color: Color3)
	if seal then
		seal:Destroy()
	end
	seal = Kit.seal({
		size = 60,
		color = color,
		icon = ROLE_ICON[role] or "agency",
		ZIndex = 3,
		Parent = sealHolder,
	})
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
	local role = private.role or "TaskForce"
	local info = Roles.get(role)
	local hostile = role == "Kira" or role == "Follower"
	local color = if hostile then C.danger else C.g6
	if role .. tostring(private.inMatch) ~= lastRole then
		lastRole = role .. tostring(private.inMatch)
		rebuildSeal(role, color)
		roleText:set(if private.inMatch then info.display else "")
		roleText:setColor(if hostile then C.danger else C.bone)
	end
	local status = if me then Terms.status(me.status) else ""
	aliasLabel.Text = string.format("%s  ·  %s", tostring(private.alias or (me and me.alias) or ""), status)
	alliesLabel.Text = alliesText(private)
	alliesLabel.Visible = alliesLabel.Text ~= ""
	renderAbilities(abilityLines(private, phase))
	cardHint.Text = if Kit.Layout.isTouch() then "Press and hold for your role card" else "Hold C for your role card"
end

-- Actions ---------------------------------------------------------------------------------------

local function renderActions()
	local view = Router.view()
	local touch = Kit.Layout.isTouch()
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
	Kit.clear(actionBar)
	for index, action in ipairs(available) do
		Kit.actionChip({
			icon = ACTION_ICON[action.id],
			label = action.label(view),
			key = Actions.hint(action),
			variant = if action.variant == "primary" then "primary" else nil,
			touch = touch,
			LayoutOrder = index,
			Parent = actionBar,
		}, action.run)
	end
end

-- Layout ----------------------------------------------------------------------------------------

local function layout(class: string)
	local touch = class == "phone" or class == "tablet"
	for _, child in ipairs(actionBar:GetChildren()) do
		if child:IsA("UIGridStyleLayout") then
			child:Destroy()
		end
	end
	if touch then
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 12, 0.55, 0)
		-- A grid of big chips on the right edge, filled from the right, above the jump button.
		actionBar.AnchorPoint = Vector2.new(1, 0.5)
		actionBar.Position = UDim2.new(1, -12, 0.42, 0)
		actionBar.Size = UDim2.fromOffset(TOUCH_CHIP * TOUCH_COLUMNS + T.space.s * (TOUCH_COLUMNS - 1), 0)
		actionBar.AutomaticSize = Enum.AutomaticSize.Y
		local grid = Kit.grid(actionBar, UDim2.fromOffset(TOUCH_CHIP, TOUCH_CHIP), T.space.s)
		grid.StartCorner = Enum.StartCorner.TopRight
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
		objectives.Size = UDim2.fromOffset(250, 0)
	else
		Kit.Layout.place(badge, "bottomLeft")
		-- One row of chips, as wide as they need, growing to the left.
		Kit.Layout.place(actionBar, "bottomRight")
		actionBar.Size = UDim2.fromOffset(0, 56)
		actionBar.AutomaticSize = Enum.AutomaticSize.X
		Kit.list(actionBar, T.space.s, true, Enum.HorizontalAlignment.Right)
		objectives.Size = UDim2.fromOffset(340, 0)
	end
	bannerText:setSize(if class == "phone" then T.size.title else T.size.heading)
	actionKey = ""
	renderActions()
end

-- Setup -----------------------------------------------------------------------------------------

local function buildBanner()
	-- A CanvasGroup, so the whole banner can blink when the phase changes.
	banner = Kit.Base.make("CanvasGroup", {
		Name = "PhaseBanner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
		Parent = Screens.hud,
	}) :: any
	Kit.Layout.place(banner, "topCenter", Vector2.new(0, -6))
	Kit.list(banner, T.space.xs, false, Enum.HorizontalAlignment.Center)
	local stroke, text = Kit.banner({
		text = "",
		size = T.size.heading,
		LayoutOrder = 1,
		Parent = banner,
	})
	local _ = stroke
	bannerText = text
	-- The clock, the rounds and the place sit on a glass panel, so the room never shows through. The panel
	-- is a shell with the clipped-corner shape behind an inner frame that lays its rows out.
	local plate = Kit.frame({
		Name = "Plate",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
		Parent = banner,
	})
	local shell = Kit.frame({ Name = "Shell", ZIndex = 0, Parent = plate })
	Kit.Surfaces.redrawWhenReady(shell, function()
		Kit.clear(shell)
		Kit.notch(shell, { shape = "panel", color = C.page, transparency = T.alpha.glass, ZIndex = 0 })
		Kit.Base.make("Frame", {
			Name = "Edge",
			BackgroundColor3 = C.g5,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 0,
			Parent = shell,
		})
	end)
	local inner = Kit.frame({
		Name = "Inner",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 1,
		Parent = plate,
	})
	Kit.pad(inner, T.space.s, T.space.l)
	Kit.list(inner, T.space.xxs, false, Enum.HorizontalAlignment.Center)
	local row = Kit.frame({
		Name = "Clock",
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = inner,
	})
	Kit.list(row, T.space.m, true, Enum.HorizontalAlignment.Center)
	clockIcon = Kit.icon({ name = "clock", size = 20, color = C.dim, LayoutOrder = 1, Parent = row })
	clockLabel = Kit.num({ text = "0:00", size = 26, color = C.bone, LayoutOrder = 2, Parent = row })
	marks = Kit.frame({
		Name = "Rounds",
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = row,
	})
	Kit.list(marks, 4, true, Enum.HorizontalAlignment.Center)
	infoLabel = Kit.label({
		Text = "",
		font = "label",
		size = "micro",
		upper = true,
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = 2,
		Parent = inner,
	})
	Clock.bind(clockLabel, clockText)
	-- Room under the panel for controls that belong with the phase (the Deathsinger HUD).
	bannerExtra = Kit.frame({
		Name = "Extra",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 3,
		Parent = banner,
	})
	-- A one-time glitch when the phase changes (the HUD itself never loops).
	bannerGlitch = Glitch.attach(banner, { loop = false, enter = false })
end

local function buildBadge()
	local page, content = Kit.page({
		Name = "Identity",
		tone = "raised",
		glass = true,
		padding = T.space.m,
		autoHeight = true,
		Size = UDim2.fromOffset(340, 0),
		Visible = false,
		Parent = Screens.hud,
	})
	badge = page
	Kit.list(content, T.space.s)
	-- The seal beside who you are; below it, a line per thing you carry or can do.
	local top = Kit.frame({
		Name = "Top",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = content,
	})
	sealHolder = Kit.frame({ Name = "SealHolder", Size = UDim2.fromOffset(60, 60), Parent = top })
	local column = Kit.frame({
		Name = "Column",
		Position = UDim2.fromOffset(72, 0),
		Size = UDim2.new(1, -72, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = top,
	})
	Kit.list(column, 2)
	roleText = Kit.text({ face = "Head", text = "", size = T.size.title, LayoutOrder = 1, Parent = column })
	aliasLabel = Kit.label({ font = "bodyBold", size = "small", LayoutOrder = 2, Parent = column })
	alliesLabel = Kit.label({ size = "micro", color = C.dim, LayoutOrder = 3, Parent = column })
	abilities = Kit.frame({
		Name = "Abilities",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 2,
		Parent = content,
	})
	Kit.list(abilities, T.space.xxs)
	cardHint = Kit.label({ font = "label", size = "micro", color = C.faint, LayoutOrder = 3, Parent = content })
end

function Hud.init()
	buildBanner()
	buildBadge()
	-- The list sits on a glass panel that shows only while it has lines.
	local objectivesPanel = Kit.frame({
		Name = "ObjectivesPanel",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = false,
		Parent = Screens.hud,
	})
	Kit.Layout.place(objectivesPanel, "topLeft", Vector2.new(0, 4))
	local objectivesShell = Kit.frame({ Name = "Shell", ZIndex = 0, Parent = objectivesPanel })
	Kit.Surfaces.redrawWhenReady(objectivesShell, function()
		Kit.clear(objectivesShell)
		Kit.notch(objectivesShell, { shape = "panel", color = C.page, transparency = T.alpha.glass, ZIndex = 0 })
		Kit.Base.make("Frame", {
			Name = "Edge",
			BackgroundColor3 = C.g5,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 0,
			Parent = objectivesShell,
		})
	end)
	objectives = Kit.frame({
		Name = "Objectives",
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 1,
		Parent = objectivesPanel,
	})
	Kit.pad(objectives, T.space.m, T.space.m + 4)
	Kit.list(objectives, T.space.s)
	local function syncObjectives()
		local any = false
		for _, child in ipairs(objectives:GetChildren()) do
			if child:IsA("GuiObject") then
				any = true
			end
		end
		objectivesPanel.Visible = any
	end
	objectives.ChildAdded:Connect(syncObjectives)
	objectives.ChildRemoved:Connect(syncObjectives)
	-- Its layout (a row, or a grid on touch screens) is set by layout().
	actionBar = Kit.frame({ Name = "ActionBar", Parent = Screens.hud })

	local function refresh()
		updateBanner()
		updateBadge()
		renderActions()
	end
	ClientState.PublicChanged:Connect(refresh)
	ClientState.PrivateChanged:Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(renderActions)
	Kit.Layout.watch(layout)
	refresh()
end

-- The container the objective tracker fills with lines (inside a glass panel that hides when it is empty).
function Hud.objectives(): Frame
	return objectives
end

-- The identity card on the HUD; pressing and holding it shows the full role card.
function Hud.badge(): Frame
	return badge
end

-- The slot under the phase banner's plate, centred with it (the Specter HUD lives there).
function Hud.bannerExtra(): Frame
	return bannerExtra
end

-- Where a HUD piece ends, in design pixels from the top of the safe area (0 while hidden).
local function bottomOf(gui: GuiObject): number
	if not gui.Visible then
		return 0
	end
	local scale = Kit.Base.scaleOf(gui)
	return (gui.AbsolutePosition.Y + gui.AbsoluteSize.Y - Screens.hud.AbsolutePosition.Y) / scale
end

-- Where the guide's tips go: under the objectives on the left, or under the phase banner on
-- phones (where the identity card takes the left side). Returns a position and an anchor.
function Hud.tipPlacement(): (UDim2, Vector2)
	if Kit.Layout.isPhone() then
		return UDim2.new(0.5, 0, 0, bottomOf(banner) + T.space.s), Vector2.new(0.5, 0)
	end
	return UDim2.new(0, T.space.l, 0, math.max(bottomOf(objectives), T.space.l) + T.space.m), Vector2.new(0, 0)
end

return Hud
