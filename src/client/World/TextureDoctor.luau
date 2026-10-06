-- Checks that the textures uploaded with the Blender imports actually load, and gives every
-- mesh whose texture fails a flat look instead (a Roblox material and the texture's average
-- colour), so nothing renders blank. A texture fails when Roblox is still processing it, has
-- moderated it, or cannot read it; Studio prints which ones.
--
-- Scene meshes are named Map_<Venue>_<Material>_<n> and take their fallback from
-- SceneMaterials; props take theirs from ModelCatalog.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog"))
local SceneMaterials = require(Shared:WaitForChild("SceneMaterials"))

local TextureDoctor = {}

type Look = { material: string, color: { number } }

-- content id -> "ok" | "failed"
local statuses: { [string]: string } = {}
-- content id -> meshes waiting for the answer
local waiting: { [string]: { MeshPart } } = {}
local queued: { string } = {}
local flushScheduled = false
local failedNames: { [string]: number } = {}
local checked = 0

local function textureOf(part: MeshPart): string?
	if part.TextureID ~= "" then
		return part.TextureID
	end
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		local ok, id = pcall(function()
			return (appearance :: any).ColorMap
		end)
		if ok and type(id) == "string" and id ~= "" then
			return id
		end
	end
	return nil
end

-- The imported prop a mesh belongs to (ModelLibrary marks each prop model), or nil.
local function propOf(part: MeshPart): string?
	local node: Instance? = part.Parent
	while node and node ~= workspace do
		local key = node:GetAttribute("DeathsGambitProp")
		if type(key) == "string" then
			return key
		end
		node = node.Parent
	end
	return nil
end

-- The look to fall back to for a mesh, from its name (map scene) or the prop it belongs to.
local function fallbackFor(part: MeshPart): (Look?, string)
	local material = string.match(part.Name, "^Map_%a+_(.-)_%d+$")
	if material then
		local entry = (SceneMaterials :: any)[material]
		return if entry then entry.fallback else nil, material
	end
	local key = propOf(part) or part.Name
	local info = (ModelCatalog :: any)[key]
	if info and info.color then
		return { material = info.material, color = info.color }, key
	end
	return nil, key
end

local function applyFallback(part: MeshPart)
	local look, name = fallbackFor(part)
	failedNames[name] = (failedNames[name] or 0) + 1
	part.TextureID = ""
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
	if look then
		local material = (Enum.Material :: any)[look.material]
		if material then
			part.Material = material
		end
		part.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	end
end

local function settle(id: string, status: string)
	statuses[id] = status
	local parts = waiting[id]
	waiting[id] = nil
	if status == "failed" and parts then
		for _, part in ipairs(parts) do
			if part.Parent then
				applyFallback(part)
			end
		end
	end
end

local function report()
	if not RunService:IsStudio() then
		return
	end
	local failed = 0
	for _, status in pairs(statuses) do
		if status == "failed" then
			failed += 1
		end
	end
	local names = {}
	for name, count in pairs(failedNames) do
		table.insert(names, string.format("%s (%d)", name, count))
	end
	table.sort(names)
	print(string.format("[DeathsGambit] Texture check: %d of %d imported textures load.", checked - failed, checked))
	if #names > 0 then
		warn(
			"[DeathsGambit] Textures that did not load (shown with a flat colour instead): "
				.. table.concat(names, ", ")
				.. ". Roblox may still be processing or reviewing new uploads; check again later, or re-import."
		)
	end
end

local function flush()
	flushScheduled = false
	local batch = queued
	queued = {}
	if #batch == 0 then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync(batch, function(id: string, status: Enum.AssetFetchStatus)
			if statuses[id] == nil then
				settle(id, if status == Enum.AssetFetchStatus.Success then "ok" else "failed")
			end
		end)
	end)
	for _, id in ipairs(batch) do
		if statuses[id] == nil then
			settle(id, "failed")
		end
	end
	checked = 0
	for _ in pairs(statuses) do
		checked += 1
	end
	report()
end

local function consider(item: Instance)
	-- Only our imports: avatars' accessories and anything else keep Roblox's own handling.
	if not item:IsA("MeshPart") or not (string.sub(item.Name, 1, 4) == "Map_" or propOf(item)) then
		return
	end
	local id = textureOf(item)
	if not id then
		return
	end
	local status = statuses[id]
	if status == "failed" then
		applyFallback(item)
		return
	elseif status == "ok" then
		return
	end
	if not waiting[id] then
		waiting[id] = {}
		table.insert(queued, id)
	end
	table.insert(waiting[id], item)
	if not flushScheduled then
		flushScheduled = true
		task.delay(1, flush)
	end
end

function TextureDoctor.init()
	for _, item in ipairs(workspace:GetDescendants()) do
		consider(item)
	end
	workspace.DescendantAdded:Connect(consider)
end

return TextureDoctor
