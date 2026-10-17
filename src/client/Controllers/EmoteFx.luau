-- The emote pack's effects round a character while its emote plays (EmoteController starts them and clears
-- them when the emote ends; each returns a function that clears it away): a beam of light from above for
-- New World, signs rising round Menacing Pose, a battery running down over Low Battery's head, red eyes
-- for Reaper's Eyes. Everything is made on this client only, and what is put on the body is marked "DGEmote"
-- (a copy of the body leaves it out). A preview (the shop's copy in its 3D view)
-- gets only what a 3D view can show: no lights, no billboards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))

local Cinema = require(script.Parent.Parent.Presentation.Cinema)
local ClientState = require(script.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)

local EmoteFx = {}

type Fx = (character: Model, preview: boolean) -> () -> ()

local function nothing() end

-- The floor under a point (or 3 studs under it when nothing is found), ignoring characters' own parts.
local function floorUnder(at: Vector3, character: Model): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

local FX: { [string]: Fx } = {}

-- New World: a hard light from above and a pale column of it standing round the body.
FX.newWorld = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local warm = Color3.fromRGB(255, 244, 214)
	local removeLight = Cinema.spotlight(character, warm)
	local floor = floorUnder(root.Position, character)
	local column = Create("Part", {
		Name = "EmoteBeam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(26, 3.4, 3.4),
		CFrame = CFrame.new(floor + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = warm,
		Material = Enum.Material.Neon,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	TweenService:Create(column, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Transparency = 0.84 }):Play()
	return function()
		removeLight()
		local fade = TweenService:Create(column, TweenInfo.new(0.5), { Transparency = 1 })
		fade.Completed:Once(function()
			column:Destroy()
		end)
		fade:Play()
	end
end

-- Menacing Pose: the sign of menace rising and fading round the body, one after another.
FX.menacingPose = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local going = true
	local random = Random.new()
	task.spawn(function()
		task.wait(0.3)
		while going and root.Parent do
			local side = if random:NextNumber() < 0.5 then -1 else 1
			local start =
				Vector3.new(side * random:NextNumber(1.6, 2.8), random:NextNumber(0, 2), random:NextNumber(-0.8, 0.8))
			local sign = Create("BillboardGui", {
				Name = "EmoteMenace",
				Adornee = root,
				AlwaysOnTop = false,
				LightInfluence = 0,
				Size = UDim2.fromScale(1.8, 1.8),
				StudsOffset = start,
				Parent = root,
			}) :: BillboardGui
			sign:SetAttribute("DGEmote", true)
			local label = Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "ゴ",
				TextScaled = true,
				FontFace = Font.fromEnum(Enum.Font.GothamBlack),
				TextColor3 = Color3.fromRGB(150, 92, 205),
				TextStrokeColor3 = Color3.fromRGB(20, 8, 30),
				TextStrokeTransparency = 0.2,
				Rotation = side * random:NextNumber(4, 14),
				Parent = sign,
			}) :: TextLabel
			label:SetAttribute("KeepFont", true)
			local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			TweenService:Create(sign, info, { StudsOffset = start + Vector3.new(0, 1.4, 0) }):Play()
			TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(1.7, function()
				sign:Destroy()
			end)
			task.wait(0.45)
		end
	end)
	return function()
		going = false
	end
end

-- Low Battery: a battery over the head, running down from green to red, then blinking empty.
FX.lowBattery = function(character, preview)
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gui = Create("BillboardGui", {
		Name = "EmoteBattery",
		Adornee = head,
		Size = UDim2.fromScale(1.5, 0.75),
		StudsOffset = Vector3.new(0, 1.8, 0),
		LightInfluence = 0,
		Parent = head,
	}) :: BillboardGui
	gui:SetAttribute("DGEmote", true)
	local case = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.88, 1),
		Parent = gui,
	})
	Create("UIStroke", { Color = Color3.fromRGB(236, 232, 222), Thickness = 2, Parent = case })
	Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(236, 232, 222),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.9, 0.5),
		Size = UDim2.fromScale(0.08, 0.4),
		Parent = gui,
	})
	local fill = Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(110, 200, 110),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.08, 0.16),
		Size = UDim2.fromScale(0.84, 0.68),
		Parent = case,
	}) :: Frame
	local info = TweenInfo.new(2.6, Enum.EasingStyle.Linear)
	TweenService
		:Create(fill, info, { Size = UDim2.fromScale(0.06, 0.68), BackgroundColor3 = Color3.fromRGB(205, 40, 40) })
		:Play()
	local going = true
	task.delay(2.7, function()
		while going and gui.Parent do
			fill.Visible = not fill.Visible
			task.wait(0.35)
		end
	end)
	return function()
		going = false
		gui:Destroy()
	end
end

-- Reaper's Eyes: two red slivers of light on the face from when the head starts to turn.
FX.reapersEyes = function(character, preview)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nothing
	end
	local parts: { BasePart } = {}
	local gone = false
	task.delay(0.9, function()
		if gone or not head.Parent then
			return
		end
		for _, side in ipairs({ -0.2, 0.2 }) do
			local part = Create("Part", {
				Name = "EmoteEyes",
				Size = Vector3.new(0.2, 0.12, 0.06),
				Color = Color3.fromRGB(255, 25, 25),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Massless = true,
				CastShadow = false,
				CFrame = head.CFrame * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.03),
				Parent = character,
			}) :: BasePart
			part:SetAttribute("DGEmote", true)
			Create("WeldConstraint", { Part0 = head, Part1 = part, Parent = part })
			table.insert(parts, part)
		end
		if not preview then
			Create("PointLight", {
				Color = Color3.fromRGB(255, 40, 40),
				Range = 8,
				Brightness = 4,
				Parent = parts[1],
			})
		end
	end)
	return function()
		gone = true
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end
end

-- Just As Planned, timed to the clip (art/scripts/emotes/poses.py): ink spreads across the floor round him and
-- motes of it drift up; the eye catches red at the stare (2.05 s) and at the last look (7.75 s); a red light
-- comes up under the face with the grin (3.55 s); the laugh (4.95 s) bursts a ring of ink out across the floor
-- with a pulse of the light; everything sinks away as he comes to rest (8.4 s). Under reduced motion there is
-- no burst and no pulse.
local CRIMSON = Color3.fromRGB(163, 25, 47)
local INK = Color3.fromRGB(10, 10, 14)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

FX.justAsPlanned = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if preview or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local gone = false
	local made: { Instance } = {}
	local function keep<T>(instance: T): T
		table.insert(made, instance :: any)
		return instance
	end
	local function at(seconds: number, fn: () -> ())
		task.delay(seconds, function()
			if not gone and root.Parent then
				fn()
			end
		end)
	end
	local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
		TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine), goal):Play()
	end

	-- the ink on the floor: the splat texture on a flat plate, or a dark disc when the texture is not imported
	local floor = floorUnder(root.Position, character)
	local splat = Assets.texture("InkSplat1")
	local pool = keep(Create("Part", {
		Name = "EmoteInkPool",
		Size = Vector3.new(0.2, 0.04, 0.2),
		CFrame = CFrame.new(floor + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0),
		Color = INK,
		Material = Enum.Material.SmoothPlastic,
		Transparency = if splat ~= "" then 1 else 0.3,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart)
	local decal: Decal? = nil
	if splat ~= "" then
		decal = Create("Decal", {
			Face = Enum.NormalId.Top,
			Texture = splat,
			Color3 = INK,
			Transparency = 0.12,
			Parent = pool,
		}) :: Decal
	end
	tween(pool, 1.3, { Size = Vector3.new(8.5, 0.04, 8.5) }, Enum.EasingStyle.Quart)

	-- motes of ink drifting up off the pool the whole time
	local inkDrop = Assets.texture("InkDrop")
	local motes = keep(Create("ParticleEmitter", {
		Texture = if inkDrop ~= "" then inkDrop else SPARKLE,
		Color = ColorSequence.new(INK),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.45) }),
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(0.6, 1.4),
		Acceleration = Vector3.new(0, 1.2, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		LightInfluence = 0.4,
		Rate = 0,
		Parent = pool,
	}) :: ParticleEmitter)
	at(0.5, function()
		motes.Rate = 16
	end)

	-- the red glint in the eye, and a flash of red light with it
	local eye =
		keep(Create("Attachment", { Name = "EmoteGlint", Position = Vector3.new(0.22, 0.12, -0.62), Parent = head }))
	eye:SetAttribute("DGEmote", true)
	local glint = Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 40, 50)),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.35, 1.1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.45),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 45),
		RotSpeed = NumberRange.new(90),
		LockedToPart = true,
		ZOffset = 1,
		Rate = 0,
		Parent = eye,
	}) :: ParticleEmitter
	local glow =
		Create("PointLight", { Color = CRIMSON, Range = 7, Brightness = 0, Shadows = false, Parent = eye }) :: PointLight
	local function catchRed()
		glint:Emit(1)
		if not calm then
			glow.Brightness = 5
			tween(glow, 0.5, { Brightness = 0 })
		end
	end
	at(2.05, catchRed)
	at(7.75, catchRed)

	-- the red light under the face from the grin on
	local torso = character:FindFirstChild("Torso")
	local under = keep(Create("Attachment", {
		Name = "EmoteUnderlight",
		Position = Vector3.new(0, 0.4, -1.4),
		Parent = if torso and torso:IsA("BasePart") then torso else root,
	}))
	under:SetAttribute("DGEmote", true)
	local below = Create("SpotLight", {
		Color = CRIMSON,
		Face = Enum.NormalId.Top,
		Angle = 70,
		Range = 9,
		Brightness = 0,
		Shadows = false,
		Parent = under,
	}) :: SpotLight
	at(3.55, function()
		tween(below, 0.8, { Brightness = 2.2 })
	end)

	-- the laugh: a ring of ink bursts out across the floor, the pool flares, the light pulses
	at(4.95, function()
		tween(pool, 0.35, { Size = Vector3.new(11.5, 0.04, 11.5) }, Enum.EasingStyle.Back)
		at(0.45, function()
			tween(pool, 1.2, { Size = Vector3.new(9, 0.04, 9) })
		end)
		if calm then
			return
		end
		below.Brightness = 6
		tween(below, 0.9, { Brightness = 2.6 })
		local ring = keep(Create("Part", {
			Name = "EmoteInkRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 2, 2),
			CFrame = CFrame.new(floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = CRIMSON,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = workspace.CurrentCamera,
		}) :: BasePart)
		tween(ring, 0.7, { Size = Vector3.new(0.05, 22, 22), Transparency = 1 }, Enum.EasingStyle.Quart)
		local splash = Create("ParticleEmitter", {
			Texture = if inkDrop ~= "" then inkDrop else SPARKLE,
			Color = ColorSequence.new(INK),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) }),
			Lifetime = NumberRange.new(0.6, 1.0),
			Speed = NumberRange.new(9, 15),
			Drag = 3,
			Acceleration = Vector3.new(0, -14, 0),
			SpreadAngle = Vector2.new(80, 80),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			LightInfluence = 0.4,
			Rate = 0,
			Parent = pool,
		}) :: ParticleEmitter
		splash:Emit(28)
	end)
	at(6.9, function()
		tween(below, 0.6, { Brightness = 0.8 })
	end)

	-- the ink sinks away as he comes to rest
	at(8.4, function()
		motes.Rate = 0
		tween(below, 0.6, { Brightness = 0 })
		tween(pool, 0.8, { Size = Vector3.new(0.2, 0.04, 0.2) }, Enum.EasingStyle.Quart)
		local fadeOut = decal
		if fadeOut then
			tween(fadeOut, 0.8, { Transparency = 1 })
		end
	end)

	return function()
		gone = true
		for _, instance in ipairs(made) do
			instance:Destroy()
		end
	end
end

-- Diavolo's Potato Chip, timed to the clip (art/scripts/emotes/props.py): at the bite (7.05 s) the crisp bursts
-- into glittering crumbs and a warm light flares on the face (no flare under reduced motion); as he stands, ink
-- spreads under the desk (8.9 s) for it to sink into (EmoteMeta `sink`, 9.1 s), then draws back in (10.1 s).
FX.chipAndPen = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if preview or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local gone = false
	local made: { Instance } = {}
	local function at(seconds: number, fn: () -> ())
		task.delay(seconds, function()
			if not gone and root.Parent then
				fn()
			end
		end)
	end
	local floor = floorUnder(root.Position, character)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	-- the bite: crumbs from the mouth, and the flare
	local mouth = Create("Attachment", { Name = "EmoteCrumbs", Position = Vector3.new(0, -0.25, -0.6), Parent = head })
	mouth:SetAttribute("DGEmote", true)
	table.insert(made, mouth)
	local crumbs = Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(222, 170, 80)),
		LightEmission = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -18, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-200, 200),
		Rate = 0,
		Parent = mouth,
	}) :: ParticleEmitter
	local flare = Create("PointLight", {
		Color = Color3.fromRGB(255, 220, 160),
		Range = 10,
		Brightness = 0,
		Shadows = false,
		Parent = mouth,
	}) :: PointLight
	at(7.05, function()
		crumbs:Emit(26)
		if not calm then
			flare.Brightness = 6
			TweenService:Create(flare, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		end
	end)
	-- the ink under the desk
	local splat = Assets.texture("InkSplat2")
	local pool = Create("Part", {
		Name = "EmoteInkPool",
		Size = Vector3.new(0.2, 0.04, 0.2),
		CFrame = CFrame.new(floor + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -0.4),
		Color = INK,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	table.insert(made, pool)
	if splat ~= "" then
		Create("Decal", { Face = Enum.NormalId.Top, Texture = splat, Color3 = INK, Transparency = 0.1, Parent = pool })
	else
		pool.Transparency = 0.3
	end
	at(8.9, function()
		TweenService:Create(pool, TweenInfo.new(0.5, Enum.EasingStyle.Quart), { Size = Vector3.new(9, 0.04, 9) }):Play()
	end)
	at(10.1, function()
		TweenService:Create(pool, TweenInfo.new(0.3), { Size = Vector3.new(0.2, 0.04, 0.2) }):Play()
	end)
	return function()
		gone = true
		for _, instance in ipairs(made) do
			instance:Destroy()
		end
	end
end

-- The rung each effect needs on the ladder (Shared/EmoteInfo `fx`): 1 one small accent, 2 a tailored effect with
-- light, 3 layered, 4 the cutscene emotes'. The four above keep their own looks; the rest come with each emote.
local RUNG: { [string]: number } = {
	menacingPose = 1,
	lowBattery = 1,
	reapersEyes = 1,
	newWorld = 2,
	justAsPlanned = 3,
	chipAndPen = 2,
}

-- How strong an emote's effects may be here, now: its own rung (Shared/EmoteInfo), at most one small accent in
-- a case (Shared/EmotePolicy) or on low graphics (World/Governor).
function EmoteFx.rung(clip: string): number
	local info = EmoteInfo.of(clip)
	local rung = EmotePolicy.fxRung(info, {
		inCase = ClientState.isParticipant(),
		phase = ClientState.phase(),
		deathsinger = ClientState.isSpecter(),
		cutscene = false,
	})
	if Governor.low("emoteFx") then
		rung = math.min(rung, 1)
	end
	return rung
end

-- Starts an emote's effect on a character (nothing for emotes without one, or when its rung is out of reach
-- here; a preview always shows it). Returns a function that clears it away.
function EmoteFx.play(character: Model, clip: string, preview: boolean?): () -> ()
	local fx = FX[clip]
	if not fx then
		return nothing
	end
	if not preview and EmoteFx.rung(clip) < (RUNG[clip] or 1) then
		return nothing
	end
	return fx(character, preview == true)
end

-- Clip ids that have an effect (for checks).
function EmoteFx.has(clip: string): boolean
	return FX[clip] ~= nil
end

-- A thud where something dropped from above lands (EmoteProps `drop`): a ring of dark dust thrown out low along
-- the floor, wider for bigger things (nothing on low graphics or under reduced motion).
function EmoteFx.thud(at: CFrame, size: number)
	if Governor.low("emoteFx") or Motion.isReduced() then
		return
	end
	local texture = Assets.texture("Smoke")
	if texture == "" then
		texture = Assets.texture("InkDrop")
	end
	if texture == "" then
		return
	end
	local holder = Create("Part", {
		Name = "EmoteThud",
		Size = Vector3.new(size * 0.8, 0.05, size * 0.8),
		CFrame = CFrame.new(at.Position + Vector3.new(0, 0.1, 0)),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	local dust = Create("ParticleEmitter", {
		Texture = texture,
		Color = ColorSequence.new(Color3.fromRGB(40, 38, 40)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1.4 + size * 0.15),
		}),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(4, 7),
		Drag = 4,
		SpreadAngle = Vector2.new(85, 5),
		EmissionDirection = Enum.NormalId.Front,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rotation = NumberRange.new(0, 360),
		LightInfluence = 0.6,
		Rate = 0,
		Parent = holder,
	}) :: ParticleEmitter
	dust:Emit(math.clamp(math.floor(size * 4), 8, 28))
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

-- The ink wisp: every emote begins and ends in a little breath of ink round the feet, rising and gone (the Core
-- set's ink texture; nothing before it is imported, on low graphics, or under reduced motion).
local WISP_TEXTURES = { "InkDrop", "Smoke" }
function EmoteFx.wisp(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or Governor.low("emoteFx") or Motion.isReduced() then
		return
	end
	local texture = ""
	for _, name in ipairs(WISP_TEXTURES) do
		texture = Assets.texture(name)
		if texture ~= "" then
			break
		end
	end
	if texture == "" then
		return
	end
	local at = Create("Attachment", { Name = "EmoteWisp", Position = Vector3.new(0, -2.6, 0), Parent = root })
	at:SetAttribute("DGEmote", true)
	local emitter = Create("ParticleEmitter", {
		Texture = texture,
		Color = ColorSequence.new(Color3.fromRGB(12, 12, 16)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.7, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) }),
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(1.2, 2.4),
		SpreadAngle = Vector2.new(70, 70),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Acceleration = Vector3.new(0, 1.5, 0),
		LightInfluence = 0.6,
		Rate = 0,
		Parent = at,
	}) :: ParticleEmitter
	emitter:Emit(9)
	task.delay(1.6, function()
		at:Destroy()
	end)
end

return EmoteFx
