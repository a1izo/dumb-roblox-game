--!strict
-- In a case's free roam the camera rides over your right shoulder, close and fixed, as in the user's picture
-- (2026-10-27): the mouse turns the view and your body turns with it (what shift lock does, but always on), and the
-- pointer stays in the middle of the screen, drawn as the closed-eyes mark (UI/Cursor). It is freed while a screen
-- that needs it is open (the emote wheel, a case file, the Manual, the hack screen, a menu: UI/Core/Router; Roblox's
-- own menu frees it by itself) and locked again the moment it closes.
--
-- Only for the living, in free roam: not in a meeting or a vote, in the lobby, while a cutscene holds the camera
-- (Presentation/CameraDirector), for a Specter or a spectator. On a touch screen or a pad there is no pointer to
-- lock: the view still sits over the shoulder, the body still turns with it, the stick turns it.
--
-- Roblox's own shift lock is off in a case (its offset would add to this one, and it swung the camera round a
-- seated body at a meeting's table) and back on in the lobby: the server switches it (Player.DevEnableMouseLock is
-- the server's to set), Services/RoundService and Services/GhostService.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Cursor = require(script.Parent.Parent.UI.Cursor)

local ShoulderCam = {}

local ZOOM = 7 -- studs from the head to the camera (fixed: the user's picture)
local OFFSET = Vector3.new(2.1, 0.35, 0) -- over the right shoulder, a little above the head
local PRIORITY = Enum.RenderPriority.Camera.Value + 1 -- after Roblox's camera has moved

local LocalPlayer = Players.LocalPlayer

local active = false
local saved: { min: number, max: number, rotation: Enum.RotationType }? = nil

local function humanoid(): Humanoid?
	local character = LocalPlayer.Character
	local found = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if found and found.Health > 0 then found else nil
end

-- Is the shoulder view wanted right now?
local function wanted(body: Humanoid?): boolean
	if not body or not ClientState.isLiving() or ClientState.phase() ~= "Investigation" then
		return false
	end
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject == body
end

local function enter(body: Humanoid)
	active = true
	saved = {
		min = LocalPlayer.CameraMinZoomDistance,
		max = LocalPlayer.CameraMaxZoomDistance,
		rotation = UserGameSettings.RotationType,
	}
	body.CameraOffset = OFFSET
end

local function leave()
	active = false
	local before = saved
	saved = nil
	if before then
		LocalPlayer.CameraMinZoomDistance = before.min
		LocalPlayer.CameraMaxZoomDistance = math.max(before.max, before.min)
		UserGameSettings.RotationType = before.rotation
	end
	local body = humanoid()
	if body then
		body.CameraOffset = Vector3.zero
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Cursor.setLocked(false)
end

local function step()
	local body = humanoid()
	local want = wanted(body)
	if want and not active and body then
		enter(body)
	elseif not want and active then
		leave()
	end
	if not active or not body then
		return
	end
	if LocalPlayer.CameraMinZoomDistance ~= ZOOM or LocalPlayer.CameraMaxZoomDistance ~= ZOOM then
		LocalPlayer.CameraMaxZoomDistance = ZOOM
		LocalPlayer.CameraMinZoomDistance = ZOOM
	end
	if body.CameraOffset ~= OFFSET then
		body.CameraOffset = OFFSET
	end
	local free = Router.anyOpen() or GuiService.MenuIsOpen
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = if free then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
		Cursor.setLocked(not free)
	end
	-- (the body faces where the camera looks, as with shift lock; not while a screen is up)
	local rotation = if free then Enum.RotationType.MovementRelative else Enum.RotationType.CameraRelative
	if UserGameSettings.RotationType ~= rotation then
		UserGameSettings.RotationType = rotation
	end
end

-- Is the camera over the shoulder now (for checks)?
function ShoulderCam.isActive(): boolean
	return active
end

function ShoulderCam.init()
	RunService:BindToRenderStep("DeathsGambit_Shoulder", PRIORITY, step)
end

return ShoulderCam
