-- Models used in the world, in cutscenes and in previews. Each returns a fresh Model whose
-- parts are anchored and never collide: the Blender prop when it has been imported
-- (ModelLibrary), otherwise a part-built stand-in.

local Assets = require(script.Parent.Assets)
local Create = require(script.Parent.Create)
local ModelLibrary = require(script.Parent.ModelLibrary)

local Models = {}

local INK = Color3.fromRGB(12, 12, 14)
local PAPER = Color3.fromRGB(226, 220, 205)
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

-- The notebook everyone holds in the Grimoire phase (lying flat), or nil (parts are used).
function Models.notebook(): Model?
	return custom("Notebook")
end

-- A fountain pen standing along Y, or nil.
function Models.pen(): Model?
	return custom("Pen")
end

-- The hood worn over the head, or nil.
function Models.hood(): Model?
	return custom("Hood")
end

-- The Grimoire, closed and lying flat, centred on its PrimaryPart.
function Models.grimoire(): Model
	local existing = custom("Grimoire")
	if existing then
		return existing
	end
	local model = Instance.new("Model")
	model.Name = "Grimoire"
	local cover = part(model, {
		Name = "Cover",
		Size = Vector3.new(2.4, 0.5, 3.2),
		Color = INK,
		Material = Enum.Material.Leather,
	})
	part(model, {
		Name = "Pages",
		Size = Vector3.new(2.25, 0.36, 3.02),
		CFrame = CFrame.new(0.1, 0, 0),
		Color = PAPER,
		Material = Enum.Material.SmoothPlastic,
	})
	part(model, {
		Name = "Spine",
		Size = Vector3.new(0.2, 0.56, 3.24),
		CFrame = CFrame.new(-1.15, 0, 0),
		Color = Color3.fromRGB(8, 8, 10),
		Material = Enum.Material.Leather,
	})
	local sigil = part(model, {
		Name = "Sigil",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.04, 1.3, 1.3),
		CFrame = CFrame.new(0.1, 0.27, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = RED,
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	part(model, {
		Name = "SigilHole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1.0, 1.0),
		CFrame = sigil.CFrame,
		Color = INK,
		Material = Enum.Material.Leather,
		CastShadow = false,
	})
	part(model, {
		Name = "Ribbon",
		Size = Vector3.new(0.18, 0.04, 0.9),
		CFrame = CFrame.new(0.5, -0.1, 1.95),
		Color = RED,
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	Create("PointLight", { Color = Color3.fromRGB(255, 40, 50), Brightness = 1.5, Range = 8, Parent = sigil })
	model.PrimaryPart = cover
	return model
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
			Font = Enum.Font.Oswald,
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
		Font = Enum.Font.Oswald,
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

return Models
