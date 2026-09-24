--!strict
-- The props made in Blender (art/export/InkboundModels.fbx), once they are imported into
-- ReplicatedStorage.InkboundAssets. get(key) returns a ready model: anchored, scaled to the
-- size in ModelCatalog (whatever unit the importer used), turned upright if the importer
-- swapped axes, glowing parts turned Neon, and pivoted at its bottom centre ("bottom") or its
-- middle ("centre"). Without an import it returns nil and callers build their part-made
-- stand-ins, so the game works either way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(script.Parent.ModelCatalog)

local ModelLibrary = {}

type Info = {
	size: { number },
	pivot: string,
	material: string,
	collide: boolean,
	glow: { { number } }?,
}

local templates: { [string]: Model | false } = {}

-- Axis-aligned turns tried when the imported model's shape does not match the catalog.
local TURNS = {
	CFrame.identity,
	CFrame.Angles(-math.pi / 2, 0, 0),
	CFrame.Angles(math.pi / 2, 0, 0),
	CFrame.Angles(0, 0, math.pi / 2),
	CFrame.Angles(0, math.pi / 2, 0),
}

local function assetRoot(): Instance?
	return ReplicatedStorage:FindFirstChild("InkboundAssets")
end

local function isSource(instance: Instance, name: string): boolean
	if instance.Name ~= name then
		return false
	end
	return instance:IsA("MeshPart")
		or (instance:IsA("Model") and instance:FindFirstChildWhichIsA("MeshPart", true) ~= nil)
end

local function findSource(name: string): Instance?
	local root = assetRoot()
	if not root then
		return nil
	end
	for _, item in ipairs(root:GetDescendants()) do
		if isSource(item, name) then
			return item
		end
	end
	return nil
end

-- <key>_Glow, <key>_Glow2, ... in order.
local function glowSources(key: string): { Instance }
	local list = {}
	local first = findSource(key .. "_Glow")
	if first then
		table.insert(list, first)
		local index = 2
		while true do
			local extra = findSource(key .. "_Glow" .. index)
			if not extra then
				break
			end
			table.insert(list, extra)
			index += 1
		end
	end
	return list
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
	for index, glowSource in ipairs(glowSources(key)) do
		local glow = glowSource:Clone()
		local colour = info.glow and info.glow[index]
		for _, part in ipairs(partsOf(glow)) do
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
		glow.Parent = model
	end

	-- Upright: pick the turn that makes the model's shape match the catalog.
	local expected = vector(info.size)
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position)
	local bestTurn, bestError = CFrame.identity, math.huge
	for _, turn in ipairs(TURNS) do
		local turned = absolute(turn:VectorToWorldSpace(size))
		local err = shapeError(turned, expected)
		if err < bestError - 1e-3 then
			bestTurn, bestError = turn, err
		end
	end
	if bestTurn ~= CFrame.identity then
		model:PivotTo(model:GetPivot() * bestTurn)
		-- Measure again along the world axes.
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
	model.WorldPivot = CFrame.new(pivot)
	local primary = partsOf(main)[1]
	if primary then
		model.PrimaryPart = primary
		-- Keep the pivot where we set it (setting PrimaryPart moves WorldPivot).
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

-- A texture that came in on a carrier quad named "Tex_<name>" with the same import.
function ModelLibrary.carrierTexture(name: string): string?
	local source = findSource("Tex_" .. name)
	if not source then
		return nil
	end
	for _, part in ipairs(partsOf(source)) do
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

return ModelLibrary
