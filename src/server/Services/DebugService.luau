-- Studio-only test commands, sent by the debug panel (F2 in a Studio play test). Live
-- servers never connect the handler, so these commands cannot run in a published game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local DataService = require(script.Parent.DataService)
local Elimination = require(script.Parent.Elimination)
local Match = require(script.Parent.Match)

local DebugRemote = Net.event("Debug")

local DebugService = {}

DebugService.ENABLED = RunService:IsStudio() and Config.STUDIO_DEBUG == true

-- A living match player whose alias starts with the given text (case-insensitive).
local function findLiving(text: any)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local wanted = string.lower(text)
	for _, ps in ipairs(Match.living()) do
		if string.sub(string.lower(ps.alias), 1, #wanted) == wanted then
			return ps
		end
	end
	return nil
end

local function reply(player: Player, text: string)
	Match.notify(player, "[debug] " .. text, "secret")
end

local COMMANDS: { [string]: (Player, any) -> () } = {
	nextPhase = function(player)
		if not Match.active then
			reply(player, "No match is running.")
			return
		end
		Match.phaseEndsAt = workspace:GetServerTimeNow()
		reply(player, "Ending the " .. Terms.phase(Match.phase) .. " now.")
	end,
	winTeam = function(player)
		if Match.active then
			Match.declareWinner("Team", "Debug: forced win.")
			reply(player, Terms.f("{Agency} wins."))
		end
	end,
	winHand = function(player)
		if Match.active then
			Match.declareWinner("Kira", "Debug: forced win.")
			reply(player, Terms.f("{Hand} wins."))
		end
	end,
	kill = function(player, target)
		local ps = findLiving(target)
		if not ps then
			reply(player, "No living player with that alias.")
			return
		end
		Elimination.eliminate(
			ps,
			"dead",
			"Heart attack",
			ps.alias .. " collapsed. Cause of death: heart attack.",
			{ byKira = true }
		)
		Match.announce(ps.alias .. " is dead", "Cause of death: Heart attack", "danger")
	end,
	voteOut = function(player, target)
		local ps = findLiving(target)
		if not ps then
			reply(player, "No living player with that alias.")
			return
		end
		Match.announce(ps.alias .. " was voted out", "Debug vote", "neutral")
		Elimination.eliminate(ps, "voted", nil, ps.alias .. " was voted out.", {})
	end,
	roster = function(player)
		if not Match.active then
			reply(player, "No match is running.")
			return
		end
		for _, ps in ipairs(Match.list) do
			print(
				string.format(
					"[Inkbound debug] %-10s %-12s %-22s %s",
					ps.alias,
					Terms.role(ps.role, "Name"),
					ps.realName,
					ps.status
				)
			)
		end
		reply(player, "Roles and real names printed to the Output window.")
	end,
	coins = function(player)
		local data = DataService.get(player)
		if data then
			data.coins += 500
			DataService.push(player)
			reply(player, "+500 coins.")
		end
	end,
	xp = function(player)
		local data = DataService.get(player)
		if data then
			data.xp += 500
			DataService.push(player)
			reply(player, "+500 XP.")
		end
	end,
}

function DebugService.init()
	if not DebugService.ENABLED then
		return
	end
	DebugRemote.OnServerEvent:Connect(function(player: Player, command: any, argument: any)
		if player.Parent ~= Players or type(command) ~= "string" then
			return
		end
		local handler = COMMANDS[command]
		if handler then
			handler(player, argument)
		end
	end)
	print("[Inkbound] Debug panel enabled (press F2 in a play test).")
end

return DebugService
