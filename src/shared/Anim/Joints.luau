--!strict
-- The R15 joints poses can move, by short name. Each joint is the Motor6D inside `part`.
--
-- Angles in poses are degrees around the joint, in the parent part's frame:
--   x: pitch. Arms and legs: + swings forward/up. Knees: - bends. Neck and waist: - leans
--      forward (looks down), + leans back.
--   y: twist (turn left is +).
--   z: roll. Right arm: + lifts it out to the side. Left arm: - lifts it out.

local Joints = {}

export type Joint = { part: string, motor: string }

Joints.R15 = {
	root = { part = "LowerTorso", motor = "Root" },
	waist = { part = "UpperTorso", motor = "Waist" },
	neck = { part = "Head", motor = "Neck" },
	lShoulder = { part = "LeftUpperArm", motor = "LeftShoulder" },
	lElbow = { part = "LeftLowerArm", motor = "LeftElbow" },
	lWrist = { part = "LeftHand", motor = "LeftWrist" },
	rShoulder = { part = "RightUpperArm", motor = "RightShoulder" },
	rElbow = { part = "RightLowerArm", motor = "RightElbow" },
	rWrist = { part = "RightHand", motor = "RightWrist" },
	lHip = { part = "LeftUpperLeg", motor = "LeftHip" },
	lKnee = { part = "LeftLowerLeg", motor = "LeftKnee" },
	lAnkle = { part = "LeftFoot", motor = "LeftAnkle" },
	rHip = { part = "RightUpperLeg", motor = "RightHip" },
	rKnee = { part = "RightLowerLeg", motor = "RightKnee" },
	rAnkle = { part = "RightFoot", motor = "RightAnkle" },
} :: { [string]: Joint }

-- Finds the Motor6D for every joint on an R15 character. Missing joints are left out.
function Joints.find(character: Model): { [string]: Motor6D }
	local motors = {}
	for name, joint in pairs(Joints.R15) do
		local part = character:FindFirstChild(joint.part)
		local motor = if part then part:FindFirstChild(joint.motor) else nil
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
	end
	return motors
end

return Joints
