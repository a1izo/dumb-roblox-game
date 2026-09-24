-- The only code that takes the camera away from the player. A cutscene takes it with
-- take(maxSeconds) and gives it back with release(token); the camera then returns exactly to
-- what it was (your character, or the player you were spectating). A watchdog gives the
-- camera back after maxSeconds no matter what, and so does respawning or the match ending.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ClientState = require(script.Parent.Parent.ClientState)

local LocalPlayer = Players.LocalPlayer

local CameraDirector = {}

type Saved = { cameraType: Enum.CameraType, subject: Instance?, fov: number }

local token = 0
local saved: Saved? = nil
local tween: Tween? = nil

local function camera(): Camera
	return workspace.CurrentCamera
end

local function restore()
	local state = saved
	saved = nil
	if tween then
		tween:Cancel()
		tween = nil
	end
	local cam = camera()
	if not cam or not state then
		return
	end
	cam.CameraType = if state.cameraType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else state.cameraType
	local subject = state.subject
	if not subject or not subject.Parent then
		local character = LocalPlayer.Character
		subject = if character then character:FindFirstChildOfClass("Humanoid") else nil
	end
	cam.CameraSubject = subject
	cam.FieldOfView = state.fov
end

-- True while a cutscene holds the camera.
function CameraDirector.busy(): boolean
	return saved ~= nil
end

-- Takes the camera for at most maxSeconds. Returns a token for the other calls.
function CameraDirector.take(maxSeconds: number): number
	token += 1
	local myToken = token
	local cam = camera()
	if not saved then
		saved = { cameraType = cam.CameraType, subject = cam.CameraSubject, fov = cam.FieldOfView }
	end
	cam.CameraType = Enum.CameraType.Scriptable
	task.delay(maxSeconds, function()
		if token == myToken and saved then
			restore()
		end
	end)
	return myToken
end

-- Gives the camera back, unless a newer cutscene has taken it since.
function CameraDirector.release(myToken: number)
	if myToken == token and saved then
		restore()
	end
end

-- Puts the camera somewhere at once.
function CameraDirector.cut(myToken: number, cframe: CFrame, fov: number?)
	if myToken ~= token or not saved then
		return
	end
	if tween then
		tween:Cancel()
		tween = nil
	end
	local cam = camera()
	cam.CFrame = cframe
	if fov then
		cam.FieldOfView = fov
	end
end

-- Moves the camera to cframe over `seconds`. Returns the tween (nil if not in control).
function CameraDirector.move(
	myToken: number,
	cframe: CFrame,
	seconds: number,
	fov: number?,
	style: Enum.EasingStyle?
): Tween?
	if myToken ~= token or not saved then
		return nil
	end
	if tween then
		tween:Cancel()
	end
	local props: { [string]: any } = { CFrame = cframe }
	if fov then
		props.FieldOfView = fov
	end
	local newTween = TweenService:Create(
		camera(),
		TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		props
	)
	tween = newTween
	newTween:Play()
	return newTween
end

-- A small random shake for impacts (respects the camera shake setting in the caller).
function CameraDirector.shake(myToken: number, strength: number, seconds: number)
	if myToken ~= token or not saved then
		return
	end
	task.spawn(function()
		local started = os.clock()
		local cam = camera()
		while os.clock() - started < seconds and myToken == token and saved do
			local fade = 1 - (os.clock() - started) / seconds
			local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength * fade
			cam.CFrame = cam.CFrame * CFrame.new(offset)
			task.wait()
		end
	end)
end

function CameraDirector.init()
	LocalPlayer.CharacterAdded:Connect(function()
		if saved then
			token += 1
			restore()
		end
	end)
	ClientState.PhaseChanged:Connect(function()
		if saved and not ClientState.public.active then
			token += 1
			restore()
		end
	end)
end

return CameraDirector
