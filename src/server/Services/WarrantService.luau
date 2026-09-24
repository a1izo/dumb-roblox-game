-- L's warrant: one arrest per match, during the vote. L picks a suspect and types that
-- player's full real name. A wrong name rejects the warrant (only L is told) and L must
-- wait for the next round to try again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local Elimination = require(script.Parent.Elimination)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)

local WarrantRemote = Net.event("Warrant")

local WarrantService = {}

local isOpen = false

local function onWarrant(player: Player, payload)
	if type(payload) ~= "table" or type(payload.name) ~= "string" or type(payload.suspect) ~= "number" then
		return
	end
	local l = Match.getLiving(player)
	if not l or l.role ~= "L" then
		return
	end
	if not isOpen or Match.phase ~= "Vote" then
		Match.notify(player, "Warrants can only be issued during the vote.", "bad")
		return
	end
	if l.warrantUsed then
		Match.notify(player, "You have already used your warrant.", "bad")
		return
	end
	if l.warrantBlockedRound == Match.round then
		Match.notify(player, "Your last warrant was rejected. Try again next round.", "bad")
		return
	end
	local suspect = Match.getByUserId(payload.suspect)
	if not suspect or not suspect.alive or suspect == l then
		return
	end
	local typed = Util.cleanText(payload.name, Config.NAME_MAX_LENGTH)

	if not NameUtil.matches(typed, suspect.first, suspect.last) then
		l.warrantBlockedRound = Match.round
		EventLog.add(string.format("L (%s) tried to arrest %s, but the name was wrong. Warrant rejected.", l.alias, suspect.alias), "warrant")
		Match.notify(player, "Warrant rejected: that is not the suspect's real name. You can try again next round.", "bad")
		Match.pushPrivate(l)
		return
	end

	l.warrantUsed = true
	Match.pushPrivate(l)
	if suspect.role == "Kira" then
		l.stats.arrestedKira = true
		EventLog.add(string.format("L (%s) arrested %s with a valid warrant. %s was Kira.", l.alias, suspect.alias, suspect.alias), "warrant")
		Match.announce("Warrant served: " .. suspect.alias .. " arrested", suspect.alias .. " was KIRA!", "team")
		Elimination.eliminate(suspect, "arrested", nil, suspect.alias .. " was arrested by L.", {})
	elseif suspect.role == "Follower" then
		EventLog.add(string.format("L (%s) arrested %s, a Kira follower.", l.alias, suspect.alias), "warrant")
		Match.announce("Warrant served: " .. suspect.alias .. " arrested", suspect.alias .. " was a Kira follower. Kira is still free.", "team")
		Elimination.eliminate(suspect, "arrested", nil, suspect.alias .. " was arrested by L.", {})
	else
		EventLog.add(string.format("L (%s) arrested %s, who was innocent.", l.alias, suspect.alias), "warrant")
		Match.declareWinner("Kira", "L arrested an innocent player.")
		Match.announce("Warrant served: " .. suspect.alias .. " arrested", suspect.alias .. " was innocent...", "kira")
		Elimination.eliminate(suspect, "arrested", nil, suspect.alias .. " was arrested by L.", {})
	end
end

function WarrantService.open()
	isOpen = true
end

function WarrantService.close()
	isOpen = false
end

function WarrantService.init()
	WarrantRemote.OnServerEvent:Connect(onWarrant)
end

return WarrantService
