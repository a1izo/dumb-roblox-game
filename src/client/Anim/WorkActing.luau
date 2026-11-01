-- A body working a case-file station (ActingController plays it while the server marks the character
-- LWorking). The station type's Blender clip (workCamera, workFingerprint, workPhone, workForensics) is
-- the hands' work underneath; on top of it the body acts in beats that never come round the same way
-- twice: it leans in to look closer, sits back and pauses with its hands off the desk, glances across
-- the screens, holds a card up to the light, nods along on the phone. Each beat eases in on a spring
-- that overshoots a little and settles, the clip's own pace slows or stops with it (a pause is a pause),
-- and under everything the body breathes and the head drifts. Joint angles follow Shared/Anim/Joints:
-- x pitch (neck and root: - leans forward), y twist (+ left), z roll. A root pitch or twist is taken back
-- at the hips so the legs stay standing.
--
-- It reads only what everyone sees (the station type), so a hack is acted exactly as a case file.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClipPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("ClipPlayer"))

local WorkActing = {}

type Pose = { [string]: Vector3 } -- degrees, added to the clip's own pose
type Beat = { pose: Pose, rate: number, time: { number }, nod: number? }

local V = Vector3.new

-- Per type: the beats a working body moves between. `rate` is the clip's pace during the beat,
-- `time` how long it lasts (seconds, min and max), `nod` a slow nod of that many degrees.
local BEATS: { [string]: { Beat } } = {
	Camera = {
		{ pose = {}, rate = 1, time = { 3, 6 } },
		{ pose = { root = V(-5, 0, 0), neck = V(-4, 0, 0) }, rate = 0.8, time = { 2, 4 } },
		{ pose = { root = V(0, 4, 0), neck = V(-2, 10, 0) }, rate = 0.9, time = { 1.5, 3 } },
		{ pose = { root = V(0, -4, 0), neck = V(-2, -10, 0) }, rate = 0.9, time = { 1.5, 3 } },
		{
			pose = { root = V(4, 0, 0), neck = V(4, 0, 0), rShoulder = V(-12, 0, 0), lShoulder = V(-10, 0, 0) },
			rate = 0.1,
			time = { 1.5, 3 },
		},
	},
	Fingerprint = {
		{ pose = {}, rate = 1, time = { 3, 5 } },
		{ pose = { root = V(-6, 0, 0), neck = V(-5, 0, 0) }, rate = 0.7, time = { 2, 3.5 } },
		{ pose = { root = V(-3, 0, 0), neck = V(-6, 0, 6) }, rate = 0.15, time = { 1, 1.8 } },
		{
			pose = { root = V(5, 3, 0), neck = V(7, 6, 0), lShoulder = V(22, 0, 0) },
			rate = 0.1,
			time = { 1.5, 2.5 },
		},
	},
	Phone = {
		{ pose = {}, rate = 1, time = { 3, 5 }, nod = 3 },
		{ pose = { root = V(-3, 0, 0), neck = V(-7, -4, 0) }, rate = 1.25, time = { 2, 4 } },
		{ pose = { root = V(2, 0, 0), neck = V(5, 8, 0) }, rate = 0.3, time = { 1.5, 3 } },
		{ pose = { neck = V(0, -6, -4), rShoulder = V(-8, 0, 0) }, rate = 0.2, time = { 1.5, 2.5 }, nod = 4 },
	},
	Forensics = {
		{ pose = {}, rate = 1, time = { 3, 5 } },
		{ pose = { root = V(-4, 0, 0), neck = V(-4, 0, 0) }, rate = 0.6, time = { 2, 4 } },
		{
			pose = { root = V(6, 0, 0), neck = V(4, 0, 0), rShoulder = V(-14, 0, 0), lShoulder = V(-12, 0, 0) },
			rate = 0.05,
			time = { 1.5, 3 },
		},
		{ pose = { root = V(0, -4, 0), neck = V(-4, -10, 0) }, rate = 0.8, time = { 1.5, 2.5 } },
	},
}

local JOINTS = { "root", "neck", "rShoulder", "lShoulder" }
local OMEGA = 2 * math.pi * 1.1 -- the spring's speed (radians a second)
local DAMPING = 0.68 -- under 1: it overshoots a touch and settles
local STEP = 1 / 60

local function hash(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function angles(d: Vector3): CFrame
	return CFrame.Angles(math.rad(d.X), math.rad(d.Y), math.rad(d.Z))
end

-- Adds a turn to a sampled joint (its rotation only: the joint's slide stays where the clip put it).
local function turn(cf: CFrame?, d: Vector3): CFrame
	local base = cf or CFrame.identity
	return CFrame.new(base.Position) * angles(d) * base.Rotation
end

-- The sampler for PoseController.playProcedural. `seed` picks this body's beats (any number).
function WorkActing.sampler(kind: string, seed: number)
	local clip = ClipPlayer.get("work" .. kind) or ClipPlayer.get("workCamera")
	local beats = BEATS[kind] or BEATS.Camera
	local value: { [string]: Vector3 } = {}
	local speed: { [string]: Vector3 } = {}
	for _, joint in ipairs(JOINTS) do
		value[joint] = Vector3.zero
		speed[joint] = Vector3.zero
	end
	local rate, rateSpeed = 1, 0
	local clipTime = hash(seed, 0.5) * 3
	local last = 0
	local count = 0
	local index = 1
	local endsAt = 0.8 + hash(seed, 0.9) * 1.5 -- it settles into the work first
	local out: { [string]: CFrame } = {}

	return function(elapsed: number)
		local dt = math.clamp(elapsed - last, 0, 0.1)
		last = elapsed
		if elapsed >= endsAt then
			count += 1
			-- never the same beat twice running; the plain work comes back often
			local nextIndex = if hash(seed, count) < 0.35 then 1 else 1 + math.floor(hash(seed, count + 0.5) * #beats)
			if nextIndex == index then
				nextIndex = index % #beats + 1
			end
			index = nextIndex
			local span = beats[index].time
			endsAt = elapsed + span[1] + hash(seed, count + 0.25) * (span[2] - span[1])
		end
		local beat = beats[index]
		-- the springs, stepped finely enough to stay steady at any frame rate
		local left = dt
		while left > 1e-4 do
			local h = math.min(left, STEP)
			left -= h
			for _, joint in ipairs(JOINTS) do
				local target = beat.pose[joint] or Vector3.zero
				local accel = (target - value[joint]) * OMEGA * OMEGA - speed[joint] * 2 * DAMPING * OMEGA
				speed[joint] += accel * h
				value[joint] += speed[joint] * h
			end
			rateSpeed += ((beat.rate - rate) * OMEGA * OMEGA - rateSpeed * 2 * OMEGA) * h
			rate += rateSpeed * h
		end
		clipTime += dt * math.max(rate, 0)
		table.clear(out)
		local offset: Vector3? = nil
		if clip then
			offset = select(2, ClipPlayer.sample(clip, clipTime, out))
		end
		-- breathing, a slow drift of the head, and a nod where the beat has one
		local breath = math.sin(elapsed * 1.7) * 0.7
		local drift = V(
			math.noise(elapsed * 0.3, seed % 61) * 2.5,
			math.noise(elapsed * 0.25, seed % 61 + 10) * 4,
			math.noise(elapsed * 0.2, seed % 61 + 20) * 2
		)
		local nod = if beat.nod then math.sin(elapsed * 2.2) * beat.nod * 0.5 else 0
		local root = value.root + V(breath, 0, 0)
		out.root = turn(out.root, root)
		out.neck = turn(out.neck, value.neck + drift + V(nod - breath * 0.5, 0, 0))
		out.rShoulder = turn(out.rShoulder, value.rShoulder + V(breath * 0.4, 0, 0))
		out.lShoulder = turn(out.lShoulder, value.lShoulder + V(breath * 0.4, 0, 0))
		local back = V(-root.X, -root.Y, 0)
		out.rHip = turn(out.rHip, back)
		out.lHip = turn(out.lHip, back)
		return out, offset
	end
end

-- This player's own body, as the work starts: it steps up to the station if it stood back from it,
-- then turns square to it, so the hands work on the desk and not in the air. (Only the body's owner
-- can move it; everyone else sees it through replication. A hack starts the same way.)
local REACH = 1.7 -- studs between the station's front and the body's middle
local FAR = 1.2 -- closer than this to that spot already: no step

function WorkActing.face(character: Model, at: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid) then
		return
	end
	local flat = Vector3.new(at.X, root.Position.Y, at.Z)
	local toward = flat - root.Position
	if toward.Magnitude < 0.2 then
		return
	end
	-- Where the station's front is, from here: the first part of the station a ray at the desk's height hits.
	local station: Instance? = nil
	for _, desk in ipairs(CollectionService:GetTagged("LStation")) do
		if desk:IsA("BasePart") and (desk.Position - at).Magnitude < 0.5 then
			station = desk.Parent
		end
	end
	local hit = nil
	if station then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { station }
		local from = Vector3.new(root.Position.X, at.Y, root.Position.Z)
		hit = workspace:Raycast(from, Vector3.new(toward.X, 0, toward.Z), params)
	end
	local front = if hit then Vector3.new(hit.Position.X, root.Position.Y, hit.Position.Z) else flat
	local stand = front - toward.Unit * REACH
	local gap = (stand - root.Position) * Vector3.new(1, 0, 1)
	task.spawn(function()
		if hit and gap.Magnitude > FAR and gap:Dot(toward) > 0 then
			humanoid:MoveTo(Vector3.new(stand.X, root.Position.Y, stand.Z))
			local done = false
			local connection = humanoid.MoveToFinished:Once(function()
				done = true
			end)
			local started = os.clock()
			while not done and os.clock() - started < 1.2 and character:GetAttribute("LWorking") do
				task.wait()
			end
			connection:Disconnect()
		end
		if not character:GetAttribute("LWorking") or humanoid.MoveDirection.Magnitude > 0.1 then
			return
		end
		-- the turn, eased over a third of a second (AutoRotate held off so it is not undone mid-way)
		local from = root.CFrame
		local look = Vector3.new(at.X, from.Position.Y, at.Z) - from.Position
		if look.Magnitude < 0.2 then
			return
		end
		local goal = CFrame.lookAt(from.Position, from.Position + look)
		local auto = humanoid.AutoRotate
		humanoid.AutoRotate = false
		local started = os.clock()
		while os.clock() - started < 0.35 and humanoid.MoveDirection.Magnitude < 0.1 do
			local u = (os.clock() - started) / 0.35
			u = u * u * (3 - 2 * u)
			root.CFrame = from.Rotation:Lerp(goal.Rotation, u) + root.Position
			task.wait()
		end
		humanoid.AutoRotate = auto
	end)
end

return WorkActing
