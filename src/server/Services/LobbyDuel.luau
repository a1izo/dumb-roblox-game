--!strict
-- The name duel under the lobby's ribs, run by the server (rules: Shared/LobbyGames/Duel).
--
-- A client asks to step up to a stone, to step down, or hands in a name; nothing else. When both stones
-- are taken the server invents the two names and the leak begins. No name leaves the server while a duel
-- is on: each duellist is sent their own name and the other's mask, and what they write is checked here and
-- shown to nobody. Everyone else sees who stands at the stones and how it ended, on the stones' slates
-- (and attribute Holder on each stone's part, the user id of whoever stands there, for the prompts).
--
-- Part of the lobby's games: Services/LobbyGameService owns the loop and the requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Duel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyGames"):WaitForChild("Duel"))

local LobbyDuel = {}

export type Context = {
	tell: (Player, { [string]: any }) -> (),
	root: (Player) -> BasePart?,
	-- A lobby player in plain sight (not in a case, not watching one, not a hidden Deathsinger).
	playable: (Player) -> boolean,
	-- Ends whatever other lobby game the player is in.
	leaveOthers: (Player) -> (),
	-- Adds a duel won to the player's profile; returns how many that makes.
	won: (Player) -> number,
}

type Stone = { at: Vector3, part: BasePart, label: TextLabel }

local STAND_RANGE = 12 -- studs from a stone within which one can step up to it
local STAY_RANGE = 16 -- walking farther than this from one's stone gives it up
local SHOW = 5 -- seconds the result stays on the slates before the stones are free again

local ctx: Context? = nil
local stones: { Stone } = {}
local holders: { [number]: Player } = {}
local state: Duel.State? = nil
-- While a result shows (os.clock() until it is wiped), nobody steps up or down.
local clearAt: number? = nil
local rng = Random.new()

local function sideOf(player: Player): number?
	for index, holder in pairs(holders) do
		if holder == player then
			return index
		end
	end
	return nil
end

local function write(index: number, text: string)
	local stone = stones[index]
	if stone and stone.label.Parent then
		stone.label.Text = text
	end
end

local function setHolder(index: number, player: Player?)
	holders[index] = player :: any
	local stone = stones[index]
	if stone and stone.part.Parent then
		stone.part:SetAttribute("Holder", if player then player.UserId else nil)
	end
	write(index, if player then player.DisplayName else "")
end

-- A moment of this server's clock (os.clock()) as the time every client can count down to.
local function shared(at: number): number
	return workspace:GetServerTimeNow() + (at - os.clock())
end

local function free(index: number, why: string)
	local context = ctx
	local player = holders[index]
	setHolder(index, nil)
	if player and player.Parent and context then
		context.tell(player, { game = "duel", kind = "left", why = why })
	end
end

local function begin()
	local context = ctx
	if not context or not holders[1] or not holders[2] then
		return
	end
	local now = os.clock()
	local nameA, nameB = Duel.names(rng)
	local duel = Duel.new(nameA, nameB, now)
	state = duel
	for index = 1, 2 do
		local other = Duel.other(index)
		context.tell(holders[index], {
			game = "duel",
			kind = "start",
			you = duel.sides[index].name,
			yourMask = Duel.mask(duel, index),
			rival = holders[other].DisplayName,
			mask = Duel.mask(duel, other),
			endsAt = shared(now + Duel.LIMIT),
		})
	end
end

-- The duel is over: `winner` is the side that won (nil: nobody). Both are told both names, the slates say
-- how it went, and a moment later the stones are free again.
local function finish(winner: number?, why: string)
	local context = ctx
	local duel = state
	if not context or not duel then
		return
	end
	duel.over = true
	state = nil
	clearAt = os.clock() + SHOW
	for index = 1, 2 do
		local player = holders[index]
		if player then
			local result = if winner == nil then "draw" elseif winner == index then "won" else "lost"
			write(index, player.DisplayName .. "\n" .. string.upper(result))
			if player.Parent then
				context.tell(player, {
					game = "duel",
					kind = "over",
					result = result,
					why = why,
					you = duel.sides[index].name,
					rival = duel.sides[Duel.other(index)].name,
					wins = if result == "won" then context.won(player) else nil,
				})
			end
		end
	end
end

-- The player steps down, walks off or leaves the server: mid-duel that hands it to the other.
local function leave(player: Player, why: string)
	local index = sideOf(player)
	if not index then
		return
	end
	if state then
		finish(Duel.other(index), "forfeit")
	elseif clearAt == nil then
		free(index, why)
	end
end

function LobbyDuel.holds(player: Player): boolean
	return sideOf(player) ~= nil
end

-- The player left the lobby's games (left the server, began another game, dived into the rift).
function LobbyDuel.cancel(player: Player)
	leave(player, "left")
end

local function stand(player: Player, index: number)
	local context = ctx
	local stone = stones[index]
	if not context or not stone or state or clearAt or holders[index] or sideOf(player) then
		return
	end
	local part = context.root(player)
	if not part or not context.playable(player) or (part.Position - stone.at).Magnitude > STAND_RANGE then
		return
	end
	context.leaveOthers(player)
	setHolder(index, player)
	context.tell(player, { game = "duel", kind = "stand", stone = index })
	begin()
end

local function guess(player: Player, text: string)
	local context = ctx
	local duel = state
	local index = sideOf(player)
	if not context or not duel or not index then
		return
	end
	local now = os.clock()
	local result = Duel.guess(duel, index, text, now)
	if result == "win" then
		finish(index, "named")
	elseif result == "miss" then
		context.tell(player, { game = "duel", kind = "miss", lockedUntil = shared(now + Duel.LOCKOUT) })
		local rival = holders[Duel.other(index)]
		if rival and rival.Parent then
			context.tell(rival, { game = "duel", kind = "rivalMiss" })
		end
	end
end

function LobbyDuel.request(player: Player, action: string, payload: any)
	if action == "stand" and type(payload.stone) == "number" then
		stand(player, math.floor(payload.stone))
	elseif action == "leave" then
		leave(player, "left")
	elseif action == "guess" and type(payload.text) == "string" and #payload.text <= 200 then
		guess(player, payload.text)
	end
end

function LobbyDuel.step()
	local context = ctx
	if not context then
		return
	end
	local now = os.clock()
	if clearAt then
		if now >= clearAt then
			clearAt = nil
			for index = 1, 2 do
				if holders[index] then
					free(index, "done")
				end
			end
		end
		return
	end
	for index = 1, 2 do
		local player = holders[index]
		if player and clearAt == nil then
			local part = context.root(player)
			if player.Parent and not context.playable(player) then
				-- Called to a case: nobody's fault, nobody's win.
				if state then
					finish(nil, "called")
				else
					free(index, "away")
				end
			elseif not player.Parent or not part or (part.Position - stones[index].at).Magnitude > STAY_RANGE then
				leave(player, "away")
			end
		end
	end
	local duel = state
	if not duel then
		return
	end
	if Duel.expired(duel, now) then
		finish(nil, "time")
	elseif Duel.due(duel, now) then
		Duel.leak(duel, now, rng)
		for index = 1, 2 do
			local other = Duel.other(index)
			context.tell(holders[index], {
				game = "duel",
				kind = "leak",
				mask = Duel.mask(duel, other),
				yourMask = Duel.mask(duel, index),
				hidden = Duel.hidden(duel, other),
			})
		end
	end
end

-- Handed the two stones the lobby built (Maps/LobbyGames) on every build of the lobby.
function LobbyDuel.setup(context: Context, built: any)
	state = nil
	clearAt = nil
	for index = 1, 2 do
		if holders[index] then
			free(index, "reset")
		end
	end
	ctx = context
	stones = if built then built.stones else {}
end

return LobbyDuel
