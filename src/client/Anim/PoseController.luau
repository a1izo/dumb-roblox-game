-- Animates every R6 character on this client, from public events only, by writing each
-- joint's Transform every frame (Motor6D or AnimationConstraint; it never replicates):
--   1. a base layer from the locomotion controller (standing, walking, running, the air), then
--   2. clip tracks on top (actions, deaths, emotes), each blended in and out by weight, then
--   3. an after-pass from the locomotion controller that keeps a standing body's soles planted under
--      whatever the layers above did to it, then
--   4. while a clip that moves the legs fades in or out, the body lifted off the floor wherever the blend of
--      two poses would put a leg through it.
-- Clips come from Blender (Anim/Clips). A clip with an uploaded animation id in
-- Assets.anim plays that animation instead. A track can also be procedural (playProcedural): a function
-- that gives the joints' rotations each frame, like a clip's sample (the rift dive's tumble, Anim/Tumble).

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
	phase: number?, -- seconds into the clip it starts at (looping emotes start on a shared beat)
	speed: number?,
	emote: boolean?, -- emotes stop when the character moves
	-- "upper": only the waist up (the legs, the body's height and its hops stay with the base layer, so a body
	-- standing at a meeting's seat keeps its feet where they are)
	mask: string?,
	-- called once when the track leaves, with why: "finished", "stopped", "moved", "replaced", "baked", "gone"
	onEnd: ((reason: string) -> ())?,
}

-- What play() hands back: stops that one track (and only it).
export type Handle = {
	stop: (fadeOut: number?, reason: string?) -> (),
	playing: () -> boolean,
}

-- A procedural track's source: the joints' rotations (and a body offset) `elapsed` seconds in.
export type Sampler = (elapsed: number) -> ({ [string]: CFrame }, Vector3?)

type Track = {
	id: string,
	clip: ClipPlayer.Prepared?,
	sampler: Sampler?,
	animTrack: AnimationTrack?,
	started: number,
	fadeIn: number,
	fadeOut: number,
	stopAt: number?,
	speed: number,
	phase: number,
	emote: boolean,
	mask: string?,
	onEnd: ((reason: string) -> ())?,
	why: string?, -- why it was told to stop (passed to onEnd when it leaves)
}

export type Rig = {
	character: Model,
	humanoid: Humanoid,
	motors: { [string]: Joints.Instance6D },
	basis: { [string]: CFrame },
	inverse: { [string]: CFrame }, -- each basis inverted, worked out with it
	c0: { [string]: CFrame }, -- each joint's C0 and C1, for the after-pass (LocomotionController's feet)
	c1: { [string]: CFrame },
	watch: RBXScriptConnection?, -- joints added later refresh the rig
	gone: RBXScriptConnection?, -- the body is destroyed
	tracks: { Track },
	-- How much of this frame's pose comes from clips that move the legs (dances, actions): the after-pass
	-- leaves the legs to them that much.
	legsTaken: number,
	-- A clip that moves the legs is fading in or out this frame (the floor guard looks at the legs then).
	legsBlending: boolean,
	baked: boolean,
	-- Posed once every `every` frames (far-off bodies); nil: every frame. Between, the joints are given the
	-- pose of the last posed frame again (`held`): an Animator puts them back to rest each frame otherwise.
	every: number?,
	held: { [string]: CFrame }?,
	turn: number?,
	owed: number?,
}

-- provider(character, dt) -> (rotations by joint, body offset) or nil to leave the base alone.
type BaseProvider = (Model, number) -> ({ [string]: CFrame }?, Vector3?)
-- after(rig, dt): once every layer is on, may adjust the joints (LocomotionController plants the feet).
type AfterPass = (Rig, number) -> ()

local rigs: { [Model]: Rig } = {}
local baseProvider: BaseProvider? = nil
local afterPass: AfterPass? = nil
-- What posing costs this client (for the debug panel's performance stats and the test harness).
local cost = { rigs = 0, posed = 0, last = 0, average = 0 }
local IDENTITY = CFrame.identity
local scratch: { [string]: CFrame } = {}

local function rotation(cf: CFrame): CFrame
	return cf - cf.Position
end

-- A track has left the body: tell whoever started it (once, and never from inside the frame's loop).
local function ended(track: Track, reason: string)
	local onEnd = track.onEnd
	if onEnd then
		track.onEnd = nil
		task.spawn(onEnd, track.why or reason)
	end
end

-- Fewer joints than this and the body is still being assembled (or is not R6).
local MIN_JOINTS = Joints.COUNT

local function refresh(rig: Rig)
	local motors = Joints.find(rig.character)
	local basis, inverse, c0s, c1s = {}, {}, {}, {}
	for name, motor in pairs(motors) do
		local c0 = Joints.c0(motor)
		basis[name] = rotation(c0)
		inverse[name] = basis[name]:Inverse()
		c0s[name] = c0
		c1s[name] = Joints.c1(motor)
	end
	rig.motors = motors
	rig.basis = basis
	rig.inverse = inverse
	rig.c0 = c0s
	rig.c1 = c1s
end

-- Forgets a rig (its body was destroyed, or left the world: a crowd walker that is no longer drawn
-- is bound again when it comes back).
local function unbind(character: Model)
	local rig = rigs[character]
	if rig then
		if rig.watch then
			rig.watch:Disconnect()
		end
		if rig.gone then
			rig.gone:Disconnect()
		end
		rig.watch, rig.gone = nil, nil
		for _, track in ipairs(rig.tracks) do
			ended(track, "gone")
		end
	end
	rigs[character] = nil
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
		inverse = {},
		c0 = {},
		c1 = {},
		tracks = {},
		legsTaken = 0,
		legsBlending = false,
		baked = false,
	}
	refresh(rig)
	rigs[character] = rig
	-- Joints that arrive (or are replaced) later join the rig.
	rig.watch = character.DescendantAdded:Connect(function(item)
		if (item:IsA("Motor6D") or item:IsA("AnimationConstraint")) and rigs[character] == rig then
			task.defer(refresh, rig)
		end
	end)
	rig.gone = character.Destroying:Once(function()
		if rigs[character] == rig then
			unbind(character)
		end
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

function PoseController.setAfterPass(pass: AfterPass)
	afterPass = pass
end

-- How many bodies are bound, how many were posed last frame, and what posing them took (milliseconds: the
-- last frame, and an average over the last second or so).
function PoseController.stats(): { rigs: number, posed: number, last: number, average: number }
	return table.clone(cost)
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

local function running(track: Track, now: number): boolean
	return track.stopAt == nil or track.stopAt > now
end

-- Tells one track to stop (fading over `fade` seconds, at once when 0), remembering why.
local function stopTrack(rig: Rig, track: Track, fade: number, why: string)
	local now = os.clock()
	if not running(track, now) and fade > 0 then
		return
	end
	track.why = track.why or why
	if track.animTrack then
		track.animTrack:Stop(fade)
		local index = table.find(rig.tracks, track)
		if index then
			table.remove(rig.tracks, index)
		end
		ended(track, why)
	elseif fade <= 0 then
		local index = table.find(rig.tracks, track)
		if index then
			table.remove(rig.tracks, index)
		end
		ended(track, why)
	else
		track.fadeOut = fade
		track.stopAt = math.min(track.stopAt or math.huge, now)
	end
end

local function handleFor(rig: Rig, track: Track): Handle
	return {
		stop = function(fadeOut: number?, reason: string?)
			if table.find(rig.tracks, track) then
				stopTrack(rig, track, fadeOut or track.fadeOut, reason or "stopped")
			end
		end,
		playing = function(): boolean
			return table.find(rig.tracks, track) ~= nil and running(track, os.clock())
		end,
	}
end

-- Starts a clip (replacing the same clip if it is already playing). Returns a handle on the new track.
function PoseController.play(character: Model?, id: string, options: Options?): Handle?
	local rig = PoseController.bind(character)
	if not rig or rig.baked then
		return nil
	end
	local clip = ClipPlayer.get(id)
	if not clip then
		return nil
	end
	PoseController.stop(character, id, 0, "replaced")
	local now = os.clock()
	local track: Track = {
		id = id,
		clip = clip,
		started = if options and options.startAt then options.startAt else now,
		fadeIn = if options and options.fadeIn then options.fadeIn else 0.2,
		fadeOut = if options and options.fadeOut then options.fadeOut else 0.3,
		stopAt = if options and options.duration then now + options.duration else nil,
		speed = if options and options.speed then options.speed else 1,
		phase = if options and options.phase then options.phase else 0,
		emote = options ~= nil and options.emote == true,
		mask = if options then options.mask else nil,
		onEnd = if options then options.onEnd else nil,
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
	return handleFor(rig, track)
end

-- Starts a procedural track (replacing a track of the same id): `sampler` is asked for the pose every frame
-- the body is posed, and is blended in and out like a clip.
function PoseController.playProcedural(character: Model?, id: string, sampler: Sampler, options: Options?)
	local rig = PoseController.bind(character)
	if not rig or rig.baked then
		return
	end
	PoseController.stop(character, id, 0, "replaced")
	local now = os.clock()
	table.insert(rig.tracks, {
		id = id,
		sampler = sampler,
		started = now,
		fadeIn = if options and options.fadeIn then options.fadeIn else 0.2,
		fadeOut = if options and options.fadeOut then options.fadeOut else 0.3,
		stopAt = if options and options.duration then now + options.duration else nil,
		speed = 1,
		phase = 0,
		emote = false,
		onEnd = if options then options.onEnd else nil,
	})
end

-- Stops a clip (all clips when id is nil). `reason` reaches the tracks' onEnd ("stopped" by default).
function PoseController.stop(character: Model?, id: string?, fadeOut: number?, reason: string?)
	local rig = if character then rigs[character] else nil
	if not rig then
		return
	end
	for index = #rig.tracks, 1, -1 do
		local track = rig.tracks[index]
		if id == nil or track.id == id then
			stopTrack(rig, track, fadeOut or track.fadeOut, reason or "stopped")
		end
	end
end

-- Stops every emote on a character (it started moving, by default: the reason its onEnd hears).
function PoseController.stopEmotes(character: Model?, reason: string?)
	local rig = if character then rigs[character] else nil
	if not rig then
		return
	end
	for _, track in ipairs(table.clone(rig.tracks)) do
		if track.emote then
			stopTrack(rig, track, 0.3, reason or "moved")
		end
	end
end

function PoseController.isPlaying(character: Model?, id: string): boolean
	local rig = if character then rigs[character] else nil
	if not rig then
		return false
	end
	for _, track in ipairs(rig.tracks) do
		if track.id == id and running(track, os.clock()) then
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
		if running(track, os.clock()) then
			return true
		end
	end
	return false
end

-- Eased in and out (smoothstep): a pose leaves and arrives slowly at both ends of the blend, never with a
-- corner where the fade starts or stops.
local function ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function weight(track: Track, now: number): number
	local w = 1
	if track.fadeIn > 0 then
		w = ease((now - track.started) / track.fadeIn)
	end
	if track.stopAt and now > track.stopAt then
		w *= if track.fadeOut > 0 then 1 - ease((now - track.stopAt) / track.fadeOut) else 0
	end
	return w
end

-- Joints an "upper" track leaves alone (the base layer keeps them).
local LOWER = { rHip = true, lHip = true }

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
	for _, track in ipairs(rig.tracks) do
		ended(track, "baked")
	end
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
	local elapsed = math.max(0, now - track.started) * track.speed + track.phase
	local sampler = track.sampler
	if sampler then
		local rotations, offset = sampler(elapsed)
		if rotations.rHip or rotations.lHip then
			rig.legsTaken = math.max(rig.legsTaken, w)
			rig.legsBlending = rig.legsBlending or w < 1
		end
		for joint, rot in pairs(rotations) do
			local basis = rig.basis[joint]
			if basis then
				apply(
					rig,
					joint,
					ClipPlayer.transform(basis, rot, if joint == "root" then offset else nil, rig.inverse[joint]),
					w
				)
			end
		end
		return
	end
	local clip = track.clip
	if clip then
		local upper = track.mask == "upper"
		if not upper and (clip.joints.rHip or clip.joints.lHip) then
			rig.legsTaken = math.max(rig.legsTaken, w)
			rig.legsBlending = rig.legsBlending or w < 1
		end
		table.clear(scratch)
		local rotations, offset = ClipPlayer.sample(clip, elapsed, scratch)
		if upper then
			-- The waist up only: the legs and the body's height stay with the base layer (the after-pass keeps the
			-- soles planted), and the torso turns half as far, so a body standing at its seat never hops or slides.
			offset = nil
			for joint in pairs(LOWER) do
				rotations[joint] = nil
			end
			local root = rotations.root
			if root then
				rotations.root = IDENTITY:Lerp(root, 0.5)
			end
		end
		for joint, rot in pairs(rotations) do
			local basis = rig.basis[joint]
			if basis then
				local moved = if joint == "root" then offset else nil
				apply(rig, joint, ClipPlayer.transform(basis, rot, moved, rig.inverse[joint]), w)
			end
		end
		if offset and not rotations.root and rig.basis.root then
			local motor = rig.motors.root
			local shifted = CFrame.new(rig.inverse.root * offset) * rotation(motor.Transform)
			apply(rig, "root", shifted, w)
		end
		return
	end
end

-- The floor guard. Each joint blends straight from one pose to the other, so halfway into a crouch the legs
-- are only half swung forward while the body is already half lowered, and the feet go through the floor (and
-- the same on the way out). While that can happen, the body is raised just enough that no corner of a leg is
-- below where the soles stand at rest.
local HIPS = { "rHip", "lHip" }
local CORNERS = {}
for _, x in ipairs({ -1, 1 }) do
	for _, y in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			table.insert(CORNERS, Vector3.new(x, y, z) / 2)
		end
	end
end

local function liftOffFloor(rig: Rig)
	local root = rig.motors.root
	local rootC0, rootC1 = rig.c0.root, rig.c1.root
	local part = rig.character:FindFirstChild("HumanoidRootPart")
	if not root or not rootC0 or not rootC1 or not part or not part:IsA("BasePart") or rig.humanoid.Sit then
		return
	end
	-- (in the root part's frame, which stands upright: R6 legs stand on the floor, half the root plus a leg
	-- below its middle)
	local torso = rootC0 * root.Transform * rootC1:Inverse()
	local floor = math.huge
	local lowest = math.huge
	for _, joint in ipairs(HIPS) do
		local motor = rig.motors[joint]
		local c0, c1 = rig.c0[joint], rig.c1[joint]
		local leg = motor and Joints.child(motor)
		if leg and c0 and c1 then
			floor = math.min(floor, -(rig.humanoid.HipHeight + part.Size.Y / 2 + leg.Size.Y))
			local at = torso * c0 * motor.Transform * c1:Inverse()
			for _, corner in ipairs(CORNERS) do
				lowest = math.min(lowest, (at * (corner * leg.Size)).Y)
			end
		end
	end
	local short = floor - lowest
	if floor < math.huge and short > 0.001 then
		root.Transform = rootC0:Inverse() * CFrame.new(0, short, 0) * rootC0 * root.Transform
	end
end

local function step(dt: number)
	local now = os.clock()
	local bound, posed = 0, 0
	for character, rig in pairs(rigs) do
		bound += 1
		if not character.Parent then
			unbind(character)
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
				local held = rig.held
				if held then
					for joint, motor in pairs(rig.motors) do
						local pose = held[joint]
						if pose then
							motor.Transform = pose
						end
					end
				end
				continue
			end
		end
		local elapsed = if every then rig.owed or dt else dt
		rig.owed = 0
		posed += 1
		-- Finished tracks leave.
		for index = #rig.tracks, 1, -1 do
			local track = rig.tracks[index]
			if track.stopAt ~= nil and now >= track.stopAt + track.fadeOut then
				if track.animTrack then
					track.animTrack:Stop(track.fadeOut)
				end
				table.remove(rig.tracks, index)
				ended(track, "finished")
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
					motor.Transform = ClipPlayer.transform(
						rig.basis[joint],
						rotations[joint] or IDENTITY,
						if joint == "root" then offset else nil,
						rig.inverse[joint]
					)
				end
			end
		end
		-- 2. clip tracks on top
		rig.legsTaken = 0
		rig.legsBlending = false
		for _, track in ipairs(rig.tracks) do
			playTrack(rig, track, now)
		end
		-- 3. the after-pass (planted feet), once everything above has moved the body
		if afterPass and not uploaded then
			afterPass(rig, elapsed)
		end
		-- 4. the floor guard, while a leg clip blends
		if rig.legsBlending and not uploaded then
			liftOffFloor(rig)
		end
		if every and not uploaded then
			local held = rig.held or {}
			for joint, motor in pairs(rig.motors) do
				held[joint] = motor.Transform
			end
			rig.held = held
		end
	end
	local spent = (os.clock() - now) * 1000
	cost.rigs, cost.posed, cost.last = bound, posed, spent
	cost.average += (spent - cost.average) * math.min(1, dt * 2)
end

function PoseController.init()
	RunService.PreSimulation:Connect(step)
end

return PoseController
