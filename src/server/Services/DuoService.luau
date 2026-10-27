-- Duo emotes (Shared/Cosmetics `duo`), in the lobby only: played near someone, they ask first. The nearest player
-- within REACH is asked "Join?" (UI/DuoPanel); if they say yes in time, both play it together, the same on every
-- screen (Controllers/DuoController):
--   Match Point  a rally: the one asked walks to a spot facing the one asking, RALLY studs off (with no room
--                there, both just turn to face each other if they are near enough); once there, every client
--                plays it from the same moment. Not there in WALK_SECONDS: it is called off.
--   High Five, Handshake  free, lobby only: the one asked walks up to face the one asking (MEET studs apart),
--                then both play it from the same moment (Services/EmoteService.playTogether)
--   Cuffed Together  lobby only: the two are chained wrist to wrist (a "DuoChain" ObjectValue in each body
--                naming the other, the asker leading); the one asked walks after the leader. Only "Let go" ends
--                it, pressed by either (the user's call of 2026-10-27: not a jump, not another emote); a death,
--                leaving, a case, or being torn CHAIN_BREAK studs apart (a teleport) still does
-- Test bots can be asked too (in Studio), and answer through Net.simulate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local DuoRemote = Net.event("Duo")

local DuoService = {}

local REACH = 10
local ASK_SECONDS = 15
local RALLY = 12
local CHAIN_BREAK = 12
local WALK_SECONDS = 4 -- to walk into place for a rally
-- The duos that are just a meeting: how far apart the two stand for it (root to root, studs).
local MEET: { [string]: number } = { highFive = 3.0, handshake = 2.6 }

type Ask = { from: any, emote: string, name: string, expires: number }
local asks: { [any]: Ask } = {}
local chained: { [any]: any } = {}

local function rootOf(who: any): BasePart?
	local character = who and who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function nameOf(who: any): string
	return tostring(who.DisplayName or who.Name)
end

-- Everyone who could be asked: the players, and in Studio the test bots.
local function candidates(): { any }
	local list: { any } = table.clone(Players:GetPlayers())
	if RunService:IsStudio() then
		local ok, Bots =
			pcall(require, script.Parent.Parent:FindFirstChild("Debug") and script.Parent.Parent.Debug.Bots)
		if ok and type(Bots) == "table" then
			for _, bot in ipairs(Bots.list) do
				table.insert(list, bot)
			end
		end
	end
	return list
end

-- Somewhere duos are played together: both in the lobby (Shared/EmotePolicy keeps duos out of cases).
local function together(a: any, b: any): boolean
	local inA = Match.active and Match.get(a) ~= nil
	local inB = Match.active and Match.get(b) ~= nil
	return not inA and not inB
end

local function busy(who: any): boolean
	return asks[who] ~= nil or chained[who] ~= nil
end

-- Ends a chain the player is in ("Let go", a death, too far apart, a case).
function DuoService.stop(player: any)
	local partner = chained[player]
	if not partner then
		return
	end
	chained[player] = nil
	chained[partner] = nil
	for _, who in ipairs({ player, partner }) do
		local character = who.Character
		local link = character and character:FindFirstChild("DuoChain")
		if link then
			link:Destroy()
		end
	end
end

-- The player played a duo emote: ask the nearest player within reach.
function DuoService.request(player: any, emote: { id: string, name: string, lobbyOnly: boolean? })
	if chained[player] then
		Match.notify(player, "Let go of the chain first.", "info")
		return
	end
	if busy(player) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local best, bestDistance = nil, REACH
	for _, other in ipairs(candidates()) do
		local otherRoot = rootOf(other)
		if other ~= player and otherRoot and not busy(other) and together(player, other) then
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	if not best then
		Match.notify(player, "Nobody near enough to ask (" .. REACH .. " studs).", "info")
		return
	end
	asks[best] = { from = player, emote = emote.id, name = emote.name, expires = os.clock() + ASK_SECONDS }
	DuoRemote:FireClient(best, { kind = "ask", from = nameOf(player), emote = emote.name, seconds = ASK_SECONDS })
	Match.notify(player, string.format("Asked %s to %s.", nameOf(best), emote.name), "info")
	task.delay(ASK_SECONDS + 0.5, function()
		local ask = asks[best]
		if ask and ask.from == player and os.clock() > ask.expires then
			asks[best] = nil
		end
	end)
end

-- Turns a body to face a point (on the level).
local function face(root: BasePart, at: Vector3)
	local flat = Vector3.new(at.X, root.Position.Y, at.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- The rally (Match Point), played for real (owner's call, 2026-10-17): the server keeps the ball. The first player
-- serves; each time the ball is on its way, the one it goes to must press as it reaches their racket (within EARLY
-- before to LATE after); a hit sends it back a little quicker (FLIGHT down to FLIGHT_MIN), and the first miss
-- (no press in time, or one too early) ends it for both. Every screen is told each hit and the miss, with the
-- server times the ball leaves and arrives, so all draw the same ball.
local SERVE_HIT = 0.6 -- seconds from the start to the serve's hit (art/scripts/emotes/duos.py)
local FLIGHT, FLIGHT_MIN, QUICKER = 1.0, 0.45, 0.93
local EARLY, LATE = 0.32, 0.16
local MAX_HITS = 80
local SLACK = 0.35 -- seconds a press's own clock may be behind the server's (its travel time)
type Rally = { a: any, b: any, to: any, arrive: number, flight: number, hits: number, done: boolean }
local rallies: { [any]: Rally } = {}

local function endRally(rally: Rally, missedBy: any?)
	if rally.done then
		return
	end
	rally.done = true
	if rallies[rally.a] == rally then
		rallies[rally.a] = nil
	end
	if rallies[rally.b] == rally then
		rallies[rally.b] = nil
	end
	DuoRemote:FireAllClients({
		kind = "rallyMiss",
		a = rally.a.Character,
		b = rally.b.Character,
		by = if missedBy == rally.a then "a" else "b",
		at = rally.arrive,
		hits = rally.hits,
	})
end

local function begin(a: any, b: any)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return
	end
	face(rb, ra.Position)
	face(ra, rb.Position)
	local at = workspace:GetServerTimeNow() + 0.25
	local rally: Rally =
		{ a = a, b = b, to = b, arrive = at + SERVE_HIT + FLIGHT, flight = FLIGHT, hits = 1, done = false }
	rallies[a], rallies[b] = rally, rally
	DuoRemote:FireAllClients({
		kind = "rally",
		a = a.Character,
		b = b.Character,
		at = at,
		serve = at + SERVE_HIT,
		arrive = rally.arrive,
	})
	-- the watch: no press by the time the ball has gone past is a miss
	task.spawn(function()
		while not rally.done do
			task.wait(0.03)
			local gone = not rootOf(a) or not rootOf(b)
			if gone or workspace:GetServerTimeNow() > rally.arrive + LATE then
				endRally(rally, rally.to)
			end
		end
	end)
end

-- A press from a player in a rally: a hit if the ball is theirs and within reach of the racket.
local function press(player: any, t: any)
	local rally = rallies[player]
	if not rally or rally.done or rally.to ~= player then
		return
	end
	local now = workspace:GetServerTimeNow()
	local at = if type(t) == "number" then math.clamp(t, now - SLACK, now) else now
	if at < rally.arrive - EARLY or at > rally.arrive + LATE then
		endRally(rally, player) -- swung at nothing
		return
	end
	local hitAt = rally.arrive
	rally.hits += 1
	rally.flight = math.max(FLIGHT_MIN, rally.flight * QUICKER)
	rally.to = if player == rally.a then rally.b else rally.a
	rally.arrive = hitAt + rally.flight
	DuoRemote:FireAllClients({
		kind = "rallyHit",
		a = rally.a.Character,
		b = rally.b.Character,
		by = if player == rally.a then "a" else "b",
		at = hitAt,
		arrive = rally.arrive,
		hits = rally.hits,
	})
	if rally.hits >= MAX_HITS then
		endRally(rally, rally.to)
	end
end
DuoService.press = press

local function startRally(a: any, b: any)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { a.Character, b.Character }
	local look = Vector3.new(ra.CFrame.LookVector.X, 0, ra.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot = ra.Position + look * RALLY
	local clear = workspace:Raycast(ra.Position, spot - ra.Position, params) == nil
	local floor = workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	if not clear or not floor or ra.Anchored or rb.Anchored then
		-- No room in front: play where they stand, if that is a rally's distance.
		local apart = (rb.Position - ra.Position).Magnitude
		if apart < 5 or apart > RALLY + 3 then
			Match.notify(a, "No room for a rally here.", "info")
			Match.notify(b, "No room for a rally here.", "info")
			return
		end
		begin(a, b)
		return
	end
	-- The one asked walks to the spot (their own client walks them; a test bot is walked here), then it starts.
	local target = floor.Position + Vector3.new(0, 3, 0)
	local humanoid = b.Character and b.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(target)
	end
	if typeof(b) == "Instance" and b:IsA("Player") then
		DuoRemote:FireClient(b, { kind = "walk", to = target, face = ra.Position, seconds = WALK_SECONDS })
	end
	task.spawn(function()
		local deadline = os.clock() + WALK_SECONDS
		while os.clock() < deadline do
			task.wait(0.1)
			local nowA, nowB = rootOf(a), rootOf(b)
			if not nowA or not nowB or (nowA.Position - ra.Position).Magnitude > 3 then
				return -- the asker moved off or a body went: called off quietly
			end
			local flat = Vector3.new(nowB.Position.X - target.X, 0, nowB.Position.Z - target.Z)
			if flat.Magnitude < 1.6 then
				begin(a, b)
				return
			end
		end
		Match.notify(a, "Couldn't get into place for the rally.", "info")
		Match.notify(b, "Couldn't get into place for the rally.", "info")
	end)
end

-- A meeting duo: the one asked walks up to face the one asking, `apart` studs off (or, with no room, both turn to
-- face each other where they stand if they are close enough), then both play it from the same moment.
local function startMeet(a: any, b: any, clip: string, apart: number)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return
	end
	local function go(spot: Vector3?)
		local nowA, nowB = rootOf(a), rootOf(b)
		if not nowA or not nowB then
			return
		end
		if spot then
			-- set right on the spot (a walk ends up to a stud or so short), so the hands meet
			nowB.CFrame = CFrame.new(Vector3.new(spot.X, nowB.Position.Y, spot.Z))
		end
		face(nowB, nowA.Position)
		face(nowA, nowB.Position)
		local EmoteService = require(script.Parent.EmoteService) :: any
		EmoteService.playTogether(a, b, clip)
	end
	local towards = Vector3.new(rb.Position.X - ra.Position.X, 0, rb.Position.Z - ra.Position.Z)
	local look = if towards.Magnitude > 0.01 then towards.Unit else Vector3.new(0, 0, -1)
	local target = ra.Position + look * apart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { a.Character, b.Character }
	local floor = workspace:Raycast(target + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	if not floor or ra.Anchored or rb.Anchored then
		if towards.Magnitude <= apart + 3 then
			go()
		end
		return
	end
	local spot = floor.Position + Vector3.new(0, 3, 0)
	local humanoid = b.Character and b.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(spot)
	end
	if typeof(b) == "Instance" and b:IsA("Player") then
		DuoRemote:FireClient(b, { kind = "walk", to = spot, face = ra.Position, seconds = WALK_SECONDS })
	end
	task.spawn(function()
		local begun = os.clock()
		while os.clock() < begun + WALK_SECONDS do
			task.wait(0.1)
			local nowA, nowB = rootOf(a), rootOf(b)
			if not nowA or not nowB or (nowA.Position - ra.Position).Magnitude > 3 then
				return -- the asker moved off or a body went: called off quietly
			end
			-- there, or stopped a little short of it
			local off = Vector3.new(nowB.Position.X - spot.X, 0, nowB.Position.Z - spot.Z).Magnitude
			local still = nowB.AssemblyLinearVelocity.Magnitude < 1 and os.clock() > begun + 0.4
			if off < 0.4 or (off < 2 and still) then
				go(spot)
				return
			end
		end
	end)
end

local function startChain(leader: any, follower: any)
	if Match.active and (Match.get(leader) or Match.get(follower)) then
		Match.notify(leader, "Cuffed Together is for the lobby only.", "info")
		return
	end
	DuoService.stop(leader)
	DuoService.stop(follower)
	chained[leader] = follower
	chained[follower] = leader
	for _, pair in ipairs({ { leader, follower, "lead" }, { follower, leader, "follow" } }) do
		local who, other, role = pair[1], pair[2], pair[3]
		local link = Instance.new("ObjectValue")
		link.Name = "DuoChain"
		link.Value = other.Character
		link:SetAttribute("Role", role)
		link.Parent = who.Character
	end
end

local function onRequest(player: any, payload)
	if type(payload) == "table" and payload.action == "hit" then
		if RateLimit.allow(player, "rallyHit", 0.1) then
			press(player, payload.t)
		end
		return
	end
	if type(payload) ~= "table" or not RateLimit.allow(player, "duo", 0.3) then
		return
	end
	if payload.action == "break" then
		DuoService.stop(player)
		return
	end
	local ask = asks[player]
	asks[player] = nil
	if not ask or os.clock() > ask.expires then
		return
	end
	local from = ask.from
	if payload.action ~= "accept" then
		Match.notify(from, nameOf(player) .. " said no.", "info")
		return
	end
	local ra, rb = rootOf(from), rootOf(player)
	if not ra or not rb or (ra.Position - rb.Position).Magnitude > REACH + 4 or not together(from, player) then
		Match.notify(player, "Too late: you are no longer together.", "info")
		return
	end
	if ask.emote == "cuffedLead" then
		startChain(from, player)
	elseif MEET[ask.emote] then
		startMeet(from, player, ask.emote, MEET[ask.emote])
	else
		startRally(from, player)
	end
end

-- Chains break when the two get too far apart, a body goes or dies, or a case takes one of them.
local function alive(who: any): boolean
	local humanoid = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function checkChains()
	for who, partner in pairs(chained) do
		local a, b = rootOf(who), rootOf(partner)
		local inCase = Match.active and (Match.get(who) ~= nil or Match.get(partner) ~= nil)
		local apart = a ~= nil and b ~= nil and (a.Position - b.Position).Magnitude > CHAIN_BREAK
		if not a or not b or inCase or apart or not alive(who) or not alive(partner) then
			DuoService.stop(who)
		end
	end
end

function DuoService.init()
	DuoRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		asks[player] = nil
		local rally = rallies[player]
		if rally then
			endRally(rally, player)
		end
		DuoService.stop(player)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			checkChains()
		end
	end)
end

-- For checks: who a player is chained to, and whether someone is being asked.
function DuoService.partner(player: any): any
	return chained[player]
end

-- Check hooks: the play-test probes (the emote harness) read these, nothing in the game does. Keep them.
-- The rally a player is in (who the ball goes to, when it gets there, the hits so far).
function DuoService.rallyOf(player: any): Rally?
	return rallies[player]
end

function DuoService.asked(player: any): boolean
	return asks[player] ~= nil
end

return DuoService
