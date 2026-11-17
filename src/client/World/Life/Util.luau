--!strict
-- What every small motion in a map shares (World/MapLife and the kinds in World/Life): one pass over the built map that
-- sorts out what there is to animate (props by name, signs by their writing, lamps, rain covers), the local folder the
-- client-made parts live in, and a few helpers. Nothing here is replicated: a part made on a client is its own.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Venues = require(Shared:WaitForChild("Venues"))

local Emit = require(script.Parent.Parent.Parent.Presentation.Vfx.Emit)
local Textures = require(script.Parent.Parent.Parent.UI.Kit.Textures)

local Util = {}

-- What a pass over the map finds.
export type Index = {
	map: Instance,
	props: { [string]: { Model } }, -- every placed prop, by its catalog name
	boards: { { part: BasePart, text: string } }, -- the signs the map draws itself: the board and what is written on it
	lamps: { { anchor: BasePart, light: Light } }, -- the map's own lamps: the "Light" part and the light in it
	covers: { BasePart }, -- the boxes that shelter from rain (awnings, canopies)
	zones: { BasePart }, -- the boxes the lighting changes look in (a building's footprint and height)
}

-- What the world is like for the frame being stepped.
export type Env = {
	now: number, -- seconds, a steady clock
	dt: number,
	eye: Vector3, -- the camera
	reduced: boolean, -- Reduce motion: nothing shakes, flashes or spins
	flashes: boolean, -- false when the player has flashes off, or reduced motion
	particles: boolean, -- false when the governor or Low quality has cut particles
	share: number, -- Emit.share(): the share of particles a device makes (1 on a computer)
	blackout: boolean, -- the map's power is out
}

-- A thing that is on in a map: stepped every frame (about 30 times a second), taken down when the map goes.
export type Built = {
	step: (Env) -> (),
	destroy: () -> (),
}

-- One kind of motion. `maps` are the map ids it belongs to; `build` returns nil when the map has nothing for it.
export type Kind = {
	name: string,
	maps: { string },
	build: (Index, string) -> Built?,
}

local PROP_ATTRIBUTE = "DeathsGambitProp"
local COVER_TAG = "LRainCover"
local LOOK_TAG = "LLookZone"

-- One pass over a built map (about one hitch at the start of a match, never again).
function Util.index(map: Instance): Index
	local index: Index = { map = map, props = {}, boards = {}, lamps = {}, covers = {}, zones = {} }
	for _, item in ipairs(map:GetDescendants()) do
		if item:IsA("Model") then
			local key = item:GetAttribute(PROP_ATTRIBUTE)
			if type(key) == "string" then
				local list = index.props[key]
				if not list then
					list = {}
					index.props[key] = list
				end
				table.insert(list, item)
			end
		elseif item:IsA("TextLabel") then
			local gui = item.Parent
			local board = if gui and gui:IsA("SurfaceGui") then gui.Parent else nil
			if board and board:IsA("BasePart") then
				table.insert(index.boards, { part = board, text = item.Text })
			end
		elseif item:IsA("Light") then
			local anchor = item.Parent
			if anchor and anchor:IsA("BasePart") and anchor.Name == "Light" then
				table.insert(index.lamps, { anchor = anchor, light = item })
			end
		end
	end
	for _, part in ipairs(CollectionService:GetTagged(COVER_TAG)) do
		if part:IsA("BasePart") and part:IsDescendantOf(map) then
			table.insert(index.covers, part)
		end
	end
	for _, part in ipairs(CollectionService:GetTagged(LOOK_TAG)) do
		if part:IsA("BasePart") and part:IsDescendantOf(map) then
			table.insert(index.zones, part)
		end
	end
	return index
end

-- The venue's own origin (a place in a map's data is its local studs plus this).
function Util.world(x: number, y: number, z: number): Vector3
	return Venues.MAP + Vector3.new(x, y, z)
end

-- The folder the client-made parts live in (made again if something removed it).
local folder: Folder? = nil
function Util.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Create("Folder", { Name = "DeathsGambitLife", Parent = workspace }) :: Folder
	folder = made
	return made
end

-- A small unseen part that holds emitters, or a lamp's glow: never solid, never in a ray.
function Util.holder(cframe: CFrame, size: Vector3, name: string?): Part
	return Create("Part", {
		Name = name or "LifeHolder",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = size,
		CFrame = cframe,
		Parent = Util.folder(),
	}) :: Part
end

-- A visible plain part of the same kind (the fan's blades, a status light).
function Util.solid(cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, name: string?): Part
	return Create("Part", {
		Name = name or "LifePart",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Color = color,
		Material = material,
		Size = size,
		CFrame = cframe,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}) :: Part
end

-- Rays that skip every character (a body in the way is not part of the map).
function Util.rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- The soft round glow every map effect draws its particles with ("" until the UI textures are in).
function Util.glow(): string
	return Textures.id("AuraGlow")
end

-- A flake of snow (the weather's own when the Campus import brought it, else the glow).
function Util.flake(): string
	local id = Assets.texture("CampusFlake")
	if id ~= "" then
		return id
	end
	return Util.glow()
end

-- The share of particles this device makes (see Vfx/Emit).
function Util.share(): number
	return Emit.share()
end

-- True when a colour is within `tolerance` (0 to 255, per channel) of an {r, g, b} triple.
function Util.near(color: Color3, rgb: { number }, tolerance: number): boolean
	return math.abs(color.R * 255 - rgb[1]) <= tolerance
		and math.abs(color.G * 255 - rgb[2]) <= tolerance
		and math.abs(color.B * 255 - rgb[3]) <= tolerance
end

-- A prop's glowing parts: the Neon meshes the map made from its catalog glow list, in no particular order.
function Util.glowsOf(model: Model): { BasePart }
	local list: { BasePart } = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("DeathsGambitGlow") ~= nil then
			table.insert(list, item)
		end
	end
	return list
end

local warned: { [string]: boolean } = {}
-- Says once, in the output, that a kind of motion failed (it is then left out until the map changes).
function Util.complain(name: string, err: any)
	if not warned[name] then
		warned[name] = true
		warn(string.format("[DeathsGambit] map life '%s' stopped: %s", name, tostring(err)))
	end
end

return Util
