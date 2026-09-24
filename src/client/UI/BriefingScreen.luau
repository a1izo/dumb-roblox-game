-- The briefing: role, alias, allies and the player's real name, shown exactly once.
-- The real name is wiped from the UI as soon as the briefing ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local BriefingScreen = {}

local root: Frame
local roleLabel: TextLabel
local blurbLabel: TextLabel
local aliasLabel: TextLabel
local nameLabel: TextLabel
local alliesLabel: TextLabel
local hintLabel: TextLabel
local footerLabel: TextLabel
local timerLabel: TextLabel
local token = 0

local function hide()
	root.Visible = false
	Router.setBlocking("briefing", false)
	nameLabel.Text = ""
	hintLabel.Text = ""
	alliesLabel.Text = ""
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
	token += 1
	local myToken = token
	local info = Roles.get(payload.role)
	roleLabel.Text = info.display
	roleLabel.TextColor3 = info.color
	blurbLabel.Text = info.blurb
	aliasLabel.Text = "Your alias: " .. tostring(payload.alias)
	nameLabel.Text = string.upper(tostring(payload.realName))
	alliesLabel.Text = alliesText(payload.role, payload.allies)
	if type(payload.hint) == "string" then
		hintLabel.Text = Terms.f("{BUTLER}'S HINT") .. "\n" .. payload.hint
		hintLabel.Visible = true
	else
		hintLabel.Visible = false
	end
	footerLabel.Text = string.format(
		"%d players  |  %d %s  |  %s",
		payload.playerCount or 0,
		payload.followers or 0,
		if payload.followers == 1 then Terms.role("Follower") else Terms.role("Follower", "plural"),
		tostring(payload.mapName)
	)
	root.Visible = true
	Router.setBlocking("briefing", true)
	local endsAt = os.clock() + (tonumber(payload.duration) or 12)
	task.spawn(function()
		while token == myToken and os.clock() < endsAt do
			timerLabel.Text = string.format("The investigation begins in %d", math.ceil(endsAt - os.clock()))
			task.wait(0.2)
		end
		if token == myToken then
			hide()
		end
	end)
end

function BriefingScreen.init()
	root = Widgets.frame({
		Name = "Briefing",
		BackgroundTransparency = 0.08,
		BackgroundColor3 = Theme.colors.backdrop,
		Visible = false,
		Parent = Screens.overlay,
	})
	local column = Widgets.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		Parent = root,
	})
	Widgets.sizeLimit(column, Vector2.new(760, 640))
	Widgets.list(column, 10, false, Enum.HorizontalAlignment.Center)

	local function centered(props)
		props.TextXAlignment = Enum.TextXAlignment.Center
		props.Parent = column
		return Widgets.label(props)
	end

	centered({
		Text = "YOUR ROLE",
		TextColor3 = Theme.colors.muted,
		Font = Theme.fonts.bold,
		TextSize = 14,
		LayoutOrder = 1,
	})
	roleLabel = centered({ Font = Theme.fonts.black, TextSize = 54, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 2 })
	blurbLabel =
		centered({ TextSize = 16, TextColor3 = Theme.colors.text, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 3 })
	aliasLabel = centered({ Font = Theme.fonts.bold, TextSize = 20, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 4 })
	centered({
		Text = "YOUR REAL NAME",
		TextColor3 = Theme.colors.muted,
		Font = Theme.fonts.bold,
		TextSize = 14,
		LayoutOrder = 5,
	})
	nameLabel = centered({
		Font = Theme.fonts.typewriter,
		TextSize = 46,
		TextColor3 = Theme.colors.paper,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 6,
	})
	centered({
		Text = Terms.f(
			"Memorise it. It will not be shown again. {Hand} needs it to kill you; {zero} needs it to arrest."
		),
		TextColor3 = Theme.colors.bad,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 7,
	})
	alliesLabel = centered({ Font = Theme.fonts.medium, TextSize = 17, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 8 })
	hintLabel = centered({
		Font = Theme.fonts.typewriter,
		TextSize = 20,
		TextColor3 = Theme.colors.team,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 9,
	})
	footerLabel = centered({ TextSize = 14, TextColor3 = Theme.colors.muted, LayoutOrder = 10 })
	timerLabel = centered({ Font = Theme.fonts.bold, TextSize = 18, TextColor3 = Theme.colors.gold, LayoutOrder = 11 })

	Net.event("Briefing").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			BriefingScreen.show(payload)
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase ~= "Briefing" and root.Visible then
			token += 1
			hide()
		end
	end)
end

return BriefingScreen
