-- The reveal, when the case closes, on a small paper sheet: what matters and nothing else (the owner, 2026-11-01:
-- "too much info and no relevant info"). Your result in the big title font ("you won." or "you lost.", red when
-- Diavolo's side won), one line on how the case ended, the culprits unmasked (Diavolo and any Muertos: alias, Roblox
-- name, real name), and one line of what you earned. No roster of every role, no replay of the case.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Roles = require(Shared:WaitForChild("Roles"))

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
local titleLabel: TextLabel
local reasonLabel: TextLabel
local culprits: Frame
local youLabel: TextLabel
local token = 0

-- One culprit: the role in red, the alias large, the Roblox name and the real name under it.
local function culpritRow(entry, index: number)
	local row = Kit.frame({
		Name = "Culprit",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = index,
		Parent = culprits,
	})
	Kit.list(row, 0)
	Kit.label({
		Text = string.upper(Roles.get(entry.role).display),
		font = "monoBold",
		size = "small",
		color = C.danger,
		LayoutOrder = 1,
		Parent = row,
	})
	Kit.label({
		Text = string.format("%s  (%s)", tostring(entry.alias), tostring(entry.displayName)),
		font = "title",
		size = "heading",
		color = C.white,
		LayoutOrder = 2,
		Parent = row,
	})
	Kit.label({
		Text = "real name " .. tostring(entry.realName),
		font = "body",
		size = "body",
		color = C.g6,
		LayoutOrder = 3,
		Parent = row,
	})
end

-- Your line: the role you played and what you earned, in total (the itemised lines are left out), plus a rank
-- up or an unlock when there is one.
local function youText(payload): string
	local rewards = payload.rewards
	if type(rewards) ~= "table" then
		return "YOU WATCHED THIS CASE"
	end
	local myId = Players.LocalPlayer.UserId
	local role = nil
	for _, entry in ipairs(payload.players or {}) do
		if entry.userId == myId then
			role = entry.role
		end
	end
	local line = string.format("+%d REÁL   +%d XP", tonumber(rewards.coins) or 0, tonumber(rewards.xp) or 0)
	if role then
		line = string.format("YOU WERE %s   %s", string.upper(Roles.get(role).display), line)
	end
	local progress = rewards.progress
	if type(progress) == "table" then
		if type(progress.rankUp) == "table" then
			local rank = Ranks.LIST[tonumber(progress.rankUp.to) or 1]
			line ..= "\nRANK UP  " .. string.upper(if rank then rank.name else "?")
		end
		if type(progress.unlocked) == "table" and #progress.unlocked > 0 then
			line ..= "\nUNLOCKED  " .. string.upper(table.concat(progress.unlocked, ", "))
		end
	end
	return line
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

function RevealScreen.show(payload)
	token += 1
	local teamWon = payload.winner == "Team"
	local rewards = payload.rewards
	local text = "case closed."
	if type(rewards) == "table" then
		text = if rewards.won then "you won." else "you lost."
	end
	titleLabel.Text = text
	titleLabel.TextColor3 = if teamWon then C.white else C.danger
	reasonLabel.Text = tostring(payload.reason or "")
	Kit.clear(culprits)
	Kit.list(culprits, T.space.m)
	local count = 0
	for _, entry in ipairs(payload.players or {}) do
		if HOSTILE[entry.role] then
			count += 1
			culpritRow(entry, count)
		end
	end
	youLabel.Text = youText(payload)
	root.Visible = true
	Router.setBlocking("reveal", true)
	UiSound.play("slam")
end

function RevealScreen.init()
	root = Kit.frame({ Name = "Reveal", Visible = false, Parent = Screens.overlay })
	-- (the case summary stands still: no boil on its lines or letters, the owner 2026-11-01)
	root:SetAttribute("NoBoil", true)
	root.BackgroundColor3 = C.void
	root.BackgroundTransparency = 0.04
	-- Darkened edges behind the spread.
	Kit.vignette(root, 0.8).ZIndex = 0
	local window = Kit.frame({
		Name = "Sheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	Kit.Base.maxSize(window, Vector2.new(640, 1000))
	-- A paper report (concept A), everything on it in ink (Kit/Paper); never rotated.
	window.BackgroundColor3 = T.paper.g0
	window.BackgroundTransparency = 0
	Kit.pad(window, T.space.xl, T.space.xxl)
	Kit.list(window, T.space.l)
	titleLabel = Kit.label({
		Text = "",
		font = "title",
		size = 88,
		color = C.white,
		TextWrapped = false,
		LayoutOrder = 1,
		Parent = window,
	})
	titleLabel:SetAttribute("KeepFont", true)
	reasonLabel = Kit.label({
		Text = "",
		font = "body",
		size = "lead",
		color = C.white,
		LayoutOrder = 2,
		Parent = window,
	})
	Kit.rule({ LayoutOrder = 3, Parent = window })
	culprits = Kit.frame({
		Name = "Culprits",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = window,
	})
	Kit.rule({ LayoutOrder = 5, Parent = window })
	local foot = Kit.frame({
		Name = "Foot",
		Size = UDim2.new(1, 0, 0, T.touch),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = window,
	})
	youLabel = Kit.label({
		Text = "",
		font = "monoBold",
		size = "small",
		color = C.white,
		Size = UDim2.new(1, -160, 0, 0),
		Parent = foot,
	})
	Kit.button({
		text = "Close",
		variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(140, T.touch),
		Parent = foot,
	}, closeByButton)

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
