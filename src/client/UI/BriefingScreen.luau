-- The briefing: your role's own cutscene (made in Blender, art/scripts/cinema/shots/role_*.py), with you in it and the
-- allies you know: a voiced role's line typed as it is said (the Operative's scene runs your role card as captions).
-- Then your role card stays up to read until the investigation begins: who you are, how you win, your first move,
-- your alias, your real name in red, your allies. The briefing lasts the match's longest cutscene and a hold, the same
-- for everyone. Without the cutscene the card shows from the start. Everything here can be seen again on the role card
-- (hold C).

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
		return Terms.f("Your {cultists} know you. You don't know them.")
	elseif role == "Follower" then
		return Terms.f("{Hand} is {alias}. They don't know you.", { alias = kira or "unknown" })
	elseif role == "L" then
		return Terms.f("Only {butler} knows who you are.")
	elseif role == "Watari" then
		return Terms.f("{Zero} is {alias}. They don't know you.", { alias = ace or "unknown" })
	end
	return "Trust no one."
end

-- A line in the big title font, kept out of the Melodrama mirror.
local function bigText(props: { [string]: any }): TextLabel
	local label = Kit.label({
		Text = props.text,
		font = "title",
		size = props.size,
		color = props.color or C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
	})
	label:SetAttribute("KeepFont", true)
	label.Parent = props.Parent
	return label
end

local function mono(text: string, props: { [string]: any }): TextLabel
	return Kit.label({
		Text = text,
		font = "mono",
		size = props.size or "small",
		color = props.color or C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		Parent = props.Parent,
	})
end

-- The role poster (concept A): your real name large in the serif, your alias in mono, three short rules
-- numbered in red, and the role itself huge and lowercase across the foot, red for Diavolo's side.
local function build(payload)
	Kit.clear(body)
	local role = payload.role or "TaskForce"
	local info = Roles.get(role)
	local copy = RoleCopy[role] or RoleCopy.TaskForce
	local hostile = role == "Kira" or role == "Follower"
	local phone = Kit.Layout.isPhone()
	local left = if phone then T.space.l else T.space.xxxl

	local holder = Kit.frame({ Name = "Poster", Parent = body })
	mono(
		string.format(
			"%s   %d PLAYERS   %d %s",
			string.upper(tostring(payload.mapName)),
			payload.playerCount or 0,
			payload.followers or 0,
			string.upper(if payload.followers == 1 then Terms.role("Follower") else Terms.role("Follower", "plural"))
		),
		{ Position = UDim2.fromOffset(left, T.space.xl), Parent = holder }
	)
	mono("YOUR REAL NAME", { Position = UDim2.fromOffset(left, 84), Parent = holder })
	local name = Kit.text({
		face = "Head",
		text = tostring(payload.realName),
		size = if phone then 52 else 84,
		color = C.bone,
		Position = UDim2.fromOffset(left - 4, 100),
		Parent = holder,
	})
	task.delay(0.3, function()
		name:write(0.9)
	end)
	mono(string.format("ALIAS %s   NEVER SAY IT", string.upper(tostring(payload.alias))), {
		color = C.bone,
		Position = UDim2.fromOffset(left, if phone then 164 else 200),
		Parent = holder,
	})
	local rules = Kit.frame({
		Name = "Rules",
		Position = UDim2.fromOffset(left, if phone then 200 else 250),
		Size = UDim2.fromOffset(if phone then 320 else 560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	})
	Kit.list(rules, T.space.m)
	for index, text in ipairs(copy.bullets) do
		local row = Kit.frame({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Parent = rules,
		})
		mono(string.format("%02d", index), { color = C.danger, Position = UDim2.fromOffset(0, 3), Parent = row })
		Kit.label({
			Text = Keys.resolve(text),
			font = "bodyBold",
			size = if phone then "body" else "lead",
			color = C.bone,
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -36, 0, 0),
			Parent = row,
		})
	end
	mono(alliesText(role, payload.allies), {
		color = C.bone,
		Position = UDim2.fromOffset(left, if phone then 330 else 420),
		Parent = holder,
	})
	-- The role, huge across the foot and cut by the screen's bottom edge, boiling.
	local word = bigText({
		text = string.lower(info.display) .. ".",
		size = if phone then 110 else 220,
		color = if hostile then C.danger else C.bone,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, left - 12, 1, if phone then 30 else 56),
		Parent = holder,
	})
	Kit.Boil.attach(word, 2, 0.3)
	Motion.slideIn(holder, Vector2.new(0, 30), T.motion.slow)
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
	elseif key == "win" or key == "move" then
		-- (the owner, 2026-10-29: no "how you win" or first move on the card; the three rules say enough)
		return Cinema.caption("YOUR RULES", {
			{ text = Keys.resolve(copy.bullets[1] or ""), font = "bodyBold", size = "body" },
			{ text = Keys.resolve(copy.bullets[2] or ""), font = "bodyBold", size = "body" },
			{ text = Keys.resolve(copy.bullets[3] or ""), font = "bodyBold", size = "body" },
		})
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
		return string.format("BEGINS IN %02d", math.ceil(seconds))
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
			length = tonumber(payload.length),
			onCard = function(key: string)
				return caption(key, payload)
			end,
			stop = function()
				return showing ~= mine or ClientState.phase() ~= "Briefing"
			end,
		})
		if not ok then
			warn("[DeathsGambit] Role cutscene failed: " .. tostring(err))
		end
		-- (after the cutscene, the role card until the investigation begins)
		if showing == mine and ClientState.phase() == "Briefing" then
			showPanels(payload)
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
		font = "mono",
		size = "small",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -T.space.xxxl, 1, -18),
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
