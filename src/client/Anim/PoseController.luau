-- Animates every R6 character on this client, from public events only, by writing each
-- joint's Transform every frame (Motor6D or AnimationConstraint; it never replicates):
--   1. a base layer from the locomotion controller (idle, walk, run, jump, fall), then
--   2. clip tracks on top (actions, deaths, emotes), each blended in and out by weight.
-- Clips come from Blender (Anim/Clips.luau). A clip with an uploaded animation id in
-- Assets.anim plays that animation instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local Assets = require(Shared:WaitForChild("Assets"))
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Joints = require(Anim:WaitForChild("Joints"))

local PoseController = {}

export type Options = {
	duration: number?, -- stop after this many seconds (runs until stopped otherwise)
	fadeIn: number?,
	fadeOut: number?,
	startAt: number?, -- os.clock() time the clip counts from (to sync with a cue)
	speed: number?,
	emote: boolean?, -- emotes stop when the character moves
}

type Track = {
	id: string,
	clip: ClipPlayer.Prepared?,
	animTrack: AnimationTrack?,
	started: number,
	fadeIn: number,
	fadeOut: number,
	stopAt: number?,
	speed: number,
	emote: boolean,
}

export type Rig = {
	character: Model,
	humanoid: Humanoid,
	motors: { [string]: Joints.Instance6D },
	basis: { [string]: CFrame },
	tracks: { Track },
	baked: boolean,
	-- Posed once every `every` frames (far-off bodies of the Tokyo crowd); nil: every frame.
	every: number?,
	turn: number?,
	owed: number?,
}

-- provider(character, dt) -> (rotations by joint, body offset) or nil to leave the base alone.
type BaseProvider = (Model, number) -> ({ [string]: CFrame }?, Vector3?)

local rigs: { [Model]: Rig } = {}
local baseProvider: BaseProvider? = nil
local IDENTITY = CFrame.identity
local scratch: { [string]: CFrame } = {}

local function rotation(cf: CFrame): CFrame
	return cf - cf.Position
end

-- Fewer joints than this and the body is still being assembled (or is not R6).
local MIN_JOINTS = Joints.COUNT

local function refresh(rig: Rig)
	local motors = Joints.find(rig.character)
	local basis = {}
	for name, motor in pairs(motors) do
		basis[name] = rotation(Joints.c0(motor))
	end
	rig.motors = motors
	rig.basis = basis
end

-- The rig for a character (built once), or nil while it has no R6 joints.
function PoseController.bind(character: Model?): Rig?
	if not character then
		return nil
	end
	local existing = rigs[character]
	if existing then
		return existing
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return nil
	end
	local motors = Joints.find(character)
	local count = 0
	for _ in pairs(motors) do
		count += 1
	end
	if count < MIN_JOINTS or not motors.root then
		return nil
	end
	local rig: Rig = {
		character = character,
		humanoid = humanoid,
		motors = motors,
		basis = {},
		tracks = {},
		baked = false,
	}
	refresh(rig)
	rigs[character] = rig
	-- Joints that arrive (or are replaced) later join the rig.
	local connection = character.DescendantAdded:Connect(function(item)
		if (item:IsA("Motor6D") or item:IsA("AnimationConstraint")) and rigs[character] == rig then
			task.defer(refresh, rig)
		end
	end)
	character.Destroying:Once(function()
		connection:Disconnect()
		rigs[character] = nil
	end)
	return rig
end

-- Waits (up to `timeout` seconds) for the character's joints, then binds it.
function PoseController.bindWhenReady(character: Model, timeout: number?): Rig?
	local deadline = os.clock() + (timeout or 6)
	repeat
		local rig = PoseController.bind(character)
		if rig or not character.Parent then
			return rig
		end
		task.wait(0.1)
	until os.clock() > deadline
	return nil
end

function PoseController.setBaseProvider(provider: BaseProvider)
	baseProvider = provider
end

-- Poses a body only once every `every` frames (1: every frame). For bodies too far off for anyone to
-- tell: the Tokyo crowd's distant walkers.
function PoseController.setEvery(character: Model, every: number)
	local rig = rigs[character]
	if rig then
		rig.every = if every > 1 then math.floor(every) else nil
	end
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

function PoseController.exists(id: string): boolean
	return ClipPlayer.exists(id)
end

-- Starts a clip (replacing the same clip if it is already playing).
function PoseController.play(character: Model?, id: string, options: Options?)
	local rig = PoseController.bind(character)
	if not rig or rig.baked then
		return
	end
	local clip = ClipPlayer.get(id)
	if not clip then
		return
	end
	PoseController.stop(character, id, 0)
	local now = os.clock()
	local track: Track = {
		id = id,
		clip = clip,
		started = if options and options.startAt then options.startAt else now,
		fadeIn = if options and options.fadeIn then options.fadeIn else 0.2,
		fadeOut = if options and options.fadeOut then options.fadeOut else 0.3,
		stopAt = if options and options.duration then now + options.duration else nil,
		speed = if options and options.speed then options.speed else 1,
		emote = options ~= nil and options.emote == true,
	}
	local animTrack = animationFor(rig.character, id)
	if animTrack then
		track.clip = nil
		track.animTrack = animTrack
		animTrack.Priority = Enum.AnimationPriority.Action
		animTrack.Looped = clip.loop
		animTrack:Play(track.fadeIn)
	end
	table.insert(rig.tracks, track)
end

-- Stops a clip (all clips when id is nil).
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

-- Stops every emote on a character (it started moving).
function PoseController.stopEmotes(character: Model?)
	local rig = if character then rigs[character] else nil
	if not rig then
		return
	end
	for _, track in ipairs(rig.tracks) do
		if track.emote and not track.stopAt then
			if track.animTrack then
				track.animTrack:Stop(0.25)
				track.stopAt = os.clock()
				track.fadeOut = 0
			else
				track.stopAt = os.clock()
				track.fadeOut = 0.25
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
		if track.id == id and not track.stopAt then
			return true
		end
	end
	return false
end

-- True while any clip is playing on the character (and has not been told to stop).
function PoseController.busy(character: Model?): boolean
	local rig = if character then rigs[character] else nil
	if not rig then
		return false
	end
	for _, track in ipairs(rig.tracks) do
		if not track.stopAt then
			return true
		end
	end
	return false
end

function PoseController.hasEmote(character: Model?): boolean
	local rig = if character then rigs[character] else nil
	if not rig then
		return false
	end
	for _, track in ipairs(rig.tracks) do
		if track.emote and not track.stopAt then
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

local function apply(rig: Rig, joint: string, target: CFrame, w: number)
	local motor = rig.motors[joint]
	if not motor then
		return
	end
	motor.Transform = if w >= 1 then target else motor.Transform:Lerp(target, w)
end

-- Once the server has locked a pose into the joints (a death), this client stops posing.
local function bake(rig: Rig)
	rig.baked = true
	rig.tracks = {}
	for _, motor in pairs(rig.motors) do
		motor.Transform = IDENTITY
	end
end

local function playTrack(rig: Rig, track: Track, now: number)
	local w = weight(track, now)
	if w <= 0 then
		return
	end
	local elapsed = math.max(0, now - track.started) * track.speed
	local clip = track.clip
	if clip then
		table.clear(scratch)
		local rotations, offset = ClipPlayer.sample(clip, elapsed, scratch)
		for joint, rot in pairs(rotations) do
			local basis = rig.basis[joint]
			if basis then
				apply(rig, joint, ClipPlayer.transform(basis, rot, if joint == "root" then offset else nil), w)
			end
		end
		if offset and not rotations.root and rig.basis.root then
			local motor = rig.motors.root
			local shifted = CFrame.new(rig.basis.root:Inverse() * offset) * rotation(motor.Transform)
			apply(rig, "root", shifted, w)
		end
		return
	end
end

local function step(dt: number)
	local now = os.clock()
	for character, rig in pairs(rigs) do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		if rig.baked then
			continue
		end
		if character:GetAttribute("LPoseBaked") then
			bake(rig)
			continue
		end
		local every = rig.every
		if every then
			rig.owed = (rig.owed or 0) + dt
			rig.turn = ((rig.turn or 0) + 1) % every
			if rig.turn ~= 0 then
				continue
			end
		end
		local elapsed = if every then rig.owed or dt else dt
		rig.owed = 0
		-- Finished tracks leave.
		for index = #rig.tracks, 1, -1 do
			local track = rig.tracks[index]
			if track.stopAt ~= nil and now >= track.stopAt + track.fadeOut then
				if track.animTrack then
					track.animTrack:Stop(track.fadeOut)
				end
				table.remove(rig.tracks, index)
			end
		end
		-- 1. base layer (skipped while an uploaded animation plays, so the Animator drives it)
		local uploaded = false
		for _, track in ipairs(rig.tracks) do
			if track.animTrack then
				uploaded = true
			end
		end
		if baseProvider and not uploaded then
			local rotations, offset = baseProvider(character, elapsed)
			if rotations then
				for joint, motor in pairs(rig.motors) do
					local basis = rig.basis[joint]
					motor.Transform = ClipPlayer.transform(
						basis,
						rotations[joint] or IDENTITY,
						if joint == "root" then offset else nil
					)
				end
			end
		end
		-- 2. clip tracks on top
		for _, track in ipairs(rig.tracks) do
			playTrack(rig, track, now)
		end
	end
end

function PoseController.init()
	RunService.PreSimulation:Connect(step)
end

return PoseController
