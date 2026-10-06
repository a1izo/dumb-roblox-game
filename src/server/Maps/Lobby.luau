-- The lobby: the Grey Realm, a never-ending wasteland under layered cloud, made in Blender
-- (art/scripts/maps/venues/lobby/). Players appear on a ruined terrace over its old flagstone
-- plaza, facing north; the steles round the plaza carry How to Play, the next case and the boards;
-- south-west lies the Academy, a ring of broken pillars with a practice altar for every skill and
-- three effigies to practise on; two old causeways over chasms lead to the plateaus of the Spire Ascent
-- and the rune courtyard, and the dice rock and the stone-toss wait in the basin itself.
--
-- SceneBuilder puts up the scene (or its greybox, without the import); this module builds what
-- shows text or does something, at the scene's anchors. The Academy only tags parts (LTraining
-- drill desks, LDummy torsos); the drills run on each player's client and never touch a match.
-- The mini-games' objects are LobbyGames', the things that sway in the wind LobbyDecor's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))
local Assets = require(Shared:WaitForChild("Assets"))
local Terms = require(Shared:WaitForChild("Terms"))

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyGames = require(script.Parent.LobbyGames)
local SceneBuilder = require(script.Parent.SceneBuilder)

local Lobby = {}

local GOLD = Color3.fromRGB(163, 170, 181) -- the grey of the UI's secondary text
local INK = Color3.fromRGB(12, 12, 14)
local SLATE = Color3.fromRGB(16, 16, 20)
local STONE = Color3.fromRGB(58, 58, 62)
local NEWLINE = string.char(10)

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number? }

-- The practice dummies' aliases and real names (names from the real name pools).
local DUMMIES = {
	{ alias = "Dummy A", name = "Kenji Mori" },
	{ alias = "Dummy B", name = "Mei Sato" },
	{ alias = "Dummy C", name = "Hina Ogawa" },
}

-- drill id, title, one-line blurb: one case-file altar per station type, then the Grimoire, the
-- warrant and the eyes. They take the scene's altars in order (drill1, drill2...).
local DRILLS = {}
for _, id in ipairs(TaskTypes.LIST) do
	local info = TaskTypes.get(id)
	table.insert(DRILLS, { info.drill, info.drillTitle, "Practise every puzzle this station can give." })
end
for _, drill in ipairs({
	{ "grimoire", Terms.NAMES.GRIMOIRE, "Write a full real name exactly." },
	{ "warrant", "THE WARRANT", "Pick the suspect, type the name." },
	{ "eyes", Terms.NAMES.EYES, "See real names up close." },
}) do
	table.insert(DRILLS, drill)
end

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
		FontFace = WorldFont.face(font),
		Parent = gui,
	})
end

-- A sign on an anchor's face (its size from the anchor unless given).
local function sign(b, a: Anchor, text: string, color: Color3, bg: Color3, font: Enum.Font, w: number?, h: number?)
	return b:sign(a.x, a.y, a.z, a.rot, w or a.w or 10, h or a.h or 4, text, color, bg, font)
end

-- A practice altar: the game's drill desk (the prompt's part), dressed with the Blender altar when
-- it is imported, and a stone tablet behind it carrying the drill's name.
local function drillDesk(b, drill, a: Anchor)
	local id, title, blurb = drill[1], drill[2], drill[3]
	local desk = b:prop(
		a.x,
		a.z,
		a.rot,
		CFrame.new(0, 1.5, 0),
		Vector3.new(5, 3, 2.4),
		Color3.fromRGB(58, 56, 62),
		Enum.Material.Slate
	)
	local strip = b:prop(
		a.x,
		a.z,
		a.rot,
		CFrame.new(0, 3.06, 0),
		Vector3.new(5.2, 0.12, 2.6),
		GOLD,
		Enum.Material.Neon,
		{ CanQuery = false }
	)
	if ModelLibrary.dress(desk, "PracticeAltar", CFrame.new(0, -1.5, 0)) then
		strip.Transparency = 1
		strip.CanQuery = false
	end
	desk:SetAttribute("Drill", id)
	desk:SetAttribute("DrillTitle", title)
	desk:AddTag("LTraining")
	local base = b:cf(a.x, 0, a.z, a.rot)
	b:part(Vector3.new(6.6, 7.6, 0.7), base * CFrame.new(0, 3.8, 2.6), STONE, Enum.Material.Slate)
	local plaque = b:part(Vector3.new(6, 2.4, 0.3), base * CFrame.new(0, 6.2, 2.1), SLATE, Enum.Material.SmoothPlastic)
	signText(plaque, title .. NEWLINE .. blurb, GOLD, Enum.Font.SpecialElite)
end

-- A figure for the drills to point at: a plain grey mannequin, or the Blender effigy over it when
-- it is imported. Its torso carries the tag and the names; the whole model tips over when a drill
-- "kills" it (client PracticePanel), so everything hangs off the torso.
local function dummy(b, info, a: Anchor)
	local model = Create("Model", { Name = "Dummy_" .. info.alias, Parent = b.parent })
	local grey = Color3.fromRGB(150, 146, 140)
	local base = b:cf(a.x, 0, a.z, a.rot)
	local parts = {}
	local function piece(size: Vector3, offset: CFrame, shape: Enum.PartType?)
		local part = b:part(
			size,
			base * offset,
			grey,
			Enum.Material.SmoothPlastic,
			{ Parent = model, Shape = shape or Enum.PartType.Block }
		)
		table.insert(parts, part)
		return part
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
	if ModelLibrary.dress(torso, "Effigy", CFrame.new(0, -3.8, 0)) then
		for _, part in ipairs(parts) do
			part.Transparency = 1
		end
	end
	-- Alias placard at its feet, tilted towards the gate.
	local plate = b:part(
		Vector3.new(3, 0.8, 0.2),
		base * CFrame.new(0, 0.6, -1.6) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(20, 20, 24),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)
	signText(plate, string.upper(info.alias), Color3.fromRGB(235, 230, 220), Enum.Font.GothamBlack)
end

-- The Academy's signs, drill altars and effigies.
local function academy(b, anchors: { [string]: Anchor })
	sign(b, anchors.academyTitle, "ACADEMY", GOLD, INK, Enum.Font.GrenzeGotisch)
	sign(
		b,
		anchors.academyLine,
		"Practice every skill here. Nothing you do here counts in a match.",
		Color3.fromRGB(220, 215, 205),
		INK,
		Enum.Font.SpecialElite
	)
	sign(b, anchors.academyGate, "ACADEMY  ·  PRACTICE", GOLD, INK, Enum.Font.GothamBlack)
	for index, drill in ipairs(DRILLS) do
		local a = anchors["drill" .. index]
		if a then
			drillDesk(b, drill, a)
		else
			warn("[DeathsGambit] The lobby scene has no altar for drill " .. index .. " (" .. drill[1] .. ").")
		end
	end
	for index, info in ipairs(DUMMIES) do
		local a = anchors["dummy" .. index]
		if a then
			dummy(b, info, a)
		end
	end
end

function Lobby.build(b)
	SceneBuilder.build(b, "Lobby")
	local data = SceneBuilder.data("Lobby")
	assert(data, "no scene data for the lobby (run art/scripts/run_maps.py -- Lobby --export)")
	local anchors = data.layout.anchors :: { [string]: Anchor }

	academy(b, anchors)

	-- The title, carved into the monolith.
	local _, titleLabel =
		sign(b, anchors.title, Terms.NAMES.GAME, Color3.fromRGB(245, 245, 245), INK, Enum.Font.GothamBlack)
	-- The ransom-note wordmark replaces the plain lettering once the Core import has brought it.
	local wordmark = Assets.texture("UiWordmark")
	if wordmark ~= "" and titleLabel.Parent then
		titleLabel.Visible = false
		Create("ImageLabel", {
			Name = "Wordmark",
			BackgroundTransparency = 1,
			Image = wordmark,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Parent = titleLabel.Parent,
		})
	end
	sign(b, anchors.tagline, Terms.TAGLINE, GOLD, INK, Enum.Font.SpecialElite)

	-- How to play, on the great stele west of the plaza.
	sign(
		b,
		anchors.howto,
		Terms.f(
			"HOW TO PLAY\n\n1. Press READY. A match starts with 6 to 12 players.\n"
				.. "2. Your real name is on your role card. Hold C to see it.\n"
				.. "3. Work case files. Every task leaks 3 letters of your name to anyone close.\n"
				.. "4. Outside meetings you only have quick-chat. Meetings open free chat.\n"
				.. "5. {Hand} needs your full real name. So does {zero}'s warrant.\n\n"
				.. "Practice every skill in the Academy, the ring of pillars to the south-west."
		),
		Color3.fromRGB(230, 230, 230),
		SLATE,
		Enum.Font.SpecialElite
	)

	-- The next case, on the stele east of the plaza.
	local _, nextMapLabel = sign(b, anchors.nextCase, "NEXT CASE", GOLD, SLATE, Enum.Font.GothamBlack)

	-- Leaderboards (east) and today's quests and the weekly board (west); the two mini-game boards stand by
	-- the bridges' heads (anchor parkourBoard, runesBoard; board keys parkour, runes).
	local boards = {}
	for _, key in ipairs({ "wins", "xp", "weekly", "quests", "parkour", "runes" }) do
		local anchor = anchors[if key == "parkour" or key == "runes" then key .. "Board" else key]
		if anchor then
			local _, label = sign(b, anchor, "", Color3.fromRGB(235, 232, 225), SLATE, Enum.Font.SpecialElite)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			Create("UITextSizeConstraint", { MaxTextSize = 34, Parent = label })
			boards[key] = label
		else
			warn("[DeathsGambit] The lobby scene has no board for " .. key .. ".")
		end
	end

	LobbyDecor.build(b, anchors)
	local games = LobbyGames.build(b, anchors)

	-- Where players appear: the ring on the terrace (the scene's floor is under it, so the pad
	-- itself only marks the place).
	local spawn = anchors.spawn
	local spawnCFrame = b:world(b:cf(spawn.x, spawn.y + 0.4, spawn.z, spawn.rot))
	Create("SpawnLocation", {
		Name = "LobbySpawn",
		Anchored = true,
		Size = Vector3.new(12, 0.4, 12),
		CFrame = b:world(b:cf(spawn.x, spawn.y + 0.2, spawn.z, spawn.rot)),
		Transparency = 1,
		CanCollide = false,
		Neutral = true,
		Duration = 0,
		Parent = b.parent,
	})

	return {
		nextMapLabel = nextMapLabel,
		boards = boards,
		spawnCFrame = spawnCFrame,
		games = games,
	}
end

return Lobby
