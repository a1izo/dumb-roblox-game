-- Bodies. A player who dies first plays their collapse (on every client), then goes limp:
-- each joint becomes a ball socket with limits. A few seconds later the body is frozen in
-- place as a lifeless copy at the table and the player respawns. The copies are cleared
-- when the next round starts, and a card with the alias marks the empty place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Create = require(Shared:WaitForChild("Create"))
local Joints = require(Anim:WaitForChild("Joints"))
local Causes = require(Anim:WaitForChild("Causes"))

local CollisionGroups = require(script.Parent.CollisionGroups)
local Match = require(script.Parent.Match)

local RagdollService = {}

RagdollService.GROUP = CollisionGroups.RAGDOLL
-- The collapse clip plays for this long (cue lead included) before the body goes limp.
RagdollService.COLLAPSE_DELAY = 1.9
-- How long the limp body stays physical before it is frozen.
RagdollService.BODY_TIME = 4.5

-- Ball-socket limits per joint: { cone angle, twist }.
local LIMITS = {
	Neck = { 35, 30 },
	["Left Shoulder"] = { 80, 45 },
	["Right Shoulder"] = { 80, 45 },
	["Left Hip"] = { 55, 20 },
	["Right Hip"] = { 55, 20 },
}

-- Which way each limb points from its joint, in the parent part's frame (the neck goes up).
local LIMB_UP = Vector3.new(0, 1, 0)
local LIMB_DOWN = Vector3.new(0, -1, 0)

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

-- Locks the last frame of a clip into the joints (C0), so the pose every client animated is
-- also where the physics starts. Clients stop animating the body when LPoseBaked is set.
function RagdollService.bakePose(character: Model, clipId: string)
	local clip = ClipPlayer.get(clipId)
	if not clip then
		return
	end
	local rotations, offset = ClipPlayer.sample(clip, clip.length)
	for joint, motor in pairs(Joints.find(character)) do
		local rot = rotations[joint]
		local jointOffset = if joint == "root" then offset else nil
		if rot or jointOffset then
			local c0 = Joints.c0(motor)
			local basis = c0 - c0.Position
			Joints.setC0(motor, c0 * ClipPlayer.transform(basis, rot or CFrame.identity, jointOffset))
		end
	end
	character:SetAttribute("LPoseBaked", true)
end

-- Turns every joint (Motor6D or AnimationConstraint) into a limited ball socket so the body
-- falls naturally.
function RagdollService.ragdoll(character: Model)
	for name, joint in pairs(Joints.find(character)) do
		local parent, child = Joints.parent(joint), Joints.child(joint)
		if name ~= "root" and parent and child then
			local limit = LIMITS[Joints.R6[name].motor] or { 45, 20 }
			-- A ball socket's cone and twist run along its attachments' X axis, so the attachments
			-- point down the limb (R6 joints are turned a quarter, which would aim them sideways).
			local c0, c1 = Joints.c0(joint), Joints.c1(joint)
			local along = if name == "neck" then LIMB_UP else LIMB_DOWN
			local side = if math.abs(along.Z) > 0.9 then Vector3.xAxis else Vector3.zAxis
			local frame0 = CFrame.fromMatrix(c0.Position, along, along:Cross(side).Unit:Cross(along))
			local frame1 = c1 * c0:Inverse() * frame0
			local a0 = Create("Attachment", { Name = "RagdollA0", CFrame = frame0, Parent = parent })
			local a1 = Create("Attachment", { Name = "RagdollA1", CFrame = frame1, Parent = child })
			Create("BallSocketConstraint", {
				Name = "RagdollSocket",
				Attachment0 = a0,
				Attachment1 = a1,
				LimitsEnabled = true,
				UpperAngle = limit[1],
				TwistLimitsEnabled = true,
				TwistLowerAngle = -limit[2],
				TwistUpperAngle = limit[2],
				Parent = child,
			})
			joint.Enabled = false
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
-- respawn(player) is called when the player should get a new character. cause picks the
-- collapse clip (the same one every client plays).
function RagdollService.collapse(player: Player, alias: string, respawn: (Player) -> (), cause: string?)
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
		RagdollService.bakePose(character, Causes.clipFor(cause))
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

return RagdollService
