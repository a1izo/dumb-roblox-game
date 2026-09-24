-- Ink effects, local to this client: bursts of ink drops, splats on the floor that fade, ink
-- wisps rising off a body, sparks, and an ink-splattered overlay on your own screen when you
-- are taken out. Textures come from Blender (Assets.texture); without them the effects that
-- need a shape are skipped and bursts use Roblox's default particle.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)

local InkFx = {}

InkFx.INK = Color3.fromRGB(12, 10, 14)
InkFx.BLOOD_INK = Color3.fromRGB(70, 6, 14)

local SPLATS = { "InkSplat1", "InkSplat2", "InkSplat3" }

local function anchorPart(position: Vector3): Part
	return Create("Part", {
		Name = "InkFx",
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

local function randomSplat(): string
	return Assets.texture(SPLATS[math.random(1, #SPLATS)])
end

-- A particle emitter with a Blender texture when there is one (Roblox's default otherwise).
local function emitter(textureName: string, props: { [string]: any }): ParticleEmitter
	local texture = if textureName == "splat" then randomSplat() else Assets.texture(textureName)
	if texture ~= "" then
		props.Texture = texture
	end
	return Create("ParticleEmitter", props)
end

-- A burst of ink drops flung out from a point.
function InkFx.burst(position: Vector3, colour: Color3?, amount: number?)
	local holder = anchorPart(position)
	local drops = emitter("InkDrop", {
		Color = ColorSequence.new(colour or InkFx.INK),
		LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.15) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.4) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(12, 24),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -60, 0),
		Drag = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 0,
		Parent = holder,
	})
	drops:Emit(amount or 36)
	-- A few big blobs for weight.
	local blobs = drops:Clone()
	local splatTexture = randomSplat()
	if splatTexture ~= "" then
		blobs.Texture = splatTexture
	end
	blobs.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.4) })
	blobs.Speed = NumberRange.new(4, 9)
	blobs.Orientation = Enum.ParticleOrientation.FacingCamera
	blobs.Rotation = NumberRange.new(0, 360)
	blobs.Parent = holder
	blobs:Emit(6)
	Debris:AddItem(holder, 2)
end

-- An ink splat on the ground under a point, fading after `seconds`.
function InkFx.splat(position: Vector3, size: number?, colour: Color3?, seconds: number?)
	local texture = randomSplat()
	if texture == "" then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace.CurrentCamera }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end
	local s = size or 6
	local helper = if math.abs(hit.Normal.Y) > 0.9 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = hit.Normal:Cross(helper).Unit
	local plate = Create("Part", {
		Name = "InkSplat",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.5, 0.05, 0.5),
		CFrame = CFrame.fromMatrix(hit.Position + hit.Normal * 0.03, right, hit.Normal)
			* CFrame.Angles(0, math.random() * math.pi * 2, 0),
		Parent = workspace.CurrentCamera,
	})
	local decal = Create("Decal", {
		Face = Enum.NormalId.Top,
		Texture = texture,
		Color3 = colour or InkFx.INK,
		Transparency = 0,
		Parent = plate,
	})
	-- The splat spreads out quickly, then soaks away.
	TweenService:Create(plate, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(s, 0.05, s),
	}):Play()
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

-- Ink wisps rising off a character while it fades (voted out).
function InkFx.dissolve(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local wisps = emitter("Smoke", {
		Color = ColorSequence.new(InkFx.INK),
		LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 60,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Parent = root,
	})
	task.delay(seconds, function()
		wisps.Enabled = false
		Debris:AddItem(wisps, 1.5)
	end)
end

-- A spray of sparks (handcuffs clicking shut, the Grimoire landing).
function InkFx.sparks(position: Vector3, colour: Color3?)
	local holder = anchorPart(position)
	local sparks = emitter("Spark", {
		Color = ColorSequence.new(colour or Color3.fromRGB(255, 230, 190)),
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

-- Ink splattered across your own screen (you were taken out). Fades after `seconds`.
function InkFx.screenSplat(seconds: number?, colour: Color3?)
	local layer = Instance.new("CanvasGroup")
	layer.Name = "InkScreen"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = Screens.cinematic
	local spots = {
		{ 0.18, 0.22, 0.55 },
		{ 0.82, 0.3, 0.45 },
		{ 0.5, 0.85, 0.6 },
		{ 0.12, 0.8, 0.35 },
		{ 0.9, 0.78, 0.4 },
	}
	for index, spot in ipairs(spots) do
		local texture = randomSplat()
		if texture ~= "" then
			local image = Create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = texture,
				ImageColor3 = colour or InkFx.INK,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(spot[1], spot[2]),
				Size = UDim2.fromScale(spot[3], spot[3]),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Rotation = math.random(0, 359),
				Parent = layer,
			})
			local scale = Instance.new("UIScale")
			scale.Scale = if Motion.isReduced() then 1 else 0.2
			scale.Parent = image
			task.delay((index - 1) * 0.05, function()
				Motion.tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
			end)
		end
	end
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

return InkFx
