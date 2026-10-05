--!strict
-- The props and scenes made in Blender (art/export/InkboundModels_<Set>.fbx for the props,
-- InkboundMaps_<Venue>.fbx for each venue's scene) after they are imported with Studio's 3D
-- importer. The importer drops its result into Workspace; install() (server, at
-- start) moves every import it can find into ReplicatedStorage.InkboundAssets, so it is
-- hidden, anchored and reachable from clients. get(key) then returns a ready model: scaled to
-- the size in ModelCatalog, turned upright, glow parts turned Neon, and pivoted at its bottom
-- centre ("bottom") or its middle ("centre"). Without an import it returns nil and callers
-- build their part-made stand-ins, so the game works either way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.ModelCatalog)

local ModelLibrary = {}

export type Info = {
	size: { number },
	pivot: string,
	material: string,
	collide: boolean,
	glow: { { number } }?,
	lights: { any }?, -- the lights it carries (placed by the map builder, see SceneBuilder)
	anchor: { number }?, -- where maps put its foot (x, z from its pivot), when not the middle
	set: string?, -- which import it comes in ("Core": InkboundModels_Core.fbx, "Tokyo": InkboundModels_Tokyo.fbx)
	-- A station look's slot for the game's screen: the middle of its face from the station's
	-- origin (x, y, z), its size (w, h) and how far its top leans back (degrees).
	screen: { at: { number }, size: { number }, tilt: number? }?,
	tris: number?, -- triangles, for the debug line-up
}

local STORE_NAME = "InkboundAssets"

local templates: { [string]: Model | false } = {}
local index: { [string]: Instance }? = nil

-- Axis-aligned turns tried when the imported model's shape does not match the catalog.
local TURNS = {
	CFrame.identity,
	CFrame.Angles(-math.pi / 2, 0, 0),
	CFrame.Angles(math.pi / 2, 0, 0),
	CFrame.Angles(0, 0, math.pi / 2),
	CFrame.Angles(0, math.pi / 2, 0),
}

local function store(): Instance?
	return ReplicatedStorage:FindFirstChild(STORE_NAME)
end

local function isMeshSource(instance: Instance): boolean
	return instance:IsA("MeshPart")
		or (instance:IsA("Model") and instance:FindFirstChildWhichIsA("MeshPart", true) ~= nil)
end

-- name -> the first mesh (or model of meshes) with that name in the store.
local function buildIndex(): { [string]: Instance }
	local found = {}
	local root = store()
	if root then
		for _, item in ipairs(root:GetDescendants()) do
			if found[item.Name] == nil and isMeshSource(item) then
				found[item.Name] = item
			end
		end
	end
	return found
end

local function findSource(name: string): Instance?
	if not index then
		index = buildIndex()
	end
	local hit = (index :: { [string]: Instance })[name]
	if hit and hit.Parent then
		return hit
	end
	-- Something may have arrived since (replication, a late install): look once more.
	index = buildIndex()
	return (index :: { [string]: Instance })[name]
end

-- True for a model or folder that came from our importer runs (by name, or because it holds
-- several meshes named after catalog props).
local function looksImported(instance: Instance): boolean
	if not (instance:IsA("Model") or instance:IsA("Folder")) then
		return false
	end
	if instance.Name == STORE_NAME or instance.Name == "InkboundSuperseded" then
		return false
	end
	if string.sub(instance.Name, 1, 8) == "Inkbound" then
		return instance:FindFirstChildWhichIsA("MeshPart", true) ~= nil
	end
	local known = 0
	for _, item in ipairs(instance:GetDescendants()) do
		local name = item.Name
		local ours = (Catalog :: any)[name] ~= nil or string.find(name, "^Map_")
		if item:IsA("MeshPart") and ours then
			known += 1
			if known >= 3 then
				return true
			end
		end
	end
	return false
end

local function quiet(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

-- Calibration --------------------------------------------------------------------------------
-- Studio's importer may scale, turn or move what it imports. Each export carries three cubes,
-- <prefix>_O at the origin, _X 64 studs along x and _Y 64 studs up; where they land tells
-- exactly how the import was changed.

export type Calibration = { toLocal: CFrame, scale: number }

local calibrations: { [string]: Calibration | false } = {}

local function positionOf(source: Instance): Vector3?
	if source:IsA("BasePart") then
		return source.Position
	elseif source:IsA("Model") then
		return (source :: Model):GetBoundingBox().Position
	end
	return nil
end

-- The import's calibration from the cubes named prefix_O/_X/_Y, or nil when they are missing.
-- toLocal turns an imported CFrame back into the one it was exported with (before scaling).
function ModelLibrary.calibration(prefix: string): Calibration?
	local cached = calibrations[prefix]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local o, x, y = findSource(prefix .. "_O"), findSource(prefix .. "_X"), findSource(prefix .. "_Y")
	local po = o and positionOf(o)
	local px = x and positionOf(x)
	local py = y and positionOf(y)
	if not (po and px and py) then
		calibrations[prefix] = false
		return nil
	end
	local ex, ey = px - po, py - po
	if ex.Magnitude < 1e-3 or ey.Magnitude < 1e-3 then
		calibrations[prefix] = false
		return nil
	end
	local right = ex.Unit
	local up = (ey - right * ey:Dot(right)).Unit
	local found = {
		toLocal = CFrame.fromMatrix(po, right, up, right:Cross(up)):Inverse(),
		scale = ex.Magnitude / 64,
	}
	calibrations[prefix] = found
	return found
end

-- Studio's importer also turns the mesh data of every prop half way round the vertical axis, which
-- the cubes cannot show (they only tell where the importer put each mesh, and Studio puts them
-- where the file says). Measured with the debug Prop gallery on 2026-09-29, with every file
-- freshly imported: every front faced away from its red arrow, in every set. Blender makes them
-- face -Z and the file holds them that way, so build() turns each prop this much about its own
-- centre. Set to 0 if a later Studio stops doing it (the gallery shows it at once).
local FACING_TURN = CFrame.Angles(0, math.pi, 0)

-- True while build() gives every prop that half turn. The debug Prop gallery says so in its
-- message, so a place that still runs scripts from before the fix is easy to tell.
function ModelLibrary.facingTurned(): boolean
	return FACING_TURN ~= CFrame.identity
end

-- The turn that undoes the importer's rotation of a prop: from the cubes in the prop's own file
-- (Calib_Props<Set>, such as Calib_PropsCore in InkboundModels_Core.fbx), else nil. Each file is
-- measured on its own: two imports can come in turned differently.
local function importTurn(set: string?): CFrame?
	local cal = ModelLibrary.calibration("Calib_Props" .. (if set and set ~= "" then set else "Core"))
	return if cal then cal.toLocal.Rotation else nil
end

local function describeTurn(prefix: string): string
	local cal = ModelLibrary.calibration(prefix)
	if not cal then
		return prefix .. ": no calibration cubes"
	end
	local rx, ry, rz = cal.toLocal:Inverse():ToOrientation()
	return string.format(
		"%s: turned %d/%d/%d degrees, scale %.3f",
		prefix,
		math.round(math.deg(rx)),
		math.round(math.deg(ry)),
		math.round(math.deg(rz)),
		cal.scale
	)
end

-- Versions -----------------------------------------------------------------------------------
-- Every export carries a marker mesh Inkbound<Kind>_Version_<n>. When the same kind was
-- imported more than once, only the newest import is used; older ones are set aside so old
-- and new meshes never mix.
--
-- Two files are retired: InkboundModels.fbx (kind "Models", its props now come in
-- InkboundModels_Core.fbx) and InkboundMaps.fbx (kind "Maps", the lobby and the meeting room now
-- have files of their own). An import of either is always set aside, so nothing can use it.
local RETIRED = { Models = "InkboundModels.fbx", Maps = "InkboundMaps.fbx" }

-- The import's kind and version from its marker, and whether it has one (without, the kind is
-- the folder's own name: an early import, or your own models).
local function importVersion(root: Instance): (string, number, boolean)
	for _, item in ipairs(root:GetDescendants()) do
		local kind, version = string.match(item.Name, "^Inkbound(%a+)_Version_(%d+)$")
		if kind then
			return kind, tonumber(version) or 0, true
		end
	end
	return root.Name, 0, false
end

-- True for an import of a retired file: its marker says so, or (an import from before the
-- markers) the importer named it after the file.
local function isRetired(root: Instance, kind: string, marked: boolean): boolean
	if marked then
		return RETIRED[kind] ~= nil
	end
	return root.Name == "InkboundModels" or root.Name == "InkboundMaps"
end

local function supersede(item: Instance)
	local ServerStorage = game:GetService("ServerStorage")
	local bin = ServerStorage:FindFirstChild("InkboundSuperseded")
	if not bin then
		bin = Instance.new("Folder")
		bin.Name = "InkboundSuperseded"
		bin.Parent = ServerStorage
	end
	item.Parent = bin
end

-- Sets aside every import of a retired file and all but the newest import of each kind. Returns
-- (older imports set aside, retired files found).
local function setAsideOlder(root: Instance): ({ string }, { string })
	local groups: { [string]: { { item: Instance, version: number, order: number } } } = {}
	local retired = {}
	for order, child in ipairs(root:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			local kind, version, marked = importVersion(child)
			if isRetired(child, kind, marked) then
				supersede(child)
				table.insert(retired, RETIRED[kind] or (child.Name .. ".fbx"))
				continue
			end
			groups[kind] = groups[kind] or {}
			table.insert(groups[kind], { item = child, version = version, order = order })
		end
	end
	local setAside = {}
	for kind, list in pairs(groups) do
		if #list > 1 then
			table.sort(list, function(a, b)
				if a.version ~= b.version then
					return a.version > b.version
				end
				return a.order > b.order
			end)
			for index = 2, #list do
				local older = list[index]
				supersede(older.item)
				table.insert(setAside, string.format("%s (version %d)", kind, older.version))
			end
		end
	end
	return setAside, retired
end

-- Server, once at start (before any map is built): moves imports that were left in Workspace,
-- ReplicatedStorage or ServerStorage into ReplicatedStorage.InkboundAssets and reports what
-- the game can use.
function ModelLibrary.install(): { found: number, missing: { string } }
	local root = store()
	if not root then
		local folder = Instance.new("Folder")
		folder.Name = STORE_NAME
		folder.Parent = ReplicatedStorage
		root = folder
	end
	local rootInstance = root :: Instance
	local moved = {}
	local containers = { workspace, ReplicatedStorage, game:GetService("ServerStorage") }
	for _, container in ipairs(containers) do
		for _, child in ipairs(container:GetChildren()) do
			if child ~= rootInstance and looksImported(child) then
				quiet(child)
				child.Parent = rootInstance
				table.insert(moved, container.Name .. "." .. child.Name)
			end
		end
	end
	quiet(rootInstance)
	local setAside, retired = setAsideOlder(rootInstance)
	index = buildIndex()
	templates = {}
	calibrations = {}

	local found, missing = 0, {}
	for key in pairs(Catalog :: any) do
		if (index :: { [string]: Instance })[key] then
			found += 1
		else
			table.insert(missing, key)
		end
	end
	table.sort(missing)
	local total = found + #missing
	if #moved > 0 then
		print(
			"[Inkbound] Moved imported models into ReplicatedStorage."
				.. STORE_NAME
				.. ": "
				.. table.concat(moved, ", ")
		)
	end
	if #retired > 0 then
		warn(
			"[Inkbound] Set aside imports of retired files (nothing uses them any more; delete them in Studio): "
				.. table.concat(retired, ", ")
				.. ". Their props come in InkboundModels_Core.fbx, the lobby and the meeting room in "
				.. "InkboundMaps_Lobby.fbx and InkboundMaps_Meeting.fbx."
		)
	end
	if found == 0 then
		print(
			"[Inkbound] No Blender models imported yet: the game uses its part-built stand-ins. "
				.. "Import art/export/InkboundModels_<Set>.fbx and InkboundMaps_<Venue>.fbx with Studio's 3D importer (art/README.md)."
		)
	else
		print(string.format("[Inkbound] Blender models: %d of %d found.", found, total))
		if #missing > 0 and RunService:IsStudio() then
			warn("[Inkbound] Missing Blender models (built from parts instead): " .. table.concat(missing, ", "))
		end
	end
	local scenes = 0
	local venues = {}
	for name in pairs(index :: { [string]: Instance }) do
		if string.sub(name, 1, 4) == "Map_" then
			scenes += 1
		end
		local venue, version = string.match(name, "^InkboundMaps(%a+)_Version_(%d+)$")
		if venue then
			table.insert(venues, venue .. " v" .. version)
		end
	end
	table.sort(venues)
	if #venues > 0 then
		print(string.format("[Inkbound] Scene imports: %s (%d meshes).", table.concat(venues, ", "), scenes))
	elseif RunService:IsStudio() then
		print(
			"[Inkbound] No scenes imported yet (every venue is a greybox): import art/export/InkboundMaps_<Venue>.fbx."
		)
	end
	if #setAside > 0 then
		warn(
			"[Inkbound] Several imports of the same file: using the newest, ignoring "
				.. table.concat(setAside, ", ")
				.. ". Delete the old copies in Studio to keep the place small."
		)
	end
	if found > 0 or scenes > 0 then
		-- Every props file (one per set), measured apart.
		local prefixes, seen = {}, {}
		for _, info in pairs(Catalog :: any) do
			local set = (info :: Info).set
			if set and set ~= "" and not seen[set] then
				seen[set] = true
				table.insert(prefixes, "Calib_Props" .. set)
			end
		end
		table.sort(prefixes)
		local lines = {}
		for _, prefix in ipairs(prefixes) do
			table.insert(lines, describeTurn(prefix))
		end
		print(
			"[Inkbound] Import check: "
				.. table.concat(lines, "; ")
				.. ". Props are also turned half way round for Studio's importer (FACING_TURN); open the debug Prop gallery to check: every front faces its red arrow."
		)
	end
	rootInstance:SetAttribute("Installed", true)
	return { found = found, missing = missing }
end

local function partsOf(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, item in ipairs(instance:GetDescendants()) do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

-- <key>_Glow, <key>_Glow2, ... in order.
local function glowSources(key: string): { Instance }
	local list = {}
	local first = findSource(key .. "_Glow")
	if first then
		table.insert(list, first)
		local n = 2
		while true do
			local extra = findSource(key .. "_Glow" .. n)
			if not extra then
				break
			end
			table.insert(list, extra)
			n += 1
		end
	end
	return list
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function absolute(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

-- How different two sizes are in shape (ignoring overall scale).
local function shapeError(a: Vector3, b: Vector3): number
	local na = a / math.max(a.X, a.Y, a.Z, 1e-3)
	local nb = b / math.max(b.X, b.Y, b.Z, 1e-3)
	return (na - nb).Magnitude
end

local function prepareGlow(part: BasePart, colour: { number }?)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	if colour then
		part.Color = Color3.fromRGB(colour[1], colour[2], colour[3])
	end
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
	if part:IsA("MeshPart") then
		pcall(function()
			(part :: MeshPart).TextureID = ""
		end)
	end
	part:SetAttribute("InkboundGlow", true)
end

local function build(key: string): Model?
	local info = (Catalog :: any)[key] :: Info?
	local source = findSource(key)
	if not info or not source then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key
	-- Kept when dress() renames the copy, so clients know which prop a mesh belongs to.
	model:SetAttribute("InkboundProp", key)
	local main = source:Clone()
	main.Parent = model
	for _, part in ipairs(partsOf(main)) do
		part.Anchored = true
		part.CanCollide = info.collide
		part.CanQuery = info.collide
		part.CanTouch = false
		part.CastShadow = true
		local material = (Enum.Material :: any)[info.material]
		if material then
			part.Material = material
		end
	end
	for n, glowSource in ipairs(glowSources(key)) do
		local glow = glowSource:Clone()
		for _, part in ipairs(partsOf(glow)) do
			prepareGlow(part, info.glow and info.glow[n])
		end
		glow.Parent = model
	end

	-- Upright and facing -Z (the way it was made): undo the importer's turn, measured by the
	-- calibration cubes. Without them, pick the turn that makes the shape match the catalog
	-- (which cannot tell front from back).
	local expected = vector(info.size)
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	local measured = importTurn(info.set)
	if measured then
		model:PivotTo(measured * model:GetPivot())
		cf, size = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(cf.Position)
	else
		local bestTurn, bestError = CFrame.identity, math.huge
		for _, turn in ipairs(TURNS) do
			local err = shapeError(absolute(turn:VectorToWorldSpace(size)), expected)
			if err < bestError - 1e-3 then
				bestTurn, bestError = turn, err
			end
		end
		if bestTurn ~= CFrame.identity then
			model:PivotTo(model:GetPivot() * bestTurn)
			model.WorldPivot = CFrame.new(model:GetPivot().Position)
			cf, size = model:GetBoundingBox()
		end
	end
	-- Then the half turn Studio's importer gives every mesh (see FACING_TURN), about the prop's
	-- own centre so it stays where it is.
	local centre = cf.Position
	model:PivotTo(CFrame.new(centre) * FACING_TURN * CFrame.new(-centre) * model:GetPivot())
	cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)

	-- Scale to the catalog size (the importer may have used another unit).
	local largest = math.max(expected.X, expected.Y, expected.Z)
	local actual = math.max(size.X, size.Y, size.Z)
	if actual > 0 then
		model:ScaleTo(largest / actual)
	end
	cf, size = model:GetBoundingBox()
	local pivot = if info.pivot == "bottom" then cf.Position - Vector3.new(0, size.Y / 2, 0) else cf.Position
	local primary = partsOf(main)[1]
	if primary then
		model.PrimaryPart = primary
		-- With a primary part the pivot takes that part's orientation, which carries the half turn
		-- above (and any measured turn), and PivotTo would then undo it: a prop placed upright at a
		-- yaw faced the importer's way again. The part's own pivot offset keeps the pivot upright, at
		-- the bottom or centre of the prop, so PivotTo(position * yaw) places it as it was made.
		primary.PivotOffset = primary.CFrame:Inverse() * CFrame.new(pivot)
	else
		model.WorldPivot = CFrame.new(pivot)
	end
	return model
end

-- True when the prop has been imported.
function ModelLibrary.has(key: string): boolean
	local cached = templates[key]
	if cached ~= nil then
		return cached ~= false
	end
	return findSource(key) ~= nil
end

-- A fresh copy of the prop, or nil when it is not imported.
function ModelLibrary.get(key: string): Model?
	local template = templates[key]
	if template == nil then
		local ok, result = pcall(build, key)
		if not ok then
			warn("[Inkbound] Could not prepare model " .. key .. ": " .. tostring(result))
		end
		template = if ok and result then result else false
		templates[key] = template
	end
	if template == false then
		return nil
	end
	return (template :: Model):Clone()
end

-- The catalog entry for a prop (size, pivot, anchor, lights, screen slot...), or nil.
function ModelLibrary.info(key: string): Info?
	return (Catalog :: any)[key]
end

-- Dresses a gameplay part with a prop: the prop is placed at part.CFrame * offset (scaled if
-- asked) and parented to the part, and the part turns invisible. The part keeps its tags,
-- attributes, prompts and collisions, so gameplay does not change. Returns the prop, or nil
-- when it is not imported (the part then stays as it was).
function ModelLibrary.dress(part: BasePart, key: string, offset: CFrame?, scale: number?): Model?
	local model = ModelLibrary.get(key)
	if not model then
		return nil
	end
	if scale and math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model.Name = "Visual"
	model:PivotTo(part.CFrame * (offset or CFrame.identity))
	model.Parent = part
	part.Transparency = 1
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		end
	end
	return model
end

-- The glowing parts of a prop placed with get().
function ModelLibrary.glowParts(model: Model): { BasePart }
	local list = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("InkboundGlow") then
			table.insert(list, item)
		end
	end
	return list
end

-- The size the prop was made at (studs).
function ModelLibrary.size(key: string): Vector3?
	local info = (Catalog :: any)[key] :: Info?
	return if info then vector(info.size) else nil
end

-- The imported mesh (or model of meshes) called `name`, as it came from the importer.
function ModelLibrary.source(name: string): Instance?
	return findSource(name)
end

-- Every imported mesh whose name starts with `prefix`.
function ModelLibrary.sourcesWithPrefix(prefix: string): { Instance }
	if not index then
		index = buildIndex()
	end
	local list = {}
	for name, item in pairs(index :: { [string]: Instance }) do
		if string.sub(name, 1, #prefix) == prefix then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- A texture id from an imported mesh: its SurfaceAppearance colour map or its TextureID.
function ModelLibrary.textureOf(instance: Instance): string?
	for _, part in ipairs(partsOf(instance)) do
		local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
		if appearance then
			local ok, id = pcall(function()
				return (appearance :: any).ColorMap
			end)
			if ok and type(id) == "string" and id ~= "" then
				return id
			end
		end
		if part:IsA("MeshPart") then
			local id = (part :: MeshPart).TextureID
			if id ~= "" then
				return id
			end
		end
	end
	return nil
end

-- A texture that came in on a carrier quad named "Tex_<name>" with the same import.
function ModelLibrary.carrierTexture(name: string): string?
	local source = findSource("Tex_" .. name)
	return if source then ModelLibrary.textureOf(source) else nil
end

return ModelLibrary
