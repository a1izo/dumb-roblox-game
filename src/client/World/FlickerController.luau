-- Tired lamps and neon: parts tagged LFlicker (with a light inside) cut out for a moment now
-- and then. Local only, so every screen flickers on its own.

local CollectionService = game:GetService("CollectionService")

local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Blackout = require(script.Parent.Blackout)
local LightingController = require(script.Parent.LightingController)

local FlickerController = {}

local TAG = "LFlicker"
-- In the tower the lights flicker only now and then (one pick in this many is used): a tired
-- strip over the bullpen, a desk lamp. It is only a local light going dark for half a second, so
-- it never touches what anyone can see of a letter.
local RARE = { TaskForceHQ = 6 }

local function lightsOf(part: Instance): { Light }
	local list = {}
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("Light") then
			table.insert(list, child)
		end
	end
	return list
end

-- The glowing parts that go dark with a lamp: its own part (a fitting's face drawn by the game) and, for a
-- prop's lamp, the prop's glowing parts (SceneBuilder links them with a FlickerGlow value).
local function glowsOf(part: BasePart): { BasePart }
	local list = {}
	if part.Material == Enum.Material.Neon and part.Transparency < 1 then
		table.insert(list, part)
	end
	local link = part:FindFirstChild("FlickerGlow")
	local model = if link and link:IsA("ObjectValue") then link.Value else nil
	if model then
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") and item:GetAttribute("DeathsGambitGlow") ~= nil then
				table.insert(list, item)
			end
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
	local glows = glowsOf(part)
	local pulses = math.random(2, 4)
	for _ = 1, pulses do
		if not part.Parent then
			return
		end
		for _, light in ipairs(lights) do
			light.Brightness = 0
		end
		for _, glow in ipairs(glows) do
			glow.Material = Enum.Material.SmoothPlastic
		end
		task.wait(0.03 + math.random() * 0.08)
		-- Back to what the lighting wants now (a mood may have dimmed it meanwhile).
		for index, light in ipairs(lights) do
			light.Brightness = LightingController.lampBrightness(light) or brightness[index]
		end
		for _, glow in ipairs(glows) do
			glow.Material = Enum.Material.Neon
		end
		task.wait(0.04 + math.random() * 0.12)
	end
end

function FlickerController.init()
	task.spawn(function()
		while true do
			task.wait(1.2 + math.random() * 1.5)
			-- (Nothing flickers in a blackout: the lamps are out.)
			if not Settings.get("reduceMotion") and not Blackout.isActive() then
				local tagged = CollectionService:GetTagged(TAG)
				local mapId = ClientState.public.mapId
				local every = if type(mapId) == "string" then RARE[mapId] else nil
				if #tagged > 0 and (not every or math.random(1, every) == 1) then
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
