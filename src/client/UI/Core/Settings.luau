-- The player's settings: volumes, UI scale, reduced motion, camera shake and hints. They are
-- applied on this client right away and saved in the profile a moment later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Motion = require(script.Parent.Motion)
local Responsive = require(script.Parent.Responsive)

local Settings = {}

-- Fired as (key, value) whenever a setting changes, locally or from the profile.
Settings.Changed = Signal.new()

-- Must match the settings defaults in src/server/Data/Migrations.luau.
Settings.DEFAULTS = {
	music = 0.7,
	sfx = 1,
	ambience = 0.8,
	ui = 1,
	uiScale = 1,
	reduceMotion = false,
	cameraShake = true,
	hints = true,
	lowGraphics = false,
}

local values = table.clone(Settings.DEFAULTS)
local pending: { [string]: any } = {}
local sendQueued = false
local SEND_DELAY = 1

local function apply(key: string, value: any)
	if key == "reduceMotion" then
		Motion.setReduced(value == true)
	elseif key == "uiScale" then
		Responsive.setUserScale(tonumber(value) or 1)
	end
	Settings.Changed:Fire(key, value)
end

function Settings.get(key: string): any
	return values[key]
end

function Settings.set(key: string, value: any)
	if Settings.DEFAULTS[key] == nil or values[key] == value then
		return
	end
	values[key] = value
	pending[key] = value
	apply(key, value)
	if sendQueued then
		return
	end
	sendQueued = true
	task.delay(SEND_DELAY, function()
		sendQueued = false
		local batch = pending
		pending = {}
		if next(batch) then
			Net.event("ProfileRequest"):FireServer({ action = "settings", values = batch })
		end
	end)
end

local function fromProfile(profile)
	local saved = if type(profile) == "table" then profile.settings else nil
	if type(saved) ~= "table" then
		return
	end
	for key, default in pairs(Settings.DEFAULTS) do
		local value = saved[key]
		-- Changes still waiting to be sent win over the older saved value.
		if pending[key] == nil and type(value) == type(default) and values[key] ~= value then
			values[key] = value
			apply(key, value)
		end
	end
end

function Settings.init()
	ClientState.ProfileChanged:Connect(fromProfile)
	fromProfile(ClientState.profile)
end

return Settings
