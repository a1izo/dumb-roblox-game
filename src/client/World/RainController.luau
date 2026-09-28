-- Rain and snow that follow the camera: an emitter each above your head, stopped under a roof,
-- heavier or lighter with the venue's preset and the device (phones get less). Now and then in
-- the rain the sky flashes and thunder rolls in a second later; in the snow the flakes drift
-- down slowly and the wind is heard over them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local LightingController = require(script.Parent.LightingController)

local RainController = {}

-- Most drops per second for each device class at full rain.
local MAX_RATE = { phone = 150, tablet = 280, console = 400, desktop = 500 }
-- Most flakes per second at full snow: they fall slowly and live long, so fewer do.
local MAX_SNOW = { phone = 70, tablet = 120, console = 170, desktop = 220 }
local HEIGHT = 32
local SNOW_HEIGHT = 16
local ROOF_CHECK = 0.4

local holder: Part
local emitter: ParticleEmitter
local snowHolder: Part
local snowEmitter: ParticleEmitter
local loop: Sound? = nil
local windLoop: Sound? = nil
local indoors = false
local lastRoofCheck = 0

-- Set from the debug panel (setDebug): rain and snow from 0 to 1 whatever the preset says
-- (nil = the preset).
RainController.debugRain = nil :: number?
RainController.debugSnow = nil :: number?

local function rainAmount(): number
	return RainController.debugRain or LightingController.preset().rain
end

-- How hard it snows here (0 to 1): the preset's snow, or the debug panel's.
function RainController.snowAmount(): number
	return RainController.debugSnow or LightingController.preset().snow
end

local function refreshRate()
	local class = Responsive.class()
	local cap = MAX_RATE[class] or MAX_RATE.desktop
	local snowCap = MAX_SNOW[class] or MAX_SNOW.desktop
	if Settings.get("reduceMotion") then
		cap *= 0.5
		snowCap *= 0.5
	end
	if Settings.get("lowGraphics") then
		snowCap *= 0.5
	end
	emitter.Rate = if indoors then 0 else cap * rainAmount()
	snowEmitter.Rate = if indoors then 0 else snowCap * RainController.snowAmount()
	if loop then
		loop.Volume = rainAmount() * (if indoors then 0.25 else 0.8)
	end
	if windLoop then
		windLoop.Volume = RainController.snowAmount() * (if indoors then 0.3 else 0.9)
	end
end

-- Debug panel: forces the rain and the snow (nil for the preset's), at once.
function RainController.setDebug(rain: number?, snow: number?)
	RainController.debugRain = rain
	RainController.debugSnow = snow
	refreshRate()
end

local function underRoof(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { holder, snowHolder }
	local camera = workspace.CurrentCamera
	local subject = if camera then camera.CameraSubject else nil
	if subject and subject:IsA("Humanoid") and subject.Parent then
		table.insert(exclude, subject.Parent)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, 80, 0), params) ~= nil
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.CFrame.Position
	holder.CFrame = CFrame.new(at + Vector3.new(0, HEIGHT, 0) + camera.CFrame.LookVector * 14)
	-- The flakes fall slowly, so the box sits lower and further ahead, where the camera looks.
	local ahead = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	snowHolder.CFrame = CFrame.new(at + Vector3.new(0, SNOW_HEIGHT, 0) + ahead * 16)
	local now = os.clock()
	if now - lastRoofCheck > ROOF_CHECK then
		lastRoofCheck = now
		local wasIndoors = indoors
		indoors = underRoof(at)
		if wasIndoors ~= indoors then
			refreshRate()
		end
	end
end

local function lightningLoop()
	while true do
		task.wait(math.random(14, 32))
		local preset = LightingController.preset()
		if preset.lightning and preset.rain > 0 then
			if not Settings.get("reduceMotion") then
				LightingController.lightning()
			end
			task.delay(0.6 + math.random() * 1.6, function()
				Sfx.play("thunder", { group = "Ambience", volume = if indoors then 0.5 else 0.9 })
			end)
		end
	end
end

local function makeSnow()
	snowHolder = Create("Part", {
		Name = "InkboundSnow",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(90, 1, 90),
		Parent = workspace.CurrentCamera,
	})
	snowEmitter = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(3, 5),
		Lifetime = NumberRange.new(6, 8),
		Rate = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2, 0.07),
			NumberSequenceKeypoint.new(1, 0.2, 0.07),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.08, 0.15),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(242, 244, 255)),
		LightInfluence = 0.5,
		LightEmission = 0.15,
		-- A slow drift with the wind, each flake wandering a little on its way down: the drag
		-- holds them near 4 studs a second down and 3 across.
		Acceleration = Vector3.new(1, -1.4, 0.6),
		Drag = 0.5,
		SpreadAngle = Vector2.new(28, 28),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		Parent = snowHolder,
	})
	local texture = Assets.texture("Snowflake")
	snowEmitter.Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds"
end

function RainController.init()
	holder = Create("Part", {
		Name = "InkboundRain",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(70, 1, 70),
		Parent = workspace.CurrentCamera,
	})
	emitter = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(80, 95),
		Lifetime = NumberRange.new(0.55, 0.7),
		Rate = 0,
		Size = NumberSequence.new(0.09),
		Squash = NumberSequence.new(3),
		Transparency = NumberSequence.new(0.45),
		Color = ColorSequence.new(Color3.fromRGB(200, 210, 235)),
		LightInfluence = 0.6,
		LightEmission = 0.2,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Acceleration = Vector3.new(2, 0, 0),
		SpreadAngle = Vector2.new(2, 2),
		Parent = holder,
	})
	local texture = Assets.texture("RainStreak")
	if texture ~= "" then
		emitter.Texture = texture
	end
	makeSnow()
	loop = Sfx.play("rainLoop", { group = "Ambience", looped = true, volume = 0 })
	windLoop = Sfx.play("mapWindSnow", { group = "Ambience", looped = true, volume = 0 })
	RunService.RenderStepped:Connect(step)
	LightingController.Changed:Connect(refreshRate)
	Responsive.Changed:Connect(refreshRate)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" or key == "lowGraphics" then
			refreshRate()
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		holder.Parent = workspace.CurrentCamera
		snowHolder.Parent = workspace.CurrentCamera
	end)
	refreshRate()
	task.spawn(lightningLoop)
end

return RainController
