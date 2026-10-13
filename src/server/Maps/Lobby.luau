-- The lobby: the Grey Realm, a never-ending wasteland under layered cloud, made in Blender
-- (art/scripts/maps/venues/lobby/). Players appear on a ruined terrace over its old flagstone
-- plaza, facing north. No wall in it explains anything: the game is learnt by doing (the Trial, in the
-- Academy) and by looking (the stone tableaux round the plaza, the candles at its middle). The only
-- writing left is the title on its monolith, one board (Most Wins, on a low slab at the foot of the
-- throne's mesa) and the names on the Academy's gate and altars.
-- South-west lies the Academy, a ring of broken pillars with a practice altar for every skill and three
-- wooden puppets to practise on, hung on strings from a great hand; two old causeways over chasms lead to the plateaus of the Spire Ascent and the
-- rune courtyard, and the dice rock and the stone-toss wait in the basin itself.
--
-- SceneBuilder puts up the scene (or its greybox, without the import); this module builds what
-- shows text or does something, at the scene's anchors. The Academy only tags parts (LTraining
-- drill desks, LDummy torsos); the drills run on each player's client and never touch a match.
-- The mini-games' objects are LobbyGames', the things that sway in the wind LobbyDecor's, and the
-- candles, the rift's guard and the other fixtures LobbyFixtures'.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))
local Assets = require(Shared:WaitForChild("Assets"))
local Terms = require(Shared:WaitForChild("Terms"))

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyFixtures = require(script.Parent.LobbyFixtures)
local LobbyGames = require(script.Parent.LobbyGames)
local SceneBuilder = require(script.Parent.SceneBuilder)

local Lobby = {}

local GOLD = Color3.fromRGB(163, 170, 181) -- the grey of the UI's secondary text
local INK = Color3.fromRGB(12, 12, 14)
local SLATE = Color3.fromRGB(16, 16, 20)
local STONE = Color3.fromRGB(58, 58, 62)

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number? }

local STONE_TOP = 0.6 -- the low stone each practice figure stands (or hangs) over
local HAND_HEIGHT = 22 -- how high over the figures' ground the hand's fingertips are

-- The practice dummies' aliases and real names (names from the real name pools).
local DUMMIES = {
	{ alias = "Dummy A", name = "Kenji Mori" },
	{ alias = "Dummy B", name = "Mei Sato" },
	{ alias = "Dummy C", name = "Hina Ogawa" },
}

-- drill id and the name on its plaque: one case-file altar per station type, then the Grimoire, the
-- warrant and the eyes. They take the scene's altars in order (drill1, drill2...). The name is all
-- the plaque says; what a drill asks of you, it says itself when you start it.
local DRILLS = {}
for _, id in ipairs(TaskTypes.LIST) do
	local info = TaskTypes.get(id)
	table.insert(DRILLS, { info.drill, info.drillTitle })
end
for _, drill in ipairs({
	{ "grimoire", Terms.NAMES.GRIMOIRE },
	{ "warrant", "THE WARRANT" },
	{ "eyes", Terms.NAMES.EYES },
}) do
	table.insert(DRILLS, drill)
end

-- pixelsPerStud: more for a small card, so its lettering is not cut off at the smallest size text is
-- drawn at (40 by default).
local function signText(board: BasePart, text: string, color: Color3, font: Enum.Font, pixelsPerStud: number?)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pixelsPerStud or 40,
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
	local id, title = drill[1], drill[2]
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
	local plaque = b:part(Vector3.new(6, 1.5, 0.3), base * CFrame.new(0, 6.5, 2.1), SLATE, Enum.Material.SmoothPlastic)
	signText(plaque, title, GOLD, Enum.Font.SpecialElite)
end

-- A figure for the drills to point at, on a low stone. Every client hangs a wooden puppet on strings
-- in its place (World/Puppets, once the Lobby models are imported: the puppet's feet a hand's width
-- above the stone, the strings up to the hand over the three); until then this plain grey mannequin
-- stands on the stone. Its torso carries the tag and the names, and its name tag is pinned on its chest
-- (the puppet's clients carry the tag along on the puppet's chest). A drill's reaction plays on the
-- drilling player's screen only (client PracticePanel, through Puppets).
local function dummy(b, info, a: Anchor)
	-- The stone is not the figure's: the figure tips over (or the puppet drops) onto it.
	b:part(
		Vector3.new(STONE_TOP, 3.2, 3.2),
		b:cf(a.x, STONE_TOP / 2, a.z, a.rot) * CFrame.Angles(0, 0, math.rad(90)),
		STONE,
		Enum.Material.Slate,
		{ Shape = Enum.PartType.Cylinder, Name = "PracticeStone" }
	)
	local model = Create("Model", { Name = "Dummy_" .. info.alias, Parent = b.parent })
	local grey = Color3.fromRGB(150, 146, 140)
	local base = b:cf(a.x, STONE_TOP, a.z, a.rot)
	local function piece(size: Vector3, offset: CFrame, shape: Enum.PartType?)
		return b:part(
			size,
			base * offset,
			grey,
			Enum.Material.SmoothPlastic,
			{ Parent = model, Shape = shape or Enum.PartType.Block, Name = "Figure" }
		)
	end
	piece(Vector3.new(0.9, 2.6, 0.9), CFrame.new(-0.5, 1.3, 0))
	piece(Vector3.new(0.9, 2.6, 0.9), CFrame.new(0.5, 1.3, 0))
	local torso = piece(Vector3.new(2, 2.4, 1), CFrame.new(0, 3.8, 0))
	piece(Vector3.new(0.8, 2.3, 0.8), CFrame.new(-1.45, 3.85, 0))
	piece(Vector3.new(0.8, 2.3, 0.8), CFrame.new(1.45, 3.85, 0))
	piece(Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 5.8, 0), Enum.PartType.Ball)
	torso.Name = "Torso"
	model.PrimaryPart = torso
	torso:SetAttribute("Alias", info.alias)
	torso:SetAttribute("PracticeName", info.name)
	-- Where the feet stand (the puppet hangs a hand's width above it), from the torso.
	torso:SetAttribute("Feet", CFrame.new(0, -3.8, 0))
	torso:AddTag("LDummy")
	-- The name tag, a paper card pinned on the chest.
	local tag = b:part(
		Vector3.new(1.1, 0.55, 0.05),
		base * CFrame.new(0, 4.25, -0.53) * CFrame.Angles(0, 0, math.rad(-4)),
		Color3.fromRGB(214, 206, 186),
		Enum.Material.SmoothPlastic,
		{ Parent = model, Name = "Tag", CanCollide = false, CanQuery = false }
	)
	signText(tag, string.upper(info.alias), INK, Enum.Font.SpecialElite, 120)
end

-- The mark for the hand over the three figures (World/Puppets hangs it there): the middle of its
-- fingertips HAND_HEIGHT studs over the middle of the three, facing the way they face.
local function handMark(b, anchors: { [string]: Anchor })
	local sum, count, rot = Vector3.zero, 0, 0
	for index = 1, #DUMMIES do
		local a = anchors["dummy" .. index]
		if a then
			sum += Vector3.new(a.x, a.y, a.z)
			count += 1
			rot = a.rot
		end
	end
	if count == 0 then
		return
	end
	local middle = sum / count
	local mark = b:part(
		Vector3.new(1, 1, 1),
		b:cf(middle.X, middle.Y + HAND_HEIGHT, middle.Z, rot),
		STONE,
		Enum.Material.SmoothPlastic,
		{ Name = "PuppeteerHand", Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
	)
	mark:AddTag("LPuppeteer")
end

-- The Academy's name over its gate, its drill altars, the practice figures and the hand over them.
local function academy(b, anchors: { [string]: Anchor })
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
	handMark(b, anchors)
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

	-- The one board in the world: Most Wins, on the low slab at the foot of the throne's mesa. The other
	-- boards (experience, the week, the mini-games) are in the Leaderboards window; the next case and the
	-- quests are on the lobby's own page.
	local boards = {}
	if anchors.wins then
		local _, label = sign(b, anchors.wins, "", Color3.fromRGB(235, 232, 225), SLATE, Enum.Font.SpecialElite)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		Create("UITextSizeConstraint", { MaxTextSize = 34, Parent = label })
		boards.wins = label
	else
		warn("[DeathsGambit] The lobby scene has no board for wins.")
	end

	LobbyDecor.build(b, anchors)
	LobbyFixtures.build(b, anchors)
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
		boards = boards,
		spawnCFrame = spawnCFrame,
		games = games,
	}
end

return Lobby
