-- Local-only props for cutscenes. Each one uses your exported model from
-- assets/shared/Models when there is one, and a part-built stand-in otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Props = {}

local function part(model: Model, props: { [string]: any }): BasePart
	local defaults = {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = model,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return Create("Part", defaults)
end

local function prepare(model: Model)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

-- The Grimoire, closed, lying flat. Its PrimaryPart sits at the centre of the book.
function Props.grimoire(): Model
	local custom = Assets.model("Grimoire")
	if custom and custom:IsA("Model") then
		prepare(custom)
		if not custom.PrimaryPart then
			custom.PrimaryPart = custom:FindFirstChildWhichIsA("BasePart", true)
		end
		return custom
	end
	local model = Instance.new("Model")
	model.Name = "Grimoire"
	local cover = part(model, {
		Name = "Cover",
		Size = Vector3.new(2.4, 0.5, 3.2),
		Color = Color3.fromRGB(12, 12, 14),
		Material = Enum.Material.Leather,
	})
	part(model, {
		Name = "Pages",
		Size = Vector3.new(2.25, 0.36, 3.02),
		CFrame = CFrame.new(0.1, 0, 0),
		Color = Color3.fromRGB(226, 220, 205),
		Material = Enum.Material.SmoothPlastic,
	})
	part(model, {
		Name = "Spine",
		Size = Vector3.new(0.2, 0.56, 3.24),
		CFrame = CFrame.new(-1.15, 0, 0),
		Color = Color3.fromRGB(8, 8, 10),
		Material = Enum.Material.Leather,
	})
	-- The sigil on the cover: a thin red "0" ring.
	local sigil = part(model, {
		Name = "Sigil",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.04, 1.3, 1.3),
		CFrame = CFrame.new(0.1, 0.27, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(209, 26, 42),
		Material = Enum.Material.Neon,
		CastShadow = false,
	})
	part(model, {
		Name = "SigilHole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1.0, 1.0),
		CFrame = sigil.CFrame,
		Color = Color3.fromRGB(12, 12, 14),
		Material = Enum.Material.Leather,
		CastShadow = false,
	})
	part(model, {
		Name = "Ribbon",
		Size = Vector3.new(0.18, 0.04, 0.9),
		CFrame = CFrame.new(0.5, -0.1, 1.95),
		Color = Color3.fromRGB(209, 26, 42),
		Material = Enum.Material.Fabric,
		CastShadow = false,
	})
	Create("PointLight", { Color = Color3.fromRGB(255, 40, 50), Brightness = 1.5, Range = 8, Parent = sigil })
	model.PrimaryPart = cover
	return model
end

return Props
