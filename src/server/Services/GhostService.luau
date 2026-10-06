-- Specters: players who died, were voted out or were arrested stay in the match as ghosts.
-- Ghosts fly through walls, but only inside invisible bounds that follow the map's outer
-- walls and ceiling (Venues.specterBounds), follow the match between the map and
-- the meeting room's gallery, chat only with each other, and can gather lost souls for a
-- few coins. The living never see, hear or touch them (the client hides them, and they sit
-- in their own collision group with CanQuery and CanTouch off).
--
-- Real names: a ghost sees the real names of the living only while none of their party
-- members or Roblox friends is still alive (otherwise a dead Cultist could read names to
-- the Hand over voice chat outside the game).
--
-- Away: a Specter can go back to the lobby until the case closes ("away"). They stay in the case (its
-- rewards and its results are theirs), but in the lobby they are hidden from everyone: no body, no name, they
-- walk through people (the Away collision group), talk in the Specters' channel only, and their mini-game
-- bests reach the public boards only after the case. Lost souls drift in the lobby for them too (the same cap
-- as in the case). They can go back in as a Specter ("rejoin") at any time.
--
-- Spectators: players in the lobby can watch a running match. They fly in it like a ghost
-- (the same bounds and venue moves) but are nobody's ghost: hidden from everyone, Specters
-- included, with no real names, lost souls or rewards, reading the meeting without sending,
-- and their voice off. They leave when they want, and the case closing sends them back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local SpectateRules = require(Shared:WaitForChild("SpectateRules"))
local Venues = require(Shared:WaitForChild("Venues"))

local CharacterService = require(script.Parent.CharacterService)
local ChatService = require(script.Parent.ChatService)
local CollisionGroups = require(script.Parent.CollisionGroups)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Match = require(script.Parent.Match)
local PartyService = require(script.Parent.PartyService)
local RateLimit = require(script.Parent.RateLimit)

local GhostRemote = Net.event("Ghost")
local WatchRemote = Net.event("Watch")

local GhostService = {}

GhostService.DUTY_RANGE = 8
GhostService.DUTY_COOLDOWN = 4
GhostService.DUTY_MAX = 8
local ACTIVE_WISPS = 3

-- How far past its walls the watchdog lets a ghost stray before bringing it back.
local STRAY = Vector3.new(2, 4, 2)

-- Camera zoom for spectators (as close as the players'), and back in the lobby.
local WATCH_ZOOM = 18
local LOBBY_ZOOM = 128

type Ghost = {
	ps: any,
	venue: string,
	wisps: { [number]: Vector3 },
	nextWisp: number,
	lastCollect: number,
	eligible: boolean,
}

local ghosts: { [Player]: Ghost } = {}
-- Specters waiting in the lobby: their lost souls there (ids -> positions).
type Away = { ps: any, wisps: { [number]: Vector3 }, nextWisp: number, lastCollect: number }
local awayPlayers: { [Player]: Away } = {}
-- Spectators from the lobby: player -> the venue they are in.
local watchers: { [Player]: { venue: string } } = {}
-- Set by the matchmaker: whether a player is queued for the next match.
local queued: (Player) -> boolean = function(_player: Player)
	return false
end
local partyOf: { [number]: number } = {}
local friendsOf: { [number]: { [number]: boolean } } = {}
local boundsFolder: Folder? = nil

function GhostService.isGhost(player: Player): boolean
	if not Match.active then
		return false
	end
	local ps = Match.get(player)
	return ps ~= nil and not ps.alive and ps.status ~= "left" and not awayPlayers[player]
end

-- A Specter waiting in the lobby (see the top of the file).
function GhostService.isAway(player: Player): boolean
	return Match.active and awayPlayers[player] ~= nil
end

local function venueForPhase(phase: string): string
	if phase == "Meeting" or phase == "Vote" or phase == "Verdict" or phase == "Outro" then
		return "meeting"
	end
	return "map"
end

local function origin(venue: string): Vector3
	return if venue == "meeting" then Venues.MEETING else Venues.MAP
end

local function spotIn(venue: string): CFrame
	local map = Match.map
	if venue == "meeting" and map and map.meeting and map.meeting.gallery and #map.meeting.gallery > 0 then
		local gallery = map.meeting.gallery
		return gallery[Match.rng:NextInteger(1, #gallery)] + Vector3.new(0, 3, 0)
	end
	if map and #map.spawns > 0 then
		return map.spawns[Match.rng:NextInteger(1, #map.spawns)] + Vector3.new(0, 6, 0)
	end
	return CFrame.new(origin(venue) + Vector3.new(0, 8, 0))
end

-- The venue's box for this match's map (Venues holds the sizes; clients clamp to the same).
local function bounds(venue: string): (Vector3, Vector3)
	return Venues.specterBounds(venue, Match.mapId)
end

local function inBounds(venue: string, position: Vector3): boolean
	local min, max = bounds(venue)
	min -= STRAY
	max += STRAY
	return position.X >= min.X
		and position.X <= max.X
		and position.Y >= min.Y
		and position.Y <= max.Y
		and position.Z >= min.Z
		and position.Z <= max.Z
end

-- Invisible walls, floor and ceiling around a venue that only ghosts bump into.
local function buildBox(parent: Instance, venue: string)
	local min, max = bounds(venue)
	local size = max - min
	local centre = (min + max) / 2
	local faces = {
		{ Vector3.new(size.X, 1, size.Z), Vector3.new(centre.X, min.Y - 0.5, centre.Z) },
		{ Vector3.new(size.X, 1, size.Z), Vector3.new(centre.X, max.Y + 0.5, centre.Z) },
		{ Vector3.new(1, size.Y, size.Z), Vector3.new(min.X - 0.5, centre.Y, centre.Z) },
		{ Vector3.new(1, size.Y, size.Z), Vector3.new(max.X + 0.5, centre.Y, centre.Z) },
		{ Vector3.new(size.X, size.Y, 1), Vector3.new(centre.X, centre.Y, min.Z - 0.5) },
		{ Vector3.new(size.X, size.Y, 1), Vector3.new(centre.X, centre.Y, max.Z + 0.5) },
	}
	for _, face in ipairs(faces) do
		Create("Part", {
			Name = "SpecterBound",
			Anchored = true,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = face[1],
			Position = face[2],
			CollisionGroup = CollisionGroups.BOUNDS,
			Parent = parent,
		})
	end
end

-- Real names ----------------------------------------------------------------------------

local function hasAllyAlive(ps): boolean
	local party = partyOf[ps.userId]
	local friends = friendsOf[ps.userId] or {}
	for _, other in ipairs(Match.living()) do
		if other ~= ps then
			if party ~= nil and partyOf[other.userId] == party then
				return true
			end
			if friends[other.userId] then
				return true
			end
		end
	end
	return false
end

local function sendNames(player: Player, ghost: Ghost)
	local names = {}
	if ghost.eligible then
		for _, other in ipairs(Match.living()) do
			names[tostring(other.userId)] = other.realName
		end
	end
	GhostRemote:FireClient(player, { action = "names", names = names, eligible = ghost.eligible })
end

local function refreshNames()
	for player, ghost in pairs(ghosts) do
		ghost.eligible = not hasAllyAlive(ghost.ps)
		sendNames(player, ghost)
	end
end

-- Lost souls ------------------------------------------------------------------------------

local function newWispPosition(): Vector3?
	local map = Match.map
	if not map or #map.areas == 0 then
		return nil
	end
	local area = map.areas[Match.rng:NextInteger(1, #map.areas)]
	local offset = Vector3.new(Match.rng:NextNumber(-14, 14), Match.rng:NextNumber(3, 9), Match.rng:NextNumber(-14, 14))
	return area.position + offset
end

local function sendDuties(player: Player, ghost: Ghost)
	local list = {}
	for id, position in pairs(ghost.wisps) do
		table.insert(list, { id = id, position = position })
	end
	GhostRemote:FireClient(player, {
		action = "duties",
		done = ghost.ps.stats.duties or 0,
		max = GhostService.DUTY_MAX,
		wisps = list,
	})
end

local function fillWisps(ghost: Ghost)
	local done = ghost.ps.stats.duties or 0
	local count = 0
	for _ in pairs(ghost.wisps) do
		count += 1
	end
	while count < ACTIVE_WISPS and done + count < GhostService.DUTY_MAX do
		local position = newWispPosition()
		if not position then
			return
		end
		ghost.nextWisp += 1
		ghost.wisps[ghost.nextWisp] = position
		count += 1
	end
end

local function onCollect(player: Player, ghost: Ghost, id: any)
	local position = if type(id) == "number" then ghost.wisps[id] else nil
	local root = Match.rootPart(ghost.ps)
	if not position or not root then
		return
	end
	if (root.Position - position).Magnitude > GhostService.DUTY_RANGE then
		return
	end
	local now = os.clock()
	if now - ghost.lastCollect < GhostService.DUTY_COOLDOWN then
		return
	end
	local stats = ghost.ps.stats
	if (stats.duties or 0) >= GhostService.DUTY_MAX then
		return
	end
	ghost.lastCollect = now
	stats.duties = (stats.duties or 0) + 1
	ghost.wisps[id] = nil
	fillWisps(ghost)
	sendDuties(player, ghost)
end

-- Ghost characters --------------------------------------------------------------------------

local function moveTo(ghost: Ghost, venue: string)
	ghost.venue = venue
	local character = ghost.ps.player.Character
	if character and character:GetAttribute("Specter") then
		character:PivotTo(spotIn(venue))
	end
end

-- Makes a body a ghost's: through walls, untouchable, unseen by sight lines, no name tag.
-- `attribute` is "Specter" for the dead and "Spectator" for watchers from the lobby.
local function ghostBody(character: Model, attribute: string, displayName: string)
	character:SetAttribute(attribute, true)
	local function ghostPart(item: Instance)
		if item:IsA("BasePart") then
			item.CollisionGroup = CollisionGroups.SPECTERS
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
		end
	end
	for _, item in ipairs(character:GetDescendants()) do
		ghostPart(item)
	end
	character.DescendantAdded:Connect(ghostPart)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.DisplayName = displayName
		character:SetAttribute("NameHidden", true)
	end
end

local function setupCharacter(player: Player, character: Model)
	local ps = Match.get(player)
	if not ps then
		return
	end
	local ghost = ghosts[player]
	if not ghost then
		ghost = {
			ps = ps,
			venue = venueForPhase(Match.phase),
			wisps = {},
			nextWisp = 0,
			lastCollect = 0,
			eligible = false,
		}
		ghosts[player] = ghost
	end
	ghostBody(character, "Specter", ps.alias)
	CharacterService.applyOutfit(player)
	ghost.venue = venueForPhase(Match.phase)
	character:PivotTo(spotIn(ghost.venue))
	fillWisps(ghost)
	ghost.eligible = not hasAllyAlive(ps)
	GhostRemote:FireClient(player, { action = "rise", alias = ps.alias })
	sendNames(player, ghost)
	sendDuties(player, ghost)
end

-- Away in the lobby ---------------------------------------------------------------------------------

local LOBBY_WISP_RADIUS = 70

-- A spot over the lobby's open ground, near its spawn, where a lost soul can drift.
local function lobbyWispPosition(): Vector3?
	local lobby = workspace:FindFirstChild("LGameLobby")
	local spawn = if lobby then lobby:FindFirstChild("LobbySpawn", true) else nil
	if not spawn or not spawn:IsA("BasePart") then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { lobby :: Instance }
	for _ = 1, 8 do
		local angle = Match.rng:NextNumber(0, math.pi * 2)
		local distance = Match.rng:NextNumber(12, LOBBY_WISP_RADIUS)
		local top = spawn.Position + Vector3.new(math.cos(angle) * distance, 40, math.sin(angle) * distance)
		local hit = workspace:Raycast(top, Vector3.new(0, -80, 0), params)
		if hit and hit.Normal.Y > 0.7 then
			return hit.Position + Vector3.new(0, Match.rng:NextNumber(2.5, 5), 0)
		end
	end
	return nil
end

local function sendAwayDuties(player: Player, away: Away)
	local list = {}
	for id, position in pairs(away.wisps) do
		table.insert(list, { id = id, position = position })
	end
	GhostRemote:FireClient(player, {
		action = "duties",
		done = away.ps.stats.duties or 0,
		max = GhostService.DUTY_MAX,
		wisps = list,
	})
end

local function fillAwayWisps(away: Away)
	local done = away.ps.stats.duties or 0
	local count = 0
	for _ in pairs(away.wisps) do
		count += 1
	end
	while count < ACTIVE_WISPS and done + count < GhostService.DUTY_MAX do
		local position = lobbyWispPosition()
		if not position then
			return
		end
		away.nextWisp += 1
		away.wisps[away.nextWisp] = position
		count += 1
	end
end

local function onAwayCollect(player: Player, away: Away, id: any)
	local position = if type(id) == "number" then away.wisps[id] else nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not position or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - position).Magnitude > GhostService.DUTY_RANGE then
		return
	end
	local now = os.clock()
	if now - away.lastCollect < GhostService.DUTY_COOLDOWN then
		return
	end
	local stats = away.ps.stats
	if (stats.duties or 0) >= GhostService.DUTY_MAX then
		return
	end
	away.lastCollect = now
	stats.duties = (stats.duties or 0) + 1
	away.wisps[id] = nil
	fillAwayWisps(away)
	sendAwayDuties(player, away)
end

-- Hides an away body: nobody else sees it (the clients hide bodies marked Away), it has no name tag and it
-- walks through people.
local function awayBody(character: Model)
	character:SetAttribute("Away", true)
	character:SetAttribute("NameHidden", true)
	CollisionGroups.body(character, CollisionGroups.AWAY, true)
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.DisplayName = ""
	end
end

local function setupAway(player: Player, character: Model)
	local away = awayPlayers[player]
	if not away then
		return
	end
	awayBody(character)
	fillAwayWisps(away)
	sendAwayDuties(player, away)
end

-- A Specter goes back to the lobby (hidden) until the case closes. False when they cannot.
function GhostService.goAway(player: Player): boolean
	local ps = Match.get(player)
	if not GhostService.isGhost(player) or not ps or Match.phase == "Reveal" or Match.phase == "Outro" then
		return false
	end
	ghosts[player] = nil
	awayPlayers[player] = { ps = ps, wisps = {}, nextWisp = 0, lastCollect = 0 }
	ps.away = true
	LeaderboardService.hold(player.UserId, true)
	player.CameraMaxZoomDistance = LOBBY_ZOOM
	GhostRemote:FireClient(player, { action = "names", names = {}, eligible = false })
	Match.pushPrivate(ps)
	CharacterService.load(player)
	return true
end

-- An away Specter goes back into the case as a Specter.
function GhostService.rejoin(player: Player): boolean
	local away = awayPlayers[player]
	if not away or not Match.active or Match.phase == "Reveal" or Match.phase == "Outro" then
		return false
	end
	awayPlayers[player] = nil
	away.ps.away = false
	player.CameraMaxZoomDistance = WATCH_ZOOM
	Match.pushPrivate(away.ps)
	-- The new body is made a Specter's on spawn (CharacterSpawned below).
	CharacterService.load(player)
	return true
end

-- Spectators ---------------------------------------------------------------------------------

function GhostService.isWatching(player: Player): boolean
	return watchers[player] ~= nil
end

-- The matchmaker says who is queued (a queued player cannot watch).
function GhostService.setQueueCheck(check: (Player) -> boolean)
	queued = check
end

local function setupWatcher(player: Player, character: Model)
	local watcher = watchers[player]
	if not watcher then
		return
	end
	ghostBody(character, "Spectator", player.DisplayName)
	watcher.venue = venueForPhase(Match.phase)
	character:PivotTo(spotIn(watcher.venue))
end

-- Why a player cannot watch right now (nil when they can).
function GhostService.watchBlocker(player: Player): string?
	return SpectateRules.blocker({
		active = Match.active,
		phase = Match.phase,
		participant = Match.get(player) ~= nil,
		queued = queued(player),
	})
end

-- Sends a lobby player into the running match as a spectator.
function GhostService.watch(player: Player): boolean
	if watchers[player] then
		return true
	end
	local blocker = GhostService.watchBlocker(player)
	local character = player.Character
	if blocker or not character then
		if blocker then
			Match.notify(player, blocker, "bad")
		end
		return false
	end
	watchers[player] = { venue = venueForPhase(Match.phase) }
	player.CameraMaxZoomDistance = WATCH_ZOOM
	setupWatcher(player, character)
	ChatService.addWatcher(player.UserId)
	WatchRemote:FireClient(player, { watching = true })
	return true
end

-- Brings a spectator back to the lobby with a fresh body.
function GhostService.unwatch(player: Player)
	if not watchers[player] then
		return
	end
	watchers[player] = nil
	ChatService.removeWatcher(player.UserId)
	if player.Parent == Players then
		player.CameraMaxZoomDistance = LOBBY_ZOOM
		WatchRemote:FireClient(player, { watching = false })
		CharacterService.load(player)
	end
end

local function onWatch(player: Player, payload: any)
	if type(payload) ~= "table" or not RateLimit.allow(player, "watch", 0.5) then
		return
	end
	if payload.action == "watch" then
		GhostService.watch(player)
	elseif payload.action == "leave" then
		GhostService.unwatch(player)
	end
end

local function onRequest(player: Player, payload: any)
	if type(payload) ~= "table" or not RateLimit.allow(player, "ghost", 0.2) then
		return
	end
	if payload.action == "away" then
		GhostService.goAway(player)
		return
	elseif payload.action == "rejoin" then
		GhostService.rejoin(player)
		return
	end
	local away = awayPlayers[player]
	if away then
		if payload.action == "collect" and Match.active then
			onAwayCollect(player, away, payload.id)
		end
		return
	end
	local jump = payload.action == "jump" and (payload.venue == "map" or payload.venue == "meeting")
	local watcher = watchers[player]
	if watcher then
		if jump and player.Character then
			watcher.venue = payload.venue
			player.Character:PivotTo(spotIn(payload.venue))
		end
		return
	end
	local ghost = ghosts[player]
	if not ghost or not GhostService.isGhost(player) then
		return
	end
	if payload.action == "collect" then
		onCollect(player, ghost, payload.id)
	elseif jump then
		moveTo(ghost, payload.venue)
	end
end

-- Brings anything that strayed outside both boxes back to its venue, and damps runaways.
local function keepInside(character: Model?, attribute: string, venue: string)
	local root = if character and character:GetAttribute(attribute)
		then character:FindFirstChild("HumanoidRootPart")
		else nil
	if root and root:IsA("BasePart") then
		if not inBounds("map", root.Position) and not inBounds("meeting", root.Position) then
			(character :: Model):PivotTo(spotIn(venue))
		elseif root.AssemblyLinearVelocity.Magnitude > 120 then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function watchdog()
	while true do
		task.wait(1)
		if Match.active then
			for player, ghost in pairs(ghosts) do
				keepInside(player.Character, "Specter", ghost.venue)
			end
			for player, watcher in pairs(watchers) do
				keepInside(player.Character, "Spectator", watcher.venue)
			end
		end
	end
end

-- Match hooks ---------------------------------------------------------------------------------

-- Debug panel: a revived player stops being a Specter.
function GhostService.forget(player: Player)
	ghosts[player] = nil
end

function GhostService.onMatchStart()
	ghosts = {}
	partyOf = {}
	friendsOf = {}
	local players = {}
	for _, ps in ipairs(Match.list) do
		table.insert(players, ps.player)
	end
	for index, group in ipairs(PartyService.groupsFor(players)) do
		if #group > 1 then
			for _, userId in ipairs(group) do
				partyOf[userId] = index
			end
		end
	end
	-- Friendships among the players in this match (looked up in the background).
	for _, ps in ipairs(Match.list) do
		friendsOf[ps.userId] = {}
	end
	for _, ps in ipairs(Match.list) do
		for _, other in ipairs(Match.list) do
			if other.userId > ps.userId then
				task.spawn(function()
					local ok, friends = pcall(function()
						return ps.player:IsFriendsWith(other.userId)
					end)
					-- If Roblox cannot say, assume they are friends (the safe side).
					if not ok or friends then
						friendsOf[ps.userId][other.userId] = true
						friendsOf[other.userId][ps.userId] = true
					end
				end)
			end
		end
	end
	local map = Match.map
	if map and map.model then
		local folder = Instance.new("Folder")
		folder.Name = "SpecterBounds"
		buildBox(folder, "map")
		buildBox(folder, "meeting")
		folder.Parent = map.model
		boundsFolder = folder
	end
end

function GhostService.onMatchEnd()
	ghosts = {}
	-- Away Specters come back into view (the case's cleanup gives everyone a fresh body), and their held
	-- mini-game bests go to the boards.
	for player, away in pairs(awayPlayers) do
		away.ps.away = false
		LeaderboardService.hold(player.UserId, false)
	end
	awayPlayers = {}
	partyOf = {}
	friendsOf = {}
	-- The case is closed: every spectator goes back to the lobby.
	local watching = {}
	for player in pairs(watchers) do
		table.insert(watching, player)
	end
	for _, player in ipairs(watching) do
		GhostService.unwatch(player)
	end
	if boundsFolder then
		boundsFolder:Destroy()
		boundsFolder = nil
	end
end

function GhostService.onPhase(phase: string)
	local venue = venueForPhase(phase)
	for _, ghost in pairs(ghosts) do
		if ghost.venue ~= venue then
			moveTo(ghost, venue)
		end
	end
	for player, watcher in pairs(watchers) do
		if watcher.venue ~= venue and player.Character then
			watcher.venue = venue
			player.Character:PivotTo(spotIn(venue))
		end
	end
end

function GhostService.init()
	GhostRemote.OnServerEvent:Connect(onRequest)
	WatchRemote.OnServerEvent:Connect(onWatch)
	CharacterService.CharacterSpawned:Connect(function(player, character)
		if awayPlayers[player] and Match.active then
			-- At once: the body must never show in the lobby, even for a frame.
			setupAway(player, character)
		elseif watchers[player] then
			-- A spectator's body was replaced (it fell apart, or the avatar reloaded).
			task.spawn(function()
				RunService.Heartbeat:Wait()
				if player.Character == character then
					setupWatcher(player, character)
				end
			end)
		elseif GhostService.isGhost(player) then
			task.spawn(function()
				-- Let the default spawn placement finish first.
				RunService.Heartbeat:Wait()
				if player.Character == character and GhostService.isGhost(player) then
					setupCharacter(player, character)
				end
			end)
		end
	end)
	Match.Eliminated:Connect(function()
		task.defer(refreshNames)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ghosts[player] = nil
		if awayPlayers[player] then
			awayPlayers[player] = nil
			LeaderboardService.hold(player.UserId, false)
		end
		if watchers[player] then
			watchers[player] = nil
			ChatService.removeWatcher(player.UserId)
		end
	end)
	task.spawn(watchdog)
end

return GhostService
