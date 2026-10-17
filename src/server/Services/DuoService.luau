-- Duo emotes (Shared/Cosmetics `duo`), in the lobby only: played near someone, they ask first. The nearest player
-- within REACH is asked "Join?" (UI/DuoPanel); if they say yes in time, both play it together, the same on every
-- screen (Controllers/DuoController):
--   Match Point  a rally: the one asked walks to a spot facing the one asking, RALLY studs off (with no room
--                there, both just turn to face each other if they are near enough); once there, every client
--                plays it from the same moment. Not there in WALK_SECONDS: it is called off.
--   Cuffed Together  lobby only: the two are chained wrist to wrist (a "DuoChain" ObjectValue in each body
--                naming the other, the asker leading); the one asked walks after the leader, and a jump,
--                another emote, going CHAIN_BREAK studs apart or a case ends it
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

-- Ends a chain the player is in (another emote, a jump, too far apart, a case).
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
	if busy(player) then
		DuoService.stop(player)
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

local function begin(a: any, b: any)
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return
	end
	face(rb, ra.Position)
	face(ra, rb.Position)
	DuoRemote:FireAllClients({
		kind = "rally",
		a = a.Character,
		b = b.Character,
		at = workspace:GetServerTimeNow() + 0.25,
	})
end

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
	else
		startRally(from, player)
	end
end

-- Chains break when the two get too far apart, a body goes, or a case takes one of them.
local function checkChains()
	for who, partner in pairs(chained) do
		local a, b = rootOf(who), rootOf(partner)
		local inCase = Match.active and (Match.get(who) ~= nil or Match.get(partner) ~= nil)
		if not a or not b or inCase or (a.Position - b.Position).Magnitude > CHAIN_BREAK then
			DuoService.stop(who)
		end
	end
end

function DuoService.init()
	DuoRemote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		asks[player] = nil
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

function DuoService.asked(player: any): boolean
	return asks[player] ~= nil
end

return DuoService
