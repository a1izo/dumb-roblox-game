-- Set dressing on top of the map builder for the part-built meeting room: neon strips and the
-- Specters' walkway round its walls. None of it changes gameplay: dressing never collides with
-- players or blocks the raycasts used for sight lines (CanQuery = false).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Style = {}

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
