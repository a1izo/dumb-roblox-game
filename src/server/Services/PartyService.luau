-- Parties. Friends who join together (a Roblox platform party or a teleport from
-- matchmaking) are grouped automatically; players can also invite each other in the
-- lobby. Party members are always placed on the same side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local PartyStateRemote = Net.event("PartyState")
local PartyRequest = Net.event("PartyRequest")

local PartyService = {}

-- Fired with a list of players whose party changed.
PartyService.Changed = Signal.new()

local parties = {} -- id -> { id, leader, members }
local memberOf = {} -- Player -> party id
local invites = {} -- invitee Player -> { [inviter Player] = expiry }
local externalKeys = {} -- platform/teleport party key -> party id
local nextId = 0

local function newParty(leader: Player)
	nextId += 1
	local party = { id = "party" .. nextId, leader = leader, members = { leader } }
	parties[party.id] = party
	memberOf[leader] = party.id
	return party
end

function PartyService.partyOf(player: Player)
	local id = memberOf[player]
	return if id then parties[id] else nil
end

-- The player's party members (including the player), or just the player.
function PartyService.membersOf(player: Player): { Player }
	local party = PartyService.partyOf(player)
	if not party then
		return { player }
	end
	return table.clone(party.members)
end

-- Groups the given players by party, as lists of user ids, for role assignment.
function PartyService.groupsFor(players: { Player }): { { number } }
	local groups = {}
	local byParty = {}
	for _, player in ipairs(players) do
		local id = memberOf[player]
		if id then
			local group = byParty[id]
			if not group then
				group = {}
				byParty[id] = group
				table.insert(groups, group)
			end
			table.insert(group, player.UserId)
		else
			table.insert(groups, { player.UserId })
		end
	end
	return groups
end

function PartyService.payload(player: Player)
	local party = PartyService.partyOf(player)
	local members = {}
	if party then
		for _, member in ipairs(party.members) do
			table.insert(members, { userId = member.UserId, name = member.DisplayName })
		end
	end
	local pending = {}
	local now = os.clock()
	for inviter, expiry in pairs(invites[player] or {}) do
		if expiry > now and inviter.Parent == Players then
			table.insert(pending, { userId = inviter.UserId, name = inviter.DisplayName })
		end
	end
	return {
		partyId = if party then party.id else nil,
		leaderUserId = if party then party.leader.UserId else nil,
		members = members,
		invites = pending,
		maxSize = Config.MAX_PARTY_SIZE,
	}
end

local function push(player: Player)
	if player.Parent == Players then
		PartyStateRemote:FireClient(player, PartyService.payload(player))
	end
end

local function pushParty(party)
	for _, member in ipairs(party.members) do
		push(member)
	end
end

local function leave(player: Player)
	local party = PartyService.partyOf(player)
	if not party then
		return
	end
	memberOf[player] = nil
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	local affected = table.clone(party.members)
	table.insert(affected, player)
	if #party.members <= 1 then
		for _, member in ipairs(party.members) do
			memberOf[member] = nil
		end
		parties[party.id] = nil
	else
		if party.leader == player then
			party.leader = party.members[1]
		end
		pushParty(party)
	end
	for _, member in ipairs(affected) do
		push(member)
	end
	PartyService.Changed:Fire(affected)
end

local function join(player: Player, party): boolean
	if #party.members >= Config.MAX_PARTY_SIZE then
		return false
	end
	if memberOf[player] == party.id then
		return true
	end
	leave(player)
	table.insert(party.members, player)
	memberOf[player] = party.id
	pushParty(party)
	PartyService.Changed:Fire(table.clone(party.members))
	return true
end

-- Party changes are locked while a player is alive in the running match.
local function canChange(player: Player): boolean
	return Match.getLiving(player) == nil
end

-- Joins players that arrived together under a shared key (platform party or teleport).
local function joinExternal(player: Player, key: string)
	local id = externalKeys[key]
	local party = if id then parties[id] else nil
	if party then
		join(player, party)
	else
		party = PartyService.partyOf(player) or newParty(player)
		externalKeys[key] = party.id
		pushParty(party)
	end
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		return
	end
	if not RateLimit.allow(player, "party", 0.4) then
		return
	end
	if not canChange(player) then
		Match.notify(player, "Parties are locked while you are playing.", "bad")
		return
	end
	local action = payload.action
	if action == "invite" then
		local target = if type(payload.userId) == "number" then Players:GetPlayerByUserId(payload.userId) else nil
		if not target or target == player then
			return
		end
		local party = PartyService.partyOf(player)
		if party and table.find(party.members, target) then
			return
		end
		if party and #party.members >= Config.MAX_PARTY_SIZE then
			Match.notify(player, "Your party is full.", "bad")
			return
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock() + Config.PARTY_INVITE_TIMEOUT
		push(target)
		Match.notify(target, player.DisplayName .. " invited you to a party.", "info")
		Match.notify(player, "Invite sent to " .. target.DisplayName .. ".", "info")
	elseif action == "accept" then
		local inviter = if type(payload.userId) == "number" then Players:GetPlayerByUserId(payload.userId) else nil
		local pending = invites[player]
		if not inviter or not pending or not pending[inviter] or pending[inviter] < os.clock() then
			Match.notify(player, "That invite has expired.", "bad")
			return
		end
		pending[inviter] = nil
		if not canChange(inviter) then
			Match.notify(player, "That player is in a match right now.", "bad")
			return
		end
		local party = PartyService.partyOf(inviter) or newParty(inviter)
		if not join(player, party) then
			Match.notify(player, "That party is full.", "bad")
		end
		push(player)
	elseif action == "decline" then
		local inviter = if type(payload.userId) == "number" then Players:GetPlayerByUserId(payload.userId) else nil
		if inviter and invites[player] then
			invites[player][inviter] = nil
		end
		push(player)
	elseif action == "leave" then
		leave(player)
		push(player)
	end
end

local function onPlayerAdded(player: Player)
	-- Roblox platform parties
	local ok, partyId = pcall(function()
		return player.PartyId
	end)
	if ok and type(partyId) == "string" and partyId ~= "" then
		joinExternal(player, "platform:" .. partyId)
	end
	-- Parties that came through cross-server matchmaking
	local okData, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if okData and type(joinData) == "table" and type(joinData.TeleportData) == "table" then
		local key = joinData.TeleportData.lgameParty
		if type(key) == "string" and key ~= "" then
			joinExternal(player, "teleport:" .. key)
		end
	end
	push(player)
end

function PartyService.init()
	PartyRequest.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
		for _, pending in pairs(invites) do
			pending[player] = nil
		end
	end)
end

return PartyService
