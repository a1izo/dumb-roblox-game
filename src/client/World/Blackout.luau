-- A map's blackout (Bureau HQ's breaker): while the map's BlackoutUntil (server time) is ahead, its
-- emergency lamps (SceneBuilder.EMERGENCY_TAG) glow and pulse a slow red, the building's own glowing
-- fittings (ceiling panels, tubes, downlights, desk lamps, monitors) go dark with their lights, and the
-- power dies and comes back with a sound. Red and green glows stay: exit signs, standby lights and the
-- emergency lamps run on batteries, and the city's windows far below have power. The lighting look
-- itself is LightingController's ("Blackout" mood); the rules (sight, name tags, once per round) are
-- the server's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Venues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Venues"))

local Sfx = require(script.Parent.Parent.Audio.Sfx)

local Blackout = {}

local TAG = "LMapEmergency"
local PULSE = 2.4 -- seconds per breath

local active = false
local watched: Instance? = nil

-- What loses power, per map: the scene's glowing looks (meshes Map_<Venue>_<Look>_<n>) and every prop's
-- glowing part, inside the building (a box around the map's origin: min and max corners, studs).
local DARK = {
	TaskForceHQ = {
		looks = {
			PanelWarm = true,
			PanelCool = true,
			TubeDiffuser = true,
			NeonWarm = true,
			NeonCool = true,
		},
		box = { Vector3.new(-104, -2, -79), Vector3.new(104, 34, 79) },
	},
}
local darkened: { [BasePart]: { material: Enum.Material, color: Color3 } } = {}

-- A glow in a safety colour (exit green, standby or emergency red) keeps its battery.
local function safety(color: Color3): boolean
	local h, s = color:ToHSV()
	return s > 0.45 and (h < 0.05 or h > 0.93 or (h > 0.22 and h < 0.45))
end

local function setGlows(map: Instance?, on: boolean)
	if not on then
		for part, was in pairs(darkened) do
			if part.Parent then
				part.Material = was.material
				part.Color = was.color
			end
		end
		table.clear(darkened)
		return
	end
	local spec = if map then DARK[tostring(map:GetAttribute("MapId"))] else nil
	if not map or not spec then
		return
	end
	local low, high = Venues.MAP + spec.box[1], Venues.MAP + spec.box[2]
	for _, item in ipairs(map:GetDescendants()) do
		if item:IsA("BasePart") and item.Material == Enum.Material.Neon and not darkened[item] then
			local look = string.match(item.Name, "^Map_%a+_(%a+)_%d+$")
			local glowing = (look ~= nil and spec.looks[look] == true)
				or (
					(item:GetAttribute("DeathsGambitGlow") ~= nil or (item.Name == "Light" and item.Transparency < 1))
					and not safety(item.Color)
				)
			local p = item.Position
			if
				glowing
				and p.X >= low.X
				and p.X <= high.X
				and p.Y >= low.Y
				and p.Y <= high.Y
				and p.Z >= low.Z
				and p.Z <= high.Z
			then
				darkened[item] = { material = item.Material, color = item.Color }
				item.Material = Enum.Material.SmoothPlastic
				item.Color = item.Color:Lerp(Color3.new(0.05, 0.05, 0.06), 0.85)
			end
		end
	end
end

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
	setGlows(map, on)
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
