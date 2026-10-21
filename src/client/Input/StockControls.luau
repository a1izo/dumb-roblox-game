--!nonstrict
-- Walking, jumping, the camera keys and shift lock follow the player's own bindings (Shared/Bindings: moveForward
-- .. moveRight, jump, turnLeft/turnRight, zoomIn/zoomOut, shiftLock, and the pad's two sticks: "move" and
-- "look"). Those controls belong to Roblox's stock PlayerModule, which reads fixed keys. Rather than a copy of the
-- whole module (some fifty files that would fall behind Roblox's updates), a few of its methods are wrapped in
-- place, here and only here:
--
--   ControlModule/Keyboard  BindContextActions  binds the walk and jump keys from the bindings (the stock one binds
--                                                Enum.PlayerActions, which the engine ties to WASD, the arrows and
--                                                Space)
--   ControlModule/Gamepad   BindContextActions  the stock one, then the jump button and, with the sticks swapped,
--                                                walking on the right stick
--   CameraModule/CameraInput setInputEnabled,    the stock keys and right stick are unbound and ours read instead;
--                           getRotation,         the stock speeds (copied below) apply to them
--                           getZoomDelta,
--                           getRotationActivated
--   CameraModule/MouseLockController's BoundKeys (a StringValue Roblox reads for this purpose) holds the shift lock
--                                                keys
--
-- With the default keys every wrapper hands straight to Roblox's own code: a player who never rebinds anything
-- plays on the stock module, untouched. A wrapper is only installed when the method it wraps is where it should
-- be; if Roblox moves it, that control keeps its stock keys and a warning says so, and nothing else breaks.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Bindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bindings"))

local StockControls = {}

local MOVE_IDS = { "moveForward", "moveBack", "moveLeft", "moveRight", "jump" }
local CAMERA_IDS = { "turnLeft", "turnRight", "zoomIn", "zoomOut" }
local PAD_IDS = { "jump", "move", "look" }

-- CameraInput's own speeds and stick curve (version-4f087c32742644ab), for the keys and stick it no longer reads.
local ROTATION_SPEED_KEYS = math.rad(120) -- rad/s
local ROTATION_SPEED_GAMEPAD = Vector2.new(1, 0.77) * math.rad(4) * 60 -- rad/s
local ZOOM_SPEED_KEYS = 0.1
local CAMERA_PRIORITY = Enum.ContextActionPriority.Medium.Value
local STICK_DEADZONE = 0.2 -- Gamepad's thumbstickDeadzone

local function thumbstickCurve(x: number): number
	local fDeadzone = (math.abs(x) - 0.1) / (1 - 0.1)
	local fCurve = (math.exp(2 * fDeadzone) - 1) / (math.exp(2) - 1)
	return math.sign(x) * math.clamp(fCurve, 0, 1)
end

local saved: any = nil
local custom = { keyboard = false, pad = false, camera = false }

local modules: { [string]: any } = {}
local installed = false

local function keyCodes(id: string, platform: string): { Enum.KeyCode }
	return Bindings.keyCodes(id, platform, saved)
end

local function wrap(name: string, owner: any, method: string, make: (any) -> any): boolean
	if type(owner) ~= "table" or type(rawget(owner, method)) ~= "function" then
		warn(
			string.format("[DeathsGambit] Controls: %s.%s is not where it was; those keys stay Roblox's.", name, method)
		)
		return false
	end
	owner[method] = make(owner[method])
	return true
end

-- Walking and jumping ----------------------------------------------------------------------------------------------

local function keyboardBind(original)
	return function(self, ...)
		if not custom.keyboard then
			return original(self, ...)
		end
		local function held(state: Enum.UserInputState): boolean
			return state == Enum.UserInputState.Begin
		end
		local handlers = {
			moveForward = function(_, state)
				self.forwardValue = if held(state) then -1 else 0
				self:UpdateMovement(state)
				return Enum.ContextActionResult.Pass
			end,
			moveBack = function(_, state)
				self.backwardValue = if held(state) then 1 else 0
				self:UpdateMovement(state)
				return Enum.ContextActionResult.Pass
			end,
			moveLeft = function(_, state)
				self.leftValue = if held(state) then -1 else 0
				self:UpdateMovement(state)
				return Enum.ContextActionResult.Pass
			end,
			moveRight = function(_, state)
				self.rightValue = if held(state) then 1 else 0
				self:UpdateMovement(state)
				return Enum.ContextActionResult.Pass
			end,
			jump = function(_, state)
				self.jumpRequested = self.jumpEnabled and held(state)
				self:UpdateJump()
				return Enum.ContextActionResult.Pass
			end,
		}
		-- (the stock action names, so Roblox's own unbinding still finds them)
		local names = {
			moveForward = "moveForwardAction",
			moveBack = "moveBackwardAction",
			moveLeft = "moveLeftAction",
			moveRight = "moveRightAction",
			jump = "jumpAction",
		}
		for _, id in ipairs(MOVE_IDS) do
			local name = names[id]
			local keys = keyCodes(id, "keyboard")
			if #keys > 0 then
				ContextActionService:BindActionAtPriority(
					name,
					handlers[id],
					false,
					self.CONTROL_ACTION_PRIORITY,
					table.unpack(keys)
				)
			end
			self._connectionUtil:trackBoundFunction(name, function()
				ContextActionService:UnbindAction(name)
			end)
		end
	end
end

local function gamepadBind(original)
	return function(self, ...)
		local result = original(self, ...)
		if not custom.pad or result == false then
			return result
		end
		local jumpKeys = keyCodes("jump", "gamepad")
		if #jumpKeys > 0 then
			ContextActionService:BindActionAtPriority("jumpAction", function(_, state)
				self.isJumping = state == Enum.UserInputState.Begin
				return Enum.ContextActionResult.Sink
			end, false, self.CONTROL_ACTION_PRIORITY, table.unpack(jumpKeys))
		else
			ContextActionService:UnbindAction("jumpAction")
		end
		local stick = keyCodes("move", "gamepad")[1] or Enum.KeyCode.Thumbstick1
		if stick ~= Enum.KeyCode.Thumbstick1 then
			ContextActionService:BindActionAtPriority("moveThumbstick", function(_, state, input)
				if state == Enum.UserInputState.Cancel then
					self.thumbstickVector = Vector3.zero
					self.moveVector = Vector3.zero
					return Enum.ContextActionResult.Sink
				end
				if self.activeGamepad ~= input.UserInputType then
					return Enum.ContextActionResult.Pass
				end
				local p = input.Position
				local v = if p.Magnitude > STICK_DEADZONE then Vector3.new(p.X, 0, -p.Y) else Vector3.zero
				if self.thumbstickVector ~= nil then
					self.thumbstickVector = v
					self:UpdateMovement()
				else
					self.moveVector = v
				end
				return Enum.ContextActionResult.Sink
			end, false, self.CONTROL_ACTION_PRIORITY, stick)
		end
		return result
	end
end

-- The camera -------------------------------------------------------------------------------------------------------

local cameraKeys = { turnLeft = 0, turnRight = 0, zoomIn = 0, zoomOut = 0 }
local lookStick = Vector2.zero
local stockCameraOn = false

local function bindCamera()
	ContextActionService:UnbindAction("DeathsGambit_CameraKeys")
	ContextActionService:UnbindAction("DeathsGambit_CameraStick")
	for id in pairs(cameraKeys) do
		cameraKeys[id] = 0
	end
	lookStick = Vector2.zero
	if not (custom.camera and stockCameraOn) then
		return
	end
	-- Roblox's own camera keys and right stick go quiet; ours stand in for them.
	ContextActionService:UnbindAction("RbxCameraKeypress")
	ContextActionService:UnbindAction("RbxCameraThumbstick")
	local byKey: { [Enum.KeyCode]: string } = {}
	local inputs = {}
	for _, id in ipairs(CAMERA_IDS) do
		for _, key in ipairs(keyCodes(id, "keyboard")) do
			byKey[key] = id
			table.insert(inputs, key)
		end
	end
	if #inputs > 0 then
		ContextActionService:BindActionAtPriority("DeathsGambit_CameraKeys", function(_, state, input)
			local id = byKey[input.KeyCode]
			if id then
				cameraKeys[id] = if state == Enum.UserInputState.Begin then 1 else 0
			end
			return Enum.ContextActionResult.Pass
		end, false, CAMERA_PRIORITY, table.unpack(inputs))
	end
	local stick = keyCodes("look", "gamepad")[1] or Enum.KeyCode.Thumbstick2
	ContextActionService:BindActionAtPriority("DeathsGambit_CameraStick", function(_, state, input)
		if state == Enum.UserInputState.Cancel then
			lookStick = Vector2.zero
		else
			local p = input.Position
			lookStick = Vector2.new(thumbstickCurve(p.X), -thumbstickCurve(p.Y))
		end
		return Enum.ContextActionResult.Pass
	end, false, CAMERA_PRIORITY, stick)
end

local function cameraWrappers(CameraInput: any): boolean
	local ok = wrap("CameraInput", CameraInput, "setInputEnabled", function(original)
		return function(enabled, ...)
			local result = original(enabled, ...)
			stockCameraOn = enabled == true
			bindCamera()
			return result
		end
	end)
	ok = ok
		and wrap("CameraInput", CameraInput, "getRotation", function(original)
			return function(dt, disableKeyboardRotation, ...)
				local base = original(dt, disableKeyboardRotation, ...)
				if not custom.camera then
					return base
				end
				local invert = Vector2.new(1, UserGameSettings:GetCameraYInvertValue())
				local keys = if disableKeyboardRotation
					then Vector2.zero
					else Vector2.new(cameraKeys.turnRight - cameraKeys.turnLeft, 0) * dt
				local pad = lookStick * UserGameSettings.GamepadCameraSensitivity * dt
				return base + (keys * ROTATION_SPEED_KEYS + pad * ROTATION_SPEED_GAMEPAD) * invert
			end
		end)
	ok = ok
		and wrap("CameraInput", CameraInput, "getZoomDelta", function(original)
			return function(...)
				local base = original(...)
				if not custom.camera then
					return base
				end
				return base + (cameraKeys.zoomOut - cameraKeys.zoomIn) * ZOOM_SPEED_KEYS
			end
		end)
	ok = ok
		and wrap("CameraInput", CameraInput, "getRotationActivated", function(original)
			return function(...)
				return original(...) or (custom.camera and lookStick.Magnitude > 0)
			end
		end)
	-- The camera's input may be on already: the stock bindings are live, so take them over now.
	stockCameraOn = next(ContextActionService:GetBoundActionInfo("RbxCameraKeypress")) ~= nil
	return ok
end

-- Shift lock -------------------------------------------------------------------------------------------------------

local function applyShiftLock()
	local controller = modules.MouseLockController
	local value = controller and controller:FindFirstChild("BoundKeys")
	if not (value and value:IsA("StringValue")) then
		return
	end
	local names = Bindings.keys("shiftLock", "keyboard", saved)
	-- (no keys at all would leave shift lock unreachable: then Roblox's own stand)
	value.Value = if #names > 0 then table.concat(names, ",") else "LeftShift,RightShift"
end

-- Setting up -------------------------------------------------------------------------------------------------------

-- Every controller the ControlModule has made of a class, enabled ones rebound now.
local function rebind(class: any)
	local controls = modules.controls
	if not (controls and class and type(controls.controllers) == "table") then
		return
	end
	local controller = controls.controllers[class]
	if controller and controller.enabled then
		controller:Enable(false)
		controller:Enable(true)
	end
end

local function install(): boolean
	local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 30)
	if not playerModule then
		warn("[DeathsGambit] Controls: no PlayerModule; walking and camera keys stay Roblox's.")
		return false
	end
	local ok, err = pcall(function()
		local main = require(playerModule)
		modules.controls = main:GetControls()
		local controlModule = playerModule:WaitForChild("ControlModule")
		local cameraModule = playerModule:WaitForChild("CameraModule")
		modules.Keyboard = require(controlModule:WaitForChild("Keyboard"))
		modules.Gamepad = require(controlModule:WaitForChild("Gamepad"))
		modules.CameraInput = require(cameraModule:WaitForChild("CameraInput"))
		modules.MouseLockController = cameraModule:FindFirstChild("MouseLockController")
		wrap("Keyboard", modules.Keyboard, "BindContextActions", keyboardBind)
		wrap("Gamepad", modules.Gamepad, "BindContextActions", gamepadBind)
		cameraWrappers(modules.CameraInput)
	end)
	if not ok then
		warn("[DeathsGambit] Controls: could not reach the PlayerModule: " .. tostring(err))
		return false
	end
	return true
end

-- Applies a player's set (their profile's `keybinds`; nil for the defaults).
function StockControls.apply(set: any)
	saved = set
	local wasCamera = custom.camera
	custom.keyboard = Bindings.changed(MOVE_IDS, "keyboard", saved)
	custom.pad = Bindings.changed(PAD_IDS, "gamepad", saved)
	custom.camera = Bindings.changed(CAMERA_IDS, "keyboard", saved) or Bindings.changed({ "look" }, "gamepad", saved)
	if not installed then
		return
	end
	-- (Enable(false) unbinds through Roblox's own tracked names, Enable(true) binds afresh with the wrappers)
	rebind(modules.Keyboard)
	rebind(modules.Gamepad)
	if wasCamera and not custom.camera and stockCameraOn then
		-- Back to the defaults: Roblox binds its own camera keys and stick again.
		modules.CameraInput.setInputEnabled(false)
		modules.CameraInput.setInputEnabled(true)
	else
		bindCamera()
	end
	applyShiftLock()
end

-- What the wrappers are doing now, for checks.
-- Where the player is steering now (Roblox's controls: the keys, the stick, the touch pad), in the camera's frame;
-- zero when they are not (or the controls are not reachable).
function StockControls.moveVector(): Vector3
	local controls = modules.controls
	if not controls then
		return Vector3.zero
	end
	local ok, value = pcall(function()
		return controls:GetMoveVector()
	end)
	return if ok and typeof(value) == "Vector3" then value else Vector3.zero
end

function StockControls.state(): { installed: boolean, keyboard: boolean, pad: boolean, camera: boolean }
	return { installed = installed, keyboard = custom.keyboard, pad = custom.pad, camera = custom.camera }
end

function StockControls.init(set: any)
	saved = set
	task.spawn(function()
		installed = install()
		StockControls.apply(saved)
	end)
end

return StockControls
