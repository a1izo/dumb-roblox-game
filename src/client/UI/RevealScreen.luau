-- The reveal, when the case closes: the winning side on a brush stroke with a CASE CLOSED
-- stamp, every role and real name on the left page, a replay of the key events on the right,
-- and your rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)

local C = Kit.color
local T = Kit.Tokens

local RevealScreen = {}

local HOSTILE = { Kira = true, Follower = true } -- terms:ok (internal ids)
local TOP = 150 -- the title block

local root: Frame
local titleHolder: Frame
local reasonText: any
local roster: ScrollingFrame
local timeline: ScrollingFrame
local rewardsLabel: TextLabel
local token = 0

local function fillRoster(players)
	Kit.clear(roster)
	for index, entry in ipairs(players) do
		local info = Roles.get(entry.role)
		local row = Kit.frame({ Name = "Line", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = index, Parent = roster })
		local name = string.format("%s  (%s)", tostring(entry.alias), tostring(entry.displayName))
		if type(entry.title) == "string" and entry.title ~= "" then
			name ..= "  ·  " .. string.upper(entry.title)
		end
		Kit.label({
			Text = name,
			font = "bodyBold",
			size = "small",
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0.62, 0, 0, 22),
			Parent = row,
		})
		Kit.label({
			Text = string.upper(tostring(entry.realName)),
			font = "document",
			size = "small",
			color = C.parchment,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(0.62, 0, 0, 20),
			Parent = row,
		})
		Kit.label({
			Text = info.display,
			font = "label",
			size = "small",
			color = if HOSTILE[entry.role] then C.red else C.steel,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromScale(0.62, 0),
			Size = UDim2.new(0.38, 0, 0, 22),
			Parent = row,
		})
		local status = Terms.status(tostring(entry.status))
		if entry.cause then
			status ..= " · " .. tostring(entry.cause)
		end
		Kit.label({
			Text = status,
			size = "micro",
			color = C.dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.new(0.62, 0, 0, 24),
			Size = UDim2.new(0.38, 0, 0, 20),
			Parent = row,
		})
		Kit.rule({ Position = UDim2.new(0, 0, 1, -1), Parent = row })
	end
end

local function playTimeline(events, myToken: number)
	Kit.clear(timeline)
	for index, event in ipairs(events) do
		if token ~= myToken then
			return
		end
		local isHand = event.kind == "kill"
			or event.kind == "eyes"
			or event.kind == "burn"
			or event.kind == "fake"
			or event.kind == "tamper"
		Kit.label({
			Text = string.format("R%s %s   %s", tostring(event.round), tostring(event.time), tostring(event.text)),
			font = if event.kind == "role" then "bodyItalic" else "body",
			size = "small",
			color = if isHand then C.red elseif event.kind == "role" then C.dim else C.bone,
			LayoutOrder = index,
			Parent = timeline,
		})
		timeline.CanvasPosition = Vector2.new(0, 1e6)
		task.wait(if event.kind == "role" then 0.08 else 0.4)
	end
end

local function rewardsText(rewards): string
	if type(rewards) ~= "table" then
		return "You watched this case from the lobby."
	end
	local lines = {
		string.format(
			"%s   +%d coins   +%d XP",
			if rewards.won then "Victory" else "Defeat",
			rewards.coins,
			rewards.xp
		),
	}
	for _, line in ipairs(rewards.lines or {}) do
		table.insert(lines, string.format("%s: +%d coins, +%d XP", tostring(line.label), line.coins, line.xp))
	end
	local progress = rewards.progress
	if type(progress) == "table" then
		if type(progress.rankUp) == "table" then
			local rank = Ranks.LIST[tonumber(progress.rankUp.to) or 1]
			table.insert(lines, "Rank up: " .. (if rank then rank.name else "?"))
		end
		if type(progress.masteryLevel) == "table" and type(progress.role) == "string" then
			table.insert(
				lines,
				string.format(
					"%s mastery: level %d",
					Roles.get(progress.role).display,
					tonumber(progress.masteryLevel.to) or 1
				)
			)
		end
		if type(progress.unlocked) == "table" and #progress.unlocked > 0 then
			table.insert(lines, "Unlocked: " .. table.concat(progress.unlocked, ", "))
		end
	end
	return table.concat(lines, "\n")
end

local function close()
	token += 1
	root.Visible = false
	Router.setBlocking("reveal", false)
end

function RevealScreen.show(payload)
	token += 1
	local myToken = token
	local teamWon = payload.winner == "Team"
	Kit.clear(titleHolder)
	local banner = Kit.banner({
		text = if teamWon then Terms.f("{Agency} wins") else Terms.f("{Hand} wins"),
		size = T.size.display,
		tone = if teamWon then C.steel:Lerp(C.void, 0.4) else C.blood,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = titleHolder,
	})
	banner.Rotation = -2
	Kit.stamp({
		text = "Case closed",
		width = 200,
		rotation = -10,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.5, 150, 0, 40),
		Parent = titleHolder,
	})
	reasonText:set(tostring(payload.reason or ""))
	fillRoster(payload.players or {})
	rewardsLabel.Text = rewardsText(payload.rewards)
	root.Visible = true
	Router.setBlocking("reveal", true)
	task.spawn(playTimeline, payload.events or {}, myToken)
end

local function page(title: string, props): ScrollingFrame
	local frame, content = Kit.page({
		tone = "black",
		ruled = true,
		padding = T.space.l,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size,
		Parent = props.Parent,
	})
	local _ = frame
	Kit.heading({ text = title, Parent = content })
	local scroll = Kit.scroll({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), Parent = content })
	Kit.list(scroll, T.space.xs)
	return scroll
end

function RevealScreen.init()
	root = Kit.frame({ Name = "Reveal", Visible = false, Parent = Screens.overlay })
	root.BackgroundColor3 = C.void
	root.BackgroundTransparency = 0.04
	-- Darkened edges behind the spread.
	Kit.vignette(root, 0.8).ZIndex = 0
	local window = Kit.frame({
		Name = "Spread",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.92),
		Parent = root,
	})
	Kit.Base.maxSize(window, Vector2.new(1100, 720))
	titleHolder = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 100), Parent = window })
	reasonText = Kit.text({
		face = "Scrawl",
		text = "",
		size = 30,
		color = C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Parent = window,
	})
	roster = page("Roles and real names", {
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(0.45, -T.space.s, 1, -(TOP + 72)),
		Parent = window,
	})
	timeline = page("Case replay", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, TOP),
		Size = UDim2.new(0.55, -T.space.s, 1, -(TOP + 72)),
		Parent = window,
	})
	rewardsLabel = Kit.label({
		font = "bodyBold",
		size = "small",
		color = C.candle,
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -160, 0, 60),
		Parent = window,
	})
	Kit.button({
		text = "Close",
		variant = "primary",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(140, T.touch),
		Parent = window,
	}, close)

	Net.event("Reveal").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			RevealScreen.show(payload)
		end
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase == "Briefing" then
			close()
		end
	end)
end

return RevealScreen
