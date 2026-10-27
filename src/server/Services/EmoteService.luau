-- Emotes are the server's (the user's call of 2026-10-27: server-sided): it checks the emote (owned from the
-- shop, or the Emote Pack pass) and where it may play (Shared/EmotePolicy: never in a cutscene, lobby-only ones
-- and duos never in a case, the waist up only at the meeting and the vote), then keeps it as each player's emote now
-- (`current`) and puts it on their body for every screen: the "Emote" attribute, what it is and the server time it
-- started (below). Every client draws it from that (Controllers/EmoteController: the pose, its props, its sound),
-- from the same moment, so a player who joins or streams the body in later sees it mid-way, and nobody but the
-- server can set it. A Deathsinger's is drawn only for other Deathsingers. A refused emote is answered with the
-- reason, for the wheel.
-- It also keeps:
--   the emote wheel (Shared/EmoteWheel): the four emotes a player put on it;
--   Join in, on the dances and group celebrations only (Shared/EmoteInfo `joinable`, the user's call of
--     2026-10-27): anyone near joins on the dance's beat, beside the dancer, never inside their body (a group
--     dance with a `formation` walks each joiner to a free place round the first dancer, up to six);
--   an emote's press-to-do moment (Shared/EmoteInfo `context`: one press, from its moment on, plays its branch);
--   strolls: not sent, an attribute on the body ("Stroll", the clip) that every client walks it in, until it is
--     picked again, another emote is played, or the player's own client asks to stop (Controllers/StrollWalker).
-- Everyone's emotes stop when a cutscene everyone sees begins, and when the case moves to the meeting or a
-- cutscene phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipIndex = require(Shared:WaitForChild("Anim"):WaitForChild("Clips"):WaitForChild("Index")) :: any
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local Cues = require(script.Parent.Cues)
local DataService = require(script.Parent.DataService)
local DuoService = require(script.Parent.DuoService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local ProfileService = require(script.Parent.ProfileService)
local RateLimit = require(script.Parent.RateLimit)

local EmoteRemote = Net.event("Emote")

local EmoteService = {}

local JOIN_REACH = 12 -- studs: how near a dancer you must be to join in
local FORMATION_WALK = 4 -- seconds to walk to a place in a group dance's formation
-- A dance joined closer than APART studs: the joiner walks to a place beside the dancer first, the nearest free one
-- of these ({ x, z } in the dancer's frame: x to their right, z behind them), so two bodies never dance in each other.
local APART = 2.6
local BESIDE = { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 5.5, 0 }, { -5.5, 0 } }

local cutsceneUntil = 0

export type Current = { clip: string, at: number, loop: boolean, length: number, pressed: boolean? }
local current: { [Player]: Current } = {}

-- Starts a stroll on the player's body (nil ends it). It walks by itself until something ends it (the owner's Q25,
-- 2026-10-21: no time limit): picked again, another emote, or the player's own input (Controllers/StrollWalker asks
-- to stop).
function EmoteService.setStroll(player: Player, clip: string?)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("Stroll", clip)
end

local function isDeathsinger(player: Player): boolean
	if not Match.active then
		return false
	end
	local ps = Match.get(player)
	return ps ~= nil and not ps.alive and ps.status ~= "left"
end

-- Where the player is, for the rules (Shared/EmotePolicy).
function EmoteService.situation(player: Player): EmotePolicy.Situation
	local inCase = Match.active and Match.get(player) ~= nil
	return {
		inCase = inCase,
		phase = if inCase then Match.phase else "Lobby",
		deathsinger = isDeathsinger(player),
		cutscene = inCase and workspace:GetServerTimeNow() < cutsceneUntil,
	}
end

-- May the player use this emote at all (everyone's, bought, earned, or from its pass)?
function EmoteService.canUse(player: Player, emote: QuickChat.Emote): boolean
	local item = if emote.item then Cosmetics.byId(emote.item) else nil
	if item then
		-- (owns counts the Emote Pack for the four it brings)
		return CosmeticsService.owns(player, item)
	elseif emote.pass then
		return PassService.owns(player, emote.pass)
	end
	return true
end

local function refuse(player: Player, emoteId: string, reason: string)
	Match.notify(player, reason, "info")
	EmoteRemote:FireClient(player, { refused = reason, emote = emoteId })
end

-- The emote on a body for every screen: "clip;at;mask;joined;owned;from" in one attribute, so a screen never reads
-- half of a change (Controllers/EmoteController reads it). nil: no emote (a one-shot that has run its course stays
-- until the next; every screen knows from its start and length that it is over).
local function publish(player: any, value: string?)
	local character = player.Character
	if character then
		character:SetAttribute("Emote", value)
	end
end

-- The player's emote now, if it is still playing.
function EmoteService.current(player: Player): Current?
	local now = current[player]
	if not now then
		return nil
	end
	if not now.loop and workspace:GetServerTimeNow() > now.at + now.length + 0.6 then
		current[player] = nil
		return nil
	end
	return now
end

-- Plays a clip on the player for everyone (checked already).
local function play(player: Player, clip: string, mask: string?, extra: { [string]: any }?)
	local entry = ClipIndex[clip]
	local at = workspace:GetServerTimeNow()
	current[player] = {
		clip = clip,
		at = at,
		loop = entry ~= nil and entry.loop == true,
		length = if entry then entry.length else 0,
	}
	local more = extra or {}
	publish(
		player,
		table.concat({
			clip,
			string.format("%.3f", at),
			mask or "",
			if type(more.joined) == "number" then tostring(more.joined) else "",
			if more.owned == false then "0" else "",
			if type(more.from) == "string" then more.from else "",
		}, ";")
	)
end

-- Two players play the same clip from the same moment (a duo met: DuoService).
function EmoteService.playTogether(a: Player, b: Player, clip: string)
	play(a, clip)
	play(b, clip)
end

-- Stops the player's emote on every screen (a cutscene, the meeting, a stop asked for).
function EmoteService.stop(player: Player, reason: string?)
	current[player] = nil
	if player.Character and player.Character:GetAttribute("Stroll") then
		EmoteService.setStroll(player, nil)
	end
	-- (a cutscene or the meeting ends a chain too; a stop asked for by the player does not: only "Let go" does)
	if reason ~= "stopped" then
		DuoService.stop(player)
	end
	publish(player, nil)
end

-- Stops the emotes of everyone in the case (the lobby dances on whatever a case is showing).
function EmoteService.stopCase(reason: string)
	-- everyone with an emote playing (test bots too) or out on a stroll
	local emoting: { [any]: boolean } = {}
	for player in pairs(current) do
		if EmoteService.current(player) then
			emoting[player] = true
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:GetAttribute("Stroll") then
			emoting[player] = true
		end
	end
	for player in pairs(emoting) do
		if Match.active and Match.get(player) ~= nil then
			EmoteService.stop(player, reason)
		end
	end
end

-- The case moved on: a cutscene phase or the meeting (everyone is stood at a seat) stops every emote.
function EmoteService.onPhase(name: string)
	if EmotePolicy.CUTSCENE_PHASES[name] or EmotePolicy.SEATED_PHASES[name] then
		EmoteService.stopCase("phase")
	end
end

local function startEmote(player: Player, emoteId: string)
	local emote = QuickChat.emote(emoteId)
	if not emote or not EmoteService.canUse(player, emote) then
		return
	end
	-- A Deathsinger waiting in the lobby is hidden; an emote would only show where they stand.
	if player.Character and player.Character:GetAttribute("Away") then
		return
	end
	local info = EmoteInfo.of(emote.id)
	local ok, reason, mask = EmotePolicy.check(info, EmoteService.situation(player))
	if not ok then
		refuse(player, emote.id, reason or "Not here")
		return
	end
	local item = info.item
	if info.duo then
		-- Played by two: ask the nearest player first (DuoService).
		DuoService.request(player, emote)
		return
	end
	-- (a chain is not let go by another emote: only by "Let go", the user's call of 2026-10-27, Services/DuoService)
	local walking = player.Character and player.Character:GetAttribute("Stroll")
	if info.stroll then
		-- Picked again: it ends; otherwise it starts (or takes over from another stroll).
		current[player] = nil
		publish(player, nil)
		EmoteService.setStroll(player, if walking == emote.id then nil else emote.id)
		return
	elseif walking then
		EmoteService.setStroll(player, nil)
	end
	-- Now and then an emote plays its other ending (Furious Scribbling's slash), the same on every screen.
	local clip = emote.id
	if item and type(item.alt) == "string" and info.context == nil then
		if math.random() < (tonumber(item.altChance) or 0.5) then
			clip = item.alt
		end
	end
	play(player, clip, mask)
end

-- A player by user id: in the server, or in Studio one of the test bots (Debug/Bots).
local function byUserId(userId: number): any
	local player = Players:GetPlayerByUserId(userId)
	if player or not RunService:IsStudio() then
		return player
	end
	local debug = script.Parent.Parent:FindFirstChild("Debug")
	local bots = debug and debug:FindFirstChild("Bots")
	local ok, Bots = pcall(require, bots :: ModuleScript)
	return if bots and ok and type(Bots) == "table" then Bots.byUserId(userId) else nil
end

-- Group dances (Shared/EmoteInfo `formation`): who holds which place round each dancer joined first. A place
-- is held while its joiner walks there and while they dance it.
type Place = { who: any, clip: string, walking: number } -- (walking: held while they walk there, till then)
local formations: { [any]: { [number]: Place } } = {}

local function freePlace(leader: any, count: number): number?
	local taken = formations[leader]
	if not taken then
		taken = {}
		formations[leader] = taken
	end
	for index = 1, count do
		local place = taken[index]
		local held = false
		if place then
			local theirs = EmoteService.current(place.who)
			held = os.clock() < place.walking or (theirs ~= nil and theirs.clip == place.clip)
		end
		if not held then
			taken[index] = nil
			return index
		end
	end
	return nil
end

-- Walks a joiner to a free place in the formation (their own client walks them; a test bot is walked here),
-- turned the way the first dancer faces, then starts the dance there. Not there in FORMATION_WALK: called off.
local function intoPlace(player: any, leader: any, leaderRoot: BasePart, clip: string, places: { { number } }, extra)
	local index = freePlace(leader, math.min(#places, 5))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not index then
		refuse(player, clip, "No place left in the formation")
		return
	end
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	-- (never out of a frozen or held body: a player held still by the game stays where they are, 2026-10-27)
	if root.Anchored or humanoid.WalkSpeed <= 0 then
		refuse(player, clip, "You cannot move right now")
		return
	end
	local place = places[index]
	local spot = leaderRoot.CFrame * CFrame.new(place[1] or 0, 0, place[2] or 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, leader.Character }
	local floor = workspace:Raycast(spot.Position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	if not floor then
		refuse(player, clip, "No room for the formation here")
		return
	end
	-- (and never through a wall: the walk to the place must be open, from you and from the first dancer)
	local chest = Vector3.new(0, 1.5, 0)
	local place3 = floor.Position + Vector3.new(0, 3, 0)
	local bodies = {}
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			table.insert(bodies, model)
		end
	end
	local walls = RaycastParams.new()
	walls.FilterType = Enum.RaycastFilterType.Exclude
	walls.FilterDescendantsInstances = bodies
	walls.RespectCanCollide = true
	for _, from in ipairs({ root.Position, leaderRoot.Position }) do
		local gap = (place3 + chest) - (from + chest)
		if gap.Magnitude > 0.5 and workspace:Raycast(from + chest, gap, walls) then
			refuse(player, clip, "A wall is in the way")
			return
		end
	end
	local to = floor.Position + Vector3.new(0, 3, 0)
	local look = leaderRoot.CFrame.LookVector
	local face = to + Vector3.new(look.X, 0, look.Z) * 10
	formations[leader][index] = { who = player, clip = clip, walking = os.clock() + FORMATION_WALK + 0.5 }
	-- (there: within 0.4 studs, or stopped within 2; when time is up, near enough within 3, as a body brushing
	-- past the first dancer on its way can stop a little short; then set right on the place)
	local function within(studs: number): boolean
		local flat = Vector3.new(root.Position.X - to.X, 0, root.Position.Z - to.Z)
		return flat.Magnitude < studs
	end
	if not within(0.4) then
		humanoid:MoveTo(to)
		if typeof(player) == "Instance" and player:IsA("Player") then
			EmoteRemote:FireClient(player, { walk = { to = to, face = face, seconds = FORMATION_WALK } })
		end
		local begun = os.clock()
		local function settled(): boolean -- there, or stopped a little short of it
			local still = root.AssemblyLinearVelocity.Magnitude < 1 and os.clock() > begun + 0.4
			return within(0.4) or (within(2) and still)
		end
		while os.clock() < begun + FORMATION_WALK and not settled() do
			task.wait(0.1)
			if not root.Parent then
				return
			end
		end
		if not within(3) then
			formations[leader][index] = nil
			refuse(player, clip, "Couldn't get into place")
			return
		end
	end
	-- right on the place (a walk ends up to a stud or so short), so the rows line up
	local on = Vector3.new(to.X, root.Position.Y, to.Z)
	root.CFrame = CFrame.lookAt(on, Vector3.new(face.X, on.Y, face.Z))
	extra.place = index
	play(player, clip, nil, extra)
end

-- Join in: the player joins a dancer near them, on the same beat (a looping dance or group celebration only:
-- EmoteInfo `joinable`). In the lobby anyone may join; in a case only someone who owns the dance.
local function joinIn(player: Player, userId)
	local target = if type(userId) == "number" then byUserId(userId) else nil
	local theirs = if target and target ~= player then EmoteService.current(target) else nil
	if not theirs or not theirs.loop or not EmoteInfo.of(theirs.clip).joinable then
		return
	end
	-- The living and the Deathsingers never see each other dance (and are not told whether the other does).
	if isDeathsinger(player) ~= isDeathsinger(target :: Player) then
		return
	end
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local b = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not a or not b or not a:IsA("BasePart") or not b:IsA("BasePart") then
		return
	end
	if (a.Position - b.Position).Magnitude > JOIN_REACH then
		refuse(player, theirs.clip, "Too far to join in")
		return
	end
	local emote = QuickChat.emote(theirs.clip)
	if not emote then
		return
	end
	local situation = EmoteService.situation(player)
	if situation.inCase and not EmoteService.canUse(player, emote) then
		refuse(player, emote.id, "Join in with your own dances in a case")
		return
	end
	local ok, reason, mask = EmotePolicy.check(EmoteInfo.of(emote.id), situation)
	if not ok then
		refuse(player, emote.id, reason or "Not here")
		return
	end
	if player.Character and player.Character:GetAttribute("Stroll") then
		EmoteService.setStroll(player, nil)
	end
	local extra = { joined = target and target.UserId, owned = EmoteService.canUse(player, emote) }
	local places = EmoteInfo.of(emote.id).formation
	if places and #places > 0 and mask == nil then
		-- A group dance: to a free place round the one joined first (walked there), then the dance.
		task.spawn(intoPlace, player, target, b, theirs.clip, places, extra)
		return
	end
	if mask == nil and (a.Position - b.Position).Magnitude < APART then
		-- Too close to dance without passing through them: beside them first.
		task.spawn(intoPlace, player, target, b, theirs.clip, BESIDE, extra)
		return
	end
	-- (a loop plays on the shared beat on every screen, so the same clip is already in step with theirs)
	play(player, theirs.clip, mask, extra)
end

-- The emote's press-to-do moment: once, any time from its moment until the emote ends, it plays its branch from
-- where the emote is.
local function press(player: Player)
	local now = EmoteService.current(player)
	if not now or now.pressed then
		return
	end
	local info = EmoteInfo.of(now.clip)
	local context = info.context
	if not context then
		return
	end
	-- (a loop plays on the shared beat, the server's clock, wherever it began: as every client plays it)
	local into = workspace:GetServerTimeNow() - now.at
	if now.loop and now.length > 0 then
		into = workspace:GetServerTimeNow() % now.length
	end
	-- (from its moment on, until the emote ends: no closing window, the owner's call of 2026-10-24; a loop's
	-- moment comes round every bar)
	if not now.loop and into < context.from - 0.15 then
		return
	end
	now.pressed = true
	-- (pushing your luck: now and then the other branch, the same on every screen)
	local branch = context.branch
	if context.alt and math.random() < (context.altChance or 0.5) then
		branch = context.alt
	end
	local ok, _, mask = EmotePolicy.check(EmoteInfo.of(branch), EmoteService.situation(player))
	if ok then
		play(player, branch, mask, { from = now.clip })
		-- (a branch with its own press-to-do moment, NEXT POSE's next pose, can be pressed again; any other
		-- branch is the press's end)
		local fresh = current[player]
		if fresh and not EmoteInfo.of(branch).context then
			fresh.pressed = true
		end
	end
end

local function onEmote(player: Player, payload)
	if type(payload) == "table" then
		if payload.ended == true then
			-- The player walked out of their emote (every screen saw it): it is not theirs any more.
			if RateLimit.allow(player, "emoteEnded", 0.2) then
				current[player] = nil
				publish(player, nil)
			end
			return
		end
		if not RateLimit.allow(player, "emoteAct", 0.35) then
			return
		end
		if payload.join ~= nil then
			joinIn(player, payload.join)
		elseif payload.press == true then
			press(player)
		elseif payload.stop == true then
			local strolling = player.Character ~= nil and player.Character:GetAttribute("Stroll") ~= nil
			if current[player] or strolling then
				EmoteService.stop(player, "stopped")
			end
		end
		return
	end
	if type(payload) ~= "string" or not RateLimit.allow(player, "emote", 0.8) then
		return
	end
	startEmote(player, payload)
end

-- Puts an emote just bought on the wheel's first empty slot (nothing when the wheel is full). The caller
-- pushes and saves the profile.
function EmoteService.placeBought(data, clip: string): number?
	local slots, slot = EmoteWheel.place(data.emoteWheel, clip)
	data.emoteWheel = slots
	return slot
end

-- ProfileRequest "emoteWheel": { slot = 1..4, emote = clip id or "" to empty the slot }.
local function setWheel(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.slot) ~= "number" or type(payload.emote) ~= "string" then
		return
	end
	if payload.emote ~= "" then
		local emote = QuickChat.emote(payload.emote)
		if not emote or not EmoteService.canUse(player, emote) then
			return
		end
	end
	data.emoteWheel = EmoteWheel.set(data.emoteWheel, payload.slot, payload.emote)
	DataService.push(player)
	DataService.saveSoon(player)
end

function EmoteService.init()
	EmoteRemote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
		formations[player] = nil
	end)
	Cues.Started:Connect(function(kind: string, startsAt: number, hold: number?)
		if EmotePolicy.CUTSCENE_CUES[kind] then
			cutsceneUntil = math.max(cutsceneUntil, startsAt + (hold or 4))
			EmoteService.stopCase("cutscene")
		end
	end)
	ProfileService.register("emoteWheel", 0.15, setWheel)
end

return EmoteService
