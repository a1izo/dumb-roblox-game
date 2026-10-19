-- The briefing: your role's own cutscene (made in Blender, art/scripts/cinema/shots/role_*.py, every
-- one the same length), with you in it and the allies you know, and your role card running over it as
-- captions: who you are, how you win, your first move, then your alias, your real name in red, your
-- allies. Without the cutscene two panels show the same. Everything here
-- can be seen again on the role card (hold C).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RoleCopy = require(Shared:WaitForChild("Copy"):WaitForChild("RoleCopy"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Clock = require(script.Parent.Core.Clock)
local Keys = require(script.Parent.Parent.Input.Keys)
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
	local kira, ace = nil, nil
	for _, ally in ipairs(allies or {}) do
		if ally.role == "Kira" then
			kira = ally.alias
		elseif ally.role == "L" then
			ace = ally.alias
		end
	end
	if role == "Kira" then
		return Terms.f("You do not know your {cultists}, and they know you. A name you write could be theirs.")
	elseif role == "Follower" then
		return Terms.f("{Hand} is {alias}. They do not know you.", { alias = kira or "unknown" })
	elseif role == "L" then
		return Terms.f("Only {butler} knows who you are. You do not know {butler}.")
	elseif role == "Watari" then
		return Terms.f("{Zero} is {alias}. {Zero} does not know you.", { alias = ace or "unknown" })
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
		tone = "black",
		padding = T.space.xl,
		Size = if phone then UDim2.new(1, 0, 0.55, 0) else UDim2.fromOffset(460, 540),
		LayoutOrder = 1,
		Parent = holder,
	})
	Kit.list(cardContent, T.space.s)
	local top = Kit.frame({ Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1, Parent = cardContent })
	Kit.seal({
		size = 72,
		color = if hostile then C.red else C.steel,
		icon = ROLE_ICON[role],
		portrait = Players.LocalPlayer.UserId,
		Parent = top,
	})
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
		face = "Head",
		text = info.display,
		size = T.size.heading + 6,
		color = if hostile then C.red else C.bone,
		Position = UDim2.fromOffset(84, 22),
		Parent = top,
	})
	roleName:write(0.6)
	Kit.label({
		Text = "How you win: " .. Keys.resolve(copy.win),
		font = "bodyBold",
		size = "small",
		color = C.white,
		LayoutOrder = 2,
		Parent = cardContent,
	})
	for index, text in ipairs(copy.bullets) do
		Kit.label({
			Text = "·  " .. Keys.resolve(text),
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
		Text = Keys.resolve(copy.firstMove),
		font = "document",
		size = "body",
		color = C.bone,
		LayoutOrder = 12,
		Parent = cardContent,
	})

	-- Your secret page.
	local page, pageContent = Kit.page({
		tone = "raised",
		padding = T.space.xl,
		Size = if phone then UDim2.new(1, 0, 0.4, 0) else UDim2.fromOffset(440, 520),
		LayoutOrder = 2,
		Parent = holder,
	})
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
		Kit.text({ face = "Head", text = tostring(payload.alias), size = 44, LayoutOrder = 2, Parent = pageContent })
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
		face = "Head",
		text = tostring(payload.realName),
		size = 48,
		color = C.danger,
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

-- The captions the role cutscene asks for, by key (its "card" events).
local function caption(key: string, payload): (() -> ())?
	local Cinema = require(script.Parent.Parent.Presentation.Cinema) :: any
	local role = payload.role or "TaskForce"
	local info = Roles.get(role)
	local copy = RoleCopy[role] or RoleCopy.TaskForce
	local hostile = role == "Kira" or role == "Follower"
	if key == "role" then
		return Cinema.caption(
			"YOU ARE",
			{ { text = info.display, head = true, color = if hostile then C.red else C.bone } }
		)
	elseif key == "win" then
		return Cinema.caption("HOW YOU WIN", { { text = Keys.resolve(copy.win), font = "bodyBold", size = "body" } })
	elseif key == "move" then
		return Cinema.caption(
			"FIRST MOVE",
			{ { text = Keys.resolve(copy.firstMove), font = "document", size = "body" } }
		)
	elseif key == "names" then
		local lines: { any } = {
			{ text = tostring(payload.alias), head = true, size = 40 },
			{ text = "YOUR REAL NAME", font = "label", size = "micro", color = C.dim },
			{ text = tostring(payload.realName), head = true, size = 40, color = C.danger },
			{ text = alliesText(role, payload.allies), size = "small" },
		}
		return Cinema.caption("YOUR ALIAS", lines)
	end
	return nil
end

local function showPanels(payload)
	build(payload)
	root.Visible = true
	if unbindTimer then
		unbindTimer()
	end
	unbindTimer = Clock.bind(timerLabel, function(seconds: number)
		return string.format("The investigation begins in %d", math.ceil(seconds))
	end)
end

function BriefingScreen.show(payload)
	showing += 1
	local mine = showing
	root.Visible = false
	Router.setBlocking("briefing", true)
	-- Lazily required: Presentation needs the UI to exist first.
	local ShotPlayer = require(script.Parent.Parent.Presentation.ShotPlayer) :: any
	if type(payload.shot) ~= "string" or not ShotPlayer.exists(payload.shot) then
		showPanels(payload)
		return
	end
	task.spawn(function()
		local ok, err = pcall(ShotPlayer.play, payload.shot, {
			at = tonumber(payload.at),
			cast = if type(payload.cast) == "table" then payload.cast else {},
			onCard = function(key: string)
				return caption(key, payload)
			end,
			stop = function()
				return showing ~= mine or ClientState.phase() ~= "Briefing"
			end,
		})
		if not ok then
			warn("[DeathsGambit] Role cutscene failed: " .. tostring(err))
			if showing == mine and ClientState.phase() == "Briefing" then
				showPanels(payload)
			end
		end
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
