--!strict
-- The lobby mini-games, run by the server: the Spire Ascent here, and routed through here the dive into the rift
-- (LobbyRift) and the name duel (LobbyDuel); the user kept these three on 2026-11-05 and removed the rest. The rules
-- are in Shared/LobbyGames (and tested); the objects are Maps/LobbyGames'. Everything here is the server's say: a run
-- is checked against where the character really is (checkpoints in order and in a believable time), and a client only
-- ever asks to start.
--
-- A player in a case (or watching one) is in none of these: their runs end the moment they are
-- called to a match. Nothing here pays coins or XP; bests are saved in the profile and the Spire
-- Ascent also goes on the global boards (LeaderboardService).
--
-- And one safeguard: whoever falls out of the lobby's world is set back on the terrace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Venues = require(Shared:WaitForChild("Venues"))
local Games = Shared:WaitForChild("LobbyGames")
local Parkour = require(Games:WaitForChild("Parkour"))

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LobbyDuel = require(script.Parent.LobbyDuel)
local LobbyRift = require(script.Parent.LobbyRift)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local LobbyGameService = {}

local requestRemote = Net.event("LobbyGame")
local stateRemote = Net.event("LobbyGameState")

local POLL = 0.2
local START_RANGE = 16 -- studs from a pad within which a request counts

type Session = {
	game: string,
	parkour: Parkour.Session?,
}

local games: any = nil -- what Maps/LobbyGames built, set by MapService
local sessions: { [Player]: Session } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function humanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Why a player may not play `game` now (in a case, or watching one from the lobby), nil when they may. A
-- Specter waiting in the lobby (hidden) may play the solo games, not the ones played in front of others
-- ("shared": the rift, the duel).
local function blocked(player: Player, game: string?): string?
	local ok, ghost = pcall(function()
		return require(script.Parent.GhostService)
	end)
	if Match.active and Match.get(player) ~= nil then
		if ok and ghost.isAway(player) and game ~= "shared" then
			return nil
		end
		return "in a case"
	end
	if ok and ghost.isWatching(player) then
		return "watching"
	end
	return nil
end

local function tell(player: Player, payload: { [string]: any })
	stateRemote:FireClient(player, payload)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Bests ---------------------------------------------------------------------------------------------

local function bests(player: Player): { [string]: number }?
	local data = DataService.get(player)
	return if data then data.lobbyGames else nil
end

local function saved(player: Player)
	DataService.push(player)
	DataService.saveSoon(player)
end

-- The profile's best for a game, and whether `value` beats it (it is then stored).
local function improve(
	player: Player,
	key: string,
	value: number,
	better: (number, number) -> boolean
): (boolean, number)
	local mine = bests(player)
	if not mine then
		return false, 0
	end
	local old = mine[key] or 0
	if better(old, value) then
		mine[key] = value
		saved(player)
		return true, value
	end
	return false, old
end

-- The Spire Ascent ----------------------------------------------------------------------------------------

local function cancel(player: Player, why: string?)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		tell(player, { game = session.game, kind = "end", why = why or "left" })
	end
end

local function startParkour(player: Player)
	local part = root(player)
	if not part or (part.Position - games.parkour.start).Magnitude > START_RANGE then
		return
	end
	cancel(player, "restart")
	local session: Session = { game = "parkour", parkour = Parkour.newSession(os.clock()) }
	sessions[player] = session
	tell(player, { game = "parkour", kind = "start", at = workspace:GetServerTimeNow(), total = Parkour.CHECKPOINTS })
end

local function sendHome(player: Player, spot: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(spot + Vector3.new(0, 4, 0)))
	end
end

local function finishParkour(player: Player, session: Session)
	local run = session.parkour :: Parkour.Session
	local time = Parkour.finish(run, os.clock())
	sessions[player] = nil
	if not time then
		tell(player, { game = "parkour", kind = "end", why = "invalid" })
		return
	end
	local isBest, best = improve(player, "parkourBest", time, Parkour.isBetter)
	if isBest then
		LeaderboardService.record(player, "parkour", time)
	end
	tell(player, { game = "parkour", kind = "finish", time = time, best = best, newBest = isBest })
	sendHome(player, games.parkour.start)
end

local function parkourStep(player: Player, session: Session, position: Vector3)
	local run = session.parkour :: Parkour.Session
	local g = games.parkour
	if (flat(position) - flat(g.center)).Magnitude > Parkour.WANDER then
		cancel(player, "left")
		return
	end
	local reached = run.reached
	local mark: Vector3? = g.marks[reached + 1]
	if mark and Parkour.near(position, mark) then
		local from: Vector3 = if reached == 0 then g.start else g.marks[reached]
		if Parkour.reach(run, reached + 1, os.clock(), (mark - from).Magnitude) then
			tell(
				player,
				{ game = "parkour", kind = "checkpoint", index = reached + 1, time = os.clock() - run.startedAt }
			)
			if reached + 1 >= Parkour.CHECKPOINTS then
				finishParkour(player, session)
			end
		end
		return
	end
	local checkpoint: Vector3 = if reached == 0 then g.start else g.marks[reached]
	if Parkour.fell(position, checkpoint) then
		sendHome(player, checkpoint)
		tell(player, { game = "parkour", kind = "fall", index = reached })
	end
end

-- The catch under the lobby -------------------------------------------------------------------------------

-- Nothing under the lobby's ground is solid (the rift opens on another world's sky, the causeways cross
-- chasms), so whoever has fallen this far below it, or has left the lobby's walkable box, is set back: at
-- the end of the causeway they were on (the end they came from), or else on the terrace. The causeways'
-- parapets keep everyone on them; this is for whatever gets past (a push, a glitch, a wall-hop: Roblox's
-- trick of jumping off a wall, which no height of wall stops).
local CATCH_DEPTH = 60
local OUT_MARGIN = 12 -- studs past the walkable box before a player counts as out of it
local BRIDGE_REACH = 9 -- studs from a causeway's line within which a player counts as on it

-- Who is on a causeway, and from which end they came on to it.
local onBridge: { [Player]: { cf: CFrame, index: number } } = {}

local lobbySpawn: BasePart? = nil

local function spawnPart(): BasePart?
	if lobbySpawn and lobbySpawn.Parent then
		return lobbySpawn
	end
	local lobby = workspace:FindFirstChild("LGameLobby")
	local spawn = if lobby then lobby:FindFirstChild("LobbySpawn", true) else nil
	lobbySpawn = if spawn and spawn:IsA("BasePart") then spawn else nil
	return lobbySpawn
end

-- Is this player in the lobby's world (not in a case's map or its meeting room)?
local function inLobby(player: Player): boolean
	if Match.active and Match.get(player) ~= nil then
		local ok, ghost = pcall(function()
			return require(script.Parent.GhostService)
		end)
		return ok and ghost.isAway(player)
	end
	return true
end

-- Which causeway a point is over (its index), and the end nearer to it.
local function bridgeAt(position: Vector3): (number?, CFrame?)
	for index, bridge in ipairs(games.bridges or {}) do
		local a, b = flat(bridge.a.Position), flat(bridge.b.Position)
		local ab = b - a
		local t = math.clamp((flat(position) - a):Dot(ab) / ab:Dot(ab), 0, 1)
		if (flat(position) - (a + ab * t)).Magnitude <= BRIDGE_REACH then
			return index, if t < 0.5 then bridge.a else bridge.b
		end
	end
	return nil, nil
end

-- Keeps onBridge: set on stepping on to a causeway (the end nearest then), kept while on it or in the air
-- (a fall off it), dropped once standing anywhere else.
local function watchBridges(player: Player, part: BasePart)
	local index, near = bridgeAt(part.Position)
	local hum = humanoid(player)
	local airborne = hum ~= nil and hum.FloorMaterial == Enum.Material.Air
	local mine = onBridge[player]
	if index and near then
		if not mine or mine.index ~= index then
			onBridge[player] = { cf = near, index = index }
		end
	elseif mine and not airborne then
		onBridge[player] = nil
	end
end

local function catchFallen()
	local spawn = spawnPart()
	if not spawn then
		return
	end
	local floor = spawn.Position.Y - CATCH_DEPTH
	for _, player in ipairs(Players:GetPlayers()) do
		local part = root(player)
		-- (A diver is far under the lobby on purpose: the rift gives them back itself.)
		-- (Only in the lobby's own part of the world: a map being looked at between cases, the meeting room
		-- and the cutscene sets stand far from it.)
		if part and inLobby(player) and not LobbyRift.diving(player) and Venues.at(part.Position) == "lobby" then
			local box = games.bounds
			local p = part.Position
			local out = box ~= nil
				and (
					p.X < box.min.X - OUT_MARGIN
					or p.X > box.max.X + OUT_MARGIN
					or p.Z < box.min.Z - OUT_MARGIN
					or p.Z > box.max.Z + OUT_MARGIN
				)
			if p.Y < floor or out then
				cancel(player, "fell")
				local from = onBridge[player]
				onBridge[player] = nil
				if from then
					local character = player.Character
					if character then
						character:PivotTo(from.cf + Vector3.new(0, 4, 0))
					end
				else
					sendHome(player, spawn.Position)
				end
				tell(player, { game = "lobby", kind = "caught" })
			else
				watchBridges(player, part)
			end
		end
	end
end

-- The loop and the requests -------------------------------------------------------------------------------

-- A lobby player in plain sight: not in a case, not watching one, not a hidden Deathsinger.
local function playable(player: Player): boolean
	return blocked(player, "shared") == nil
end

-- Ends whatever a player is doing in the lobby's games (they began another, or dived into the rift).
local function leaveOthers(player: Player)
	cancel(player, "left")
	LobbyDuel.cancel(player)
end

-- A name duel won goes in the profile (a count, nothing more); returns how many that makes.
local function duelWon(player: Player): number
	local mine = bests(player)
	if not mine then
		return 0
	end
	local wins = math.floor(tonumber(mine.duelWins) or 0) + 1
	mine.duelWins = wins
	saved(player)
	return wins
end

local function step()
	if not games then
		return
	end
	catchFallen()
	LobbyRift.step()
	LobbyDuel.step()
	for player, session in pairs(sessions) do
		local part = root(player)
		if not player.Parent or not part then
			sessions[player] = nil
		elseif blocked(player, session.game) then
			cancel(player, "case")
		elseif session.game == "parkour" then
			parkourStep(player, session, part.Position)
		end
	end
end

local function onRequest(player: Player, payload: any)
	if type(payload) ~= "table" or not games then
		return
	end
	local game, action = payload.game, payload.action
	if type(game) ~= "string" or type(action) ~= "string" then
		return
	end
	if not RateLimit.allow(player, "lobbyGame", 0.2) or blocked(player, game) then
		return
	end
	if game == "parkour" then
		if action == "start" then
			startParkour(player)
		elseif action == "leave" then
			cancel(player, "left")
		end
	elseif game == "rift" then
		LobbyRift.request(player, action, payload)
	elseif game == "duel" then
		LobbyDuel.request(player, action, payload)
	end
end

-- Handed the objects the lobby just built (MapService, on every build of the lobby).
function LobbyGameService.setup(built: any)
	for player in pairs(sessions) do
		cancel(player, "reset")
	end
	games = built
	LobbyRift.setup({
		tell = tell,
		improve = improve,
		root = root,
		playable = playable,
		sendHome = sendHome,
		leaveOthers = leaveOthers,
	}, built.dive)
	LobbyDuel.setup({
		tell = tell,
		root = root,
		playable = playable,
		leaveOthers = leaveOthers,
		won = duelWon,
	}, built.duel)
end

function LobbyGameService.init()
	requestRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		onBridge[player] = nil
		LobbyRift.cancel(player)
		LobbyDuel.cancel(player)
	end)
	task.spawn(function()
		while true do
			task.wait(POLL)
			local ok, err = pcall(step)
			if not ok then
				warn("[DeathsGambit] Lobby games: " .. tostring(err))
			end
		end
	end)
	if RunService:IsStudio() then
		print("[DeathsGambit] Lobby games ready.")
	end
end

return LobbyGameService
