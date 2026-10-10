-- Puts a scene made in Blender into a venue: the lobby, the meeting room and every map (Tokyo,
-- Agency HQ, the University Campus) each have an FBX of their own, art/export/DeathsGambitMaps_<Venue>.fbx
-- (imported with Studio's 3D importer), with its meshes named Map_<Venue>_<Material>_<n>, and scene
-- data in Maps/Scenes/<Venue>/: invisible colliders where the walls and furniture are, props from
-- the prop library, lights, signs, particle emitters, the gameplay layout, and anchors where the
-- venue's own Luau builds what shows text or does something (the lobby's boards, the meeting
-- room's screen and seats). A venue always builds: as the imported scene or, without the import
-- (or with an older one), as a playable greybox (see buildFormat2 below).
--
-- The importer may scale or turn what it imports. Three calibration cubes in the same file
-- (Calib_<Venue>_O at the origin, _X 64 studs along x, _Y 64 studs up) tell how, so every mesh
-- lands exactly where it was made.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local SceneMaterials = require(Shared:WaitForChild("SceneMaterials"))

local Scenes = script.Parent:WaitForChild("Scenes")

local SceneBuilder = {}

-- Set from the debug panel to build every venue as its greybox instead (to compare them).
SceneBuilder.disabled = false

-- Tag on the colliders the camera cannot pass through (see client World/CameraCollision).
SceneBuilder.CAMERA_TAG = "LCameraBlock"
-- Emergency lamps (off until the map's blackout; the client lights them, World/Blackout).
SceneBuilder.EMERGENCY_TAG = "LMapEmergency"

local function dress(part: BasePart, material: string)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local look = (SceneMaterials :: any)[material]
	if not look or look.textured then
		part.CastShadow = true
		return
	end
	local enum = (Enum.Material :: any)[look.material] or Enum.Material.SmoothPlastic
	part.Material = enum
	part.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	part.Transparency = look.transparency or 0
	part.Reflectance = look.reflectance or 0
	part.CastShadow = enum ~= Enum.Material.Neon and enum ~= Enum.Material.Glass
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
	if part:IsA("MeshPart") then
		pcall(function()
			(part :: MeshPart).TextureID = ""
		end)
	end
end

local function color(values: { number }?): Color3?
	return if values then Color3.fromRGB(values[1], values[2], values[3]) else nil
end

-- A light in an invisible anchor inside its fixture. When the fixture itself is not there (a
-- greybox, or a prop that is not imported) the anchor shows as a small glowing fixture, so no
-- light ever hangs in mid-air.
local function addLight(b, folder: Instance, spec, showFixture: boolean?, where: CFrame?)
	local at = spec.at
	local anchor = Create("Part", {
		Name = "Light",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = if showFixture then 0 else 1,
		Material = Enum.Material.Neon,
		Color = color(spec.color) :: Color3,
		Size = if showFixture then Vector3.new(0.8, 0.8, 0.8) else Vector3.new(0.2, 0.2, 0.2),
		CFrame = where or b:world(CFrame.new(at[1], at[2], at[3])),
		Parent = folder,
	})
	local light
	if spec.kind == "spot" then
		light = Create("SpotLight", {
			Face = (Enum.NormalId :: any)[spec.face] or Enum.NormalId.Bottom,
			Angle = spec.angle,
		})
	else
		light = Instance.new("PointLight")
	end
	light.Color = color(spec.color) :: Color3
	light.Range = spec.range
	light.Brightness = spec.brightness
	light.Shadows = spec.shadows
	light.Parent = anchor
	if spec.flicker then
		CollectionService:AddTag(anchor, "LFlicker")
	end
	if spec.role == "emergency" then
		-- An emergency lamp: off until the map's blackout (the client lights it, World/Blackout).
		light.Enabled = false
		CollectionService:AddTag(anchor, SceneBuilder.EMERGENCY_TAG)
	end
end

local function addSign(b, spec)
	local at = spec.at
	local bg = color(spec.bg)
	local board, label = b:sign(
		at[1],
		at[2],
		at[3],
		spec.rot,
		spec.w,
		spec.h,
		spec.text,
		color(spec.color) :: Color3,
		bg or Color3.new(0, 0, 0),
		(Enum.Font :: any)[spec.font] or Enum.Font.GothamBlack
	)
	board.CanCollide = false
	board.CanQuery = false
	board.CastShadow = false
	if not bg then
		board.Transparency = 1
	end
	label.TextXAlignment = (Enum.TextXAlignment :: any)[spec.align] or Enum.TextXAlignment.Center
	if spec.glow then
		Create("SurfaceLight", {
			Face = Enum.NormalId.Front,
			Color = color(spec.glow),
			Range = 10,
			Brightness = 1.2,
			Angle = 120,
			Parent = board,
		})
	end
end

-- Marks a mist, cloud or dust emitter so the client can thin it on slower devices (it keeps the
-- rate it was built with in BaseRate).
local function fogged(emitter: ParticleEmitter): ParticleEmitter
	emitter:SetAttribute("BaseRate", emitter.Rate)
	CollectionService:AddTag(emitter, SceneBuilder.FOG_TAG)
	return emitter
end

local function addEmitter(b, folder: Instance, spec)
	local at = spec.at
	local anchor = Create("Part", {
		Name = "Emitter",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(1, 0.2, 1),
		CFrame = b:world(CFrame.new(at[1], at[2], at[3])),
		Parent = folder,
	}) :: BasePart
	if spec.kind == "fountain" then
		Create("ParticleEmitter", {
			EmissionDirection = Enum.NormalId.Top,
			Rate = 40,
			Lifetime = NumberRange.new(0.9, 1.3),
			Speed = NumberRange.new(9, 11),
			SpreadAngle = Vector2.new(8, 8),
			Acceleration = Vector3.new(0, -24, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.6) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0.9),
			}),
			Color = ColorSequence.new(Color3.fromRGB(190, 220, 255)),
			LightEmission = 0.3,
			Parent = anchor,
		})
	elseif spec.kind == "steam" then
		local steam = Create("ParticleEmitter", {
			EmissionDirection = Enum.NormalId.Top,
			Rate = 6,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(12, 12),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(200, 200, 210)),
			LightInfluence = 1,
			RotSpeed = NumberRange.new(-20, 20),
			Parent = anchor,
		})
		local texture = Assets.texture("Smoke")
		if texture ~= "" then
			steam.Texture = texture
		end
	elseif spec.kind == "rivermist" then
		-- A low, slow mist lying on the water (or pooling in an alley), drifting along. A map may give
		-- it a box of its own (spec.size); the rate follows the ground it covers.
		local box = if spec.size
			then Vector3.new(spec.size[1], spec.size[2], spec.size[3])
			else Vector3.new(30, 0.2, 18)
		anchor.Size = box
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Smoke")
		local mist = Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = if spec.size then math.max(1.5, box.X * box.Z * 0.0045) else 3,
			Lifetime = NumberRange.new(8, 12),
			Speed = NumberRange.new(0.2, 0.6),
			Acceleration = Vector3.new(0.4, 0, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.86),
				NumberSequenceKeypoint.new(0.7, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(150, 146, 180)),
			LightInfluence = 1,
			LightEmission = 0,
			RotSpeed = NumberRange.new(-6, 6),
			Rotation = NumberRange.new(0, 360),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		})
		fogged(mist)
	elseif spec.kind == "petals" then
		-- Sakura petals drifting down from the trees over the promenade and onto the water.
		anchor.Size = Vector3.new(34, 0.2, 10)
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		-- A petal's shape when the map brought its texture in (else Roblox's default spark).
		local petal = Assets.texture("TokyoPetal")
		local petals = Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 4,
			Lifetime = NumberRange.new(6, 9),
			Speed = NumberRange.new(0.5, 1.2),
			Acceleration = Vector3.new(0.6, -0.9, 0.3),
			Drag = 0.6,
			SpreadAngle = Vector2.new(35, 35),
			Size = NumberSequence.new(0.18),
			Squash = NumberSequence.new(0.5),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.1),
				NumberSequenceKeypoint.new(0.85, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 196, 214), Color3.fromRGB(246, 168, 196)),
			LightInfluence = 1,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Parent = anchor,
		})
		if petal ~= "" then
			petals.Texture = petal
			petals.Size = NumberSequence.new(0.3)
			petals.Squash = NumberSequence.new(0)
		end
	elseif spec.kind == "branchsnow" then
		-- Snow slipping off a tree's branches: nothing until the client shakes a clump loose now and
		-- then (World/MapAmbient calls Emit on it), then a short fall of flakes and powder.
		local size = if spec.size then Vector3.new(spec.size[1], spec.size[2], spec.size[3]) else Vector3.new(8, 1, 8)
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Snowflake")
		local fall = Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 0,
			Lifetime = NumberRange.new(1.4, 2.2),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0.6, -14, 0.3),
			Drag = 1.2,
			SpreadAngle = Vector2.new(20, 20),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3, 0.12),
				NumberSequenceKeypoint.new(1, 0.5, 0.2),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(240, 244, 252)),
			LightInfluence = 0.8,
			LightEmission = 0.1,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		})
		-- How many flakes one clump makes, for the size of the tree.
		fall:SetAttribute("Burst", math.floor(size.X * size.Z * 0.4))
		CollectionService:AddTag(fall, SceneBuilder.BRANCH_SNOW_TAG)
	elseif spec.kind == "windowrain" and spec.size then
		-- Rain running down the outside of a tower's glass: drops sliding down a band the size of
		-- the window, just outside it. The client thins it on slower devices (World/MapAmbient).
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local rain = Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = size.X * 0.3,
			Lifetime = NumberRange.new(1.6, 3.0),
			Speed = NumberRange.new(2, 5),
			Acceleration = Vector3.new(0, -3, 0),
			SpreadAngle = Vector2.new(0, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.07) }),
			Squash = NumberSequence.new(1.5),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.55),
				NumberSequenceKeypoint.new(0.8, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(190, 205, 230)),
			LightInfluence = 0.4,
			LightEmission = 0.25,
			Parent = anchor,
		})
		local texture = Assets.texture("RainStreak")
		if texture ~= "" then
			rain.Texture = texture
		end
		rain:SetAttribute("BaseRate", rain.Rate)
		CollectionService:AddTag(rain, SceneBuilder.RAIN_GLASS_TAG)
	elseif spec.kind == "ash" and spec.size then
		-- The Grey Realm's ash: flakes drifting sideways through a big box over the plain, slowly
		-- settling, never quite reaching the ground.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Snowflake")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = size.X * size.Z / 2400,
			Lifetime = NumberRange.new(9, 14),
			Speed = NumberRange.new(0.3, 0.9),
			Acceleration = Vector3.new(1.4, -0.35, 0.5),
			Drag = 0.4,
			SpreadAngle = Vector2.new(40, 40),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14, 0.06), NumberSequenceKeypoint.new(1, 0.1) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.35),
				NumberSequenceKeypoint.new(0.85, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(96, 96, 100), Color3.fromRGB(150, 150, 154)),
			LightInfluence = 1,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		}))
	elseif spec.kind == "riftwisp" and spec.size then
		-- Pale motes rising out of the rift and fading as they clear its rim.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("SoulGlow")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 5,
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(0.8, 1.8),
			Acceleration = Vector3.new(0, 0.4, 0),
			SpreadAngle = Vector2.new(25, 25),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(170, 205, 255)),
			LightEmission = 0.8,
			LightInfluence = 0,
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/sparkles_main.dds",
			Parent = anchor,
		}))
	elseif (spec.kind == "realmcloud" or spec.kind == "realmhaze") and spec.size then
		-- The Grey Realm's cloud layers: huge slow grey sprites in a wide, flat box. They take the scene's
		-- light, so the sky's slow breathing (World/RealmSky) darkens and lightens them with everything
		-- else. "realmcloud" is the sea under the island and the dark banks on the horizon; "realmhaze"
		-- the pale, thin layers high above. Thinned on weak devices like every cloud emitter.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Smoke")
		local sea = spec.kind == "realmcloud"
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = math.max(0.6, size.X * size.Z / (if sea then 1400000 else 2200000)),
			Lifetime = NumberRange.new(40, 56),
			Speed = NumberRange.new(0.2, 0.8),
			Acceleration = Vector3.new(if sea then 0.12 else 0.18, 0, if sea then 0.04 else 0.06),
			Drag = 0.06,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, if sea then 260 else 380),
				NumberSequenceKeypoint.new(1, if sea then 340 else 520),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.22, if sea then 0.5 else 0.84),
				NumberSequenceKeypoint.new(0.78, if sea then 0.54 else 0.86),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = if sea
				then ColorSequence.new(Color3.fromRGB(120, 126, 140), Color3.fromRGB(190, 196, 208))
				else ColorSequence.new(Color3.fromRGB(84, 88, 98), Color3.fromRGB(170, 174, 186)),
			LightInfluence = if sea then 0.5 else 0.6,
			LightEmission = if sea then 0.3 else 0.15,
			RotSpeed = NumberRange.new(-1, 1),
			Rotation = NumberRange.new(0, 360),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		}))
	elseif spec.kind == "mist" and spec.size then
		-- Cold ground mist: big soft sprites lying low over a patch of ground, thinning with height,
		-- lit by the lamps they pass (the campus lawns, the tower's atrium).
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Smoke")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = math.max(1.5, size.X * size.Z * 0.0035),
			Lifetime = NumberRange.new(10, 15),
			Speed = NumberRange.new(0.15, 0.45),
			Acceleration = Vector3.new(0.35, 0.02, 0.15),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 17) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.87),
				NumberSequenceKeypoint.new(0.75, 0.89),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(152, 164, 190)),
			LightInfluence = 1,
			LightEmission = 0,
			RotSpeed = NumberRange.new(-5, 5),
			Rotation = NumberRange.new(0, 360),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		}))
	elseif spec.kind == "cloudsea" and spec.size then
		-- A sea of cloud far below the tower windows: huge slow sprites in a wide flat box, the
		-- glow of the city showing through them.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Smoke")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = math.max(1, size.X * size.Z / 90000),
			Lifetime = NumberRange.new(34, 48),
			Speed = NumberRange.new(0.8, 2.2),
			Acceleration = Vector3.new(1.0, 0, 0.3),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 170), NumberSequenceKeypoint.new(1, 230) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.8),
				NumberSequenceKeypoint.new(0.8, 0.82),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(104, 108, 148), Color3.fromRGB(138, 130, 170)),
			LightInfluence = 0.25,
			LightEmission = 0.12,
			RotSpeed = NumberRange.new(-1.5, 1.5),
			Rotation = NumberRange.new(0, 360),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		}))
	elseif spec.kind == "dust" and spec.size then
		-- Dust motes hanging in the light of a tall room: tiny warm specks that barely move.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local texture = Assets.texture("Snowflake")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Rate = math.max(1, size.X * size.Y * size.Z / 2200),
			Lifetime = NumberRange.new(9, 14),
			Speed = NumberRange.new(0.03, 0.18),
			Acceleration = Vector3.new(0.02, 0.01, 0.015),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1, 0.04),
				NumberSequenceKeypoint.new(1, 0.1, 0.04),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.38),
				NumberSequenceKeypoint.new(0.8, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 232, 196)),
			LightInfluence = 0,
			LightEmission = 0.7,
			Rotation = NumberRange.new(0, 360),
			Texture = if texture ~= "" then texture else "rbxasset://textures/particles/sparkles_main.dds",
			Parent = anchor,
		}))
	elseif spec.kind == "feathers" and spec.size then
		-- Now and then a single black feather turning slowly down through the snow.
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		anchor.Size = size
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		local feather = Assets.texture("Feather")
		fogged(Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 0.14,
			Lifetime = NumberRange.new(14, 18),
			Speed = NumberRange.new(0.7, 1.2),
			Acceleration = Vector3.new(0.3, -0.15, 0.22),
			Drag = 0.5,
			SpreadAngle = Vector2.new(20, 20),
			Size = NumberSequence.new(if feather ~= "" then 1.1 else 0.45),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0.05),
				NumberSequenceKeypoint.new(0.88, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(20, 20, 26)),
			LightInfluence = 1,
			LightEmission = 0,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-45, 45),
			Texture = if feather ~= "" then feather else "rbxasset://textures/particles/smoke_main.dds",
			Parent = anchor,
		}))
	elseif (spec.kind == "traffic_tail" or spec.kind == "traffic_head") and spec.size then
		-- Car lights streaming down a road far below: particles sent along it from its start (the
		-- anchor faces the way the traffic runs; size z is how far the road goes).
		local width, length = spec.size[1], spec.size[3]
		local speed = 60
		anchor.Size = Vector3.new(width, 0.2, 0.2)
		anchor.CFrame = b:world(b:cf(at[1], at[2], at[3], spec.rot))
		Create("ParticleEmitter", {
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Front,
			Rate = 3,
			Lifetime = NumberRange.new(length / speed, length / speed),
			Speed = NumberRange.new(speed, speed),
			SpreadAngle = Vector2.new(0, 0),
			Size = NumberSequence.new(2.4),
			Transparency = NumberSequence.new(0.1),
			Color = ColorSequence.new(
				if spec.kind == "traffic_tail" then Color3.fromRGB(255, 60, 50) else Color3.fromRGB(255, 236, 200)
			),
			LightEmission = 1,
			LightInfluence = 0,
			Parent = anchor,
		})
	end
end

-- Terrain water (a river's channel): filled when a big venue builds, cleared when its map goes.
-- The water's look is set here, the same for every map that has any.
local filledWater: { { cf: CFrame, size: Vector3 } } = {}

local function fillWater(b, boxes)
	if #boxes == 0 then
		return
	end
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(22, 40, 52)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.9
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	for _, w in ipairs(boxes) do
		local cf = b:world(b:cf(w.at[1], w.at[2], w.at[3], w.rot))
		local size = Vector3.new(w.size[1], w.size[2], w.size[3])
		terrain:FillBlock(cf, size, Enum.Material.Water)
		table.insert(filledWater, { cf = cf, size = size })
	end
end

-- Takes away the water the last build filled in (MapService, when it tears a map down).
function SceneBuilder.clearWater()
	for _, w in ipairs(filledWater) do
		-- A little bigger, so no half-full voxel is left behind at the edges.
		workspace.Terrain:FillBlock(w.cf, w.size + Vector3.new(8, 8, 8), Enum.Material.Air)
	end
	table.clear(filledWater)
end

-- Building a venue ---------------------------------------------------------------------------------
-- Its scene data (Scenes/<Venue>/) holds everything, gameplay spots and anchors included, and each
-- venue has an FBX of its own (DeathsGambitMaps_<Venue>.fbx). Without that import, or with an older
-- one, the venue is built as a greybox: the colliders shown in their materials' colours, so it is
-- complete and playable, just plain.

local function lookOf(name: string?): (Enum.Material, Color3, number)
	local look = if name then (SceneMaterials :: any)[name] else nil
	if not look then
		return Enum.Material.Concrete, Color3.fromRGB(118, 118, 124), 0
	end
	if look.textured then
		local fallback = look.fallback
		return (Enum.Material :: any)[fallback.material] or Enum.Material.Concrete,
			Color3.fromRGB(fallback.color[1], fallback.color[2], fallback.color[3]),
			0
	end
	return (Enum.Material :: any)[look.material] or Enum.Material.SmoothPlastic,
		Color3.fromRGB(look.color[1], look.color[2], look.color[3]),
		look.transparency or 0
end

-- A solid part that shows in greybox mode in its look, and is invisible otherwise.
local function solid(part: BasePart, look: string?, greybox: boolean, query: boolean)
	part.Anchored = true
	part.CanQuery = query
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if greybox and look then
		local material, colour, transparency = lookOf(look)
		part.Material = material
		part.Color = colour
		-- Solid glass stays a little see-through at most: it blocks sight lines like the wall it
		-- is (MapContract only lets clearly see-through glass block nothing).
		part.Transparency = if query then math.min(transparency, 0.25) else transparency
		part.CastShadow = transparency < 0.3
	else
		part.Transparency = 1
	end
end

-- Two wedges filling the triangle a, b, c (a plane), `thickness` thick across it.
local function triangle(folder: Instance, a: Vector3, b: Vector3, c: Vector3, thickness: number): { WedgePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return {}
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local made = {}
	for index = 1, 2 do
		local depth = if index == 1 then math.abs(ab:Dot(back)) else math.abs(ac:Dot(back))
		if height < 0.02 or depth < 0.02 then
			continue
		end
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Floor"
		wedge.Size = Vector3.new(thickness, height, depth)
		if index == 1 then
			wedge.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
		else
			wedge.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
		end
		wedge.Parent = folder
		table.insert(made, wedge)
	end
	return made
end

-- Ground zones painted in greybox mode (thin, not solid), so streets read as streets.
local ZONE_PAINT: { [string]: Color3 } = {
	road = Color3.fromRGB(40, 40, 44),
	crossing = Color3.fromRGB(66, 66, 72),
	water = Color3.fromRGB(40, 90, 120),
	arcade = Color3.fromRGB(150, 146, 140),
	park = Color3.fromRGB(56, 84, 48),
	sidewalk = Color3.fromRGB(104, 104, 108),
}

local function paintZones(b, folder: Instance, zones)
	for _, zone in ipairs(zones) do
		local colour = ZONE_PAINT[zone.kind]
		if not colour then
			continue
		end
		local points = zone.points
		local y = zone.y0 + 0.04
		local first = b:worldPos(points[1], y, points[2])
		for index = 3, #points - 3, 2 do
			local p = b:worldPos(points[index], y, points[index + 1])
			local q = b:worldPos(points[index + 2], y, points[index + 3])
			for _, wedge in ipairs(triangle(folder, first, p, q, 0.05)) do
				wedge.Anchored = true
				wedge.CanCollide = false
				wedge.CanQuery = false
				wedge.CanTouch = false
				wedge.CastShadow = false
				wedge.Material = Enum.Material.SmoothPlastic
				wedge.Color = colour
			end
		end
	end
end

-- The prop's catalog entry, for its stand-in box when it is not imported.
local Catalog = require(Shared:WaitForChild("ModelCatalog")) :: any

local function standIn(b, folder: Instance, p)
	local info = Catalog[p[1]]
	if not info or not info.collide then
		return
	end
	local scale = p[6] or 1
	local size = Vector3.new(info.size[1], info.size[2], info.size[3]) * scale
	local y = if info.pivot == "bottom" then p[3] + size.Y / 2 else p[3]
	local box = b:part(
		size,
		b:cf(p[2], y, p[4], p[5]),
		Color3.fromRGB(150, 150, 156),
		Enum.Material.SmoothPlastic,
		{ Name = "StandIn_" .. p[1], CanTouch = false, CastShadow = false, Parent = folder }
	)
	if info.color then
		box.Color = Color3.fromRGB(info.color[1], info.color[2], info.color[3])
	end
end

-- The lights a prop carries (its catalog lights, at their places in the prop), unless the map
-- placed it dark. Their anchors show as fixtures when the prop is only a stand-in.
local function propLights(b, folder: Instance, p, standIn: boolean)
	local info = Catalog[p[1]]
	if not info or not info.lights or p[7] == "dark" then
		return
	end
	local scale = p[6] or 1
	local base = b:world(b:cf(p[2], p[3], p[4], p[5]))
	for _, spec in ipairs(info.lights) do
		local where = base * CFrame.new(spec.at[1] * scale, spec.at[2] * scale, spec.at[3] * scale)
		addLight(b, folder, {
			kind = spec.kind,
			at = spec.at,
			color = spec.color,
			range = spec.range,
			brightness = spec.brightness,
			shadows = false,
			face = spec.face or "Bottom",
			angle = spec.angle or 90,
			flicker = spec.flicker == true,
		}, standIn, where)
	end
end

-- Tagged markers the clients bring to life (client World/MapAmbient): giant screens, ambient
-- sound sources, the metro train's run, snowy branches and a clock tower's hands; and boxes
-- where the client's LightingController switches to a look of their own (the metro under
-- Tokyo, the campus buildings).
SceneBuilder.SCREEN_TAG = "LMapScreen"
SceneBuilder.SOUND_TAG = "LMapSound"
SceneBuilder.TRAIN_TAG = "LMapTrain"
SceneBuilder.LOOK_TAG = "LLookZone"
-- Rain on a tower's glass (thinned by the client), aircraft lights that blink, and the searchlight
-- helicopter's flight past the windows.
SceneBuilder.RAIN_GLASS_TAG = "LMapRainGlass"
SceneBuilder.BLINK_TAG = "LMapBlink"
SceneBuilder.HELI_TAG = "LMapHeli"
-- Snow the client shakes off the branches, and a clock tower's hands (the client turns them).
SceneBuilder.BRANCH_SNOW_TAG = "LMapBranchSnow"
SceneBuilder.CLOCK_TAG = "LMapClock"
-- Boxes that shelter from rain and snow (client World/RainController, Weather/CoverIndex): an
-- awning, a tree's crown. Attribute Cover is how much they stop, 1 all, 0.5 half.
SceneBuilder.COVER_TAG = "LRainCover"
-- Mist, cloud and dust emitters the client thins on slower devices (World/MapAmbient); the
-- attribute BaseRate is the rate they were built with.
SceneBuilder.FOG_TAG = "LMapFog"
-- Rooms whose lights the client flickers now and then (World/MapAmbient).
SceneBuilder.FLICKER_TAG = "LMapFlicker"

-- An invisible box that stops the weather under it without being solid or showing: the client
-- finds it by its tag and does the arithmetic itself, so no ray ever meets it.
local function addCover(b, folder: Instance, spec)
	local part = Create("Part", {
		Name = "Cover",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3]),
		CFrame = b:world(b:cf(spec.at[1], spec.at[2], spec.at[3], spec.rot)),
		Parent = folder,
	}) :: BasePart
	part:SetAttribute("Cover", spec.amount or 1)
	CollectionService:AddTag(part, SceneBuilder.COVER_TAG)
end

-- A clock's two hands over its dial, made here and turned by the client (World/MapAmbient): a
-- model holding an invisible "Dial" (its front is the face) and the "Hour" and "Minute" hands.
-- Each hand turns about the dial's middle: at angle a (clockwise from twelve, seen from the
-- front) it stands at Dial * Angles(0, 0, a) * (0, Reach, -Lift), its attributes. Built showing
-- 23:00.
local HAND_COLOUR = Color3.fromRGB(18, 16, 16)

local function makeHand(
	dial: CFrame,
	name: string,
	length: number,
	width: number,
	angle: number,
	lift: number
): BasePart
	-- A short tail past the middle, the rest towards the rim.
	local reach = length / 2 - length * 0.12
	local hand = Create("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = HAND_COLOUR,
		Size = Vector3.new(width, length, 0.12),
		CFrame = dial * CFrame.Angles(0, 0, angle) * CFrame.new(0, reach, -lift),
	})
	hand:SetAttribute("Reach", reach)
	hand:SetAttribute("Lift", lift)
	return hand
end

-- The hour and minute hands over a dial of `radius`, showing `minutes` past midnight.
local function clockHands(dial: CFrame, radius: number, minutes: number): (BasePart, BasePart)
	local hours = (minutes / 60) % 12
	local hour = makeHand(dial, "Hour", radius * 0.58, radius * 0.1, hours / 12 * math.pi * 2, 0.18)
	local minute = makeHand(dial, "Minute", radius * 0.86, radius * 0.06, (minutes % 60) / 60 * math.pi * 2, 0.3)
	return hour, minute
end

-- "x,y,z;x,y,z;..." for a list of local points, in world space (attributes cannot hold lists).
local function encodePath(b, points: { { number } }): string
	local parts = {}
	for _, p in ipairs(points) do
		local w = b:worldPos(p[1], p[2], p[3])
		table.insert(parts, string.format("%.2f,%.2f,%.2f", w.X, w.Y, w.Z))
	end
	return table.concat(parts, ";")
end

local function addAmbience(b, folder: Instance, dressing)
	for _, spec in ipairs(dressing.screens or {}) do
		local screen = Create("Part", {
			Name = "Screen",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(10, 10, 14),
			Size = Vector3.new(spec.w, spec.h, 0.2),
			CFrame = b:world(b:cf(spec.at[1], spec.at[2], spec.at[3], spec.rot)),
			Parent = folder,
		})
		screen:SetAttribute("Loop", spec.loop)
		CollectionService:AddTag(screen, SceneBuilder.SCREEN_TAG)
	end
	for _, spec in ipairs(dressing.sounds or {}) do
		local source = Create("Part", {
			Name = "Sound_" .. spec.key,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = b:world(CFrame.new(spec.at[1], spec.at[2], spec.at[3])),
			Parent = folder,
		})
		source:SetAttribute("Key", spec.key)
		source:SetAttribute("Radius", spec.radius)
		source:SetAttribute("Volume", spec.volume)
		source:SetAttribute("Looped", spec.loop)
		CollectionService:AddTag(source, SceneBuilder.SOUND_TAG)
	end
	local train = dressing.train
	if train then
		local run = Create("Folder", { Name = "MetroTrain", Parent = folder })
		run:SetAttribute("Cars", table.concat(train.cars, ","))
		run:SetAttribute("EnterAt", b:worldPos(train.enter, train.y, train.z))
		run:SetAttribute("StopAt", b:worldPos(train.stop, train.y, train.z))
		run:SetAttribute("LeaveAt", b:worldPos(train.leave, train.y, train.z))
		run:SetAttribute("Rot", train.rot)
		run:SetAttribute("Every", train.every)
		run:SetAttribute("Dwell", train.dwell)
		run:SetAttribute("CarLength", train.carLength)
		CollectionService:AddTag(run, SceneBuilder.TRAIN_TAG)
	end
	for _, spec in ipairs(dressing.blinkers or {}) do
		local lamp = Create("Part", {
			Name = "Blinker",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Color = color(spec.color) :: Color3,
			Size = Vector3.one * spec.size,
			CFrame = b:world(CFrame.new(spec.at[1], spec.at[2], spec.at[3])),
			Parent = folder,
		})
		lamp:SetAttribute("Period", spec.period)
		lamp:SetAttribute("Phase", spec.phase)
		CollectionService:AddTag(lamp, SceneBuilder.BLINK_TAG)
	end
	local heli = dressing.helicopter
	if heli then
		local run = Create("Folder", { Name = "Helicopter", Parent = folder })
		run:SetAttribute("Path", encodePath(b, heli.path))
		run:SetAttribute("Target", encodePath(b, heli.target))
		run:SetAttribute("Every", heli.every)
		run:SetAttribute("Duration", heli.duration)
		CollectionService:AddTag(run, SceneBuilder.HELI_TAG)
	end
	for _, spec in ipairs(dressing.lookZones or {}) do
		local lo = Vector3.new(spec.min[1], spec.min[2], spec.min[3])
		local hi = Vector3.new(spec.max[1], spec.max[2], spec.max[3])
		local zone = Create("Part", {
			Name = "LookZone_" .. spec.preset,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = hi - lo,
			CFrame = b:world(CFrame.new((lo + hi) / 2)),
			Parent = folder,
		})
		zone:SetAttribute("Preset", spec.preset)
		CollectionService:AddTag(zone, SceneBuilder.LOOK_TAG)
	end
	for _, spec in ipairs(dressing.clocks or {}) do
		local clock = Create("Model", { Name = "Clock" })
		local dial = Create("Part", {
			Name = "Dial",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = b:world(b:cf(spec.at[1], spec.at[2], spec.at[3], spec.rot)),
			Parent = clock,
		})
		local hour, minute = clockHands(dial.CFrame, spec.radius, 23 * 60)
		hour.Parent = clock
		minute.Parent = clock
		clock.PrimaryPart = dial
		clock:SetAttribute("Radius", spec.radius)
		clock.Parent = folder
		CollectionService:AddTag(clock, SceneBuilder.CLOCK_TAG)
	end
end

local warned: { [string]: boolean } = {}

-- "scene" when the venue's own import (the right version) is there, else "greybox".
function SceneBuilder.mode(venue: string): string
	local module = Scenes:FindFirstChild(venue)
	if SceneBuilder.disabled or not module then
		return "greybox"
	end
	local data = require(module) :: any
	-- Imports from before the rename carry the older marker name (same version, same meshes).
	local marker = ModelLibrary.source(data.marker)
	local cal = ModelLibrary.calibration(data.calibration)
	if marker and cal and #ModelLibrary.sourcesWithPrefix(data.meshPrefix) > 0 then
		return "scene"
	end
	if not warned[venue] and RunService:IsStudio() then
		warned[venue] = true
		local older = #ModelLibrary.sourcesWithPrefix(data.meshPrefix) > 0
		warn(
			string.format(
				"[DeathsGambit] %s is built as a greybox: %s. Import art/export/%s with Studio's 3D importer (art/README.md).",
				venue,
				if older
					then "the imported meshes are an older version than the scene data (v" .. data.version .. ")"
					else "its meshes are not imported",
				data.fbx
			)
		)
	end
	return "greybox"
end

local function buildFormat2(b, venue: string, data): string
	local mode = SceneBuilder.mode(venue)
	local greybox = mode == "greybox"
	local folder = Create("Folder", { Name = "Scene", Parent = b.parent })
	if not greybox then
		local cal = ModelLibrary.calibration(data.calibration) :: ModelLibrary.Calibration
		for _, source in ipairs(ModelLibrary.sourcesWithPrefix(data.meshPrefix)) do
			if not source:IsA("MeshPart") then
				continue
			end
			local part = source:Clone()
			local local_ = cal.toLocal * source.CFrame
			part.Size = source.Size / cal.scale
			part.CFrame = b:world(CFrame.new(local_.Position / cal.scale) * local_.Rotation)
			local rest = string.sub(source.Name, #data.meshPrefix + 1)
			dress(part, (string.gsub(rest, "_%d+$", "")))
			part.Parent = folder
		end
	end
	local geometry = data.geometry
	local looks = geometry.looks
	local solids = Create("Folder", { Name = "Solids", Parent = folder })
	for _, c in ipairs(geometry.colliders) do
		local look = if c[9] and c[9] > 0 then looks[c[9]] else nil
		local part = Instance.new("Part")
		part.Name = "Collider"
		part.Size = Vector3.new(c[4], c[5], c[6])
		part.CFrame = b:world(b:cf(c[1], c[2], c[3], c[7]))
		solid(part, look, greybox, c[8])
		if look then
			-- What the surface is (the client's footprints look for "Snow").
			part:SetAttribute("Look", look)
		end
		part.Parent = solids
		if c[8] then
			CollectionService:AddTag(part, SceneBuilder.CAMERA_TAG)
		end
	end
	for _, f in ipairs(geometry.floors) do
		local thickness = f[8]
		local y = f[7] - thickness / 2
		local a = b:worldPos(f[1], y, f[2])
		local p = b:worldPos(f[3], y, f[4])
		local q = b:worldPos(f[5], y, f[6])
		local look = if f[9] > 0 then looks[f[9]] else nil
		for _, wedge in ipairs(triangle(solids, a, p, q, thickness)) do
			solid(wedge, look, greybox, f[10])
			if look then
				wedge:SetAttribute("Look", look)
			end
			if f[10] then
				CollectionService:AddTag(wedge, SceneBuilder.CAMERA_TAG)
			end
		end
	end
	-- Stairs: the smooth slab under the steps is what people walk on, never shown; the greybox
	-- draws the steps over it.
	for _, r in ipairs(geometry.ramps) do
		local part = Instance.new("Part")
		part.Name = "Ramp"
		part.Size = Vector3.new(r[4], r[5], r[6])
		part.CFrame = b:world(
			CFrame.new(r[1], r[2], r[3]) * CFrame.Angles(0, math.rad(r[7]), 0) * CFrame.Angles(math.rad(r[8]), 0, 0)
		)
		solid(part, nil, greybox, r[9])
		part.Parent = solids
	end
	if greybox then
		for _, st in ipairs(geometry.steps or {}) do
			local look = if st[8] > 0 then looks[st[8]] else nil
			local step = Instance.new("Part")
			step.Name = "Step"
			step.Size = Vector3.new(st[4], st[5], st[6])
			step.CFrame = b:world(b:cf(st[1], st[2], st[3], st[7]))
			solid(step, look, true, false)
			step.CanCollide = false
			step.Parent = solids
		end
		paintZones(b, folder, data.layout.zones or {})
	end
	local dressing = data.dressing
	for _, p in ipairs(dressing.props) do
		local model = b:placeModel(p[1], p[2], p[4], p[5], p[6], p[3])
		if model then
			model.Parent = folder
		else
			standIn(b, folder, p)
		end
		propLights(b, folder, p, model == nil)
	end
	for _, spec in ipairs(dressing.lights) do
		addLight(b, folder, spec, greybox)
	end
	addAmbience(b, folder, dressing)
	for _, spec in ipairs(dressing.signs) do
		addSign(b, spec)
	end
	for _, spec in ipairs(dressing.emitters) do
		addEmitter(b, folder, spec)
	end
	for _, spec in ipairs(dressing.covers or {}) do
		addCover(b, folder, spec)
	end
	fillWater(b, dressing.water or {})
	folder:SetAttribute("Mode", mode)
	return mode
end

-- The scene data of a venue (Scenes/<Venue>/), or nil.
function SceneBuilder.data(venue: string): any
	local module = Scenes:FindFirstChild(venue)
	if not module then
		return nil
	end
	local data = require(module) :: any
	return if data.format == 2 then data else nil
end

-- Builds the venue's scene with builder b: "scene" (its import is there) or "greybox"; nil when the
-- venue has no scene data.
function SceneBuilder.build(b, venue: string): string?
	local data = SceneBuilder.data(venue)
	if not data then
		return nil
	end
	return buildFormat2(b, venue, data)
end

return SceneBuilder
