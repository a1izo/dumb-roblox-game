-- Inkbound server bootstrap: starts every service in dependency order, then the match loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local Services = script:WaitForChild("Services")
local CaseFileService = require(Services:WaitForChild("CaseFileService"))
local CharacterService = require(Services:WaitForChild("CharacterService"))
local AliasService = require(Services:WaitForChild("AliasService"))
local ChatService = require(Services:WaitForChild("ChatService"))
local CollisionGroups = require(Services:WaitForChild("CollisionGroups"))
local CosmeticsService = require(Services:WaitForChild("CosmeticsService"))
local DataService = require(Services:WaitForChild("DataService"))
local DebugService = require(Services:WaitForChild("DebugService"))
local DeathNoteService = require(Services:WaitForChild("DeathNoteService"))
local DirectorService = require(Services:WaitForChild("DirectorService"))
local EvidenceService = require(Services:WaitForChild("EvidenceService"))
local EyesService = require(Services:WaitForChild("EyesService"))
local GhostService = require(Services:WaitForChild("GhostService"))
local HoodService = require(Services:WaitForChild("HoodService"))
local MapService = require(Services:WaitForChild("MapService"))
local Match = require(Services:WaitForChild("Match"))
local MatchmakingService = require(Services:WaitForChild("MatchmakingService"))
local MeetingService = require(Services:WaitForChild("MeetingService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local NoteService = require(Services:WaitForChild("NoteService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local PassService = require(Services:WaitForChild("PassService"))
local ProfileService = require(Services:WaitForChild("ProfileService"))
local RoundService = require(Services:WaitForChild("RoundService"))
local ShopService = require(Services:WaitForChild("ShopService"))
local SuspicionService = require(Services:WaitForChild("SuspicionService"))
local TipBoxService = require(Services:WaitForChild("TipBoxService"))
local VoteService = require(Services:WaitForChild("VoteService"))
local WarrantService = require(Services:WaitForChild("WarrantService"))

CollisionGroups.init()
MapService.init()
CharacterService.init()
PassService.init()
DataService.init()
ProfileService.init()
AliasService.init()
MonetizationService.init()
DirectorService.init()
CosmeticsService.init()
ShopService.init()
PartyService.init()
EvidenceService.init()
SuspicionService.init()
CaseFileService.init()
NoteService.init()
HoodService.init()
EyesService.init()
DeathNoteService.init()
VoteService.init()
WarrantService.init()
TipBoxService.init()
MeetingService.init()
ChatService.init()
MatchmakingService.init()
GhostService.init()
RoundService.init()
DebugService.init()

-- Everything a client needs when it starts (or restarts its UI).
Net.func("GetSnapshot").OnServerInvoke = function(player: Player)
	return {
		state = Match.publicState(),
		private = Match.privateState(Match.get(player)),
		profile = DataService.payload(player),
		lobby = MatchmakingService.lobbyPayload(player),
		party = PartyService.payload(player),
	}
end

RoundService.start()

if RunService:IsStudio() and Config.RUN_TESTS_IN_STUDIO then
	task.spawn(function()
		local TestRunner = require(script:WaitForChild("Tests"):WaitForChild("TestRunner"))
		TestRunner.run(script:WaitForChild("Tests"))
	end)
end

print(string.format("[Inkbound] Server ready. %d player(s) online.", #Players:GetPlayers()))
