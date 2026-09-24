-- Movement animation for every character, worked out on each client from what everyone can
-- see (how fast a body moves, whether it is on the ground). Idle, walk and run blend by speed
-- and share one stride phase so the feet never slide between them; jumping and falling take
-- over in the air, and a knee dip plays on landing. The default Animate script is replaced by
-- an empty one (src/character/Animate.client.luau), so these are the only movement animations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClipPlayer = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anim"):WaitForChild("ClipPlayer"))

local PoseController = require(script.Parent.PoseController)

local LocomotionController = {}

-- Studs covered by one stride of the walk and run clips.
local STRIDE = 10.5
-- Speed (studs/s) where walking starts and where running takes over completely.
local WALK_SPEED = 3
local RUN_FROM, RUN_FULL = 9, 15
local GROUND_CHECK = 0.1
local LAND_AFTER = 0.35 -- seconds in the air before a landing dip plays

type State = {
	phase: number,
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
			phase = math.random(),
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

local function onGround(character: Model, root: BasePart, humanoid: Humanoid): boolean
	rayParams.FilterDescendantsInstances = { character }
	local reach = humanoid.HipHeight + root.Size.Y / 2 + 1.2
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

	-- Moving stops emotes.
	if speed > WALK_SPEED or not state.grounded then
		PoseController.stopEmotes(character)
	end

	-- Ground: idle, walk and run on a shared stride phase.
	state.phase = (state.phase + dt * speed / STRIDE) % 1
	local moving = math.clamp(speed / WALK_SPEED, 0, 1)
	local running = math.clamp((speed - RUN_FROM) / (RUN_FULL - RUN_FROM), 0, 1)
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

local function track(character: Model)
	-- Wait for the rig to be assembled.
	character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	for _, name in ipairs({ "LowerTorso", "UpperTorso", "Head" }) do
		character:WaitForChild(name, 5)
	end
	task.wait()
	PoseController.bind(character)
end

function LocomotionController.init()
	for _, id in ipairs({ "idle", "walk", "run", "jump", "fall" }) do
		local clip = ClipPlayer.get(id)
		if not clip then
			warn("[Inkbound] Missing movement clip " .. id .. "; run art/scripts/export_anims.py.")
			return
		end
		clips[id] = clip
	end
	PoseController.setBaseProvider(provide)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(track, character)
		end)
		if player.Character then
			task.spawn(track, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return LocomotionController
