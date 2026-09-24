-- The private-server Director: the owner of a VIP server who has the Director pass can set
-- rounds, phase times and maps between matches. Everyone in the server is told when the
-- rules change, since custom rules only pay participation rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SettingsSchema = require(Shared:WaitForChild("SettingsSchema"))

local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)
local RateLimit = require(script.Parent.RateLimit)
local ServerSettings = require(script.Parent.ServerSettings)

local PrivateServerRemote = Net.event("PrivateServer")

local DirectorService = {}

local function canDirect(player: Player): boolean
	return ServerSettings.isVipServer
		and player.UserId == ServerSettings.ownerId
		and PassService.owns(player, "director")
end

local function payload(player: Player)
	return {
		action = "state",
		vip = ServerSettings.isVipServer,
		canEdit = canDirect(player),
		custom = ServerSettings.isCustom(),
		settings = ServerSettings.get(),
	}
end

local function broadcast()
	for _, player in ipairs(Players:GetPlayers()) do
		PrivateServerRemote:FireClient(player, payload(player))
	end
end

local function onRequest(player: Player, request)
	if type(request) ~= "table" or not RateLimit.allow(player, "director", 0.5) then
		return
	end
	if request.action == "get" then
		PrivateServerRemote:FireClient(player, payload(player))
	elseif request.action == "set" then
		if not canDirect(player) then
			return
		end
		if Match.active then
			Match.notify(player, "Change the rules between matches.", "bad")
			return
		end
		ServerSettings.set(request.settings)
		broadcast()
		if ServerSettings.isCustom() then
			for _, other in ipairs(Players:GetPlayers()) do
				Match.notify(other, "Custom rules are on: matches pay participation rewards only.", "info")
			end
		end
	elseif request.action == "reset" and canDirect(player) and not Match.active then
		ServerSettings.set(SettingsSchema.defaults())
		broadcast()
	end
end

function DirectorService.init()
	PrivateServerRemote.OnServerEvent:Connect(onRequest)
	PassService.Changed:Connect(function(player, key)
		if key == "director" then
			PrivateServerRemote:FireClient(player, payload(player))
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, function()
			if player.Parent == Players then
				PrivateServerRemote:FireClient(player, payload(player))
			end
		end)
	end)
end

return DirectorService
