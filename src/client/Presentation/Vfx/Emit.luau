--!strict
-- The VFX kit's particles: emitters made from plain specs, a burst emitted once from a point (cleaned up after its
-- longest life), and an emitter held on a part or attachment (Emit.hold) until let go, when it stops making particles
-- and lets the last ones live out. Every emitter is unlit (its own light) unless the spec says otherwise, and is
-- watched by the kit's clock (held still with it for pictures).
--
-- A spec (all optional but tex):
--   tex     texture name (Vfx/Tex), grid = 8 | {x, y} for a flipbook, fps, mode = "Loop" | "OneShot" | "PingPong" |
--           "Random", blend (blend flipbook frames), startRandom
--   color   Color3 | ColorSequence | { {t, Color3}, ... }
--   size    number | { {t, size, envelope?}, ... };  alpha  { {t, transparency}, ... } (0 = solid)
--   life    {min, max} | number;  speed {min, max} | number;  spread  number | {x, y};  dir  Enum.NormalId
--   accel   Vector3;  drag  number;  rot {min, max};  spin {min, max};  squash { {t, v}, ... } | number
--   light   LightEmission (1 adds as light);  lit  LightInfluence (0 unlit);  bright  Brightness;  z  ZOffset
--   face    "camera" | "up" (camera, world up) | "along" (velocity parallel) | "flat" (velocity perpendicular)
--   locked  LockedToPart;  rate;  inherit  VelocityInheritance;  shape  Enum.ParticleEmitterShape, shapeStyle,
--   shapeInOut, shapePartial;  timeScale;  wind (WindAffectsDrag)

local Tex = require(script.Parent.Tex)
local Clock = require(script.Parent.Clock)

local Emit = {}

export type Spec = { [string]: any }

local function numberSeq(value: any, default: number): NumberSequence
	if value == nil then
		return NumberSequence.new(default)
	elseif type(value) == "number" then
		return NumberSequence.new(value)
	elseif typeof(value) == "NumberSequence" then
		return value
	end
	local keys = {}
	for _, p in ipairs(value) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	-- (a sequence must start at 0 and end at 1)
	if keys[1].Time > 0 then
		table.insert(keys, 1, NumberSequenceKeypoint.new(0, keys[1].Value, keys[1].Envelope))
	end
	if keys[#keys].Time < 1 then
		table.insert(keys, NumberSequenceKeypoint.new(1, keys[#keys].Value, keys[#keys].Envelope))
	end
	return NumberSequence.new(keys)
end

local function colorSeq(value: any): ColorSequence
	if value == nil then
		return ColorSequence.new(Color3.new(1, 1, 1))
	elseif typeof(value) == "Color3" then
		return ColorSequence.new(value)
	elseif typeof(value) == "ColorSequence" then
		return value
	end
	local keys = {}
	for _, p in ipairs(value) do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	if keys[1].Time > 0 then
		table.insert(keys, 1, ColorSequenceKeypoint.new(0, keys[1].Value))
	end
	if keys[#keys].Time < 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[#keys].Value))
	end
	return ColorSequence.new(keys)
end

local function range(value: any, default: number): NumberRange
	if value == nil then
		return NumberRange.new(default)
	elseif type(value) == "number" then
		return NumberRange.new(value)
	end
	return NumberRange.new(value[1], value[2] or value[1])
end

local FACES = {
	camera = Enum.ParticleOrientation.FacingCamera,
	up = Enum.ParticleOrientation.FacingCameraWorldUp,
	along = Enum.ParticleOrientation.VelocityParallel,
	flat = Enum.ParticleOrientation.VelocityPerpendicular,
}

-- The longest a particle of this spec lives (seconds).
function Emit.longest(spec: Spec): number
	local life = spec.life
	if life == nil then
		return 1
	elseif type(life) == "number" then
		return life
	end
	return life[2] or life[1]
end

-- A new emitter on `parent` from the spec (Rate 0 unless the spec gives one).
function Emit.make(parent: Instance, spec: Spec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = spec.name or "DGVfx"
	e.Texture = Tex.id(spec.tex or "VfxGlow")
	e.Color = colorSeq(spec.color)
	e.Size = numberSeq(spec.size, 1)
	e.Transparency = numberSeq(spec.alpha, 0)
	e.Lifetime = range(spec.life, 1)
	e.Speed = range(spec.speed, 0)
	local spread = spec.spread or 0
	e.SpreadAngle = if type(spread) == "number" then Vector2.new(spread, spread) else Vector2.new(spread[1], spread[2])
	e.EmissionDirection = spec.dir or Enum.NormalId.Top
	e.Acceleration = spec.accel or Vector3.zero
	e.Drag = spec.drag or 0
	e.Rotation = range(spec.rot, 0)
	e.RotSpeed = range(spec.spin, 0)
	if spec.squash ~= nil then
		e.Squash = numberSeq(spec.squash, 0)
	end
	e.LightEmission = spec.light or 1
	e.LightInfluence = spec.lit or 0
	e.Brightness = spec.bright or 1
	e.ZOffset = spec.z or 0
	e.Orientation = FACES[spec.face or "camera"] or Enum.ParticleOrientation.FacingCamera
	e.LockedToPart = spec.locked == true
	e.Rate = spec.rate or 0
	e.VelocityInheritance = spec.inherit or 0
	e.TimeScale = spec.timeScale or 1
	e.WindAffectsDrag = spec.wind == true
	if spec.shape then
		e.Shape = spec.shape
		e.ShapeStyle = spec.shapeStyle or Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = spec.shapeInOut or Enum.ParticleEmitterShapeInOut.Outward
		e.ShapePartial = spec.shapePartial or 1
	end
	local grid = spec.grid
	if grid then
		if type(grid) == "number" then
			e.FlipbookLayout = if grid == 2
				then Enum.ParticleFlipbookLayout.Grid2x2
				elseif grid == 4 then Enum.ParticleFlipbookLayout.Grid4x4
				else Enum.ParticleFlipbookLayout.Grid8x8
		else
			e.FlipbookLayout = Enum.ParticleFlipbookLayout.Custom
			e.FlipbookSizeX = grid[1]
			e.FlipbookSizeY = grid[2]
		end
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[spec.mode or "Loop"]
		e.FlipbookFramerate = range(spec.fps, 30)
		e.FlipbookStartRandom = spec.startRandom == true
		e.FlipbookBlendFrames = spec.blend ~= false
	end
	e.Parent = parent
	Clock.watch(e)
	return e
end

-- The folder every loose effect part lives in (in the camera: this client's only, never replicated, never hit).
function Emit.folder(): Instance
	local camera = workspace.CurrentCamera
	local folder = camera:FindFirstChild("DGVfx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DGVfx"
		folder.Parent = camera
	end
	return folder :: Instance
end

-- An unseen anchored point to emit from (cleaned up by whoever made it).
function Emit.point(at: CFrame | Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = "DGVfxPoint"
	p.Size = size or Vector3.new(0.05, 0.05, 0.05)
	p.CFrame = if typeof(at) == "CFrame" then at else CFrame.new(at)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = Emit.folder()
	return p
end

-- Emits `count` particles of the spec once from `at` (its up the emitters' Top), and cleans up after the last dies.
-- With several specs, each with its own count: Emit.burst(at, { {spec, count}, ... }).
function Emit.burst(at: CFrame | Vector3, spec: Spec | { any }, count: number?, size: Vector3?): Part
	local holder = Emit.point(at, size)
	local list = if (spec :: any).tex ~= nil or (spec :: any)[1] == nil
		then { { spec, count or 1 } }
		else spec :: { any }
	local longest = 0
	for _, entry in ipairs(list) do
		local s, n = entry[1], entry[2]
		local e = Emit.make(holder, s)
		e:Emit(n)
		longest = math.max(longest, Emit.longest(s))
	end
	Clock.after(longest + 0.25, function()
		holder:Destroy()
	end)
	return holder
end

-- An emitter held on `parent` (a part or an attachment), making particles at its rate until the returned stop is
-- called; then it makes no more and goes once the last has lived out.
function Emit.hold(parent: Instance, spec: Spec): (ParticleEmitter, () -> ())
	local e = Emit.make(parent, spec)
	local stopped = false
	return e,
		function()
			if stopped then
				return
			end
			stopped = true
			e.Enabled = false
			Clock.after(Emit.longest(spec) + 0.25, function()
				e:Destroy()
			end)
		end
end

return Emit
