-- Joints are found on classic rigs (Motor6D) and on upgraded rigs (AnimationConstraint), and
-- both kinds give the same C0/C1 frames, so every pose lands the same on either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Joints = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("Joints"))

local PARENTS = {
	Torso = "HumanoidRootPart",
	Head = "Torso",
	["Left Arm"] = "Torso",
	["Right Arm"] = "Torso",
	["Left Leg"] = "Torso",
	["Right Leg"] = "Torso",
}

local C0 = CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.rad(30), 0)
local C1 = CFrame.new(0, -0.4, 0.1)

-- A bare R6 skeleton. `kind` picks the joint class; `hidden` puts the joints somewhere a
-- classic rig would not (in the part they move, as R15 keeps them), with other names.
local function rig(kind: string, hidden: boolean?): Model
	local model = Instance.new("Model")
	local parts = {}
	for _, name in ipairs({ "HumanoidRootPart" }) do
		local part = Instance.new("Part")
		part.Name = name
		part.Parent = model
		parts[name] = part
	end
	for child in pairs(PARENTS) do
		local part = Instance.new("Part")
		part.Name = child
		part.Parent = model
		parts[child] = part
	end
	local motorName = {}
	for _, joint in pairs(Joints.R6) do
		motorName[joint.part] = joint.motor
	end
	for child, parentName in pairs(PARENTS) do
		local parent, part = parts[parentName], parts[child]
		local name = if hidden then "Joint_" .. child else motorName[child]
		local holder = if hidden then part else parent
		if kind == "Motor6D" then
			local motor = Instance.new("Motor6D")
			motor.Name = name
			motor.Part0 = parent
			motor.Part1 = part
			motor.C0 = C0
			motor.C1 = C1
			motor.Parent = holder
		else
			local a0 = Instance.new("Attachment")
			a0.Name = child .. "RigAttachment"
			a0.CFrame = C0
			a0.Parent = parent
			local a1 = Instance.new("Attachment")
			a1.Name = child .. "RigAttachment"
			a1.CFrame = C1
			a1.Parent = part
			local constraint = Instance.new("AnimationConstraint")
			constraint.Name = name
			constraint.Attachment0 = a0
			constraint.Attachment1 = a1
			constraint.Parent = holder
		end
	end
	return model
end

local function count(found): number
	local n = 0
	for _ in pairs(found) do
		n += 1
	end
	return n
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Joints", function()
		it("finds every joint of a classic rig", function()
			local model = rig("Motor6D")
			local found = Joints.find(model)
			expect(count(found)).to.equal(Joints.COUNT)
			expect(Joints.kind(found)).to.equal("Motor6D")
			model:Destroy()
		end)
		it("finds every joint of an upgraded rig", function()
			local model = rig("AnimationConstraint")
			local found = Joints.find(model)
			expect(count(found)).to.equal(Joints.COUNT)
			expect(Joints.kind(found)).to.equal("AnimationConstraint")
			expect(Joints.child(found.lHip).Name).to.equal("Left Leg")
			expect(Joints.parent(found.lHip).Name).to.equal("Torso")
			model:Destroy()
		end)
		it("finds joints kept elsewhere under other names", function()
			for _, kind in ipairs({ "Motor6D", "AnimationConstraint" }) do
				local model = rig(kind, true)
				local found = Joints.find(model)
				expect(count(found)).to.equal(Joints.COUNT)
				expect(Joints.child(found.neck).Name).to.equal("Head")
				model:Destroy()
			end
		end)
		it("reads the same frames from both kinds", function()
			local classic, upgraded = rig("Motor6D"), rig("AnimationConstraint")
			local a, b = Joints.find(classic), Joints.find(upgraded)
			for name in pairs(Joints.R6) do
				expect(Joints.c0(a[name]):FuzzyEq(Joints.c0(b[name]), 1e-4)).to.equal(true)
				expect(Joints.c1(a[name]):FuzzyEq(Joints.c1(b[name]), 1e-4)).to.equal(true)
			end
			local moved = C0 * CFrame.Angles(0.3, 0, 0)
			Joints.setC0(b.root, moved)
			expect(Joints.c0(b.root):FuzzyEq(moved, 1e-4)).to.equal(true)
			classic:Destroy()
			upgraded:Destroy()
		end)
	end)
end
