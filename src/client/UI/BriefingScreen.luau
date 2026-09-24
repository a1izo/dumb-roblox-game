-- The briefing: your role, three things to know, how you win and a first move, then your
-- alias, your real name, your allies and (for the Butler) the hint. Everything here can be
-- seen again later on the role card (hold C).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RoleCopy = require(Shared:WaitForChild("Copy"):WaitForChild("RoleCopy"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local BriefingScreen = {}

local root: Frame
local column: Frame
local roleLabel: TextLabel
local bullets: Frame
local winLabel: TextLabel
local firstMoveLabel: TextLabel
local aliasLabel: TextLabel
local nameLabel: TextLabel
local alliesLabel: TextLabel
local hintLabel: TextLabel
local footerLabel: TextLabel
local timerLabel: TextLabel
local unbindTimer: (() -> ())? = nil

local function hide()
	root.Visible = false
	Router.setBlocking("briefing", false)
	nameLabel.Text = ""
	hintLabel.Text = ""
	alliesLabel.Text = ""
	if unbindTimer then
		unbindTimer()
		unbindTimer = nil
	end
end

local function alliesText(role: string, allies): string
	local kira, followers, watari = nil, {}, nil
	for _, ally in ipairs(allies or {}) do
		if ally.role == "Kira" then
			kira = ally.alias
		elseif ally.role == "Follower" then
			table.insert(followers, ally.alias)
		elseif ally.role == "Watari" then
			watari = ally.alias
		end
	end
	if role == "Kira" then
		if #followers == 0 then
			return Terms.f("You have no {cultists} this match.")
		end
		return Terms.f("Your {cultists}: ") .. table.concat(followers, ", ")
	elseif role == "Follower" then
		local text = Terms.f("{Hand} is {alias}.", { alias = kira or "unknown" })
		if #followers > 0 then
			text ..= Terms.f("  Other {cultist}: ") .. table.concat(followers, ", ")
		end
		return text
	elseif role == "L" then
		return if watari
			then Terms.f("{Butler} is {alias}. Nobody else knows who you are.", { alias = watari })
			else "You work alone this match."
	elseif role == "Watari" then
		return Terms.f("Only {zero} knows who you are. You do not know who {zero} is.")
	end
	return "Nobody knows anyone's role. Trust carefully."
end

function BriefingScreen.show(payload)
	local role = payload.role or "TaskForce"
	local info = Roles.get(role)
	local copy = RoleCopy[role] or RoleCopy.TaskForce
	roleLabel.Text = info.display
	roleLabel.TextColor3 = info.color
	Widgets.clear(bullets)
	for index, text in ipairs(copy.bullets) do
		Widgets.label({
			Text = "•  " .. text,
			TextSize = Theme.text.body,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = bullets,
		})
	end
	winLabel.Text = "HOW YOU WIN: " .. copy.win
	firstMoveLabel.Text = "FIRST MOVE: " .. copy.firstMove
	aliasLabel.Text = "Your alias: " .. tostring(payload.alias)
	nameLabel.Text = string.upper(tostring(payload.realName))
	alliesLabel.Text = alliesText(role, payload.allies)
	hintLabel.Visible = type(payload.hint) == "string"
	hintLabel.Text = if type(payload.hint) == "string" then Terms.f("{BUTLER}'S HINT: ") .. payload.hint else ""
	footerLabel.Text = string.format(
		"%d players  ·  %d %s  ·  %s",
		payload.playerCount or 0,
		payload.followers or 0,
		if payload.followers == 1 then Terms.role("Follower") else Terms.role("Follower", "plural"),
		tostring(payload.mapName)
	)
	root.Visible = true
	Router.setBlocking("briefing", true)
	Motion.pop(column)
	if unbindTimer then
		unbindTimer()
	end
	unbindTimer = Clock.bind(timerLabel, function(seconds: number)
		return string.format("The investigation begins in %d", math.ceil(seconds))
	end)
end

function BriefingScreen.init()
	root = Widgets.frame({
		Name = "Briefing",
		BackgroundTransparency = 0.06,
		BackgroundColor3 = Theme.colors.backdrop,
		Visible = false,
		Parent = Screens.overlay,
	})
	column = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.94),
		Parent = root,
	})
	Widgets.sizeLimit(column, Vector2.new(720, 760))
	Widgets.list(column, Theme.space.sm, false, Enum.HorizontalAlignment.Center)

	local function centered(props)
		props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
		props.Parent = column
		props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.Y
		return Widgets.label(props)
	end

	centered({
		Text = "YOUR ROLE",
		TextColor3 = Theme.colors.muted,
		Font = Theme.fonts.black,
		TextSize = Theme.text.small,
		LayoutOrder = 1,
	})
	roleLabel = centered({ Font = Theme.fonts.black, TextSize = 52, LayoutOrder = 2 })
	bullets = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = column,
	})
	Widgets.list(bullets, Theme.space.xs)
	winLabel = centered({
		Font = Theme.fonts.bold,
		TextColor3 = Theme.colors.gold,
		TextSize = Theme.text.body,
		LayoutOrder = 4,
	})
	firstMoveLabel = centered({
		Font = Theme.fonts.medium,
		TextColor3 = Theme.colors.muted,
		TextSize = Theme.text.small,
		LayoutOrder = 5,
	})
	Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.colors.accent,
		Size = UDim2.fromOffset(48, 2),
		LayoutOrder = 6,
		Parent = column,
	})
	aliasLabel = centered({ Font = Theme.fonts.bold, TextSize = Theme.text.title, LayoutOrder = 7 })
	centered({
		Text = "YOUR REAL NAME",
		TextColor3 = Theme.colors.muted,
		Font = Theme.fonts.black,
		TextSize = Theme.text.small,
		LayoutOrder = 8,
	})
	nameLabel = centered({
		Font = Theme.fonts.typewriter,
		TextSize = 44,
		TextColor3 = Theme.colors.paper,
		LayoutOrder = 9,
	})
	centered({
		Text = Terms.f(
			"Keep it secret: {hand} needs it to kill you, {zero} needs it to arrest. Hold C any time to see it again."
		),
		TextColor3 = Theme.colors.bad,
		TextSize = Theme.text.small,
		LayoutOrder = 10,
	})
	alliesLabel = centered({ Font = Theme.fonts.medium, TextSize = Theme.text.body, LayoutOrder = 11 })
	hintLabel = centered({
		Font = Theme.fonts.typewriter,
		TextSize = Theme.text.title,
		TextColor3 = Theme.colors.team,
		LayoutOrder = 12,
	})
	footerLabel = centered({ TextSize = Theme.text.small, TextColor3 = Theme.colors.muted, LayoutOrder = 13 })
	timerLabel = centered({
		Font = Theme.fonts.bold,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = Theme.colors.gold,
		LayoutOrder = 14,
	})

	Net.event("Briefing").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			BriefingScreen.show(payload)
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Briefing" and root.Visible then
			hide()
		end
	end)
end

return BriefingScreen
