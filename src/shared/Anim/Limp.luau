--!strict
-- Going limp: every R6 joint but the root becomes a limited ball socket, so the body falls and settles
-- by physics. Used by the server for the bodies of the dead (Services/RagdollService) and by a diver's own
-- client when a dive into the rift ends on the roof (Controllers/DiveController), which puts the joints back
-- afterwards with the function apply() returns.
--
-- Each limb gets a NoCollisionConstraint with the torso: a limb's end sits inside the torso at the
-- shoulder and the hip, and the two pushing apart made a limp body shiver.
--
-- A living player's Humanoid keeps an R6 body's arms and legs from colliding, whatever their CanCollide says;
-- `colliders` adds an unseen solid box welded inside each limb (and the head), so a body that is still a
-- player's lands on what it falls on rather than through it.

local Joints = require(script.Parent.Joints)

local Limp = {}

-- Ball-socket limits per joint: { cone angle, twist }.
Limp.LIMITS = {
	Neck = { 35, 30 },
	["Left Shoulder"] = { 80, 45 },
	["Right Shoulder"] = { 80, 45 },
	["Left Hip"] = { 55, 20 },
	["Right Hip"] = { 55, 20 },
} :: { [string]: { number } }

-- Which way each limb points from its joint, in the parent part's frame (the neck goes up).
local LIMB_UP = Vector3.new(0, 1, 0)
local LIMB_DOWN = Vector3.new(0, -1, 0)

-- An unseen solid box welded inside a part, the part's own size a little smaller.
local function collider(part: BasePart, torso: BasePart?): { Instance }
	local box = Instance.new("Part")
	box.Name = "RagdollCollider"
	box.Size = part.Size * 0.9
	box.CFrame = part.CFrame
	box.Transparency = 1
	box.Massless = true
	box.CanCollide = true
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.CollisionGroup = part.CollisionGroup
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = box
	weld.Parent = box
	box.Parent = part
	local out: { Instance } = { box }
	if torso then
		local apart = Instance.new("NoCollisionConstraint")
		apart.Part0 = torso
		apart.Part1 = box
		apart.Parent = box
	end
	return out
end

-- Makes the body limp (`colliders`: see above). Returns a function that puts every joint back (and removes
-- what was added).
function Limp.apply(character: Model, colliders: boolean?): () -> ()
	local added: { Instance } = {}
	local disabled: { any } = {}
	local torso = character:FindFirstChild("Torso")
	for name, joint in pairs(Joints.find(character)) do
		local parent, child = Joints.parent(joint), Joints.child(joint)
		if name ~= "root" and parent and child then
			local limit = Limp.LIMITS[Joints.R6[name].motor] or { 45, 20 }
			-- A ball socket's cone and twist run along its attachments' X axis, so the attachments
			-- point down the limb (R6 joints are turned a quarter, which would aim them sideways).
			local c0, c1 = Joints.c0(joint), Joints.c1(joint)
			local along = if name == "neck" then LIMB_UP else LIMB_DOWN
			local side = if math.abs(along.Z) > 0.9 then Vector3.xAxis else Vector3.zAxis
			local frame0 = CFrame.fromMatrix(c0.Position, along, along:Cross(side).Unit:Cross(along))
			local frame1 = c1 * c0:Inverse() * frame0
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = frame0
			a0.Parent = parent
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = frame1
			a1.Parent = child
			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.UpperAngle = limit[1]
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -limit[2]
			socket.TwistUpperAngle = limit[2]
			socket.Parent = child
			table.insert(added, a0)
			table.insert(added, a1)
			table.insert(added, socket)
			if torso and torso:IsA("BasePart") and child ~= torso then
				local apart = Instance.new("NoCollisionConstraint")
				apart.Name = "RagdollApart"
				apart.Part0 = torso
				apart.Part1 = child
				apart.Parent = child
				table.insert(added, apart)
			end
			joint.Enabled = false
			table.insert(disabled, joint)
			if colliders and child:IsA("BasePart") then
				for _, item in ipairs(collider(child, if torso and torso:IsA("BasePart") then torso else nil)) do
					table.insert(added, item)
				end
			end
		end
	end
	return function()
		for _, joint in ipairs(disabled) do
			if joint.Parent then
				joint.Enabled = true
			end
		end
		for _, item in ipairs(added) do
			item:Destroy()
		end
		table.clear(added)
		table.clear(disabled)
	end
end

return Limp
