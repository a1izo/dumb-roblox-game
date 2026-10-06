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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Characters = require(script.Parent.Parent.Characters)

local Stage = {}
Stage.__index = Stage

type Saved = { [Instance]: any }

export type Stage = typeof(setmetatable({} :: { folder: Folder, hidden: { [Model]: Saved }, actors: { Model } }, Stage))

local function folder(): Folder
	local existing = workspace:FindFirstChild("DeathsGambitStage")
	if existing and existing:IsA("Folder") then
		return existing
	end
	return Create("Folder", { Name = "DeathsGambitStage", Parent = workspace })
end

function Stage.new(): Stage
	local set = Create("Folder", { Name = "Set", Parent = folder() })
	return setmetatable({ folder = set, hidden = {}, actors = {} }, Stage)
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

-- A still copy of a character: no scripts, no physics, no name tag.
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
	clone:SetAttribute("Specter", nil)
	return clone
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
			local model = ModelLibrary.get("Grimoire")
			if model then
				return model
			end
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
			if item:IsA("BasePart") and item ~= anchor then
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
	self.folder:ClearAllChildren()
end

function Stage.destroy(self: Stage)
	self:clear()
	self.folder:Destroy()
end

return Stage
