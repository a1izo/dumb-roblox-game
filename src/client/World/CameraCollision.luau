-- Keeps the player camera out of walls, ceilings and big furniture. Roblox's own camera only
-- stops at visible parts that collide; the Blender venues are drawn by meshes that do not
-- collide, and their walls are invisible collider boxes, so the camera slid through both.
-- Every frame, after Roblox's camera has moved, this casts a small sphere from the camera's
-- focus (your head) out to the camera and pulls the camera in front of the first collider
-- tagged LCameraBlock. When the way clears the camera eases back out.
--
-- Off while a cutscene holds the camera and in first person. Specters (and spectators) fly
-- through walls, so their camera ignores colliders; instead it is kept inside the box they fly in (the map's
-- outer walls and ceiling, or the meeting room), so the outside of a place never shows.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Venues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Venues"))

local ClientState = require(script.Parent.Parent.ClientState)
local CameraDirector = require(script.Parent.Parent.Presentation.CameraDirector)

local CameraCollision = {}

CameraCollision.TAG = "LCameraBlock"

local RADIUS = 0.45
local MARGIN = 0.15
local MIN_DISTANCE = 0.6
local EASE_OUT = 10 -- how fast the camera returns once the way is clear (per second)
local FADE_FROM = 1.6 -- your own body fades when the camera is pulled closer than this
local BOX_MARGIN = 0.4 -- a Specter's camera stays this far inside the box's faces

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

local function free(camera: Camera): boolean
	return camera.CameraType == Enum.CameraType.Custom and not CameraDirector.busy()
end

-- How far a camera may go from `focus` along `direction` before it leaves the Specter box of
-- the venue the focus is in (nil when there is no box there, or the focus is outside it).
local function reachInside(focus: Vector3, direction: Vector3): number?
	local venue = Venues.at(focus)
	if venue == "lobby" then
		return nil
	end
	local mapId = if type(ClientState.public.mapId) == "string" then ClientState.public.mapId else nil
	local min, max = Venues.specterBounds(venue, mapId)
	min += Vector3.one * BOX_MARGIN
	max -= Vector3.one * BOX_MARGIN
	if Venues.clampInto(focus, min, max) ~= focus then
		return nil
	end
	local reach = math.huge
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local d = (direction :: any)[axis]
		if d > 1e-6 then
			reach = math.min(reach, ((max :: any)[axis] - (focus :: any)[axis]) / d)
		elseif d < -1e-6 then
			reach = math.min(reach, ((min :: any)[axis] - (focus :: any)[axis]) / d)
		end
	end
	return reach
end

-- A Specter's camera is pulled in along its line to the focus until it is inside the box.
local function keepInside(camera: Camera)
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local length = offset.Magnitude
	if length < 1e-3 then
		return
	end
	local direction = offset / length
	local reach = reachInside(focus, direction)
	if reach and reach < length then
		camera.CFrame = CFrame.new(focus + direction * math.max(reach, 0)) * camera.CFrame.Rotation
	end
end

local function release(character: Model?)
	distance = nil
	if faded then
		faded = false
		setFade(character, 0)
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if not camera or not free(camera) then
		release(character)
		return
	end
	if character and (character:GetAttribute("Specter") or character:GetAttribute("Spectator")) then
		release(character)
		keepInside(camera)
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
	RunService:BindToRenderStep("DeathsGambitCameraCollision", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraCollision
