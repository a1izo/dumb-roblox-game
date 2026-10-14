-- Emotes are animated on every client, so the server passes them on: it checks the emote (owned from the
-- shop, or the Emote Pack pass, and never a lobby-only emote in a match) and sends it to everyone who can
-- see the player (Specters' emotes only reach other Specters). It also keeps the emote wheel
-- (Shared/EmoteWheel): the eight emotes a player put on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local ProfileService = require(script.Parent.ProfileService)
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

-- May the player use this emote at all (everyone's, bought, earned, or from its pass)?
function EmoteService.canUse(player: Player, emote: QuickChat.Emote): boolean
	local item = if emote.item then Cosmetics.byId(emote.item) else nil
	if item then
		-- (owns counts the Emote Pack for the four it brings)
		return CosmeticsService.owns(player, item)
	elseif emote.pass then
		return PassService.owns(player, emote.pass)
	end
	return true
end

-- In a case right now (a lobby-only emote would look like one of its signals there).
local function inCase(player: Player): boolean
	return Match.active and Match.get(player) ~= nil
end

local function onEmote(player: Player, emoteId)
	if type(emoteId) ~= "string" or not RateLimit.allow(player, "emote", 0.8) then
		return
	end
	local emote = QuickChat.emote(emoteId)
	if not emote or not EmoteService.canUse(player, emote) then
		return
	end
	if emote.lobbyOnly and inCase(player) then
		Match.notify(player, emote.name .. " is for the lobby only.", "info")
		return
	end
	-- A Specter waiting in the lobby is hidden; an emote would only show where they stand.
	if player.Character and player.Character:GetAttribute("Away") then
		return
	end
	-- Now and then an emote plays its other ending (Furious Scribbling's slash), the same on every screen.
	local clip = emote.id
	local item = if emote.item then Cosmetics.byId(emote.item) else nil
	if item and type(item.alt) == "string" and math.random() < (tonumber(item.altChance) or 0.5) then
		clip = item.alt
	end
	local payload = { userId = player.UserId, emote = clip }
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

-- Puts an emote just bought on the wheel's first empty slot (nothing when the wheel is full). The caller
-- pushes and saves the profile.
function EmoteService.placeBought(data, clip: string): number?
	local slots, slot = EmoteWheel.place(data.emoteWheel, clip)
	data.emoteWheel = slots
	return slot
end

-- ProfileRequest "emoteWheel": { slot = 1..8, emote = clip id or "" to empty the slot }.
local function setWheel(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.slot) ~= "number" or type(payload.emote) ~= "string" then
		return
	end
	if payload.emote ~= "" then
		local emote = QuickChat.emote(payload.emote)
		if not emote or not EmoteService.canUse(player, emote) then
			return
		end
	end
	data.emoteWheel = EmoteWheel.set(data.emoteWheel, payload.slot, payload.emote)
	DataService.push(player)
	DataService.saveSoon(player)
end

function EmoteService.init()
	EmoteRemote.OnServerEvent:Connect(onEmote)
	ProfileService.register("emoteWheel", 0.15, setWheel)
end

return EmoteService
