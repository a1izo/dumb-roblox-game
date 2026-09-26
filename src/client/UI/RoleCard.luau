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
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local RoleCard = {}

local card: Frame
local sealHolder: Frame
local roleText: any
local winLabel: TextLabel
local bullets: Frame
local aliasText: any
local nameText: any
local alliesLabel: TextLabel
local hintLabel: TextLabel

local ROLE_ICON = { Kira = "hand", Follower = "cultist", L = "zero", Watari = "butler", TaskForce = "agency" } -- terms:ok

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
	local hostile = role == "Kira" or role == "Follower"
	Kit.clear(sealHolder)
	Kit.seal({ size = 72, color = if hostile then C.red else C.steel, icon = ROLE_ICON[role], Parent = sealHolder })
	roleText:set(info.display)
	roleText:setColor(if hostile then C.blood else C.ink)
	winLabel.Text = "How you win: " .. copy.win
	Kit.clear(bullets)
	for index, text in ipairs(copy.bullets) do
		Kit.label({
			Text = "·  " .. text,
			size = "small",
			color = C.ink,
			LayoutOrder = index,
			Parent = bullets,
		})
	end
	aliasText:set(tostring(private.alias or ""))
	nameText:set(tostring(private.realName or "?"))
	alliesLabel.Text = alliesText(private)
	hintLabel.Visible = type(private.hint) == "string"
	hintLabel.Text = if type(private.hint) == "string" then Terms.f("{Butler}'s hint: ") .. private.hint else ""
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
	nameText:set("")
	hintLabel.Text = ""
end

function RoleCard.init()
	local page, content = Kit.page({
		Name = "RoleCard",
		tone = "parchment",
		padding = T.space.xl,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		autoHeight = true,
		Visible = false,
		ZIndex = 10,
		Parent = Screens.overlay,
	})
	card = page
	Kit.Base.maxSize(card, Vector2.new(500, 760))
	Kit.list(content, T.space.s)
	local top = Kit.frame({ Name = "Top", Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 1, Parent = content })
	sealHolder = Kit.frame({ Name = "Seal", Size = UDim2.fromOffset(72, 72), Parent = top })
	Kit.label({
		Text = "YOUR ROLE",
		font = "label",
		size = "micro",
		color = C.inkDim,
		Position = UDim2.fromOffset(88, 4),
		Size = UDim2.new(1, -88, 0, 0),
		Parent = top,
	})
	roleText = Kit.text({
		face = "Gothic",
		text = "",
		size = T.size.display,
		color = C.ink,
		Position = UDim2.fromOffset(86, 18),
		Parent = top,
	})
	winLabel = Kit.label({ font = "bodyBold", size = "small", color = C.blood, LayoutOrder = 2, Parent = content })
	bullets = Kit.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = content,
	})
	Kit.list(bullets, T.space.xs)
	Kit.rule({ color = C.ink, transparency = 0.7, LayoutOrder = 4, Parent = content })
	Kit.label({
		Text = "YOUR ALIAS",
		font = "label",
		size = "micro",
		color = C.inkDim,
		LayoutOrder = 5,
		Parent = content,
	})
	aliasText = Kit.text({ face = "Scrawl", text = "", size = 40, color = C.ink, LayoutOrder = 6, Parent = content })
	Kit.label({
		Text = "YOUR REAL NAME",
		font = "label",
		size = "micro",
		color = C.inkDim,
		LayoutOrder = 7,
		Parent = content,
	})
	nameText = Kit.text({ face = "Scrawl", text = "", size = 52, color = C.blood, LayoutOrder = 8, Parent = content })
	alliesLabel = Kit.label({ size = "small", color = C.inkDim, LayoutOrder = 9, Parent = content })
	hintLabel = Kit.label({ font = "document", size = "small", color = C.ink, LayoutOrder = 10, Parent = content })
	Kit.label({
		Text = "Release to hide.",
		font = "bodyItalic",
		size = "micro",
		color = C.inkDim,
		LayoutOrder = 11,
		Parent = content,
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
