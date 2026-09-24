-- In-match HUD: alias, role, status, allies and the actions available right now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local EvidencePanel = require(script.Parent.EvidencePanel)
local EyesController = require(script.Parent.Parent.Controllers.EyesController)
local LPanel = require(script.Parent.LPanel)
local NotePanel = require(script.Parent.NotePanel)
local QuickChatPanel = require(script.Parent.QuickChatPanel)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local RoleHud = {}

local panel: Frame
local aliasLabel: TextLabel
local roleLabel: TextLabel
local alliesLabel: TextLabel
local extraLabel: TextLabel
local buttons: Frame

local function alliesText(private): string
	local parts = {}
	for _, ally in ipairs(private.allies or {}) do
		local info = Roles.get(ally.role)
		local suffix = if ally.alive then "" else " (dead)"
		table.insert(parts, string.format("%s: %s%s", info.display, ally.alias, suffix))
	end
	return table.concat(parts, "   ")
end

local function addButton(text: string, color: Color3?, onClick: () -> ())
	Widgets.button({
		Text = text,
		TextSize = 13,
		BackgroundColor3 = color or Theme.colors.button,
		Parent = buttons,
	}, onClick)
end

local function rebuild()
	local participant = ClientState.isParticipant()
	panel.Visible = participant and ClientState.phase() ~= "Vote"
	if not participant then
		return
	end
	local private = ClientState.private
	local me = ClientState.me()
	local living = ClientState.isLiving()
	local phase = ClientState.phase()
	local info = Roles.get(private.role or "TaskForce")

	local status = if me then (Theme.STATUS_NAMES[me.status] or me.status) else ""
	aliasLabel.Text = string.format("%s   |   %s", tostring(private.alias or (me and me.alias) or ""), status)
	roleLabel.Text = if private.inMatch then info.display else ""
	roleLabel.TextColor3 = info.color
	alliesLabel.Text = alliesText(private)

	local extras = {}
	if private.hood then
		table.insert(extras, Terms.f("Hood on: {eyes} cannot read you"))
	end
	if private.carrying == "blank" then
		table.insert(extras, "Carrying a blank sheet")
	elseif private.carrying == "note" then
		table.insert(extras, "Carrying a written note")
	end
	if private.eyes then
		table.insert(
			extras,
			Terms.f(
				"{Eyes}: {reads} reads left, {rounds} round(s) to live",
				{ reads = private.eyes.readsLeft, rounds = private.eyes.countdown }
			)
		)
	end
	if private.role == "L" then
		if private.warrantUsed then
			table.insert(extras, "Warrant used")
		elseif private.warrantBlocked then
			table.insert(extras, "Warrant blocked this round")
		else
			table.insert(extras, "Warrant ready (during the vote)")
		end
	end
	if private.role == "Follower" and private.canTamper and phase == "Investigation" then
		table.insert(extras, "Hold T at a station to rig its next flash")
	end
	extraLabel.Text = table.concat(extras, "\n")

	Widgets.clear(buttons)
	addButton("Evidence [B]", nil, EvidencePanel.toggle)
	if living then
		addButton("Quick chat [Q]", nil, QuickChatPanel.toggle)
		if private.carrying == "blank" then
			addButton("Write [N]", Theme.colors.team, NotePanel.openWrite)
			addButton("Discard [G]", nil, NotePanel.drop)
		elseif private.carrying == "note" then
			addButton("Read note [N]", Theme.colors.team, NotePanel.openHeld)
			addButton("Drop note [G]", nil, NotePanel.drop)
		end
		if private.role == "Follower" and private.canDeal and phase == "Investigation" then
			addButton(Terms.f("{Eyes}"), Theme.colors.accent, EyesController.deal)
		end
		if private.eyes and phase == "Investigation" then
			addButton("Read name [R]", Theme.colors.accent, EyesController.read)
		end
	end
	if private.role == "L" then
		addButton(Terms.f("{ZeroDesk} [Z]"), Color3.fromRGB(70, 70, 80), LPanel.toggle)
	end
end

function RoleHud.init()
	panel = Widgets.panel({
		Name = "RoleHud",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.36, 0, 0, 210),
		Visible = false,
		Parent = Screens.hud,
	})
	Widgets.sizeLimit(panel, Vector2.new(430, 210), Vector2.new(290, 0))
	aliasLabel = Widgets.label({
		Font = Theme.fonts.bold,
		TextSize = 16,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 20),
		Parent = panel,
	})
	roleLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 24,
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 28),
		Parent = panel,
	})
	alliesLabel = Widgets.label({
		TextSize = 13,
		TextColor3 = Theme.colors.muted,
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 0, 18),
		Parent = panel,
	})
	extraLabel = Widgets.label({
		TextSize = 13,
		TextColor3 = Theme.colors.gold,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 50),
		Parent = panel,
	})
	buttons = Widgets.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 70),
		Parent = panel,
	})
	Widgets.grid(buttons, UDim2.new(0.333, -6, 0, 32), 6)

	ClientState.PublicChanged:Connect(rebuild)
	ClientState.PrivateChanged:Connect(rebuild)
	rebuild()
end

return RoleHud
