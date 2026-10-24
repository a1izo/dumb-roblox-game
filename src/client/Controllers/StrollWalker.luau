-- Strolls walk by themselves (the owner's Q7/Q25, 2026-10-20/21): while this player's body has a stroll (the
-- server's "Stroll" attribute), it walks on its own along the way it faced when the stroll began, at the stroll's
-- pace (Cosmetics `pace`), its stroll's walk playing (LocomotionController). The player guides it with whatever they
-- play on (the owner, 2026-10-24: "guided with the camera or wasd or any other thing for different systems and only
-- interrupt when you jump"):
--   walking: the walk keys, the left stick, the touch pad, from the camera as Roblox's controls do. Read from
--     Roblox's controls when they can be reached (Input/StockControls), else straight from the bound keys and the
--     stick, and else from the controls' own move this frame (Humanoid.MoveDirection, taken before this walker's
--     own move): a place without the stock PlayerModule (the owner's, 2026-10-24) steers too;
--   the camera: while the player turns it (the mouse dragged with its right button or locked by shift lock or first
--     person, the right stick, a finger dragging the view, the camera's turn keys), the walk turns to the way the
--     camera looks.
-- It turns that way (a turn, not a snap) and, let go, keeps on that way. By itself it slides along walls and turns
-- back at a ledge or a wall met head-on. Only a jump ends it (or another emote picked, or the server: a meeting, a
-- cutscene); chat, menus, prompts, game actions and the camera never do. Only this player's own body: Roblox
-- replicates its walk to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)
local StockControls = require(script.Parent.Parent.Input.StockControls)

local StrollWalker = {}

local EmoteRemote = Net.event("Emote")
local BIND = "DeathsGambit_StrollWalker"
local SAMPLE = "DeathsGambit_StrollWalkerSample"
local DEFAULT_PACE = 7
local STEER = 0.15 -- the player's own steering past this turns the walk
local STEER_RATE = math.rad(420) -- how fast it turns to the way steered (radians a second): a turn, not a snap
local STICK_DEADZONE = 0.2
local CAMERA_HOLD = 0.12 -- seconds after the last camera turn it still counts as turning (mouse moves come in bursts)
local AHEAD = 2.6 -- studs ahead of the root the ground is looked for (a ledge: none within DROP)
local DROP = 6
local WALL = 2.0 -- studs ahead of the root a wall is looked for
local HEAD_ON = -0.8 -- a wall this square to the way (its normal against it) turns the walk back
local TURN = 0.4 -- seconds to turn back
local PADS = {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
}

type Walk = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	heading: Vector3,
	turning: { from: Vector3, to: Vector3, began: number }?,
	speed: number,
	oldSpeed: number,
	connections: { RBXScriptConnection },
	asked: boolean,
	sampled: Vector3, -- the controls' own move this frame, taken before this walker's
	moved: Vector3, -- this walker's last move
	cameraAt: number, -- when the player last turned the camera
	why: string?, -- what last steered it (for the harness)
}

local walk: Walk? = nil

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

local function keybinds(): any
	local profile = ClientState.profile
	return if profile then profile.keybinds else nil
end

-- The body stops walking by itself (its speed as it was).
local function stop()
	local w = walk
	if not w then
		return
	end
	walk = nil
	RunService:UnbindFromRenderStep(BIND)
	RunService:UnbindFromRenderStep(SAMPLE)
	for _, connection in ipairs(w.connections) do
		connection:Disconnect()
	end
	if w.humanoid.Parent then
		w.humanoid:Move(Vector3.zero, false)
		if w.humanoid.WalkSpeed == w.speed then
			w.humanoid.WalkSpeed = w.oldSpeed
		end
	end
end

-- The player ended it: the server is asked (once) to end the stroll on every screen, and it stops here at once.
local function cancel()
	local w = walk
	if not w then
		return
	end
	if not w.asked then
		w.asked = true
		EmoteRemote:FireServer({ stop = true })
	end
	stop()
end

local function ground(w: Walk, from: Vector3): boolean
	params.FilterDescendantsInstances = { w.character, workspace.CurrentCamera }
	return workspace:Raycast(from, Vector3.new(0, -(DROP + 3.5), 0), params) ~= nil
end

-- `from` turned toward `to` (both flat and unit) by at most `most` radians, the short way round.
local function turnToward(from: Vector3, to: Vector3, most: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= most then
		return to
	end
	-- (to the right of `from` the cross is down; straight back it is nought, and goes right)
	local side = if from:Cross(to).Y <= 0 then 1 else -1
	local right = Vector3.new(-from.Z, 0, from.X) * side
	return flat(from * math.cos(most) + right * math.sin(most))
end

local function typing(): boolean
	return UserInputService:GetFocusedTextBox() ~= nil
end

local function anyKeyDown(id: string): boolean
	for _, key in ipairs(Bindings.keyCodes(id, "keyboard", keybinds())) do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

-- A stick's position on any connected pad (zero inside the dead zone).
local function stick(id: string, default: Enum.KeyCode): Vector2
	local code = Bindings.keyCodes(id, "gamepad", keybinds())[1] or default
	for _, pad in ipairs(PADS) do
		if UserInputService:GetGamepadConnected(pad) then
			for _, state in ipairs(UserInputService:GetGamepadState(pad)) do
				if state.KeyCode == code then
					local p = Vector2.new(state.Position.X, state.Position.Y)
					if p.Magnitude > STICK_DEADZONE then
						return p
					end
				end
			end
		end
	end
	return Vector2.zero
end

-- Where the player is steering now, flat in the world, and by what; nil when they are not.
local function steering(w: Walk): (Vector3?, string?)
	local camera = workspace.CurrentCamera
	local function fromCamera(v: Vector3): Vector3
		return flat(if camera then camera.CFrame:VectorToWorldSpace(v) else v)
	end
	-- Roblox's controls, when they can be reached (every platform, the player's own keys)
	local move = StockControls.moveVector()
	if move.Magnitude > STEER then
		return fromCamera(move), "controls"
	end
	-- the bound walk keys and the walking stick, read straight
	if not typing() then
		local keys = Vector3.new(
			(if anyKeyDown("moveRight") then 1 else 0) - (if anyKeyDown("moveLeft") then 1 else 0),
			0,
			(if anyKeyDown("moveBack") then 1 else 0) - (if anyKeyDown("moveForward") then 1 else 0)
		)
		if keys.Magnitude > 0 then
			return fromCamera(keys), "keys"
		end
	end
	local left = stick("move", Enum.KeyCode.Thumbstick1)
	if left.Magnitude > 0 then
		return fromCamera(Vector3.new(left.X, 0, -left.Y)), "stick"
	end
	-- whatever the place's controls asked of the body this frame (a touch pad or a controller not reached above):
	-- unlike this walker's own last move, it is the player's
	local sampled = w.sampled
	if sampled.Magnitude > STEER and (sampled.Unit - w.moved).Magnitude > 0.05 then
		return flat(sampled), "move"
	end
	return nil, nil
end

-- What the player is turning the camera with now (or did a moment ago), or nil.
local function cameraTurning(w: Walk): string?
	if os.clock() - w.cameraAt < CAMERA_HOLD then
		return "camera"
	end
	if stick("look", Enum.KeyCode.Thumbstick2).Magnitude > 0 then
		return "camera stick"
	end
	if not typing() and (anyKeyDown("turnLeft") or anyKeyDown("turnRight")) then
		return "camera keys"
	end
	return nil
end

local function step(w: Walk, dt: number)
	if not w.root.Parent or not w.humanoid.Parent or w.humanoid.Health <= 0 then
		stop()
		return
	end
	-- a jump: the stroll ends
	if w.humanoid.Jump then
		cancel()
		return
	end
	local now = os.clock()
	local want, by = steering(w)
	if not want then
		local turning = cameraTurning(w)
		local camera = workspace.CurrentCamera
		if turning and camera then
			want, by = flat(camera.CFrame.LookVector), turning
		end
	end
	if want then
		w.why = by
		w.turning = nil
		w.heading = turnToward(w.heading, want, STEER_RATE * dt)
	elseif w.turning then
		local u = math.clamp((now - w.turning.began) / TURN, 0, 1)
		-- (half round to the right, so it never passes through the way it came)
		local right = Vector3.new(-w.turning.from.Z, 0, w.turning.from.X)
		local angle = u * math.pi
		w.heading = flat(w.turning.from * math.cos(angle) + right * math.sin(angle))
		if u >= 1 then
			w.heading = w.turning.to
			w.turning = nil
		end
	else
		local at = w.root.Position
		local ledge = not ground(w, at + w.heading * AHEAD)
		params.FilterDescendantsInstances = { w.character, workspace.CurrentCamera }
		local hit = workspace:Raycast(at, w.heading * WALL, params)
		local headOn = hit ~= nil and hit.Normal:Dot(w.heading) < HEAD_ON
		if ledge or headOn then
			w.turning = { from = w.heading, to = -w.heading, began = now }
		end
	end
	w.moved = w.heading
	w.humanoid:Move(w.heading, false)
end

-- Input that turns the camera: the mouse moved with its right button held or locked to the middle (shift lock, first
-- person), or a finger dragging the view (a touch the interface did not take, such as the touch pad's).
local function watchCamera(w: Walk, input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local turned = math.abs(input.Delta.X) > 0
		local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		if turned and (held or locked) then
			w.cameraAt = os.clock()
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		if math.abs(input.Delta.X) > 0 then
			w.cameraAt = os.clock()
		end
	end
end

local function begin(character: Model, clip: string)
	stop()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local item = EmoteInfo.of(clip).item
	local pace = if item and type(item.pace) == "number" then item.pace else DEFAULT_PACE
	local heading = flat(root.CFrame.LookVector)
	local w: Walk = {
		character = character,
		humanoid = humanoid,
		root = root,
		heading = heading,
		turning = nil,
		speed = pace,
		oldSpeed = humanoid.WalkSpeed,
		connections = {},
		asked = false,
		sampled = Vector3.zero,
		moved = heading,
		cameraAt = -math.huge,
	}
	-- (frozen, as at a meeting: it does not walk)
	if humanoid.WalkSpeed <= 0 or root.Anchored then
		return
	end
	humanoid.WalkSpeed = pace
	walk = w
	-- Only a jump ends it: the jump request (every platform's jump), and the bound jump keys and button read straight
	-- for a place whose controls do not ask for jumps.
	table.insert(w.connections, UserInputService.JumpRequest:Connect(cancel))
	table.insert(
		w.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or typing() then
				return
			end
			local platform = if input.UserInputType == Enum.UserInputType.Keyboard then "keyboard" else "gamepad"
			for _, key in ipairs(Bindings.keyCodes("jump", platform, keybinds())) do
				if input.KeyCode == key then
					cancel()
					return
				end
			end
		end)
	)
	table.insert(
		w.connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
			watchCamera(w, input, processed)
		end)
	)
	-- (just after Roblox's controls have moved the body: what they asked of it this frame)
	RunService:BindToRenderStep(SAMPLE, Enum.RenderPriority.Input.Value + 1, function()
		if walk == w then
			w.sampled = humanoid.MoveDirection
		end
	end)
	-- (after Roblox's controls have moved the body for this frame: this move wins)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Character.Value + 5, function(dt: number)
		if walk == w then
			step(w, dt)
		end
	end)
end

local function watch(character: Model)
	local function changed()
		local clip = character:GetAttribute("Stroll")
		if type(clip) == "string" then
			begin(character, clip)
		elseif walk and walk.character == character then
			stop()
		end
	end
	character:GetAttributeChangedSignal("Stroll"):Connect(changed)
	changed()
end

-- (for the harness: the way the stroll walks now, or nil when it is not walking)
function StrollWalker.heading(): Vector3?
	return if walk then walk.heading else nil
end

-- (for the harness: what last steered the walk, or nil)
function StrollWalker.why(): string?
	return if walk then walk.why else nil
end

-- (for the harness: the camera counts as turned by the player now, as a mouse drag or the right stick would)
function StrollWalker.cameraTurned()
	if walk then
		walk.cameraAt = os.clock()
	end
end

function StrollWalker.init()
	local player = Players.LocalPlayer
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		stop()
		watch(character)
	end)
end

return StrollWalker
