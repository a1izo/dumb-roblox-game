-- Rain and snow that follow the camera, stopped under a roof, heavier or lighter with the venue's
-- preset and the device (phones get less). The rain comes down in two layers, a dense near one of
-- long streaks slanting in the wind and a thin far one for depth, and splashes on the ground
-- round you; now and then the sky flashes and thunder rolls in a second later. In the snow the
-- flakes drift down slowly and the wind is heard over them.

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

-- Most drops per second for each device class at full rain: the near layer, the far layer and
-- the splashes on the ground.
local MAX_RATE = { phone = 260, tablet = 480, console = 700, desktop = 900 }
local FAR_SHARE = 0.35
local SPLASH_SHARE = 0.45
-- Most flakes per second at full snow: they fall slowly and live long, so fewer do.
local MAX_SNOW = { phone = 70, tablet = 120, console = 170, desktop = 220 }
local NEAR_HEIGHT = 24
local FAR_HEIGHT = 48
local SNOW_HEIGHT = 16
local ROOF_CHECK = 0.4
-- The rain slants a little in the wind (a steady breeze from the north-east).
local SLANT = CFrame.Angles(math.rad(7), 0, math.rad(-8))
local FALLBACK_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local holder: Part
local emitter: ParticleEmitter
local farHolder: Part
local farEmitter: ParticleEmitter
local splashHolder: Part
local splashEmitter: ParticleEmitter
local snowHolder: Part
local snowEmitter: ParticleEmitter
local loop: Sound? = nil
local windLoop: Sound? = nil
local indoors = false
local lastRoofCheck = 0
local groundY: number? = nil

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

-- The texture for the rain: Tokyo's own streak when its map brought it in, else the shared one.
local function texture(...: string): string
	for _, name in ipairs({ ... }) do
		local id = Assets.texture(name)
		if id ~= "" then
			return id
		end
	end
	return FALLBACK_TEXTURE
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
		cap *= 0.6
		snowCap *= 0.5
	end
	local rain = if indoors then 0 else cap * rainAmount()
	emitter.Rate = rain
	farEmitter.Rate = rain * FAR_SHARE
	splashEmitter.Rate = if groundY then rain * SPLASH_SHARE else 0
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

local function params(): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { holder, farHolder, splashHolder, snowHolder }
	local camera = workspace.CurrentCamera
	local subject = if camera then camera.CameraSubject else nil
	if subject and subject:IsA("Humanoid") and subject.Parent then
		table.insert(exclude, subject.Parent)
	end
	p.FilterDescendantsInstances = exclude
	return p
end

local function underRoof(position: Vector3, p: RaycastParams): boolean
	return workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, 80, 0), p) ~= nil
end

-- The ground (or water) under a spot, open to the sky: its height, or nil.
local function openGround(position: Vector3, p: RaycastParams): number?
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -70, 0), p)
	if not hit or underRoof(hit.Position, p) then
		return nil
	end
	return hit.Position.Y
end

local function step()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.CFrame.Position
	local ahead = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	holder.CFrame = CFrame.new(at + Vector3.new(0, NEAR_HEIGHT, 0) + ahead * 12) * SLANT
	farHolder.CFrame = CFrame.new(at + Vector3.new(0, FAR_HEIGHT, 0) + ahead * 30) * SLANT
	-- The flakes fall slowly, so the box sits lower and further ahead, where the camera looks.
	snowHolder.CFrame = CFrame.new(at + Vector3.new(0, SNOW_HEIGHT, 0) + ahead * 16)
	local now = os.clock()
	if now - lastRoofCheck > ROOF_CHECK then
		lastRoofCheck = now
		local p = params()
		local wasIndoors, hadGround = indoors, groundY ~= nil
		indoors = underRoof(at, p)
		local spot = at + ahead * 9
		groundY = if indoors then nil else openGround(spot, p)
		if groundY then
			splashHolder.CFrame = CFrame.new(spot.X, groundY + 0.08, spot.Z)
		end
		if wasIndoors ~= indoors or hadGround ~= (groundY ~= nil) then
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

local function box(name: string, size: Vector3): Part
	return Create("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = size,
		Parent = workspace.CurrentCamera,
	}) :: Part
end

local function makeRain()
	local streak = texture("TokyoRain", "RainStreak")
	-- Near: long thin streaks all round the camera, a little lit by the lamps they pass.
	holder = box("InkboundRain", Vector3.new(46, 1, 46))
	emitter = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(92, 108),
		Lifetime = NumberRange.new(0.42, 0.55),
		Rate = 0,
		Size = NumberSequence.new(0.16),
		Squash = NumberSequence.new(5),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0.3),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
		Color = ColorSequence.new(Color3.fromRGB(206, 214, 236)),
		LightInfluence = 0.6,
		LightEmission = 0.3,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(1.5, 1.5),
		Texture = streak,
		Parent = holder,
	}) :: ParticleEmitter
	-- Far: a thin veil further out and higher, fainter, falling past the camera to the street.
	farHolder = box("InkboundRainFar", Vector3.new(130, 1, 130))
	farEmitter = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Bottom,
		Speed = NumberRange.new(92, 108),
		Lifetime = NumberRange.new(0.75, 0.95),
		Rate = 0,
		Size = NumberSequence.new(0.3),
		Squash = NumberSequence.new(6),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.62),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
		Color = ColorSequence.new(Color3.fromRGB(190, 198, 226)),
		LightInfluence = 0.5,
		LightEmission = 0.2,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(1.5, 1.5),
		Texture = streak,
		Parent = farHolder,
	}) :: ParticleEmitter
	-- Splashes: rings flat on the ground round where you look, each a fraction of a second.
	splashHolder = box("InkboundRainSplash", Vector3.new(34, 0.1, 34))
	local ring = Assets.texture("TokyoSplash")
	splashEmitter = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.2, 0.4),
		Lifetime = NumberRange.new(0.2, 0.32),
		Rate = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, if ring ~= "" then 0.9 else 0.45),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(200, 208, 230)),
		LightInfluence = 0.7,
		LightEmission = 0.2,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Texture = if ring ~= "" then ring else FALLBACK_TEXTURE,
		Parent = splashHolder,
	}) :: ParticleEmitter
end

local function makeSnow()
	snowHolder = box("InkboundSnow", Vector3.new(90, 1, 90))
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
	}) :: ParticleEmitter
	local flake = Assets.texture("Snowflake")
	snowEmitter.Texture = if flake ~= "" then flake else FALLBACK_TEXTURE
end

-- A map imported after the client started may bring the rain's textures: pick them up when the
-- venue's look changes (entering a match).
local function refreshTextures()
	local streak = texture("TokyoRain", "RainStreak")
	emitter.Texture = streak
	farEmitter.Texture = streak
	local ring = Assets.texture("TokyoSplash")
	if ring ~= "" then
		splashEmitter.Texture = ring
	end
end

function RainController.init()
	makeRain()
	makeSnow()
	loop = Sfx.play("rainLoop", { group = "Ambience", looped = true, volume = 0 })
	windLoop = Sfx.play("mapWindSnow", { group = "Ambience", looped = true, volume = 0 })
	RunService.RenderStepped:Connect(step)
	LightingController.Changed:Connect(function()
		refreshTextures()
		refreshRate()
	end)
	Responsive.Changed:Connect(refreshRate)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" or key == "lowGraphics" then
			refreshRate()
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		for _, part in ipairs({ holder, farHolder, splashHolder, snowHolder }) do
			part.Parent = workspace.CurrentCamera
		end
	end)
	refreshRate()
	task.spawn(lightningLoop)
end

return RainController
