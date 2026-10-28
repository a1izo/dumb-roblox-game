--!strict
-- The lobby mini-games, run by the server: the Spire Ascent, the rune courtyard and the rift stone-toss.
-- The rules are in Shared/LobbyGames (and tested); the objects are Maps/LobbyGames'. Everything here is the
-- server's say: a run is checked against where the character really is (checkpoints in order and in a
-- believable time, tiles actually stepped on), the throws are rolled here, and a client only ever asks to
-- start or throw.
--
-- A player in a case (or watching one) is in none of these: their runs end the moment they are
-- called to a match. Nothing here pays coins or XP; bests are saved in the profile and the Spire
-- Ascent and the rune rounds also go on the global boards (LeaderboardService).
--
-- Four more things to do in the lobby are routed through here: the dive into the rift (LobbyRift),
-- Death's mark (LobbyMark), the name duel (LobbyDuel) and the seven grey apples (below). And one safeguard: whoever falls out of
-- the lobby's world is set back on the terrace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Venues = require(Shared:WaitForChild("Venues"))
local Games = Shared:WaitForChild("LobbyGames")
local Parkour = require(Games:WaitForChild("Parkour"))
local Runes = require(Games:WaitForChild("Runes"))
local Toss = require(Games:WaitForChild("Toss"))
local SpiritTrial = require(Games:WaitForChild("SpiritTrial"))

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LobbyDuel = require(script.Parent.LobbyDuel)
local LobbyMark = require(script.Parent.LobbyMark)
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
	spirit: SpiritTrial.Session?,
	runes: Runes.State?,
	state: string?, -- runes: "show" or "input"
	inputAt: number?,
	deadline: number?,
	lastTile: number?,
}

local games: any = nil -- what Maps/LobbyGames built, set by MapService
local sessions: { [Player]: Session } = {}
local rng = Random.new()

local lastToss: { [Player]: number } = {}

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
-- ("shared": the rift, Death's mark, the duel).
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

-- The spirit trial (Deathsingers waiting in the lobby only) ------------------------------------------------

local spiritRings: { Vector3 }? = nil
local spiritCenter = Vector3.zero

-- The loop's rings, dropped onto the lobby's real floor around its spawn (worked out once).
local function spiritCourse(): { Vector3 }?
	if spiritRings then
		return spiritRings
	end
	local lobby = workspace:FindFirstChild("LGameLobby")
	local spawn = if lobby then lobby:FindFirstChild("LobbySpawn", true) else nil
	if not lobby or not spawn or not spawn:IsA("BasePart") then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { lobby }
	local rings = {}
	for _, spot in ipairs(SpiritTrial.layout(spawn.Position)) do
		local hit = workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
		table.insert(rings, (if hit then hit.Position else spot) + Vector3.new(0, 3.5, 0))
	end
	spiritRings = rings
	spiritCenter = spawn.Position
	return rings
end

local function isAway(player: Player): boolean
	local ok, ghost = pcall(function()
		return require(script.Parent.GhostService)
	end)
	return ok and ghost.isAway(player)
end

local function startSpirit(player: Player)
	local rings = spiritCourse()
	if not rings or not isAway(player) then
		return
	end
	cancel(player, "restart")
	sessions[player] = { game = "spirit", spirit = SpiritTrial.newSession(os.clock()) }
	tell(player, { game = "spirit", kind = "start", at = workspace:GetServerTimeNow(), rings = rings })
end

local function spiritStep(player: Player, session: Session, position: Vector3)
	local run = session.spirit :: SpiritTrial.Session
	local rings = spiritRings
	if not rings or not isAway(player) then
		cancel(player, "case")
		return
	end
	if (flat(position) - flat(spiritCenter)).Magnitude > SpiritTrial.WANDER then
		cancel(player, "wandered")
		return
	end
	local index = run.reached + 1
	local ring = rings[index]
	if not ring or (position - ring).Magnitude > SpiritTrial.REACH then
		return
	end
	local from = if run.reached > 0 then rings[run.reached] else position
	local ok = SpiritTrial.reach(run, index, os.clock(), (ring - from).Magnitude)
	if not ok then
		return
	end
	tell(player, { game = "spirit", kind = "ring", reached = index })
	if index < SpiritTrial.RINGS then
		return
	end
	sessions[player] = nil
	local time = SpiritTrial.finish(run, os.clock())
	if not time then
		tell(player, { game = "spirit", kind = "end", why = "invalid" })
		return
	end
	local ps = Match.get(player)
	if ps then
		ps.stats.spiritRuns = (ps.stats.spiritRuns or 0) + 1
	end
	local isBest, best = improve(player, "spiritBest", time, SpiritTrial.isBetter)
	if isBest then
		-- Held off the public board until the case closes (LeaderboardService.hold).
		LeaderboardService.record(player, "spirit", time)
	end
	tell(player, { game = "spirit", kind = "finish", time = time, best = best, newBest = isBest })
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

-- The rune courtyard -------------------------------------------------------------------------------------

local function showRound(player: Player, session: Session)
	local state = session.runes :: Runes.State
	session.state = "show"
	session.inputAt = os.clock() + Runes.showTime(#state.seq)
	tell(player, { game = "runes", kind = "show", seq = state.seq, round = state.round, step = Runes.STEP })
end

local function startRunes(player: Player)
	local part = root(player)
	if not part or (part.Position - games.runes.start).Magnitude > START_RANGE then
		return
	end
	cancel(player, "restart")
	local session: Session = { game = "runes", runes = Runes.start(rng:NextInteger(1, 2 ^ 30)) }
	sessions[player] = session
	tell(player, { game = "runes", kind = "start" })
	showRound(player, session)
end

local function endRunes(player: Player, session: Session, why: string)
	local rounds = Runes.rounds(session.runes :: Runes.State)
	sessions[player] = nil
	local isBest, best = improve(player, "runesBest", rounds, function(old, value)
		return value > old
	end)
	if isBest then
		LeaderboardService.record(player, "runes", rounds)
	end
	tell(player, { game = "runes", kind = "over", rounds = rounds, best = best, newBest = isBest, why = why })
end

local function runesStep(player: Player, session: Session, position: Vector3)
	local g = games.runes
	if (flat(position) - flat(g.center)).Magnitude > Runes.WANDER then
		cancel(player, "left")
		return
	end
	local now = os.clock()
	local tile: number? = nil
	if math.abs(position.Y - g.center.Y) < 8 then
		tile = Runes.tileAt(position.X - g.center.X, position.Z - g.center.Z, g.tile, g.gap)
	end
	if session.state == "show" then
		if now >= (session.inputAt or 0) then
			session.state = "input"
			session.lastTile = tile
			session.deadline = now + Runes.INPUT_TIMEOUT
			tell(player, { game = "runes", kind = "input" })
		end
		return
	end
	if tile ~= session.lastTile then
		session.lastTile = tile
		if tile then
			local state = session.runes :: Runes.State
			local result = Runes.step(state, tile)
			tell(player, { game = "runes", kind = "step", tile = tile, ok = result ~= "wrong" })
			if result == "wrong" then
				endRunes(player, session, "wrong")
			elseif result == "round" then
				if Runes.rounds(state) >= Runes.MAX_ROUNDS then
					endRunes(player, session, "perfect")
				else
					showRound(player, session)
				end
			else
				session.deadline = now + Runes.INPUT_TIMEOUT
			end
			return
		end
	end
	if session.deadline and now > session.deadline then
		endRunes(player, session, "slow")
	end
end

-- The stone-toss -------------------------------------------------------------------------------------------

local function throwStone(player: Player, look: any)
	local part = root(player)
	if typeof(look) ~= "Vector3" or not part then
		return
	end
	local mag = look.Magnitude
	if mag < 0.5 or mag > 1.5 or (part.Position - games.toss.cairn).Magnitude > Toss.RANGE + 4 then
		return
	end
	local now = os.clock()
	if now - (lastToss[player] or -10) < Toss.COOLDOWN then
		return
	end
	lastToss[player] = now
	local unit = look.Unit
	local across = Vector2.new(unit.X, unit.Z)
	if across.Magnitude < 0.05 then
		return
	end
	local pitch = math.deg(math.asin(math.clamp(unit.Y, -1, 1)))
	local result = Toss.result(Vector2.new(part.Position.X, part.Position.Z), across.Unit, pitch, games.toss.rift, rng)
	local isBest, best = false, 0
	if result.hit then
		isBest, best = improve(player, "tossBest", result.echo, Toss.isBetter)
	else
		local mine = bests(player)
		best = if mine then mine.tossBest or 0 else 0
	end
	tell(player, {
		game = "toss",
		kind = "result",
		hit = result.hit,
		land = { x = result.land.X, z = result.land.Y },
		from = { x = part.Position.X, y = part.Position.Y, z = part.Position.Z },
		echo = result.echo,
		bounces = result.bounces,
		flight = result.flight,
		best = best,
		newBest = isBest,
	})
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

-- The seven grey apples -----------------------------------------------------------------------------------

local APPLE_RANGE = 12

-- A player takes an apple they are standing at: kept in the profile (a bit per apple), and all seven earn
-- a title.
local function takeApple(player: Player, index: number)
	local spots: { Vector3 } = games.apples or {}
	local spot = spots[index]
	local part = root(player)
	local data = DataService.get(player)
	if not spot or not part or not data or (part.Position - spot).Magnitude > APPLE_RANGE then
		return
	end
	local mine = data.lobbyGames
	local have = math.floor(tonumber(mine.apples) or 0)
	local bit = bit32.lshift(1, index - 1)
	if bit32.band(have, bit) ~= 0 then
		return
	end
	have = bit32.bor(have, bit)
	mine.apples = have
	local count = 0
	for n = 0, #spots - 1 do
		if bit32.band(have, bit32.lshift(1, n)) ~= 0 then
			count += 1
		end
	end
	if count >= #spots and not data.titles.realmwalker then
		data.titles.realmwalker = true
		data.owned.emote_apple_toss = true
		Match.notify(player, "All 7 apples found. Unlocked Realm Walker and Apple Toss.", "good")
	end
	saved(player)
	tell(player, { game = "apples", kind = "took", index = index, count = count, total = #spots })
end

-- The loop and the requests -------------------------------------------------------------------------------

-- A lobby player in plain sight: not in a case, not watching one, not a hidden Deathsinger.
local function playable(player: Player): boolean
	return blocked(player, "shared") == nil
end

-- Ends whatever a player is doing in the lobby's games (they began another, or dived into the rift).
local function leaveOthers(player: Player)
	cancel(player, "left")
	LobbyMark.cancel(player)
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
	LobbyMark.step()
	LobbyDuel.step()
	for player, session in pairs(sessions) do
		local part = root(player)
		if not player.Parent or not part then
			sessions[player] = nil
		elseif blocked(player, session.game) then
			cancel(player, "case")
		elseif session.game == "parkour" then
			parkourStep(player, session, part.Position)
		elseif session.game == "runes" then
			runesStep(player, session, part.Position)
		elseif session.game == "spirit" then
			spiritStep(player, session, part.Position)
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
	elseif game == "spirit" then
		if action == "start" then
			startSpirit(player)
		elseif action == "leave" then
			cancel(player, "left")
		end
	elseif game == "runes" then
		if action == "start" then
			startRunes(player)
		elseif action == "leave" then
			cancel(player, "left")
		end
	elseif game == "toss" and action == "throw" then
		throwStone(player, payload.look)
	elseif game == "rift" then
		LobbyRift.request(player, action, payload)
	elseif game == "mark" then
		LobbyMark.request(player, action)
	elseif game == "duel" then
		LobbyDuel.request(player, action, payload)
	elseif game == "apples" and action == "take" and type(payload.index) == "number" then
		takeApple(player, math.floor(payload.index))
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
	LobbyMark.setup({
		tell = tell,
		improve = improve,
		root = root,
		humanoid = humanoid,
		playable = playable,
	}, built.mark)
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
		lastToss[player] = nil
		onBridge[player] = nil
		LobbyRift.cancel(player)
		LobbyMark.cancel(player)
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
