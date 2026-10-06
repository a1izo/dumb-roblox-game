-- Movement animation for every R6 character, worked out on each client from what everyone can
-- see (how fast a body moves, whether it is on the ground). Idle, walk and run blend by speed
-- and share one stride phase so the feet never slide between them; jumping and falling take
-- over in the air, and a knee dip plays on landing. Roblox's default Animate script is removed
-- (by the server, and here for this player's own body), so these are the only movement
-- animations. Each time a stride plants a foot, Footfall fires (the snow's footprints use it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Anim = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Joints = require(Anim:WaitForChild("Joints"))

local PoseController = require(script.Parent.PoseController)
local Characters = require(script.Parent.Parent.Characters)
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local LocomotionController = {}

-- Fired with (character) when a walking or running character's foot comes down on the ground.
LocomotionController.Footfall = Signal.new()

-- Speeds (studs/s) where walking starts, where running begins to take over and where only
-- the run plays. Each clip knows its stride (studs per cycle); strides scale with the length
-- of an avatar's legs, so feet stay planted on small and tall bodies alike.
local MOVE_FULL = 1.5
local RUN_FROM, RUN_FULL = 4, 11
local GROUND_CHECK = 0.1
local LAND_AFTER = 0.35 -- seconds in the air before a landing dip plays
local DEFAULT_STRIDES = { walk = 2.4, run = 8.64 } -- until the clips say their own

-- Now and then a standing body fidgets (looks round, checks a watch, straightens a tie).
local FIDGETS = { "idleLook", "idleWatch", "idleTie" }
local FIDGET_EVERY = { 6, 15 }

type State = {
	fidgetAt: number,
	phase: number,
	legScale: number?,
	blendSpeed: number,
	idleTime: number,
	airTime: number,
	airWeight: number,
	grounded: boolean,
	lastCheck: number,
	rising: boolean,
}

local states: { [Model]: State } = {}
local clips: { [string]: ClipPlayer.Prepared } = {}
local buffers = {
	idle = {},
	walk = {},
	run = {},
	stride = {},
	ground = {},
	jump = {},
	fall = {},
	air = {},
	out = {},
}

local IDENTITY = CFrame.new()

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function stateFor(character: Model): State
	local state = states[character]
	if not state then
		state = {
			fidgetAt = os.clock() + FIDGET_EVERY[1] + math.random() * (FIDGET_EVERY[2] - FIDGET_EVERY[1]),
			phase = math.random(),
			blendSpeed = 0,
			idleTime = math.random() * 3,
			airTime = 0,
			airWeight = 0,
			grounded = true,
			lastCheck = 0,
			rising = false,
		}
		states[character] = state
		character.Destroying:Once(function()
			states[character] = nil
		end)
	end
	return state
end

-- How long this avatar's legs are compared with the rig the clips were made on.
local function legLength(character: Model): number
	local leg = character:FindFirstChild("Right Leg")
	return if leg and leg:IsA("BasePart") then leg.Size.Y else 2
end

local function legScale(character: Model, reference: number?): number
	if not reference then
		return 1
	end
	local length = legLength(character)
	return if length > 0.2 then math.clamp(length / reference, 0.4, 3) else 1
end

-- R6 legs are the part that stands on the ground (HipHeight is 0), so the distance from the
-- root to the floor is half the root plus the leg.
local function onGround(character: Model, root: BasePart, humanoid: Humanoid): boolean
	rayParams.FilterDescendantsInstances = { character }
	local reach = humanoid.HipHeight + root.Size.Y / 2 + legLength(character) + 1.2
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), rayParams) ~= nil
end

local function blendInto(out: { [string]: CFrame }, a: { [string]: CFrame }, b: { [string]: CFrame }, w: number)
	for joint, rot in pairs(a) do
		local other = b[joint]
		out[joint] = if other then rot:Lerp(other, w) else rot:Lerp(IDENTITY, w)
	end
	for joint, rot in pairs(b) do
		if not a[joint] then
			out[joint] = IDENTITY:Lerp(rot, w)
		end
	end
end

local function lerpOffset(a: Vector3?, b: Vector3?, w: number): Vector3
	return (a or Vector3.zero):Lerp(b or Vector3.zero, w)
end

-- The base pose for one character this frame.
local function provide(character: Model, dt: number): ({ [string]: CFrame }?, Vector3?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return nil, nil
	end
	local state = stateFor(character)
	local idle, walk, run = clips.idle, clips.walk, clips.run
	state.idleTime += dt

	-- Specters float; only the idle body sits under their float clip.
	if character:GetAttribute("Specter") then
		table.clear(buffers.out)
		local rotations, offset = ClipPlayer.sample(idle, state.idleTime, buffers.out)
		return rotations, offset
	end

	-- Sitting (a Seat, like the lobby's dice table): the seated pose, whatever else is going on.
	if humanoid.Sit and clips.sit then
		table.clear(buffers.out)
		local rotations, offset = ClipPlayer.sample(clips.sit, state.idleTime, buffers.out)
		return rotations, offset
	end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if root.Anchored then
		speed = 0
	end
	local now = os.clock()
	if now - state.lastCheck > GROUND_CHECK then
		state.lastCheck = now
		local grounded = root.Anchored or onGround(character, root, humanoid)
		if grounded and not state.grounded and state.airTime > LAND_AFTER then
			PoseController.play(character, "land", { fadeIn = 0.02, duration = 0.3, fadeOut = 0.2 })
		end
		if not grounded and state.grounded then
			state.rising = velocity.Y > 2
		end
		state.grounded = grounded
	end
	if state.grounded then
		state.airTime = 0
	else
		state.airTime += dt
	end
	state.airWeight = if state.grounded
		then math.max(0, state.airWeight - dt * 10)
		else math.min(1, state.airWeight + dt * 8)

	-- A fidget now and then, when standing still with nothing else to do.
	if speed < 0.3 and state.grounded and os.clock() >= state.fidgetAt then
		state.fidgetAt = os.clock() + FIDGET_EVERY[1] + math.random() * (FIDGET_EVERY[2] - FIDGET_EVERY[1])
		if not PoseController.busy(character) then
			local id = FIDGETS[math.random(#FIDGETS)]
			if ClipPlayer.exists(id) then
				PoseController.play(
					character,
					id,
					{ fadeIn = 0.35, fadeOut = 0.45, duration = ClipPlayer.length(id), emote = true }
				)
			end
		end
	end

	-- Moving stops emotes.
	if speed > MOVE_FULL * 2 or not state.grounded then
		PoseController.stopEmotes(character)
	end

	-- Ground: idle, walk and run on a shared phase that advances one cycle per stride, so the
	-- planted foot moves back exactly as fast as the body moves forward.
	if not state.legScale then
		state.legScale = legScale(character, run.leg)
	end
	-- Humanoids start and stop almost at once; the poses ease between speeds instead.
	state.blendSpeed += (speed - state.blendSpeed) * math.min(1, dt * (if speed > state.blendSpeed then 14 else 9))
	local moving = math.clamp(state.blendSpeed / MOVE_FULL, 0, 1)
	local running = math.clamp((state.blendSpeed - RUN_FROM) / (RUN_FULL - RUN_FROM), 0, 1)
	local walkStride = walk.stride or DEFAULT_STRIDES.walk
	local runStride = run.stride or DEFAULT_STRIDES.run
	local stride = (walkStride + (runStride - walkStride) * running) * (state.legScale :: number)
	local before = state.phase
	state.phase = (state.phase + dt * math.max(speed, state.blendSpeed) / stride) % 1
	-- A foot comes down each time the stride passes 0 and 0.5.
	if state.grounded and speed > MOVE_FULL and not root.Anchored then
		if state.phase < before or (before < 0.5 and state.phase >= 0.5) then
			LocomotionController.Footfall:Fire(character)
		end
	end
	table.clear(buffers.idle)
	table.clear(buffers.walk)
	table.clear(buffers.run)
	local idleRot, idleOffset = ClipPlayer.sample(idle, state.idleTime, buffers.idle)
	local ground, groundOffset = idleRot, idleOffset
	if moving > 0 then
		local walkRot, walkOffset = ClipPlayer.sample(walk, state.phase * walk.length, buffers.walk)
		local runRot, runOffset = ClipPlayer.sample(run, state.phase * run.length, buffers.run)
		table.clear(buffers.stride)
		blendInto(buffers.stride, walkRot, runRot, running)
		local strideOffset = lerpOffset(walkOffset, runOffset, running)
		table.clear(buffers.ground)
		blendInto(buffers.ground, idleRot, buffers.stride, moving)
		ground = buffers.ground
		groundOffset = lerpOffset(idleOffset, strideOffset, moving)
	end
	if state.airWeight <= 0 then
		return ground, groundOffset
	end

	-- Air: the take-off while rising, easing into the fall as the body starts to drop.
	table.clear(buffers.jump)
	table.clear(buffers.fall)
	table.clear(buffers.air)
	local jumpRot, jumpOffset = ClipPlayer.sample(clips.jump, state.airTime, buffers.jump)
	local fallRot, fallOffset = ClipPlayer.sample(clips.fall, state.airTime, buffers.fall)
	local falling = if state.rising then math.clamp((2 - velocity.Y) / 12, 0, 1) else 1
	blendInto(buffers.air, jumpRot, fallRot, falling)
	local airRot, airOffset = buffers.air, lerpOffset(jumpOffset, fallOffset, falling)
	table.clear(buffers.out)
	blendInto(buffers.out, ground, airRot, state.airWeight)
	return buffers.out, lerpOffset(groundOffset, airOffset, state.airWeight)
end

-- Roblox's own Animate script (added to characters by default) would play its walk on top
-- of ours, and tracks this client starts on its own body replicate to everyone. Only this
-- player's own Animate runs here, so only that one is stopped.
local function silenceDefaultAnimate(character: Model, humanoid: Humanoid): number
	local removed = 0
	for _, item in ipairs(character:GetChildren()) do
		if item.Name == "Animate" and (item:IsA("LocalScript") or item:IsA("Script")) then
			(item :: any).Enabled = false
			item:Destroy()
			removed += 1
		end
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, playing in ipairs(animator:GetPlayingAnimationTracks()) do
			playing:Stop(0)
		end
	end
	return removed
end

local function track(character: Model)
	-- Wait for the rig to be assembled.
	character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local own = character == Players.LocalPlayer.Character
	local removed = 0
	if own then
		removed += silenceDefaultAnimate(character, humanoid)
		-- The script can arrive a moment after the body.
		local connection = character.ChildAdded:Connect(function(item)
			if item.Name == "Animate" then
				task.defer(function()
					removed += silenceDefaultAnimate(character, humanoid)
				end)
			end
		end)
		task.delay(10, function()
			connection:Disconnect()
		end)
	end
	local rig = PoseController.bindWhenReady(character, 8)
	if RunService:IsStudio() and own then
		-- One line in the output (and Studio's log) that says whether the animator took over.
		task.delay(4, function()
			local joints = 0
			for _ in pairs(if rig then rig.motors else {}) do
				joints += 1
			end
			local animate = character:FindFirstChild("Animate")
			local animator = humanoid:FindFirstChildOfClass("Animator")
			print(
				string.format(
					"[DeathsGambit] Animation check: %s, %d joints (%s), clip animator %s, default Animate %s, Roblox tracks %d, walk speed %d",
					tostring(humanoid.RigType),
					joints,
					if rig then Joints.kind(rig.motors) else Joints.kind(Joints.find(character)),
					if rig then "on" else "OFF",
					if animate then "STILL PRESENT" elseif removed > 0 then "removed" else "absent",
					if animator then #animator:GetPlayingAnimationTracks() else 0,
					humanoid.WalkSpeed
				)
			)
		end)
	end
end

function LocomotionController.init()
	for _, id in ipairs({ "idle", "walk", "run", "jump", "fall", "sit" }) do
		local clip = ClipPlayer.get(id)
		if not clip then
			warn("[DeathsGambit] Missing movement clip " .. id .. "; run art/scripts/export_anims.py.")
			return
		end
		clips[id] = clip
	end
	PoseController.setBaseProvider(provide)
	-- Every player's character and every test bot's.
	Characters.each(function(character)
		task.spawn(track, character)
	end)
end

return LocomotionController
