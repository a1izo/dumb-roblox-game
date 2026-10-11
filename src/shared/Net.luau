-- Every RemoteEvent and RemoteFunction used by the game. The server creates them
-- once at startup; clients wait for the folder. Always get remotes through
-- Net.event / Net.func so a typo fails loudly instead of silently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER_NAME = "LGameRemotes"

local EVENTS = {
	-- state sync (server -> client)
	"State",
	"Private",
	"Profile",
	"LobbyState",
	"PartyState",
	"Briefing",
	"Notify",
	"Announce",
	"Elimination",
	-- case files
	"Evidence",
	"LetterFlash",
	"TaskRequest",
	"TaskState",
	"Tamper",
	-- communication
	"QuickChat",
	"QuickChatMsg",
	"LScreen",
	"LScreenMsg",
	"Tip",
	"LInbox",
	-- Grimoire phase (id "DeathNote"), meeting and vote
	"DeathNote",
	"Report",
	"Vote",
	"VoteUpdate",
	"VoteResult",
	"Warrant",
	"Suspicion",
	-- notes, eyes and hoods
	"NoteRequest",
	"NoteView",
	-- a note offered hand to hand (server -> giver and receiver)
	"NoteOffer",
	"EyesRequest",
	"EyesName",
	"HoodRequest",
	-- lobby, parties and shop
	"Ready",
	"PartyRequest",
	"ShopRequest",
	-- end of match and spectating
	"Reveal",
	"Spectate",
	"Watch",
	-- presentation cues, Specters, profile settings, private servers and leaderboards
	"Cue",
	"Emote",
	"Leaderboard",
	-- the lobby mini-games: requests (client -> server) and what the server tells the player about their run
	"LobbyGame",
	"LobbyGameState",
	"Ghost",
	-- a Deathsinger haunting the lobby (server -> every client), and Death's wager (both ways)
	"Haunt",
	"Wager",
	"ProfileRequest",
	"PrivateServer",
	-- a map's own mechanic: requests (the breaker) and the snow tracks
	"MapAction",
	"Tracks",
	-- Studio debug panel (ignored by live servers)
	"Debug",
}

-- Unreliable events (server -> every client): frequent snapshots where a lost one is replaced by
-- the next (the Tokyo crowd and cars). Got with Net.unreliable, never Net.event.
local UNRELIABLE = {
	"MapSync",
}

local FUNCTIONS = {
	"GetEvidence",
	"GetSnapshot",
}

local folder: Instance

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for _, name in ipairs(EVENTS) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
	end
	for _, name in ipairs(UNRELIABLE) do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = newFolder
	end
	for _, name in ipairs(FUNCTIONS) do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- Test bots (server, debug only) -----------------------------------------------------------
-- When the debug tools are available, the server hands out thin wrappers around its
-- RemoteEvents: a message fired at a test bot (a table standing in for a Player) goes to
-- Net.botSink instead of the network, and Net.simulate lets a bot "send" a request through
-- the very same handlers a real client's request goes through. Live servers without debug
-- access get the plain RemoteEvents.

local wrapped: { [string]: any } = {}
local handlers: { [string]: { (...any) -> () } } = {}

-- Set by the bot service: (bot, remoteName, ...payload) for messages sent to a bot.
Net.botSink = nil :: ((any, string, ...any) -> ())?

local function debugPossible(): boolean
	local ok, Config = pcall(require, script.Parent:FindFirstChild("Config") :: ModuleScript)
	if not ok then
		return false
	end
	return (RunService:IsStudio() and Config.STUDIO_DEBUG == true) or #(Config.DEBUG_USER_IDS or {}) > 0
end

local WRAP = RunService:IsServer() and debugPossible()

local function wrap(remote: RemoteEvent): any
	local name = remote.Name
	local list = {}
	handlers[name] = list
	local signal = {}
	function signal.Connect(_, fn)
		table.insert(list, fn)
		return remote.OnServerEvent:Connect(fn)
	end
	function signal.Once(_, fn)
		return remote.OnServerEvent:Once(fn)
	end
	function signal.Wait(_)
		return remote.OnServerEvent:Wait()
	end
	local proxy = {
		Name = name,
		Instance = remote,
		OnServerEvent = signal,
		OnClientEvent = remote.OnClientEvent,
	}
	function proxy.FireClient(_, player, ...)
		if type(player) == "table" then
			local sink = Net.botSink
			if sink then
				sink(player, name, ...)
			end
			return
		end
		remote:FireClient(player, ...)
	end
	function proxy.FireAllClients(_, ...)
		remote:FireAllClients(...)
	end
	return setmetatable(proxy, {
		__index = function(_, key)
			local value = (remote :: any)[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(remote, ...)
				end
			end
			return value
		end,
	})
end

-- Runs a remote's server handlers as if `player` (usually a test bot) had fired it.
function Net.simulate(name: string, player: any, ...: any)
	for _, fn in ipairs(handlers[name] or {}) do
		task.spawn(fn, player, ...)
	end
end

function Net.event(name: string): RemoteEvent
	local cached = wrapped[name]
	if cached then
		return cached
	end
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Unknown RemoteEvent: " .. name)
	if WRAP then
		local proxy = wrap(remote :: RemoteEvent)
		wrapped[name] = proxy
		return proxy
	end
	return remote
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("UnreliableRemoteEvent"), "Unknown UnreliableRemoteEvent: " .. name)
	return remote :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "Unknown RemoteFunction: " .. name)
	return remote
end

return Net
