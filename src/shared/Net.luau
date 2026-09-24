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
	"DropPointView",
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
	-- presentation cues, Specters, profile settings, private servers and leaderboards
	"Cue",
	"Emote",
	"Leaderboard",
	"Ghost",
	"ProfileRequest",
	"PrivateServer",
	-- Studio debug panel (ignored by live servers)
	"Debug",
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

function Net.event(name: string): RemoteEvent
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Unknown RemoteEvent: " .. name)
	return remote
end

function Net.func(name: string): RemoteFunction
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteFunction"), "Unknown RemoteFunction: " .. name)
	return remote
end

return Net
