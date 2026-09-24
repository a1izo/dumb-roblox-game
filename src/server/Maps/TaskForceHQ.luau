-- Map 1: Task Force headquarters. An open-plan office in the middle with six rooms
-- around it. Local coordinates: x -80..80, z -60..60, ceiling at 14.

local TaskForceHQ = {}

TaskForceHQ.id = "TaskForceHQ"
TaskForceHQ.name = "Task Force HQ"
TaskForceHQ.lighting = {
	clockTime = 20.5,
	brightness = 1,
	ambient = Color3.fromRGB(110, 110, 120),
	outdoorAmbient = Color3.fromRGB(90, 90, 100),
	fogEnd = 100000,
	fogColor = Color3.fromRGB(20, 20, 25),
}

function TaskForceHQ.build(b)
	local H = 14
	local wallColor = Color3.fromRGB(196, 200, 208)
	local wallMat = Enum.Material.SmoothPlastic
	local partition = Color3.fromRGB(90, 100, 118)

	-- Floors
	b:floor(-40, -60, 40, 60, Color3.fromRGB(70, 78, 92), Enum.Material.Carpet)
	b:floor(-80, -60, -40, -20, Color3.fromRGB(60, 60, 66), Enum.Material.Concrete)
	b:floor(-80, -20, -40, 20, Color3.fromRGB(170, 150, 120), Enum.Material.WoodPlanks)
	b:floor(-80, 20, -40, 60, Color3.fromRGB(110, 90, 70), Enum.Material.WoodPlanks)
	b:floor(40, -60, 80, -20, Color3.fromRGB(215, 220, 225), Enum.Material.Marble)
	b:floor(40, -20, 80, 20, Color3.fromRGB(140, 140, 150), Enum.Material.Marble)
	b:floor(40, 20, 80, 60, Color3.fromRGB(50, 55, 62), Enum.Material.DiamondPlate)

	-- Shell
	b:enclose(-80, -60, 80, 60, H, Color3.fromRGB(150, 155, 165), Enum.Material.Concrete)
	b:block(0, H + 0.5, 0, 162, 1, 122, Color3.fromRGB(225, 225, 228), Enum.Material.SmoothPlastic)

	-- Office side walls with a door into every side room
	b:wallDoors(-40, -60, -40, 60, H, { { 20, 8 }, { 60, 10 }, { 100, 8 } }, wallColor, wallMat)
	b:wallDoors(40, -60, 40, 60, H, { { 20, 8 }, { 60, 10 }, { 100, 8 } }, wallColor, wallMat)
	b:wallDoors(-80, -20, -40, -20, H, { { 20, 8 } }, wallColor, wallMat)
	b:wallDoors(-80, 20, -40, 20, H, { { 20, 8 } }, wallColor, wallMat)
	b:wallDoors(40, -20, 80, -20, H, { { 20, 8 } }, wallColor, wallMat)
	b:wallDoors(40, 20, 80, 20, H, { { 20, 8 } }, wallColor, wallMat)

	-- Ceiling lights
	local lightColor = Color3.fromRGB(255, 244, 225)
	for _, x in ipairs({ -26, 0, 26 }) do
		for _, z in ipairs({ -40, -14, 14, 40 }) do
			b:light(x, H - 0.2, z, lightColor, 30, 1)
		end
	end
	for _, x in ipairs({ -60, 60 }) do
		for _, z in ipairs({ -40, 0, 40 }) do
			b:light(x, H - 0.2, z, lightColor, 32, 1.1)
		end
	end

	-- Open-plan office: desk rows along the walls, partitions and pillars for cover
	for _, x in ipairs({ -30, -18, 18, 30 }) do
		b:desk(x, -52, 180)
		b:chair(x, -49.2, 0)
		b:desk(x, 52, 0)
		b:chair(x, 49.2, 180)
	end
	b:wall(-26, -24, -26, -8, 6, partition, Enum.Material.Fabric)
	b:wall(-26, 8, -26, 24, 6, partition, Enum.Material.Fabric)
	b:wall(26, -24, 26, -8, 6, partition, Enum.Material.Fabric)
	b:wall(26, 8, 26, 24, 6, partition, Enum.Material.Fabric)
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -26, 26 }) do
			b:pillar(x, z, H, Color3.fromRGB(210, 210, 215), 3)
		end
	end
	b:table(0, 0, 0, 4, 3, Color3.fromRGB(200, 200, 205))
	b:block(0, 3.3, 0.6, 2.4, 0.8, 1.4, Color3.fromRGB(60, 60, 64), Enum.Material.SmoothPlastic)
	b:plant(-36, -56)
	b:plant(36, -56)
	b:plant(-36, 56)
	b:plant(36, 56)

	-- Security office
	for i = 0, 3 do
		b:block(-71 + i * 6, 8, -59.35, 5, 3, 0.2, Color3.fromRGB(60, 110, 190), Enum.Material.Neon, { CanQuery = false })
	end
	b:desk(-58, -54, 180)
	b:chair(-58, -51.2, 0)
	b:cabinet(-77, -26, -90)
	b:cabinet(-44, -26, 180)

	-- Break room
	b:vending(-78.2, -12, -90)
	b:vending(-78.2, -7, -90, Color3.fromRGB(40, 90, 180))
	b:counter(-70, -17.5, 0, 8)
	b:table(-66, -2, 0, 5, 3)
	b:chair(-66, -5, 180)
	b:chair(-66, 1, 0)
	b:sofa(-76, 10, -90)
	b:plant(-44, 16)

	-- Archive
	b:shelf(-60, 32, 0, 10)
	b:shelf(-60, 48, 0, 10)
	b:shelf(-46, 32, 0, 6)
	b:shelf(-46, 48, 0, 6)
	b:table(-50, 55, 0, 5, 3)
	b:cabinet(-77, 24, -90)

	-- Forensics lab
	b:counter(62, -57, 0, 14, Color3.fromRGB(235, 235, 240))
	b:counter(56, -30, 0, 10, Color3.fromRGB(235, 235, 240))
	b:block(56, 4, -30, 0.6, 1, 0.6, Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
	b:block(52, 3.8, -30, 1.2, 0.6, 0.8, Color3.fromRGB(80, 200, 160), Enum.Material.Glass)
	b:cabinet(77, -26, 90)
	b:cabinet(44, -57, 0)

	-- Reception
	b:counter(64, 4, 90, 10, Color3.fromRGB(60, 60, 70))
	b:sofa(50, 16.5, 0, Color3.fromRGB(40, 60, 90))
	b:sign(79.3, 9, -8, 90, 14, 3, "TASK FORCE HQ", Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 30, 50))
	b:plant(76, -16)
	b:plant(44, 16)

	-- Server room
	for _, x in ipairs({ 50, 54, 58, 62 }) do
		b:rack(x, 30, 180)
		b:rack(x, 50, 0)
	end

	return {
		stations = {
			{ type = "Camera", name = "CCTV Wall", x = -74, z = -40, rot = -90 },
			{ type = "Fingerprint", name = "Print Analyzer", x = 74, z = -40, rot = 90 },
			{ type = "Phone", name = "Records Terminal", x = -74, z = 40, rot = -90 },
			{ type = "Phone", name = "Wiretap Console", x = 74, z = 40, rot = 90 },
			{ type = "Camera", name = "Street Feed", x = -16, z = -8, rot = 180 },
			{ type = "Fingerprint", name = "Print Scanner", x = 16, z = 8, rot = 0 },
			{ type = "Phone", name = "Call Log Desk", x = -52, z = 10, rot = 90 },
			{ type = "Camera", name = "Entrance Cam", x = 48, z = -10, rot = -90 },
		},
		tipBox = { x = 74, z = 10, rot = 90 },
		board = { x = 39.3, y = 7, z = -24, rot = 90, w = 12, h = 7 },
		spawns = {
			{ x = -30, z = -20 },
			{ x = -30, z = 0 },
			{ x = -30, z = 20 },
			{ x = 30, z = -20 },
			{ x = 30, z = 0 },
			{ x = 30, z = 20 },
			{ x = 0, z = -34 },
			{ x = 0, z = 34 },
			{ x = -8, z = -32 },
			{ x = 8, z = 32 },
			{ x = -8, z = 32 },
			{ x = 8, z = -32 },
		},
		sheets = {
			{ x = 0, y = 2.8, z = -0.8 },
			{ x = -66, y = 2.8, z = -2 },
			{ x = 64, y = 3.55, z = 6 },
			{ x = -50, y = 2.8, z = 55 },
		},
		dropPoints = {
			{ name = "Behind the vending machines", x = -78, z = -16.5 },
			{ name = "Archive back corner", x = -77.5, z = 57.5 },
			{ name = "Server rack alcove", x = 77.5, z = 57.5 },
		},
		hoods = {
			{ x = -46, y = 0.6, z = -56 },
			{ x = 46, y = 0.6, z = -44 },
			{ x = -8, y = 0.6, z = 44 },
			{ x = 46, y = 0.6, z = 56 },
		},
		areas = {
			{ name = "the Security Office", x = -60, z = -40 },
			{ name = "the Break Room", x = -60, z = 0 },
			{ name = "the Archive", x = -60, z = 40 },
			{ name = "the Forensics Lab", x = 60, z = -40 },
			{ name = "Reception", x = 60, z = 0 },
			{ name = "the Server Room", x = 60, z = 40 },
			{ name = "the north office", x = 0, z = -40 },
			{ name = "the central office", x = 0, z = 0 },
			{ name = "the south office", x = 0, z = 40 },
		},
	}
end

return TaskForceHQ
