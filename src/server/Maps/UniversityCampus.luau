-- Map 2: University campus. An outdoor quad with a fountain surrounded by the library,
-- the lecture hall, the science lab, the cafeteria and the campus security office.
-- Local coordinates: x -110..110, z -90..90.

local SceneBuilder = require(script.Parent.SceneBuilder)
local Style = require(script.Parent.Style)

local UniversityCampus = {}

UniversityCampus.id = "UniversityCampus"
UniversityCampus.name = "University Campus"

local BRICK = Color3.fromRGB(96, 52, 44)
local STONE = Color3.fromRGB(120, 116, 108)
local ROOF = Color3.fromRGB(34, 30, 30)
local PATH = Color3.fromRGB(78, 76, 76)

-- A building with doors and a roof. doors: { side = { {center, width} } } where
-- north/south centres are measured from x1 and west/east centres from z1.
local function building(
	b,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	h: number,
	doors,
	wallColor: Color3,
	floorColor: Color3,
	floorMaterial: Enum.Material
)
	b:floor(x1, z1, x2, z2, floorColor, floorMaterial, 0.02)
	b:wallDoors(x1, z1, x2, z1, h, doors.north or {}, wallColor, Enum.Material.Brick)
	b:wallDoors(x1, z2, x2, z2, h, doors.south or {}, wallColor, Enum.Material.Brick)
	b:wallDoors(x1, z1, x1, z2, h, doors.west or {}, wallColor, Enum.Material.Brick)
	b:wallDoors(x2, z1, x2, z2, h, doors.east or {}, wallColor, Enum.Material.Brick)
	b:block((x1 + x2) / 2, h + 0.5, (z1 + z2) / 2, x2 - x1 + 2, 1, z2 - z1 + 2, ROOF, Enum.Material.Slate)
	local light = Color3.fromRGB(255, 240, 215)
	b:light((x1 + x2) / 2 - (x2 - x1) / 4, h - 0.2, (z1 + z2) / 2, light, 28, 1)
	b:light((x1 + x2) / 2 + (x2 - x1) / 4, h - 0.2, (z1 + z2) / 2, light, 28, 1)
end

local function dress(b)
	-- Ground, boundary hedge and paths
	b:floor(-110, -90, 110, 90, Color3.fromRGB(36, 54, 38), Enum.Material.Grass)
	b:enclose(-110, -90, 110, 90, 12, Color3.fromRGB(24, 40, 28), Enum.Material.Grass)
	b:block(0, 0.05, -5, 12, 0.1, 118, PATH, Enum.Material.Pavement)
	b:block(0, 0.05, 0, 216, 0.1, 12, PATH, Enum.Material.Pavement)
	b:block(-75, 0.05, -35, 10, 0.1, 10, PATH, Enum.Material.Pavement)
	b:block(75, 0.05, -35, 10, 0.1, 10, PATH, Enum.Material.Pavement)
	b:block(75, 0.05, 35, 10, 0.1, 10, PATH, Enum.Material.Pavement)
	b:block(-75, 0.05, 35, 10, 0.1, 10, PATH, Enum.Material.Pavement)

	-- Library (north-west)
	building(b, -100, -80, -50, -40, 14, {
		south = { { 25, 10 } },
		east = { { 20, 8 } },
	}, BRICK, Color3.fromRGB(120, 95, 70), Enum.Material.WoodPlanks)
	b:shelf(-80, -70, 0, 12)
	b:shelf(-80, -56, 0, 12)
	b:shelf(-64, -70, 0, 8)
	b:table(-66, -50, 0, 6, 3)
	b:chair(-66, -47.5, 0)
	b:sign(-75, 12, -39.2, 180, 18, 3, "LIBRARY", Color3.fromRGB(255, 250, 235), Color3.fromRGB(60, 30, 25))

	-- Lecture hall (north-east)
	building(b, 50, -80, 100, -40, 16, {
		south = { { 25, 10 } },
		west = { { 20, 8 } },
	}, STONE, Color3.fromRGB(90, 70, 60), Enum.Material.Carpet)
	for row = 0, 2 do
		for _, x in ipairs({ 60, 72, 84 }) do
			b:bench(x, -72 + row * 7, 0)
		end
	end
	b:block(75, 8, -79.3, 20, 7, 0.3, Color3.fromRGB(30, 50, 35), Enum.Material.SmoothPlastic)
	b:sign(75, 12.5, -39.2, 180, 20, 3, "LECTURE HALL", Color3.fromRGB(40, 40, 40), Color3.fromRGB(230, 225, 210))

	-- Science lab (south-east)
	building(b, 50, 40, 100, 80, 14, {
		north = { { 25, 10 } },
		west = { { 20, 8 } },
	}, STONE, Color3.fromRGB(220, 225, 228), Enum.Material.Marble)
	b:counter(70, 70, 0, 14, Color3.fromRGB(235, 235, 240))
	b:counter(70, 56, 0, 14, Color3.fromRGB(235, 235, 240))
	b:cabinet(97, 44, 90)
	b:sign(75, 12, 39.2, 0, 18, 3, "SCIENCE LAB", Color3.fromRGB(30, 60, 90), Color3.fromRGB(230, 240, 245))

	-- Cafeteria (south-west)
	building(b, -100, 40, -50, 80, 12, {
		north = { { 25, 10 } },
		east = { { 20, 8 } },
	}, BRICK, Color3.fromRGB(200, 190, 170), Enum.Material.Marble)
	for _, x in ipairs({ -85, -70 }) do
		for _, z in ipairs({ 52, 66 }) do
			b:table(x, z, 0, 8, 4)
		end
	end
	b:counter(-75, 77.5, 0, 20, Color3.fromRGB(170, 170, 175))
	b:vending(-52.5, 72, 90)
	b:sign(-75, 10.5, 39.2, 0, 18, 3, "CAFETERIA", Color3.fromRGB(255, 245, 230), Color3.fromRGB(150, 60, 30))

	-- Campus security office (south, the headquarters of this map)
	building(b, -15, 55, 15, 85, 12, {
		north = { { 15, 8 } },
	}, Color3.fromRGB(70, 80, 100), Color3.fromRGB(80, 80, 88), Enum.Material.Concrete)
	b:cabinet(-12, 60, -90)
	b:sign(0, 10.5, 54.2, 0, 16, 2.5, "CAMPUS SECURITY", Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 45, 80))

	-- Clock tower (north)
	b:block(0, 15, -70, 10, 30, 10, STONE, Enum.Material.Concrete)
	b:sign(
		0,
		24,
		-64.8,
		180,
		7,
		7,
		"XII",
		Color3.fromRGB(30, 30, 30),
		Color3.fromRGB(240, 235, 220),
		Enum.Font.Garamond
	)

	-- Quad: fountain, trees and benches
	b:part(
		Vector3.new(2, 18, 18),
		CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		STONE,
		Enum.Material.Concrete,
		{ Shape = Enum.PartType.Cylinder }
	)
	b:part(
		Vector3.new(0.3, 15, 15),
		CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(80, 150, 220),
		Enum.Material.Glass,
		{ Shape = Enum.PartType.Cylinder, Transparency = 0.3, CanQuery = false }
	)
	b:block(0, 4, 0, 2, 6, 2, STONE, Enum.Material.Concrete)
	for _, spot in ipairs({
		{ -28, -24 },
		{ 28, -24 },
		{ -28, 24 },
		{ 28, 24 },
		{ -45, 0 },
		{ 45, 0 },
		{ -30, -60 },
		{ 30, -60 },
	}) do
		b:tree(spot[1], spot[2], 1)
	end
	for _, spot in ipairs({ { -14, -18, 0 }, { 14, -18, 0 }, { -14, 18, 180 }, { 14, 18, 180 } }) do
		b:bench(spot[1], spot[2], spot[3])
	end
	for _, spot in ipairs({ { -40, -84 }, { 40, -84 }, { -104, 0 }, { 104, 0 } }) do
		b:crate(spot[1], spot[2], 4)
	end
	b:block(-24, 3, 44, 12, 6, 1, Color3.fromRGB(50, 95, 50), Enum.Material.Grass)
	b:block(24, 3, 44, 12, 6, 1, Color3.fromRGB(50, 95, 50), Enum.Material.Grass)
	b:block(-70, 3, 0, 1, 6, 14, Color3.fromRGB(50, 95, 50), Enum.Material.Grass)
	b:block(70, 3, 0, 1, 6, 14, Color3.fromRGB(50, 95, 50), Enum.Material.Grass)
	-- Posts for the freestanding evidence board
	b:block(-6.4, 4.75, 30.4, 0.5, 9.5, 0.5, Color3.fromRGB(60, 50, 40), Enum.Material.Wood)
	b:block(6.4, 4.75, 30.4, 0.5, 9.5, 0.5, Color3.fromRGB(60, 50, 40), Enum.Material.Wood)
end

-- Noir pass: lamps with hard shadows along the paths, puddles, fog over the lawns.
local function noir(b)
	for index, spot in ipairs({ { -8, -34, 90 }, { 8, 34, -90 }, { -40, 12, 180 }, { 40, -12, 0 } }) do
		Style.lampPost(b, spot[1], spot[2], { rot = spot[3], shadows = true, flicker = index == 3 })
	end
	for _, spot in ipairs({ { 3, -40, 5, 3 }, { -30, 3, 6, 3 }, { 46, -2, 4, 3 }, { -2, 52, 5, 4 }, { 70, 4, 6, 3 } }) do
		Style.puddle(b, spot[1], spot[2], spot[3], spot[4])
	end
	for _, spot in ipairs({ { -9, -26 }, { 9, 26 }, { -30, 16 }, { 30, -16 }, { -6, 44 }, { 6, -44 } }) do
		Style.prop(b, "TrashCan", spot[1], spot[2], (spot[2] * 5) % 360)
	end
	Style.steamVent(b, -104, -30)
	Style.steamVent(b, 104, 40)
	Style.skyline(b, 110, 90, 23)
end

-- The gameplay contract: stations, spawns, sheets, drop points, hoods, areas, the tip box
-- and the board. MapContract checks it; the dressing above must leave these places clear.
function UniversityCampus.layout()
	return {
		stations = {
			{ type = "Phone", name = "Archive Microfilm", x = -95, z = -62, rot = -90 },
			{ type = "Fingerprint", name = "Book Return Prints", x = -60, z = -76, rot = 180 },
			{ type = "Camera", name = "Lecture Recordings", x = 95, z = -60, rot = 90 },
			{ type = "Fingerprint", name = "Chem Lab Analyzer", x = 95, z = 62, rot = 90 },
			{ type = "Phone", name = "Cafeteria Payphone", x = -95, z = 62, rot = -90 },
			{ type = "Camera", name = "Quad Camera Post", x = -22, z = 8, rot = -90 },
			{ type = "Phone", name = "Student Union Kiosk", x = 22, z = -8, rot = 90 },
			{ type = "Camera", name = "Campus CCTV Hub", x = 0, z = 81, rot = 0 },
			{ type = "Forensics", name = "Forensic Microscope", x = 70, z = 76, rot = 0 },
			{ type = "Forensics", name = "Rare Books Ink Lab", x = -78, z = -46, rot = 180 },
		},
		tipBox = { x = 12, z = 70, rot = 90 },
		board = { x = 0, y = 6, z = 30, rot = 0, w = 12, h = 7 },
		spawns = {
			{ x = -18, z = 0 },
			{ x = 18, z = 0 },
			{ x = 0, z = -18 },
			{ x = 0, z = 18 },
			{ x = -13, z = -13 },
			{ x = 13, z = -13 },
			{ x = -13, z = 13 },
			{ x = 13, z = 13 },
			{ x = -24, z = -8 },
			{ x = 24, z = 8 },
			{ x = -8, z = 24 },
			{ x = 8, z = -24 },
		},
		sheets = {
			{ x = -66, y = 2.8, z = -50 },
			{ x = -70, y = 2.8, z = 66 },
			{ x = 70, y = 3.55, z = 56 },
			{ x = 14, y = 1.7, z = -18 },
		},
		dropPoints = {
			{ name = "Loose grate behind the clock tower", x = 0, z = -78 },
			{ name = "Library back corner", x = -97.5, z = -77.5 },
			{ name = "Behind the cafeteria vending machine", x = -52.5, z = 78 },
		},
		hoods = {
			{ x = -30, y = 0.6, z = 40 },
			{ x = 30, y = 0.6, z = -40 },
			{ x = 60, y = 0.6, z = 20 },
			{ x = -60, y = 0.6, z = -20 },
		},
		areas = {
			{ name = "the Library", x = -75, z = -60 },
			{ name = "the Lecture Hall", x = 75, z = -60 },
			{ name = "the Science Lab", x = 75, z = 60 },
			{ name = "the Cafeteria", x = -75, z = 60 },
			{ name = "the fountain", x = 0, z = 0 },
			{ name = "the Clock Tower", x = 0, z = -70 },
			{ name = "Campus Security", x = 0, z = 70 },
			{ name = "the east lawn", x = 75, z = 0 },
			{ name = "the west lawn", x = -75, z = 0 },
		},
	}
end

function UniversityCampus.build(b)
	-- The Blender scene when it is imported, the part-built map otherwise. Either way the
	-- layout (stations, spawns, sheets...) is the same.
	if not SceneBuilder.build(b, "Campus") then
		dress(b)
		noir(b)
	end
	return UniversityCampus.layout()
end

return UniversityCampus
