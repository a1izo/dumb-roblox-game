-- The briefing. First your own avatar acts out your role on a dark set (Presentation/RoleReveal,
-- the same length for every role), then two pages open: a parchment card with your role, how
-- you win, the three things to know and your first move; and a black page with your alias and
-- your real name written in red, your allies, and (for the Butler) the hint. Everything here
-- can be seen again on the role card (hold C).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RoleCopy = require(Shared:WaitForChild("Copy"):WaitForChild("RoleCopy"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local BriefingScreen = {}

local ROLE_ICON = { Kira = "hand", Follower = "cultist", L = "zero", Watari = "butler", TaskForce = "agency" } -- terms:ok

local root: Frame
local body: Frame
local timerLabel: TextLabel
local unbindTimer: (() -> ())? = nil
local showing = 0

local function hide()
	showing += 1
	root.Visible = false
	Router.setBlocking("briefing", false)
	Kit.clear(body)
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

local function build(payload)
	Kit.clear(body)
	local role = payload.role or "TaskForce"
	local info = Roles.get(role)
	local copy = RoleCopy[role] or RoleCopy.TaskForce
	local hostile = role == "Kira" or role == "Follower"
	local phone = Kit.Layout.isPhone()

	local holder = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = if phone then UDim2.fromScale(0.96, 0.84) else UDim2.fromOffset(940, 560),
		Parent = body,
	})
	local list = Kit.list(holder, T.space.l, not phone, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	-- The role card.
	local card, cardContent = Kit.page({
		tone = "parchment",
		padding = T.space.xl,
		Size = if phone then UDim2.new(1, 0, 0.55, 0) else UDim2.fromOffset(460, 540),
		Rotation = -1,
		LayoutOrder = 1,
		Parent = holder,
	})
	card.Rotation = if phone then 0 else -1.5
	Kit.list(cardContent, T.space.s)
	local top = Kit.frame({ Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1, Parent = cardContent })
	Kit.seal({ size = 72, color = if hostile then C.red else C.steel, icon = ROLE_ICON[role], Parent = top })
	Kit.label({
		Text = "YOU ARE",
		font = "label",
		size = "micro",
		color = C.dim,
		Position = UDim2.fromOffset(86, 6),
		Size = UDim2.new(1, -86, 0, 14),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = top,
	})
	local roleName = Kit.text({
		face = "Gothic",
		text = info.display,
		size = T.size.heading + 6,
		color = if hostile then C.red else C.bone,
		Position = UDim2.fromOffset(84, 22),
		Parent = top,
	})
	roleName:write(0.6, C.red)
	Kit.label({
		Text = "How you win: " .. copy.win,
		font = "bodyBold",
		size = "small",
		color = C.red,
		LayoutOrder = 2,
		Parent = cardContent,
	})
	for index, text in ipairs(copy.bullets) do
		Kit.label({
			Text = "·  " .. text,
			size = "small",
			color = C.bone,
			LayoutOrder = 2 + index,
			Parent = cardContent,
		})
	end
	Kit.rule({ color = C.bone, transparency = 0.7, LayoutOrder = 10, Parent = cardContent })
	Kit.label({
		Text = "FIRST MOVE",
		font = "label",
		size = "micro",
		color = C.dim,
		LayoutOrder = 11,
		Parent = cardContent,
	})
	Kit.label({
		Text = copy.firstMove,
		font = "document",
		size = "body",
		color = C.bone,
		LayoutOrder = 12,
		Parent = cardContent,
	})

	-- Your secret page.
	local page, pageContent = Kit.page({
		tone = "black",
		ruled = true,
		margin = true,
		padding = T.space.xl,
		Size = if phone then UDim2.new(1, 0, 0.4, 0) else UDim2.fromOffset(440, 520),
		LayoutOrder = 2,
		Parent = holder,
	})
	page.Rotation = if phone then 0 else 1.2
	Kit.list(pageContent, T.space.xs)
	Kit.label({
		Text = "YOUR ALIAS",
		font = "label",
		size = "micro",
		color = C.dim,
		LayoutOrder = 1,
		Parent = pageContent,
	})
	local alias =
		Kit.text({ face = "Scrawl", text = tostring(payload.alias), size = 48, LayoutOrder = 2, Parent = pageContent })
	alias:write(0.5)
	Kit.label({
		Text = "YOUR REAL NAME",
		font = "label",
		size = "micro",
		color = C.dim,
		LayoutOrder = 3,
		Parent = pageContent,
	})
	local name = Kit.text({
		face = "Scrawl",
		text = tostring(payload.realName),
		size = 60,
		color = C.red,
		LayoutOrder = 4,
		Parent = pageContent,
	})
	task.delay(0.5, function()
		name:write(0.9)
	end)
	Kit.label({
		Text = "Never say it. Anyone who writes it down can kill you.",
		font = "bodyItalic",
		size = "small",
		color = C.dim,
		LayoutOrder = 5,
		Parent = pageContent,
	})
	Kit.frame({ Size = UDim2.new(1, 0, 0, T.space.m), LayoutOrder = 6, Parent = pageContent })
	Kit.label({ Text = alliesText(role, payload.allies), size = "small", LayoutOrder = 7, Parent = pageContent })
	if type(payload.hint) == "string" then
		Kit.label({
			Text = Terms.f("{Butler}'s hint: ") .. payload.hint,
			font = "document",
			size = "small",
			color = C.steel,
			LayoutOrder = 8,
			Parent = pageContent,
		})
	end
	Kit.label({
		Text = string.format(
			"%d players  ·  %d %s  ·  %s",
			payload.playerCount or 0,
			payload.followers or 0,
			if payload.followers == 1 then Terms.role("Follower") else Terms.role("Follower", "plural"),
			tostring(payload.mapName)
		),
		font = "label",
		size = "micro",
		color = C.faint,
		LayoutOrder = 9,
		Parent = pageContent,
	})
	Motion.slideIn(card, Vector2.new(-80, 0), T.motion.slow)
	Motion.slideIn(page, Vector2.new(80, 0), T.motion.slow)
end

function BriefingScreen.show(payload)
	showing += 1
	local mine = showing
	root.Visible = false
	Router.setBlocking("briefing", true)
	-- Lazily required: Presentation needs the UI to exist first.
	local RoleReveal = require(script.Parent.Parent.Presentation.RoleReveal) :: any
	task.spawn(function()
		local ok, err = pcall(RoleReveal.play, payload.role or "TaskForce")
		if not ok then
			warn("[DeathsGambit] Role reveal failed: " .. tostring(err))
		end
		if showing ~= mine or ClientState.phase() ~= "Briefing" then
			return
		end
		build(payload)
		root.Visible = true
		if unbindTimer then
			unbindTimer()
		end
		unbindTimer = Clock.bind(timerLabel, function(seconds: number)
			return string.format("The investigation begins in %d", math.ceil(seconds))
		end)
	end)
end

function BriefingScreen.init()
	root = Kit.Base.make("Frame", {
		Name = "Briefing",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = Screens.overlay,
	})
	Kit.vignette(root, 0.8)
	body = Kit.frame({ Name = "Body", Parent = root })
	timerLabel = Kit.label({
		Text = "",
		font = "label",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = root,
	})

	Net.event("Briefing").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			BriefingScreen.show(payload)
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Briefing" then
			hide()
		end
	end)
end

return BriefingScreen
