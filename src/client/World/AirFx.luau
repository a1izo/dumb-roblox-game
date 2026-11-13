--!strict
-- Air you can see (the owner's graphics plan, 2026-11-13, phase 5): each map gets one kind of visible air the other two
-- do not, so the three read apart even in a still frame.
--
--   Tokyo   neon haze: a faint, slow bank of fog hanging in front of each lit sign and street lamp, in its own colour,
--           so the signs' light has something to catch in the rain-wet air (the lamps behind it are the ones
--           lightbook.sign_glow and the lane lamps add: SpotLights facing out of a wall, in a colour).
--   Campus  lamp posts: a warm halo round the head of each post (the snow in the air round a lamp) and snow that falls
--           denser inside each lamp's cone than outside it.
--   HQ      the lamps' shafts and dust (World/LampHaze), a touch stronger near the outside glass.
--
-- All of it is left out in Low quality mode (Motion.isLow). Under Reduce motion the halos and banks stay and nothing
-- drifts (the emitters go quiet). Only what is near the camera is drawn (NEAR). Built from the map's own lamps, one
-- holder part each in the camera (nothing is replicated), and rebuilt when the map changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Create = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Create"))

local Emit = require(script.Parent.Parent.Presentation.Vfx.Emit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Textures = require(script.Parent.Parent.UI.Kit.Textures)
local LightingController = require(script.Parent.LightingController)

local AirFx = {}

local NEAR = 85 -- studs from the camera within which the air is drawn
local UPDATE = 0.25
local SIGN_SATURATION = 90 -- the widest gap between a colour's channels below which it is "white" (lightbook.sign_glow)
local HAZE_AHEAD = 3.4 -- how far out of the sign's face its bank hangs
local HALO = 9 -- a lamp post's halo, studs across
local SNOW_RATE = 4 -- flakes a second in a lamp's cone, before Emit.share

type Item = {
	holder: Part,
	emitter: ParticleEmitter?,
	halo: BillboardGui?,
	at: Vector3,
	base: number, -- the emitter's rate at full share
	drifts: NumberRange?, -- a bank's drift speed (still under Reduce motion); nil for snow, which stops altogether
}

local items: { Item } = {}
local builtFor: Instance? = nil
local lastUpdate = 0

local function clear()
	for _, item in ipairs(items) do
		item.holder:Destroy()
	end
	table.clear(items)
end

local function holderAt(position: Vector3, size: Vector3): Part
	return Create("Part", {
		Name = "AirFx",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = size,
		CFrame = CFrame.new(position),
		Parent = workspace.CurrentCamera,
	}) :: Part
end

local function saturated(color: Color3): boolean
	return math.max(color.R, color.G, color.B) - math.min(color.R, color.G, color.B) >= SIGN_SATURATION / 255
end

-- Tokyo: a bank of haze in front of a coloured spot that shines out of a wall.
local function neonHaze(light: SpotLight, anchor: BasePart, glow: string)
	local ahead = anchor.CFrame.LookVector
	local at = anchor.Position + ahead * HAZE_AHEAD
	local holder = holderAt(at, Vector3.new(5, 4, 5))
	local emitter = Create("ParticleEmitter", {
		Texture = glow,
		Color = ColorSequence.new(light.Color),
		LightEmission = 0.6,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 6),
			NumberSequenceKeypoint.new(1, 11),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.94),
			NumberSequenceKeypoint.new(0.7, 0.94),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(7, 11),
		Rate = 0.5,
		Speed = NumberRange.new(0.1, 0.4),
		SpreadAngle = Vector2.new(180, 180),
		RotSpeed = NumberRange.new(-8, 8),
		Shape = Enum.ParticleEmitterShape.Box,
		Parent = holder,
	}) :: ParticleEmitter
	table.insert(items, { holder = holder, emitter = emitter, halo = nil, at = at, base = 0.5, drifts = emitter.Speed })
end

-- Campus: a halo at a lamp post's head and snow falling in its cone.
local function postAir(light: SpotLight, anchor: BasePart, glow: string)
	local from = anchor.Position
	local holder = holderAt(from, Vector3.new(0.2, 0.2, 0.2))
	local halo = Create("BillboardGui", {
		Size = UDim2.fromScale(HALO, HALO), -- (a billboard's scale is studs)
		LightInfluence = 0,
		AlwaysOnTop = false,
		Adornee = holder,
		Parent = holder,
	}) :: BillboardGui
	Create("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = glow,
		ImageColor3 = light.Color,
		ImageTransparency = 0.84,
		Parent = halo,
	})
	local drop = 10
	local cone = holderAt(from - Vector3.new(0, drop * 0.5, 0), Vector3.new(8, drop, 8))
	cone.Parent = holder
	local emitter = Create("ParticleEmitter", {
		Texture = glow,
		Color = ColorSequence.new(Color3.fromRGB(255, 244, 228)),
		LightEmission = 0.7,
		LightInfluence = 0,
		Size = NumberSequence.new(0.14),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.25),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 4),
		Rate = SNOW_RATE,
		Speed = NumberRange.new(0.4, 1.2),
		Acceleration = Vector3.new(0, -2.2, 0),
		SpreadAngle = Vector2.new(30, 30),
		Shape = Enum.ParticleEmitterShape.Box,
		Parent = cone,
	}) :: ParticleEmitter
	table.insert(items, { holder = holder, emitter = emitter, halo = halo, at = from, base = SNOW_RATE, drifts = nil })
end

local function build(map: Instance)
	clear()
	builtFor = map
	local glow = Textures.id("AuraGlow")
	if glow == "" then
		builtFor = nil -- (tried again once the texture is in)
		return
	end
	local mapId = map:GetAttribute("MapId")
	for _, light in ipairs(map:GetDescendants()) do
		local anchor = light.Parent
		if light:IsA("SpotLight") and anchor and anchor:IsA("BasePart") and anchor.Name == "Light" then
			if mapId == "TokyoDistrict" then
				if light.Face == Enum.NormalId.Front and light.Angle >= 150 and saturated(light.Color) then
					neonHaze(light, anchor, glow)
				end
			elseif mapId == "UniversityCampus" then
				-- (a post's head or a prop lamp: a wide spot down, not one of the pools in a ceiling, which carry LShadowOk)
				if
					light.Face == Enum.NormalId.Bottom
					and light.Angle >= 110
					and light:GetAttribute("LShadowOk") ~= true
					and anchor.Position.Y > 5
				then
					postAir(light, anchor, glow)
				end
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
		if #items > 0 then
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
	local share = Emit.share()
	local still = Motion.isReduced()
	for _, item in ipairs(items) do
		local near = (item.at - eye).Magnitude < NEAR
		local emitter = item.emitter
		if emitter then
			-- (Reduce motion: a bank hangs where it is and snow stops falling; the halos stay)
			emitter.Rate = if near and not (still and item.drifts == nil) then item.base * share else 0
			if item.drifts then
				emitter.Speed = if still then NumberRange.new(0) else item.drifts
				emitter.RotSpeed = if still then NumberRange.new(0) else NumberRange.new(-8, 8)
			end
		end
		if item.halo then
			item.halo.Enabled = near
		end
	end
end

function AirFx.init()
	RunService.Heartbeat:Connect(step)
	Textures.whenReady(function()
		builtFor = nil
	end)
end

return AirFx
