-- Puts a map scene made in Blender (art/export/InkboundMaps.fbx, imported with Studio's 3D
-- importer) into a venue: every mesh named Scene_<Venue>_<Material>_<n>, invisible colliders
-- where the walls and furniture are, props from the prop library, lights, signs and steam, as
-- listed in Maps/Scenes/<Venue>.luau. build() returns false when the scene is not imported, and
-- the venue then builds its part-made version instead.
--
-- Big venues rebuilt at full size (format 2, Tokyo so far) have an FBX of their own and scene
-- data that includes their gameplay layout; they always build, as the imported scene or, without
-- the import, as a playable greybox (see buildFormat2 below).
--
-- The importer may scale or turn what it imports. Three calibration cubes in the same file
-- (Calib_Maps_O at the origin, _X 64 studs along x, _Y 64 studs up) tell how, so every mesh
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

-- Set from the debug panel to build the old part-made venues instead (to compare them).
SceneBuilder.disabled = false

-- Tag on the colliders the camera cannot pass through (see client World/CameraCollision).
SceneBuilder.CAMERA_TAG = "LCameraBlock"

local function calibrate(): ModelLibrary.Calibration?
	return ModelLibrary.calibration("Calib_Maps")
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

-- Format 2: the big venues ----------------------------------------------------------------------
-- Their scene data (Scenes/<Venue>/) holds everything, gameplay spots included, and each has an
-- FBX of its own (InkboundMaps_<Venue>.fbx). Without that import, or with an older one, the
-- venue is built as a greybox: the colliders shown in their materials' colours, so the map is
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
-- sound sources and the metro train's run; and boxes where the client's LightingController
-- switches to a look of their own (the metro under Tokyo).
SceneBuilder.SCREEN_TAG = "LMapScreen"
SceneBuilder.SOUND_TAG = "LMapSound"
SceneBuilder.TRAIN_TAG = "LMapTrain"
SceneBuilder.LOOK_TAG = "LLookZone"

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
end

local warned: { [string]: boolean } = {}

-- "scene" when the venue's own import (the right version) is there, else "greybox".
function SceneBuilder.mode(venue: string): string
	local module = Scenes:FindFirstChild(venue)
	if SceneBuilder.disabled or not module then
		return "greybox"
	end
	local data = require(module) :: any
	if data.format ~= 2 then
		return if SceneBuilder.available(venue) then "scene" else "greybox"
	end
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
				"[Inkbound] %s is built as a greybox: %s. Import art/export/%s with Studio's 3D importer (art/README.md).",
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
	folder:SetAttribute("Mode", mode)
	return mode
end

-- The scene data of a big venue (format 2), or nil.
function SceneBuilder.data(venue: string): any
	local module = Scenes:FindFirstChild(venue)
	if not module then
		return nil
	end
	local data = require(module) :: any
	return if data.format == 2 then data else nil
end

-- Builds the venue's scene with builder b. Older venues: returns false (and builds nothing)
-- when the scene has not been imported. Big venues (format 2) always build: "scene" or
-- "greybox".
function SceneBuilder.build(b, venue: string): boolean | string
	local big = SceneBuilder.data(venue)
	if big then
		return buildFormat2(b, venue, big)
	end
	if SceneBuilder.disabled then
		return false
	end
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
		local collider = b:part(
			Vector3.new(c[4], c[5], c[6]),
			b:cf(c[1], c[2], c[3], c[7]),
			Color3.new(0, 0, 0),
			Enum.Material.SmoothPlastic,
			{ Name = "Collider", Transparency = 1, CanQuery = c[8], CanTouch = false, CastShadow = false }
		)
		-- Walls, ceilings and big furniture also stop the camera (client CameraCollision):
		-- Roblox's own camera ignores invisible parts.
		if c[8] then
			CollectionService:AddTag(collider, SceneBuilder.CAMERA_TAG)
		end
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
