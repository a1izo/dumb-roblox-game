--!strict
-- Death's mark, the lobby's game of tag, run by the server (rules: Shared/LobbyGames/Mark).
--
-- A client only asks to join (at the bell) or to leave. The server holds who is in and who carries the
-- mark, passes it when the carrier comes close to another player, tolls the bell, and keeps the streaks.
-- What everyone needs to see is on the characters, for every client: attribute MarkCarrier on whoever
-- carries it (they also walk a little faster), MarkDown on whoever the bell just dropped. Each player in
-- the game is sent its state (who carries it, when the bell tolls next, their own streak).
--
-- Part of the lobby's games: Services/LobbyGameService owns the loop and the requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mark = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames"):WaitForChild("Mark"))

local LobbyMark = {}

export type Context = {
	tell: (Player, { [string]: any }) -> (),
	improve: (Player, string, number, (number, number) -> boolean) -> (boolean, number),
	root: (Player) -> BasePart?,
	humanoid: (Player) -> Humanoid?,
	playable: (Player) -> boolean,
}

local JOIN_RANGE = 16
local WALK = 16

local ctx: Context? = nil
local bell: Vector3? = nil
local state = Mark.new()
local rng = Random.new()
-- Whoever the bell dropped, until they are up again (os.clock()).
local downUntil: { [Player]: number } = {}
local fast: Player? = nil

local function pickIndex(n: number): number
	return rng:NextInteger(1, n)
end

local function setAttribute(player: Player, name: string, value: any)
	local character = player.Character
	if character then
		character:SetAttribute(name, value)
	end
end

local function setSpeed(player: Player, speed: number)
	local context = ctx
	local humanoid = if context then context.humanoid(player) else nil
	local part = if context then context.root(player) else nil
	-- A character the game holds still (a case is opening on them) is left as it is.
	if humanoid and not (part and part.Anchored) then
		humanoid.WalkSpeed = speed
	end
end

-- Puts the mark's look and speed on whoever carries it now, and tells everyone in the game.
local function sync()
	local context = ctx
	if not context then
		return
	end
	local carrier: Player? = state.carrier
	if fast ~= carrier then
		if fast and fast.Parent then
			setAttribute(fast, "MarkCarrier", nil)
			if (downUntil[fast] or 0) <= os.clock() then
				setSpeed(fast, WALK)
			end
		end
		if carrier then
			setAttribute(carrier, "MarkCarrier", true)
			setSpeed(carrier, WALK * Mark.CARRIER_SPEED)
		end
		fast = carrier
	end
	local nextToll = state.nextToll
	local tollAt = if nextToll then workspace:GetServerTimeNow() + (nextToll - os.clock()) else nil
	for _, member: Player in ipairs(state.members) do
		context.tell(member, {
			game = "mark",
			kind = "state",
			carrier = if carrier then carrier.UserId else nil,
			carrierName = if carrier then carrier.DisplayName else nil,
			tollAt = tollAt,
			members = #state.members,
			streak = state.streaks[member] or 0,
		})
	end
end

local function drop(player: Player, why: string)
	local context = ctx
	if not Mark.leave(state, player, os.clock(), pickIndex) then
		return
	end
	downUntil[player] = nil
	if player.Parent then
		setAttribute(player, "MarkCarrier", nil)
		setAttribute(player, "MarkDown", nil)
		setSpeed(player, WALK)
		if context then
			context.tell(player, { game = "mark", kind = "left", why = why })
		end
	end
	if fast == player then
		fast = nil
	end
	sync()
end

function LobbyMark.isMember(player: Player): boolean
	return Mark.isMember(state, player)
end

-- The player left the lobby's games (called to a case, left the server, began another game).
function LobbyMark.cancel(player: Player)
	drop(player, "left")
end

function LobbyMark.request(player: Player, action: string)
	local context = ctx
	local at = bell
	if not context or not at then
		return
	end
	if action == "join" then
		local part = context.root(player)
		if not part or not context.playable(player) or (part.Position - at).Magnitude > JOIN_RANGE then
			return
		end
		if Mark.join(state, player, os.clock(), pickIndex) then
			context.tell(player, { game = "mark", kind = "joined" })
			sync()
		end
	elseif action == "leave" then
		drop(player, "left")
	end
end

local function toll(now: number)
	local context = ctx
	local down: Player?, streaks = Mark.toll(state, now, pickIndex)
	if not context or not down then
		return
	end
	downUntil[down] = now + Mark.DOWN
	setAttribute(down, "MarkDown", true)
	setSpeed(down, 0)
	task.delay(Mark.DOWN, function()
		if down.Parent then
			setAttribute(down, "MarkDown", nil)
			if Mark.isMember(state, down) then
				setSpeed(down, if state.carrier == down then WALK * Mark.CARRIER_SPEED else WALK)
			else
				setSpeed(down, WALK)
			end
		end
	end)
	for _, member: Player in ipairs(state.members) do
		local streak = streaks[member] or 0
		local isBest, best = false, 0
		if streak > 0 then
			isBest, best = context.improve(member, "markBest", streak, Mark.isBetter)
		end
		context.tell(member, {
			game = "mark",
			kind = "toll",
			down = down.UserId,
			downName = down.DisplayName,
			streak = streak,
			best = best,
			newBest = isBest,
		})
	end
	sync()
end

function LobbyMark.step()
	local context = ctx
	if not context then
		return
	end
	local now = os.clock()
	-- Whoever has left the lobby's games is out.
	for _, member: Player in ipairs(table.clone(state.members)) do
		if not member.Parent or not context.playable(member) or not context.root(member) then
			drop(member, "away")
		end
	end
	if Mark.due(state, now) then
		toll(now)
		return
	end
	local carrier: Player? = state.carrier
	if not carrier or not Mark.running(state) or (downUntil[carrier] or 0) > now then
		return
	end
	local from = context.root(carrier)
	if not from then
		return
	end
	local nearest: Player? = nil
	local nearestDistance = math.huge
	for _, member: Player in ipairs(state.members) do
		if member ~= carrier and (downUntil[member] or 0) <= now then
			local part = context.root(member)
			if part then
				local distance = (part.Position - from.Position).Magnitude
				if distance < nearestDistance and Mark.canPass(state, carrier, member, now, distance) then
					nearest = member
					nearestDistance = distance
				end
			end
		end
	end
	if nearest then
		Mark.pass(state, nearest, now)
		context.tell(carrier, { game = "mark", kind = "pass", to = nearest.UserId, toName = nearest.DisplayName })
		context.tell(nearest, { game = "mark", kind = "pass", to = nearest.UserId, toName = nearest.DisplayName })
		sync()
	end
end

-- Handed where the bell stands (Maps/LobbyGames) on every build of the lobby.
function LobbyMark.setup(context: Context, built: any)
	for _, member: Player in ipairs(table.clone(state.members)) do
		drop(member, "reset")
	end
	ctx = context
	bell = if built then built.bell else nil
end

return LobbyMark
