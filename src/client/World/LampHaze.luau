--!strict
-- The air under the lamps (the owner, 2026-11-01: "the atmosphere is missing"). Roblox's Atmosphere is a haze over
-- distance, so inside a room it shows nothing at all; this gives the air in a room something to catch the light: a
-- soft shaft from each ceiling lamp down to the floor (a camera-facing beam in the lamp's colour, faint, widening as
-- it falls) and a few dust motes drifting slowly in its pool. Both follow the lamp: they flicker with it, dim with a
-- mood, go dark in a blackout or a lightning dip, and are left out where the lamp is off.
--
-- A ceiling lamp is a map lamp (SceneBuilder's "Light" anchors) with a floor 7 to 16 studs under it; desk lamps,
-- sconces and screens' spill are not. Only lamps near the camera are kept lit. Off in Low quality mode.
--
-- Near the outside glass (a pane of a curtain wall, the map's colliders of the CurtainGlass look: Bureau HQ's tower)
-- the shafts are up to GLASS_BOOST stronger, where the city's light comes in and the air in front of the glass is the
-- brightest (the owner's graphics plan, 2026-11-13, phase 5).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Create = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Create"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Textures = require(script.Parent.Parent.UI.Kit.Textures)
local LightingController = require(script.Parent.LightingController)

local LampHaze = {}

local DROP = { 7, 16 } -- a ceiling lamp's height over the floor under it
local NEAR = 110 -- studs from the camera within which the shafts are drawn
local SHAFT = 0.93 -- the shaft's transparency at its brightest (just under the lamp)
local GLASS_LOOK = "CurtainGlass" -- the look of the glass that faces outside (SceneBuilder sets the Look attribute)
local GLASS_REACH = 26 -- a lamp this far from a pane or further has its shaft as it was
local GLASS_BOOST = 0.8 -- and one at the glass has it this much stronger
local UPDATE = 0.1

type Haze = {
	light: Light,
	boost: number, -- 1 in the room, up to 1 + GLASS_BOOST at the glass
	base: number,
	beam: Beam,
	dust: ParticleEmitter?,
	at: Vector3,
	holder: Part,
}

local hazes: { Haze } = {}
local builtFor: Instance? = nil
local lastUpdate = 0

local function clear()
	for _, haze in ipairs(hazes) do
		haze.holder:Destroy()
	end
	table.clear(hazes)
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

local function shade(k: number): NumberSequence
	local top = 1 - (1 - SHAFT) * k
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, top),
		NumberSequenceKeypoint.new(0.55, 1 - (1 - top) * 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- How much stronger a lamp's shaft is for the glass near it (1 where there is none).
local function glassBoost(panes: { BasePart }, at: Vector3): number
	local nearest = math.huge
	for _, pane in ipairs(panes) do
		local local_ = pane.CFrame:PointToObjectSpace(at)
		local half = pane.Size / 2
		local edge = Vector3.new(
			math.clamp(local_.X, -half.X, half.X),
			math.clamp(local_.Y, -half.Y, half.Y),
			math.clamp(local_.Z, -half.Z, half.Z)
		)
		nearest = math.min(nearest, (local_ - edge).Magnitude)
	end
	return 1 + GLASS_BOOST * (1 - math.clamp(nearest / GLASS_REACH, 0, 1))
end

local function build(map: Instance)
	clear()
	builtFor = map
	local glow = Textures.id("AuraGlow")
	if glow == "" then
		builtFor = nil -- (tried again once the texture is in)
		return
	end
	local params = rayParams()
	local panes: { BasePart } = {}
	for _, item in ipairs(map:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("Look") == GLASS_LOOK then
			table.insert(panes, item)
		end
	end
	for _, light in ipairs(map:GetDescendants()) do
		local anchor = light.Parent
		if
			(light:IsA("PointLight") or light:IsA("SpotLight"))
			and anchor
			and anchor:IsA("BasePart")
			and anchor.Name == "Light"
			and not anchor:HasTag("LMapEmergency")
		then
			local from = anchor.Position
			local hit = workspace:Raycast(from + Vector3.new(0, -0.3, 0), Vector3.new(0, -DROP[2], 0), params)
			local drop = if hit then from.Y - hit.Position.Y else 0
			if hit and drop >= DROP[1] then
				local holder = Create("Part", {
					Name = "LampHaze",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
					Transparency = 1,
					Size = Vector3.new(0.2, 0.2, 0.2),
					CFrame = CFrame.new(from),
					Parent = workspace.CurrentCamera,
				}) :: Part
				local top = Create("Attachment", { Position = Vector3.new(0, -0.2, 0), Parent = holder })
				local bottom = Create("Attachment", { Position = Vector3.new(0, -drop + 0.2, 0), Parent = holder })
				-- (a pool lamp's shaft is its cone; a round lamp's widens with its reach)
				local spread = if light:IsA("SpotLight")
					then math.clamp(2 * drop * math.tan(math.rad(light.Angle / 2)) * 0.75, 5, 16)
					else math.clamp(light.Range * 0.45, 5, 11)
				local beam = Create("Beam", {
					Attachment0 = top,
					Attachment1 = bottom,
					FaceCamera = true,
					Texture = glow,
					TextureMode = Enum.TextureMode.Stretch,
					LightEmission = 1,
					LightInfluence = 0,
					Color = ColorSequence.new(light.Color),
					Width0 = 2.2,
					Width1 = spread,
					Segments = 6,
					Transparency = shade(1),
					Parent = holder,
				}) :: Beam
				local dust = Create("ParticleEmitter", {
					Texture = glow,
					Color = ColorSequence.new(light.Color),
					LightEmission = 0.6,
					LightInfluence = 0,
					Size = NumberSequence.new(0.07),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.3, 0.55),
						NumberSequenceKeypoint.new(0.7, 0.55),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Lifetime = NumberRange.new(6, 10),
					Rate = 1.6,
					Speed = NumberRange.new(0.05, 0.25),
					SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, -0.03, 0),
					RotSpeed = NumberRange.new(-20, 20),
					Shape = Enum.ParticleEmitterShape.Box,
					ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				}) :: ParticleEmitter
				-- (the motes fill the shaft's pool: a box as wide as its foot, most of its height)
				local box = Create("Part", {
					Name = "DustBox",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Transparency = 1,
					Size = Vector3.new(spread * 0.7, drop * 0.7, spread * 0.7),
					CFrame = CFrame.new(from - Vector3.new(0, drop * 0.5, 0)),
					Parent = holder,
				})
				dust.Parent = box
				table.insert(hazes, {
					light = light,
					boost = if #panes > 0 then glassBoost(panes, from) else 1,
					base = LightingController.lampBrightness(light) or light.Brightness,
					beam = beam,
					dust = dust,
					at = from,
					holder = holder,
				})
			end
		end
	end
end

local function step()
	local now = os.clock()
	if now - lastUpdate < UPDATE then
		return
	end
	lastUpdate = now
	local map = workspace:FindFirstChild("LGameMap")
	local wanted = not Motion.isLow() and map ~= nil and LightingController.venue() == "map"
	if not wanted then
		if #hazes > 0 then
			clear()
			builtFor = nil
		end
		return
	end
	if map ~= builtFor then
		build(map :: Instance)
	end
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, haze in ipairs(hazes) do
		local light = haze.light
		local near = (haze.at - eye).Magnitude < NEAR
		local resting = LightingController.lampBrightness(light) or haze.base
		local k = if light.Parent
				and light.Enabled
				and resting > 0
			then math.clamp(light.Brightness / math.max(resting, 0.01), 0, 1.4)
			else 0
		haze.beam.Enabled = near and k > 0.05
		if haze.beam.Enabled then
			haze.beam.Transparency = shade(math.min(k, 1) * haze.boost)
		end
		local dust = haze.dust
		if dust then
			dust.Enabled = near and k > 0.5 and not Motion.isReduced()
		end
	end
end

function LampHaze.init()
	RunService.Heartbeat:Connect(step)
	Textures.whenReady(function()
		builtFor = nil
	end)
end

return LampHaze
