-- Plays poses on any R15 character, on this client only. Every client plays the same poses
-- from the same public events, so everyone sees the same thing without anything being sent.
--
-- Procedural poses write Motor6D.Transform right after the Animator each frame, blending
-- from the walk underneath, and only on the joints the pose names. A pose with an uploaded
-- animation in Assets.anim plays that animation instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Joints = require(Shared:WaitForChild("Anim"):WaitForChild("Joints"))
local Poses = require(Shared:WaitForChild("Anim"):WaitForChild("Poses"))

local PoseController = {}

export type Options = {
	duration: number?, -- stop after this many seconds (runs until stopped otherwise)
	fadeIn: number?,
	fadeOut: number?,
	startAt: number?, -- os.clock() time the pose counts from (to sync with a cue)
}

type Track = {
	id: string,
	pose: Poses.Pose?,
	animTrack: AnimationTrack?,
	started: number,
	fadeIn: number,
	fadeOut: number,
	stopAt: number?,
}

type Rig = {
	character: Model,
	motors: { [string]: Motor6D },
	basis: { [string]: CFrame },
	tracks: { Track },
}

local rigs: { [Model]: Rig } = {}

local function rotation(cf: CFrame): CFrame
	return cf - cf.Position
end

local function bind(character: Model): Rig?
	local existing = rigs[character]
	if existing then
		return existing
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local motors = Joints.find(character)
	if not motors.waist then
		return nil
	end
	local basis = {}
	for name, motor in pairs(motors) do
		basis[name] = rotation(motor.C0)
	end
	local rig: Rig = { character = character, motors = motors, basis = basis, tracks = {} }
	rigs[character] = rig
	character.Destroying:Once(function()
		rigs[character] = nil
	end)
	return rig
end

local function animationFor(character: Model, id: string): AnimationTrack?
	local assetId = Assets.anim[id]
	if not assetId or assetId == "" then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not animator then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = Assets.contentId(assetId)
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	return if ok then track else nil
end

-- Starts a pose (replacing the same pose if it is already playing).
function PoseController.play(character: Model?, id: string, options: Options?)
	if not character then
		return
	end
	local pose = Poses.LIST[id]
	if not pose then
		return
	end
	local rig = bind(character)
	if not rig then
		return
	end
	PoseController.stop(character, id, 0)
	local now = os.clock()
	local track: Track = {
		id = id,
		pose = pose,
		started = if options and options.startAt then options.startAt else now,
		fadeIn = if options and options.fadeIn then options.fadeIn else 0.2,
		fadeOut = if options and options.fadeOut then options.fadeOut else 0.3,
		stopAt = if options and options.duration then now + options.duration else nil,
	}
	local animTrack = animationFor(character, id)
	if animTrack then
		track.pose = nil
		track.animTrack = animTrack
		animTrack.Priority = Enum.AnimationPriority.Action
		animTrack.Looped = pose.loop == true
		animTrack:Play(track.fadeIn)
	end
	table.insert(rig.tracks, track)
end

-- Stops a pose (all poses when id is nil).
function PoseController.stop(character: Model?, id: string?, fadeOut: number?)
	local rig = if character then rigs[character] else nil
	if not rig then
		return
	end
	local now = os.clock()
	for index = #rig.tracks, 1, -1 do
		local track = rig.tracks[index]
		if id == nil or track.id == id then
			local fade = fadeOut or track.fadeOut
			if track.animTrack then
				track.animTrack:Stop(fade)
				table.remove(rig.tracks, index)
			elseif fade <= 0 then
				table.remove(rig.tracks, index)
			else
				track.fadeOut = fade
				track.stopAt = math.min(track.stopAt or math.huge, now)
			end
		end
	end
end

function PoseController.isPlaying(character: Model?, id: string): boolean
	local rig = if character then rigs[character] else nil
	if not rig then
		return false
	end
	for _, track in ipairs(rig.tracks) do
		if track.id == id then
			return true
		end
	end
	return false
end

local function weight(track: Track, now: number): number
	local w = 1
	if track.fadeIn > 0 then
		w = math.clamp((now - track.started) / track.fadeIn, 0, 1)
	end
	if track.stopAt and now > track.stopAt then
		w *= if track.fadeOut > 0 then 1 - math.clamp((now - track.stopAt) / track.fadeOut, 0, 1) else 0
	end
	return w
end

local function step()
	local now = os.clock()
	for character, rig in pairs(rigs) do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		for index = #rig.tracks, 1, -1 do
			local track = rig.tracks[index]
			local finished = track.stopAt ~= nil and now >= track.stopAt + track.fadeOut
			if finished then
				if track.animTrack then
					track.animTrack:Stop(track.fadeOut)
				elseif track.pose then
					-- Hand the joints back; the Animator writes over them again next frame.
					for _, joint in ipairs(Poses.joints(track.pose)) do
						local motor = rig.motors[joint]
						if motor then
							motor.Transform = CFrame.identity
						end
					end
				end
				table.remove(rig.tracks, index)
			end
		end
		for _, track in ipairs(rig.tracks) do
			local pose = track.pose
			if pose then
				local w = weight(track, now)
				if w > 0 then
					local angles, offset = Poses.sample(pose, math.max(0, now - track.started))
					for joint, angle in pairs(angles) do
						local motor = rig.motors[joint]
						local basis = rig.basis[joint]
						if motor and basis then
							local r = CFrame.Angles(math.rad(angle[1]), math.rad(angle[2]), math.rad(angle[3]))
							local target = basis:Inverse() * r * basis
							if joint == "root" then
								target = CFrame.new(basis:Inverse() * offset) * target
							end
							motor.Transform = if w >= 1 then target else motor.Transform:Lerp(target, w)
						end
					end
					if angles.root == nil and offset.Magnitude > 0 then
						local motor = rig.motors.root
						local basis = rig.basis.root
						if motor and basis then
							local shifted = CFrame.new(basis:Inverse() * offset) * motor.Transform
							motor.Transform = motor.Transform:Lerp(shifted, w)
						end
					end
				end
			end
		end
		if #rig.tracks == 0 then
			rigs[character] = nil
		end
	end
end

function PoseController.init()
	RunService.PreSimulation:Connect(step)
end

return PoseController
