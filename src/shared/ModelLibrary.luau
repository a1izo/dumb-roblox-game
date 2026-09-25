--!strict
-- The props and map scenes made in Blender (art/export/*.fbx) after they are imported with
-- Studio's 3D importer. The importer drops its result into Workspace; install() (server, at
-- start) moves every import it can find into ReplicatedStorage.InkboundAssets, so it is
-- hidden, anchored and reachable from clients. get(key) then returns a ready model: scaled to
-- the size in ModelCatalog, turned upright, glow parts turned Neon, and pivoted at its bottom
-- centre ("bottom") or its middle ("centre"). Without an import it returns nil and callers
-- build their part-made stand-ins, so the game works either way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.ModelCatalog)

local ModelLibrary = {}

type Info = {
	size: { number },
	pivot: string,
	material: string,
	collide: boolean,
	glow: { { number } }?,
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
	if instance.Name == STORE_NAME then
		return false
	end
	if string.sub(instance.Name, 1, 8) == "Inkbound" then
		return instance:FindFirstChildWhichIsA("MeshPart", true) ~= nil
	end
	local known = 0
	for _, item in ipairs(instance:GetDescendants()) do
		if item:IsA("MeshPart") and ((Catalog :: any)[item.Name] ~= nil or string.find(item.Name, "^Scene_")) then
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
	index = buildIndex()
	templates = {}

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
	if found == 0 then
		print(
			"[Inkbound] No Blender models imported yet: the game uses its part-built stand-ins. "
				.. "Import art/export/InkboundModels.fbx and InkboundMaps.fbx with Studio's 3D importer (art/README.md)."
		)
	else
		print(string.format("[Inkbound] Blender models: %d of %d found.", found, total))
		if #missing > 0 and RunService:IsStudio() then
			warn("[Inkbound] Missing Blender models (built from parts instead): " .. table.concat(missing, ", "))
		end
	end
	local scenes = 0
	for name in pairs(index :: { [string]: Instance }) do
		if string.sub(name, 1, 6) == "Scene_" then
			scenes += 1
		end
	end
	if scenes > 0 then
		print(string.format("[Inkbound] Blender map scenes: %d meshes.", scenes))
	elseif RunService:IsStudio() then
		print("[Inkbound] No map scenes imported yet: import art/export/InkboundMaps.fbx for the new maps.")
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

	-- Upright: pick the turn that makes the model's shape match the catalog.
	local expected = vector(info.size)
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
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
	end
	-- Setting PrimaryPart moves WorldPivot, so the pivot goes last.
	model.WorldPivot = CFrame.new(pivot)
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
