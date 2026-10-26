-- A client-only set for cutscenes: copies of players' avatars (in their match outfits), placed
-- on marks, holding props and playing clips. Nothing here exists on the server or on anyone
-- else's screen; every client builds the same show from the same public data. While a copy
-- stands in for someone, their real body is hidden on this screen only.
--
--   local stage = Stage.new()
--   local actor = stage:cast(userId, CFrame, "actCoffee", { "cup" })
--   ...
--   stage:clear()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))
local Suit = require(Shared:WaitForChild("Suit"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)

local Stage = {}
Stage.__index = Stage

type Saved = { [Instance]: any }

export type Stage = typeof(setmetatable(
	{} :: {
		folder: Folder,
		hidden: { [Model]: Saved },
		actors: { Model },
		worn: { BasePart },
		sight: RBXScriptConnection?,
	},
	Stage
))

local function folder(): Folder
	local existing = workspace:FindFirstChild("DeathsGambitStage")
	if existing and existing:IsA("Folder") then
		return existing
	end
	return Create("Folder", { Name = "DeathsGambitStage", Parent = workspace })
end

function Stage.new(): Stage
	local set = Create("Folder", { Name = "Set", Parent = folder() })
	return setmetatable({ folder = set, hidden = {}, actors = {}, worn = {}, sight = nil }, Stage)
end

-- What an actor wears (hair, a mask, a coat) goes see-through on this screen while the camera is inside it, and
-- comes back once it leaves: a close shot of someone in big hair would otherwise show the inside of the hair
-- (the owner's avatar in God of the New World, 2026-10-23).
local NEAR = 0.35 -- studs round a part that count as inside it

local function inside(part: BasePart, point: Vector3): boolean
	local at = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2 + Vector3.one * NEAR
	return math.abs(at.X) <= half.X and math.abs(at.Y) <= half.Y and math.abs(at.Z) <= half.Z
end

local function keepSight(self: Stage)
	if self.sight then
		return
	end
	local cleared: { [BasePart]: boolean } = {}
	self.sight = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for _, part in ipairs(self.worn) do
			local hide = part.Parent ~= nil and inside(part, eye)
			if hide ~= (cleared[part] == true) then
				cleared[part] = if hide then true else nil
				part.LocalTransparencyModifier = if hide then 1 else 0
			end
		end
	end)
end

-- Hides a model on this screen and returns what it changed, to put back later.
local function conceal(model: Model): Saved
	local saved: Saved = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			saved[item] = (item :: any).LocalTransparencyModifier;
			(item :: any).LocalTransparencyModifier = 1
		elseif item:IsA("BillboardGui") then
			saved[item] = item.Enabled
			item.Enabled = false
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		saved[humanoid] = humanoid.DisplayDistanceType
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return saved
end

local function reveal(saved: Saved)
	for item, value in pairs(saved) do
		if item.Parent then
			if item:IsA("BillboardGui") then
				item.Enabled = value
			elseif item:IsA("Humanoid") then
				item.DisplayDistanceType = value
			else
				(item :: any).LocalTransparencyModifier = value
			end
		end
	end
end

-- Hides a real character on this screen while its copy performs.
function Stage.hide(self: Stage, model: Model)
	if not self.hidden[model] then
		self.hidden[model] = conceal(model)
	end
end

-- A still copy of a character: no scripts, no physics, no name tag, nothing an emote put on it. (The shop's
-- Your Look uses it too.)
local function copyOf(source: Model): Model?
	local archivable = source.Archivable
	source.Archivable = true
	local ok, clone = pcall(function()
		return source:Clone()
	end)
	source.Archivable = archivable
	if not ok or not clone then
		return nil
	end
	-- What an emote or a duo put on the body (props, effects, a chain: all marked "DGEmote") stays with it.
	local leftovers: { Instance } = {}
	for _, item in ipairs(clone:GetDescendants()) do
		if item:GetAttribute("DGEmote") or item.Name == "DuoChain" then
			table.insert(leftovers, item)
		end
	end
	for _, item in ipairs(leftovers) do
		item:Destroy()
	end
	-- A suited body's copy sheds what of the avatar reached this screen before the server took it off (a coat that
	-- loaded late), so no cutscene shows it over the suit.
	if clone:GetAttribute(Suit.DRESSED) then
		for _, item in ipairs(clone:GetChildren()) do
			if Suit.offBody(item) then
				item:Destroy()
			end
		end
	end
	-- and the head wears its own face, not the emote's
	local head = clone:FindFirstChild("Head")
	local face = head and head:FindFirstChild("face")
	if face and face:IsA("Decal") and type(face:GetAttribute("OwnFace")) == "string" then
		face.Texture = face:GetAttribute("OwnFace") :: string
		face:SetAttribute("OwnFace", nil)
		face:SetAttribute("EmoteFace", nil)
	end
	-- (an avatar's own painted head, its picture put away for an emote's face: back, the decal see-through again)
	local painted = if head then head:GetAttribute("LHeadTexture") else nil
	if head and head:IsA("MeshPart") and type(painted) == "string" and head.TextureID ~= painted then
		head.TextureID = painted
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
	end
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("ProximityPrompt") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.LocalTransparencyModifier = 0
			item.Anchored = item.Name == "HumanoidRootPart"
		elseif item:IsA("Decal") then
			item.LocalTransparencyModifier = 0
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.PlatformStand = true
		pcall(function()
			(humanoid :: any).EvaluateStateMachine = false
		end)
	end
	-- Placed by the root: Roblox's R6 models pivot on the Head, which puts a posed body off its mark.
	local root = clone:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		clone.PrimaryPart = root
	end
	clone:SetAttribute("Specter", nil)
	return clone
end
Stage.copyOf = copyOf

-- The R6 rig's standard joints: name, the part that holds it, the part it moves, C0, C1.
local R6_FRONT = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
local R6_RIGHT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
local R6_LEFT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local R6_JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", R6_FRONT, R6_FRONT },
	{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0) * R6_FRONT, CFrame.new(0, -0.5, 0) * R6_FRONT },
	{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0) * R6_RIGHT, CFrame.new(-0.5, 0.5, 0) * R6_RIGHT },
	{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0) * R6_LEFT, CFrame.new(0.5, 0.5, 0) * R6_LEFT },
	{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0) * R6_RIGHT, CFrame.new(0.5, 1, 0) * R6_RIGHT },
	{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0) * R6_LEFT, CFrame.new(-0.5, 1, 0) * R6_LEFT },
}

-- A faceless stand-in (an R6 body in a black suit, no face, no name): for the cutscene parts that are
-- nobody in particular, or someone the viewer must not know. Not parented; cast() copies it.
function Stage.figure(): Model
	local model = Instance.new("Model")
	model.Name = "Figure"
	local suit, skin = Color3.fromRGB(16, 16, 19), Color3.fromRGB(28, 26, 26)
	local sizes = {
		HumanoidRootPart = Vector3.new(2, 2, 1),
		Torso = Vector3.new(2, 2, 1),
		Head = Vector3.new(2, 1, 1),
		["Right Arm"] = Vector3.new(1, 2, 1),
		["Left Arm"] = Vector3.new(1, 2, 1),
		["Right Leg"] = Vector3.new(1, 2, 1),
		["Left Leg"] = Vector3.new(1, 2, 1),
	}
	local parts: { [string]: BasePart } = {}
	for name, size in pairs(sizes) do
		parts[name] = Create("Part", {
			Name = name,
			Size = size,
			Color = if name == "Head" then skin else suit,
			Material = Enum.Material.SmoothPlastic,
			Transparency = if name == "HumanoidRootPart" then 1 else 0,
			CanCollide = false,
			Anchored = name == "HumanoidRootPart",
			CFrame = CFrame.new(0, 3, 0),
			Parent = model,
		})
	end
	Create("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25), Parent = parts.Head })
	for _, joint in ipairs(R6_JOINTS) do
		Create("Motor6D", {
			Name = joint[1],
			Part0 = parts[joint[2]],
			Part1 = parts[joint[3]],
			C0 = joint[4],
			C1 = joint[5],
			Parent = parts[joint[2]],
		})
	end
	-- and the match suit's tailored cloth over the body, as the players wear it (Shared/Suit; none before the import)
	for name, body in pairs(parts) do
		if name ~= "Head" and name ~= "HumanoidRootPart" then
			for _, cloth in ipairs(Suit.cloth(body)) do
				cloth.Anchored = false
				cloth.CanCollide = false
				cloth.CanQuery = false
				cloth.CanTouch = false
				cloth.Massless = true
				cloth.CastShadow = false
				Create("Weld", { Part0 = body, Part1 = cloth, Parent = cloth })
				cloth.Parent = model
			end
		end
	end
	Create("Humanoid", { RigType = Enum.HumanoidRigType.R6, Parent = model })
	model.PrimaryPart = parts.HumanoidRootPart
	return model
end

-- Puts a copy of `userId`'s avatar (or of `model`) on a mark (feet on the mark, facing its look
-- vector), playing `clip`, holding `props`. Returns the copy, or nil if there is no body.
function Stage.cast(self: Stage, who: number | Model, mark: CFrame, clip: string?, props: { string }?): Model?
	local source = if typeof(who) == "Instance" then who :: Model else Characters.byUserId(who :: number)
	if not source then
		return nil
	end
	local actor = copyOf(source)
	if not actor then
		return nil
	end
	actor.Name = "Actor_" .. source.Name
	local root = actor:FindFirstChild("HumanoidRootPart")
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	local lift = 3
	if root and root:IsA("BasePart") and humanoid then
		-- R6: the root hangs half its height plus a leg above the floor.
		local leg = actor:FindFirstChild("Right Leg")
		lift = humanoid.HipHeight + root.Size.Y / 2 + (if leg and leg:IsA("BasePart") then leg.Size.Y else 2)
	end
	actor:PivotTo(mark * CFrame.new(0, lift, 0))
	actor.Parent = self.folder
	table.insert(self.actors, actor)
	for _, item in ipairs(actor:GetChildren()) do
		if item:IsA("Accessory") then
			for _, part in ipairs(item:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(self.worn, part)
				end
			end
		end
	end
	keepSight(self)
	if typeof(who) ~= "Instance" then
		self:hide(source)
	end
	for _, prop in ipairs(props or {}) do
		self:hold(actor, prop)
	end
	if clip then
		task.defer(function()
			PoseController.bindWhenReady(actor, 2)
			PoseController.play(actor, clip, { fadeIn = 0, startAt = os.clock() - math.random() * 0.5 })
		end)
	end
	return actor
end

-- Plays a clip on an actor (or any character) on this screen only.
function Stage.act(_self: Stage, actor: Model, clip: string, options: PoseController.Options?)
	PoseController.play(actor, clip, options or { fadeIn = 0.15 })
end

-- Props -------------------------------------------------------------------------------------------

local INK = Color3.fromRGB(20, 18, 22)
local PAPER = Color3.fromRGB(226, 218, 200)

local function part(size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	return Create("Part", {
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Shape = shape or Enum.PartType.Block,
		Anchored = false,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
	})
end

-- prop -> hand, offset from the hand, builder
local PROPS: { [string]: { string | CFrame | (() -> Instance) } } = {
	cup = {
		"RightHand",
		CFrame.new(0, -0.45, -0.25),
		function()
			local cup = part(Vector3.new(0.5, 0.35, 0.35), PAPER, nil, Enum.PartType.Cylinder)
			cup.CFrame = CFrame.Angles(0, 0, math.rad(90))
			return cup
		end,
	},
	phone = {
		"RightHand",
		CFrame.new(0, -0.35, -0.3) * CFrame.Angles(math.rad(-60), 0, 0),
		function()
			return part(Vector3.new(0.4, 0.06, 0.75), INK)
		end,
	},
	file = {
		"LeftHand",
		CFrame.new(0.5, -0.4, -0.4) * CFrame.Angles(math.rad(-55), 0, 0),
		function()
			return part(Vector3.new(1.6, 0.06, 1.1), Color3.fromRGB(196, 160, 96))
		end,
	},
	magnifier = {
		"RightHand",
		CFrame.new(0, 0.2, -0.6) * CFrame.Angles(0, 0, math.rad(90)),
		function()
			local glass = part(
				Vector3.new(0.08, 0.8, 0.8),
				Color3.fromRGB(180, 210, 230),
				Enum.Material.Glass,
				Enum.PartType.Cylinder
			)
			glass.Transparency = 0.4
			return glass
		end,
	},
	newspaper = {
		"LeftHand",
		CFrame.new(0.8, 0.2, -0.3),
		function()
			return part(Vector3.new(1.9, 1.4, 0.05), PAPER)
		end,
	},
	umbrella = {
		"RightHand",
		CFrame.new(0, 2.2, 0),
		function()
			local model = Instance.new("Model")
			local canopy = part(Vector3.new(0.5, 4.2, 4.2), INK, Enum.Material.Fabric, Enum.PartType.Cylinder)
			canopy.CFrame = CFrame.Angles(0, 0, math.rad(90))
			canopy.Parent = model
			local shaft = part(Vector3.new(0.12, 2.4, 0.12), Color3.fromRGB(60, 50, 40))
			shaft.CFrame = CFrame.new(0, -1.2, 0)
			shaft.Parent = model
			model.PrimaryPart = canopy
			return model
		end,
	},
	candle = {
		"RightHand",
		CFrame.new(0, 0.1, -0.35),
		function()
			local model = Instance.new("Model")
			local wax = part(Vector3.new(0.25, 0.7, 0.25), Color3.fromRGB(230, 220, 200), nil, Enum.PartType.Cylinder)
			wax.CFrame = CFrame.Angles(0, 0, math.rad(90))
			wax.Parent = model
			local flame = part(
				Vector3.new(0.18, 0.28, 0.18),
				Color3.fromRGB(255, 180, 90),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			flame.CFrame = CFrame.new(0, 0.5, 0)
			flame.Parent = model
			Create("PointLight", { Color = Color3.fromRGB(255, 170, 90), Range = 10, Brightness = 1.4, Parent = flame })
			model.PrimaryPart = wax
			return model
		end,
	},
	sweets = {
		"RightHand",
		CFrame.new(0, -0.2, -0.2),
		function()
			return part(Vector3.new(0.3, 0.2, 0.3), Color3.fromRGB(220, 80, 120))
		end,
	},
	badge = {
		"RightHand",
		CFrame.new(0, -0.1, -0.35) * CFrame.Angles(math.rad(-80), 0, 0),
		function()
			local badge = part(Vector3.new(0.9, 0.05, 1.2), Color3.fromRGB(40, 40, 46))
			local shield = part(Vector3.new(0.5, 0.06, 0.6), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
			shield.CFrame = CFrame.new(0, 0.03, 0)
			shield.Parent = badge
			Create("WeldConstraint", { Part0 = badge, Part1 = shield, Parent = shield })
			return badge
		end,
	},
	grimoire = {
		"LeftHand",
		CFrame.new(0.6, -0.3, -0.5) * CFrame.Angles(math.rad(-70), 0, 0),
		function()
			return Models.grimoire()
		end,
	},
}

-- R6 has no hands: a prop sits at the end of the arm.
local ARM_OF = { RightHand = "Right Arm", LeftHand = "Left Arm" }
local ARM_END = CFrame.new(0, -0.9, 0)

-- Welds a prop into an actor's hand.
function Stage.hold(_self: Stage, actor: Model, prop: string)
	local spec = PROPS[prop]
	if not spec then
		return
	end
	local hand = actor:FindFirstChild(ARM_OF[spec[1] :: string] or spec[1] :: string)
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local built = (spec[3] :: () -> Instance)()
	built.Name = "Prop_" .. prop
	local anchor: BasePart? = if built:IsA("BasePart")
		then built
		elseif built:IsA("Model") then built.PrimaryPart
		else nil
	if built:IsA("Model") and not anchor then
		anchor = built:FindFirstChildWhichIsA("BasePart", true)
	end
	for _, item in ipairs(built:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.Massless = true
		end
	end
	if built:IsA("BasePart") then
		built.Anchored = false
	end
	local target = hand.CFrame * ARM_END * (spec[2] :: CFrame)
	if built:IsA("Model") then
		built:PivotTo(target)
		for _, item in ipairs(built:GetDescendants()) do
			-- (A piece with a joint of its own, the Manual's board and leaves, moves on that joint.)
			if item:IsA("BasePart") and item ~= anchor and not item:FindFirstChildWhichIsA("JointInstance") then
				Create("WeldConstraint", { Part0 = anchor, Part1 = item, Parent = item })
			end
		end
	else
		(built :: BasePart).CFrame = target * (built :: BasePart).CFrame.Rotation
	end
	if anchor then
		Create("WeldConstraint", { Part0 = hand, Part1 = anchor, Parent = anchor })
	end
	built.Parent = actor
end

-- Set pieces --------------------------------------------------------------------------------------

-- A chair for a seated mark (the seat front at the mark, facing the same way).
function Stage.chair(self: Stage, mark: CFrame): Instance
	local model = ModelLibrary.get("OfficeChair") or ModelLibrary.get("Chair")
	if model then
		model:PivotTo(mark * CFrame.new(0, 0, 0.3))
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.CanQuery = false
			end
		end
		model.Parent = self.folder
		return model
	end
	local seat = part(Vector3.new(1.8, 0.3, 1.8), Color3.fromRGB(36, 34, 40), Enum.Material.Fabric)
	seat.Anchored = true
	seat.CFrame = mark * CFrame.new(0, 1.6, 0.3)
	seat.Parent = self.folder
	local back = part(Vector3.new(1.8, 2, 0.25), Color3.fromRGB(36, 34, 40), Enum.Material.Fabric)
	back.Anchored = true
	back.CFrame = mark * CFrame.new(0, 2.7, 1.1)
	back.Parent = seat
	return seat
end

-- Any extra instance that belongs to this set (cleared with it).
function Stage.add(self: Stage, instance: Instance): Instance
	instance.Parent = self.folder
	return instance
end

-- Removes every actor and prop, and shows the real bodies again.
function Stage.clear(self: Stage)
	for _, saved in pairs(self.hidden) do
		reveal(saved)
	end
	self.hidden = {}
	self.actors = {}
	self.worn = {}
	if self.sight then
		self.sight:Disconnect()
		self.sight = nil
	end
	self.folder:ClearAllChildren()
end

function Stage.destroy(self: Stage)
	self:clear()
	self.folder:Destroy()
end

return Stage
