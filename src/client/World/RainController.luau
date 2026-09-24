-- Rain that follows the camera: one emitter above your head, stopped under a roof, heavier
-- or lighter with the venue's preset and the device (phones get less). Now and then the
-- sky flashes and thunder rolls in a second later.

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
local HEIGHT = 32
local ROOF_CHECK = 0.4

local holder: Part
local emitter: ParticleEmitter
local loop: Sound? = nil
local indoors = false
local lastRoofCheck = 0

local function rainAmount(): number
	return LightingController.preset().rain
end

local function refreshRate()
	local amount = if indoors then 0 else rainAmount()
	local cap = MAX_RATE[Responsive.class()] or MAX_RATE.desktop
	if Settings.get("reduceMotion") then
		cap *= 0.5
	end
	emitter.Rate = cap * amount
	if loop then
		local target = rainAmount() * (if indoors then 0.25 else 0.8)
		loop.Volume = target
	end
end

local function underRoof(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { holder }
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
	local texture = Assets.contentId(Assets.textures.rain)
	if texture ~= "" then
		emitter.Texture = texture
	end
	loop = Sfx.play("rainLoop", { group = "Ambience", looped = true, volume = 0 })
	RunService.RenderStepped:Connect(step)
	LightingController.Changed:Connect(refreshRate)
	Responsive.Changed:Connect(refreshRate)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" then
			refreshRate()
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		holder.Parent = workspace.CurrentCamera
	end)
	refreshRate()
	task.spawn(lightningLoop)
end

return RainController
