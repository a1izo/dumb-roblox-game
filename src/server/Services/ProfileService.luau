-- Small profile changes a player makes from the menus, all through one remote
-- (ProfileRequest): settings now, and later hints seen, the custom alias, streak claims,
-- title choice and training progress. Every action is validated and rate-limited here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.RateLimit)

local ProfileRequest = Net.event("ProfileRequest")

local ProfileService = {}

-- Allowed settings: numbers are clamped to their range, booleans must be booleans.
local SETTINGS = {
	music = { min = 0, max = 1 },
	sfx = { min = 0, max = 1 },
	ambience = { min = 0, max = 1 },
	ui = { min = 0, max = 1 },
	uiScale = { min = 0.8, max = 1.25 },
	reduceMotion = "boolean",
	cameraShake = "boolean",
	hints = "boolean",
}

local function setSettings(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.values) ~= "table" then
		return
	end
	local changed = false
	for key, rule in pairs(SETTINGS) do
		local value = payload.values[key]
		if value ~= nil then
			if rule == "boolean" then
				if type(value) == "boolean" then
					data.settings[key] = value
					changed = true
				end
			elseif type(value) == "number" and value == value then
				data.settings[key] = math.clamp(value, rule.min, rule.max)
				changed = true
			end
		end
	end
	if changed then
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- action -> { cooldown in seconds, handler }
local ACTIONS: { [string]: { cooldown: number, handler: (Player, any) -> () } } = {
	settings = { cooldown = 0.5, handler = setSettings },
}

-- Other services add their actions here (for example hints or the custom alias).
function ProfileService.register(action: string, cooldown: number, handler: (Player, any) -> ())
	ACTIONS[action] = { cooldown = cooldown, handler = handler }
end

function ProfileService.init()
	ProfileRequest.OnServerEvent:Connect(function(player: Player, payload)
		if type(payload) ~= "table" or type(payload.action) ~= "string" then
			return
		end
		local entry = ACTIONS[payload.action]
		if not entry or not RateLimit.allow(player, "profile:" .. payload.action, entry.cooldown) then
			return
		end
		entry.handler(player, payload)
	end)
end

return ProfileService
