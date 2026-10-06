--!strict
-- The R6 joints poses can move, by short name. R6 has six Motor6Ds: the RootJoint (in the
-- HumanoidRootPart; it moves the Torso, so it also bends the waist) and the Neck, both
-- Shoulders and both Hips (all in the Torso).
--
-- A joint is either a Motor6D or an AnimationConstraint (Roblox's Avatar Joint Upgrade).
-- Both have a Transform the animator writes, and both place the child part at
-- parent * C0 * Transform * C1:Inverse(). For a Motor6D, C0 and C1 are properties; for an
-- AnimationConstraint they are its two attachments' CFrames. Use Joints.c0/c1/setC0 instead of
-- reading the properties directly.
--
-- Angles in clips and poses are degrees (or quaternions) around the joint, in the parent part's
-- frame, relative to the rest pose:
--   x: pitch. Arms and legs: + swings forward/up. Neck and root: - leans forward, + leans back.
--   y: twist (turn left is +).
--   z: roll. Right arm and leg: + lifts it out to the side. Left arm and leg: - lifts it out.
-- ClipPlayer.transform turns that into the joint's Transform using the rotation of its C0.

local Joints = {}

-- part: the part the joint moves (its Part1). home: the part that holds the Motor6D.
export type Joint = { part: string, motor: string, home: string }

-- A Motor6D or an AnimationConstraint.
export type Instance6D = any

Joints.R6 = {
	root = { part = "Torso", motor = "RootJoint", home = "HumanoidRootPart" },
	neck = { part = "Head", motor = "Neck", home = "Torso" },
	lShoulder = { part = "Left Arm", motor = "Left Shoulder", home = "Torso" },
	rShoulder = { part = "Right Arm", motor = "Right Shoulder", home = "Torso" },
	lHip = { part = "Left Leg", motor = "Left Hip", home = "Torso" },
	rHip = { part = "Right Leg", motor = "Right Hip", home = "Torso" },
} :: { [string]: Joint }

Joints.COUNT = 6

local function isJoint(item: Instance): boolean
	return item:IsA("Motor6D") or item:IsA("AnimationConstraint")
end

-- The part a joint moves (its child part).
function Joints.child(joint: Instance6D): BasePart?
	if joint:IsA("Motor6D") then
		return joint.Part1
	end
	local attachment = joint.Attachment1
	local parent = if attachment then attachment.Parent else nil
	return if parent and parent:IsA("BasePart") then parent else nil
end

-- The part a joint hangs from.
function Joints.parent(joint: Instance6D): BasePart?
	if joint:IsA("Motor6D") then
		return joint.Part0
	end
	local attachment = joint.Attachment0
	local parent = if attachment then attachment.Parent else nil
	return if parent and parent:IsA("BasePart") then parent else nil
end

function Joints.c0(joint: Instance6D): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	local attachment = joint.Attachment0
	return if attachment then attachment.CFrame else CFrame.identity
end

function Joints.c1(joint: Instance6D): CFrame
	if joint:IsA("Motor6D") then
		return joint.C1
	end
	local attachment = joint.Attachment1
	return if attachment then attachment.CFrame else CFrame.identity
end

-- Moves the joint's resting frame in the parent part (bakes a pose into the rig).
function Joints.setC0(joint: Instance6D, cframe: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = cframe
	elseif joint.Attachment0 then
		joint.Attachment0.CFrame = cframe
	end
end

-- Finds the joint for every R6 joint name. Missing joints are left out.
function Joints.find(character: Model): { [string]: Instance6D }
	local found = {}
	local missing = false
	for name, joint in pairs(Joints.R6) do
		local part = character:FindFirstChild(joint.part)
		local home = character:FindFirstChild(joint.home)
		local item = if home then home:FindFirstChild(joint.motor) else nil
		if item and part and isJoint(item) and Joints.child(item) == part then
			found[name] = item
		else
			missing = true
		end
	end
	if not missing then
		return found
	end
	-- Not where a classic rig keeps them: match joints by the part they move.
	local byPart = {}
	for name, joint in pairs(Joints.R6) do
		if not found[name] then
			byPart[joint.part] = name
		end
	end
	for _, item in ipairs(character:GetDescendants()) do
		if isJoint(item) then
			local child = Joints.child(item)
			local name = if child and child.Parent == character then byPart[child.Name] else nil
			if name and not found[name] then
				found[name] = item
			end
		end
	end
	return found
end

-- "Motor6D", "AnimationConstraint", "mixed" or "none", for the Studio check line.
function Joints.kind(found: { [string]: Instance6D }): string
	local kind = nil
	for _, joint in pairs(found) do
		local class = joint.ClassName
		if kind == nil then
			kind = class
		elseif kind ~= class then
			return "mixed"
		end
	end
	return kind or "none"
end

return Joints
