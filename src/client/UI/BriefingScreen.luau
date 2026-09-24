-- The briefing, "angular manga" style: a red band cuts across the screen, your role slams in
-- on a huge tilted ribbon, the three things to know sit on a paper card, and your real name
-- is typed on a black card stamped SECRET. Everything here can be seen again later on the
-- role card (hold C).

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

local C = Theme.colors

local BriefingScreen = {}

local root: Frame
local band: Frame
local roleRibbon: Frame
local roleLabel: TextLabel
local rulesCard: Frame
local bullets: Frame
local winLabel: TextLabel
local firstMoveLabel: TextLabel
local nameCard: Frame
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
	local handSide = role == "Kira" or role == "Follower"
	roleLabel.Text = info.display
	roleRibbon.BackgroundColor3 = if handSide then C.accent else C.paper
	roleLabel.TextColor3 = if handSide then C.paper else C.ink
	band.BackgroundColor3 = if handSide then C.ink else C.accent
	root.BackgroundColor3 = if handSide then Color3.fromRGB(40, 4, 8) else C.backdrop
	Widgets.clear(bullets)
	for index, text in ipairs(copy.bullets) do
		Widgets.label({
			Text = "▶  " .. text,
			TextSize = Theme.text.body,
			TextColor3 = C.ink,
			Font = Theme.fonts.medium,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = bullets,
		})
	end
	winLabel.Text = "HOW YOU WIN: " .. string.upper(copy.win)
	firstMoveLabel.Text = "FIRST MOVE: " .. copy.firstMove
	aliasLabel.Text = "ALIAS: " .. string.upper(tostring(payload.alias))
	nameLabel.Text = string.upper(tostring(payload.realName))
	alliesLabel.Text = alliesText(role, payload.allies)
	hintLabel.Visible = type(payload.hint) == "string"
	hintLabel.Text = if type(payload.hint) == "string" then Terms.f("{BUTLER}'S HINT: ") .. payload.hint else ""
	footerLabel.Text = string.upper(
		string.format(
			"%d players  ·  %d %s  ·  %s",
			payload.playerCount or 0,
			payload.followers or 0,
			if payload.followers == 1 then Terms.role("Follower") else Terms.role("Follower", "plural"),
			tostring(payload.mapName)
		)
	)
	root.Visible = true
	Router.setBlocking("briefing", true)
	Motion.slideIn(roleRibbon, Vector2.new(-400, 0), 0.35)
	Motion.slideIn(rulesCard, Vector2.new(0, 60), 0.45)
	Motion.slideIn(nameCard, Vector2.new(0, 80), 0.55)
	if unbindTimer then
		unbindTimer()
	end
	unbindTimer = Clock.bind(timerLabel, function(seconds: number)
		return string.format("THE INVESTIGATION BEGINS IN %d", math.ceil(seconds))
	end)
end

function BriefingScreen.init()
	root = Widgets.frame({
		Name = "Briefing",
		BackgroundTransparency = 0.02,
		BackgroundColor3 = C.backdrop,
		ClipsDescendants = true,
		Visible = false,
		Parent = Screens.overlay,
	})
	-- The red band cutting across the screen.
	band = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.accent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(2, 0, 0, 150),
		Rotation = -8,
		Parent = root,
	})

	local column = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.94),
		Parent = root,
	})
	Widgets.sizeLimit(column, Vector2.new(760, 800))
	Widgets.list(column, Theme.space.md, false, Enum.HorizontalAlignment.Center)

	Widgets.display({
		Text = "YOUR ROLE",
		TextSize = Theme.text.bodyLarge,
		TextColor3 = C.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = column,
	})
	roleRibbon = Widgets.frame({
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(0, 82),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -4,
		LayoutOrder = 2,
		Parent = column,
	})
	Widgets.slant(roleRibbon, 0.05)
	Widgets.padding(roleRibbon, 0, 56)
	roleLabel = Widgets.display({
		TextSize = 64,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = roleRibbon,
	})

	rulesCard = Widgets.card({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Rotation = 1,
		LayoutOrder = 3,
		Parent = column,
	})
	Widgets.padding(rulesCard, Theme.space.lg, Theme.space.xl)
	Widgets.list(rulesCard, Theme.space.sm)
	bullets = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = rulesCard,
	})
	Widgets.list(bullets, Theme.space.xs)
	winLabel = Widgets.label({
		FontFace = Theme.faces.display,
		TextSize = Theme.text.bodyLarge,
		TextColor3 = C.accent,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = rulesCard,
	})
	firstMoveLabel = Widgets.label({
		Font = Theme.fonts.medium,
		TextSize = Theme.text.small,
		TextColor3 = C.inkMuted,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = rulesCard,
	})

	-- The name card and its SECRET stamp share a holder, so the stamp stays out of the
	-- card's list layout.
	local nameHolder = Widgets.frame({
		Size = UDim2.new(0.8, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = column,
	})
	nameCard = Widgets.frame({
		BackgroundTransparency = 0,
		BackgroundColor3 = C.ink,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Rotation = -1,
		Parent = nameHolder,
	})
	Widgets.stroke(nameCard, C.paper, 2, 0)
	Widgets.padding(nameCard, Theme.space.md, Theme.space.xl)
	Widgets.list(nameCard, Theme.space.xs, false, Enum.HorizontalAlignment.Center)
	aliasLabel = Widgets.display({
		TextSize = Theme.text.bodyLarge,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = nameCard,
	})
	Widgets.display({
		Text = "YOUR REAL NAME",
		TextSize = Theme.text.small,
		TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = nameCard,
	})
	nameLabel = Widgets.label({
		Font = Theme.fonts.typewriter,
		TextSize = 44,
		TextColor3 = C.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 3,
		Parent = nameCard,
	})
	Widgets.label({
		Text = Terms.f(
			"Keep it secret: {hand} needs it to kill you, {zero} needs it to arrest. Hold C any time to see it again."
		),
		TextSize = Theme.text.small,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = nameCard,
	})
	-- The SECRET stamp in the corner of the name card.
	local stamp = Widgets.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 16, 0, -14),
		Size = UDim2.fromOffset(110, 34),
		Rotation = 12,
		ZIndex = 3,
		Parent = nameHolder,
	})
	Widgets.stroke(stamp, C.accent, 3, 0)
	Widgets.display({
		Text = "SECRET",
		TextSize = Theme.text.title,
		TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = stamp,
	})

	alliesLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.body,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = column,
	})
	hintLabel = Widgets.label({
		Font = Theme.fonts.typewriter,
		TextSize = Theme.text.title,
		TextColor3 = C.team,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = column,
	})
	footerLabel = Widgets.label({
		FontFace = Theme.faces.displayMedium,
		TextSize = Theme.text.small,
		TextColor3 = C.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 7,
		Parent = column,
	})
	timerLabel = Widgets.display({
		TextSize = Theme.text.bodyLarge,
		TextColor3 = C.paper,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 8,
		Parent = column,
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
