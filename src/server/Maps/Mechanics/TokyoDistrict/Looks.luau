-- The Tokyo crowd's bodies: CrowdLooks.COUNT R6 rigs built once per server, dressed (the players' suit
-- or a commuter's coat, hair, sometimes an umbrella) and kept in ReplicatedStorage.LCrowd, never in the
-- world: every client clones them for the walkers it draws. Roblox builds each rig from a description;
-- when it cannot (no web access in a test), a plain rig is put together by hand instead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local CrowdLooks = require(Shared:WaitForChild("CrowdLooks"))

local Services = script.Parent.Parent.Parent.Parent:WaitForChild("Services")
local CharacterService = require(Services:WaitForChild("CharacterService"))

local Looks = {}

Looks.FOLDER = "LCrowd"

local LIMBS = { "HeadColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor", "TorsoColor" }

-- R6 by hand: the six parts and the six joints PoseController moves.
local function plainRig(skin: Color3): Model
	local model = Instance.new("Model")
	local function part(name: string, size: Vector3, at: Vector3): Part
		return Create("Part", {
			Name = name,
			Size = size,
			Color = skin,
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(at),
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Parent = model,
		})
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
	Create("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25), Parent = head })
	Create(
		"Decal",
		{ Name = "face", Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front, Parent = head }
	)
	local limb = Vector3.new(1, 2, 1)
	local rightArm = part("Right Arm", limb, Vector3.new(1.5, 3, 0))
	local leftArm = part("Left Arm", limb, Vector3.new(-1.5, 3, 0))
	local rightLeg = part("Right Leg", limb, Vector3.new(0.5, 1, 0))
	local leftLeg = part("Left Leg", limb, Vector3.new(-0.5, 1, 0))
	local function joint(name: string, home: BasePart, moved: BasePart, c0: CFrame, c1: CFrame)
		Create("Motor6D", { Name = name, Part0 = home, Part1 = moved, C0 = c0, C1 = c1, Parent = home })
	end
	local up = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local right = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	local left = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	joint("RootJoint", root, torso, up, up)
	joint("Neck", torso, head, CFrame.new(0, 1, 0) * up, CFrame.new(0, -0.5, 0) * up)
	joint("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0) * right, CFrame.new(-0.5, 0.5, 0) * right)
	joint("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0) * left, CFrame.new(0.5, 0.5, 0) * left)
	joint("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0) * right, CFrame.new(0.5, 1, 0) * right)
	joint("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0) * left, CFrame.new(-0.5, 1, 0) * left)
	Create("Humanoid", { RigType = Enum.HumanoidRigType.R6, Parent = model })
	model.PrimaryPart = root
	model:SetAttribute("Plain", true)
	return model
end

local function rigFor(look: CrowdLooks.Look): Model
	local description = Instance.new("HumanoidDescription")
	for _, key in ipairs(LIMBS) do
		(description :: any)[key] = look.skin
	end
	if look.hairId and look.style ~= "bald" then
		description.HairAccessory = tostring(look.hairId)
	end
	if look.faceId then
		description.Face = look.faceId
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if ok and model then
		return model
	end
	return plainRig(look.skin)
end

local function block(size: Vector3, colour: Color3, cf: CFrame): Part
	return Create("Part", { Size = size, Color = colour, Material = Enum.Material.SmoothPlastic, CFrame = cf })
end

-- Hair from a few blocks over the head (a round head 1.25 across): a cap, and what each style adds.
-- Only for a body that came without its catalog hair.
local function hair(character: Model, look: CrowdLooks.Look)
	if look.style == "bald" or character:FindFirstChildWhichIsA("Accessory") then
		return
	end
	CharacterService.attachBuiltTo(character, "LCrowdHair", { "Head" }, function(anchor: CFrame)
		local colour = look.hair
		local parts = {
			block(Vector3.new(1.3, 0.34, 1.3), colour, anchor * CFrame.new(0, 0.5, 0.02)),
			block(Vector3.new(1.3, 0.6, 0.3), colour, anchor * CFrame.new(0, 0.2, 0.52)),
		}
		if look.style == "part" then
			-- A fringe swept to one side.
			local sweep = CFrame.new(0.12, 0.42, -0.56) * CFrame.Angles(0, 0, math.rad(-10))
			table.insert(parts, block(Vector3.new(1.1, 0.22, 0.22), colour, anchor * sweep))
		elseif look.style == "bob" then
			table.insert(parts, block(Vector3.new(1.32, 1.0, 0.32), colour, anchor * CFrame.new(0, 0, 0.54)))
			for _, side in ipairs({ -1, 1 }) do
				table.insert(
					parts,
					block(Vector3.new(0.2, 0.9, 0.9), colour, anchor * CFrame.new(side * 0.62, 0.02, 0.14))
				)
			end
			table.insert(parts, block(Vector3.new(1.2, 0.2, 0.2), colour, anchor * CFrame.new(0, 0.36, -0.58)))
		elseif look.style == "bun" then
			local bun = block(Vector3.new(0.5, 0.5, 0.5), colour, anchor * CFrame.new(0, 0.62, 0.5))
			bun.Shape = Enum.PartType.Ball
			table.insert(parts, bun)
		end
		return parts
	end)
end

-- A commuter: a coat over the arms and body, plain trousers, hands like the suits' cuffs.
local function coat(character: Model, look: CrowdLooks.Look)
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors") then
			item:Destroy()
		end
	end
	local function paint(names: { string }, colour: Color3)
		for _, name in ipairs(names) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = colour
				part.Material = Enum.Material.Fabric
			end
		end
	end
	paint({ "Torso", "Left Arm", "Right Arm" }, look.coat :: Color3)
	paint({ "Left Leg", "Right Leg" }, look.trousers :: Color3)
	for _, side in ipairs({ "Left", "Right" }) do
		CharacterService.attachBuiltTo(character, "LHand" .. side, { side .. " Arm" }, function(anchor: CFrame)
			return { block(Vector3.new(1.04, 0.55, 1.04), look.skin, anchor * CFrame.new(0, -0.74, 0)) }
		end)
	end
	-- The coat's skirt, a little below the waist.
	CharacterService.attachBuiltTo(character, "LCoat", { "Torso" }, function(anchor: CFrame)
		local skirt = block(Vector3.new(2.06, 0.7, 1.06), look.coat :: Color3, anchor * CFrame.new(0, -1.3, 0))
		skirt.Material = Enum.Material.Fabric
		return { skirt }
	end)
end

-- An open umbrella held upright in front of the right shoulder.
local function umbrella(character: Model, colour: Color3)
	CharacterService.attachBuiltTo(character, "LUmbrella", { "Torso" }, function(anchor: CFrame)
		local shaft =
			block(Vector3.new(0.1, 3.3, 0.1), Color3.fromRGB(40, 40, 44), anchor * CFrame.new(0.95, 1.35, -0.55))
		shaft.Material = Enum.Material.Metal
		local canopy = block(Vector3.new(4.6, 0.9, 4.6), colour, anchor * CFrame.new(0.95, 2.9, -0.55))
		canopy.Material = Enum.Material.Fabric
		Create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = canopy })
		if colour.R > 0.7 then
			canopy.Transparency = 0.55 -- the clear plastic kind
		end
		return { shaft, canopy }
	end)
end

-- One body, ready to clone: dressed, with no script, name tag or health bar, and nothing a ray or a
-- touch can find.
local function body(index: number, look: CrowdLooks.Look): Model
	local model = rigFor(look)
	model.Name = string.format("Body%02d", index)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end
	if look.suit then
		CharacterService.dressNoir(model, look.tie)
	else
		coat(model, look)
	end
	hair(model, look)
	if look.umbrella then
		umbrella(model, look.umbrella)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
		end
	end
	model:SetAttribute("Suit", look.suit)
	return model
end

local building = false

-- Builds the bodies (once; it waits on Roblox for each rig). Returns the folder straight away: the
-- bodies arrive in it one by one, and clients use whichever are there.
function Looks.ensure(seed: number?): Folder
	local existing = ReplicatedStorage:FindFirstChild(Looks.FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Create("Folder", { Name = Looks.FOLDER, Parent = ReplicatedStorage }) :: Folder
	if not building then
		building = true
		task.spawn(function()
			local rng = Random.new(seed or 20261007)
			for index = 1, CrowdLooks.COUNT do
				local ok, result = pcall(body, index, CrowdLooks.make(index, rng))
				if ok then
					result.Parent = folder
				else
					warn("[DeathsGambit] Could not build crowd body " .. index .. ": " .. tostring(result))
				end
			end
			folder:SetAttribute("Ready", true)
			building = false
		end)
	end
	return folder
end

return Looks
