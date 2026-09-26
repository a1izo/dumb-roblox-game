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
	return ps ~= nil and not ps.alive and ps.status ~= "left"
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
		if watchers[player] then
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
		if watchers[player] then
			watchers[player] = nil
			ChatService.removeWatcher(player.UserId)
		end
	end)
	task.spawn(watchdog)
end

return GhostService
