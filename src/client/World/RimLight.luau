--!strict
-- A faint rim light on the other players (the owner's graphics plan, 2026-11-13, phase 6): on a dark map a body in a
-- dark corridor was a hole the shape of a person. Each player in sight gets a very low light just past their head, on
-- the side away from the camera, so their hair and shoulders catch a thin edge and the face stays as the room lit it
-- (the game is about staring at faces and reading names, so nothing is added in front). It follows the camera round.
--
-- The rules the plan set: it must not give away a player behind a wall (a light without shadows reaches through thin
-- walls, so a player is only rimmed while a ray from the camera to their head meets nothing: no rim for a body
-- hiding behind a prop or a door, and none through a wall), it goes out in a blackout (Blackout), in Low quality mode
-- (Motion.isLow), and anywhere but a map. Your own body is not rimmed (the shoulder camera looks over it).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Blackout = require(script.Parent.Blackout)
local LightingController = require(script.Parent.LightingController)
local Motion = require(script.Parent.Parent.UI.Core.Motion)

local RimLight = {}

local BRIGHTNESS = 0.4
local RANGE = 6.5
local NEAR = 70 -- studs from the camera within which a player is rimmed
local BEHIND = 1.6 -- how far past the head, away from the camera, the light stands
local RAISE = 0.5 -- and how far above it
local SIGHT_EVERY = 0.2 -- seconds between the line-of-sight checks
local FOLLOW = 8 -- how fast the light's strength moves to where it should be (per second)

type Rim = { holder: Part, light: PointLight, seen: boolean, level: number }

local rims: { [Model]: Rim } = {}
local folder: Folder? = nil
local lastSight = 0

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "DGRimLights"
	made.Parent = workspace
	folder = made
	return made
end

local function drop(character: Model)
	local rim = rims[character]
	if rim then
		rim.holder:Destroy()
		rims[character] = nil
	end
end

local function make(character: Model): Rim
	local holder = Instance.new("Part")
	holder.Name = "Rim"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Parent = container()
	local light = Instance.new("PointLight")
	light.Range = RANGE
	light.Brightness = 0
	light.Shadows = false
	light.Parent = holder
	local rim = { holder = holder, light = light, seen = false, level = 0 }
	rims[character] = rim
	return rim
end

-- Whether the camera has a clear line to the character's head (nothing solid between them but bodies).
local function inSight(camera: Camera, head: BasePart, params: RaycastParams): boolean
	local from = camera.CFrame.Position
	local hit = workspace:Raycast(from, head.Position - from, params)
	return hit == nil or hit.Instance:IsDescendantOf(head.Parent :: Instance)
end

local function lit(): boolean
	return LightingController.venue() == "map" and not Blackout.isActive() and not Motion.isLow()
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local on = lit() and camera ~= nil
	local sight = os.clock() - lastSight >= SIGHT_EVERY
	local params: RaycastParams? = nil
	if on and sight then
		lastSight = os.clock()
		-- (Your own body is skipped, the camera sits at its shoulder; another body in front of the head counts.)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local mine = Players.LocalPlayer.Character
		rayParams.FilterDescendantsInstances = if mine then { mine } else {}
		params = rayParams
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if player == Players.LocalPlayer or not character then
			continue
		end
		local head = character:FindFirstChild("Head")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not (head and head:IsA("BasePart")) or not humanoid or humanoid.Health <= 0 then
			drop(character)
			continue
		end
		local rim = rims[character] or make(character)
		local eye = if camera then camera.CFrame.Position else head.Position
		local away = head.Position - eye
		local near = on and away.Magnitude < NEAR
		if near and sight and params and camera then
			rim.seen = inSight(camera, head, params)
		end
		local wanted = if near and rim.seen then BRIGHTNESS else 0
		rim.level += (wanted - rim.level) * math.min(1, dt * FOLLOW)
		rim.light.Brightness = if rim.level < 0.003 then 0 else rim.level
		rim.light.Enabled = rim.level >= 0.003
		if rim.light.Enabled and away.Magnitude > 0.01 then
			rim.holder.Position = head.Position + away.Unit * BEHIND + Vector3.new(0, RAISE, 0)
			-- (the map's cool fill, lifted: the edge is the room's own colour)
			rim.light.Color = game:GetService("Lighting").Ambient:Lerp(Color3.new(1, 1, 1), 0.6)
		end
	end
	for character in pairs(rims) do
		if not character.Parent then
			drop(character)
		end
	end
end

function RimLight.init()
	RunService.PreRender:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			drop(player.Character)
		end
	end)
end

return RimLight
