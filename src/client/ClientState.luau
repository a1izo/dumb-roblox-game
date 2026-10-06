-- Everything this client knows: the public match state, its own private role state,
-- its profile, the lobby queue and its party. UI modules listen to the signals here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local LocalPlayer = Players.LocalPlayer

local ClientState = {}

-- Replaced wholesale by server payloads (see Match.publicState / Match.privateState).
ClientState.public = {
	active = false,
	phase = "Lobby",
	round = 0,
	maxRounds = 5,
	startedAt = 0,
	endsAt = 0,
	mapName = "",
	players = {},
} :: { [string]: any }
ClientState.private = { inMatch = false } :: { [string]: any }
ClientState.profile = nil
ClientState.lobby = nil
ClientState.party = nil

ClientState.PublicChanged = Signal.new()
ClientState.PrivateChanged = Signal.new()
ClientState.PhaseChanged = Signal.new()
ClientState.ProfileChanged = Signal.new()
ClientState.LobbyChanged = Signal.new()
-- Fired with true/false when this player starts or stops spectating from the lobby.
ClientState.WatchChanged = Signal.new()

-- True while this player watches the running match as a spectator.
ClientState.watching = false
ClientState.PartyChanged = Signal.new()

local received = { state = false, private = false, profile = false, lobby = false, party = false }

local function setPublic(state)
	if type(state) ~= "table" then
		return
	end
	received.state = true
	local oldPhase = ClientState.public.phase
	local oldActive = ClientState.public.active
	ClientState.public = state
	ClientState.PublicChanged:Fire(state)
	if state.phase ~= oldPhase or state.active ~= oldActive then
		ClientState.PhaseChanged:Fire(state.phase, oldPhase)
	end
end

local function setPrivate(state)
	if type(state) ~= "table" then
		return
	end
	received.private = true
	ClientState.private = state
	ClientState.PrivateChanged:Fire(state)
end

local function setProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	received.profile = true
	ClientState.profile = profile
	ClientState.ProfileChanged:Fire(profile)
end

local function setWatching(on: boolean)
	if on ~= ClientState.watching then
		ClientState.watching = on
		ClientState.WatchChanged:Fire(on)
	end
end

local function setLobby(lobby)
	if type(lobby) ~= "table" then
		return
	end
	received.lobby = true
	ClientState.lobby = lobby
	if type(lobby.watching) == "boolean" then
		setWatching(lobby.watching)
	end
	ClientState.LobbyChanged:Fire(lobby)
end

local function setParty(party)
	if type(party) ~= "table" then
		return
	end
	received.party = true
	ClientState.party = party
	ClientState.PartyChanged:Fire(party)
end

-- Queries --------------------------------------------------------------------------

function ClientState.me()
	for _, entry in ipairs(ClientState.public.players) do
		if entry.userId == LocalPlayer.UserId then
			return entry
		end
	end
	return nil
end

-- A Specter waiting in the lobby: still in the case (its rewards and results), but on the lobby's side of
-- everything (menus, mini-games), hidden from everyone there.
function ClientState.isAway(): boolean
	return ClientState.public.active == true and ClientState.private.away == true and ClientState.me() ~= nil
end

-- In the case right now (an away Specter is in the lobby, so not).
function ClientState.isParticipant(): boolean
	return ClientState.public.active and ClientState.me() ~= nil and not ClientState.isAway()
end

function ClientState.isLiving(): boolean
	local me = ClientState.me()
	return ClientState.public.active and me ~= nil and me.alive == true
end

-- Out of the match but still in it as a Specter (until the results).
function ClientState.isSpecter(): boolean
	local me = ClientState.me()
	return ClientState.public.active
		and me ~= nil
		and not me.alive
		and me.status ~= "left"
		and not ClientState.isAway()
		and ClientState.public.phase ~= "Reveal"
end

-- Watching the running match from the lobby as a spectator.
function ClientState.isWatching(): boolean
	return ClientState.watching and ClientState.public.active == true
end

function ClientState.phase(): string
	if not ClientState.public.active then
		return "Lobby"
	end
	return ClientState.public.phase
end

function ClientState.role(): string?
	if ClientState.private.inMatch then
		return ClientState.private.role
	end
	return nil
end

function ClientState.isKiraSide(): boolean
	local role = ClientState.role()
	return role == "Kira" or role == "Follower"
end

function ClientState.timeLeft(): number
	return math.max(0, (ClientState.public.endsAt or 0) - workspace:GetServerTimeNow())
end

function ClientState.living()
	local result = {}
	for _, entry in ipairs(ClientState.public.players) do
		if entry.alive then
			table.insert(result, entry)
		end
	end
	return result
end

function ClientState.aliasOf(userId: number): string?
	for _, entry in ipairs(ClientState.public.players) do
		if entry.userId == userId then
			return entry.alias
		end
	end
	return nil
end

function ClientState.init()
	Net.event("State").OnClientEvent:Connect(setPublic)
	Net.event("Private").OnClientEvent:Connect(setPrivate)
	Net.event("Profile").OnClientEvent:Connect(setProfile)
	Net.event("LobbyState").OnClientEvent:Connect(setLobby)
	Net.event("PartyState").OnClientEvent:Connect(setParty)
	Net.event("Watch").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			setWatching(payload.watching == true)
		end
	end)
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return Net.func("GetSnapshot"):InvokeServer()
		end)
		if not ok or type(snapshot) ~= "table" then
			warn("[DeathsGambit] Could not load the initial state: " .. tostring(snapshot))
			return
		end
		-- Events that already arrived are newer than the snapshot.
		if not received.state then
			setPublic(snapshot.state)
		end
		if not received.private then
			setPrivate(snapshot.private)
		end
		if not received.profile and snapshot.profile then
			setProfile(snapshot.profile)
		end
		if not received.lobby then
			setLobby(snapshot.lobby)
		end
		if not received.party then
			setParty(snapshot.party)
		end
	end)
end

return ClientState
