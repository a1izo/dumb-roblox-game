-- Builds equipped cosmetics on characters: hats made of parts and body trails.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)

local CosmeticsService = {}

local HAT = "LCosmeticHat"
local TRAIL_NAMES = { "LCosmeticTrail", "LTrailTop", "LTrailBottom" }

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function cylinder(cf: CFrame, height: number, diameter: number, color: Color3): Part
	return Create("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * VERTICAL,
		Color = color,
		Material = Enum.Material.Fabric,
	})
end

local function box(cf: CFrame, size: Vector3, color: Color3): Part
	return Create("Part", {
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Fabric,
	})
end

local function buildHat(item, anchor: CFrame, head: BasePart): { BasePart }
	local top = anchor * CFrame.new(0, head.Size.Y / 2, 0)
	local color = item.color
	local accent = item.accent
	if item.style == "fedora" then
		return {
			cylinder(top * CFrame.new(0, 0.06, 0), 0.12, 2.3, color),
			cylinder(top * CFrame.new(0, 0.5, 0), 0.85, 1.35, color),
			cylinder(top * CFrame.new(0, 0.22, 0), 0.22, 1.4, accent),
		}
	elseif item.style == "tophat" then
		return {
			cylinder(top * CFrame.new(0, 0.06, 0), 0.12, 2, color),
			cylinder(top * CFrame.new(0, 0.85, 0), 1.6, 1.3, color),
			cylinder(top * CFrame.new(0, 0.25, 0), 0.25, 1.35, accent),
		}
	elseif item.style == "deerstalker" then
		return {
			cylinder(top * CFrame.new(0, 0.3, 0), 0.7, 1.4, color),
			box(top * CFrame.new(0, 0.05, -0.85), Vector3.new(1, 0.1, 0.6), accent),
			box(top * CFrame.new(0, 0.05, 0.85), Vector3.new(1, 0.1, 0.6), accent),
			box(top * CFrame.new(-0.72, -0.2, 0), Vector3.new(0.1, 0.55, 0.6), color),
			box(top * CFrame.new(0.72, -0.2, 0), Vector3.new(0.1, 0.55, 0.6), color),
		}
	end
	-- cap
	return {
		cylinder(top * CFrame.new(0, 0.25, 0), 0.5, 1.35, color),
		box(top * CFrame.new(0, 0.05, -0.85), Vector3.new(1.1, 0.1, 0.7), accent),
	}
end

local function clearTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in ipairs(TRAIL_NAMES) do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

local function addTrail(character: Model, item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local top = Create("Attachment", { Name = "LTrailTop", Position = Vector3.new(0, 0.8, 0.45), Parent = root })
	local bottom = Create("Attachment", { Name = "LTrailBottom", Position = Vector3.new(0, -0.8, 0.45), Parent = root })
	Create("Trail", {
		Name = "LCosmeticTrail",
		Attachment0 = top,
		Attachment1 = bottom,
		Color = ColorSequence.new(item.colors[1], item.colors[2]),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = 0.6,
		MinLength = 0.1,
		LightEmission = 0.4,
		FaceCamera = true,
		Parent = root,
	})
end

function CosmeticsService.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	CharacterService.detach(player, HAT)
	clearTrail(character)
	local data = DataService.get(player)
	if not data then
		return
	end
	local hat = if data.equipped.hat then Cosmetics.byId(data.equipped.hat) else nil
	if hat and hat.kind == "hat" and data.owned[hat.id] then
		CharacterService.attachBuilt(player, HAT, { "Head" }, function(anchor: CFrame, head: BasePart)
			return buildHat(hat, anchor, head)
		end)
	end
	local trail = if data.equipped.trail then Cosmetics.byId(data.equipped.trail) else nil
	if trail and trail.kind == "trail" and data.owned[trail.id] then
		addTrail(character, trail)
	end
end

function CosmeticsService.init()
	CharacterService.CharacterSpawned:Connect(function(player)
		CosmeticsService.apply(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		CosmeticsService.apply(player)
	end)
end

return CosmeticsService
