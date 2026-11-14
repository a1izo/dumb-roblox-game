--!strict
-- Photo mode, in the lobby only (2026-11-14): your body holds still where it stands, the camera comes loose, the UI
-- goes, and you frame a picture of the Grey Realm (Roblox's own screenshot key or the phone's takes it). The camera
-- stays within REACH studs of your body and never passes through what stands between them (no looking into what is
-- closed off). Film looks change the picture's colour; no blur (the owner had a global depth of field taken out).
--
--   Keyboard: hold the right mouse button and move to look; W A S D move, E / Q up and down, Shift faster; Z / C tilt,
--   R straightens it; the wheel zooms; F the next look; H hides these words; P or Backspace leaves.
--   Gamepad: the sticks move and look, R2 / L2 up and down, the D-pad zooms, X the next look, Y hides the words, B
--   leaves. Touch: drag to look, pinch to zoom, hold Forward / Back to move; Look, Hide and Leave buttons.
--
-- It leaves by itself when you are pulled into a case, a cutscene takes the camera, or your body goes.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.Parent.ClientState)
local CameraDirector = require(script.Parent.Parent.Presentation.CameraDirector)
local Device = require(script.Parent.Parent.UI.Core.Device)
local Kit = require(script.Parent.Parent.UI.Kit)
local LobbyChrome = require(script.Parent.Parent.UI.Core.LobbyChrome)
local LobbyIntro = require(script.Parent.Parent.UI.LobbyIntro)
local Screens = require(script.Parent.Parent.UI.Screens)
local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local PhotoMode = {}

-- Fired as (active) when photo mode starts or ends (the lobby's eye button stays away meanwhile).
PhotoMode.Changed = Signal.new()

local C = Kit.color
local LocalPlayer = Players.LocalPlayer

local REACH = 36 -- studs from the body the camera may go
local SPEED = 14 -- studs a second (Shift: three times)
local FOV_MIN, FOV_MAX = 12, 100
local ACTION = "DeathsGambit_PhotoMode"
local STEP = "DeathsGambit_PhotoCamera"

-- The film looks: a name and the colour correction it puts over the picture (nil: as it is).
type Look = { name: string, cc: { [string]: any }? }
local LOOKS: { Look } = {
	{ name = "As seen" },
	{ name = "Noir", cc = { Saturation = -1, Contrast = 0.35, Brightness = -0.02 } },
	{
		name = "Silver",
		cc = { Saturation = -0.85, Contrast = 0.15, Brightness = 0.04, TintColor = Color3.fromRGB(232, 238, 248) },
	},
	{ name = "Sepia", cc = { Saturation = -0.6, Contrast = 0.12, TintColor = Color3.fromRGB(255, 226, 190) } },
	{ name = "Bleach", cc = { Saturation = -0.45, Contrast = 0.3, Brightness = 0.05 } },
	{
		name = "Night",
		cc = { Saturation = -0.3, Contrast = 0.15, Brightness = -0.04, TintColor = Color3.fromRGB(190, 205, 255) },
	},
}

local active = false
local saved: {
	cameraType: Enum.CameraType,
	subject: Instance?,
	fov: number,
	hidden: boolean,
	anchored: boolean,
}? =
	nil
local root: BasePart? = nil
local position = Vector3.zero
local yaw, pitch, roll = 0, 0, 0
local fov = 70
local lookIndex = 1
local filter: ColorCorrectionEffect? = nil
local gui: ScreenGui? = nil
local hint: TextLabel? = nil
local hintShown = true
local held: { [string]: boolean } = {} -- the touch buttons held down
local connections: { RBXScriptConnection } = {}

local KEYS = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.E,
	Enum.KeyCode.Q,
	Enum.KeyCode.Z,
	Enum.KeyCode.C,
	Enum.KeyCode.R,
	Enum.KeyCode.F,
	Enum.KeyCode.H,
	Enum.KeyCode.P,
	Enum.KeyCode.Backspace,
	Enum.KeyCode.Space,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.Up,
	Enum.KeyCode.Down,
	Enum.KeyCode.Left,
	Enum.KeyCode.Right,
	Enum.KeyCode.I,
	Enum.KeyCode.O,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.ButtonA,
	Enum.KeyCode.ButtonB,
	Enum.KeyCode.ButtonX,
	Enum.KeyCode.ButtonY,
	Enum.KeyCode.ButtonL1,
	Enum.KeyCode.ButtonR1,
	Enum.KeyCode.ButtonL2,
	Enum.KeyCode.ButtonR2,
	Enum.KeyCode.DPadUp,
	Enum.KeyCode.DPadDown,
	Enum.KeyCode.DPadLeft,
	Enum.KeyCode.DPadRight,
	Enum.KeyCode.Thumbstick1,
	Enum.KeyCode.Thumbstick2,
	Enum.UserInputType.MouseWheel,
} :: { any }

local function inLobby(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching() and not ClientState.isAway()
end

-- Something else has the screen: the arrival's eye (or the loading screen), a cutscene's frame, a scene's camera.
local function screenTaken(): boolean
	return LobbyIntro.isPlaying() or Screens.hud:GetAttribute("Cinematic") == true or CameraDirector.busy()
end

function PhotoMode.isActive(): boolean
	return active
end

-- Whether photo mode can start now.
function PhotoMode.available(): boolean
	return not active and inLobby() and not screenTaken() and LocalPlayer.Character ~= nil
end

local function hintText(): string
	local look = LOOKS[lookIndex].name
	if Device.touch() then
		return "PHOTO MODE   drag to look, pinch to zoom   look: " .. look
	end
	return string.format(
		"PHOTO MODE   right mouse: look   WASD, E / Q: move   Z / C: tilt   wheel: zoom   F: look (%s)   H: hide   P: leave",
		look
	)
end

local function setLook(index: number)
	lookIndex = (index - 1) % #LOOKS + 1
	local look = LOOKS[lookIndex]
	if filter then
		filter:Destroy()
		filter = nil
	end
	local camera = Workspace.CurrentCamera
	if look.cc and camera then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "DGPhotoLook"
		for key, value in pairs(look.cc) do
			(cc :: any)[key] = value
		end
		cc.Parent = camera
		filter = cc
	end
	if hint then
		hint.Text = hintText()
	end
end

local function setHint(on: boolean)
	hintShown = on
	if hint then
		hint.Visible = on
	end
end

-- Where the camera may be: no farther than REACH from the body, and not past anything standing in between.
local function allowed(want: Vector3): Vector3
	local body = root
	if not body then
		return want
	end
	local from = body.Position + Vector3.new(0, 1.5, 0)
	local offset = want - from
	if offset.Magnitude > REACH then
		offset = offset.Unit * REACH
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character :: any }
	local hit = Workspace:Raycast(from, offset, params)
	if hit then
		return hit.Position + hit.Normal * 0.4
	end
	return from + offset
end

local function onInput(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		fov = math.clamp(fov - input.Position.Z * 4, FOV_MIN, FOV_MAX)
		return Enum.ContextActionResult.Sink
	end
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.P or key == Enum.KeyCode.Backspace or key == Enum.KeyCode.ButtonB then
		task.defer(PhotoMode.stop)
	elseif key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonX then
		setLook(lookIndex + 1)
	elseif key == Enum.KeyCode.H or key == Enum.KeyCode.ButtonY then
		setHint(not hintShown)
	elseif key == Enum.KeyCode.R then
		roll = 0
	end
	return Enum.ContextActionResult.Sink
end

local function pressed(key: Enum.KeyCode): number
	return if UserInputService:IsKeyDown(key) then 1 else 0
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local character = LocalPlayer.Character
	if not active or not camera or not character or not root or not root.Parent or not inLobby() then
		PhotoMode.stop()
		return
	end
	-- (a cutscene's camera wins: it took the camera, so photo mode is over)
	if screenTaken() then
		PhotoMode.stop()
		return
	end
	-- Look: the right mouse button held, the right stick, a finger (TouchMoved, below).
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		local delta = UserInputService:GetMouseDelta()
		yaw -= delta.X * 0.0035 * (fov / 70)
		pitch -= delta.Y * 0.0035 * (fov / 70)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	local move = Vector3.new(
		pressed(Enum.KeyCode.D) - pressed(Enum.KeyCode.A),
		pressed(Enum.KeyCode.E) - pressed(Enum.KeyCode.Q),
		pressed(Enum.KeyCode.S) - pressed(Enum.KeyCode.W)
	)
	local tilt = pressed(Enum.KeyCode.C) - pressed(Enum.KeyCode.Z)
	for _, state in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		local p = state.Position
		if state.KeyCode == Enum.KeyCode.Thumbstick1 and p.Magnitude > 0.15 then
			move += Vector3.new(p.X, 0, -p.Y)
		elseif state.KeyCode == Enum.KeyCode.Thumbstick2 and p.Magnitude > 0.15 then
			yaw -= p.X * 2.2 * dt * (fov / 70)
			pitch += p.Y * 1.6 * dt * (fov / 70)
		elseif state.KeyCode == Enum.KeyCode.ButtonR2 and p.Z > 0.2 then
			move += Vector3.new(0, p.Z, 0)
		elseif state.KeyCode == Enum.KeyCode.ButtonL2 and p.Z > 0.2 then
			move -= Vector3.new(0, p.Z, 0)
		elseif state.KeyCode == Enum.KeyCode.DPadUp and state.UserInputState == Enum.UserInputState.Begin then
			fov = math.clamp(fov - 30 * dt, FOV_MIN, FOV_MAX)
		elseif state.KeyCode == Enum.KeyCode.DPadDown and state.UserInputState == Enum.UserInputState.Begin then
			fov = math.clamp(fov + 30 * dt, FOV_MIN, FOV_MAX)
		end
	end
	if held.forward then
		move += Vector3.new(0, 0, -1)
	end
	if held.back then
		move += Vector3.new(0, 0, 1)
	end
	pitch = math.clamp(pitch, -1.45, 1.45)
	roll = math.clamp(roll + tilt * 0.9 * dt, -0.6, 0.6)
	local turn = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	if move.Magnitude > 0 then
		local fast = if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then 3 else 1
		local flat = turn:VectorToWorldSpace(Vector3.new(move.X, 0, move.Z))
		local go = flat + Vector3.new(0, move.Y, 0)
		if go.Magnitude > 1 then
			go = go.Unit
		end
		position = allowed(position + go * SPEED * fast * dt)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	camera.CFrame = CFrame.new(position) * turn * CFrame.Angles(0, 0, roll)
end

local function buildOverlay()
	local screen = Instance.new("ScreenGui")
	screen.Name = "DGPhotoMode"
	screen.DisplayOrder = 60
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.Parent = LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	local label = Kit.label({
		Text = hintText(),
		font = "label",
		size = "small",
		color = C.bone,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -14),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Parent = screen,
	}) :: TextLabel
	label.TextStrokeTransparency = 0.4
	hint = label
	if Device.touch() then
		-- (a column of buttons at the right edge: hold to move, then the look, the words, leave)
		local column = Kit.frame({
			Name = "Buttons",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(120, 300),
			Parent = screen,
		})
		Kit.Base.make("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Parent = column,
		})
		local function hold(text: string, key: string, order: number)
			local b = Kit.button({
				text = text,
				variant = "ghost",
				size = "s",
				width = 110,
				LayoutOrder = order,
				Parent = column,
			})
			b.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					held[key] = true
				end
			end)
			b.InputEnded:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					held[key] = false
				end
			end)
		end
		hold("Forward", "forward", 1)
		hold("Back", "back", 2)
		Kit.button(
			{ text = "Look", variant = "ghost", size = "s", width = 110, LayoutOrder = 3, Parent = column },
			function()
				setLook(lookIndex + 1)
			end
		)
		Kit.button(
			{ text = "Hide", variant = "ghost", size = "s", width = 110, LayoutOrder = 4, Parent = column },
			function()
				setHint(not hintShown)
				column.Visible = hintShown
				-- (hidden, a tap anywhere brings the buttons back)
			end
		)
		Kit.button(
			{ text = "Leave", variant = "primary", size = "s", width = 110, LayoutOrder = 5, Parent = column },
			function()
				PhotoMode.stop()
			end
		)
		table.insert(
			connections,
			UserInputService.TouchTapInWorld:Connect(function()
				if not hintShown then
					setHint(true)
					column.Visible = true
				end
			end)
		)
	end
end

function PhotoMode.start()
	if not PhotoMode.available() then
		return
	end
	local camera = Workspace.CurrentCamera
	local character = LocalPlayer.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not body or not body:IsA("BasePart") then
		return
	end
	active = true
	root = body
	saved = {
		cameraType = camera.CameraType,
		subject = camera.CameraSubject,
		fov = camera.FieldOfView,
		hidden = LobbyChrome.isHidden(),
		anchored = body.Anchored,
	}
	-- (the body holds still where it stands: anchored here only, so it simply stands still for everyone)
	body.Anchored = true
	position = camera.CFrame.Position
	local x, y, _ = camera.CFrame:ToEulerAnglesYXZ()
	pitch, yaw, roll = x, y, 0
	fov = camera.FieldOfView
	LobbyChrome.setHidden(true)
	ContextActionService:BindActionAtPriority(
		ACTION,
		onInput,
		false,
		Enum.ContextActionPriority.High.Value + 50,
		table.unpack(KEYS)
	)
	table.insert(
		connections,
		UserInputService.TouchMoved:Connect(function(touch: InputObject, processed: boolean)
			if processed then
				return
			end
			yaw -= touch.Delta.X * 0.005 * (fov / 70)
			pitch -= touch.Delta.Y * 0.005 * (fov / 70)
		end)
	)
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(
			function(_: { Vector2 }, scale: number, _: number, _: Enum.UserInputState, processed: boolean)
				if not processed and scale > 0 then
					fov = math.clamp(fov / scale ^ 0.06, FOV_MIN, FOV_MAX)
				end
			end
		)
	)
	hintShown = true
	buildOverlay()
	setLook(1)
	RunService:BindToRenderStep(STEP, Enum.RenderPriority.Camera.Value + 50, step)
	PhotoMode.Changed:Fire(true)
end

function PhotoMode.stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(STEP)
	ContextActionService:UnbindAction(ACTION)
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(held)
	if filter then
		filter:Destroy()
		filter = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
		hint = nil
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local camera = Workspace.CurrentCamera
	local was = saved
	saved = nil
	if root and root.Parent and was then
		root.Anchored = was.anchored
	end
	root = nil
	if camera and was then
		-- (a cutscene that took the camera keeps it; otherwise the camera goes back to following you)
		if not CameraDirector.busy() then
			camera.CameraType = was.cameraType
			camera.CameraSubject = was.subject
			camera.FieldOfView = was.fov
		end
	end
	if was then
		LobbyChrome.setHidden(was.hidden)
	end
	PhotoMode.Changed:Fire(false)
end

function PhotoMode.toggle()
	if active then
		PhotoMode.stop()
	else
		PhotoMode.start()
	end
end

function PhotoMode.init()
	LocalPlayer.CharacterRemoving:Connect(function()
		PhotoMode.stop()
	end)
end

return PhotoMode
