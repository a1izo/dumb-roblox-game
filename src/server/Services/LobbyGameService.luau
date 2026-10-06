--!strict
-- The lobby mini-games, run by the server: the Spire Ascent, the rune courtyard, the bone dice and the
-- rift stone-toss. The rules are in Shared/LobbyGames (and tested); the objects are Maps/LobbyGames'.
-- Everything here is the server's say: a run is checked against where the character really is
-- (checkpoints in order and in a believable time, tiles actually stepped on), the dice and the
-- throws are rolled here, and a client only ever asks to start, sit, roll or throw.
--
-- A player in a case (or watching one) is in none of these: their runs end the moment they are
-- called to a match. Nothing here pays coins or XP; bests are saved in the profile and the Spire
-- Ascent and the rune rounds also go on the global boards (LeaderboardService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Games = Shared:WaitForChild("LobbyGames")
local Dice = require(Games:WaitForChild("Dice"))
local Parkour = require(Games:WaitForChild("Parkour"))
local Runes = require(Games:WaitForChild("Runes"))
local Toss = require(Games:WaitForChild("Toss"))
local SpiritTrial = require(Games:WaitForChild("SpiritTrial"))

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local LobbyGameService = {}

local requestRemote = Net.event("LobbyGame")
local stateRemote = Net.event("LobbyGameState")

local POLL = 0.2
local START_RANGE = 16 -- studs from a pad or a seat within which a request counts

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

-- The dice table.
local seats: { [number]: Player? } = {}
local rolls: { [Player]: { d1: number, d2: number, total: number } } = {}
local streaks: { [Player]: number } = {}
local windowEndsAt: number? = nil
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
-- Specter waiting in the lobby (hidden) may play the solo games, not the shared dice table.
local function blocked(player: Player, game: string?): string?
	local ok, ghost = pcall(function()
		return require(script.Parent.GhostService)
	end)
	if Match.active and Match.get(player) ~= nil then
		if ok and ghost.isAway(player) and game ~= "dice" then
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

-- The bone dice -----------------------------------------------------------------------------------------

local function seatOf(player: Player): number?
	for index = 1, Dice.SEATS do
		if seats[index] == player then
			return index
		end
	end
	return nil
end

local function seated(): { Player }
	local out = {}
	for index = 1, Dice.SEATS do
		local player = seats[index]
		if player then
			table.insert(out, player)
		end
	end
	return out
end

local function setBoard(text: string)
	if games then
		games.dice.board.Text = text
	end
end

local function refreshBoard()
	local here = seated()
	if #here == 0 then
		setBoard("BONE DICE\nSit on a stool to play.")
	else
		local names = {}
		for _, player in ipairs(here) do
			table.insert(names, player.DisplayName)
		end
		setBoard("BONE DICE\n" .. table.concat(names, ", "))
	end
end

local function tumble(d1: number, d2: number)
	for index, value in ipairs({ d1, d2 }) do
		local die: BasePart = games.dice.dice[index]
		local face: TextLabel = games.dice.faces[index]
		face.Text = "?"
		local spin = CFrame.Angles(
			math.rad(rng:NextInteger(180, 540)),
			math.rad(rng:NextInteger(0, 360)),
			math.rad(rng:NextInteger(180, 540))
		)
		local settle = CFrame.new(die.Position) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 360)), 0)
		local tween = TweenService:Create(
			die,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = settle * spin }
		)
		tween.Completed:Once(function()
			die.CFrame = settle
			face.Text = tostring(value)
		end)
		tween:Play()
	end
end

local function settleDice()
	windowEndsAt = nil
	local totals: { [Player]: number } = {}
	local count = 0
	for player, roll in pairs(rolls) do
		if player.Parent and seatOf(player) then
			totals[player] = roll.total
			count += 1
		end
	end
	if count == 0 then
		table.clear(rolls)
		return
	end
	local house: number? = nil
	if count == 1 then
		local a, b = Dice.roll(rng)
		house = a + b
	end
	local outcome = Dice.settle(totals, house)
	local lines = {}
	for player, total in pairs(totals) do
		table.insert(lines, string.format("%s %d", player.DisplayName, total))
	end
	table.sort(lines)
	for player, total in pairs(totals) do
		local result = "push"
		if table.find(outcome.winners, player) then
			result = "win"
		elseif table.find(outcome.losers, player) then
			result = "lose"
		end
		streaks[player] = Dice.streak(streaks[player] or 0, result)
		local isBest, best = improve(player, "diceBest", streaks[player], function(old, value)
			return value > old
		end)
		tell(player, {
			game = "dice",
			kind = "result",
			total = total,
			house = house,
			result = result,
			streak = streaks[player],
			best = best,
			newBest = isBest,
		})
	end
	local headline = if outcome.push
		then "A tie."
		elseif #outcome.winners > 0 then "Won: " .. (outcome.winners[1] :: Player).DisplayName
		else "Lost to the realm."
	setBoard(
		"BONE DICE\n"
			.. table.concat(lines, "  ·  ")
			.. (if house then "  ·  realm " .. house else "")
			.. "\n"
			.. headline
	)
	table.clear(rolls)
end

local function sit(player: Player, index: number)
	local seat: Seat? = games.dice.seats[index]
	local hum = humanoid(player)
	local part = root(player)
	if not seat or not hum or not part or seats[index] ~= nil then
		return
	end
	if (part.Position - seat.Position).Magnitude > START_RANGE then
		return
	end
	for other, who in pairs(seats) do
		if who == player then
			seats[other] = nil
		end
	end
	seats[index] = player
	seat:Sit(hum)
	tell(player, { game = "dice", kind = "seated", seat = index, streak = streaks[player] or 0 })
	refreshBoard()
end

local function leaveDice(player: Player)
	for index, who in pairs(seats) do
		if who == player then
			seats[index] = nil
		end
	end
	rolls[player] = nil
	refreshBoard()
end

local function rollDice(player: Player)
	if not seatOf(player) or rolls[player] or not RateLimit.allow(player, "diceRoll", Dice.COOLDOWN) then
		return
	end
	local d1, d2 = Dice.roll(rng)
	rolls[player] = { d1 = d1, d2 = d2, total = d1 + d2 }
	tumble(d1, d2)
	tell(player, { game = "dice", kind = "rolled", d1 = d1, d2 = d2 })
	local here = seated()
	if #here <= 1 then
		task.delay(1, settleDice)
	elseif not windowEndsAt then
		windowEndsAt = os.clock() + Dice.WINDOW
	end
end

local function diceStep()
	for index = 1, Dice.SEATS do
		local player = seats[index]
		if player then
			local hum = humanoid(player)
			local seat: Seat = games.dice.seats[index]
			if not player.Parent or not hum or hum.SeatPart ~= seat or blocked(player, "dice") then
				seats[index] = nil
				rolls[player] = nil
				if player.Parent then
					tell(player, { game = "dice", kind = "left" })
				end
				refreshBoard()
			end
		end
	end
	if windowEndsAt then
		local all = true
		for _, player in ipairs(seated()) do
			if not rolls[player] then
				all = false
			end
		end
		if all or os.clock() >= windowEndsAt then
			settleDice()
		end
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

-- The loop and the requests -------------------------------------------------------------------------------

local function step()
	if not games then
		return
	end
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
	diceStep()
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
	elseif game == "dice" then
		if action == "sit" and type(payload.seat) == "number" then
			local index = math.floor(payload.seat)
			if index >= 1 and index <= Dice.SEATS then
				sit(player, index)
			end
		elseif action == "roll" then
			rollDice(player)
		elseif action == "leave" then
			leaveDice(player)
			tell(player, { game = "dice", kind = "left" })
			local hum = humanoid(player)
			if hum then
				hum.Sit = false
			end
		end
	elseif game == "toss" and action == "throw" then
		throwStone(player, payload.look)
	end
end

-- Handed the objects the lobby just built (MapService, on every build of the lobby).
function LobbyGameService.setup(built: any)
	for player in pairs(sessions) do
		cancel(player, "reset")
	end
	table.clear(seats)
	table.clear(rolls)
	windowEndsAt = nil
	games = built
	refreshBoard()
end

function LobbyGameService.init()
	requestRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		streaks[player] = nil
		lastToss[player] = nil
		if games then
			leaveDice(player)
		end
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
