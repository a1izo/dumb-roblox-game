--!strict
-- Procedural poses: a few keyframes of joint angles (see Joints.luau for the directions).
-- A pose only moves the joints it names, so walking keeps playing on the rest of the body.
-- A slot in Assets.anim with an uploaded animation id replaces the pose of the same name.

local Joints = require(script.Parent.Joints)

local Poses = {}

export type Angles = { number } -- { x, y, z } in degrees
export type Frame = {
	t: number, -- seconds from the start
	j: { [string]: Angles },
	offset: Vector3?, -- moves the whole body (root joint), in studs
}
export type Pose = {
	frames: { Frame },
	loop: boolean?, -- loops over the last frame's time; otherwise holds the last frame
}

local function hold(joints: { [string]: Angles }, offset: Vector3?): { Frame }
	return { { t = 0, j = joints, offset = offset } }
end

Poses.LIST = {
	-- Writing in a notebook held in the left hand. Everyone alive plays it in the Grimoire phase.
	write = {
		loop = true,
		frames = {
			{
				t = 0,
				j = {
					neck = { -28, 0, 0 },
					waist = { -6, 0, 0 },
					lShoulder = { 55, 0, 20 },
					lElbow = { 65, 0, 0 },
					rShoulder = { 48, 0, -18 },
					rElbow = { 72, 0, 0 },
					rWrist = { 0, 0, -12 },
				},
			},
			{
				t = 0.35,
				j = {
					neck = { -30, 4, 0 },
					waist = { -6, 0, 0 },
					lShoulder = { 55, 0, 20 },
					lElbow = { 65, 0, 0 },
					rShoulder = { 50, 0, -14 },
					rElbow = { 66, 0, 0 },
					rWrist = { 0, 0, 14 },
				},
			},
			{
				t = 0.7,
				j = {
					neck = { -28, 0, 0 },
					waist = { -6, 0, 0 },
					lShoulder = { 55, 0, 20 },
					lElbow = { 65, 0, 0 },
					rShoulder = { 48, 0, -18 },
					rElbow = { 72, 0, 0 },
					rWrist = { 0, 0, -12 },
				},
			},
		},
	},

	-- Deaths, one per cause. The body goes limp (ragdoll) when the pose ends.
	collapseHeart = {
		frames = {
			{ t = 0, j = { neck = { 0, 0, 0 }, waist = { 0, 0, 0 }, rShoulder = { 0, 0, 0 }, rElbow = { 0, 0, 0 } } },
			{
				t = 0.3,
				j = {
					neck = { 20, 0, 0 },
					waist = { -12, 0, 0 },
					rShoulder = { 62, 0, -38 },
					rElbow = { 105, 0, 0 },
					lShoulder = { 20, 0, -25 },
				},
			},
			{
				t = 1,
				j = {
					neck = { -25, 0, 10 },
					waist = { -35, 0, 0 },
					rShoulder = { 62, 0, -38 },
					rElbow = { 105, 0, 0 },
					lShoulder = { 30, 0, -10 },
					lHip = { 45, 0, 0 },
					lKnee = { -70, 0, 0 },
					rHip = { 35, 0, 0 },
					rKnee = { -60, 0, 0 },
				},
				offset = Vector3.new(0, -1.1, 0),
			},
		},
	},
	collapseIllness = {
		frames = {
			{ t = 0, j = { waist = { 0, 0, 0 }, neck = { 0, 0, 0 } } },
			{
				t = 0.25,
				j = {
					waist = { -40, 0, 0 },
					neck = { -10, 0, 0 },
					lShoulder = { 35, 0, 22 },
					lElbow = { 85, 0, 0 },
					rShoulder = { 35, 0, -22 },
					rElbow = { 85, 0, 0 },
				},
			},
			{
				t = 0.5,
				j = {
					waist = { -30, 0, 0 },
					neck = { 5, 0, 0 },
					lShoulder = { 35, 0, 22 },
					lElbow = { 85, 0, 0 },
					rShoulder = { 35, 0, -22 },
					rElbow = { 85, 0, 0 },
				},
			},
			{
				t = 1.1,
				j = {
					waist = { -55, 0, 0 },
					neck = { -20, 0, 0 },
					lShoulder = { 40, 0, 22 },
					lElbow = { 90, 0, 0 },
					rShoulder = { 40, 0, -22 },
					rElbow = { 90, 0, 0 },
					lHip = { 60, 0, 0 },
					lKnee = { -90, 0, 0 },
					rHip = { 60, 0, 0 },
					rKnee = { -90, 0, 0 },
				},
				offset = Vector3.new(0, -1.4, 0),
			},
		},
	},
	collapseFall = {
		frames = {
			{ t = 0, j = { waist = { 0, 0, 0 }, neck = { 0, 0, 0 } } },
			{
				t = 0.35,
				j = {
					waist = { 18, 0, 0 },
					neck = { 30, 0, 0 },
					lShoulder = { 150, 0, -45 },
					lElbow = { 25, 0, 0 },
					rShoulder = { 150, 0, 45 },
					rElbow = { 25, 0, 0 },
					lHip = { 25, 0, 0 },
				},
			},
			{
				t = 1,
				j = {
					waist = { 28, 0, 0 },
					neck = { 35, 0, 0 },
					lShoulder = { 120, 0, -70 },
					lElbow = { 15, 0, 0 },
					rShoulder = { 120, 0, 70 },
					rElbow = { 15, 0, 0 },
					lHip = { 40, 0, 0 },
					rHip = { 10, 0, 0 },
				},
				offset = Vector3.new(0, -0.6, 0.6),
			},
		},
	},
	collapseTraffic = {
		frames = {
			{ t = 0, j = { waist = { 0, 0, 0 }, root = { 0, 0, 0 } } },
			{
				t = 0.15,
				j = {
					root = { -8, 35, 0 },
					waist = { 10, 30, 0 },
					neck = { 20, -30, 0 },
					lShoulder = { 30, 0, -80 },
					rShoulder = { 30, 0, 80 },
					rElbow = { 20, 0, 0 },
				},
			},
			{
				t = 1,
				j = {
					root = { -15, 80, 0 },
					waist = { -20, 20, 0 },
					neck = { -25, 0, 0 },
					lShoulder = { 10, 0, -40 },
					rShoulder = { 10, 0, 40 },
					lHip = { 50, 0, 0 },
					lKnee = { -70, 0, 0 },
				},
				offset = Vector3.new(0, -1.2, 0),
			},
		},
	},

	-- Arrested: hands cuffed behind the back, head down.
	cuffed = {
		frames = hold({
			neck = { -22, 0, 0 },
			lShoulder = { -38, 0, 14 },
			lElbow = { 35, 0, 0 },
			rShoulder = { -38, 0, -14 },
			rElbow = { 35, 0, 0 },
		}),
	},
	-- The player voted out slumps before they fade away.
	slump = {
		frames = {
			{ t = 0, j = { neck = { 0, 0, 0 }, waist = { 0, 0, 0 } } },
			{
				t = 0.6,
				j = {
					neck = { -45, 0, 0 },
					waist = { -18, 0, 0 },
					lShoulder = { 4, 0, 6 },
					rShoulder = { 4, 0, -6 },
				},
			},
		},
	},
	-- A vote is cast (who voted is public; for whom is not).
	raiseHand = {
		frames = {
			{ t = 0, j = { rShoulder = { 0, 0, 0 }, rElbow = { 0, 0, 0 } } },
			{ t = 0.25, j = { rShoulder = { 168, 0, -8 }, rElbow = { 12, 0, 0 } } },
		},
	},

	-- Endings.
	victory = {
		loop = true,
		frames = {
			{
				t = 0,
				j = {
					lShoulder = { 160, 0, -28 },
					lElbow = { 18, 0, 0 },
					rShoulder = { 160, 0, 28 },
					rElbow = { 18, 0, 0 },
					neck = { 12, 0, 0 },
				},
			},
			{
				t = 0.45,
				j = {
					lShoulder = { 172, 0, -18 },
					lElbow = { 4, 0, 0 },
					rShoulder = { 172, 0, 18 },
					rElbow = { 4, 0, 0 },
					neck = { 20, 0, 0 },
				},
			},
			{
				t = 0.9,
				j = {
					lShoulder = { 160, 0, -28 },
					lElbow = { 18, 0, 0 },
					rShoulder = { 160, 0, 28 },
					rElbow = { 18, 0, 0 },
					neck = { 12, 0, 0 },
				},
			},
		},
	},
	defeat = {
		frames = {
			{ t = 0, j = { neck = { 0, 0, 0 }, waist = { 0, 0, 0 } } },
			{
				t = 0.8,
				j = {
					neck = { -40, 0, 0 },
					waist = { -14, 0, 0 },
					lShoulder = { 6, 0, 4 },
					rShoulder = { 6, 0, -4 },
				},
			},
		},
	},
	laugh = {
		loop = true,
		frames = {
			{
				t = 0,
				j = {
					waist = { 14, 0, 0 },
					neck = { 26, 0, 0 },
					lShoulder = { 25, 0, 30 },
					lElbow = { 95, 0, 0 },
					rShoulder = { 25, 0, -30 },
					rElbow = { 95, 0, 0 },
				},
			},
			{
				t = 0.22,
				j = {
					waist = { 22, 0, 0 },
					neck = { 34, 0, 0 },
					lShoulder = { 28, 0, 30 },
					lElbow = { 95, 0, 0 },
					rShoulder = { 28, 0, -30 },
					rElbow = { 95, 0, 0 },
				},
			},
			{
				t = 0.44,
				j = {
					waist = { 14, 0, 0 },
					neck = { 26, 0, 0 },
					lShoulder = { 25, 0, 30 },
					lElbow = { 95, 0, 0 },
					rShoulder = { 25, 0, -30 },
					rElbow = { 95, 0, 0 },
				},
			},
		},
	},
	-- The Hand, caught: down on one knee with the hands behind the back.
	kneel = {
		frames = {
			{ t = 0, j = { lHip = { 0, 0, 0 }, rHip = { 0, 0, 0 } } },
			{
				t = 0.7,
				j = {
					neck = { -30, 0, 0 },
					waist = { -8, 0, 0 },
					lHip = { 85, 0, 0 },
					lKnee = { -85, 0, 0 },
					rHip = { -8, 0, 0 },
					rKnee = { -100, 0, 0 },
					rAnkle = { 30, 0, 0 },
					lShoulder = { -38, 0, 14 },
					lElbow = { 35, 0, 0 },
					rShoulder = { -38, 0, -14 },
					rElbow = { 35, 0, 0 },
				},
				offset = Vector3.new(0, -1.25, 0),
			},
		},
	},
	-- Specters drift with their legs trailing.
	specterFloat = {
		loop = true,
		frames = {
			{
				t = 0,
				j = {
					lHip = { -12, 0, 0 },
					lKnee = { -25, 0, 0 },
					rHip = { -6, 0, 0 },
					rKnee = { -18, 0, 0 },
					lShoulder = { 12, 0, -14 },
					rShoulder = { 12, 0, 14 },
				},
				offset = Vector3.new(0, 0, 0),
			},
			{
				t = 1.2,
				j = {
					lHip = { -8, 0, 0 },
					lKnee = { -20, 0, 0 },
					rHip = { -12, 0, 0 },
					rKnee = { -25, 0, 0 },
					lShoulder = { 16, 0, -18 },
					rShoulder = { 16, 0, 18 },
				},
				offset = Vector3.new(0, 0.35, 0),
			},
			{
				t = 2.4,
				j = {
					lHip = { -12, 0, 0 },
					lKnee = { -25, 0, 0 },
					rHip = { -6, 0, 0 },
					rKnee = { -18, 0, 0 },
					lShoulder = { 12, 0, -14 },
					rShoulder = { 12, 0, 14 },
				},
				offset = Vector3.new(0, 0, 0),
			},
		},
	},
} :: { [string]: Pose }

-- The pose played for each public cause of death.
Poses.FOR_CAUSE = {
	["Heart attack"] = "collapseHeart",
	["Traffic accident"] = "collapseTraffic",
	["Sudden illness"] = "collapseIllness",
	["Accidental fall"] = "collapseFall",
} :: { [string]: string }

-- How long a pose runs before looping or holding.
function Poses.length(pose: Pose): number
	local frames = pose.frames
	return frames[#frames].t
end

local jointCache: { [Pose]: { string } } = setmetatable({}, { __mode = "k" }) :: any

-- Every joint the pose touches.
function Poses.joints(pose: Pose): { string }
	local cached = jointCache[pose]
	if cached then
		return cached
	end
	local seen = {}
	local list = {}
	for _, frame in ipairs(pose.frames) do
		for joint in pairs(frame.j) do
			if not seen[joint] then
				seen[joint] = true
				table.insert(list, joint)
			end
		end
	end
	table.sort(list)
	jointCache[pose] = list
	return list
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- The joint angles (degrees) and body offset at `time` seconds into the pose.
function Poses.sample(pose: Pose, time: number): ({ [string]: Angles }, Vector3)
	local frames = pose.frames
	local length = Poses.length(pose)
	local t = time
	if pose.loop and length > 0 then
		t = time % length
	else
		t = math.clamp(time, 0, length)
	end
	local a, b = frames[1], frames[1]
	for index = 1, #frames do
		if frames[index].t <= t then
			a = frames[index]
			b = frames[math.min(index + 1, #frames)]
		end
	end
	local span = b.t - a.t
	local alpha = if span > 0 then smooth(math.clamp((t - a.t) / span, 0, 1)) else 0
	local result: { [string]: Angles } = {}
	for _, joint in ipairs(Poses.joints(pose)) do
		local from = a.j[joint] or { 0, 0, 0 }
		local to = b.j[joint] or { 0, 0, 0 }
		result[joint] = {
			from[1] + (to[1] - from[1]) * alpha,
			from[2] + (to[2] - from[2]) * alpha,
			from[3] + (to[3] - from[3]) * alpha,
		}
	end
	local fromOffset = a.offset or Vector3.zero
	local toOffset = b.offset or Vector3.zero
	return result, fromOffset:Lerp(toOffset, alpha)
end

-- Checks that every pose names only known joints and has frames in time order.
function Poses.validate(): { string }
	local problems = {}
	for id, pose in pairs(Poses.LIST) do
		if #pose.frames == 0 then
			table.insert(problems, id .. ": no frames")
		end
		local last = -1
		for _, frame in ipairs(pose.frames) do
			if frame.t < last then
				table.insert(problems, id .. ": frames out of order")
			end
			last = frame.t
			for joint in pairs(frame.j) do
				if not Joints.R15[joint] then
					table.insert(problems, id .. ": unknown joint " .. joint)
				end
			end
		end
	end
	return problems
end

return Poses
