-- The reveal, when the case closes: CASE CLOSED in ransom-note letters (two of them red when Diavolo's
-- side won), the winning side in Aktura beneath it, every role and real name on the left, a replay of the
-- key events on the right, and your rewards. On a phone the two pages stack. The winner line glitches
-- every couple of seconds.

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
local UiSound = require(script.Parent.Core.UiSound)

local C = Kit.color
local T = Kit.Tokens

local RevealScreen = {}

local HOSTILE = { Kira = true, Follower = true } -- terms:ok (internal ids)

local root: Frame
local titleHolder: Frame
local winnerHolder: CanvasGroup
local winnerText: any
local reasonText: any
local roster: ScrollingFrame
local timeline: ScrollingFrame
local rosterPage: Frame
local timelinePage: Frame
local ransom: any
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
			color = C.g6,
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

local handWon = false

-- CASE CLOSED, cut out of ransom-note letters at a size for the device.
local function buildTitle()
	Kit.clear(titleHolder)
	local phone = Kit.Layout.isPhone()
	ransom = Kit.ransom({
		text = "Case Closed",
		size = if phone then 34 else 56,
		hand = handWon,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = titleHolder,
	})
end

-- The title block is 190 px tall on a PC and 130 on a phone; below it the two pages sit side by side or
-- stacked. The close button and the rewards line take the bottom 72 px.
local function layout(class: string)
	local phone = class == "phone"
	local top = if phone then 132 else 196
	titleHolder.Size = UDim2.new(1, 0, 0, if phone then 44 else 70)
	winnerHolder.Position = UDim2.new(0.5, 0, 0, if phone then 48 else 76)
	winnerText:setSize(if phone then 26 else 44)
	reasonText.frame.Position = UDim2.new(0.5, 0, 0, if phone then 84 else 130)
	reasonText:setSize(if phone then 16 else 22)
	if phone then
		rosterPage.AnchorPoint = Vector2.new(0, 0)
		rosterPage.Position = UDim2.fromOffset(0, top)
		rosterPage.Size = UDim2.new(1, 0, 0.5, -(top / 2 + 36 + 4))
		timelinePage.AnchorPoint = Vector2.new(0, 1)
		timelinePage.Position = UDim2.new(0, 0, 1, -72)
		timelinePage.Size = UDim2.new(1, 0, 0.5, -(top / 2 + 36 + 4))
	else
		rosterPage.AnchorPoint = Vector2.new(0, 0)
		rosterPage.Position = UDim2.fromOffset(0, top)
		rosterPage.Size = UDim2.new(0.45, -T.space.s, 1, -(top + 72))
		timelinePage.AnchorPoint = Vector2.new(1, 0)
		timelinePage.Position = UDim2.new(1, 0, 0, top)
		timelinePage.Size = UDim2.new(0.55, -T.space.s, 1, -(top + 72))
	end
	if ransom then
		buildTitle()
		if root.Visible then
			ransom:play()
		end
	end
end

function RevealScreen.show(payload)
	token += 1
	local myToken = token
	local teamWon = payload.winner == "Team"
	handWon = not teamWon
	buildTitle()
	winnerText:set(Kit.mixedCase(if teamWon then Terms.f("{Agency} wins") else Terms.f("{Hand} wins")))
	winnerText:setColor(if teamWon then C.white else C.danger)
	reasonText:set(tostring(payload.reason or ""))
	fillRoster(payload.players or {})
	rewardsLabel.Text = rewardsText(payload.rewards)
	root.Visible = true
	Router.setBlocking("reveal", true)
	ransom:play()
	UiSound.play("slam")
	task.spawn(playTimeline, payload.events or {}, myToken)
end

local function page(title: string, props): (ScrollingFrame, Frame)
	local frame, content = Kit.page({
		tone = "black",
		padding = T.space.l,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size,
		Parent = props.Parent,
	})
	Kit.heading({ text = title, Parent = content })
	local scroll = Kit.scroll({ Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), Parent = content })
	Kit.list(scroll, T.space.xs)
	return scroll, frame
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
	titleHolder = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 70), Parent = window })
	winnerHolder = Kit.Base.make("CanvasGroup", {
		Name = "Winner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = window,
	}) :: any
	winnerText = Kit.text({
		face = "Title",
		text = "",
		size = 44,
		color = C.white,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Parent = winnerHolder,
	})
	reasonText = Kit.text({
		face = "Semi",
		text = "",
		size = 22,
		color = C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Parent = window,
	})
	roster, rosterPage = page("Roles and real names", { Parent = window })
	timeline, timelinePage = page("Case replay", { Parent = window })
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

	buildTitle()
	Kit.Layout.watch(layout)

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
