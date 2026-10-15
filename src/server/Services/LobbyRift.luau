--!strict
-- Last breath, the dive into the lobby's rift, run by the server (rules: Shared/LobbyGames/LastBreath).
--
-- A client says when its player has gone over the rim ("enter") and when they brake ("brake"); nothing
-- else. The server checks the first against where the character really is, and scores the dive from its
-- own clock: the fall is one curve of time, so the two moments settle the gap. What a diver is doing shows
-- on their character for every client to pose it (attribute Dive: "fall", "brake", "caught", "crash";
-- DiveSeed, the seed of the body's tumble, which the diver's client chose; and DiveGap, the studs left, while
-- they hang there). A moment after coming to rest the rift gives the diver
-- back, at the rim. Divers whose falls begin together are told how they ranked.
--
-- Part of the lobby's games: Services/LobbyGameService owns the loop and the requests, and hands this
-- what it needs (Context).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Games = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames")
local LastBreath = require(Games:WaitForChild("LastBreath"))
local Toss = require(Games:WaitForChild("Toss"))

local LeaderboardService = require(script.Parent.LeaderboardService)

local LobbyRift = {}

export type Context = {
	tell: (Player, { [string]: any }) -> (),
	improve: (Player, string, number, (number, number) -> boolean) -> (boolean, number),
	root: (Player) -> BasePart?,
	-- A lobby player in plain sight (not in a case, not watching one, not a hidden Deathsinger).
	playable: (Player) -> boolean,
	sendHome: (Player, Vector3) -> (),
	-- Ends whatever other lobby game the player is in.
	leaveOthers: (Player) -> (),
}

type Wave = { first: number, dives: { Dive }, told: boolean }
type Dive = {
	player: Player,
	name: string,
	start: number,
	wave: Wave,
	brakeAt: number?,
	outcome: LastBreath.Outcome?,
	rested: boolean,
	over: boolean,
}

local ctx: Context? = nil
local info: any = nil
local height = 0
local dives: { [Player]: Dive } = {}
local waves: { Wave } = {}
-- When each diver was last given back (os.clock()): for a moment after it their body may still be seen far
-- under the lobby (their client owns it, and has to hear of the move).
local backAt: { [Player]: number } = {}
local BACK_GRACE = 2

local function pose(player: Player, value: string?, gap: number?)
	local character = player.Character
	if character then
		character:SetAttribute("Dive", value)
		character:SetAttribute("DiveGap", gap)
		if value == nil then
			character:SetAttribute("DiveSeed", nil)
		end
	end
end

local function waveFor(now: number): Wave
	local last = waves[#waves]
	if last and not last.told and LastBreath.sameWave(last.first, now) then
		return last
	end
	local wave: Wave = { first = now, dives = {}, told = false }
	table.insert(waves, wave)
	return wave
end

-- Tells a wave's divers how they ranked (two or more of them).
local function announce(wave: Wave)
	wave.told = true
	local context = ctx
	if #wave.dives < 2 or not context then
		return
	end
	local rows: { LastBreath.Row } = {}
	for _, dive in ipairs(wave.dives) do
		local outcome = dive.outcome
		table.insert(rows, {
			id = dive,
			crashed = outcome == nil or outcome.crashed,
			gap = if outcome then outcome.gap else 0,
		})
	end
	local ranked = LastBreath.rank(rows)
	local list = {}
	for place, row in ipairs(ranked) do
		local dive: Dive = row.id
		list[place] = { name = dive.name, userId = dive.player.UserId, crashed = row.crashed, gap = row.gap }
	end
	for place, row in ipairs(ranked) do
		local dive: Dive = row.id
		if dive.player.Parent then
			context.tell(dive.player, { game = "rift", kind = "wave", place = place, rows = list })
		end
	end
end

local function close(dive: Dive)
	if dive.over then
		return
	end
	dive.over = true
	if dives[dive.player] == dive then
		dives[dive.player] = nil
	end
	pose(dive.player, nil, nil)
end

-- Is the player in a dive, or only just out of one (so nothing else should fetch them from under the lobby)?
function LobbyRift.diving(player: Player): boolean
	if dives[player] ~= nil then
		return true
	end
	local back = backAt[player]
	return back ~= nil and os.clock() - back < BACK_GRACE
end

-- The player left the lobby's games (called to a case, left the server): their dive is over, unscored.
function LobbyRift.cancel(player: Player)
	local dive = dives[player]
	if dive then
		close(dive)
	end
	backAt[player] = nil
end

local function enter(player: Player, seed: any)
	local context = ctx
	if not context or not info or dives[player] or not context.playable(player) then
		return
	end
	local part = context.root(player)
	if not part then
		return
	end
	local at = part.Position
	local depth = Toss.depth(Vector2.new(at.X, at.Z), info.rift)
	if depth > 1.25 or at.Y > info.rimY + 4 or at.Y < info.rimY - 60 then
		-- Not in the rift: the client lets go again.
		context.tell(player, { game = "rift", kind = "refused" })
		return
	end
	context.leaveOthers(player)
	local now = os.clock()
	local dive: Dive = {
		player = player,
		name = player.DisplayName,
		start = now,
		wave = waveFor(now),
		brakeAt = nil,
		outcome = nil,
		rested = false,
		over = false,
	}
	dives[player] = dive
	table.insert(dive.wave.dives, dive)
	local character = player.Character
	if character then
		-- (Before Dive, so every client has the seed when it starts drawing the tumble.)
		character:SetAttribute("DiveSeed", if type(seed) == "number" then math.floor(seed) % 16777216 else 1)
	end
	pose(player, "fall", nil)
	context.tell(player, { game = "rift", kind = "start" })
end

local function brake(player: Player)
	local context = ctx
	local dive = dives[player]
	if not context or not dive or dive.brakeAt or dive.outcome then
		return
	end
	local at = os.clock() - dive.start
	if at < LastBreath.MIN_BRAKE then
		return
	end
	local outcome = LastBreath.outcome(height, at)
	dive.brakeAt = at
	dive.outcome = outcome
	pose(player, "brake", nil)
	context.tell(player, { game = "rift", kind = "brake", at = at, crashed = outcome.crashed, gap = outcome.gap })
end

function LobbyRift.request(player: Player, action: string, payload: any)
	if action == "enter" then
		enter(player, if type(payload) == "table" then payload.seed else nil)
	elseif action == "brake" then
		brake(player)
	end
end

function LobbyRift.step()
	local context = ctx
	if not context or not info then
		return
	end
	local now = os.clock()
	local impact = LastBreath.timeToFall(height)
	for player, dive in pairs(dives) do
		if not player.Parent or not context.playable(player) or not context.root(player) then
			close(dive)
			continue
		end
		local t = now - dive.start
		if not dive.outcome and t >= impact then
			dive.outcome = LastBreath.outcome(height, nil)
		end
		local outcome = dive.outcome
		if outcome and not dive.rested and t >= outcome.restAt then
			dive.rested = true
			if outcome.crashed then
				pose(player, "crash", nil)
				context.tell(player, { game = "rift", kind = "rest", crashed = true })
			else
				pose(player, "caught", outcome.gap)
				local isBest, best = context.improve(player, "riftBest", outcome.gap, LastBreath.isBetter)
				if isBest then
					LeaderboardService.record(player, "rift", outcome.gap)
				end
				context.tell(player, {
					game = "rift",
					kind = "rest",
					crashed = false,
					gap = outcome.gap,
					best = best,
					newBest = isBest,
				})
			end
		end
		if outcome and t >= outcome.restAt + LastBreath.HOLD then
			-- Told first, so the client lets the body go before it is moved.
			context.tell(player, { game = "rift", kind = "end" })
			close(dive)
			backAt[player] = now
			context.sendHome(player, info.back)
		end
	end
	-- A wave is told once nobody can join it any more and all its divers are back.
	for index = #waves, 1, -1 do
		local wave = waves[index]
		if not wave.told and now - wave.first > LastBreath.WAVE then
			local open = false
			for _, dive in ipairs(wave.dives) do
				if not dive.over then
					open = true
				end
			end
			if not open then
				announce(wave)
			end
		end
		if wave.told then
			table.remove(waves, index)
		end
	end
end

-- Handed what the lobby built (Maps/LobbyGames: the rift's shape, the rim's and the roof's heights, where
-- to set a diver down) on every build of the lobby.
function LobbyRift.setup(context: Context, built: any)
	for _, dive in pairs(dives) do
		close(dive)
	end
	table.clear(waves)
	ctx = context
	info = built
	height = if built then LastBreath.height(built.rimY, built.roofY) else 0
end

return LobbyRift
