-- The lobby hall where players gather, pick cosmetics and wait for a match, and the
-- Academy behind its south door: practice desks for every skill and three practice dummies.
-- The Academy only tags parts (LTraining desks, LDummy torsos); the drills run on each
-- player's client and never touch a match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Terms = require(Shared:WaitForChild("Terms"))

local Lobby = {}

local WALL = Color3.fromRGB(26, 26, 32)
local FLOOR = Color3.fromRGB(34, 34, 40)
local GOLD = Color3.fromRGB(215, 185, 110)
local RED = Color3.fromRGB(170, 25, 35)
local NEWLINE = string.char(10)

-- The practice dummies' aliases and real names (names from the real name pools).
local DUMMIES = {
	{ alias = "Dummy A", name = "Kenji Mori", x = -8 },
	{ alias = "Dummy B", name = "Mei Sato", x = 0 },
	{ alias = "Dummy C", name = "Hina Ogawa", x = 8 },
}

-- drill id, title, one-line blurb, x, z, rotation (the player stands on the side it faces)
local DRILLS = {
	{ "camera", "CAMERA FOOTAGE", "Put the frames in time order.", -26, 62, -90 },
	{ "fingerprint", "FINGERPRINTS", "Match the print to the sample.", -26, 74, -90 },
	{ "phone", "PHONE RECORDS", "Dial the number from the log.", -26, 86, -90 },
	{ "grimoire", "THE GRIMOIRE", "Write a full real name exactly.", 26, 62, 90 },
	{ "warrant", "THE WARRANT", "Pick the suspect, type the name.", 26, 74, 90 },
	{ "eyes", "SPECTER'S EYES", "See real names up close.", 26, 86, 90 },
}

local function signText(board: BasePart, text: string, color: Color3, font: Enum.Font)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Parent = board,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextScaled = true,
		Font = font,
		Parent = gui,
	})
end

local function drillDesk(b, drill)
	local id, title, blurb, x, z, rot = table.unpack(drill)
	local desk = b:prop(
		x,
		z,
		rot,
		CFrame.new(0, 1.5, 0),
		Vector3.new(5, 3, 2.4),
		Color3.fromRGB(58, 56, 62),
		Enum.Material.Metal
	)
	b:prop(
		x,
		z,
		rot,
		CFrame.new(0, 3.06, 0),
		Vector3.new(5.2, 0.12, 2.6),
		GOLD,
		Enum.Material.Neon,
		{ CanQuery = false }
	)
	desk:SetAttribute("Drill", id)
	desk:SetAttribute("DrillTitle", title)
	desk:AddTag("LTraining")
	local board = b:part(
		Vector3.new(6, 2.4, 0.3),
		b:cf(x, 0, z, rot) * CFrame.new(0, 6.2, 1.4),
		Color3.fromRGB(14, 14, 18),
		Enum.Material.SmoothPlastic
	)
	signText(board, title .. NEWLINE .. blurb, GOLD, Enum.Font.SpecialElite)
end

-- A plain grey figure for the drills to point at.
local function dummy(b, info)
	local model = Create("Model", { Name = "Dummy_" .. info.alias, Parent = b.parent })
	local grey = Color3.fromRGB(150, 146, 140)
	local base = b:cf(info.x, 0, 80, 0)
	local function piece(size: Vector3, offset: CFrame, shape: Enum.PartType?)
		return b:part(
			size,
			base * offset,
			grey,
			Enum.Material.SmoothPlastic,
			{ Parent = model, Shape = shape or Enum.PartType.Block }
		)
	end
	piece(Vector3.new(0.9, 2.6, 0.9), CFrame.new(-0.5, 1.3, 0))
	piece(Vector3.new(0.9, 2.6, 0.9), CFrame.new(0.5, 1.3, 0))
	local torso = piece(Vector3.new(2, 2.4, 1), CFrame.new(0, 3.8, 0))
	piece(Vector3.new(0.8, 2.3, 0.8), CFrame.new(-1.45, 3.85, 0))
	piece(Vector3.new(0.8, 2.3, 0.8), CFrame.new(1.45, 3.85, 0))
	piece(Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 5.8, 0), Enum.PartType.Ball)
	model.PrimaryPart = torso
	torso:SetAttribute("Alias", info.alias)
	torso:SetAttribute("PracticeName", info.name)
	torso:AddTag("LDummy")
	-- Alias placard at its feet, tilted towards the door.
	local plate = b:part(
		Vector3.new(3, 0.8, 0.2),
		base * CFrame.new(0, 0.6, -1.2) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(20, 20, 24),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)
	signText(plate, string.upper(info.alias), Color3.fromRGB(235, 230, 220), Enum.Font.GothamBlack)
end

local function buildAcademy(b)
	local academyWall = Color3.fromRGB(22, 22, 28)
	b:floor(-30, 50, 30, 96, Color3.fromRGB(28, 28, 34), Enum.Material.WoodPlanks)
	b:wall(-30, 50, -30, 96, 14, academyWall, Enum.Material.Concrete)
	b:wall(30, 50, 30, 96, 14, academyWall, Enum.Material.Concrete)
	b:wall(-30, 96, 30, 96, 14, academyWall, Enum.Material.Concrete)
	b:block(0, 14.5, 73, 62, 1, 48, Color3.fromRGB(16, 16, 20), Enum.Material.Concrete)
	b:sign(0, 10, 95.3, 180, 30, 4, "ACADEMY", GOLD, Color3.fromRGB(12, 12, 14), Enum.Font.GrenzeGotisch)
	b:sign(
		0,
		6.5,
		95.3,
		180,
		30,
		2.2,
		"Practice every skill here. Nothing you do here counts in a match.",
		Color3.fromRGB(220, 215, 205),
		Color3.fromRGB(12, 12, 14),
		Enum.Font.SpecialElite
	)
	for _, drill in ipairs(DRILLS) do
		drillDesk(b, drill)
	end
	for _, info in ipairs(DUMMIES) do
		dummy(b, info)
	end
	for _, z in ipairs({ 62, 80 }) do
		b:light(-14, 13.8, z, Color3.fromRGB(255, 232, 196), 30, 1.1)
		b:light(14, 13.8, z, Color3.fromRGB(255, 232, 196), 30, 1.1)
	end
	-- The sign above the door, on the lobby side.
	b:sign(0, 11.2, 49.3, 0, 16, 2.6, "ACADEMY  ·  PRACTICE", GOLD, Color3.fromRGB(12, 12, 14), Enum.Font.GothamBlack)
end

function Lobby.build(b)
	b:floor(-50, -50, 50, 50, FLOOR, Enum.Material.Marble)
	b:wall(-50, -50, 50, -50, 26, WALL, Enum.Material.Concrete)
	b:wall(50, -50, 50, 50, 26, WALL, Enum.Material.Concrete)
	b:wall(-50, 50, -50, -50, 26, WALL, Enum.Material.Concrete)
	-- South wall with the door to the Academy.
	b:wallDoors(-50, 50, 50, 50, 26, { { 50, 12 } }, WALL, Enum.Material.Concrete)
	buildAcademy(b)
	b:block(0, 26.5, 0, 102, 1, 102, Color3.fromRGB(18, 18, 22), Enum.Material.Concrete)

	-- Red carpet from the spawn to the title wall.
	b:block(0, 0.05, -13, 10, 0.1, 62, RED, Enum.Material.Fabric)

	-- Title wall
	b:sign(
		0,
		17,
		-49.3,
		180,
		44,
		9,
		Terms.NAMES.GAME,
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(12, 12, 14),
		Enum.Font.GrenzeGotisch
	)
	b:sign(0, 10.5, -49.3, 180, 36, 3, Terms.TAGLINE, GOLD, Color3.fromRGB(12, 12, 14), Enum.Font.SpecialElite)

	-- How to play (west wall, facing +X)
	b:sign(
		-49.3,
		11,
		0,
		-90,
		30,
		14,
		Terms.f(
			"HOW TO PLAY\n\n1. Press READY. A match starts with 6 to 12 players.\n"
				.. "2. Your real name is on your role card. Hold C to see it.\n"
				.. "3. Work case files. Every task leaks 3 letters of your name to anyone close.\n"
				.. "4. Outside meetings you only have quick-chat. Meetings open free chat.\n"
				.. "5. {Hand} needs your full real name. So does {zero}'s warrant.\n\n"
				.. "Practice every skill in the Academy, through the south door."
		),
		Color3.fromRGB(230, 230, 230),
		Color3.fromRGB(16, 16, 20),
		Enum.Font.SpecialElite
	)

	-- Next map board (east wall, facing -X)
	local _, nextMapLabel =
		b:sign(49.3, 11, 0, 90, 26, 8, "NEXT CASE", GOLD, Color3.fromRGB(16, 16, 20), Enum.Font.GothamBlack)

	-- Leaderboards (east wall) and today's quests and the weekly board (west wall).
	local boards = {}
	for _, spec in ipairs({
		{ key = "wins", x = 49.3, z = -32, rot = 90 },
		{ key = "xp", x = 49.3, z = 32, rot = 90 },
		{ key = "weekly", x = -49.3, z = -32, rot = -90 },
		{ key = "quests", x = -49.3, z = 32, rot = -90 },
	}) do
		local _, label = b:sign(
			spec.x,
			11,
			spec.z,
			spec.rot,
			14,
			14,
			"",
			Color3.fromRGB(235, 232, 225),
			Color3.fromRGB(14, 14, 18),
			Enum.Font.SpecialElite
		)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		Create("UITextSizeConstraint", { MaxTextSize = 34, Parent = label })
		boards[spec.key] = label
	end

	-- Pillars, lights and benches
	for _, x in ipairs({ -32, 32 }) do
		for _, z in ipairs({ -32, 0, 32 }) do
			b:pillar(x, z, 26, Color3.fromRGB(58, 56, 62), 3)
			b:block(x, 0.6, z, 4.2, 1.2, 4.2, GOLD, Enum.Material.Metal)
		end
	end
	for _, x in ipairs({ -24, 0, 24 }) do
		for _, z in ipairs({ -24, 0, 24 }) do
			b:light(x, 25.8, z, Color3.fromRGB(255, 236, 200), 40, 1.2)
		end
	end
	for _, z in ipairs({ -20, 20 }) do
		b:bench(-40, z, -90)
		b:bench(40, z, 90)
	end
	b:plant(-45, -45)
	b:plant(45, -45)
	b:plant(-45, 45)
	b:plant(45, 45)

	-- Zero's mark, a giant 0, inlaid in the floor.
	b:block(-4, 0.06, 26, 2.4, 0.12, 14, GOLD, Enum.Material.Neon, { CanQuery = false })
	b:block(4, 0.06, 26, 2.4, 0.12, 14, GOLD, Enum.Material.Neon, { CanQuery = false })
	b:block(0, 0.06, 20.2, 5.6, 0.12, 2.4, GOLD, Enum.Material.Neon, { CanQuery = false })
	b:block(0, 0.06, 31.8, 5.6, 0.12, 2.4, GOLD, Enum.Material.Neon, { CanQuery = false })

	-- Spawn pad
	local spawnPad = Create("SpawnLocation", {
		Name = "LobbySpawn",
		Anchored = true,
		Size = Vector3.new(12, 0.4, 12),
		CFrame = b:world(CFrame.new(0, 0.2, 14)),
		Color = Color3.fromRGB(45, 45, 52),
		Material = Enum.Material.Marble,
		Neutral = true,
		Duration = 0,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	spawnPad.Parent = b.parent

	return {
		nextMapLabel = nextMapLabel,
		boards = boards,
		spawnCFrame = b:world(CFrame.new(0, 0.4, 14)),
	}
end

return Lobby
