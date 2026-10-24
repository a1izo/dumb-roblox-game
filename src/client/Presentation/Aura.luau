-- The aura kit (the owner's three tutorials of 2026-10-24, "very high quality, not just those simple particles":
-- Twist VFX's "How to Learn Roblox Aura VFX in 1 Hour", TerKungTH's ground aura and body aura guides): an aura is
-- built in layers, each a few soft particles that grow and fade (none pops in or out), tinted from white textures
-- (art/scripts/textures.py: AuraGlow, AuraSpecks, AuraTwinkle, AuraHalo, AuraCrescent, AuraSpikeRing, AuraWisp,
-- AuraBolt; they come with the Core import). By level:
--   1  a glow behind the body held steady (two particles half a life apart on a V of transparency, so they add up
--      to the same light all along), specks rising off it, star flares twinkling on the limbs, a light;
--   2  and wisps swirling round it (an off-centre crescent turned as it goes), faint smoke behind, and on the ground
--      laid flat (VelocityPerpendicular, speed 0.001): a ripple ring, a glow, a spiked ring and crescent slashes
--      spinning round the feet;
--   3  and two beams spiralling up round the body, mirrored, a halo behind the head, sparks of lightning on the
--      limbs, and an edge of light round the body.
-- Few particles alive at once in each layer (the rate against the lifetime), all started together so they stay in
-- step. Made on this client only, marked "DGEmote" (a copy of the body leaves it out); nothing on low graphics.
-- Under reduced motion nothing spins and there are no beams.
--
--   local stop = Aura.start(character, { colour = c, accent = c2, level = 2 })   stop()

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)

local Aura = {}

export type Spec = {
	colour: Color3, -- the aura's colour
	accent: Color3?, -- its flares, rings and lightning (a lighter one by default)
	level: number, -- 1 .. 3 (above)
	scale: number?, -- its size (1 for a body)
	ground: boolean?, -- its ground layer (from level 2; false: none, for one that floats or flies)
}

-- (Roblox's own particle until the Core import brings the kit's textures)
local FALLBACK = "rbxasset://textures/particles/sparkles_main.dds"

local function texture(name: string): string
	local id = Assets.texture(name)
	return if id ~= "" then id else FALLBACK
end

local function seq(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
end

-- (a V: 1 at both ends, `peak` at the middle; two at a time half a life apart add up to a steady light)
local function steady(peak: number): NumberSequence
	return seq({ { 0, 1 }, { 0.5, peak }, { 1, 1 } })
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local base = {
		Name = "DGAura",
		LightEmission = 1,
		LightInfluence = 0,
		Speed = NumberRange.new(0.001),
		Rate = 1,
		Lifetime = NumberRange.new(1),
		Rotation = NumberRange.new(-180, 180),
		Brightness = 1,
		Parent = parent,
	}
	for key, value in pairs(props) do
		base[key] = value
	end
	local item = Create("ParticleEmitter", base) :: ParticleEmitter
	item:SetAttribute("DGEmote", true)
	return item
end

local function attach(parent: Instance, at: Vector3): Attachment
	local item = Create("Attachment", { Name = "DGAura", Position = at, Parent = parent }) :: Attachment
	item:SetAttribute("DGEmote", true)
	return item
end

local function partOf(character: Model, ...: string): BasePart?
	for _, name in ipairs({ ... }) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- The floor under a point (or 3 studs under it), ignoring bodies and what the camera holds.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function floorUnder(at: Vector3, character: Model): Vector3
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

function Aura.start(character: Model, spec: Spec): () -> ()
	local root = partOf(character, "HumanoidRootPart")
	local torso = partOf(character, "Torso", "UpperTorso")
	if not root or not torso or Governor.low("emoteFx") then
		return function() end
	end
	local calm = Motion.isReduced()
	local level = math.clamp(spec.level, 1, 3)
	local k = spec.scale or 1
	local colour = spec.colour
	local accent = spec.accent or colour:Lerp(Color3.new(1, 1, 1), 0.55)
	local deep = colour:Lerp(Color3.new(0, 0, 0), 0.55)
	local made: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local function keep<T>(item: T): T
		local instance = item :: any
		table.insert(made, instance)
		if instance:IsA("ParticleEmitter") then
			table.insert(emitters, instance)
		end
		return item
	end
	local tint = ColorSequence.new(colour)

	-- 1: the glow behind the body, the specks off it, the limbs' flares, a light
	local core = keep(attach(torso, Vector3.zero))
	keep(emitter(core, {
		Texture = texture("AuraGlow"),
		Color = tint,
		Size = NumberSequence.new(7 * k),
		Transparency = steady(0.62),
		Lifetime = NumberRange.new(1),
		Rate = 2,
		LockedToPart = true,
		Rotation = NumberRange.new(0),
		ZOffset = -1.5,
	}))
	keep(emitter(torso, {
		Texture = texture("AuraSpecks"),
		Color = ColorSequence.new(accent, colour),
		Size = seq({ { 0, 0 }, { 0.25, 2.2 * k, 0.4 * k }, { 1, 0 } }),
		Transparency = seq({ { 0, 0.4 }, { 0.7, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.0, 1.6),
		Rate = 3,
		Speed = NumberRange.new(0.8, 1.8),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		RotSpeed = NumberRange.new(-40, 40),
		Acceleration = Vector3.new(0, 1.2, 0),
		Drag = 1,
	}))
	for _, name in ipairs({ "Right Arm", "Left Arm", "Right Leg", "Left Leg" }) do
		local limb = partOf(character, name)
		if limb then
			keep(emitter(limb, {
				Texture = texture("AuraTwinkle"),
				Color = ColorSequence.new(Color3.new(1, 1, 1), accent),
				Size = seq({ { 0, 0 }, { 0.3, 1.2 * k, 0.3 * k }, { 1, 0 } }),
				Transparency = seq({ { 0, 0.1 }, { 1, 0.6 } }),
				Lifetime = NumberRange.new(0.35, 0.6),
				Rate = 1.1,
				Rotation = NumberRange.new(0, 90),
				RotSpeed = NumberRange.new(-30, 30),
				ZOffset = 0.5,
			}))
			if level >= 3 then
				-- (sparks of lightning: a fork of the four at random, held for its short life)
				keep(emitter(limb, {
					Texture = texture("AuraBolt"),
					FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
					FlipbookMode = Enum.ParticleFlipbookMode.Loop,
					FlipbookFramerate = NumberRange.new(0.01),
					FlipbookStartRandom = true,
					Color = ColorSequence.new(accent),
					Size = NumberSequence.new(1.6 * k, 0.6 * k),
					Transparency = seq({ { 0, 0 }, { 1, 0.8 } }),
					Lifetime = NumberRange.new(0.1, 0.18),
					Rate = 1.4,
					ZOffset = 0.6,
				}))
			end
		end
	end
	local light = keep(Create("PointLight", {
		Name = "DGAura",
		Color = colour,
		Range = 9 * k,
		Brightness = 0,
		Shadows = false,
		Parent = torso,
	}) :: PointLight)
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 1.3 }):Play()

	-- 2: the wisps, the smoke, the ground
	local ground: BasePart? = nil
	if level >= 2 then
		keep(emitter(torso, {
			Texture = texture("AuraCrescent"),
			Color = ColorSequence.new(accent, colour),
			Size = seq({ { 0, 1.6 * k }, { 1, 3.2 * k } }),
			Transparency = seq({ { 0, 1 }, { 0.15, 0.35 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.6, 1.0),
			Rate = 4,
			Speed = NumberRange.new(1, 2.6),
			SpreadAngle = Vector2.new(180, 180),
			RotSpeed = if calm then NumberRange.new(0) else NumberRange.new(-140, 140),
			Drag = 2,
			ZOffset = 0.4,
		}))
		keep(emitter(torso, {
			Texture = texture("Smoke"),
			Color = ColorSequence.new(deep),
			LightEmission = 0.3,
			Size = seq({ { 0, 3.5 * k }, { 1, 7 * k } }),
			Transparency = seq({ { 0, 1 }, { 0.3, 0.86 }, { 1, 1 } }),
			Lifetime = NumberRange.new(1.6, 2.2),
			Rate = 1.8,
			Speed = NumberRange.new(0.4, 1),
			EmissionDirection = Enum.NormalId.Top,
			RotSpeed = NumberRange.new(-20, 20),
			ZOffset = -2,
		}))
		if spec.ground ~= false then
			ground = keep(Create("Part", {
				Name = "DGAuraGround",
				Size = Vector3.new(0.2, 0.2, 0.2),
				Transparency = 1,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				CFrame = CFrame.new(floorUnder(root.Position, character) + Vector3.new(0, 0.08, 0)),
				Parent = workspace.CurrentCamera,
			}) :: BasePart)
			local flat = {
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Top,
				ZOffset = 0,
			}
			local function onGround(props: { [string]: any })
				for key, value in pairs(flat) do
					props[key] = value
				end
				keep(emitter(ground :: BasePart, props))
			end
			onGround({
				Texture = texture("AuraHalo"),
				Color = ColorSequence.new(accent, colour),
				Size = seq({ { 0, 2 * k }, { 1, 10 * k } }),
				Transparency = seq({ { 0, 1 }, { 0.1, 0.35 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.4),
				Rate = 0.9,
			})
			onGround({
				Texture = texture("AuraGlow"),
				Color = tint,
				Size = NumberSequence.new(9 * k),
				Transparency = steady(0.55),
				Lifetime = NumberRange.new(1),
				Rate = 2,
				Rotation = NumberRange.new(0),
			})
			onGround({
				Texture = texture("AuraSpikeRing"),
				Color = ColorSequence.new(accent),
				Size = seq({ { 0, 3 * k }, { 1, 7 * k } }),
				Transparency = seq({ { 0, 1 }, { 0.15, 0.5 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.8),
				Rate = 0.6,
				RotSpeed = if calm then NumberRange.new(0) else NumberRange.new(-30, 30),
			})
			onGround({
				Texture = texture("AuraCrescent"),
				Color = ColorSequence.new(accent, colour),
				Size = NumberSequence.new(6 * k, 7.5 * k),
				Transparency = seq({ { 0, 1 }, { 0.2, 0.45 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.5, 0.8),
				Rate = 3,
				RotSpeed = if calm then NumberRange.new(0) else NumberRange.new(170, 260),
			})
		end
	end

	-- 3: the spiral beams, the halo, the edge of light
	local beamEnds: { { low: Attachment, high: Attachment, turn: number } } = {}
	if level >= 3 then
		local head = partOf(character, "Head")
		if head then
			local back = keep(attach(head, Vector3.new(0, 0.15, 0.7)))
			keep(emitter(back, {
				Texture = texture("AuraHalo"),
				Color = ColorSequence.new(accent),
				Size = NumberSequence.new(2.8 * k),
				Transparency = steady(0.45),
				Lifetime = NumberRange.new(1),
				Rate = 2,
				LockedToPart = true,
				Rotation = NumberRange.new(0),
				RotSpeed = if calm then NumberRange.new(0) else NumberRange.new(25),
				ZOffset = -1,
			}))
		end
		if ground and not calm then
			for i, curve in ipairs({ 4.5, -4.5 }) do
				local low = keep(attach(ground, Vector3.zero))
				local high = keep(attach(ground, Vector3.new(0, 7.5 * k, 0)))
				keep(Create("Beam", {
					Name = "DGAura",
					Attachment0 = low,
					Attachment1 = high,
					CurveSize0 = curve * k,
					CurveSize1 = -curve * k,
					FaceCamera = true,
					Segments = 40,
					Texture = texture("AuraWisp"),
					TextureMode = Enum.TextureMode.Wrap,
					TextureLength = 4,
					TextureSpeed = 1.2,
					Width0 = 0.25 * k,
					Width1 = 0.7 * k,
					LightEmission = 1,
					LightInfluence = 0,
					Color = ColorSequence.new(colour, accent),
					Transparency = seq({ { 0, 1 }, { 0.15, 0.4 }, { 0.85, 0.45 }, { 1, 1 } }),
					Parent = ground,
				}))
				table.insert(beamEnds, { low = low, high = high, turn = (i - 1) * math.pi })
			end
		end
		if not character:FindFirstChildWhichIsA("Highlight") then
			keep(Create("Highlight", {
				Name = "DGAura",
				Adornee = character,
				FillColor = colour,
				OutlineColor = accent,
				FillTransparency = 0.88,
				OutlineTransparency = 0.55,
				DepthMode = Enum.HighlightDepthMode.Occluded,
				Parent = character,
			}))
		end
	end
	for _, item in ipairs(made) do
		item:SetAttribute("DGEmote", true)
	end

	-- The ground follows the feet (a beat behind on the floor's height); the beams turn round the body.
	local spin = 0
	local sinceFloor = 1
	local floorY = if ground then ground.Position.Y else 0
	local follow = RunService.RenderStepped:Connect(function(dt: number)
		if not ground or not root.Parent then
			return
		end
		sinceFloor += dt
		if sinceFloor > 0.12 then
			sinceFloor = 0
			floorY = floorUnder(root.Position, character).Y + 0.08
		end
		ground.CFrame = CFrame.new(root.Position.X, floorY, root.Position.Z)
		spin += dt * 1.3
		for _, ends in ipairs(beamEnds) do
			local a = spin + ends.turn
			ends.low.Position = Vector3.new(math.cos(a) * 1.4 * k, 0.2, math.sin(a) * 1.4 * k)
			ends.high.Position = Vector3.new(math.cos(a + 2.2) * 1.2 * k, 7.5 * k, math.sin(a + 2.2) * 1.2 * k)
		end
	end)

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		for _, item in ipairs(emitters) do
			item.Enabled = false
		end
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		for _, item in ipairs(made) do
			if item:IsA("Beam") then
				item.Enabled = false
			elseif item:IsA("Highlight") then
				TweenService:Create(item, TweenInfo.new(0.4), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			end
		end
		-- (the longest life, the smoke's, is 2.2 s: everything has faded by then)
		task.delay(2.3, function()
			follow:Disconnect()
			for _, item in ipairs(made) do
				item:Destroy()
			end
		end)
	end
end

return Aura
