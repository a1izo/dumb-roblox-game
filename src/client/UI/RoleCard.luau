-- The role card: your role, how you win, your alias and your real name, your allies and
-- (for the Butler) the hint. It shows only while you hold C, the left bumper, or press and
-- hold your role badge, so a glance at your screen never gives your name away.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoleCopy = require(Shared:WaitForChild("Copy"):WaitForChild("RoleCopy"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local Motion = require(script.Parent.Core.Motion)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local RoleCard = {}

local card: Frame
local roleLabel: TextLabel
local winLabel: TextLabel
local bullets: Frame
local aliasLabel: TextLabel
local nameLabel: TextLabel
local alliesLabel: TextLabel
local hintLabel: TextLabel

local function alliesText(private): string
	local parts = {}
	for _, ally in ipairs(private.allies or {}) do
		local info = Roles.get(ally.role)
		table.insert(parts, string.format("%s: %s%s", info.display, ally.alias, if ally.alive then "" else " (dead)"))
	end
	return if #parts > 0 then table.concat(parts, "   ") else "You know nobody else's role."
end

local function fill()
	local private = ClientState.private
	local role = private.role or "TaskForce"
	local info = Roles.get(role)
	local copy = RoleCopy[role] or RoleCopy.TaskForce
	roleLabel.Text = info.display
	roleLabel.TextColor3 = info.color
	winLabel.Text = "HOW YOU WIN: " .. copy.win
	Widgets.clear(bullets)
	for index, text in ipairs(copy.bullets) do
		Widgets.label({
			Text = "•  " .. text,
			TextSize = Theme.text.small,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = bullets,
		})
	end
	aliasLabel.Text = "Alias: " .. tostring(private.alias or "")
	nameLabel.Text = string.upper(tostring(private.realName or "?"))
	alliesLabel.Text = alliesText(private)
	hintLabel.Visible = type(private.hint) == "string"
	hintLabel.Text = if type(private.hint) == "string" then Terms.f("{BUTLER}'S HINT: ") .. private.hint else ""
end

function RoleCard.show()
	if not ClientState.private.inMatch then
		return
	end
	fill()
	if not card.Visible then
		card.Visible = true
		Motion.pop(card)
	end
end

function RoleCard.hide()
	card.Visible = false
	-- Nothing secret stays in the UI while the card is hidden.
	nameLabel.Text = ""
	hintLabel.Text = ""
end

function RoleCard.init()
	card = Widgets.panel({
		Name = "RoleCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = Screens.overlay,
	})
	Widgets.sizeLimit(card, Vector2.new(520, 700))
	Widgets.padding(card, Theme.space.xl)
	Widgets.list(card, Theme.space.sm)
	Widgets.header({ Text = "Your role card", LayoutOrder = 1, Parent = card })
	roleLabel = Widgets.label({
		Font = Theme.fonts.black,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 2,
		Parent = card,
	})
	winLabel = Widgets.label({
		Font = Theme.fonts.bold,
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.gold,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = card,
	})
	bullets = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = card,
	})
	Widgets.list(bullets, Theme.space.xs)
	aliasLabel = Widgets.label({
		Font = Theme.fonts.bold,
		LayoutOrder = 5,
		Parent = card,
	})
	Widgets.header({ Text = "Your real name", LayoutOrder = 6, Parent = card })
	nameLabel = Widgets.label({
		Font = Theme.fonts.typewriter,
		TextSize = 36,
		TextColor3 = Theme.colors.paper,
		Size = UDim2.new(1, 0, 0, 42),
		LayoutOrder = 7,
		Parent = card,
	})
	alliesLabel = Widgets.label({
		TextSize = Theme.text.small,
		TextColor3 = Theme.colors.muted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 8,
		Parent = card,
	})
	hintLabel = Widgets.label({
		Font = Theme.fonts.typewriter,
		TextColor3 = Theme.colors.team,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 9,
		Parent = card,
	})
	Widgets.label({
		Text = "Release to hide.",
		TextSize = Theme.text.caption,
		TextColor3 = Theme.colors.faint,
		LayoutOrder = 10,
		Parent = card,
	})

	-- Hold C (keyboard) or the left bumper (gamepad).
	ContextActionService:BindAction("InkboundRoleCard", function(_, state: Enum.UserInputState)
		if not ClientState.private.inMatch then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			RoleCard.show()
		else
			RoleCard.hide()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)

	-- Press and hold the role badge (mouse or touch).
	local badge = Hud.badge()
	badge.Active = true
	badge.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			RoleCard.show()
		end
	end)
	badge.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			RoleCard.hide()
		end
	end)
	ClientState.PrivateChanged:Connect(function()
		if card.Visible then
			fill()
		end
		if not ClientState.private.inMatch then
			RoleCard.hide()
		end
	end)
end

return RoleCard
