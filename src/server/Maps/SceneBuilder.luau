-- Puts a map scene made in Blender (art/export/InkboundMaps.fbx, imported with Studio's 3D
-- importer) into a venue: every mesh named Scene_<Venue>_<Material>_<n>, invisible colliders
-- where the walls and furniture are, props from the prop library, lights, signs and steam, as
-- listed in Maps/Scenes/<Venue>.luau. build() returns false when the scene is not imported, and
-- the venue then builds its part-made version instead.
--
-- The importer may scale or turn what it imports. Three calibration cubes in the same file
-- (Calib_Maps_O at the origin, _X 64 studs along x, _Y 64 studs up) tell how, so every mesh
-- lands exactly where it was made.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local SceneMaterials = require(Shared:WaitForChild("SceneMaterials"))

local Scenes = script.Parent:WaitForChild("Scenes")

local SceneBuilder = {}

type Calibration = { toLocal: CFrame, scale: number }

local calibration: Calibration | false | nil = nil

local function positionOf(source: Instance): Vector3?
	if source:IsA("BasePart") then
		return source.Position
	elseif source:IsA("Model") then
		return (source :: Model):GetBoundingBox().Position
	end
	return nil
end

local function calibrate(): Calibration?
	if calibration ~= nil then
		return if calibration then calibration else nil
	end
	local o = ModelLibrary.source("Calib_Maps_O")
	local x = ModelLibrary.source("Calib_Maps_X")
	local y = ModelLibrary.source("Calib_Maps_Y")
	local po = o and positionOf(o)
	local px = x and positionOf(x)
	local py = y and positionOf(y)
	if not (po and px and py) then
		calibration = false
		return nil
	end
	local ex = px - po
	local ey = py - po
	if ex.Magnitude < 1e-3 or ey.Magnitude < 1e-3 then
		calibration = false
		return nil
	end
	local scale = ex.Magnitude / 64
	local right = ex.Unit
	local up = (ey - right * ey:Dot(right)).Unit
	local found = {
		toLocal = CFrame.fromMatrix(po, right, up, right:Cross(up)):Inverse(),
		scale = scale,
	}
	calibration = found
	return found
end

-- "Scene_Meeting_WoodPanel_3" -> "WoodPanel"
local function materialName(meshName: string, venue: string): string
	local rest = string.sub(meshName, #("Scene_" .. venue .. "_") + 1)
	return (string.gsub(rest, "_%d+$", ""))
end

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

-- True when the venue's scene has been imported (meshes and calibration).
function SceneBuilder.available(venue: string): boolean
	return calibrate() ~= nil
		and Scenes:FindFirstChild(venue) ~= nil
		and #ModelLibrary.sourcesWithPrefix("Scene_" .. venue .. "_") > 0
end

local function color(values: { number }?): Color3?
	return if values then Color3.fromRGB(values[1], values[2], values[3]) else nil
end

local function addLight(b, folder: Instance, spec)
	local at = spec.at
	local anchor = Create("Part", {
		Name = "Light",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = b:world(CFrame.new(at[1], at[2], at[3])),
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

local function addEmitter(b, folder: Instance, spec)
	local at = spec.at
	local anchor = Create("Part", {
		Name = "Emitter",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 0.2, 1),
		CFrame = b:world(CFrame.new(at[1], at[2], at[3])),
		Parent = folder,
	})
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
	end
end

-- Builds the venue's scene with builder b. Returns false (and builds nothing) when it has not
-- been imported.
function SceneBuilder.build(b, venue: string): boolean
	local cal = calibrate()
	local module = Scenes:FindFirstChild(venue)
	if not cal or not module then
		return false
	end
	local sources = ModelLibrary.sourcesWithPrefix("Scene_" .. venue .. "_")
	if #sources == 0 then
		return false
	end
	local data = require(module) :: any
	local folder = Create("Folder", { Name = "Scene", Parent = b.parent })
	for _, source in ipairs(sources) do
		if not source:IsA("MeshPart") then
			continue
		end
		local part = source:Clone()
		local local_ = cal.toLocal * source.CFrame
		part.Size = source.Size / cal.scale
		part.CFrame = b:world(CFrame.new(local_.Position / cal.scale) * local_.Rotation)
		dress(part, materialName(source.Name, venue))
		part.Parent = folder
	end
	for _, c in ipairs(data.colliders) do
		b:part(
			Vector3.new(c[4], c[5], c[6]),
			b:cf(c[1], c[2], c[3], c[7]),
			Color3.new(0, 0, 0),
			Enum.Material.SmoothPlastic,
			{ Name = "Collider", Transparency = 1, CanQuery = c[8], CanTouch = false, CastShadow = false }
		)
	end
	for _, p in ipairs(data.props) do
		local model = b:placeModel(p[1], p[2], p[4], p[5], p[6], p[3])
		if model then
			model.Parent = folder
		end
	end
	for _, spec in ipairs(data.lights) do
		addLight(b, folder, spec)
	end
	for _, spec in ipairs(data.signs) do
		addSign(b, spec)
	end
	for _, spec in ipairs(data.emitters) do
		addEmitter(b, folder, spec)
	end
	return true
end

return SceneBuilder
