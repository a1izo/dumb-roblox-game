--!strict
-- The VFX kit's solid shapes: a ring, a dome, a tube, a cone, a swirl, a crescent, a sphere, spikes, a shard, a rock
-- and a page (the Fx props import's VfxRing ... VfxPage, art/scripts/vfx/meshes.py; before it is imported a ball stands
-- in for a sphere or a dome and the rest wait for it), grown from small to full on a curve, held, and faded, glowing
-- (Neon) or shimmering (ForceField) in a colour, or wearing a VFX texture. Each mesh is made 2 studs across (radius 1)
-- round its up, from its foot up where it has a height; Shape.grow sizes it in studs.
--
--   Shape.grow("ring", cf, { size = 12, seconds = 0.4, ease = Ease.outQuint, fade = 0.3, color = c })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelLibrary"))

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)
local Emit = require(script.Parent.Emit)
local Tex = require(script.Parent.Tex)

local Shape = {}

export type Kind =
	"ring"
	| "dome"
	| "tube"
	| "cone"
	| "swirl"
	| "crescent"
	| "sphere"
	| "spikes"
	| "shard"
	| "rock"
	| "page"

export type Options = {
	size: number, -- studs across at full size (twice the radius)
	height: number?, -- studs tall at full size, for the shapes with a height (as wide as `size` by default)
	from: number?, -- the part of its size it starts at (0.15)
	seconds: number?, -- to grow (0.4)
	hold: number?, -- at full size before it fades (0)
	fade: number?, -- to fade out (0.35)
	ease: ((number) -> number)?, -- the growth's curve (outQuint)
	color: Color3?,
	material: Enum.Material?, -- Neon (default), ForceField, SmoothPlastic...
	texture: string?, -- a VFX texture to wear (then lit by the scene; Transparency still fades it)
	transparency: number?, -- how see-through at its most solid (0.15)
	spin: number?, -- degrees it turns about its up while it lives
	rise: number?, -- studs it rises while it lives
	grow: number?, -- the part of its size it keeps growing to while it fades (1)
}

-- The meshes' own sizes in their file (x, y = across; z = up): the kit scales from these.
local MADE: { [string]: Vector3 } = {
	VfxRing = Vector3.new(2, 2, 0),
	VfxDome = Vector3.new(2, 2, 1),
	VfxTube = Vector3.new(2, 2, 2),
	VfxCone = Vector3.new(2, 2, 2),
	VfxSwirl = Vector3.new(2, 2, 2),
	VfxCrescent = Vector3.new(2, 2, 0),
	VfxSphere = Vector3.new(2, 2, 2),
	VfxSpikes = Vector3.new(2, 2, 2),
	VfxShard = Vector3.new(0.32, 0.22, 1),
	VfxRock = Vector3.new(1, 1, 0.75),
	VfxPage = Vector3.new(1, 0.12, 1.4),
}

local KEYS: { [string]: string } = {
	ring = "VfxRing",
	dome = "VfxDome",
	tube = "VfxTube",
	cone = "VfxCone",
	swirl = "VfxSwirl",
	crescent = "VfxCrescent",
	sphere = "VfxSphere",
	spikes = "VfxSpikes",
	shard = "VfxShard",
	rock = "VfxRock",
	page = "VfxPage",
}

local templates: { [string]: BasePart | false } = {}

-- The imported mesh, turned so its up is the part's +Y and sized as made (or false when not imported).
local function template(key: string): BasePart?
	local cached = templates[key]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local source = ModelLibrary.source(key)
	local part: BasePart? = nil
	if source and source:IsA("MeshPart") then
		local copy = source:Clone()
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		for _, child in ipairs(copy:GetChildren()) do
			child:Destroy()
		end
		-- (Studio's importer bakes each mesh's turn into its geometry and leaves the part square to the world, as the
		-- calibration cubes have shown for every props file: the mesh's up, Blender's Z, is the part's own Y)
		copy.CFrame = CFrame.new()
		part = copy
	end
	templates[key] = part or false
	return part
end

-- (for the harness: a mesh built in the place itself, from the same data, in place of the import)
function Shape.provide(key: string, part: BasePart)
	templates[key] = part
end

-- A plain part standing in for a shape before the Fx import (each roughly the mesh's outline).
local function standIn(kind: string): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "sphere" or kind == "dome" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "ring" or kind == "tube" or kind == "cone" or kind == "swirl" then
		p.Shape = Enum.PartType.Cylinder
	end
	return p
end

local function sizeFor(kind: string, across: number, height: number?): Vector3
	local made = MADE[KEYS[kind]]
	local scale = across / 2
	local tall = if made.Z > 0 then (height or across * made.Z / 2) else 0.05
	-- (the part's axes: x and z across, y up)
	return Vector3.new(made.X * scale, if made.Z > 0 then tall else 0.05, made.Y * scale)
end

-- A fresh copy of a shape at its made size (radius 1, its up the part's +Y), unparented, for an effect that moves it
-- itself: the mesh, or a stand-in (a page stands in as a thin card wearing the page on both faces).
function Shape.part(kind: Kind, texture: string?): BasePart
	local key = KEYS[kind]
	local source = template(key)
	local part: BasePart
	if source then
		part = source:Clone()
		if texture and part:IsA("MeshPart") then
			(part :: MeshPart).TextureID = Tex.id(texture)
		end
	else
		part = standIn(kind)
		if kind == "page" then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local d = Instance.new("Decal")
				d.Face = face
				d.Texture = Tex.id(texture or "VfxPage")
				d.Parent = part
			end
		end
	end
	local made = MADE[key]
	part.Size = if kind == "page"
		then Vector3.new(1, 1.4, 0.04)
		else Vector3.new(made.X, math.max(made.Z, 0.05), made.Y)
	part.Name = "DGVfx_" .. kind
	return part
end

-- Grows a shape at `at` (its up the shape's up), holds and fades it; returns the part (gone when done).
function Shape.grow(kind: Kind, at: CFrame, options: Options): BasePart
	local key = KEYS[kind]
	local source = template(key)
	local part: BasePart
	local turn = CFrame.identity
	if source then
		part = source:Clone()
	else
		part = standIn(kind)
		if (part :: Part).Shape == Enum.PartType.Cylinder then
			turn = CFrame.Angles(0, 0, math.rad(90))
		end
	end
	-- (before the Fx import only a ball stands in, for a sphere or a dome: a block or a disc in place of spikes, a ring
	-- or a crescent reads worse than nothing, so those stay unseen and the effect's other layers carry it)
	local hidden = not source and kind ~= "sphere" and kind ~= "dome"
	part.Name = "DGVfx_" .. kind
	part.Color = options.color or Color3.new(1, 1, 1)
	part.Material = options.material or Enum.Material.Neon
	if options.texture and part:IsA("MeshPart") then
		(part :: MeshPart).TextureID = Tex.id(options.texture)
		part.Material = options.material or Enum.Material.SmoothPlastic
	end
	local solid = options.transparency or 0.15
	part.Transparency = 1
	part.Parent = Emit.folder()
	local full = options.size
	local fullHeight = options.height
	local from = options.from or 0.15
	local seconds = options.seconds or 0.4
	local hold = options.hold or 0
	local fade = options.fade or 0.35
	local ease = options.ease or Ease.outQuint
	local spin = math.rad(options.spin or 0)
	local rise = options.rise or 0
	local after = options.grow or 1
	local total = seconds + hold + fade
	local function place(scale: number, t: number)
		local size = sizeFor(kind, full * scale, if fullHeight then fullHeight * scale else nil)
		if not source and (part :: Part).Shape == Enum.PartType.Cylinder then
			size = Vector3.new(size.Y, size.X, size.Z)
		elseif not source and (part :: Part).Shape == Enum.PartType.Ball then
			size = Vector3.new(size.X, size.X, size.X)
		end
		part.Size = size
		local u = if total > 0 then t / total else 1
		-- (a shape with a height stands on its foot at `at`: its middle half its height up)
		local lift = if MADE[key].Z > 0 and kind ~= "sphere" and kind ~= "spikes" then size.Y / 2 else 0
		part.CFrame = at * CFrame.new(0, lift + rise * u, 0) * CFrame.Angles(0, spin * u, 0) * turn
	end
	place(from, 0)
	local began = Clock.now()
	Clock.every(function(_, now)
		if not part.Parent then
			return false
		end
		local t = now - began
		if t < seconds then
			local u = ease(t / seconds)
			place(from + (1 - from) * u, t)
			part.Transparency = if hidden
				then 1
				else solid + (1 - solid) * (1 - math.min(1, t / math.max(seconds * 0.25, 1e-3)))
		elseif t < seconds + hold then
			place(1, t)
			part.Transparency = if hidden then 1 else solid
		elseif t < total then
			local u = (t - seconds - hold) / math.max(fade, 1e-3)
			place(1 + (after - 1) * Ease.outQuad(u), t)
			part.Transparency = if hidden then 1 else solid + (1 - solid) * Ease.inQuad(u)
		else
			part:Destroy()
			return false
		end
		return true
	end)
	return part
end

return Shape
