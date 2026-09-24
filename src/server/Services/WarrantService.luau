-- Zero's warrant (role id "L"): one arrest per match, during the vote. Zero picks a suspect
-- and types that player's full real name. A wrong name rejects the warrant (only Zero is
-- told) and Zero must wait for the next round to try again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
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
		EventLog.add(
			Terms.f(
				"{Zero} ({alias}) tried to arrest {suspect}, but the name was wrong. Warrant rejected.",
				{ alias = l.alias, suspect = suspect.alias }
			),
			"warrant"
		)
		Match.notify(
			player,
			"Warrant rejected: that is not the suspect's real name. You can try again next round.",
			"bad"
		)
		Match.pushPrivate(l)
		return
	end

	l.warrantUsed = true
	Match.pushPrivate(l)
	if suspect.role == "Kira" then
		l.stats.arrestedKira = true
		EventLog.add(
			Terms.f(
				"{Zero} ({alias}) arrested {suspect} with a valid warrant. {suspect} was {hand}.",
				{ alias = l.alias, suspect = suspect.alias }
			),
			"warrant"
		)
		Match.announce(
			"Warrant served: " .. suspect.alias .. " arrested",
			Terms.f("{suspect} was {HAND}!", { suspect = suspect.alias }),
			"team"
		)
		Elimination.eliminate(
			suspect,
			"arrested",
			nil,
			Terms.f("{suspect} was arrested by {zero}.", { suspect = suspect.alias }),
			{}
		)
	elseif suspect.role == "Follower" then
		EventLog.add(
			Terms.f("{Zero} ({alias}) arrested {suspect}, a {cultist}.", { alias = l.alias, suspect = suspect.alias }),
			"warrant"
		)
		Match.announce(
			"Warrant served: " .. suspect.alias .. " arrested",
			Terms.f("{suspect} was a {cultist}. {Hand} is still free.", { suspect = suspect.alias }),
			"team"
		)
		Elimination.eliminate(
			suspect,
			"arrested",
			nil,
			Terms.f("{suspect} was arrested by {zero}.", { suspect = suspect.alias }),
			{}
		)
	else
		EventLog.add(
			Terms.f(
				"{Zero} ({alias}) arrested {suspect}, who was innocent.",
				{ alias = l.alias, suspect = suspect.alias }
			),
			"warrant"
		)
		Match.declareWinner("Kira", Terms.f("{Zero} arrested an innocent player."))
		Match.announce("Warrant served: " .. suspect.alias .. " arrested", suspect.alias .. " was innocent...", "kira")
		Elimination.eliminate(
			suspect,
			"arrested",
			nil,
			Terms.f("{suspect} was arrested by {zero}.", { suspect = suspect.alias }),
			{}
		)
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
