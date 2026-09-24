-- This server's match settings. Public servers always use the defaults; in a private (VIP)
-- server the owner with the Director pass can change them between matches. Custom settings
-- only pay participation rewards, so they cannot be used to farm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SettingsSchema = require(Shared:WaitForChild("SettingsSchema"))
local Signal = require(Shared:WaitForChild("Signal"))

local ServerSettings = {}

ServerSettings.isVipServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
ServerSettings.ownerId = game.PrivateServerOwnerId

-- Fired with the new settings.
ServerSettings.Changed = Signal.new()

local current = SettingsSchema.defaults()
current.rounds = Config.MAX_ROUNDS

function ServerSettings.get(): SettingsSchema.Settings
	return current
end

function ServerSettings.set(input: any)
	current = SettingsSchema.clamp(input)
	ServerSettings.Changed:Fire(current)
end

function ServerSettings.isCustom(): boolean
	return ServerSettings.isVipServer and SettingsSchema.isCustom(current)
end

function ServerSettings.rounds(): number
	return current.rounds
end

-- The phase length the owner chose, or nil to use Config.PHASE_TIME.
function ServerSettings.phaseOverride(phase: string): number?
	if not ServerSettings.isCustom() then
		return nil
	end
	if phase == "Investigation" then
		return current.investigation
	elseif phase == "DeathNote" then
		return current.grimoire
	elseif phase == "Meeting" then
		return current.meeting
	elseif phase == "Vote" then
		return current.vote
	end
	return nil
end

function ServerSettings.maps(): { string }
	return current.maps
end

return ServerSettings
