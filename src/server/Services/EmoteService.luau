-- Emotes are animated on every client, so the server passes them on: it checks the emote and
-- the Emote Pack pass, and sends it to everyone who can see the player (Specters' emotes only
-- reach other Specters).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local RateLimit = require(script.Parent.RateLimit)

local EmoteRemote = Net.event("Emote")

local EmoteService = {}

local function isSpecter(player: Player): boolean
	if not Match.active then
		return false
	end
	local ps = Match.get(player)
	return ps ~= nil and not ps.alive and ps.status ~= "left"
end

local function onEmote(player: Player, emoteId)
	if type(emoteId) ~= "string" or not RateLimit.allow(player, "emote", 0.8) then
		return
	end
	local emote = nil
	for _, candidate in ipairs(QuickChat.EMOTES) do
		if candidate.id == emoteId then
			emote = candidate
		end
	end
	if not emote or (emote.pass and not PassService.owns(player, emote.pass)) then
		return
	end
	-- A Specter waiting in the lobby is hidden; an emote would only show where they stand.
	if player.Character and player.Character:GetAttribute("Away") then
		return
	end
	local payload = { userId = player.UserId, emote = emote.id }
	if isSpecter(player) then
		for _, other in ipairs(Players:GetPlayers()) do
			if isSpecter(other) then
				EmoteRemote:FireClient(other, payload)
			end
		end
	else
		EmoteRemote:FireAllClients(payload)
	end
end

function EmoteService.init()
	EmoteRemote.OnServerEvent:Connect(onEmote)
end

return EmoteService
