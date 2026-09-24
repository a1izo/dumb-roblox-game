-- Specters: players who died, were voted out or were arrested stay in the match as ghosts.
-- Ghosts fly through walls inside invisible bounds, follow the match between the map and
-- the meeting room's gallery, chat only with each other, and can gather lost souls for a
-- few coins. The living never see, hear or touch them (the client hides them, and they sit
-- in their own collision group with CanQuery and CanTouch off).
--
-- Real names: a ghost sees the real names of the living only while none of their party
-- members or Roblox friends is still alive (otherwise a dead Cultist could read names to
-- the Hand over voice chat outside the game).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Venues = require(Shared:WaitForChild("Venues"))

local CharacterService = require(script.Parent.CharacterService)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Match = require(script.Parent.Match)
local PartyService = require(script.Parent.PartyService)
local RateLimit = require(script.Parent.RateLimit)

local GhostRemote = Net.event("Ghost")

local GhostService = {}

GhostService.DUTY_RANGE = 8
GhostService.DUTY_COOLDOWN = 4
GhostService.DUTY_MAX = 8
local ACTIVE_WISPS = 3

-- Bounds around each venue, relative to its origin: { min, max }.
local BOUNDS = {
	map = { Vector3.new(-125, 0, -105), Vector3.new(125, 70, 105) },
	meeting = { Vector3.new(-30, 0, -30), Vector3.new(30, 18, 30) },
}

type Ghost = {
	ps: any,
	venue: string,
	wisps: { [number]: Vector3 },
	nextWisp: number,
	lastCollect: number,
	eligible: boolean,
}

local ghosts: { [Player]: Ghost } = {}
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

local function inBounds(venue: string, position: Vector3): boolean
	local box = BOUNDS[venue]
	local localPos = position - origin(venue)
	return localPos.X >= box[1].X - 2
		and localPos.X <= box[2].X + 2
		and localPos.Y >= box[1].Y - 4
		and localPos.Y <= box[2].Y + 4
		and localPos.Z >= box[1].Z - 2
		and localPos.Z <= box[2].Z + 2
end

-- Invisible walls, floor and ceiling around a venue that only ghosts bump into.
local function buildBox(parent: Instance, venue: string)
	local box = BOUNDS[venue]
	local o = origin(venue)
	local min, max = o + box[1], o + box[2]
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
	character:SetAttribute("Specter", true)
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
		humanoid.DisplayName = ps.alias
	end
	CharacterService.applyOutfit(player)
	ghost.venue = venueForPhase(Match.phase)
	character:PivotTo(spotIn(ghost.venue))
	fillWisps(ghost)
	ghost.eligible = not hasAllyAlive(ps)
	GhostRemote:FireClient(player, { action = "rise", alias = ps.alias })
	sendNames(player, ghost)
	sendDuties(player, ghost)
end

local function onRequest(player: Player, payload: any)
	if type(payload) ~= "table" or not RateLimit.allow(player, "ghost", 0.2) then
		return
	end
	local ghost = ghosts[player]
	if not ghost or not GhostService.isGhost(player) then
		return
	end
	if payload.action == "collect" then
		onCollect(player, ghost, payload.id)
	elseif payload.action == "jump" and (payload.venue == "map" or payload.venue == "meeting") then
		moveTo(ghost, payload.venue)
	end
end

local function watchdog()
	while true do
		task.wait(1)
		if Match.active then
			for player, ghost in pairs(ghosts) do
				local character = player.Character
				local root = if character and character:GetAttribute("Specter")
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				if root and root:IsA("BasePart") then
					local inMap = inBounds("map", root.Position)
					local inMeeting = inBounds("meeting", root.Position)
					if not inMap and not inMeeting then
						character:PivotTo(spotIn(ghost.venue))
					elseif root.AssemblyLinearVelocity.Magnitude > 120 then
						root.AssemblyLinearVelocity = Vector3.zero
					end
				end
			end
		end
	end
end

-- Match hooks ---------------------------------------------------------------------------------

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
end

function GhostService.init()
	GhostRemote.OnServerEvent:Connect(onRequest)
	CharacterService.CharacterSpawned:Connect(function(player, character)
		if GhostService.isGhost(player) then
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
	end)
	task.spawn(watchdog)
end

return GhostService
