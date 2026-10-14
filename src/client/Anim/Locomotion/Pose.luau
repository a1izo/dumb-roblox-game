--!strict
-- Poses for the movement controller: a CFrame per joint (rotation and slide, in the joint's parent frame,
-- the clips' own form) and the whole body's offset. Sampling a cycle with each leg at its own phase,
-- mixing poses by weight, and laying an additive clip over a pose. Each pose is a buffer reused frame
-- after frame, so the controller allocates no tables while it runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anim = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Gait = require(Anim:WaitForChild("Gait"))

local Pose = {}

export type Pose = { joints: { [string]: CFrame }, offset: Vector3 }

local IDENTITY = CFrame.identity

function Pose.new(): Pose
	return { joints = {}, offset = Vector3.zero }
end

function Pose.clear(pose: Pose)
	table.clear(pose.joints)
	pose.offset = Vector3.zero
end

function Pose.copy(from: Pose, into: Pose)
	table.clear(into.joints)
	for joint, cf in pairs(from.joints) do
		into.joints[joint] = cf
	end
	into.offset = from.offset
end

-- A clip at `time` seconds (looping or holding its end).
function Pose.sample(clip: ClipPlayer.Prepared, time: number, into: Pose)
	table.clear(into.joints)
	local _, offset = ClipPlayer.sample(clip, time, into.joints)
	into.offset = offset or Vector3.zero
end

-- A movement cycle at a shared phase (0..1): the body at that phase, and each leg at the phase that
-- stretches its clip's stance to `shared` of the cycle (Gait.warp), so cycles of different stance
-- blended together put their feet down together.
function Pose.sampleCycle(clip: ClipPlayer.Prepared, phase: number, shared: number, into: Pose)
	table.clear(into.joints)
	local length = clip.length
	local stance = clip.stance or shared
	local upper = (phase % 1) * length
	for joint, track in pairs(clip.joints) do
		local t = upper
		if joint == "rHip" then
			t = Gait.warp(phase, shared, stance) * length
		elseif joint == "lHip" then
			t = Gait.leftWarp(phase, shared, stance) * length
		end
		into.joints[joint] = ClipPlayer.sampleTrack(track, t)
	end
	into.offset = ClipPlayer.sampleOffset(clip, upper) or Vector3.zero
end

-- Folds `pose` into the running mean held in `into` (whose weight so far is `total`); returns the new
-- total. Mixing every pose of a blend this way gives their weighted average.
function Pose.mix(into: Pose, pose: Pose, weight: number, total: number): number
	if weight <= 0 then
		return total
	end
	local sum = total + weight
	if total <= 0 then
		Pose.copy(pose, into)
		return sum
	end
	local k = weight / sum
	for joint, cf in pairs(pose.joints) do
		local mine = into.joints[joint]
		into.joints[joint] = if mine then mine:Lerp(cf, k) else IDENTITY:Lerp(cf, k)
	end
	for joint, mine in pairs(into.joints) do
		if not pose.joints[joint] then
			into.joints[joint] = mine:Lerp(IDENTITY, k)
		end
	end
	into.offset = into.offset:Lerp(pose.offset, k)
	return sum
end

-- `into` moved `weight` of the way to `pose`.
function Pose.blend(into: Pose, pose: Pose, weight: number)
	if weight <= 0 then
		return
	end
	Pose.mix(into, pose, weight, 1 - weight)
end

-- Lays an additive clip over `into`: each joint it moves turns (and slides) by the change from the clip's
-- first frame, scaled by `weight`; the body offset moves by its change scaled by `lift`. The legs are left
-- alone unless `legs` (the after-pass plants standing feet; a cycle's legs keep running).
local delta = Pose.new()
local firsts: { [ClipPlayer.Prepared]: Pose } = {}
function Pose.add(into: Pose, clip: ClipPlayer.Prepared, time: number, weight: number, lift: number, legs: boolean)
	if weight <= 0 then
		return
	end
	local first = firsts[clip]
	if not first then
		first = Pose.new()
		Pose.sample(clip, 0, first)
		firsts[clip] = first
	end
	Pose.sample(clip, time, delta)
	for joint, cf in pairs(delta.joints) do
		if not legs and (joint == "rHip" or joint == "lHip") then
			continue
		end
		local from = first.joints[joint] or IDENTITY
		local change = IDENTITY:Lerp(from:Inverse() * cf, weight)
		into.joints[joint] = (into.joints[joint] or IDENTITY) * change
	end
	into.offset += (delta.offset - first.offset) * lift
end

return Pose
