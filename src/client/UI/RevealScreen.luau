-- The reveal, when the case closes, on a paper report: "case closed." in the big title font (red when Diavolo's
-- side won), the winning side in the serif beneath it, every role and real name on the left, a replay of the
-- key events on the right, and your rewards. On a phone the two pages stack. The winner line glitches
-- every couple of seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local LobbyIntro = require(script.Parent.LobbyIntro)
local Router = require(script.Parent.Core.Router)
local Screens = require(script.Parent.Screens)
local UiSound = require(script.Parent.Core.UiSound)
local WinCinema = require(script.Parent.Parent.Presentation.WinCinema)

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

-- Words safe inside rich text.
local function plain(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function fillRoster(players)
	Kit.clear(roster)
	for index, entry in ipairs(players) do
		local info = Roles.get(entry.role)
		-- (14 px short of the edge, so the scroll bar never covers the role on the right)
		local row = Kit.frame({ Name = "Line", Size = UDim2.new(1, -14, 0, 52), LayoutOrder = index, Parent = roster })
		local name = string.format("%s  (%s)", plain(tostring(entry.alias)), plain(tostring(entry.displayName)))
		if type(entry.title) == "string" and entry.title ~= "" then
			-- (in its tier's look, as over the head in the lobby: Shared/Rarity.titleText)
			name ..= "   " .. (Rarity.titleText(entry.title, entry.titleRarity, C.dim, entry.titleId))
		end
		Kit.label({
			Text = name,
			RichText = true,
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
			status ..= ", " .. tostring(entry.cause)
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
		return "You spectated this case."
	end
	local lines = {
		string.format(
			"%s   +%d Reál   +%d XP",
			if rewards.won then "Victory" else "Defeat",
			rewards.coins,
			rewards.xp
		),
	}
	for _, line in ipairs(rewards.lines or {}) do
		table.insert(lines, string.format("%s: +%d Reál, +%d XP", tostring(line.label), line.coins, line.xp))
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
					"%s mastery %d",
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

-- The Close button: in the case's own results the loading screen comes up at once and takes you back (the server
-- ends the case as soon as everyone in it has closed theirs, or when its time is up); a watcher just closes them.
local function closeByButton()
	local inCase = ClientState.isParticipant()
	-- (an away Specter is in the case's list too, though already in the lobby: they count as closed as well)
	local listed = ClientState.public.active and ClientState.me() ~= nil
	close()
	if inCase then
		LobbyIntro.hold()
	end
	if listed then
		Net.event("Reveal"):FireServer({ action = "closed" })
	end
end

local handWon = false

-- "case closed." in the big lowercase title font (concept A), boiling; red when Diavolo's side won.
local function buildTitle()
	Kit.clear(titleHolder)
	local phone = Kit.Layout.isPhone()
	local title = Kit.label({
		Text = "case closed.",
		font = "title",
		size = if phone then 48 else 92,
		color = if handWon then C.danger else C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
	})
	title:SetAttribute("KeepFont", true)
	title.Parent = titleHolder
	Kit.Boil.attach(title, 1, 0.2)
	ransom = { play = function() end }
end

-- The title block is 190 px tall on a PC and 130 on a phone; below it the two pages sit side by side or
-- stacked. The close button and the rewards line take the bottom 72 px.
local function layout(class: string)
	local phone = class == "phone"
	local top = if phone then 150 else 226
	titleHolder.Size = UDim2.new(1, 0, 0, if phone then 56 else 104)
	winnerHolder.Position = UDim2.new(0.5, 0, 0, if phone then 58 else 106)
	winnerText:setSize(if phone then 30 else 44)
	reasonText.frame.Position = UDim2.new(0.5, 0, 0, if phone then 96 else 162)
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
	Kit.Base.maxSize(window, Vector2.new(1160, 760))
	-- A paper report (concept A): the sheet, a hair off square, everything on it in ink (Kit/Paper).
	window.BackgroundColor3 = T.paper.g0
	window.BackgroundTransparency = 0
	window.Rotation = 0.3
	Kit.pad(window, T.space.xl, T.space.xxl)
	titleHolder = Kit.frame({ Name = "Title", Size = UDim2.new(1, 0, 0, 70), Parent = window })
	winnerHolder = Kit.Base.make("CanvasGroup", {
		Name = "Winner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = window,
	}) :: any
	winnerText = Kit.text({
		face = "Head",
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
		font = "monoBold",
		size = "small",
		color = C.bone,
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
	}, closeByButton)

	buildTitle()
	Kit.Layout.watch(layout)
	Kit.Paper.apply(window)

	Net.event("Reveal").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		-- (a winner's own win cutscene first, on this screen alone, then the results: the owner's Q29)
		local private = WinCinema.pendingPrivate
		WinCinema.pendingPrivate = nil
		if private and WinCinema.get(private) then
			task.spawn(function()
				WinCinema.play(private, { userId = Players.LocalPlayer.UserId, wait = true })
				RevealScreen.show(payload)
			end)
			return
		end
		RevealScreen.show(payload)
	end)
	ClientState.PhaseChanged:Connect(function(phase)
		if phase == "Briefing" then
			close()
		end
	end)
end

return RevealScreen
