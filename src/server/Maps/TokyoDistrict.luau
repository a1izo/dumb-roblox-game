-- Map 3: Tokyo district at night. Two avenues cross in the middle; each block holds a
-- building with an open interior (konbini, metro station, net cafe, koban, ramen shop).
-- Local coordinates: x -110..110, z -90..90.

local Style = require(script.Parent.Style)

local TokyoDistrict = {}

TokyoDistrict.id = "TokyoDistrict"
TokyoDistrict.name = "Tokyo District"

local ASPHALT = Color3.fromRGB(42, 42, 48)
local PAVEMENT = Color3.fromRGB(64, 64, 70)
local SHOP_WALL = Color3.fromRGB(118, 114, 108)

-- Shop with doors and a roof. doors: { side = { {center, width} } } where north/south
-- centres are measured from x1 and west/east centres from z1.
local function shop(b, x1: number, z1: number, x2: number, z2: number, doors, wallColor: Color3, floorColor: Color3)
	local h = 10
	b:floor(x1, z1, x2, z2, floorColor, Enum.Material.Marble, 0.12)
	b:wallDoors(x1, z1, x2, z1, h, doors.north or {}, wallColor, Enum.Material.Concrete)
	b:wallDoors(x1, z2, x2, z2, h, doors.south or {}, wallColor, Enum.Material.Concrete)
	b:wallDoors(x1, z1, x1, z2, h, doors.west or {}, wallColor, Enum.Material.Concrete)
	b:wallDoors(x2, z1, x2, z2, h, doors.east or {}, wallColor, Enum.Material.Concrete)
	b:block(
		(x1 + x2) / 2,
		h + 0.5,
		(z1 + z2) / 2,
		x2 - x1 + 2,
		1,
		z2 - z1 + 2,
		Color3.fromRGB(55, 55, 60),
		Enum.Material.Concrete
	)
	b:light((x1 + x2) / 2, h - 0.2, (z1 + z2) / 2, Color3.fromRGB(235, 245, 255), 30, 1.2)
end

local function neon(b, x: number, y: number, z: number, rot: number, w: number, text: string, color: Color3)
	b:sign(x, y, z, rot, w, 3, text, color, Color3.fromRGB(12, 12, 18), Enum.Font.Bangers)
end

local function dress(b)
	-- Ground: asphalt avenues, pavement blocks, boundary
	b:floor(-110, -90, 110, 90, ASPHALT, Enum.Material.Asphalt)
	b:block(-59, 0.05, -49, 102, 0.1, 82, PAVEMENT, Enum.Material.Pavement)
	b:block(59, 0.05, -49, 102, 0.1, 82, PAVEMENT, Enum.Material.Pavement)
	b:block(-59, 0.05, 49, 102, 0.1, 82, PAVEMENT, Enum.Material.Pavement)
	b:block(59, 0.05, 49, 102, 0.1, 82, PAVEMENT, Enum.Material.Pavement)
	b:enclose(-110, -90, 110, 90, 40, Color3.fromRGB(35, 35, 42), Enum.Material.Concrete)

	-- Road markings and crosswalks
	for i = 0, 6 do
		b:block(-6 + i * 2, 0.06, -12, 1, 0.12, 4, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		b:block(-6 + i * 2, 0.06, 12, 1, 0.12, 4, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		b:block(-12, 0.06, -6 + i * 2, 4, 0.12, 1, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		b:block(12, 0.06, -6 + i * 2, 4, 0.12, 1, Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
	end
	for _, z in ipairs({ -70, -50, -30, 30, 50, 70 }) do
		b:block(0, 0.03, z, 0.5, 0.06, 6, Color3.fromRGB(230, 200, 60), Enum.Material.SmoothPlastic)
	end
	for _, x in ipairs({ -90, -70, -50, -30, 30, 50, 70, 90 }) do
		b:block(x, 0.03, 0, 6, 0.06, 0.5, Color3.fromRGB(230, 200, 60), Enum.Material.SmoothPlastic)
	end

	-- Tall buildings at the corners
	b:building(-85, -70, 40, 36, 36, Color3.fromRGB(60, 62, 70), Color3.fromRGB(255, 220, 150))
	b:building(85, -70, 40, 36, 40, Color3.fromRGB(70, 66, 74), Color3.fromRGB(170, 210, 255))
	b:building(-85, 70, 40, 36, 30, Color3.fromRGB(66, 52, 70), Color3.fromRGB(255, 150, 220))
	b:building(90, 72, 36, 32, 34, Color3.fromRGB(58, 64, 66), Color3.fromRGB(255, 230, 170))
	neon(b, -64.8, 16, -62, -90, 12, "24H HOTEL", Color3.fromRGB(255, 90, 200))
	neon(b, 64.8, 18, -62, 90, 12, "CAPSULE", Color3.fromRGB(90, 220, 255))
	neon(b, -64.8, 14, 62, -90, 12, "KARAOKE", Color3.fromRGB(255, 220, 60))

	-- Konbini (north-west block)
	shop(b, -60, -50, -24, -24, {
		south = { { 18, 8 } },
		east = { { 13, 6 } },
	}, SHOP_WALL, Color3.fromRGB(230, 230, 225))
	b:shelf(-42, -44, 0, 10, Color3.fromRGB(230, 230, 230))
	b:shelf(-42, -34, 0, 10, Color3.fromRGB(230, 230, 230))
	b:block(-42, 3.5, -48.6, 16, 7, 1.6, Color3.fromRGB(170, 220, 255), Enum.Material.Neon, { CanQuery = false })
	b:counter(-30, -30, 0, 8, Color3.fromRGB(90, 150, 90))
	neon(b, -42, 12.5, -23.2, 180, 16, "KONBINI 24", Color3.fromRGB(120, 255, 140))

	-- West alley with a dumpster
	b:block(-104, 2, -40, 3, 4, 6, Color3.fromRGB(40, 90, 60), Enum.Material.Metal)
	b:crate(-96, -46, 3)
	b:crate(-100, -20, 4)
	b:crate(-80, -14, 3)

	-- Metro station (north-east block)
	shop(b, 24, -50, 60, -24, {
		south = { { 18, 8 } },
		west = { { 13, 6 } },
	}, Color3.fromRGB(180, 185, 195), Color3.fromRGB(200, 200, 205))
	for _, x in ipairs({ 32, 38, 46, 52 }) do
		b:block(x, 1.5, -36, 1, 3, 2, Color3.fromRGB(120, 125, 135), Enum.Material.Metal)
	end
	b:bench(34, -47.5, 180)
	b:bench(44, -47.5, 180)
	b:sign(
		42,
		6,
		-49.3,
		180,
		10,
		4,
		"LINE 3  >>  SHIBUYA",
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(30, 90, 60),
		Enum.Font.GothamBold
	)
	neon(b, 42, 12.5, -23.2, 180, 12, "METRO", Color3.fromRGB(90, 200, 255))

	-- Phone booth and vending machines on the north-east pavement
	b:block(20, 8.2, -14, 6.5, 0.4, 4.5, Color3.fromRGB(170, 30, 30), Enum.Material.SmoothPlastic)
	b:block(17, 4, -15.8, 0.4, 8, 0.4, Color3.fromRGB(170, 30, 30), Enum.Material.Metal)
	b:block(23, 4, -15.8, 0.4, 8, 0.4, Color3.fromRGB(170, 30, 30), Enum.Material.Metal)
	b:vending(70, -12, 180)
	b:vending(76, -12, 180, Color3.fromRGB(40, 90, 180))

	-- Net cafe (south-west block)
	shop(b, -60, 24, -24, 50, {
		north = { { 18, 8 } },
		east = { { 13, 6 } },
	}, Color3.fromRGB(60, 60, 75), Color3.fromRGB(70, 70, 85))
	for _, x in ipairs({ -52, -44, -36 }) do
		b:desk(x, 47.5, 0, Color3.fromRGB(50, 50, 60))
		b:chair(x, 45, 180)
	end
	b:table(-30, 44, 0, 4, 3)
	neon(b, -42, 12.5, 23.2, 0, 14, "NET CAFE", Color3.fromRGB(80, 255, 230))
	b:vending(-70, 12, 0)

	-- Koban police box (south-east block): the headquarters of this map
	shop(b, 16, 22, 48, 46, {
		north = { { 16, 8 } },
	}, Color3.fromRGB(225, 225, 230), Color3.fromRGB(150, 150, 160))
	b:table(32, 42, 0, 5, 3)
	b:cabinet(46, 25, 90)
	local lamp =
		b:block(32, 11.6, 22.5, 1.4, 1.2, 1.4, Color3.fromRGB(255, 40, 40), Enum.Material.Neon, { CanQuery = false })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 40)
	glow.Range = 18
	glow.Brightness = 2
	glow.Parent = lamp
	neon(b, 32, 13.5, 21.2, 0, 10, "KOBAN", Color3.fromRGB(255, 255, 255))

	-- Ramen shop (south-east block)
	shop(b, 56, 24, 92, 50, {
		north = { { 18, 8 } },
		west = { { 13, 6 } },
	}, Color3.fromRGB(150, 60, 40), Color3.fromRGB(120, 90, 60))
	b:counter(74, 44, 0, 16, Color3.fromRGB(150, 110, 70))
	for _, x in ipairs({ 68, 72, 76, 80 }) do
		b:block(x, 1, 41, 1.2, 2, 1.2, Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	end
	neon(b, 74, 12.5, 23.2, 0, 12, "RAMEN", Color3.fromRGB(255, 120, 60))

	-- Parked cars and street lamps
	b:car(-4, -60, 0, Color3.fromRGB(230, 230, 230))
	b:car(4, 60, 180, Color3.fromRGB(40, 60, 140))
	b:car(-60, 4, 90, Color3.fromRGB(180, 30, 40))
	b:car(60, -4, -90, Color3.fromRGB(30, 30, 30))
	b:car(-90, -4, 90, Color3.fromRGB(230, 200, 60))
end

-- Noir pass: wet streets, lamps with hard shadows, steam from the grates, neon trim.
local function noir(b)
	local lamps = {
		{ -12, -30, 90 },
		{ 12, -30, -90 },
		{ -12, 30, 90 },
		{ 12, 30, -90 },
		{ -40, -12, 180 },
		{ 40, 12, 0 },
		{ -80, 12, 0 },
		{ 80, -12, 180 },
		{ -40, 12, 0 },
		{ 40, -12, 180 },
	}
	for index, spot in ipairs(lamps) do
		Style.lampPost(b, spot[1], spot[2], {
			rot = spot[3],
			shadows = index <= 6,
			flicker = index == 4 or index == 9,
			color = Color3.fromRGB(255, 205, 150),
		})
	end
	for _, spot in ipairs({
		{ -6, -40, 6, 4 },
		{ 8, -72, 5, 3 },
		{ -30, 6, 7, 3 },
		{ 50, -6, 6, 3 },
		{ 82, 5, 5, 3 },
		{ -78, -4, 6, 3 },
		{ 4, 48, 6, 4 },
		{ -20, -7, 4, 3 },
		{ 22, 8, 5, 3 },
		{ -5, 78, 6, 3 },
	}) do
		Style.puddle(b, spot[1], spot[2], spot[3], spot[4])
	end
	Style.steamVent(b, -100, -62)
	Style.steamVent(b, 100, 22)
	Style.steamVent(b, -22, -84)
	Style.steamVent(b, 26, 84)
	Style.neonStrip(b, -42, 10.8, -23.1, 30, 0.2, 0.2, Color3.fromRGB(120, 255, 140), true)
	Style.neonStrip(b, 42, 10.8, -23.1, 30, 0.2, 0.2, Color3.fromRGB(90, 200, 255))
	Style.neonStrip(b, -42, 10.8, 23.1, 30, 0.2, 0.2, Color3.fromRGB(80, 255, 230))
	Style.neonStrip(b, 74, 10.8, 23.1, 30, 0.2, 0.2, Color3.fromRGB(255, 120, 60), true)
	Style.skyline(b, 110, 90, 37)
end

-- The gameplay contract: stations, spawns, sheets, drop points, hoods, areas, the tip box
-- and the board. MapContract checks it; the dressing above must leave these places clear.
function TokyoDistrict.layout()
	return {
		stations = {
			{ type = "Camera", name = "Konbini CCTV", x = -56, z = -40, rot = -90 },
			{ type = "Camera", name = "Metro Security Cams", x = 56, z = -40, rot = 90 },
			{ type = "Phone", name = "Phone Booth", x = 20, z = -14, rot = 180 },
			{ type = "Phone", name = "Net Cafe Terminal", x = -56, z = 36, rot = -90 },
			{ type = "Fingerprint", name = "Koban Print Kit", x = 20, z = 40, rot = -90 },
			{ type = "Fingerprint", name = "Alley Evidence Kit", x = -90, z = -30, rot = -90 },
			{ type = "Camera", name = "Crossing Camera", x = 14, z = 16, rot = 0 },
			{ type = "Phone", name = "Ramen Shop Phone", x = 88, z = 32, rot = 90 },
		},
		tipBox = { x = 44, z = 40, rot = 90 },
		board = { x = 15.2, y = 5, z = 34, rot = 90, w = 12, h = 7 },
		spawns = {
			{ x = -20, z = 0 },
			{ x = 20, z = 0 },
			{ x = 0, z = -20 },
			{ x = 0, z = 20 },
			{ x = -30, z = 4 },
			{ x = 30, z = -4 },
			{ x = 4, z = -30 },
			{ x = -4, z = 30 },
			{ x = -40, z = -4 },
			{ x = 40, z = 4 },
			{ x = -4, z = -40 },
			{ x = 4, z = 40 },
		},
		sheets = {
			{ x = -30, y = 3.55, z = -30 },
			{ x = -30, y = 2.8, z = 44 },
			{ x = 80, y = 3.55, z = 44 },
			{ x = 32, y = 2.8, z = 42 },
		},
		dropPoints = {
			{ name = "Behind the alley dumpster", x = -107.5, z = -40 },
			{ name = "Metro stairwell corner", x = 58, z = -27 },
			{ name = "Behind the karaoke bar", x = -60, z = 86 },
		},
		hoods = {
			{ x = -20, y = 0.6, z = -30 },
			{ x = 30, y = 0.6, z = -60 },
			{ x = -40, y = 0.6, z = 60 },
			{ x = 50, y = 0.6, z = 60 },
		},
		areas = {
			{ name = "the Konbini", x = -42, z = -37 },
			{ name = "the Metro Station", x = 42, z = -37 },
			{ name = "the Net Cafe", x = -42, z = 37 },
			{ name = "the Koban", x = 32, z = 34 },
			{ name = "the Ramen Shop", x = 74, z = 37 },
			{ name = "the west alley", x = -95, z = -25 },
			{ name = "the crossing", x = 0, z = 0 },
			{ name = "the north avenue", x = 0, z = -55 },
			{ name = "the south avenue", x = 0, z = 55 },
			{ name = "the east street", x = 65, z = 0 },
			{ name = "the west street", x = -65, z = 0 },
		},
	}
end

function TokyoDistrict.build(b)
	dress(b)
	noir(b)
	return TokyoDistrict.layout()
end

return TokyoDistrict
