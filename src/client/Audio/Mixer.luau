-- The four sound groups (music, sound effects, ambience, UI) on this client, with their
-- volumes taken from the player's settings. Cutscenes can duck the music for a moment. A fifth,
-- "Outdoor", sits inside Ambience for everything heard from outside (the rain, the wind, thunder,
-- the river, the city): Audio/Muffle closes a low-pass on it when the player goes in.

local SoundService = game:GetService("SoundService")

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local Mixer = {}

-- group name -> settings key
local GROUPS = {
	Music = "music",
	Sfx = "sfx",
	Ambience = "ambience",
	Ui = "ui",
}

-- Base loudness of each group before the player's own volume.
local BASE = {
	Music = 0.5,
	Sfx = 0.8,
	Ambience = 0.6,
	Ui = 0.6,
}

local groups: { [string]: SoundGroup } = {}
local ducks: { [string]: boolean } = {}

local function duckFactor(): number
	return if next(ducks) ~= nil then 0.35 else 1
end

local function apply(name: string, fade: number?)
	local group = groups[name]
	if not group then
		return
	end
	local volume = BASE[name] * (tonumber(Settings.get(GROUPS[name])) or 1)
	if name == "Music" then
		volume *= duckFactor()
	end
	Motion.tween(group, { Volume = volume }, fade or 0)
end

function Mixer.group(name: string): SoundGroup
	return groups[name]
end

-- Turns the music down while any reason holds a duck (cutscene stingers, death sequences).
function Mixer.duck(reason: string, on: boolean)
	ducks[reason] = if on then true else nil
	apply("Music", 0.6)
end

function Mixer.init()
	for name in pairs(GROUPS) do
		local existing = SoundService:FindFirstChild("Inkbound" .. name)
		if existing then
			existing:Destroy()
		end
		local group = Instance.new("SoundGroup")
		group.Name = "Inkbound" .. name
		group.Parent = SoundService
		groups[name] = group
		apply(name)
	end
	local outdoor = Instance.new("SoundGroup")
	outdoor.Name = "InkboundOutdoor"
	outdoor.Parent = groups.Ambience
	groups.Outdoor = outdoor
	Settings.Changed:Connect(function(key)
		for name, settingKey in pairs(GROUPS) do
			if settingKey == key then
				apply(name, 0.2)
			end
		end
	end)
end

return Mixer
