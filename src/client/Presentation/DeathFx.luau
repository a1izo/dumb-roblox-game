-- Effects for deaths and big moments, local to this client, in the Notch style: a burst of black, white and
-- red shards, a chalk outline of the body on the floor that fades, static rising off a body while it
-- dissolves, sparks, and a dark red wash over your own screen when you are taken out. Textures come
-- from Blender (Assets.texture); without them the effects that need a shape are skipped and bursts use
-- Roblox's default particle.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)

local C = Kit.color

local DeathFx = {}

DeathFx.DARK = C.g0
DeathFx.CHALK = C.white
DeathFx.DANGER = C.danger

local function anchorPart(position: Vector3): Part
	return Create("Part", {
		Name = "DeathFx",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
		Parent = workspace.CurrentCamera,
	})
end

-- A particle emitter with a Blender texture when there is one (Roblox's default otherwise).
local function emitter(textureName: string, props: { [string]: any }): ParticleEmitter
	local texture = Assets.texture(textureName)
	if texture ~= "" then
		props.Texture = texture
	end
	return Create("ParticleEmitter", props)
end

-- A burst of shards flung out from a point: dark, white and a little red.
function DeathFx.burst(position: Vector3, colour: Color3?, amount: number?)
	local holder = anchorPart(position)
	local count = amount or 36
	local palette = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour or DeathFx.DARK),
		ColorSequenceKeypoint.new(0.5, DeathFx.CHALK),
		ColorSequenceKeypoint.new(1, DeathFx.DANGER),
	})
	local shards = emitter("FxShard", {
		Color = palette,
		LightInfluence = 0,
		LightEmission = 0.2,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.4) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(12, 24),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -60, 0),
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-400, 400),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Rate = 0,
		Parent = holder,
	})
	shards:Emit(count)
	-- A few big slow slabs for weight.
	local slabs = shards:Clone()
	slabs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.4) })
	slabs.Speed = NumberRange.new(4, 9)
	slabs.Parent = holder
	slabs:Emit(6)
	Debris:AddItem(holder, 2)
end

-- A chalk outline of a body on the ground under a point, fading after `seconds`.
function DeathFx.chalk(position: Vector3, size: number?, colour: Color3?, seconds: number?)
	local texture = Assets.texture("FxChalk")
	if texture == "" then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The floor, not bodies or effects.
	local ignore: { Instance } = { workspace.CurrentCamera }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end
	local s = size or 6
	local helper = if math.abs(hit.Normal.Y) > 0.9 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = hit.Normal:Cross(helper).Unit
	local plate = Create("Part", {
		Name = "DeathChalk",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(s, 0.05, s),
		CFrame = CFrame.fromMatrix(hit.Position + hit.Normal * 0.03, right, hit.Normal)
			* CFrame.Angles(0, math.random() * math.pi * 2, 0),
		Parent = workspace.CurrentCamera,
	})
	local decal = Create("Decal", {
		Face = Enum.NormalId.Top,
		Texture = texture,
		Color3 = colour or DeathFx.CHALK,
		Transparency = 1,
		Parent = plate,
	})
	-- It cuts in with a few hard flickers, then stays and fades away.
	task.spawn(function()
		for _, shown in ipairs({ 0, 1, 0, 1, 0.15 }) do
			if not decal.Parent then
				return
			end
			decal.Transparency = shown
			task.wait(0.05)
		end
	end)
	task.delay(seconds or 10, function()
		if decal.Parent then
			local fade = TweenService:Create(decal, TweenInfo.new(2), { Transparency = 1 })
			fade:Play()
			fade.Completed:Once(function()
				plate:Destroy()
			end)
		end
	end)
end

-- Static rising off a character while it fades (voted out).
function DeathFx.dissolve(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local noise = emitter("FxStatic", {
		Color = ColorSequence.new(DeathFx.CHALK),
		LightInfluence = 0,
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		Rate = 60,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Parent = root,
	})
	task.delay(seconds, function()
		noise.Enabled = false
		Debris:AddItem(noise, 1.5)
	end)
end

-- A spray of sparks (handcuffs clicking shut, Death's Manual landing).
function DeathFx.sparks(position: Vector3, colour: Color3?)
	local holder = anchorPart(position)
	local sparks = emitter("Spark", {
		Color = ColorSequence.new(colour or C.white),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0),
		Rate = 0,
		Parent = holder,
	})
	sparks:Emit(24)
	Debris:AddItem(holder, 1)
end

-- Your own screen when you are taken out: a steady dark red wash that fades after `seconds`. (Nothing in a
-- match glitches, so there is no tear.)
function DeathFx.screenTear(seconds: number?, colour: Color3?)
	local layer = Instance.new("CanvasGroup")
	layer.Name = "DeathWash"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = Screens.cinematic
	Kit.Base.make("Frame", {
		Name = "Wash",
		BackgroundColor3 = colour or C.blood,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = layer,
	})
	Motion.fade(layer, true, 0.2)
	task.delay(seconds or 2.5, function()
		local fade = Motion.fade(layer, false, 1.2)
		if fade then
			fade.Completed:Once(function()
				layer:Destroy()
			end)
		else
			layer:Destroy()
		end
	end)
end

return DeathFx
