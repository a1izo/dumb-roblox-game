-- A map's blackout (Bureau HQ's breaker): while the map's BlackoutUntil (server time) is ahead, its
-- emergency lamps (SceneBuilder.EMERGENCY_TAG) glow and pulse a slow red, and the power dies and comes
-- back with a sound. The lighting look itself is LightingController's ("Blackout" mood); the rules
-- (sight, name tags, once per round) are the server's.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Sfx = require(script.Parent.Parent.Audio.Sfx)

local Blackout = {}

local TAG = "LMapEmergency"
local PULSE = 2.4 -- seconds per breath

local active = false
local watched: Instance? = nil

local function lamps(): { Light }
	local list = {}
	for _, anchor in ipairs(CollectionService:GetTagged(TAG)) do
		for _, item in ipairs(anchor:GetChildren()) do
			if item:IsA("Light") then
				table.insert(list, item)
			end
		end
	end
	return list
end

local function setLamps(on: boolean)
	for _, light in ipairs(lamps()) do
		if light:GetAttribute("LBase") == nil then
			light:SetAttribute("LBase", light.Brightness)
		end
		light.Enabled = on
	end
end

function Blackout.isActive(): boolean
	return active
end

local function refresh()
	local map = workspace:FindFirstChild("LGameMap")
	local untilTime = if map then map:GetAttribute("BlackoutUntil") else nil
	local on = type(untilTime) == "number" and workspace:GetServerTimeNow() < untilTime
	if on == active then
		return
	end
	active = on
	setLamps(on)
	Sfx.play(if on then "mapPowerDown" else "mapPowerUp", { volume = 0.8 })
	if on then
		Sfx.play("mapBreakerClunk", { volume = 0.9 })
	end
end

local function watch(map: Instance)
	if watched == map then
		return
	end
	watched = map
	map:GetAttributeChangedSignal("BlackoutUntil"):Connect(refresh)
	refresh()
end

function Blackout.init()
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "LGameMap" then
			watch(child)
		end
	end)
	local map = workspace:FindFirstChild("LGameMap")
	if map then
		watch(map)
	end
	RunService.Heartbeat:Connect(function()
		if active then
			-- (The blackout also ends on its own clock, should the attribute's change be missed.)
			local current = workspace:FindFirstChild("LGameMap")
			local untilTime = if current then current:GetAttribute("BlackoutUntil") else nil
			if type(untilTime) ~= "number" or workspace:GetServerTimeNow() >= untilTime then
				refresh()
				return
			end
			local breath = 0.6 + 0.4 * math.sin(os.clock() * 2 * math.pi / PULSE)
			for _, light in ipairs(lamps()) do
				local base = light:GetAttribute("LBase")
				if type(base) == "number" then
					light.Brightness = base * breath
				end
			end
		end
	end)
end

return Blackout
