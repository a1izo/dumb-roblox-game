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
local Poses = require(Anim:WaitForChild("Poses"))

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
			local limit = LIMITS[Joints.R15[name].motor] or { 45, 20 }
			local a0 = Create("Attachment", { Name = "RagdollA0", CFrame = Joints.c0(joint), Parent = parent })
			local a1 = Create("Attachment", { Name = "RagdollA1", CFrame = Joints.c1(joint), Parent = child })
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
		RagdollService.bakePose(character, Poses.FOR_CAUSE[cause or ""] or "collapseHeart")
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
