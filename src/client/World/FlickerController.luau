-- Tired lamps and neon: parts tagged LFlicker (with a light inside) cut out for a moment now
-- and then. Local only, so every screen flickers on its own.

local CollectionService = game:GetService("CollectionService")

local Settings = require(script.Parent.Parent.UI.Core.Settings)

local FlickerController = {}

local TAG = "LFlicker"

local function lightsOf(part: Instance): { Light }
	local list = {}
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("Light") then
			table.insert(list, child)
		end
	end
	return list
end

local function flicker(part: BasePart)
	local lights = lightsOf(part)
	local brightness = {}
	for index, light in ipairs(lights) do
		brightness[index] = light.Brightness
	end
	local material = part.Material
	local pulses = math.random(2, 4)
	for _ = 1, pulses do
		if not part.Parent then
			return
		end
		for _, light in ipairs(lights) do
			light.Brightness = 0
		end
		if material == Enum.Material.Neon then
			part.Material = Enum.Material.SmoothPlastic
		end
		task.wait(0.03 + math.random() * 0.08)
		for index, light in ipairs(lights) do
			light.Brightness = brightness[index]
		end
		part.Material = material
		task.wait(0.04 + math.random() * 0.12)
	end
end

function FlickerController.init()
	task.spawn(function()
		while true do
			task.wait(1.2 + math.random() * 1.5)
			if not Settings.get("reduceMotion") then
				local tagged = CollectionService:GetTagged(TAG)
				if #tagged > 0 then
					local part = tagged[math.random(1, #tagged)]
					if part:IsA("BasePart") then
						task.spawn(flicker, part)
					end
				end
			end
		end
	end)
end

return FlickerController
