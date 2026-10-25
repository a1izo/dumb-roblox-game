-- Effects for deaths and big moments, local to this client, in the Notch style: a burst of black, white and
-- red shards, a chalk outline of the body on the floor that fades, static rising off a body while it
-- dissolves, sparks, and a dark red wash over your own screen when you are taken out. The bursts, sparks and
-- wisps are layered from the VFX kit (Presentation/Vfx); the shard, chalk and static textures are the Core
-- set's (Assets.texture), the chalk outline skipped until they are imported.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.UI.Screens)
local Vfx = require(script.Parent.Vfx)

local C = Kit.color

local DeathFx = {}

DeathFx.DARK = C.g0
DeathFx.CHALK = C.white
DeathFx.DANGER = C.danger

-- A particle emitter with a Blender texture when there is one (Roblox's default otherwise).
local function emitter(textureName: string, props: { [string]: any }): ParticleEmitter
	local texture = Assets.texture(textureName)
	if texture ~= "" then
		props.Texture = texture
	end
	return Create("ParticleEmitter", props)
end

-- A death's burst from a point (the VFX kit, 2026-10-25): a white star that opens and is gone, a dark burst
-- behind it, shards flung out tumbling and falling (dark, white and a little red for a death; the colour and its
-- pale for anything else), white-hot streaks, red specks drifting, a low dark smoke rolling out, and the light it
-- throws.
function DeathFx.burst(position: Vector3, colour: Color3?, amount: number?)
	local base = colour or DeathFx.DARK
	local count = amount or 36
	local death = base == DeathFx.DARK
	local palette = if death
		then { { 0, base }, { 0.5, DeathFx.CHALK }, { 1, DeathFx.DANGER } }
		else { { 0, base }, { 1, base:Lerp(Color3.new(1, 1, 1), 0.5) } }
	local list: { any } = {
		{
			{
				tex = "VfxFlare",
				color = Color3.new(1, 1, 1),
				size = { { 0, 2 }, { 0.25, 7.5 }, { 1, 1 } },
				alpha = { { 0, 0 }, { 0.5, 0.2 }, { 1, 1 } },
				life = 0.24,
				rot = { 0, 360 },
				bright = 1.5,
				z = 2,
			},
			1,
		},
		{
			{
				-- (laid over the scene, not added: a dark burst reads against any light)
				tex = "VfxBurst",
				color = if death then Color3.fromRGB(8, 6, 8) else base,
				size = { { 0, 2 }, { 0.12, 9.5 }, { 1, 11 } },
				alpha = { { 0, 0 }, { 0.45, 0.15 }, { 1, 1 } },
				life = 0.34,
				light = if death then 0 else 0.3,
				rot = { 0, 360 },
				z = 1,
			},
			1,
		},
		{
			{
				tex = "VfxRing",
				color = DeathFx.CHALK,
				size = { { 0, 1 }, { 1, 13 } },
				alpha = { { 0, 0.1 }, { 0.5, 0.5 }, { 1, 1 } },
				life = 0.3,
				light = 0.5,
				bright = 1.1,
				z = 1.5,
			},
			1,
		},
		{
			{
				name = "Shards",
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = palette,
				size = { { 0, 0.65 }, { 1, 0.12 } },
				life = { 0.55, 1 },
				speed = { 12, 26 },
				spread = 180,
				accel = Vector3.new(0, -60, 0),
				drag = 2,
				rot = { 0, 360 },
				spin = { -420, 420 },
				light = 0.15,
				bright = 1.1,
			},
			count,
		},
		{
			{
				name = "Shards",
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = palette,
				size = { { 0, 1.5 }, { 1, 0.45 } },
				life = { 0.7, 1.1 },
				speed = { 4, 10 },
				spread = 180,
				accel = Vector3.new(0, -50, 0),
				drag = 1.5,
				rot = { 0, 360 },
				spin = { -200, 200 },
				light = 0.1,
			},
			math.max(3, math.floor(count / 6)),
		},
	}
	if not Vfx.quiet() then
		table.insert(list, {
			{
				tex = "VfxStreak",
				color = { { 0, Color3.new(1, 1, 1) }, { 1, if death then DeathFx.DANGER else base } },
				size = { { 0, 0.35 }, { 1, 0.08 } },
				squash = -2,
				life = { 0.25, 0.5 },
				speed = { 30, 56 },
				drag = 4,
				accel = Vector3.new(0, -50, 0),
				spread = 180,
				face = "along",
				bright = 1.4,
			},
			math.floor(count * 0.6),
		})
		table.insert(list, {
			{
				tex = "VfxEmber",
				color = if death then DeathFx.DANGER else base,
				size = { { 0, 0.22 }, { 1, 0 } },
				life = { 0.9, 1.6 },
				speed = { 3, 9 },
				drag = 2.5,
				accel = Vector3.new(0, 2.5, 0),
				spread = 180,
				bright = 1.3,
			},
			math.floor(count * 0.4),
		})
		table.insert(list, {
			{
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = if death then Color3.fromRGB(26, 24, 28) else base:Lerp(Color3.new(0.5, 0.5, 0.5), 0.4),
				light = 0,
				lit = 0.35,
				size = { { 0, 1.6 }, { 1, 4.6 } },
				alpha = { { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } },
				life = { 1.1, 1.7 },
				speed = { 5, 11 },
				drag = 3,
				spread = { 85, 85 },
				rot = { 0, 360 },
				spin = { -30, 30 },
			},
			6,
		})
	end
	local holder = Vfx.Emit.burst(position, list)
	-- (the Core set's broken shard where it is imported, one picture; the kit's broken chunks until then)
	local shard = Assets.texture("FxShard")
	if shard ~= "" then
		for _, e in ipairs(holder:GetChildren()) do
			if e:IsA("ParticleEmitter") and e.Name == "Shards" then
				e.Texture = shard
				e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
			end
		end
	end
	Vfx.Light.flash(position + Vector3.new(0, 1, 0), if death then DeathFx.DANGER else base, 20, 3.5, 0.45)
end

-- A chalk outline of a body on the ground under a point, fading after `seconds`.
function DeathFx.chalk(position: Vector3, size: number?, colour: Color3?, seconds: number?)
	local texture = Assets.texture("FxChalk")
	if texture == "" then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The floor, not bodies or effects.
	local ignore: { Instance } = { workspace.CurrentCamera }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end
	local s = size or 6
	local helper = if math.abs(hit.Normal.Y) > 0.9 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = hit.Normal:Cross(helper).Unit
	local plate = Create("Part", {
		Name = "DeathChalk",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(s, 0.05, s),
		CFrame = CFrame.fromMatrix(hit.Position + hit.Normal * 0.03, right, hit.Normal)
			* CFrame.Angles(0, math.random() * math.pi * 2, 0),
		Parent = workspace.CurrentCamera,
	})
	local decal = Create("Decal", {
		Face = Enum.NormalId.Top,
		Texture = texture,
		Color3 = colour or DeathFx.CHALK,
		Transparency = 1,
		Parent = plate,
	})
	-- (a breath of chalk dust off it as it appears)
	if not Vfx.quiet() then
		Vfx.Emit.burst(CFrame.fromMatrix(hit.Position + hit.Normal * 0.1, right, hit.Normal), {
			tex = "VfxDust",
			grid = 4,
			mode = "OneShot",
			color = colour or DeathFx.CHALK,
			light = 0.1,
			lit = 0.5,
			size = { { 0, 0.6 }, { 1, 2.2 } },
			alpha = { { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } },
			life = { 0.7, 1.2 },
			speed = { 2, 5 },
			drag = 3,
			spread = { 85, 85 },
			rot = { 0, 360 },
			spin = { -30, 30 },
		}, 8, Vector3.new(s * 0.6, 0.05, s * 0.6))
	end
	-- It cuts in with a few hard flickers, then stays and fades away.
	task.spawn(function()
		for _, shown in ipairs({ 0, 1, 0, 1, 0.15 }) do
			if not decal.Parent then
				return
			end
			decal.Transparency = shown
			task.wait(0.05)
		end
	end)
	task.delay(seconds or 10, function()
		if decal.Parent then
			local fade = TweenService:Create(decal, TweenInfo.new(2), { Transparency = 1 })
			fade:Play()
			fade.Completed:Once(function()
				plate:Destroy()
			end)
		end
	end)
end

-- Static rising off a character while it fades (voted out).
function DeathFx.dissolve(character: Model, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local noise = emitter("FxStatic", {
		Color = ColorSequence.new(DeathFx.CHALK),
		LightInfluence = 0,
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		Rate = 60,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Parent = root,
	})
	-- (pale wisps lifting off with it, and specks of light)
	local wisps = Vfx.Emit.make(root, {
		tex = "VfxWisp",
		grid = 4,
		mode = "OneShot",
		color = DeathFx.CHALK,
		light = 0.2,
		lit = 0.3,
		size = { { 0, 0.8 }, { 1, 2.6 } },
		alpha = { { 0, 0.55 }, { 0.5, 0.65 }, { 1, 1 } },
		life = { 0.9, 1.4 },
		speed = { 1.5, 3.5 },
		spread = 25,
		rot = { -20, 20 },
		spin = { -30, 30 },
		face = "up",
		rate = if Vfx.quiet() then 0 else 9,
		shape = Enum.ParticleEmitterShape.Box,
	})
	local specks = Vfx.Emit.make(root, {
		tex = "VfxEmber",
		color = DeathFx.CHALK,
		size = { { 0, 0.14 }, { 1, 0 } },
		life = { 0.8, 1.5 },
		speed = { 2, 5 },
		spread = 30,
		accel = Vector3.new(0, 2, 0),
		bright = 1.3,
		rate = if Vfx.quiet() then 0 else 14,
		shape = Enum.ParticleEmitterShape.Box,
	})
	task.delay(seconds, function()
		noise.Enabled = false
		wisps.Enabled = false
		specks.Enabled = false
		Debris:AddItem(noise, 1.5)
		Debris:AddItem(wisps, 1.5)
		Debris:AddItem(specks, 1.6)
	end)
end

-- A spray of sparks (handcuffs clicking shut, Death's Manual landing): a star at the spot, white-hot streaks that
-- fly out and fall, specks that hang a moment, a flick of light.
function DeathFx.sparks(position: Vector3, colour: Color3?)
	local tint = colour or C.white
	Vfx.Emit.burst(position, {
		{
			{
				tex = "VfxFlare",
				color = tint,
				size = { { 0, 0.5 }, { 0.25, 3.2 }, { 1, 0 } },
				life = 0.22,
				rot = { 0, 360 },
				bright = 1.5,
			},
			1,
		},
		{
			{
				tex = "VfxStreak",
				color = { { 0, Color3.new(1, 1, 1) }, { 1, tint } },
				size = { { 0, 0.3 }, { 1, 0.05 } },
				squash = -2,
				life = { 0.25, 0.55 },
				speed = { 14, 26 },
				drag = 3,
				accel = Vector3.new(0, -40, 0),
				spread = 180,
				face = "along",
				bright = 1.5,
			},
			22,
		},
		{
			{
				tex = "VfxEmber",
				color = tint,
				size = { { 0, 0.16 }, { 1, 0 } },
				life = { 0.4, 0.9 },
				speed = { 3, 8 },
				drag = 3,
				spread = 180,
				bright = 1.3,
			},
			10,
		},
	})
	Vfx.Light.flash(position, tint, 10, 2.5, 0.25)
end

-- Your own screen when you are taken out: a steady dark red wash that fades after `seconds`. (Nothing in a
-- match glitches, so there is no tear.)
function DeathFx.screenTear(seconds: number?, colour: Color3?)
	local layer = Instance.new("CanvasGroup")
	layer.Name = "DeathWash"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Parent = Screens.cinematic
	Kit.Base.make("Frame", {
		Name = "Wash",
		BackgroundColor3 = colour or C.blood,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = layer,
	})
	Motion.fade(layer, true, 0.2)
	task.delay(seconds or 2.5, function()
		local fade = Motion.fade(layer, false, 1.2)
		if fade then
			fade.Completed:Once(function()
				layer:Destroy()
			end)
		else
			layer:Destroy()
		end
	end)
end

return DeathFx
