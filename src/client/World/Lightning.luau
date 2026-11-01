--!strict
-- A lightning strike as each player sees it (the owner, 2026-11-01: "make them real", seen only near the windows that
-- look outside). In the open the whole scene flashes, as before. Inside, the light comes in through the outside glass:
-- a hard, cold moonlight burst from just outside each pane near you, throwing the mullions' and your own shadows
-- across the floor, and the screen's flash fades with how far you are from that glass (the next room gets a glow
-- through the doorway). Deep inside, away from any big outside window, there is no flash at all: only the thunder's
-- thud (RainController plays it) and the room's own lamps dipping for a moment, as if the storm hit the power.
--
-- The outside glass is the map's colliders whose look is a curtain wall's (SceneBuilder sets the Look attribute).

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Create = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Create"))

local Blackout = require(script.Parent.Blackout)
local LightingController = require(script.Parent.LightingController)
local Shelter = require(script.Parent.Shelter)

local Lightning = {}

-- The looks of glass that faces outside.
local WINDOW_LOOKS = { CurtainGlass = true }
local NEAR = 6 -- studs from the glass at which its flash is full
local FADE = 34 -- and over this many more it fades to nothing
local REACH = 70 -- panes further than this are not lit at all
local FLOOR = 10 -- panes more than this far above or below the camera are another floor's
local BURSTS = 3 -- at most this many panes throw light in at once
local DIP_BELOW = 0.35 -- under this much flash, the room's lamps dip instead
local DIP_RADIUS = 36
local MOON = Color3.fromRGB(198, 214, 255)

local panes: { BasePart } = {}
local panesOf: Instance? = nil

local function gather(map: Instance?)
	if map == panesOf then
		return
	end
	panesOf = map
	table.clear(panes)
	if not map then
		return
	end
	for _, item in ipairs(map:GetDescendants()) do
		if item:IsA("BasePart") and WINDOW_LOOKS[item:GetAttribute("Look") :: any] then
			table.insert(panes, item)
		end
	end
end

local function focus(): Vector3
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable and root and root:IsA("BasePart") then
		return root.Position
	end
	return if camera then camera.CFrame.Position else Vector3.zero
end

-- The nearest point of a pane's box to `at`, and the pane's outward side (away from `at`).
local function nearest(pane: BasePart, at: Vector3): (Vector3, Vector3)
	local cf = pane.CFrame
	local p = cf:PointToObjectSpace(at)
	local half = pane.Size / 2
	local clamped = Vector3.new(
		math.clamp(p.X, -half.X, half.X),
		math.clamp(p.Y, -half.Y, half.Y),
		math.clamp(p.Z, -half.Z, half.Z)
	)
	-- (a pane is thin along one of its axes: that axis is its normal)
	local axis = if pane.Size.X < pane.Size.Z then cf.RightVector else cf.LookVector
	local out = if axis:Dot(cf.Position - at) >= 0 then axis else -axis
	return cf:PointToWorldSpace(clamped), out
end

-- One burst through a pane: a spot just outside it, aimed in and down at where the player stands.
local function burst(point: Vector3, out: Vector3, toward: Vector3)
	local from = point + out * 3 + Vector3.new(0, 7, 0)
	local anchor = Create("Part", {
		Name = "LightningBurst",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.lookAt(from, Vector3.new(toward.X, toward.Y - 2, toward.Z)),
		Parent = workspace.CurrentCamera,
	})
	local light = Create("SpotLight", {
		Face = Enum.NormalId.Front,
		Angle = 75,
		Range = 55,
		Brightness = 0,
		Color = MOON,
		Shadows = true,
		Parent = anchor,
	}) :: SpotLight
	task.spawn(function()
		for _, pulse in ipairs(LightingController.PULSES) do
			light.Brightness = 4 + pulse[1] * 5
			task.wait(pulse[2])
		end
		anchor:Destroy()
	end)
end

-- The room's lamps going down and back, two or three times, as if the storm hit the power.
local function dip(at: Vector3)
	for _, light in ipairs(LightingController.lampsNear(at, DIP_RADIUS)) do
		task.spawn(function()
			for _ = 1, math.random(2, 3) do
				local base = LightingController.lampBrightness(light) or light.Brightness
				light.Brightness = base * (0.15 + math.random() * 0.2)
				task.wait(0.05 + math.random() * 0.08)
				light.Brightness = LightingController.lampBrightness(light) or base
				task.wait(0.06 + math.random() * 0.14)
			end
		end)
	end
end

-- A strike, on this screen. Returns how much of it was seen (0 inside, away from the glass; 1 in the open).
function Lightning.strike(): number
	-- (no storm reaches the cutscene sets, and the lamps are already out in a blackout)
	if LightingController.venue() == "sets" then
		return 0
	end
	gather(workspace:FindFirstChild("LGameMap"))
	local here = focus()
	local open = 1 - Shelter.level()
	local lit = {}
	local seen = 0
	for _, pane in ipairs(panes) do
		if pane.Parent then
			local point, out = nearest(pane, here)
			local distance = (point - here).Magnitude
			if distance <= REACH and math.abs(point.Y - here.Y) <= FLOOR then
				table.insert(lit, { point = point, out = out, distance = distance })
				seen = math.max(seen, 1 - math.clamp((distance - NEAR) / FADE, 0, 1))
			end
		end
	end
	table.sort(lit, function(a, b)
		return a.distance < b.distance
	end)
	-- (neighbouring panes of one wall are one burst: a pane is only lit 12 studs or more from another lit one)
	local made: { Vector3 } = {}
	for _, pane in ipairs(lit) do
		if #made >= BURSTS then
			break
		end
		local apart = true
		for _, other in ipairs(made) do
			if (other - pane.point).Magnitude < 12 then
				apart = false
				break
			end
		end
		if apart then
			table.insert(made, pane.point)
			burst(pane.point, pane.out, here)
		end
	end
	local amount = math.max(open, seen)
	LightingController.lightning(amount)
	if amount < DIP_BELOW and not Blackout.isActive() then
		dip(here)
	end
	return amount
end

return Lightning
