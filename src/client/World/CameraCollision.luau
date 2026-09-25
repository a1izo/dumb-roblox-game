-- Keeps the player camera out of walls, ceilings and big furniture. Roblox's own camera only
-- stops at visible parts that collide; the Blender venues are drawn by meshes that do not
-- collide, and their walls are invisible collider boxes, so the camera slid through both.
-- Every frame, after Roblox's camera has moved, this casts a small sphere from the camera's
-- focus (your head) out to the camera and pulls the camera in front of the first collider
-- tagged LCameraBlock. When the way clears the camera eases back out.
--
-- Off while a cutscene holds the camera, in first person, and for Specters (they fly through
-- walls).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraDirector = require(script.Parent.Parent.Presentation.CameraDirector)

local CameraCollision = {}

CameraCollision.TAG = "LCameraBlock"

local RADIUS = 0.45
local MARGIN = 0.15
local MIN_DISTANCE = 0.6
local EASE_OUT = 10 -- how fast the camera returns once the way is clear (per second)
local FADE_FROM = 1.6 -- your own body fades when the camera is pulled closer than this

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.IgnoreWater = true

local blockers: { Instance } = {}
local dirty = true
local distance: number? = nil -- where the camera is held, from the focus
local faded = false

local function rebuild()
	blockers = CollectionService:GetTagged(CameraCollision.TAG)
	params.FilterDescendantsInstances = blockers
	dirty = false
end

local function setFade(character: Model?, amount: number)
	if not character then
		return
	end
	for _, item in ipairs(character:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			(item :: any).LocalTransparencyModifier = amount
		end
	end
end

local function active(camera: Camera, character: Model?): boolean
	if camera.CameraType ~= Enum.CameraType.Custom or CameraDirector.busy() then
		return false
	end
	if character and character:GetAttribute("Specter") then
		return false
	end
	return true
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if not camera or not active(camera, character) then
		distance = nil
		if faded then
			faded = false
			setFade(character, 0)
		end
		return
	end
	if dirty then
		rebuild()
	end
	local focus = camera.Focus.Position
	local wanted = camera.CFrame.Position - focus
	local length = wanted.Magnitude
	if length < MIN_DISTANCE or #blockers == 0 then
		distance = nil
		return
	end
	local direction = wanted.Unit
	local allowed = length
	local hit = workspace:Spherecast(focus, RADIUS, wanted, params)
	if hit then
		allowed = math.max(hit.Distance - MARGIN, 0.3)
	end
	-- Pull in at once, ease back out.
	if distance == nil or allowed < distance then
		distance = allowed
	else
		distance = math.min(allowed, distance + (allowed - distance) * math.min(1, dt * EASE_OUT))
	end
	local held = distance :: number
	if held < length - 0.01 then
		camera.CFrame = CFrame.new(focus + direction * held) * camera.CFrame.Rotation
	end
	-- Your own body would fill the screen this close.
	if held < FADE_FROM then
		faded = true
		setFade(character, math.clamp((FADE_FROM - held) / (FADE_FROM - 0.4), 0, 0.85))
	elseif faded then
		faded = false
		setFade(character, 0)
	end
end

function CameraCollision.init()
	CollectionService:GetInstanceAddedSignal(CameraCollision.TAG):Connect(function()
		dirty = true
	end)
	CollectionService:GetInstanceRemovedSignal(CameraCollision.TAG):Connect(function()
		dirty = true
	end)
	RunService:BindToRenderStep("InkboundCameraCollision", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraCollision
