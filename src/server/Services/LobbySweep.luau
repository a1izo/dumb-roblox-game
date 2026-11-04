--!strict
-- The Reaper's Sweep, run by the server (rules: Shared/LobbyGames/Sweep).
--
-- A client asks to join at the pad by the dais (or to leave). The first to join opens a round that starts Sweep.WAIT
-- seconds later; whoever joins before then is set down on the dais and is in it. What everyone needs to see is on the
-- dais' pivot part (tag LSweepPivot), for every client: attribute SweepAt (the server time the round began) while one
-- runs, SweepOpen (the server time it will start) while it waits; each player in the round carries attribute Sweeping
-- on their character. A client draws the scythe from SweepAt alone (the rules' angle) and judges its own body against
-- it: struck, it throws itself off and says so. The server also puts out anyone it is sure was struck (feet on the
-- stones as a blade passed, by the angle as that player's screen showed it) and anyone who has left the dais, and keeps
-- the times: the best stand is in the profile (lobbyGames.sweepBest); with others, the last one standing wins.
--
-- Part of the lobby's games: Services/LobbyGameService owns the loop and the requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sweep = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames"):WaitForChild("Sweep"))

local LobbySweep = {}

export type Context = {
	tell: (Player, { [string]: any }) -> (),
	improve: (Player, string, number, (number, number) -> boolean) -> (boolean, number),
	root: (Player) -> BasePart?,
	playable: (Player) -> boolean,
	leaveOthers: (Player) -> (),
}

local JOIN_RANGE = 14 -- studs from the pad (or anywhere on the dais) within which a join counts
local ROOT_UP = 3 -- the root's middle over the soles
local MOST = 12 -- players a round takes at most
local LAG_MORE = 0.12 -- seconds of the player's own lag allowed for besides their ping

type Arena = { centre: Vector3, radius: number, pad: Vector3, pivot: BasePart }

local ctx: Context? = nil
local arena: Arena? = nil
local members: { Player } = {}
local openUntil: number? = nil -- os.clock() the waiting round starts at
local startedAt: number? = nil -- os.clock() the running round began
local startCount = 0
local lastT = 0 -- the round's time at the last check
local rng = Random.new()

local function serverIn(seconds: number): number
	return workspace:GetServerTimeNow() + seconds
end

local function setSweeping(player: Player, on: boolean)
	local character = player.Character
	if character then
		character:SetAttribute("Sweeping", if on then true else nil)
	end
end

-- Puts the round's state on the pivot for every client.
local function publish()
	local a = arena
	if not a then
		return
	end
	a.pivot:SetAttribute("SweepOpen", if openUntil then serverIn(openUntil - os.clock()) else nil)
	a.pivot:SetAttribute("SweepAt", if startedAt then serverIn(startedAt - os.clock()) else nil)
	a.pivot:SetAttribute("SweepCount", #members)
end

local function memberIndex(player: Player): number?
	return table.find(members, player)
end

function LobbySweep.isMember(player: Player): boolean
	return memberIndex(player) ~= nil
end

local function reset()
	for _, member in ipairs(members) do
		setSweeping(member, false)
	end
	table.clear(members)
	openUntil = nil
	startedAt = nil
	startCount = 0
	lastT = 0
	publish()
end

-- Takes a player out of the round: their stand is timed (while it ran) and told; `why` struck, fell, left, away.
local function out(player: Player, why: string)
	local context = ctx
	local index = memberIndex(player)
	if not context or not index then
		return
	end
	table.remove(members, index)
	setSweeping(player, false)
	local began = startedAt
	if began then
		local time = os.clock() - began
		local isBest, best = context.improve(player, "sweepBest", time, Sweep.isBetter)
		if player.Parent then
			context.tell(player, {
				game = "sweep",
				kind = "out",
				why = why,
				time = time,
				best = best,
				newBest = isBest,
				left = #members,
			})
		end
	elseif player.Parent then
		context.tell(player, { game = "sweep", kind = "out", why = why })
	end
	if #members == 0 then
		reset()
	else
		publish()
	end
end

-- The round is over: whoever still stands has won it.
local function finish()
	local context = ctx
	local began = startedAt
	if not context or not began then
		reset()
		return
	end
	local time = os.clock() - began
	for _, member in ipairs(members) do
		local isBest, best = context.improve(member, "sweepBest", time, Sweep.isBetter)
		context.tell(member, {
			game = "sweep",
			kind = "won",
			time = time,
			best = best,
			newBest = isBest,
			alone = startCount < 2,
		})
	end
	reset()
end

-- A spot on the dais to set a joining player down at, clear of the pillar.
local function spot(a: Arena): CFrame
	local angle = rng:NextNumber(0, 2 * math.pi)
	local r = rng:NextNumber(Sweep.INNER + 3, a.radius - 3)
	local at = a.centre + Vector3.new(math.cos(angle) * r, ROOT_UP + 0.5, math.sin(angle) * r)
	return CFrame.lookAt(at, Vector3.new(a.centre.X, at.Y, a.centre.Z))
end

function LobbySweep.request(player: Player, action: string)
	local context = ctx
	local a = arena
	if not context or not a then
		return
	end
	if action == "join" then
		local part = context.root(player)
		if not part or not context.playable(player) or startedAt or memberIndex(player) or #members >= MOST then
			return
		end
		local flat = Vector3.new(part.Position.X, 0, part.Position.Z)
		local onDais = (flat - Vector3.new(a.centre.X, 0, a.centre.Z)).Magnitude < a.radius
		if not onDais and (part.Position - a.pad).Magnitude > JOIN_RANGE then
			return
		end
		context.leaveOthers(player)
		table.insert(members, player)
		setSweeping(player, true)
		if not openUntil then
			openUntil = os.clock() + Sweep.WAIT
		end
		local character = player.Character
		if character then
			character:PivotTo(spot(a))
		end
		publish()
		context.tell(
			player,
			{ game = "sweep", kind = "joined", startsAt = serverIn((openUntil :: number) - os.clock()) }
		)
	elseif action == "leave" then
		out(player, "left")
	elseif action == "struck" then
		if startedAt and memberIndex(player) then
			out(player, "struck")
		end
	end
end

-- The player left the lobby's games (called to a case, left the server, began another game).
function LobbySweep.cancel(player: Player)
	out(player, "left")
end

function LobbySweep.step()
	local context = ctx
	local a = arena
	if not context or not a or #members == 0 then
		return
	end
	local now = os.clock()
	for _, member in ipairs(table.clone(members)) do
		if not member.Parent or not context.playable(member) or not context.root(member) then
			out(member, "away")
		end
	end
	if #members == 0 then
		return
	end
	local waiting = openUntil
	if waiting and not startedAt then
		if now >= waiting then
			openUntil = nil
			startedAt = now
			startCount = #members
			lastT = 0
			publish()
			for _, member in ipairs(members) do
				context.tell(member, { game = "sweep", kind = "start", at = serverIn(0), count = startCount })
			end
		end
		return
	end
	local began = startedAt
	if not began then
		return
	end
	local t = now - began
	if t >= Sweep.LONGEST then
		finish()
		return
	end
	for _, member in ipairs(table.clone(members)) do
		local part = context.root(member)
		if part then
			local offset = Vector2.new(part.Position.X - a.centre.X, part.Position.Z - a.centre.Z)
			local feet = part.Position.Y - ROOT_UP - a.centre.Y
			if feet < -3 or offset.Magnitude > a.radius + 4 then
				out(member, "fell")
			else
				-- (only a body plainly on the stones as a blade passed it, by the angle as its own screen showed it)
				local lag = member:GetNetworkPing() + LAG_MORE
				if Sweep.struck(Sweep.angle(lastT - lag), Sweep.angle(t - lag), offset, feet + 1.0, a.radius) then
					out(member, "struck")
				end
			end
		end
	end
	lastT = t
	if startCount >= 2 and #members == 1 then
		finish()
	end
end

-- Handed the dais (Maps/LobbyGames) on every build of the lobby.
function LobbySweep.setup(context: Context, built: any)
	reset()
	ctx = context
	if built then
		arena = { centre = built.centre, radius = built.radius, pad = built.pad, pivot = built.pivot }
	else
		arena = nil
	end
	publish()
end

return LobbySweep
