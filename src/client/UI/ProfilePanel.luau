-- Your profile, in two tabs: Overview (rank, lifetime numbers, every role's record and mastery) and Achievements
-- (each a card: done or how far along, its reward; the owner, 2026-10-25: "a separate achievements tab inside the
-- profile").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = Shared:WaitForChild("Progression")
local Achievements = require(Progression:WaitForChild("Achievements"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Mastery = require(Progression:WaitForChild("Mastery"))
local Roles = require(Shared:WaitForChild("Roles"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Kit)
local Router = require(script.Parent.Core.Router)

local C = Kit.color
local T = Kit.Tokens

local ProfilePanel = {}

local ROLE_ORDER = { "Kira", "Follower", "L", "Watari", "TaskForce" } -- terms:ok (internal ids)
local CELL = 80 -- height of a number's cell

local list: ScrollingFrame
local awards: ScrollingFrame
local awardsGrid: Frame
local current = "overview"
local chooseTab: ((string) -> ())? = nil

local function percent(won: number, played: number): string
	if played <= 0 then
		return "-"
	end
	return string.format("%d%%", math.floor(won / played * 100 + 0.5))
end

-- A big lowercase line in the title font (concept A), kept out of the Melodrama mirror.
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
		LayoutOrder = props.LayoutOrder,
	})
	label:SetAttribute("KeepFont", true)
	label.Parent = props.Parent
	return label
end

-- The header, like the profile board: a case-file line, your name huge, your rank, a thick XP line filling red.
local function rankBlock(profile, order: number)
	local block = Kit.frame({ Name = "Rank", Size = UDim2.new(1, 0, 0, 196), LayoutOrder = order, Parent = list })
	local id = tostring(Players.LocalPlayer.UserId)
	Kit.label({
		Text = "CASE FILE " .. string.sub(id, -4),
		font = "mono",
		size = "small",
		color = C.dim,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = block,
	})
	local name = bigText({
		text = string.lower(Players.LocalPlayer.DisplayName) .. ".",
		size = 76,
		Position = UDim2.fromOffset(-4, 16),
		Parent = block,
	})
	Kit.Boil.attach(name, 1, 0.2)
	bigText({ text = string.lower(profile.rankName), size = 30, Position = UDim2.fromOffset(0, 104), Parent = block })
	local _, setProgress = Kit.meter({
		color = C.danger,
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 6),
		Parent = block,
	})
	local xpText
	if profile.nextRankXp then
		setProgress((profile.xp - profile.rankXp) / math.max(1, profile.nextRankXp - profile.rankXp))
		xpText =
			string.format("%d / %d XP   NEXT: %s", profile.xp, profile.nextRankXp, string.upper(profile.nextRankName))
	else
		setProgress(1)
		xpText = string.format("%d XP   MAX RANK", profile.xp)
	end
	Kit.label({
		Text = xpText,
		font = "mono",
		size = "small",
		color = C.dim,
		Position = UDim2.fromOffset(0, 166),
		Size = UDim2.new(1, 0, 0, 0),
		Parent = block,
	})
end

-- The lifetime numbers: big numbers with a small numbered caption under each, no boxes (the profile board).
local function statGrid(entries: { { string } }, order: number)
	local grid = Kit.frame({
		Name = "Numbers",
		Size = UDim2.new(1, 0, 0, math.ceil(#entries / 4) * (CELL + T.space.l)),
		LayoutOrder = order,
		Parent = list,
	})
	Kit.grid(grid, UDim2.new(0.25, -T.space.s, 0, CELL), T.space.l)
	for index, entry in ipairs(entries) do
		local cell = Kit.frame({ Size = UDim2.fromScale(1, 1), LayoutOrder = index, Parent = grid })
		bigText({ text = entry[2], size = 52, Parent = cell })
		Kit.label({
			Text = string.format("%02d %s", index, string.upper(entry[1])),
			font = "mono",
			size = "small",
			color = C.dim,
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 0, 0),
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
		Text = string.format("%d played   %d won   %s", record.played, record.won, percent(record.won, record.played)),
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

-- An achievement's card: its mark (a tick, or a lock), its name and what it asks, a bar of how far along you are (full
-- and lit when done), and what it pays.
local function achievementCard(profile, achievement, order: number)
	local done = (profile.achievements or {})[achievement.id] ~= nil
	local value = math.min(Achievements.value(profile, achievement), achievement.goal)
	local card = Kit.card({
		Name = "Achievement",
		Size = UDim2.fromScale(1, 1),
		padding = T.space.m,
		LayoutOrder = order,
		Parent = awardsGrid,
	})
	if done then
		Kit.Base.make("UIStroke", { Color = C.candle, Transparency = 0.45, Thickness = 1, Parent = card })
	end
	Kit.icon({
		name = if done then "check" else "lock",
		size = 22,
		color = if done then C.candle else C.faint,
		Position = UDim2.fromOffset(0, 2),
		Parent = card,
	})
	Kit.label({
		Text = achievement.name,
		font = "bodyBold",
		color = if done then C.bone else C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30, 0, 22),
		Parent = card,
	})
	Kit.label({
		Text = achievement.text,
		size = "small",
		color = C.dim,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(30, 22),
		Size = UDim2.new(1, -30, 0, 34),
		Parent = card,
	})
	local _, setBar = Kit.meter({
		color = if done then C.candle else C.steel,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = card,
	})
	setBar(if done then 1 else value / math.max(1, achievement.goal))
	local reward = string.format("%d Reál", achievement.coins)
	local title = achievement.title and Cosmetics.byId(achievement.title)
	if title then
		reward ..= ", " .. title.name .. " title"
	end
	Kit.label({
		Text = if done then "Done   " .. reward else string.format("%d / %d   %s", value, achievement.goal, reward),
		font = "mono",
		size = "micro",
		color = if done then C.candle else C.dim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = card,
	})
end

local function rebuildAwards(profile)
	Kit.clear(awards)
	-- (the count and its bar over the grid of cards)
	awardsGrid = Kit.frame({
		Name = "Grid",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = awards,
	})
	Kit.grid(awardsGrid, UDim2.new(0.5, -T.space.s / 2, 0, 124), T.space.s)
	local unlocked = 0
	for _, achievement in ipairs(Achievements.LIST) do
		if (profile.achievements or {})[achievement.id] ~= nil then
			unlocked += 1
		end
	end
	-- (a header across the grid: how many, and a bar of them all)
	local head = Kit.frame({ Name = "Head", Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 0, Parent = awards })
	Kit.text({
		face = "Head",
		text = string.format("%d of %d", unlocked, #Achievements.LIST),
		size = T.size.heading,
		color = C.white,
		Parent = head,
	})
	local _, setAll = Kit.meter({
		color = C.candle,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 5),
		Parent = head,
	})
	setAll(unlocked / math.max(1, #Achievements.LIST))
	-- done ones first, then the nearest to done
	local order = table.clone(Achievements.LIST)
	table.sort(order, function(x, y)
		local dx = (profile.achievements or {})[x.id] ~= nil
		local dy = (profile.achievements or {})[y.id] ~= nil
		if dx ~= dy then
			return dx
		end
		local px = Achievements.value(profile, x) / math.max(1, x.goal)
		local py = Achievements.value(profile, y) / math.max(1, y.goal)
		return px > py
	end)
	for index, achievement in ipairs(order) do
		achievementCard(profile, achievement, index)
	end
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
	rebuildAwards(profile)
end

-- Opens the profile on a tab ("overview" or "achievements").
function ProfilePanel.open(tab: string?)
	if Router.open("profile") ~= false and tab and chooseTab then
		chooseTab(tab)
	end
end

function ProfilePanel.init()
	local win = Kit.window({ name = "profile", title = "Profile", size = "M" })
	local below = T.touch + T.space.s
	list = Kit.scroll({ Position = UDim2.fromOffset(0, below), Size = UDim2.new(1, 0, 1, -below), Parent = win.body })
	Kit.list(list, T.space.s)
	Kit.pad(list, 0, T.space.xs)
	awards = Kit.scroll({
		Position = UDim2.fromOffset(0, below),
		Size = UDim2.new(1, 0, 1, -below),
		Visible = false,
		Parent = win.body,
	})
	Kit.list(awards, T.space.m)
	Kit.pad(awards, 0, T.space.xs)
	local _, choose = Kit.tabs({
		items = { { id = "overview", label = "Overview" }, { id = "achievements", label = "Achievements" } },
		selected = current,
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = win.body,
	}, function(id)
		current = id
		list.Visible = id == "overview"
		awards.Visible = id == "achievements"
	end)
	chooseTab = choose
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
