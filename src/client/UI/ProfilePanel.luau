-- Your profile: rank, lifetime numbers, every role's record and mastery, and achievements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = Shared:WaitForChild("Progression")
local Achievements = require(Progression:WaitForChild("Achievements"))
local Mastery = require(Progression:WaitForChild("Mastery"))
local Roles = require(Shared:WaitForChild("Roles"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local ProfilePanel = {}

local ROLE_ORDER = { "Kira", "Follower", "L", "Watari", "TaskForce" } -- terms:ok (internal ids)

local list: ScrollingFrame

local function percent(won: number, played: number): string
	if played <= 0 then
		return "-"
	end
	return string.format("%d%%", math.floor(won / played * 100 + 0.5))
end

local function rankBlock(profile, order: number)
	local block = Kit.frame({ Name = "Rank", Size = UDim2.new(1, 0, 0, 76), LayoutOrder = order, Parent = list })
	Kit.seal({ size = 68, color = C.white, text = string.sub(profile.rankName, 1, 1), Parent = block })
	Kit.text({
		face = "Head",
		text = profile.rankName,
		size = T.size.heading,
		color = C.white,
		Position = UDim2.fromOffset(84, 0),
		Parent = block,
	})
	local _, setProgress = Kit.meter({
		color = C.white,
		Position = UDim2.fromOffset(86, 46),
		Size = UDim2.new(1, -86, 0, 5),
		Parent = block,
	})
	local xpText
	if profile.nextRankXp then
		setProgress((profile.xp - profile.rankXp) / math.max(1, profile.nextRankXp - profile.rankXp))
		xpText = string.format("%d / %d XP  ·  next: %s", profile.xp, profile.nextRankXp, profile.nextRankName)
	else
		setProgress(1)
		xpText = string.format("%d XP  ·  the highest rank", profile.xp)
	end
	Kit.label({
		Text = xpText,
		font = "mono",
		size = "micro",
		color = C.dim,
		Position = UDim2.fromOffset(86, 56),
		Size = UDim2.new(1, -86, 0, 0),
		Parent = block,
	})
end

local function statGrid(entries: { { string } }, order: number)
	local grid = Kit.frame({
		Name = "Numbers",
		Size = UDim2.new(1, 0, 0, math.ceil(#entries / 4) * (68 + T.space.s)),
		LayoutOrder = order,
		Parent = list,
	})
	Kit.grid(grid, UDim2.new(0.25, -T.space.s, 0, 68), T.space.s)
	for _, entry in ipairs(entries) do
		local cell = Kit.card({ Size = UDim2.fromScale(1, 1), padding = T.space.m, Parent = grid })
		Kit.label({ Text = entry[2], font = "bodyBold", size = "title", Parent = cell })
		Kit.label({
			Text = string.upper(entry[1]),
			font = "label",
			size = "micro",
			color = C.dim,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Parent = cell,
		})
	end
end

local function roleCard(profile, roleId: string, order: number)
	local info = Roles.get(roleId)
	local stats = profile.stats
	local record = stats.roles and stats.roles[roleId] or { played = 0, won = 0 }
	local xp = if profile.mastery then profile.mastery[roleId] or 0 else 0
	local level = Mastery.level(xp)
	local hostile = roleId == "Kira" or roleId == "Follower"
	local card = Kit.card({ Size = UDim2.new(1, 0, 0, 68), LayoutOrder = order, Parent = list })
	Kit.text({
		face = "Head",
		text = info.display,
		size = 24,
		color = if hostile then C.red else C.bone,
		Parent = card,
	})
	Kit.label({
		Text = string.format(
			"%d played  ·  %d won  ·  %s",
			record.played,
			record.won,
			percent(record.won, record.played)
		),
		size = "small",
		color = C.dim,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.6, 0, 0, 0),
		Parent = card,
	})
	Kit.label({
		Text = string.format("MASTERY %d/%d", level, Mastery.MAX),
		font = "label",
		size = "micro",
		color = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(170, 0),
		Parent = card,
	})
	local _, setMastery = Kit.meter({
		color = if hostile then C.red else C.steel,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -6),
		Size = UDim2.fromOffset(170, 5),
		Parent = card,
	})
	if Mastery.toNext(xp) then
		local base = Mastery.LEVELS[level]
		setMastery((xp - base) / math.max(1, Mastery.LEVELS[level + 1] - base))
	else
		setMastery(1)
	end
end

local function achievementLine(profile, achievement, order: number)
	local done = (profile.achievements or {})[achievement.id] ~= nil
	local row = Kit.frame({ Name = "Achievement", Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, Parent = list })
	Kit.icon({
		name = if done then "check" else "lock",
		size = 22,
		color = if done then C.good else C.faint,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Parent = row,
	})
	Kit.label({
		Text = achievement.name,
		font = "bodyBold",
		color = if done then C.bone else C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(34, 6),
		Size = UDim2.new(1, -130, 0, 20),
		Parent = row,
	})
	Kit.label({
		Text = achievement.text,
		size = "small",
		color = C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(34, 26),
		Size = UDim2.new(1, -130, 0, 18),
		Parent = row,
	})
	if not done then
		Kit.label({
			Text = string.format(
				"%d / %d",
				math.min(Achievements.value(profile, achievement), achievement.goal),
				achievement.goal
			),
			font = "mono",
			size = "small",
			color = C.dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(90, 20),
			Parent = row,
		})
	end
	Kit.rule({ Position = UDim2.new(0, 0, 1, -1), Parent = row })
end

local function rebuild()
	Kit.clear(list)
	local profile = ClientState.profile
	if not profile then
		return
	end
	local nextOrder = Kit.counter()
	local stats = profile.stats
	rankBlock(profile, nextOrder())
	statGrid({
		{ "Matches", tostring(stats.matches) },
		{ "Wins", tostring(stats.wins) },
		{ "Win rate", percent(stats.wins, stats.matches) },
		{ "Survived", tostring(stats.survived or 0) },
		{ "Case files", tostring(stats.tasks) },
		{ "Notes found", tostring(stats.notesFound or 0) },
		{ "Correct votes", tostring(stats.correctVotes or 0) },
		{ "Lost souls", tostring(stats.duties or 0) },
	}, nextOrder())

	Kit.heading({ text = "Roles", LayoutOrder = nextOrder(), Parent = list })
	for _, roleId in ipairs(ROLE_ORDER) do
		roleCard(profile, roleId, nextOrder())
	end

	local unlocked = 0
	for _, achievement in ipairs(Achievements.LIST) do
		if (profile.achievements or {})[achievement.id] ~= nil then
			unlocked += 1
		end
	end
	Kit.heading({
		text = "Achievements",
		detail = string.format("%d of %d", unlocked, #Achievements.LIST),
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	for _, achievement in ipairs(Achievements.LIST) do
		achievementLine(profile, achievement, nextOrder())
	end
end

function ProfilePanel.init()
	local win = Kit.window({ name = "profile", title = "Profile", size = "M" })
	list = Kit.scroll({ Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, 0, T.space.xs)
	Kit.register(win, {
		allowed = function(view)
			return not view.participant
		end,
		show = function()
			rebuild()
		end,
	})
	ClientState.ProfileChanged:Connect(function()
		if Router.isOpen("profile") then
			rebuild()
		end
	end)
end

return ProfilePanel
