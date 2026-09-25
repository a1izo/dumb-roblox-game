-- Noir set dressing on top of the map builder: lamp posts with hard shadows, puddles, steam,
-- neon strips, window blinds that throw striped light, and a skyline beyond the walls.
-- None of it changes gameplay: dressing never collides with players or blocks the
-- raycasts used for sight lines (CanQuery = false), except lamp poles, which are thin.
--
-- Budget per venue: at most 8 shadow-casting lights (lamp posts with shadows + blinds).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local Style = {}

local IRON = Color3.fromRGB(26, 26, 30)
local LAMP = Color3.fromRGB(255, 214, 160)

local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function decor(extra: { [string]: any }?): { [string]: any }
	local props = table.clone(DECOR)
	if extra then
		for key, value in pairs(extra) do
			props[key] = value
		end
	end
	return props
end

export type LampOptions = {
	shadows: boolean?,
	flicker: boolean?,
	color: Color3?,
	height: number?,
	rot: number?, -- which way the arm reaches (degrees, like the builder)
}

-- A curved street lamp: pole, arm and a hooded head that throws a cone of light down.
function Style.lampPost(b, x: number, z: number, options: LampOptions?)
	local height = if options and options.height then options.height else 13
	local rot = if options and options.rot then options.rot else 0
	local color = if options and options.color then options.color else LAMP
	-- The Blender lamp post, when imported: the light hangs in its lantern.
	local model = b:placeModel("LampPost", x, z, rot)
	if model then
		for _, bulb in ipairs(ModelLibrary.glowParts(model)) do
			bulb.Color = color
			Create("SpotLight", {
				Face = Enum.NormalId.Bottom,
				Angle = 75,
				Range = height + 14,
				Brightness = 3.2,
				Color = color,
				Shadows = options ~= nil and options.shadows == true,
				Parent = bulb,
			})
			Create("PointLight", { Color = color, Range = 8, Brightness = 0.6, Shadows = false, Parent = bulb })
			if options and options.flicker then
				bulb:AddTag("LFlicker")
			end
			return bulb
		end
	end
	b:block(x, height / 2, z, 0.45, height, 0.45, IRON, Enum.Material.Metal, { CastShadow = false })
	b:block(x, 0.4, z, 1.1, 0.8, 1.1, IRON, Enum.Material.Metal)
	local base = b:cf(x, height, z, rot)
	b:part(Vector3.new(0.3, 0.3, 2.6), base * CFrame.new(0, 0, -1.2), IRON, Enum.Material.Metal, decor())
	local head =
		b:part(Vector3.new(1.4, 0.5, 1.4), base * CFrame.new(0, -0.2, -2.4), IRON, Enum.Material.Metal, decor())
	local bulb =
		b:part(Vector3.new(0.9, 0.2, 0.9), base * CFrame.new(0, -0.5, -2.4), color, Enum.Material.Neon, decor())
	Create("SpotLight", {
		Face = Enum.NormalId.Bottom,
		Angle = 75,
		Range = height + 14,
		Brightness = 3.2,
		Color = color,
		Shadows = options ~= nil and options.shadows == true,
		Parent = bulb,
	})
	Create("PointLight", { Color = color, Range = 8, Brightness = 0.6, Shadows = false, Parent = head })
	if options and options.flicker then
		bulb:AddTag("LFlicker")
	end
	return bulb
end

-- A flat, dark, reflective puddle on the ground.
function Style.puddle(b, x: number, z: number, w: number, d: number, y: number?)
	b:part(
		Vector3.new(0.04, w, d),
		CFrame.new(x, (y or 0) + 0.12, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(16, 16, 22),
		Enum.Material.Glass,
		decor({ Shape = Enum.PartType.Cylinder, Reflectance = 0.35, Transparency = 0.15 })
	)
end

-- Steam rising from a grate in the ground.
function Style.steamVent(b, x: number, z: number)
	local grate = b:block(x, 0.08, z, 2.4, 0.16, 2.4, Color3.fromRGB(30, 30, 34), Enum.Material.DiamondPlate, decor())
	local steam = Create("ParticleEmitter", {
		EmissionDirection = Enum.NormalId.Top,
		Rate = 6,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(12, 12),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 7) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 210)),
		LightInfluence = 1,
		RotSpeed = NumberRange.new(-20, 20),
		Parent = grate,
	})
	local texture = Assets.texture("Smoke")
	if texture ~= "" then
		steam.Texture = texture
	end
	return grate
end

-- An imported Blender prop, standing on the floor. Only placed when imported: these are
-- extra street dressing with no part-built stand-in.
function Style.prop(b, key: string, x: number, z: number, rot: number?)
	return b:placeModel(key, x, z, rot or 0)
end

-- A thin neon tube (along x when sx is the long side).
function Style.neonStrip(
	b,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	flicker: boolean?
)
	local strip = b:block(x, y, z, sx, sy, sz, color, Enum.Material.Neon, decor())
	Create("PointLight", {
		Color = color,
		Range = 12,
		Brightness = 1.2,
		Shadows = false,
		Parent = strip,
	})
	if flicker then
		strip:AddTag("LFlicker")
	end
	return strip
end

-- A window with blinds on the inside of a wall. rot faces into the room. Light from outside
-- comes through the slats and throws stripes across the floor.
function Style.blinds(b, x: number, y: number, z: number, rot: number, w: number, h: number, shadows: boolean?)
	local base = b:cf(x, y, z, rot)
	-- the pale "moonlit" window glass on the wall
	b:part(
		Vector3.new(w, h, 0.05),
		base * CFrame.new(0, 0, 0.05),
		Color3.fromRGB(150, 170, 210),
		Enum.Material.Neon,
		decor({ Transparency = 0.35 })
	)
	local slats = math.floor(h / 0.45)
	for index = 0, slats - 1 do
		b:part(
			Vector3.new(w, 0.22, 0.04),
			base * CFrame.new(0, -h / 2 + 0.22 + index * 0.45, -0.7) * CFrame.Angles(math.rad(25), 0, 0),
			Color3.fromRGB(34, 32, 30),
			Enum.Material.SmoothPlastic,
			decor({ CastShadow = true })
		)
	end
	local source = b:part(
		Vector3.new(0.2, 0.2, 0.2),
		base * CFrame.new(0, h * 0.35, -0.3),
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		decor({ Transparency = 1 })
	)
	Create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = 70,
		Range = 38,
		Brightness = 4,
		Color = Color3.fromRGB(175, 195, 235),
		Shadows = shadows ~= false,
		Parent = source,
	})
end

-- Tall silhouettes with a few lit windows, in a ring outside the map's walls. They only
-- fill the sky; nothing can reach or hit them.
function Style.skyline(b, halfX: number, halfZ: number, seed: number)
	local rng = Random.new(seed)
	local count = 26
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local reach = rng:NextNumber(1.35, 1.9)
		local x = math.sin(angle) * halfX * reach
		local z = math.cos(angle) * halfZ * reach
		local w = rng:NextNumber(18, 34)
		local h = rng:NextNumber(40, 110)
		local tower = b:block(x, h / 2 - 2, z, w, h, w, Color3.fromRGB(14, 14, 20), Enum.Material.Concrete, decor())
		tower.Name = "Skyline"
		for _ = 1, rng:NextInteger(2, 6) do
			local wy = rng:NextNumber(10, h - 6)
			local face = rng:NextInteger(0, 3)
			local towards = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0))
			local offset = towards.LookVector * (w / 2 + 0.1)
			local side = towards.RightVector * rng:NextNumber(-w / 3, w / 3)
			local glow = if face == 0 then Color3.fromRGB(255, 205, 140) else Color3.fromRGB(140, 170, 230)
			b:part(
				Vector3.new(rng:NextNumber(2, 5), 1.4, 0.1),
				CFrame.lookAt(Vector3.new(x, wy, z) + offset + side, Vector3.new(0, wy, 0)),
				glow,
				Enum.Material.Neon,
				decor()
			)
		end
	end
end

-- A walkway ring high on the walls of a square room (half = half the room's width), where
-- Specters watch the meeting. Returns standing spots facing the middle. With spotsOnly the
-- walkway itself is not built (a Blender scene has it).
function Style.gallery(b, half: number, y: number, depth: number, spots: number, spotsOnly: boolean?): { CFrame }
	local color = Color3.fromRGB(22, 20, 24)
	local inner = half - depth / 2
	if spotsOnly then
		return Style.gallerySpots(b, inner, y, spots)
	end
	for _, side in ipairs({ { 0, -inner, half * 2, depth }, { 0, inner, half * 2, depth } }) do
		b:block(side[1], y, side[2], side[3], 0.5, side[4], color, Enum.Material.Metal, decor({ CastShadow = true }))
	end
	for _, side in ipairs({ { -inner, 0, depth, half * 2 - depth * 2 }, { inner, 0, depth, half * 2 - depth * 2 } }) do
		b:block(side[1], y, side[2], side[3], 0.5, side[4], color, Enum.Material.Metal, decor({ CastShadow = true }))
	end
	-- railing
	local rail = half - depth
	for _, edge in ipairs({
		{ 0, -rail, half * 2 - depth * 2, 0.2 },
		{ 0, rail, half * 2 - depth * 2, 0.2 },
		{ -rail, 0, 0.2, half * 2 - depth * 2 },
		{ rail, 0, 0.2, half * 2 - depth * 2 },
	}) do
		b:block(edge[1], y + 1.6, edge[2], edge[3], 0.2, edge[4], color, Enum.Material.Metal, decor())
	end
	return Style.gallerySpots(b, inner, y, spots)
end

function Style.gallerySpots(b, inner: number, y: number, spots: number): { CFrame }
	local list = {}
	for index = 1, spots do
		local angle = (index - 1) / spots * math.pi * 2
		local r = inner
		local px = math.clamp(math.sin(angle) * r * 1.5, -inner, inner)
		local pz = math.clamp(math.cos(angle) * r * 1.5, -inner, inner)
		local at = b:worldPos(px, y + 0.25, pz)
		local centre = b:worldPos(0, y + 0.25, 0)
		table.insert(list, CFrame.lookAt(at, centre))
	end
	return list
end

return Style
