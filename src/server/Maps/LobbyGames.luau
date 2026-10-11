--!strict
-- The lobby mini-games' objects, built at the scene's anchors (art/scripts/maps/venues/lobby): the
-- Spire Ascent's start pad and checkpoint pylons, the rune courtyard's nine tiles and start pad, the
-- dice rock's two dice, board and four seats, the stone-toss cairn, the rift's numbers for the dive, the
-- bell of Death's mark and the seven grey apples. Everything is tagged (LParkourStart,
-- LParkourCheckpoint, LRuneStart, LRuneTile, LDiceSeat, LTossCairn, LRift, LMarkBell, LApple) so each
-- client puts up its own prompts (client Controllers/LobbyGamesController); the rules and every score
-- are the server's (Services/LobbyGameService), which is handed the table this returns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))

local LobbyGames = {}

local SLATE = Color3.fromRGB(34, 34, 40)
local STONE = Color3.fromRGB(58, 58, 64)
local GLOW = Color3.fromRGB(176, 196, 224)
local DIM = Color3.fromRGB(74, 82, 100)
local BONE = Color3.fromRGB(206, 200, 186)
local INK = Color3.fromRGB(16, 16, 20)

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number?, rx: number?, rz: number? }

export type Games = {
	parkour: { start: Vector3, center: Vector3, marks: { Vector3 } },
	runes: { start: Vector3, center: Vector3, tile: number, gap: number },
	dice: { rock: Vector3, seats: { Seat }, dice: { BasePart }, faces: { TextLabel }, board: TextLabel },
	toss: { cairn: Vector3, rift: { cx: number, cz: number, rx: number, rz: number, turn: number } },
	-- The dive: the rift's shape, the rim's and the landing roof's heights, where a diver is set down after.
	dive: {
		rift: { cx: number, cz: number, rx: number, rz: number, turn: number },
		rimY: number,
		roofY: number,
		back: Vector3,
	}?,
	mark: { bell: Vector3, mouth: Vector3 }?,
	apples: { Vector3 },
}

-- Glyphs for the nine tiles: bars (x, z, width, depth, turn in degrees) on a 7-stud tile.
local GLYPHS = {
	{ { 0, 0, 4.4, 0.5, 0 }, { 0, 0, 4.4, 0.5, 90 } },
	{ { 0, 0, 5.2, 0.5, 45 }, { 0, 0, 5.2, 0.5, -45 } },
	{ { -1.6, 0, 0.5, 4.6, 0 }, { 0, 0, 0.5, 4.6, 0 }, { 1.6, 0, 0.5, 4.6, 0 } },
	{ { 0, -2.1, 4.2, 0.5, 0 }, { 0, 2.1, 4.2, 0.5, 0 }, { -2.1, 0, 0.5, 4.2, 0 }, { 2.1, 0, 0.5, 4.2, 0 } },
	{ { 0, 0, 1, 1, 0 }, { 0, -2, 3.6, 0.4, 0 }, { 0, 2, 3.6, 0.4, 0 } },
	{ { 0, 0, 5.4, 0.5, 35 } },
	{ { -1.6, 0, 0.5, 4.4, 0 }, { 0.2, 1.9, 3.6, 0.5, 0 } },
	{ { 0, -1.8, 4.4, 0.5, 0 }, { 0, 0.3, 0.5, 4.4, 0 } },
	{ { -1.8, 0, 0.5, 4.4, 0 }, { 1.8, 0, 0.5, 4.4, 0 }, { 0, 0, 3.6, 0.5, 0 } },
}

local function inert(part: BasePart)
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = Create("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Anchored = true,
		Parent = parent,
	}) :: BasePart
	return p
end

-- A square outline of cold light lying flat (a pad's border).
local function outline(parent: Instance, base: CFrame, size: number)
	for _, side in ipairs({ { 0, -1, size, 0.2 }, { 0, 1, size, 0.2 }, { -1, 0, 0.2, size }, { 1, 0, 0.2, size } }) do
		local bar = part(
			parent,
			"Border",
			Vector3.new(side[3], 0.06, side[4]),
			base * CFrame.new(side[1] * size / 2, 0.16, side[2] * size / 2),
			GLOW,
			Enum.Material.Neon
		)
		inert(bar)
		bar.CanCollide = false
	end
end

local function pad(b, parent: Instance, name: string, tag: string, a: Anchor, size: number): BasePart
	local base = b:world(b:cf(a.x, a.y, a.z, a.rot))
	local p =
		part(parent, name, Vector3.new(size, 0.3, size), base * CFrame.new(0, 0.15, 0), SLATE, Enum.Material.Slate)
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p:AddTag(tag)
	outline(parent, base, size - 1)
	return p
end

local function parkour(b, folder: Instance, anchors: { [string]: Anchor })
	local startAnchor = anchors.pkStart
	pad(b, folder, "SpirePad", "LParkourStart", startAnchor, 8)
	local marks = {}
	for index = 1, 10 do
		local a = anchors["pk" .. index]
		if not a then
			warn("[DeathsGambit] The lobby scene has no checkpoint pk" .. index .. ".")
			break
		end
		local finish = index == 10
		local height = if finish then 6 else 3.6
		local base = b:world(CFrame.new(a.x, a.y, a.z))
		local pylon = part(
			folder,
			"Checkpoint" .. index,
			Vector3.new(if finish then 1.4 else 0.8, height, if finish then 1.4 else 0.8),
			base * CFrame.new(0, height / 2, 0),
			STONE,
			Enum.Material.Slate
		)
		inert(pylon)
		pylon.CanCollide = false
		pylon:SetAttribute("Index", index)
		pylon:AddTag("LParkourCheckpoint")
		local cap = part(
			folder,
			"Cap",
			Vector3.new(1.1, 0.3, 1.1),
			base * CFrame.new(0, height + 0.15, 0),
			GLOW,
			Enum.Material.Neon
		)
		inert(cap)
		cap.CanCollide = false
		Create("PointLight", { Color = GLOW, Range = 16, Brightness = 0.6, Parent = cap })
		table.insert(marks, b:worldPos(a.x, a.y, a.z))
	end
	local centre = anchors.pkCenter
	return {
		start = b:worldPos(startAnchor.x, startAnchor.y, startAnchor.z),
		center = b:worldPos(centre.x, 0, centre.z),
		marks = marks,
	}
end

local function runes(b, folder: Instance, anchors: { [string]: Anchor })
	local tile, gap = 7, 1.8
	for index = 1, 9 do
		local a = anchors["rune" .. index]
		if not a then
			warn("[DeathsGambit] The lobby scene has no rune tile " .. index .. ".")
		else
			tile = a.w or tile
			local base = b:world(CFrame.new(a.x, a.y + 0.25, a.z))
			local slab =
				part(folder, "RuneTile" .. index, Vector3.new(tile, 0.5, tile), base, SLATE, Enum.Material.Slate)
			slab.CanCollide = true
			slab.CanQuery = true
			slab.CanTouch = false
			slab.CastShadow = false
			slab:SetAttribute("Index", index)
			slab:AddTag("LRuneTile")
			for _, bar in ipairs(GLYPHS[index]) do
				local glyph = part(
					folder,
					"Glyph" .. index,
					Vector3.new(bar[3], 0.08, bar[4]),
					base * CFrame.new(bar[1], 0.29, bar[2]) * CFrame.Angles(0, math.rad(bar[5]), 0),
					DIM,
					Enum.Material.Neon
				)
				inert(glyph)
				glyph.CanCollide = false
				glyph.Transparency = 0.35
				glyph:SetAttribute("Tile", index)
				glyph:AddTag("LRuneGlyph")
			end
		end
	end
	local startAnchor = anchors.runeStart
	pad(b, folder, "RunePad", "LRuneStart", startAnchor, 6)
	local centre = anchors.runeCenter
	return {
		start = b:worldPos(startAnchor.x, startAnchor.y, startAnchor.z),
		center = b:worldPos(centre.x, anchors.rune5.y, centre.z),
		tile = tile,
		gap = gap,
	}
end

local function dice(b, folder: Instance, anchors: { [string]: Anchor })
	local rock = anchors.diceRock
	local seats = {}
	for index = 1, 4 do
		local a = anchors["diceSeat" .. index]
		local seat = Create("Seat", {
			Name = "DiceSeat" .. index,
			Size = Vector3.new(2.2, 0.4, 2.2),
			CFrame = b:world(b:cf(a.x, 1.85, a.z, a.rot)),
			Transparency = 1,
			Anchored = true,
			CanCollide = false,
			CanQuery = true,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		}) :: Seat
		seat:SetAttribute("Seat", index)
		seat:AddTag("LDiceSeat")
		table.insert(seats, seat)
	end
	local dies, faces = {}, {}
	for index, offset in ipairs({ Vector3.new(-1.7, 0, 1.5), Vector3.new(-0.3, 0, 2.1) }) do
		local die = part(
			folder,
			"Die" .. index,
			Vector3.new(1.1, 1.1, 1.1),
			b:world(
				CFrame.new(rock.x + offset.X, rock.y + 0.58, rock.z + offset.Z)
					* CFrame.Angles(0, math.rad(index * 31), 0)
			),
			BONE,
			Enum.Material.SmoothPlastic
		)
		inert(die)
		die.CanCollide = false
		local gui = Create("SurfaceGui", {
			Face = Enum.NormalId.Top,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 80,
			LightInfluence = 1,
			Parent = die,
		})
		local face = Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			TextColor3 = INK,
			TextScaled = true,
			FontFace = WorldFont.face(Enum.Font.GrenzeGotisch),
			Parent = gui,
		}) :: TextLabel
		table.insert(dies, die)
		table.insert(faces, face)
	end
	local boardPart = part(
		folder,
		"DiceBoard",
		Vector3.new(1, 1, 1),
		b:world(CFrame.new(rock.x, rock.y + 5.2, rock.z)),
		SLATE,
		Enum.Material.SmoothPlastic
	)
	inert(boardPart)
	boardPart.CanCollide = false
	boardPart.Transparency = 1
	local gui = Create("BillboardGui", {
		Size = UDim2.fromOffset(300, 78),
		StudsOffset = Vector3.new(0, 0, 0),
		MaxDistance = 70,
		LightInfluence = 0,
		AlwaysOnTop = false,
		Parent = boardPart,
	})
	local board = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "BONE DICE",
		TextColor3 = Color3.fromRGB(226, 222, 212),
		TextStrokeTransparency = 0.4,
		TextScaled = true,
		FontFace = WorldFont.face(Enum.Font.SpecialElite),
		Parent = gui,
	}) :: TextLabel
	return {
		rock = b:worldPos(rock.x, rock.y, rock.z),
		seats = seats,
		dice = dies,
		faces = faces,
		board = board,
	}
end

-- The rift, for the dive: an unseen part tagged LRift carrying the numbers every client flies by (the rift's
-- ellipse, the rim's height and the landing roof's), and where a diver is set down afterwards (on the
-- plaza's side of the rim).
local function dive(b, folder: Instance, anchors: { [string]: Anchor })
	local rift, landing = anchors.rift, anchors.landing
	if not rift or not landing then
		return nil
	end
	local rx, rz = rift.rx or 23, rift.rz or 15
	local rim = b:worldPos(rift.x, 0, rift.z)
	local roof = b:worldPos(landing.x, landing.y, landing.z)
	-- Towards the lobby's middle, a few studs outside the balustrade.
	local toMiddle = Vector3.new(-rift.x, 0, -rift.z)
	toMiddle = if toMiddle.Magnitude > 1 then toMiddle.Unit else Vector3.new(-1, 0, 0)
	local back = rim + toMiddle * (math.max(rx, rz) * 1.08 + 9)
	local mark = part(folder, "Rift", Vector3.new(1, 1, 1), CFrame.new(rim), STONE, Enum.Material.Slate)
	inert(mark)
	mark.CanCollide = false
	mark.Transparency = 1
	mark:SetAttribute("Cx", rim.X)
	mark:SetAttribute("Cz", rim.Z)
	mark:SetAttribute("Rx", rx)
	mark:SetAttribute("Rz", rz)
	mark:SetAttribute("Turn", rift.rot)
	mark:SetAttribute("RimY", rim.Y)
	mark:SetAttribute("RoofY", roof.Y)
	mark:AddTag("LRift")
	return {
		rift = { cx = rim.X, cz = rim.Z, rx = rx, rz = rz, turn = rift.rot },
		rimY = rim.Y,
		roofY = roof.Y,
		back = back,
	}
end

-- Death's mark: the bell's prompt (an unseen part tagged LMarkBell under the bell).
local function bell(b, folder: Instance, anchors: { [string]: Anchor })
	local a = anchors.bell
	if not a then
		return nil
	end
	local prompt =
		part(folder, "MarkBell", Vector3.new(5, 6, 5), b:world(b:cf(a.x, 3, a.z, a.rot)), STONE, Enum.Material.Slate)
	inert(prompt)
	prompt.CanCollide = false
	prompt.CanQuery = true
	prompt.Transparency = 1
	prompt:AddTag("LMarkBell")
	return { bell = b:worldPos(a.x, 0, a.z), mouth = b:worldPos(a.x, a.y, a.z) }
end

-- The seven grey apples: a small grey fruit at each anchor (tag LApple, attribute Index). Every client hides
-- the ones its player has found already.
local function apples(b, folder: Instance, anchors: { [string]: Anchor })
	local spots = {}
	local index = 1
	while anchors["apple" .. index] do
		local a = anchors["apple" .. index]
		local at = b:world(CFrame.new(a.x, a.y + 1.3, a.z))
		local fruit = Create("Part", {
			Name = "Apple" .. index,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = at,
			Color = Color3.fromRGB(128, 128, 134),
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			Parent = folder,
		}) :: BasePart
		inert(fruit)
		fruit.CanCollide = false
		fruit.CanQuery = true
		local stem = part(
			folder,
			"Stem",
			Vector3.new(0.12, 0.45, 0.12),
			at * CFrame.new(0.05, 0.72, 0) * CFrame.Angles(0, 0, math.rad(-14)),
			INK,
			Enum.Material.SmoothPlastic
		)
		inert(stem)
		stem.CanCollide = false
		stem.Parent = fruit
		Create("PointLight", { Color = GLOW, Range = 7, Brightness = 0.5, Shadows = false, Parent = fruit })
		fruit:SetAttribute("Index", index)
		fruit:AddTag("LApple")
		table.insert(spots, fruit.Position)
		index += 1
	end
	return spots
end

local function toss(b, folder: Instance, anchors: { [string]: Anchor })
	local a, rift = anchors.toss, anchors.rift
	local prompt =
		part(folder, "TossCairn", Vector3.new(6, 5, 6), b:world(b:cf(a.x, 2.5, a.z, a.rot)), STONE, Enum.Material.Slate)
	inert(prompt)
	prompt.CanCollide = false
	prompt.CanQuery = true
	prompt.Transparency = 1
	prompt:AddTag("LTossCairn")
	return {
		cairn = b:worldPos(a.x, 0, a.z),
		rift = { cx = rift.x, cz = rift.z, rx = rift.rx or 23, rz = rift.rz or 15, turn = rift.rot },
	}
end

function LobbyGames.build(b, anchors: { [string]: Anchor }): Games
	local folder = Create("Folder", { Name = "Games", Parent = b.parent })
	return {
		parkour = parkour(b, folder, anchors),
		runes = runes(b, folder, anchors),
		dice = dice(b, folder, anchors),
		toss = toss(b, folder, anchors),
		dive = dive(b, folder, anchors),
		mark = bell(b, folder, anchors),
		apples = apples(b, folder, anchors),
	}
end

return LobbyGames
