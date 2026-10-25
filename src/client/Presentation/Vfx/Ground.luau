--!strict
-- The VFX kit's ground: where the floor is under a point, marks laid on it (a scorch, cracks, a glowing circle) that
-- fade, and debris thrown up by a landing that falls, bounces and sinks away.

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)
local Emit = require(script.Parent.Emit)
local Tex = require(script.Parent.Tex)

local Ground = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

-- The floor under `at` (position and normal), looking down `depth` studs and ignoring `ignore` (characters, the
-- camera's effects); the point `depth` below and straight up when nothing is there.
function Ground.at(at: Vector3, ignore: { Instance }?, depth: number?): (Vector3, Vector3)
	local list = { workspace.CurrentCamera }
	for _, item in ipairs(ignore or {}) do
		table.insert(list, item)
	end
	params.FilterDescendantsInstances = list
	local d = depth or 12
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -(d + 1), 0), params)
	if hit then
		return hit.Position, hit.Normal
	end
	return at - Vector3.new(0, d, 0), Vector3.yAxis
end

-- A texture laid on the floor at `at` (normal `normal`), `size` studs across, turned `turn` degrees: in over `fadeIn`,
-- held `hold`, out over `fadeOut`. Lit by the scene (a scorch, cracks); colour multiplies the texture.
function Ground.mark(
	at: Vector3,
	normal: Vector3,
	tex: string,
	size: number,
	color: Color3,
	hold: number,
	options: {
		fadeIn: number?,
		fadeOut: number?,
		turn: number?,
		transparency: number?,
	}?
)
	local o = options or {}
	local up = normal.Unit
	local side = up:Cross(if math.abs(up.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
	local look = side:Cross(up)
	local cf = CFrame.fromMatrix(at + up * 0.03, side, up, -look)
		* CFrame.Angles(0, math.rad(o.turn or math.random() * 360), 0)
	local pad = Emit.point(cf, Vector3.new(size, 0.02, size))
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = Tex.id(tex)
	decal.Color3 = color
	decal.Transparency = 1
	decal.Parent = pad
	local solid = o.transparency or 0
	local fadeIn = o.fadeIn or 0.05
	local fadeOut = o.fadeOut or 0.8
	Clock.tween(fadeIn, Ease.outQuad, function(u)
		decal.Transparency = 1 - (1 - solid) * u
	end, function()
		Clock.after(hold, function()
			Clock.tween(fadeOut, Ease.inQuad, function(u)
				decal.Transparency = solid + (1 - solid) * u
			end, function()
				pad:Destroy()
			end)
		end)
	end)
end

-- Chunks of the floor thrown up round `at`: `count` pieces of `color` and `material`, flung out and up at `speed`,
-- falling under gravity, spinning, then sinking away after `life` seconds. Client-side physics, never touching bodies.
function Ground.debris(
	at: Vector3,
	count: number,
	options: {
		color: Color3?,
		material: Enum.Material?,
		size: number?,
		speed: number?,
		life: number?,
		ring: number?,
	}?
)
	local o = options or {}
	local rng = Random.new()
	local size = o.size or 0.8
	local speed = o.speed or 26
	local life = o.life or 2.2
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Name = "DGVfxDebris"
		local s = size * rng:NextNumber(0.5, 1.2)
		p.Size = Vector3.new(s, s * rng:NextNumber(0.5, 0.9), s * rng:NextNumber(0.6, 1))
		local a = rng:NextNumber(0, math.pi * 2)
		local r = o.ring or 1
		p.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, s * 0.5, math.sin(a) * r))
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Color = o.color or Color3.fromRGB(70, 70, 74)
		p.Material = o.material or Enum.Material.Slate
		p.Anchored = false
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		-- (the server's group for them: the world, never a body: Services/CollisionGroups)
		pcall(function()
			p.CollisionGroup = "VfxDebris"
		end)
		p.Parent = Emit.folder()
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		p.AssemblyLinearVelocity = out * speed * rng:NextNumber(0.4, 1)
			+ Vector3.new(0, speed * rng:NextNumber(0.7, 1.3), 0)
		p.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		Clock.after(life * rng:NextNumber(0.8, 1.2), function()
			if not p.Parent then
				return
			end
			p.Anchored = true
			local from = p.CFrame
			local s0 = p.Size
			Clock.tween(0.5, Ease.inQuad, function(u)
				p.Size = s0 * (1 - u * 0.9)
				p.CFrame = from - Vector3.new(0, u * s0.Y, 0)
			end, function()
				p:Destroy()
			end)
		end)
	end
end

return Ground
