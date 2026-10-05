--!strict
-- The lobby's things that move in the wind: roots hanging from lintels and off the island's rim,
-- banners on poles. Built here at the scene's anchors (root<n>: x, y, z of where it hangs from and
-- h its length; banner<n>: where its pole stands, rot, h the pole's height); each is a Model tagged
-- LSway that the client animates (client World/WindSway). Nothing here collides.
--
-- A model's shape is the contract with the client: a "Hook" part where it hangs from, then "Seg1",
-- "Seg2"... hanging one below the other; attributes Amp (radians), Period (seconds), Phase, Cloth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local LobbyDecor = {}

LobbyDecor.TAG = "LSway"

local ROOT_COLOR = Color3.fromRGB(46, 44, 44)
local POLE_COLOR = Color3.fromRGB(52, 50, 52)
local CLOTH_COLOR = Color3.fromRGB(84, 84, 90)
local SEGMENT = 2.4

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number? }

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- A hanging chain of segments below `hook` (a world CFrame): sizes from top to bottom.
local function chain(
	parent: Instance,
	name: string,
	hook: CFrame,
	sizes: { Vector3 },
	color: Color3,
	material: Enum.Material
)
	local model = Create("Model", { Name = name, Parent = parent })
	local hookPart = Create("Part", {
		Name = "Hook",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = hook,
		Transparency = 1,
		Parent = model,
	}) :: BasePart
	inert(hookPart)
	local drop = 0
	for index, size in ipairs(sizes) do
		local part = Create("Part", {
			Name = "Seg" .. index,
			Size = size,
			Color = color,
			Material = material,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			CFrame = hook * CFrame.new(0, -(drop + size.Y / 2), 0),
			Parent = model,
		}) :: BasePart
		inert(part)
		drop += size.Y
	end
	model:AddTag(LobbyDecor.TAG)
	return model
end

local function root(b, folder: Instance, a: Anchor, index: number)
	local length = a.h or 8
	local count = math.max(2, math.ceil(length / SEGMENT))
	local sizes = {}
	for i = 1, count do
		local thick = 0.5 * (1 - (i - 1) / count * 0.78) + 0.08
		table.insert(sizes, Vector3.new(thick, length / count, thick))
	end
	local model =
		chain(folder, "Root" .. index, b:world(CFrame.new(a.x, a.y, a.z)), sizes, ROOT_COLOR, Enum.Material.Wood)
	model:SetAttribute("Amp", math.rad(3.2 + (index % 3) * 1.2))
	model:SetAttribute("Period", 4.6 + (index % 5) * 0.7)
	model:SetAttribute("Phase", index * 1.37)
	model:SetAttribute("Cloth", false)
end

local function banner(b, folder: Instance, a: Anchor, index: number)
	local height = a.h or 10
	local base = b:cf(a.x, a.y, a.z, a.rot)
	local pole = Create("Part", {
		Name = "Pole" .. index,
		Size = Vector3.new(0.4, height, 0.4),
		Color = POLE_COLOR,
		Material = Enum.Material.Slate,
		CFrame = b:world(base) * CFrame.new(0, height / 2, 0),
		Parent = folder,
	}) :: BasePart
	inert(pole)
	local bar = Create("Part", {
		Name = "Bar" .. index,
		Size = Vector3.new(3.4, 0.3, 0.3),
		Color = POLE_COLOR,
		Material = Enum.Material.Slate,
		CFrame = b:world(base) * CFrame.new(1.6, height - 0.8, 0),
		Parent = folder,
	}) :: BasePart
	inert(bar)
	local width = a.w or 3.2
	local sizes = { Vector3.new(width, 3.4, 0.06), Vector3.new(width * 0.86, 3.0, 0.06) }
	local model = chain(
		folder,
		"Banner" .. index,
		b:world(base) * CFrame.new(1.6, height - 0.95, 0),
		sizes,
		CLOTH_COLOR,
		Enum.Material.Fabric
	)
	model:SetAttribute("Amp", math.rad(8))
	model:SetAttribute("Period", 3.1 + (index % 3) * 0.5)
	model:SetAttribute("Phase", index * 2.1)
	model:SetAttribute("Cloth", true)
end

function LobbyDecor.build(b, anchors: { [string]: Anchor })
	local folder = Create("Folder", { Name = "Decor", Parent = b.parent })
	local index = 1
	while anchors["root" .. index] do
		root(b, folder, anchors["root" .. index], index)
		index += 1
	end
	index = 1
	while anchors["banner" .. index] do
		banner(b, folder, anchors["banner" .. index], index)
		index += 1
	end
	return folder
end

return LobbyDecor
