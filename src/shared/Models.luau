-- Models used in the world, in cutscenes and in previews. Each returns a fresh Model whose
-- parts are anchored and never collide: the Blender prop when it has been imported
-- (ModelLibrary), otherwise a part-built stand-in.

local Assets = require(script.Parent.Assets)
local Create = require(script.Parent.Create)
local WorldFont = require(script.Parent.WorldFont)
local ManualBook = require(script.Parent.ManualBook)
local ModelLibrary = require(script.Parent.ModelLibrary)

local Models = {}

local INK = Color3.fromRGB(12, 12, 14)
local PAPER = Color3.fromRGB(244, 245, 247)
local RED = Color3.fromRGB(209, 26, 42)
local STEEL = Color3.fromRGB(160, 162, 170)

local function part(model: Model, props: { [string]: any }): BasePart
	local defaults: { [string]: any } = {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = model,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return Create("Part", defaults)
end

local function prepare(model: Model): Model
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model
end

local function custom(key: string): Model?
	local imported = ModelLibrary.get(key)
	if imported then
		for _, item in ipairs(imported:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.CanQuery = false
			end
		end
		return imported
	end
	local model = Assets.model(key)
	if model and model:IsA("Model") then
		return prepare(model)
	end
	return nil
end

-- A fountain pen standing along Y, or nil.
function Models.pen(): Model?
	return custom("Pen")
end

-- The match suit's cloth for one body part ("SuitTorso" or "SuitLimb"), or nil before the import.
function Models.suit(key: string): Model?
	return custom(key)
end

-- Death's Manual, closed and lying flat, centred on its pivot, ready to open (ManualBook). Before the
-- import, a part-built book in the same pieces at the same places: black boards, amber pages, three
-- loose leaves on top, nothing that glows.
local MANUAL_PAGE_AT = { -0.019, 0.135, 0.161 } -- (ModelCatalog's page.at, for a catalog without one)
local MANUAL_LEATHER = Color3.fromRGB(18, 17, 19)
local MANUAL_PAGES = Color3.fromRGB(178, 100, 36)

function Models.grimoire(): Model
	local existing = custom("Grimoire")
	if existing then
		return ManualBook.rig(existing)
	end
	local info = ModelLibrary.info("Grimoire")
	local at = if info and info.page then info.page.at else MANUAL_PAGE_AT
	local top = Vector3.new(at[1], at[2], at[3]) -- the middle of the open page
	local pageSize = Vector2.new(1.895, 2.58)
	local gutter = top.X + pageSize.X / 2 -- the joint side (the spine's)
	local board = Vector3.new(1.955, 0.05, 2.7)
	local boardX = gutter - board.X / 2
	local model = Instance.new("Model")
	model.Name = "Grimoire"
	local body = part(model, {
		Name = "Grimoire",
		Size = board,
		CFrame = CFrame.new(boardX, top.Y - 0.3 - board.Y / 2, top.Z),
		Color = MANUAL_LEATHER,
		Material = Enum.Material.Leather,
	})
	part(model, {
		Name = "Block",
		Size = Vector3.new(pageSize.X, 0.3, pageSize.Y),
		CFrame = CFrame.new(top.X, top.Y - 0.15, top.Z),
		Color = MANUAL_PAGES,
		Material = Enum.Material.SmoothPlastic, -- (paper is smooth: Fabric reads as cloth this close)
	})
	part(model, {
		Name = "Spine",
		Size = Vector3.new(0.08, 0.43, board.Z),
		CFrame = CFrame.new(gutter + 0.04, top.Y - 0.135, top.Z),
		Color = MANUAL_LEATHER,
		Material = Enum.Material.Leather,
	})
	part(model, {
		Name = "Ribbon",
		Size = Vector3.new(0.11, 0.012, 0.44),
		CFrame = CFrame.new(gutter - 1.255, top.Y - 0.02, top.Z - 1.45),
		Color = INK,
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	for leaf = 1, 3 do
		part(model, {
			Name = "Grimoire_Leaf" .. leaf,
			Size = Vector3.new(pageSize.X - 0.02, 0.004, pageSize.Y - 0.012),
			CFrame = CFrame.new(top.X - 0.01, top.Y + 0.006 + 0.008 * (leaf - 1), top.Z),
			Color = MANUAL_PAGES,
			Material = Enum.Material.SmoothPlastic,
		})
	end
	part(model, {
		Name = "Grimoire_Cover",
		Size = board,
		CFrame = CFrame.new(boardX, top.Y + 0.03 + board.Y / 2, top.Z),
		Color = MANUAL_LEATHER,
		Material = Enum.Material.Leather,
	})
	model.PrimaryPart = body
	-- (Everything above is placed from the pivot, the middle of the closed book, as an import's is.)
	body.PivotOffset = body.CFrame:Inverse()
	return ManualBook.rig(model)
end

-- A pair of handcuffs: two steel rings and a short chain, lying flat.
function Models.handcuffs(): Model
	local existing = custom("Handcuffs")
	if existing then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "Handcuffs"
	local left = part(model, {
		Name = "LeftCuff",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 0.75, 0.75),
		CFrame = CFrame.new(-0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STEEL,
		Material = Enum.Material.Metal,
	})
	part(model, {
		Name = "RightCuff",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.18, 0.75, 0.75),
		CFrame = CFrame.new(0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STEEL,
		Material = Enum.Material.Metal,
	})
	part(model, {
		Name = "Chain",
		Size = Vector3.new(0.3, 0.08, 0.08),
		CFrame = CFrame.new(0, 0, 0),
		Color = STEEL,
		Material = Enum.Material.Metal,
	})
	model.PrimaryPart = left
	return model
end

-- The Specter: a tall cloaked figure with a bone-white skull face, red eyes and ragged wings.
-- About 9 studs tall; the PrimaryPart ("Core") is at chest height.
function Models.specter(): Model
	local existing = custom("Specter")
	if existing then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "Specter"
	local core = part(model, {
		Name = "Core",
		Size = Vector3.new(2.6, 3.2, 1.8),
		Color = INK,
		Material = Enum.Material.Fabric,
	})
	-- The cloak widens towards the ground in three tiers.
	for index, tier in ipairs({ { 2.9, 2.2 }, { 3.4, 2.6 }, { 3.9, 3 } }) do
		part(model, {
			Name = "Cloak" .. index,
			Size = Vector3.new(tier[1], 1.4, tier[2]),
			CFrame = CFrame.new(0, -1.4 - index * 1.2, 0.1 * index),
			Color = Color3.fromRGB(10, 10, 12),
			Material = Enum.Material.Fabric,
		})
	end
	local hood = part(model, {
		Name = "Hood",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.3, 2.3, 2.3),
		CFrame = CFrame.new(0, 2.5, 0.15),
		Color = INK,
		Material = Enum.Material.Fabric,
	})
	local skull = part(model, {
		Name = "Skull",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 1.7, 1.4),
		CFrame = CFrame.new(0, 2.4, -0.45),
		Color = Color3.fromRGB(232, 226, 210),
		Material = Enum.Material.SmoothPlastic,
	})
	for _, side in ipairs({ -0.3, 0.3 }) do
		part(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.34, 0.26, 0.2),
			CFrame = skull.CFrame * CFrame.new(side, 0.12, -0.62),
			Color = Color3.fromRGB(255, 30, 40),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
	end
	part(model, {
		Name = "Grin",
		Size = Vector3.new(0.7, 0.08, 0.1),
		CFrame = skull.CFrame * CFrame.new(0, -0.45, -0.62),
		Color = Color3.fromRGB(20, 18, 18),
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	-- Ragged wings: three thin blades per side, fanned out behind the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		for index = 1, 3 do
			part(model, {
				Name = "Wing",
				Size = Vector3.new(0.12, 4.5 - index * 0.6, 1.1),
				CFrame = CFrame.new(side * 1.6, 1.4, 0.9)
					* CFrame.Angles(0, math.rad(side * 25), math.rad(side * (30 + index * 22)))
					* CFrame.new(0, (4.5 - index * 0.6) / 2, 0),
				Color = Color3.fromRGB(18, 16, 20),
				Material = Enum.Material.Fabric,
			})
		end
	end
	-- Long arms hanging from the cloak.
	for _, side in ipairs({ -1, 1 }) do
		part(model, {
			Name = "Arm",
			Size = Vector3.new(0.5, 3.4, 0.5),
			CFrame = CFrame.new(side * 1.6, -0.4, -0.1) * CFrame.Angles(0, 0, math.rad(side * 8)),
			Color = INK,
			Material = Enum.Material.Fabric,
		})
	end
	Create("PointLight", { Color = Color3.fromRGB(255, 40, 50), Brightness = 2, Range = 10, Parent = hood })
	model.PrimaryPart = core
	return model
end

-- A small standing card with a name, for the empty place of a dead player at the table.
function Models.memorial(alias: string): Model
	local imported = custom("Memorial")
	if imported then
		-- The alias goes on an invisible card over the mesh card.
		local pivot = imported:GetPivot()
		local label = part(imported, {
			Name = "Label",
			Size = Vector3.new(1.5, 1.0, 0.05),
			CFrame = pivot * CFrame.new(0, 2.62, -0.1),
			Transparency = 1,
			CastShadow = false,
		})
		local gui = Create("SurfaceGui", {
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 60,
			LightInfluence = 0.6,
			Parent = label,
		})
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.6),
			Text = string.upper(alias),
			TextScaled = true,
			TextColor3 = INK,
			FontFace = WorldFont.face(Enum.Font.Oswald),
			Parent = gui,
		})
		return imported
	end
	local model = Instance.new("Model")
	model.Name = "Memorial"
	-- The pivot is the foot of the stand, on the floor; the card faces forward (-Z).
	local base = part(model, {
		Name = "Base",
		Size = Vector3.new(0.9, 0.1, 0.9),
		CFrame = CFrame.new(0, 0.05, 0),
		Color = INK,
		Material = Enum.Material.Metal,
	})
	part(model, {
		Name = "Post",
		Size = Vector3.new(0.12, 2.1, 0.12),
		CFrame = CFrame.new(0, 1.1, 0),
		Color = INK,
		Material = Enum.Material.Metal,
	})
	local card = part(model, {
		Name = "Card",
		Size = Vector3.new(1.6, 1.1, 0.08),
		CFrame = CFrame.new(0, 2.6, 0),
		Color = PAPER,
		Material = Enum.Material.SmoothPlastic,
		CastShadow = false,
	})
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		LightInfluence = 0.6,
		Parent = card,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.62),
		Text = string.upper(alias),
		TextScaled = true,
		TextColor3 = INK,
		FontFace = WorldFont.face(Enum.Font.Oswald),
		Parent = gui,
	})
	Create("Frame", {
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.1, 0.72),
		Size = UDim2.fromScale(0.8, 0.08),
		Parent = gui,
	})
	model.PrimaryPart = base
	return model
end

-- Death's Manual held open in the hands (Diavolo writes in it in plain sight, the shop's
-- preview of a cover): opened, at a hand's size, the board lying over to the holder's left as a book's
-- does and the page's head away from them, its open middle at `at`. With `coverColor`, the outside of the
-- board (facing down and out, what the others see) wears that colour. Anchored; the caller places it.
local HELD_SCALE = 0.43

-- A cover cosmetic's look on the board (Shared/Cosmetics `style` of a grimoire item): its plate's material, and
-- small pieces laid on it, in the plate's own frame (x across, z along the board, y up off it; w, d its size).
type Lay = (
	plate: CFrame,
	w: number,
	d: number,
	add: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> BasePart,
	open: boolean? -- the book held open as it is written in (a cover may change then: Death God's Hide opens its eye)
) -> ()
local BRASS = Color3.fromRGB(150, 118, 58)
local GOLD = Color3.fromRGB(206, 166, 70)
local IRON = Color3.fromRGB(58, 60, 64)
-- Little pieces many covers share: brass corner pieces bent round the board's corners, stitching along an edge.
local function corners(
	plate: CFrame,
	w: number,
	d: number,
	add: (Vector3, CFrame, Color3, Enum.Material?) -> BasePart,
	color: Color3
)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- (an L of metal: one arm along each edge, a stud where they meet)
			add(
				Vector3.new(w * 0.16, 0.03, d * 0.035),
				plate * CFrame.new(sx * w * 0.41, 0.012, sz * d * 0.465),
				color,
				Enum.Material.Metal
			)
			add(
				Vector3.new(w * 0.035, 0.03, d * 0.13),
				plate * CFrame.new(sx * w * 0.475, 0.012, sz * d * 0.41),
				color,
				Enum.Material.Metal
			)
			local stud = add(
				Vector3.new(w * 0.04, 0.04, w * 0.04),
				plate * CFrame.new(sx * w * 0.455, 0.018, sz * d * 0.445),
				color:Lerp(Color3.new(1, 1, 1), 0.15),
				Enum.Material.Metal
			)
			stud.Shape = Enum.PartType.Ball
		end
	end
end

local function stitches(
	plate: CFrame,
	from: Vector3,
	to: Vector3,
	count: number,
	add: (Vector3, CFrame, Color3, Enum.Material?) -> BasePart,
	color: Color3,
	w: number
)
	local step = (to - from) / count
	local along = if math.abs(step.X) > math.abs(step.Z) then "x" else "z"
	for k = 0, count - 1 do
		local at = from + step * (k + 0.5)
		add(
			if along == "x"
				then Vector3.new(step.Magnitude * 0.55, 0.012, w * 0.012)
				else Vector3.new(w * 0.012, 0.012, step.Magnitude * 0.55),
			plate * CFrame.new(at),
			color
		)
	end
end

local COVERS: { [string]: { material: Enum.Material, lay: Lay? } } = {
	-- Oxblood Hide (redesigned 2026-10-22, detailed 2026-10-25): cracked oxblood leather that still has a pulse,
	-- brass corners bent round the board, a black stitched spine strip, saddle stitching all round its edge and an
	-- oval medallion pressed into the middle under a brass rim
	oxblood = {
		material = Enum.Material.Leather,
		lay = function(plate, w, d, add)
			corners(plate, w, d, add, BRASS)
			add(
				Vector3.new(w * 0.06, 0.025, d * 0.98),
				plate * CFrame.new(w * 0.47, 0.01, 0),
				Color3.fromRGB(14, 12, 12)
			)
			local thread = Color3.fromRGB(196, 170, 120)
			local ix, iz = w * 0.4, d * 0.43
			stitches(plate, Vector3.new(-ix, 0.012, -iz), Vector3.new(ix, 0.012, -iz), 12, add, thread, w)
			stitches(plate, Vector3.new(-ix, 0.012, iz), Vector3.new(ix, 0.012, iz), 12, add, thread, w)
			stitches(plate, Vector3.new(-ix, 0.012, -iz), Vector3.new(-ix, 0.012, iz), 14, add, thread, w)
			local medal = add(
				Vector3.new(0.02, w * 0.36, w * 0.28),
				plate * CFrame.new(0, 0.008, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(64, 12, 16),
				Enum.Material.Leather
			)
			medal.Shape = Enum.PartType.Cylinder
			local rim = add(
				Vector3.new(0.014, w * 0.4, w * 0.32),
				plate * CFrame.new(0, 0.004, 0) * CFrame.Angles(0, 0, math.rad(90)),
				BRASS,
				Enum.Material.Metal
			)
			rim.Shape = Enum.PartType.Cylinder
		end,
	},
	-- Gilded Requiem (detailed 2026-10-25): black lacquer under a gilt frame, fleurons in its corners, a lozenge in the
	-- middle with a black heart and gilt rays out from it like a requiem's sunburst
	gilded = {
		material = Enum.Material.SmoothPlastic,
		lay = function(plate, w, d, add)
			for _, sz in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.86, 0.02, d * 0.025),
					plate * CFrame.new(0, 0.01, sz * d * 0.42),
					GOLD,
					Enum.Material.Metal
				)
				add(
					Vector3.new(w * 0.78, 0.016, d * 0.012),
					plate * CFrame.new(0, 0.01, sz * d * 0.37),
					GOLD,
					Enum.Material.Metal
				)
			end
			for _, sx in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.025, 0.02, d * 0.86),
					plate * CFrame.new(sx * w * 0.42, 0.01, 0),
					GOLD,
					Enum.Material.Metal
				)
				add(
					Vector3.new(w * 0.012, 0.016, d * 0.76),
					plate * CFrame.new(sx * w * 0.37, 0.01, 0),
					GOLD,
					Enum.Material.Metal
				)
				for _, sz in ipairs({ -1, 1 }) do
					add(
						Vector3.new(w * 0.07, 0.022, w * 0.07),
						plate * CFrame.new(sx * w * 0.42, 0.012, sz * d * 0.42) * CFrame.Angles(0, math.rad(45), 0),
						GOLD,
						Enum.Material.Metal
					)
				end
			end
			for k = 0, 7 do
				local a = math.rad(k * 45 + 22.5)
				add(
					Vector3.new(w * 0.012, 0.016, w * (if k % 2 == 0 then 0.34 else 0.24)),
					plate
						* CFrame.Angles(0, a, 0)
						* CFrame.new(0, 0.01, w * (if k % 2 == 0 then 0.17 else 0.12) + w * 0.06),
					GOLD,
					Enum.Material.Metal
				)
			end
			add(
				Vector3.new(w * 0.22, 0.025, w * 0.22),
				plate * CFrame.new(0, 0.012, 0) * CFrame.Angles(0, math.rad(45), 0),
				GOLD,
				Enum.Material.Metal
			)
			add(
				Vector3.new(w * 0.12, 0.03, w * 0.12),
				plate * CFrame.new(0, 0.015, 0) * CFrame.Angles(0, math.rad(45), 0),
				Color3.fromRGB(10, 10, 12),
				Enum.Material.SmoothPlastic
			)
		end,
	},
	-- Burnt Edition (detailed 2026-10-25): pulled from a fire that could not finish it: charred edges, scorch blooms
	-- across the board, and cracks in the char with the embers still glowing down in them
	burnt = {
		material = Enum.Material.Slate,
		lay = function(plate, w, d, add)
			local char = Color3.fromRGB(14, 10, 8)
			for _, sz in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.96, 0.02, d * 0.06),
					plate * CFrame.new(0, 0.008, sz * d * 0.46),
					char,
					Enum.Material.Slate
				)
			end
			add(
				Vector3.new(w * 0.06, 0.02, d * 0.9),
				plate * CFrame.new(-w * 0.46, 0.008, 0),
				char,
				Enum.Material.Slate
			)
			for k, spot in ipairs({ { 0.28, 0.3, 0.3 }, { -0.2, -0.25, 0.22 }, { 0.32, -0.32, 0.18 } }) do
				local bloom = add(
					Vector3.new(0.01, w * spot[3] * 1.6, w * spot[3]),
					plate
						* CFrame.new(w * spot[1], 0.006, d * spot[2])
						* CFrame.Angles(0, math.rad(k * 40), math.rad(90)),
					Color3.fromRGB(20, 14, 10),
					Enum.Material.Slate
				)
				bloom.Shape = Enum.PartType.Cylinder
			end
			-- (the cracks: jagged lines in from the edges, the embers glowing deep in them)
			local ember = Color3.fromRGB(190, 70, 24)
			for _, crack in ipairs({
				{ { -0.46, -0.3 }, { -0.25, -0.18 }, { -0.12, -0.24 }, { 0.02, -0.08 } },
				{ { 0.46, 0.2 }, { 0.28, 0.12 }, { 0.2, 0.26 }, { 0.06, 0.18 } },
				{ { -0.1, 0.46 }, { -0.04, 0.3 }, { -0.16, 0.18 } },
			}) do
				for k = 1, #crack - 1 do
					local a = Vector3.new(crack[k][1] * w, 0.013, crack[k][2] * d)
					local b = Vector3.new(crack[k + 1][1] * w, 0.013, crack[k + 1][2] * d)
					local glow = add(
						Vector3.new(w * 0.018, 0.012, (b - a).Magnitude),
						plate * CFrame.lookAt((a + b) / 2, b),
						ember,
						Enum.Material.Neon
					)
					glow.Transparency = 0.35
				end
			end
		end,
	},
	-- Case File (detailed 2026-10-25): a Bureau folder bound as a book, its tab standing off the edge, a strip of red
	-- tape, a paperclip, a typed label and the box of a CONFIDENTIAL stamp across a corner
	casefile = {
		material = Enum.Material.Fabric,
		lay = function(plate, w, d, add)
			add(
				Vector3.new(w * 0.98, 0.02, d * 0.08),
				plate * CFrame.new(0, 0.01, -d * 0.18) * CFrame.Angles(0, math.rad(-8), 0),
				Color3.fromRGB(150, 30, 32)
			)
			add(
				Vector3.new(w * 0.36, 0.02, d * 0.14),
				plate * CFrame.new(-w * 0.12, 0.012, d * 0.2),
				Color3.fromRGB(236, 232, 218)
			)
			for k = 0, 2 do
				add(
					Vector3.new(w * (0.26 - k * 0.05), 0.022, d * 0.012),
					plate * CFrame.new(-w * 0.14 - k * w * 0.02, 0.013, d * (0.165 + k * 0.03)),
					Color3.fromRGB(40, 38, 36)
				)
			end
			add(
				Vector3.new(w * 0.04, 0.02, d * 0.22),
				plate * CFrame.new(w * 0.3, 0.014, -d * 0.36),
				Color3.fromRGB(176, 180, 186),
				Enum.Material.Metal
			)
			add(
				Vector3.new(w * 0.22, 0.02, d * 0.07),
				plate * CFrame.new(w * 0.2, 0.006, -d * 0.52),
				Color3.fromRGB(190, 164, 110)
			)
			local stamp = Color3.fromRGB(150, 34, 36)
			local box = plate * CFrame.new(w * 0.18, 0.012, d * 0.3) * CFrame.Angles(0, math.rad(-14), 0)
			for _, sz in ipairs({ -1, 1 }) do
				add(Vector3.new(w * 0.4, 0.016, d * 0.014), box * CFrame.new(0, 0, sz * d * 0.06), stamp)
			end
			for _, sx in ipairs({ -1, 1 }) do
				add(Vector3.new(w * 0.014, 0.016, d * 0.12), box * CFrame.new(sx * w * 0.2, 0, 0), stamp)
			end
			add(Vector3.new(w * 0.3, 0.016, d * 0.02), box, stamp)
		end,
	},
	-- Iron Ledger (redesigned 2026-10-22, detailed 2026-10-25): riveted iron plates with iron corner brackets, a hasp
	-- across the edge into a padlock with its shackle, a short chain
	iron = {
		material = Enum.Material.Metal,
		lay = function(plate, w, d, add)
			corners(plate, w, d, add, Color3.fromRGB(38, 40, 44))
			for _, sx in ipairs({ -1, 1 }) do
				for k = -2, 2 do
					local rivet = add(
						Vector3.new(w * 0.05, 0.04, w * 0.05),
						plate * CFrame.new(sx * w * 0.36, 0.015, k * d * 0.18),
						Color3.fromRGB(90, 92, 96),
						Enum.Material.Metal
					)
					rivet.Shape = Enum.PartType.Ball
				end
			end
			add(
				Vector3.new(w * 0.5, 0.03, d * 0.09),
				plate * CFrame.new(-w * 0.28, 0.016, 0),
				IRON,
				Enum.Material.Metal
			)
			add(
				Vector3.new(w * 0.14, 0.08, d * 0.12),
				plate * CFrame.new(-w * 0.52, 0.03, 0),
				Color3.fromRGB(40, 42, 46),
				Enum.Material.Metal
			)
			-- (the padlock's shackle: two posts and a bar over them)
			for _, sz in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.025, 0.12, w * 0.025),
					plate * CFrame.new(-w * 0.52, 0.09, sz * d * 0.035),
					Color3.fromRGB(120, 122, 126),
					Enum.Material.Metal
				)
			end
			add(
				Vector3.new(w * 0.025, 0.025, d * 0.095),
				plate * CFrame.new(-w * 0.52, 0.15, 0),
				Color3.fromRGB(120, 122, 126),
				Enum.Material.Metal
			)
			for k = 1, 3 do
				add(
					Vector3.new(w * 0.06, 0.03, d * 0.05),
					plate * CFrame.new(-w * 0.52, 0.02, d * (0.08 + 0.07 * k)) * CFrame.Angles(0, math.rad(k * 50), 0),
					IRON,
					Enum.Material.Metal
				)
			end
		end,
	},
	-- Death God's Hide: grey scaled hide, one closed eye on the cover that opens while you write (the review page's
	-- concept): shut on the closed notebook, its lids apart over a dim red eye on the book held open; a ridge of
	-- larger scales down its spine side (2026-10-25)
	scale = {
		material = Enum.Material.Slate,
		lay = function(plate, w, d, add, open)
			for row = -3, 3 do
				for col = -2, 2 do
					local scale = add(
						Vector3.new(w * 0.12, 0.02, d * 0.09),
						plate
							* CFrame.new(col * w * 0.17 + (row % 2) * w * 0.085, 0.01, row * d * 0.13)
							* CFrame.Angles(0, math.rad(45), 0),
						Color3.fromRGB(84, 86, 80),
						Enum.Material.Slate
					)
					scale.Transparency = 0.15
				end
			end
			for row = -3, 3 do
				add(
					Vector3.new(w * 0.09, 0.04, d * 0.1),
					plate * CFrame.new(w * 0.44, 0.018, row * d * 0.13) * CFrame.Angles(0, math.rad(45), 0),
					Color3.fromRGB(60, 62, 58),
					Enum.Material.Slate
				)
			end
			local apart = if open then d * 0.05 else 0
			add(
				Vector3.new(w * 0.3, 0.04, d * 0.035),
				plate * CFrame.new(0, 0.02, -d * 0.01 - apart),
				Color3.fromRGB(20, 18, 18)
			)
			add(
				Vector3.new(w * 0.22, 0.035, d * 0.03),
				plate * CFrame.new(0, 0.022, d * 0.025 + apart),
				Color3.fromRGB(30, 26, 26)
			)
			if open then
				local eye = add(
					Vector3.new(w * 0.24, 0.03, d * 0.1),
					plate * CFrame.new(0, 0.016, d * 0.008),
					Color3.fromRGB(150, 22, 26),
					Enum.Material.Neon
				)
				eye.Transparency = 0.2
				add(
					Vector3.new(w * 0.05, 0.035, d * 0.09),
					plate * CFrame.new(0, 0.022, d * 0.008),
					Color3.fromRGB(8, 6, 6)
				)
			end
		end,
	},
	-- Black Mirror (detailed 2026-10-25): obsidian glass in a bevelled frame of darker glass, cracks catching a cold
	-- light, and a faint streak of reflection across it
	mirror = {
		material = Enum.Material.Glass,
		lay = function(plate, w, d, add)
			local frame = Color3.fromRGB(20, 22, 28)
			for _, sz in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.96, 0.025, d * 0.05),
					plate * CFrame.new(0, 0.012, sz * d * 0.47),
					frame,
					Enum.Material.Glass
				)
			end
			for _, sx in ipairs({ -1, 1 }) do
				add(
					Vector3.new(w * 0.05, 0.025, d * 0.9),
					plate * CFrame.new(sx * w * 0.47, 0.012, 0),
					frame,
					Enum.Material.Glass
				)
			end
			for k, turn in ipairs({ 28, -40, 75 }) do
				local crack = add(
					Vector3.new(w * (0.5 - k * 0.08), 0.015, 0.025),
					plate
						* CFrame.new(w * (0.1 - k * 0.07), 0.01, d * (k * 0.12 - 0.2))
						* CFrame.Angles(0, math.rad(turn), 0),
					Color3.fromRGB(196, 210, 226),
					Enum.Material.Neon
				)
				crack.Transparency = 0.45
			end
			local streak = add(
				Vector3.new(w * 0.9, 0.012, d * 0.03),
				plate * CFrame.new(-w * 0.05, 0.014, -d * 0.12) * CFrame.Angles(0, math.rad(-32), 0),
				Color3.fromRGB(230, 236, 246),
				Enum.Material.Neon
			)
			streak.Transparency = 0.8
		end,
	},
}

-- A cover style's look on any board (the shop card's small notebook too): its pieces laid on `plate` (y up off the
-- board) through `add`, and its material (nil for a style without a look).
function Models.layCover(
	style: string?,
	plate: CFrame,
	w: number,
	d: number,
	add: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> BasePart
): Enum.Material?
	local look = if style then COVERS[style] else nil
	if not look then
		return nil
	end
	if look.lay then
		look.lay(plate, w, d, add)
	end
	return look.material
end

function Models.heldManual(at: CFrame, coverColor: Color3?, coverStyle: string?): Model
	local book = Models.grimoire()
	for _, piece in ipairs(book:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	ManualBook.pose(book, 1, 1)
	book:ScaleTo(book:GetScale() * HELD_SCALE)
	-- The open book's middle, from its pivot (the board lies over on the spine's side, +X).
	local box = book:GetBoundingBox()
	local middle = book:GetPivot():PointToObjectSpace(box.Position)
	local turned = at * CFrame.Angles(0, math.pi, 0)
	book:PivotTo(turned * CFrame.new(-middle.X, -middle.Y, -middle.Z))
	if coverColor then
		-- The board's extent in the book's own frame, from its parts' corners.
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, piece in ipairs(book:GetDescendants()) do
			if piece:IsA("BasePart") and piece:GetAttribute("ManualPiece") == "Cover" then
				local half = piece.Size / 2
				for _, sx in ipairs({ -1, 1 }) do
					for _, sy in ipairs({ -1, 1 }) do
						for _, sz in ipairs({ -1, 1 }) do
							local corner = turned:PointToObjectSpace(
								piece.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
							)
							lo, hi = lo:Min(corner), hi:Max(corner)
						end
					end
				end
			end
		end
		if lo.X < hi.X then
			local look = if coverStyle then COVERS[coverStyle] else nil
			local w, d = (hi.X - lo.X) * 0.96, (hi.Z - lo.Z) * 0.96
			local plate = turned * CFrame.new((lo.X + hi.X) / 2, lo.Y - 0.012, (lo.Z + hi.Z) / 2)
			part(book, {
				Name = "ManualCoverColor",
				Size = Vector3.new(w, 0.02, d),
				Color = coverColor,
				Material = if look then look.material else Enum.Material.Leather,
				Reflectance = if coverStyle == "mirror" or coverStyle == "gilded" then 0.25 else 0,
				CFrame = plate,
			})
			if look and look.lay then
				-- (laid on the board's outside, which faces down the plate's -y; the book is held open, written in)
				local outside = plate * CFrame.Angles(math.pi, 0, 0)
				look.lay(outside, w, d, function(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
					return part(book, {
						Name = "ManualCoverPiece",
						Size = size,
						Color = color,
						Material = material or Enum.Material.Fabric,
						CFrame = cf,
					})
				end, true)
			end
		end
	end
	return book
end

return Models
