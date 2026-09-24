-- The lobby hall where players gather, pick cosmetics and wait for a match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Lobby = {}

local WALL = Color3.fromRGB(26, 26, 32)
local FLOOR = Color3.fromRGB(34, 34, 40)
local GOLD = Color3.fromRGB(215, 185, 110)
local RED = Color3.fromRGB(170, 25, 35)

function Lobby.build(b)
	b:floor(-50, -50, 50, 50, FLOOR, Enum.Material.Marble)
	b:enclose(-50, -50, 50, 50, 26, WALL, Enum.Material.Concrete)
	b:block(0, 26.5, 0, 102, 1, 102, Color3.fromRGB(18, 18, 22), Enum.Material.Concrete)

	-- Red carpet from the spawn to the title wall.
	b:block(0, 0.05, -13, 10, 0.1, 62, RED, Enum.Material.Fabric)

	-- Title wall
	b:sign(0, 17, -49.3, 180, 44, 9, "L GAME", Color3.fromRGB(245, 245, 245), Color3.fromRGB(12, 12, 14), Enum.Font.GrenzeGotisch)
	b:sign(0, 10.5, -49.3, 180, 36, 3, "Find Kira.  Protect your real name.", GOLD, Color3.fromRGB(12, 12, 14), Enum.Font.SpecialElite)

	-- How to play (west wall, facing +X)
	b:sign(
		-49.3,
		11,
		0,
		-90,
		30,
		14,
		"HOW TO PLAY\n\n1. Press READY. A match starts with 6 to 12 players.\n2. Memorise your real name in the briefing. It is shown once.\n3. Work case files. Every task leaks 3 letters of your name to anyone close.\n4. Outside meetings you only have quick-chat. Meetings open free chat.\n5. Kira needs your full real name. So does L's warrant.",
		Color3.fromRGB(230, 230, 230),
		Color3.fromRGB(16, 16, 20),
		Enum.Font.SpecialElite
	)

	-- Next map board (east wall, facing -X)
	local _, nextMapLabel = b:sign(49.3, 11, 0, 90, 26, 8, "NEXT CASE\nTask Force HQ", GOLD, Color3.fromRGB(16, 16, 20), Enum.Font.GothamBlack)

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

	-- A giant gothic L inlaid in the floor.
	b:block(-3, 0.06, 26, 3, 0.12, 14, GOLD, Enum.Material.Neon, { CanQuery = false })
	b:block(1.5, 0.06, 31.5, 6, 0.12, 3, GOLD, Enum.Material.Neon, { CanQuery = false })

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
		spawnCFrame = b:world(CFrame.new(0, 0.4, 14)),
	}
end

return Lobby
