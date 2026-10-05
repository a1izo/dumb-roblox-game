-- Everything heard from outside sounds muffled once you go in: the rain, the wind, thunder, the
-- river, the city's hum. A low-pass (an equaliser on the outdoor sound group) closes as the
-- player's shelter grows (World/Shelter: 0 in the open, about 0.5 under a roof or an awning, 1
-- inside a building) and the group gets a little quieter. In the tower the weather behind the
-- glass is always muffled. Music, interface and task sounds are not outdoor sounds and stay clear.

local RunService = game:GetService("RunService")

local Mixer = require(script.Parent.Mixer)
local Shelter = require(script.Parent.Parent.World.Shelter)

local Muffle = {}

local TUNING = {
	-- At full shelter: dB taken off the high and mid bands (the equaliser's bands are fixed), and how
	-- much quieter the group gets.
	highCut = -34,
	midCut = -9,
	quieter = 0.3,
	settle = 0.25, -- seconds the filter takes to close or open
}

local effect: EqualizerSoundEffect? = nil
local level = 0

-- How closed the filter is now (0 open, 1 full), for the tests and the debug panel.
function Muffle.level(): number
	return level
end

local function apply()
	local group = Mixer.group("Outdoor")
	if not effect or not group then
		return
	end
	effect.LowGain = 0
	effect.MidGain = TUNING.midCut * level
	effect.HighGain = TUNING.highCut * level
	group.Volume = 1 - TUNING.quieter * level
end

function Muffle.init()
	local group = Mixer.group("Outdoor")
	if not group then
		return
	end
	local existing = group:FindFirstChild("Muffle")
	if existing then
		existing:Destroy()
	end
	local filter = Instance.new("EqualizerSoundEffect")
	filter.Name = "Muffle"
	filter.Parent = group
	effect = filter
	apply()
	RunService.Heartbeat:Connect(function(delta)
		local target = Shelter.level()
		if math.abs(target - level) < 0.002 then
			return
		end
		level += (target - level) * (1 - math.exp(-delta / TUNING.settle))
		apply()
	end)
end

return Muffle
