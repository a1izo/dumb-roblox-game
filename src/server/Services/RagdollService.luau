-- Bodies. A player who dies first plays their collapse (on every client), then goes limp:
-- each joint becomes a ball socket with limits. A few seconds later the body is frozen in
-- place as a lifeless copy at the table and the player respawns. The copies are cleared
-- when the next round starts, and a card with the alias marks the empty place.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Match = require(script.Parent.Match)

local RagdollService = {}

RagdollService.GROUP = "Ragdoll"
-- The collapse plays for this long (cue lead included) before the body goes limp.
RagdollService.COLLAPSE_DELAY = 1.7
-- How long the limp body stays physical before it is frozen.
RagdollService.BODY_TIME = 4.5

-- Ball-socket limits per joint: { cone angle, twist }.
local LIMITS = {
	Neck = { 35, 30 },
	Waist = { 30, 25 },
	Root = { 20, 15 },
	LeftShoulder = { 80, 45 },
	RightShoulder = { 80, 45 },
	LeftElbow = { 70, 10 },
	RightElbow = { 70, 10 },
	LeftWrist = { 35, 10 },
	RightWrist = { 35, 10 },
	LeftHip = { 55, 20 },
	RightHip = { 55, 20 },
	LeftKnee = { 70, 5 },
	RightKnee = { 70, 5 },
	LeftAnkle = { 25, 5 },
	RightAnkle = { 25, 5 },
}

local function bodiesFolder(): Instance?
	local map = Match.map
	if not map or not map.model or not map.model.Parent then
		return nil
	end
	local existing = map.model:FindFirstChild("Bodies")
	if existing then
		return existing
	end
	return Create("Folder", { Name = "Bodies", Parent = map.model })
end

-- Turns every Motor6D into a limited ball socket so the body falls naturally.
function RagdollService.ragdoll(character: Model)
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 and motor.Name ~= "Root" then
			local limit = LIMITS[motor.Name] or { 45, 20 }
			local a0 = Create("Attachment", { Name = "RagdollA0", CFrame = motor.C0, Parent = motor.Part0 })
			local a1 = Create("Attachment", { Name = "RagdollA1", CFrame = motor.C1, Parent = motor.Part1 })
			Create("BallSocketConstraint", {
				Name = "RagdollSocket",
				Attachment0 = a0,
				Attachment1 = a1,
				LimitsEnabled = true,
				UpperAngle = limit[1],
				TwistLimitsEnabled = true,
				TwistLowerAngle = -limit[2],
				TwistUpperAngle = limit[2],
				Parent = motor.Part1,
			})
			motor.Enabled = false
		end
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = RagdollService.GROUP
			if part.Name == "HumanoidRootPart" then
				part.CanCollide = false
			elseif part.Parent == character then
				part.CanCollide = true
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

-- Leaves a frozen, lifeless copy of the body where it lies.
local function freezeCopy(character: Model, alias: string)
	local folder = bodiesFolder()
	if not folder or not character.Parent then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return
	end
	copy.Name = "Body_" .. alias
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif
			item:IsA("Script")
			or item:IsA("LocalScript")
			or item:IsA("Sound")
			or item:IsA("Trail")
			or item:IsA("ParticleEmitter")
			or item:IsA("ProximityPrompt")
		then
			item:Destroy()
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			item.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	copy.Parent = folder
end

-- Plays out a death: the collapse, the ragdoll, then the frozen copy and the respawn.
-- respawn(player) is called when the player should get a new character.
function RagdollService.collapse(player: Player, alias: string, respawn: (Player) -> ())
	local character = player.Character
	if not character then
		respawn(player)
		return
	end
	-- Tells the Died handler not to respawn on its own.
	character:SetAttribute("LHeldBody", true)
	task.delay(RagdollService.COLLAPSE_DELAY, function()
		if not character.Parent then
			return
		end
		RagdollService.ragdoll(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
		task.delay(RagdollService.BODY_TIME, function()
			if character.Parent then
				freezeCopy(character, alias)
			end
			if player.Parent == Players and player.Character == character then
				respawn(player)
			end
		end)
	end)
end

-- Removes the bodies (the next round starts).
function RagdollService.clearBodies()
	local map = Match.map
	local folder = if map and map.model then map.model:FindFirstChild("Bodies") else nil
	if folder then
		folder:ClearAllChildren()
	end
end

function RagdollService.init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RagdollService.GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(RagdollService.GROUP, RagdollService.GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(RagdollService.GROUP, "Default", true)
end

return RagdollService
