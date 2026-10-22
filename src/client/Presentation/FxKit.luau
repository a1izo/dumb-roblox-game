-- The FX kit (after the owner's tutorial, 2026-10-22: stylised effects are plain shapes grown and faded on a
-- curve, with a noise cut into hard steps): a shockwave dome, a ring, a crescent slash or a spike burst (the Core
-- set's FxDome, FxRing, FxCrescent, FxSpikes: art/scripts/props_fx.py; plain parts before the set is imported)
-- grown from small to its size on an eased curve, held, and faded, tinted and glowing; and a hard-edged puff (the
-- Core set's FxPuff, a 4 x 4 flipbook baked in art/scripts/textures.py). Made on this client only, in the camera,
-- and gone when done. Nothing under Reduce motion or on low graphics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)

local FxKit = {}

export type Kind = "dome" | "ring" | "crescent" | "spikes"
export type Options = {
	size: number, -- studs across at its full size
	seconds: number?, -- to grow (0.45 by default)
	hold: number?, -- at full size before it fades (0 by default)
	fade: number?, -- to fade out (as long as it grows by default)
	color: Color3?,
	material: Enum.Material?, -- Neon (by default) or ForceField
	transparency: number?, -- how see-through at its strongest (0.25 by default)
	from: number?, -- the part of its size it starts at (0.1 by default)
	ease: Enum.EasingStyle?, -- the curve it grows on (Quint by default: fast, then settling)
	spin: number?, -- degrees it turns about its up while it grows
}

local KEYS: { [Kind]: string } = { dome = "FxDome", ring = "FxRing", crescent = "FxCrescent", spikes = "FxSpikes" }

local function quiet(): boolean
	return Motion.isReduced() or Governor.low("emoteFx")
end

-- A shape made white and plain (its texture taken off) so it takes the colour and the glow.
local function bare(model: Model, color: Color3, material: Enum.Material)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("SurfaceAppearance") or item:IsA("Decal") or item:IsA("Texture") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			if item:IsA("MeshPart") then
				item.TextureID = ""
			end
			item.Color = color
			item.Material = material
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
		end
	end
end

-- The stand-in shapes before the Core set has the kit's: two studs across like the models.
local function standIn(kind: Kind): Model
	local model = Create("Model", { Name = KEYS[kind] }) :: Model
	local function piece(size: Vector3, cf: CFrame, shape: Enum.PartType?): BasePart
		local p = Create("Part", { Size = size, CFrame = cf, Parent = model }) :: BasePart
		if shape then
			(p :: Part).Shape = shape
		end
		return p
	end
	if kind == "dome" then
		piece(Vector3.new(2, 2, 2), CFrame.new(), Enum.PartType.Ball)
	elseif kind == "ring" then
		piece(Vector3.new(0.05, 2, 2), CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	elseif kind == "crescent" then
		piece(Vector3.new(1.9, 0.04, 0.3), CFrame.new())
	else
		for k = 0, 5 do
			piece(Vector3.new(1, 0.08, 0.08), CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0.5, 0, 0))
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Grows a shape at `at` (its up the shape's up) on its curve, holds it and fades it. Returns how long it takes.
function FxKit.shape(kind: Kind, at: CFrame, options: Options): number
	if quiet() then
		return 0
	end
	local color = options.color or Color3.fromRGB(240, 240, 236)
	local material = options.material or Enum.Material.Neon
	local model = ModelLibrary.get(KEYS[kind]) or standIn(kind)
	bare(model, color, material)
	model.Name = "FxKit_" .. kind
	local _, box = model:GetBoundingBox()
	local across = math.max(box.X, box.Z, 0.01)
	local base = model:GetScale() / across -- (the scale at which it is one stud across)
	local seconds = options.seconds or 0.45
	local hold = options.hold or 0
	local fade = options.fade or seconds
	local from = options.from or 0.1
	local strongest = options.transparency or 0.25
	local spin = math.rad(options.spin or 0)
	local parts: { BasePart } = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Transparency = strongest
			table.insert(parts, item)
		end
	end
	model:ScaleTo(base * options.size * from)
	model:PivotTo(at)
	model.Parent = workspace.CurrentCamera
	local grow = Instance.new("NumberValue")
	grow.Changed:Connect(function(t: number)
		if model.Parent then
			model:ScaleTo(math.max(1e-3, base * options.size * (from + (1 - from) * t)))
			model:PivotTo(at * CFrame.Angles(0, spin * t, 0))
		end
	end)
	TweenService
		:Create(grow, TweenInfo.new(seconds, options.ease or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Value = 1,
		})
		:Play()
	local info = TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, hold + seconds * 0.35)
	for _, part in ipairs(parts) do
		TweenService:Create(part, info, { Transparency = 1 }):Play()
	end
	local total = hold + seconds * 0.35 + fade
	task.delay(total + 0.05, function()
		grow:Destroy()
		model:Destroy()
	end)
	return total
end

-- A hard-edged puff (or `count` of them) at a point: smoke, dust or light breaking up as it goes.
function FxKit.puff(at: Vector3, size: number, color: Color3?, count: number?, glow: number?)
	if quiet() then
		return
	end
	local holder = Create("Part", {
		Name = "FxKit_puff",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	local texture = Assets.texture("FxPuff")
	local emitter = Create("ParticleEmitter", {
		Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(color or Color3.fromRGB(150, 146, 142)),
		LightEmission = glow or 0,
		LightInfluence = if glow then 0 else 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) }),
		Lifetime = NumberRange.new(0.55, 0.8),
		Speed = NumberRange.new(size * 0.6, size * 1.4),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		Rate = 0,
		Parent = holder,
	}) :: ParticleEmitter
	if texture ~= "" then
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	else
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	end
	emitter:Emit(count or 6)
	task.delay(1.0, function()
		holder:Destroy()
	end)
end

-- A crater of rocks round an impact (the tutorials' rock module): `count` stones in a ring `radius` studs out,
-- popping up tipped outwards, then sinking back and gone.
function FxKit.rocks(at: Vector3, radius: number, count: number?, color: Color3?)
	if quiet() then
		return
	end
	local n = count or 10
	local random = Random.new()
	for k = 1, n do
		local a = (k + random:NextNumber(-0.3, 0.3)) / n * math.pi * 2
		local size = radius * random:NextNumber(0.18, 0.3)
		local spot = at + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local out = CFrame.lookAt(spot, spot + Vector3.new(math.cos(a), 0, math.sin(a)))
		local up = out
			* CFrame.new(0, size * 0.3, 0)
			* CFrame.Angles(math.rad(random:NextNumber(25, 45)), 0, math.rad(random:NextNumber(-15, 15)))
		local stone = Create("Part", {
			Name = "FxKit_rock",
			Size = Vector3.new(size, size * 0.8, size * 1.1),
			CFrame = up * CFrame.new(0, -size, 0),
			Color = color or Color3.fromRGB(96, 92, 88),
			Material = Enum.Material.Slate,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = workspace.CurrentCamera,
		}) :: BasePart
		TweenService
			:Create(stone, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up })
			:Play()
		task.delay(1.1 + random:NextNumber(0, 0.3), function()
			TweenService:Create(stone, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = up * CFrame.new(0, -size * 1.2, 0),
				Transparency = 1,
			}):Play()
		end)
		task.delay(2.2, function()
			stone:Destroy()
		end)
	end
end

-- A flash of light at an impact, out again over `seconds`.
function FxKit.light(at: Vector3, color: Color3, range: number, brightness: number, seconds: number?)
	if quiet() then
		return
	end
	local holder = Create("Part", {
		Name = "FxKit_light",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	local light = Create(
		"PointLight",
		{ Color = color, Range = range, Brightness = brightness, Shadows = false, Parent = holder }
	)
	TweenService:Create(light, TweenInfo.new(seconds or 0.5, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	task.delay((seconds or 0.5) + 0.1, function()
		holder:Destroy()
	end)
end

return FxKit
