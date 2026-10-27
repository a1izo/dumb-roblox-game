-- Test bots, so a match can be played alone (debug only). A bot is a table that stands in for
-- a Player: the match code reads its UserId, Name and Character like a player's, messages
-- sent to it are dropped by Net (Net.botSink), and it acts by "sending" the same requests a
-- client would (Net.simulate), so every rule, range check and rate limit applies to it.
--
-- With autoplay on, bots walk the map on pathfinding and vote. Bureau bots work case files; Coven
-- bots wander and stare at people to learn their names, Diavolo writes the names he has learned
-- in the Manual (if hand kills are on), and Muertos sometimes sabotage. A Butler bot names the next
-- Ace, and an Ace bot now and then arrests someone. The debug panel can also order any bot to do
-- one thing.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local PuzzleSet = require(Shared:WaitForChild("Tasks"):WaitForChild("PuzzleSet"))
local Signal = require(Shared:WaitForChild("Signal"))
local VoteCounter = require(Shared:WaitForChild("VoteCounter"))

local Services = script.Parent.Parent:WaitForChild("Services")
local ArrestService = require(Services:WaitForChild("ArrestService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))
local Elimination = require(Services:WaitForChild("Elimination"))
local MapService = require(Services:WaitForChild("MapService"))
local Match = require(Services:WaitForChild("Match"))
local MatchmakingService = require(Services:WaitForChild("MatchmakingService"))

local Bots = {}

Bots.TAG = "LBotCharacter"
Bots.list = {} :: { any }
Bots.autoPlay = Config.STUDIO_BOTS_AUTOPLAY ~= false
Bots.handKills = Config.STUDIO_BOTS_HAND_KILLS ~= false
-- Where autoplaying bots vote: nil (random), "skip", or a user id.
Bots.voteTarget = nil :: any

local nextNumber = 0

local FIRST = { "Ada", "Bo", "Cy", "Dex", "Eve", "Fin", "Gil", "Hal", "Ivy", "Jo", "Kai", "Lu" }
local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(141, 94, 64),
	Color3.fromRGB(95, 62, 42),
}

-- The Player stand-in ---------------------------------------------------------------------

local BotMeta = {}
BotMeta.__index = BotMeta
BotMeta.__tostring = function(self)
	return self.Name
end
BotMeta.MembershipType = Enum.MembershipType.None
BotMeta.AccountAge = 0

function BotMeta:SetAttribute(key: string, value: any)
	self._attributes[key] = value
end

function BotMeta:GetAttribute(key: string): any
	return self._attributes[key]
end

function BotMeta:GetAttributes()
	return table.clone(self._attributes)
end

function BotMeta:IsFriendsWith(_userId: number): boolean
	return false
end

function BotMeta:GetJoinData()
	return {}
end

function BotMeta:IsA(_className: string): boolean
	return false
end

function BotMeta:FindFirstChild(_name: string): Instance?
	return nil
end

function BotMeta:FindFirstChildOfClass(_className: string): Instance?
	return nil
end

function BotMeta:Kick(_message: string?)
	Bots.remove(self)
end

function BotMeta:LoadCharacterAsync()
	Bots.spawnCharacter(self)
end

function BotMeta:LoadCharacter()
	Bots.spawnCharacter(self)
end

function Bots.is(player: any): boolean
	return type(player) == "table" and player.IsBot == true
end

function Bots.byUserId(userId: number): any
	for _, bot in ipairs(Bots.list) do
		if bot.UserId == userId then
			return bot
		end
	end
	return nil
end

-- Characters ------------------------------------------------------------------------------

local function spawnPoint(bot): CFrame
	local ps = Match.getLiving(bot)
	if ps and Match.map and #Match.map.spawns > 0 then
		return Match.map.spawns[((bot.Number - 1) % #Match.map.spawns) + 1] + Vector3.new(0, 3, 0)
	end
	local base = MapService.lobbySpawn()
	local angle = bot.Number * 0.9
	return base * CFrame.new(math.sin(angle) * 9, 3, math.cos(angle) * 9 + 10)
end

-- Bots wear the avatars of the tester's friends (the first real player in the server): fetched once,
-- then bot n takes friend n. Without friends (or offline in Studio) they get plain bodies.
local FRIENDS_MAX = 60
local friendsOf: number? = nil
local friends: { { id: number, name: string } } = {}

local function friendPool(): { { id: number, name: string } }
	local tester = nil
	for _, player in ipairs(Players:GetPlayers()) do
		tester = player
		break
	end
	if not tester or friendsOf == tester.UserId then
		return friends
	end
	friendsOf = tester.UserId
	friends = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(tester.UserId)
	end)
	while ok and pages and #friends < FRIENDS_MAX do
		for _, item in ipairs(pages:GetCurrentPage()) do
			table.insert(friends, { id = item.Id, name = item.DisplayName or item.Username })
		end
		if pages.IsFinished then
			break
		end
		ok = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
	end
	return friends
end

-- The friend whose avatar bot `bot` wears, if any.
local function friendFor(bot): { id: number, name: string }?
	local pool = friendPool()
	return if #pool > 0 then pool[((bot.Number - 1) % #pool) + 1] else nil
end

local function plainBody(bot): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[((bot.Number - 1) % #SKIN) + 1]
	for _, key in ipairs({ "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" }) do
		(description :: any)[key] = skin
	end
	return description
end

function Bots.spawnCharacter(bot)
	if bot.Parent ~= Players then
		return
	end
	local description: HumanoidDescription? = nil
	local friend = friendFor(bot)
	if friend then
		local ok, found = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(friend.id)
		end)
		if ok and found then
			description = found
			bot.DisplayName = friend.name .. " (bot)"
		end
	end
	if bot.Parent ~= Players then
		return
	end
	description = description or plainBody(bot)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[DeathsGambit debug] Could not build a body for " .. bot.Name .. ": " .. tostring(model))
		return
	end
	model.Name = bot.Name
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root -- R6 models pivot on the Head otherwise
	end
	model:SetAttribute("BotUserId", bot.UserId)
	CollectionService:AddTag(model, Bots.TAG)
	-- Characters normally start without the default Animate script; bots never had one.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local old = bot.Character
	model:PivotTo(spawnPoint(bot))
	bot.Character = model
	model.Parent = workspace
	if old and old ~= model then
		old:Destroy()
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	bot.brain = { phase = "", nextThink = 0 }
	bot.CharacterAdded:Fire(model)
end

-- Adding and removing -----------------------------------------------------------------------

function Bots.add(count: number): { any }
	local made = {}
	for _ = 1, math.clamp(count, 1, Config.MAX_PLAYERS) do
		nextNumber += 1
		local first = FIRST[((nextNumber - 1) % #FIRST) + 1]
		local bot = setmetatable({
			IsBot = true,
			Number = nextNumber,
			Name = "Bot" .. nextNumber,
			DisplayName = first .. " (bot)",
			UserId = -(1000 + nextNumber),
			Parent = Players,
			Character = nil :: Model?,
			CharacterAdded = Signal.new(),
			ChildAdded = Signal.new(),
			CameraMaxZoomDistance = 128,
			ReplicationFocus = nil,
			PartyId = "",
			_attributes = {},
			inbox = {},
			brain = { phase = "", nextThink = 0 },
		}, BotMeta)
		table.insert(Bots.list, bot)
		table.insert(made, bot)
		CharacterService.track(bot)
	end
	return made
end

function Bots.remove(bot)
	local index = table.find(Bots.list, bot)
	if not index then
		return
	end
	table.remove(Bots.list, index)
	local ps = Match.getLiving(bot)
	if ps then
		Elimination.eliminate(ps, "left", nil, ps.alias .. " left the investigation.", {})
		Match.announce(ps.alias .. " left the case", "A test bot was removed.", "neutral")
	end
	MatchmakingService.setReady(bot, false)
	bot.Parent = nil
	if bot.Character then
		bot.Character:Destroy()
		bot.Character = nil
	end
end

function Bots.removeAll()
	for _, bot in ipairs(table.clone(Bots.list)) do
		Bots.remove(bot)
	end
end

-- Movement ------------------------------------------------------------------------------------

local function parts(bot): (Humanoid?, BasePart?)
	local character = bot.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function walkTo(bot, position: Vector3)
	local humanoid, root = parts(bot)
	if not humanoid or not root then
		return
	end
	local brain = bot.brain
	brain.goal = position
	brain.waypoints = { position }
	brain.index = 1
	brain.walkStarted = os.clock()
	-- Time to get there, with room for detours (maps are big); set properly once the path is known.
	brain.walkTimeout = 10 + flat(root.Position, position) / 16 * 2.2
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = 5.5,
			AgentCanJump = true,
			WaypointSpacing = 5,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, position)
		end)
		if ok and path.Status == Enum.PathStatus.Success and brain.goal == position then
			local list = {}
			local length = 0
			for index, waypoint in ipairs(path:GetWaypoints()) do
				table.insert(list, waypoint.Position)
				if index > 1 then
					length += (waypoint.Position - list[index - 1]).Magnitude
				end
			end
			brain.waypoints = list
			brain.walkTimeout = 10 + length / 16 * 1.6
			brain.index = math.min(2, #list)
		end
	end)
end

-- True when the bot has reached its goal (or given up on it).
local function followPath(bot): boolean
	local humanoid, root = parts(bot)
	local brain = bot.brain
	if not humanoid or not root or not brain.goal then
		return true
	end
	if flat(root.Position, brain.goal) < 3.5 then
		brain.goal = nil
		humanoid:MoveTo(root.Position)
		return true
	end
	if os.clock() - (brain.walkStarted or 0) > (brain.walkTimeout or 25) then
		brain.goal = nil
		return true
	end
	local target = brain.waypoints[brain.index] or brain.goal
	if flat(root.Position, target) < 2.5 and brain.index < #brain.waypoints then
		brain.index += 1
		target = brain.waypoints[brain.index]
	end
	humanoid:MoveTo(target)
	if target.Y > root.Position.Y + 1.5 then
		humanoid.Jump = true
	end
	return false
end

-- Decisions ---------------------------------------------------------------------------------

local function randomOther(ps, filter: ((any) -> boolean)?)
	local pool = {}
	for _, other in ipairs(Match.living()) do
		if other ~= ps and (not filter or filter(other)) then
			table.insert(pool, other)
		end
	end
	return if #pool > 0 then pool[math.random(1, #pool)] else nil
end

local function workSpot(station): Vector3
	return (station.desk.CFrame * CFrame.new(0, 0, -2.7)).Position
end

local function freeStation(nearTo: Vector3?)
	local stations = Match.map and Match.map.stations or {}
	local best, bestScore = nil, math.huge
	for _, station in ipairs(stations) do
		if not station.desk:GetAttribute("Busy") then
			-- Mostly the nearest free station (the maps are big), with a little chance in it.
			local score = if nearTo
				then (station.position - nearTo).Magnitude + math.random() * 80
				else math.random() * 100
			if score < bestScore then
				best, bestScore = station, score
			end
		end
	end
	return best
end

local function startWork(bot, station)
	local brain = bot.brain
	brain.station = station
	brain.state = "walkToStation"
	brain.puzzle = nil
	walkTo(bot, workSpot(station))
end

local function wander(bot)
	local brain = bot.brain
	brain.state = "wander"
	local areas = Match.map and Match.map.areas or {}
	local area = if #areas > 0 then areas[math.random(1, #areas)] else nil
	if area then
		walkTo(bot, area.position + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
	end
end

-- Someone close enough to stare at whose name this bot does not know yet.
local function stareTarget(ps)
	local here = Match.position(ps)
	if not here then
		return nil
	end
	local range = if ps.eyes then Config.OCULUS_RANGE else Config.STARE_RANGE
	for _, other in ipairs(Match.living()) do
		local there = Match.position(other)
		if other ~= ps and not ps.learned[other.userId] and there and (there - here).Magnitude < range - 1 then
			return other
		end
	end
	return nil
end

-- Stops where it stands and stares at `target` until the stare is done.
local function startStare(bot, ps, target, now: number)
	local humanoid, root = parts(bot)
	if humanoid and root then
		humanoid:MoveTo(root.Position)
		-- (turned to face them: the server only counts a stare at someone in front of you)
		local there = Match.position(target)
		if there then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(there.X, root.Position.Y, there.Z))
		end
	end
	bot.brain.goal = nil
	bot.brain.state = "staring"
	bot.brain.doneAt = now + (if ps.eyes then Config.OCULUS_READ_TIME else Config.STARE_TIME) + 0.6
	Net.simulate("EyesRequest", bot, { action = "stare", userId = target.userId })
end

-- What a Coven bot does in free roam: write a learned name (Diavolo), sabotage now and then
-- (Muertos), stare at whoever is close, or wander on.
local function thinkCoven(bot, ps, now: number)
	local brain = bot.brain
	if ps.role == "Kira" and Bots.handKills and not ps.writing and workspace:GetServerTimeNow() >= ps.writeReadyAt then
		for userId in pairs(ps.learned) do
			local victim = Match.getByUserId(userId)
			if victim and victim.alive and math.random() < 0.3 then
				Net.simulate("DeathNote", bot, {
					name = victim.realName,
					cause = Config.DEATH_CAUSES[math.random(1, #Config.DEATH_CAUSES)],
				})
				brain.state = "writing"
				brain.doneAt = now + Config.MANUAL_WRITE_TIME + 0.5
				return
			end
		end
	end
	if ps.role == "Follower" then
		if ps.eyes == nil and math.random() < 0.01 then
			Net.simulate("EyesRequest", bot, { action = "deal" })
			brain.state = "writing"
			brain.doneAt = now + Config.OCULUS_RITUAL + 0.5
			return
		end
		if workspace:GetServerTimeNow() >= ps.sabotageReadyAt and math.random() < 0.15 then
			Net.simulate("Sabotage", bot, { kind = ({ "blackout", "jam", "barricade" })[math.random(1, 3)] })
		end
	end
	local target = stareTarget(ps)
	if target and math.random() < 0.6 then
		startStare(bot, ps, target, now)
		return
	end
	wander(bot)
end

-- The answer to the puzzle the server gave this bot (from the TaskState it "received").
local function puzzleAnswer(bot): any
	local given = bot.brain.puzzle
	local def = if given then PuzzleSet.get(given.id) else nil
	if not def then
		return nil
	end
	return def.solve(def.generate(given.seed))
end

local function thinkInvestigation(bot, ps, now: number)
	local brain = bot.brain
	if brain.state == "walkToStation" then
		if followPath(bot) then
			local _, root = parts(bot)
			local station = brain.station
			if root and station and flat(root.Position, station.position) < Config.TASK_RANGE then
				Net.simulate("TaskRequest", bot, { action = "start", stationId = station.id })
				brain.state = "working"
				-- A few seconds of "solving" before the answer goes in.
				brain.doneAt = now + 3 + math.random() * 4
			else
				brain.state = nil
			end
		end
	elseif brain.state == "working" then
		if now >= brain.doneAt then
			if brain.station then
				Net.simulate(
					"TaskRequest",
					bot,
					{ action = "complete", stationId = brain.station.id, answer = puzzleAnswer(bot) }
				)
			end
			wander(bot)
		end
	elseif brain.state == "staring" or brain.state == "writing" then
		if now >= brain.doneAt then
			brain.state = nil
			brain.nextThink = now + math.random(1, 3)
		end
	elseif brain.state == "wander" then
		if followPath(bot) then
			brain.state = nil
			brain.nextThink = now + math.random(1, 4)
		end
	elseif now >= brain.nextThink then
		if Match.isKiraSide(ps) then
			thinkCoven(bot, ps, now)
			return
		end
		local _, root = parts(bot)
		local station = freeStation(if root then root.Position else nil)
		if station then
			startWork(bot, station)
		else
			brain.nextThink = now + 2
		end
	end
end

local function think(bot, now: number)
	local ps = Match.getLiving(bot)
	local brain = bot.brain
	if not ps then
		return
	end
	-- A Butler bot names the next Ace after a few seconds.
	local pick = ArrestService.pending()
	if Bots.autoPlay and pick and pick.butler == ps and pick.endsAt - workspace:GetServerTimeNow() < 25 then
		ArrestService.botPick(ps)
	end
	if brain.phase ~= Match.phase or brain.round ~= Match.round then
		-- A new phase: forget what we were doing.
		brain.phase = Match.phase
		brain.round = Match.round
		brain.state = nil
		brain.goal = nil
		brain.acted = false
		brain.nextThink = now + 1 + math.random() * 3
	end
	if Match.phase == "Investigation" then
		if Bots.autoPlay then
			thinkInvestigation(bot, ps, now)
		end
		return
	end
	if brain.goal then
		followPath(bot)
	end
	if brain.acted or now < brain.nextThink then
		return
	end
	if Match.phase == "Meeting" and ps.isAce and not ps.arrestUsed and Bots.autoPlay then
		brain.acted = true
		if math.random() < 0.15 then
			local target = randomOther(ps)
			if target then
				Net.simulate("Arrest", bot, target.userId)
			end
		end
	elseif Match.phase == "Vote" and Bots.autoPlay then
		brain.acted = true
		local wanted = Bots.voteTarget
		local choice: any = VoteCounter.SKIP
		if type(wanted) == "number" and wanted ~= ps.userId and Match.isLivingUserId(wanted) then
			choice = wanted
		elseif wanted ~= "skip" and math.random() >= 0.2 then
			local target = randomOther(ps)
			choice = if target then target.userId else VoteCounter.SKIP
		end
		Net.simulate("Vote", bot, choice)
	end
end

-- Orders from the debug panel ------------------------------------------------------------

-- One order for one bot. Returns a short result for the panel.
function Bots.order(bot, action: string, target: any, from: Vector3?): string
	local ps = Match.getLiving(bot)
	local targetPs = if type(target) == "number" then Match.getByUserId(target) else nil
	if action == "come" then
		if from then
			bot.brain.state = "wander"
			walkTo(bot, from)
			return bot.Name .. " is on the way."
		end
		return "No position to walk to."
	elseif not ps then
		return bot.Name .. " is not alive in a match."
	elseif action == "work" then
		local _, root = parts(bot)
		local station = freeStation(if root then root.Position else nil)
		if not station then
			return "No free station."
		end
		startWork(bot, station)
		return bot.Name .. " is going to " .. station.name .. " (only works in the investigation)."
	elseif action == "vote" then
		Net.simulate("Vote", bot, if targetPs then targetPs.userId else VoteCounter.SKIP)
		return bot.Name .. " voted (only counts during the vote)."
	elseif action == "write" then
		if not targetPs then
			return "Pick a target first."
		end
		Net.simulate("DeathNote", bot, { name = targetPs.realName, cause = Config.DEATH_CAUSES[1] })
		return bot.Name .. Terms.f(" is writing a name (only works for {Hand}, in the investigation, off cooldown).")
	elseif action == "deal" then
		Net.simulate("EyesRequest", bot, { action = "deal" })
		return bot.Name .. Terms.f(" asked for {eyes} ({cultists} only, in the investigation).")
	elseif action == "warrant" then
		if not targetPs then
			return "Pick a target first."
		end
		Net.simulate("Arrest", bot, targetPs.userId)
		return bot.Name .. Terms.f(" made an arrest (only works for {zero}, during a meeting).")
	elseif action == "stare" then
		if not targetPs then
			return "Pick a target first."
		end
		startStare(bot, ps, targetPs, os.clock())
		return bot.Name .. Terms.f(" is staring (only works for {circle}, close by, in the investigation).")
	elseif action == "bell" then
		Net.simulate("Bell", bot, nil)
		return bot.Name .. " rang the bell (if close enough and unused)."
	end

	return "Unknown order."
end

-- Setup ---------------------------------------------------------------------------------------

function Bots.init()
	Net.botSink = function(bot, remoteName: string, payload: any)
		-- Remember the puzzle a task was given, to answer it when the time is up.
		if remoteName == "TaskState" and bot.brain and type(payload) == "table" and payload.state == "started" then
			bot.brain.puzzle = if payload.puzzle then { id = payload.puzzle, seed = payload.seed } else nil
		end
		local inbox = bot.inbox
		table.insert(inbox, { remote = remoteName, payload = payload, at = os.clock() })
		if #inbox > 20 then
			table.remove(inbox, 1)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, bot in ipairs(Bots.list) do
				if bot.Character and bot.Character.Parent then
					local ok, err = pcall(think, bot, now)
					if not ok then
						warn("[DeathsGambit debug] " .. bot.Name .. ": " .. tostring(err))
					end
				end
				-- In the lobby, bots are ready whenever a real player is (so they never start a
				-- match on their own).
				if not Match.active then
					local wanted = MatchmakingService.humansReady()
					if wanted ~= MatchmakingService.isReady(bot) then
						MatchmakingService.setReady(bot, wanted)
					end
				end
			end
		end
	end)
end

return Bots
