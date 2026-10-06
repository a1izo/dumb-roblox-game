--!strict
-- Footprints in the snow. Where a living, visible character walks or runs over untrodden snow (a
-- map surface whose Look is "Snow": the campus lawns, the pond hollow, the margins), a print is
-- pressed into it and fades out within a few seconds. Never on the shovelled paths or indoors,
-- never for Specters, spectators or bodies. Cosmetic and local: each client makes its own, fewer
-- on phones and with Low graphics. A print is a decal when Assets.textures.Footprint is set (or
-- imported), a flat oval otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local LocomotionController = require(script.Parent.Parent.Anim.LocomotionController)
local Responsive = require(script.Parent.Parent.UI.Core.Responsive)
local Settings = require(script.Parent.Parent.UI.Core.Settings)
local RainController = require(script.Parent.RainController)

local FootprintController = {}

local LOOK = "Snow" -- the look of the ground that takes prints
local LIFE = 8 -- seconds a print lasts...
local FADE = 3 -- ...fading out over the last of them
local REACH = 220 -- no prints this far from the camera (nobody would see them)
-- The most prints at once for each device class; Low graphics keeps a quarter.
local CAP = { phone = 40, tablet = 80, console = 120, desktop = 160 }
local SIZE = Vector3.new(0.55, 0.04, 1.05)
local COLOUR = Color3.fromRGB(150, 160, 186)
local FRESH = 0.45 -- a new print's transparency
-- The parts a foot can be (R6 legs): the lowest one is the foot coming down.
local FEET = { "Left Leg", "Right Leg" }

type Print = { part: BasePart, decal: Decal?, born: number, fade: Tween? }

local folder: Folder
local live: { Print } = {} -- oldest first
local spare: { Print } = {}
local texture = ""
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function cap(): number
	local most = CAP[Responsive.class()] or CAP.desktop
	if Settings.get("lowGraphics") then
		most = math.floor(most / 4)
	end
	return most
end

-- The map's solid parts (the colliders and floors carry their Look), or nil between maps.
local function solids(): Instance?
	local map = workspace:FindFirstChild("LGameMap")
	local scene = if map then map:FindFirstChild("Scene") else nil
	return if scene then scene:FindFirstChild("Solids") else nil
end

local function makePrint(): Print
	if texture == "" then
		-- (The import can arrive after the game starts.)
		texture = Assets.texture("Footprint")
	end
	local part = Create("Part", {
		Name = "Footprint",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = COLOUR,
		Size = SIZE,
	}) :: BasePart
	local decal: Decal? = nil
	if texture ~= "" then
		part.Transparency = 1
		decal = Create("Decal", {
			Face = Enum.NormalId.Top,
			Texture = texture,
			Color3 = COLOUR,
			Parent = part,
		}) :: Decal
	else
		-- A flat oval pressed into the snow.
		Create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = part })
	end
	return { part = part, decal = decal, born = 0, fade = nil }
end

local function release(print_: Print)
	if print_.fade then
		print_.fade:Cancel()
		print_.fade = nil
	end
	print_.part.Parent = nil
	table.insert(spare, print_)
end

local function clearAll()
	for _, print_ in ipairs(live) do
		release(print_)
	end
	table.clear(live)
end

local function press(at: CFrame)
	local print_ = table.remove(spare)
	if not print_ then
		if #live >= cap() and #live > 0 then
			print_ = table.remove(live, 1)
			if print_ and print_.fade then
				print_.fade:Cancel()
				print_.fade = nil
			end
		else
			print_ = makePrint()
		end
	end
	local chosen = print_ :: Print
	chosen.born = os.clock()
	chosen.part.CFrame = at
	local info = TweenInfo.new(FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, LIFE - FADE)
	local decal = chosen.decal
	if decal then
		decal.Transparency = FRESH
		chosen.fade = TweenService:Create(decal, info, { Transparency = 1 })
	else
		chosen.part.Transparency = FRESH
		chosen.fade = TweenService:Create(chosen.part, info, { Transparency = 1 })
	end
	chosen.part.Parent = folder;
	(chosen.fade :: Tween):Play()
	table.insert(live, chosen)
	-- Over the cap (Low graphics just turned on): the oldest go first.
	while #live > cap() do
		release(table.remove(live, 1) :: Print)
	end
end

-- Whether this character leaves prints at all: a living, visible body that is nobody's ghost.
local function leavesPrints(character: Model): boolean
	if character:GetAttribute("Specter") or character:GetAttribute("Spectator") then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local head = character:FindFirstChild("Head")
	return head ~= nil and head:IsA("BasePart") and head.Transparency < 0.9
end

local function plantedFoot(character: Model): BasePart?
	local lowest: BasePart? = nil
	local bottom = math.huge
	for _, name in ipairs(FEET) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local y = part.Position.Y - part.Size.Y / 2
			if y < bottom then
				lowest, bottom = part, y
			end
		end
	end
	return lowest
end

local function onFootfall(character: Model)
	if RainController.snowAmount() <= 0 or not character.Parent or not leavesPrints(character) then
		return
	end
	local camera = workspace.CurrentCamera
	local foot = plantedFoot(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local ground = solids()
	if not camera or not foot or not root or not root:IsA("BasePart") or not ground then
		return
	end
	if (foot.Position - camera.CFrame.Position).Magnitude > REACH then
		return
	end
	rayParams.FilterDescendantsInstances = { ground }
	local hit = workspace:Raycast(foot.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, -5, 0), rayParams)
	if not hit or hit.Instance:GetAttribute("Look") ~= LOOK then
		return
	end
	-- Lying on the snow, pointing the way the body faces.
	local up = hit.Normal
	local look = root.CFrame.LookVector
	local forward = look - up * look:Dot(up)
	if forward.Magnitude < 0.05 then
		return
	end
	forward = forward.Unit
	press(CFrame.fromMatrix(hit.Position + up * 0.03, forward:Cross(up), up, -forward))
end

function FootprintController.init()
	folder = Create("Folder", { Name = "DeathsGambitFootprints", Parent = workspace }) :: Folder
	LocomotionController.Footfall:Connect(onFootfall)
	-- Prints that have faded go back to the pool; all of them when the map is torn down.
	local lastSweep = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSweep < 0.5 then
			return
		end
		lastSweep = now
		while live[1] and now - live[1].born >= LIFE do
			release(table.remove(live, 1) :: Print)
		end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "LGameMap" then
			clearAll()
		end
	end)
	Settings.Changed:Connect(function(key)
		if key == "lowGraphics" then
			while #live > cap() do
				release(table.remove(live, 1) :: Print)
			end
		end
	end)
end

return FootprintController
