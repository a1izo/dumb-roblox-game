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

-- (phase: seconds into the clip the emote started at here, for a loop that joined the shared beat)
type Fx = (character: Model, preview: boolean, phase: number?) -> () -> ()

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
-- The battery over the head (its case, its tip and its fill, full and green).
local function battery(head: BasePart): (BillboardGui, Frame)
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
	return gui, fill
end

FX.lowBattery = function(character, preview)
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gui, fill = battery(head)
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
	-- (when the hand comes away from the eyes)
	task.delay(1.75, function()
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
	at(10.4, function()
		pool:Destroy()
	end)
	return function()
		gone = true
		for _, instance in ipairs(made) do
			instance:Destroy()
		end
	end
end

-- An imported effect texture, or one of Roblox's own when the import has none.
local function textureOr(name: string, fallback: string): string
	local id = Assets.texture(name)
	return if id ~= "" then id else fallback
end

-- Runs `fn` `seconds` after the start, unless the effect was cleared by then or the body went.
local function after(root: Instance, gone: () -> boolean, seconds: number, fn: () -> ())
	task.delay(seconds, function()
		if not gone() and root.Parent then
			fn()
		end
	end)
end

-- Apple Bite, timed to the clip (art/scripts/emotes/older.py): the crunch (0.93 s) sprays juice and flecks of
-- the apple's white flesh out of the mouth, falling.
FX.appleBite = function(character, preview)
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gone = false
	local mouth = Create("Attachment", { Name = "EmoteJuice", Position = Vector3.new(0, -0.3, -0.75), Parent = head })
	mouth:SetAttribute("DGEmote", true)
	local function spray(name: string, colors: ColorSequence, size: number, count: number)
		local emitter = Create("ParticleEmitter", {
			Name = name,
			Texture = SPARKLE,
			Color = colors,
			LightEmission = 0.25,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, size),
				NumberSequenceKeypoint.new(1, size * 0.3),
			}),
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(4, 8),
			SpreadAngle = Vector2.new(50, 35),
			EmissionDirection = Enum.NormalId.Front,
			Acceleration = Vector3.new(0, -26, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-260, 260),
			Rate = 0,
			Parent = mouth,
		}) :: ParticleEmitter
		after(
			head,
			function()
				return gone
			end,
			0.93,
			function()
				emitter:Emit(count)
			end
		)
	end
	spray("Juice", ColorSequence.new(Color3.fromRGB(255, 246, 220), Color3.fromRGB(236, 214, 160)), 0.22, 16)
	spray("Skin", ColorSequence.new(Color3.fromRGB(170, 24, 32)), 0.16, 5)
	return function()
		gone = true
		mouth:Destroy()
	end
end

-- Puppet Dance: the marionette's strings, pale threads from far overhead down to each wrist and knee and the
-- crown of the head, jerked with every pull (they hang from the body's own root, so they go where it goes).
local STRING = Color3.fromRGB(226, 220, 204)
FX.puppetDance = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local made: { Instance } = {}
	local ends = {
		{ "Right Arm", Vector3.new(0, -0.95, 0), Vector3.new(1.6, 10, -0.2) },
		{ "Left Arm", Vector3.new(0, -0.95, 0), Vector3.new(-1.6, 10, -0.2) },
		{ "Right Leg", Vector3.new(0, 0.1, -0.5), Vector3.new(0.6, 10, -0.8) },
		{ "Left Leg", Vector3.new(0, 0.1, -0.5), Vector3.new(-0.6, 10, -0.8) },
		{ "Head", Vector3.new(0, 0.5, 0), Vector3.new(0, 10, 0) },
	}
	for _, spec in ipairs(ends) do
		local limb = character:FindFirstChild(spec[1])
		if limb and limb:IsA("BasePart") then
			local low = Create("Attachment", { Name = "EmoteString", Position = spec[2], Parent = limb })
			local high = Create("Attachment", { Name = "EmoteString", Position = spec[3], Parent = root })
			low:SetAttribute("DGEmote", true)
			high:SetAttribute("DGEmote", true)
			local beam = Create("Beam", {
				Attachment0 = low,
				Attachment1 = high,
				Color = ColorSequence.new(STRING),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25),
					NumberSequenceKeypoint.new(0.7, 0.45),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Width0 = 0.035,
				Width1 = 0.035,
				FaceCamera = true,
				LightInfluence = 0.6,
				Segments = 2,
				Parent = low,
			})
			table.insert(made, low)
			table.insert(made, high)
			table.insert(made, beam)
		end
	end
	return function()
		for _, instance in ipairs(made) do
			instance:Destroy()
		end
	end
end

-- Write in the Air, timed to the clip (art/scripts/emotes/older.py): the fingertip writes in glowing red ink that
-- hangs where it was written and fades (0.4 to 1.95 s: the name, then its underline), a red light on the finger
-- as it writes; the full stop (2.3 s) flares the light and spatters the ink.
FX.writeAir = function(character, preview)
	local arm = character:FindFirstChild("Right Arm")
	if preview or not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local gone = false
	local function over()
		return gone
	end
	local tip = Create("Attachment", { Name = "EmoteInk", Position = Vector3.new(0, -1.1, 0), Parent = arm })
	tip:SetAttribute("DGEmote", true)
	local red = Color3.fromRGB(230, 36, 56)
	local glow = textureOr("SoulGlow", SPARKLE)
	local ink = Create("ParticleEmitter", {
		Name = "Writing",
		Texture = glow,
		Color = ColorSequence.new(red),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.12) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.65, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(2.4),
		Speed = NumberRange.new(0),
		Rate = 110,
		Enabled = false,
		Parent = tip,
	}) :: ParticleEmitter
	local spatter = Create("ParticleEmitter", {
		Name = "FullStop",
		Texture = SPARKLE,
		Color = ColorSequence.new(red),
		LightEmission = 0.8,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(3, 6),
		Drag = 6,
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = tip,
	}) :: ParticleEmitter
	local light = Create("PointLight", {
		Color = Color3.fromRGB(255, 50, 64),
		Range = 6,
		Brightness = 0,
		Shadows = false,
		Parent = tip,
	}) :: PointLight
	after(arm, over, 0.4, function()
		ink.Enabled = true
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 1.4 }):Play()
	end)
	after(arm, over, 1.95, function()
		ink.Enabled = false
	end)
	after(arm, over, 2.3, function()
		ink:Emit(4)
		if calm then
			return
		end
		spatter:Emit(14)
		light.Brightness = 5
		TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	end)
	return function()
		gone = true
		tip:Destroy()
	end
end

-- Ace's Crouch: a cold lamp straight overhead, as in his interview room, and dust drifting slowly in its light.
FX.aceCrouch = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local removeLight = Cinema.spotlight(character, Color3.fromRGB(196, 212, 232))
	-- (the dust fills a still box of air round him, not one that follows the body)
	local box = Create("Part", {
		Name = "EmoteDust",
		Size = Vector3.new(5, 5, 5),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = root.CFrame,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(220, 228, 240)),
		LightEmission = 0.4,
		LightInfluence = 0.5,
		Size = NumberSequence.new(0.07),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(0.1, 0.35),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -0.05, 0),
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = if Motion.isReduced() then 2 else 5,
		Parent = box,
	})
	return function()
		removeLight()
		box:Destroy()
	end
end

-- The dances' accents (S10): small, each timed to its clip's beats, every turn of the loop -------------------------

-- Runs `fn` at each of `times` (seconds into the clip) on every turn of a loop `length` seconds long, the clip
-- having started `phase` seconds in, until `gone` says the effect was cleared or the body went.
local function onBeats(
	root: Instance,
	gone: () -> boolean,
	length: number,
	times: { number },
	phase: number?,
	fn: (number) -> ()
)
	if length <= 0 then
		return
	end
	task.spawn(function()
		local began = os.clock() - (phase or 0)
		local turn = 0
		while not gone() and root.Parent do
			for _, at in ipairs(times) do
				local wait = began + turn * length + at - os.clock()
				if wait >= -0.05 then
					if wait > 0 then
						task.wait(wait)
					end
					if gone() or not root.Parent then
						return
					end
					fn(at)
				end
			end
			turn += 1
		end
	end)
end

-- A one-off spray of particles from a point (in the camera, gone after them).
type Burst = {
	color: ColorSequence,
	count: number,
	size: number,
	speed: NumberRange,
	life: NumberRange,
	spread: number?,
	gravity: number?,
	light: number?,
	direction: Enum.NormalId?,
}
local function burst(at: Vector3, spec: Burst)
	local holder = Create("Part", {
		Name = "EmoteBurst",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
	local emitter = Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = spec.color,
		LightEmission = spec.light or 0.5,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.size), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = spec.life,
		Speed = spec.speed,
		SpreadAngle = Vector2.new(spec.spread or 60, spec.spread or 60),
		EmissionDirection = spec.direction or Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -(spec.gravity or 0), 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
		Rate = 0,
		Parent = holder,
	}) :: ParticleEmitter
	emitter:Emit(spec.count)
	task.delay(spec.life.Max + 0.2, function()
		holder:Destroy()
	end)
end

-- Where a leg's sole is (its bottom face's middle).
local function soleOf(character: Model, leg: string): Vector3?
	local part = character:FindFirstChild(leg)
	if not part or not part:IsA("BasePart") then
		return nil
	end
	return (part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)).Position
end

-- The lower of the two soles (the foot that just came down).
local function lowerSole(character: Model): Vector3?
	local right, left = soleOf(character, "Right Leg"), soleOf(character, "Left Leg")
	if right and left then
		return if right.Y <= left.Y then right else left
	end
	return right or left
end

-- A step's little puff of dust under the foot that just landed.
local function stepDust(character: Model, size: number?)
	local sole = lowerSole(character)
	if sole then
		EmoteFx.thud(CFrame.new(sole), size or 1.2)
	end
end

-- A dance's accent at its beats: `make(character, at)` for each beat `at` of each loop turn.
local function accent(length: number, times: { number }, make: (character: Model, at: number) -> ()): Fx
	return function(character, preview, phase)
		local root = character:FindFirstChild("HumanoidRootPart")
		if preview or not root then
			return nothing
		end
		local gone = false
		onBeats(
			root,
			function()
				return gone
			end,
			length,
			times,
			phase,
			function(at)
				make(character, at)
			end
		)
		return function()
			gone = true
		end
	end
end

local function chest(character: Model): Vector3?
	local torso = character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso.Position else nil
end

-- Two-Legged Bop: dust under each little step (a step every beat at 200 bpm).
FX.twoLeggedBop = accent(2.4, { 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4 - 0.001 }, function(character)
	stepDust(character, 0.9)
end)

-- The Rat Dance: dust under the cross-steps.
FX.ratDance = accent(2 * 60 / 106, { 0.0, 60 / 106 }, function(character)
	stepDust(character, 1.0)
end)

-- Bunny Ears: pastel sparkles flicked off the hands on the head, every other beat.
local PASTEL = ColorSequence.new(Color3.fromRGB(255, 182, 220), Color3.fromRGB(170, 215, 255))
FX.bunnyEars = accent(4 * 60 / 165, { 0.0, 2 * 60 / 165 }, function(character)
	for _, arm in ipairs({ "Right Arm", "Left Arm" }) do
		local part = character:FindFirstChild(arm)
		if part and part:IsA("BasePart") then
			burst((part.CFrame * CFrame.new(0, -1, 0)).Position, {
				color = PASTEL,
				count = 5,
				size = 0.22,
				speed = NumberRange.new(2, 4),
				life = NumberRange.new(0.4, 0.7),
				gravity = 4,
			})
		end
	end
end)

-- Jackpot Shuffle: a spray of gold coins up from the floor once a turn (Hakari's jackpot).
local GOLD = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(230, 160, 40))
FX.jackpotShuffle = accent(7 * 60 / 150, { 0.0 }, function(character)
	local sole = lowerSole(character)
	if sole then
		burst(sole + Vector3.new(0, 0.2, 0), {
			color = GOLD,
			count = 18,
			size = 0.3,
			speed = NumberRange.new(9, 14),
			life = NumberRange.new(0.8, 1.2),
			spread = 35,
			gravity = 30,
			light = 0.7,
		})
	end
end)

-- Boat Aura: spray off the bow on every surge (each four beats).
local SPRAY = ColorSequence.new(Color3.fromRGB(220, 240, 255), Color3.fromRGB(150, 200, 235))
FX.boatAura = accent(6.4, { 0.0, 1.6, 3.2, 4.8 }, function(character)
	local sole = lowerSole(character)
	if sole then
		burst(sole + Vector3.new(0, 0.1, -1.2), {
			color = SPRAY,
			count = 16,
			size = 0.25,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.5, 0.9),
			spread = 70,
			gravity = 22,
			light = 0.3,
		})
	end
end)

-- Office Party: a flurry of loose paper as the turn comes round.
local PAPER = ColorSequence.new(Color3.fromRGB(245, 243, 236))
FX.officeParty = accent(6.4, { 3.9 }, function(character)
	local at = chest(character)
	if at then
		burst(at + Vector3.new(0, 1.5, 0), {
			color = PAPER,
			count = 14,
			size = 0.35,
			speed = NumberRange.new(4, 7),
			life = NumberRange.new(1.2, 1.8),
			spread = 80,
			gravity = 3,
			light = 0,
		})
	end
end)

-- Glitch Step: the tape's stutters throw off cyan and magenta squares.
local GLITCH = ColorSequence.new(Color3.fromRGB(0, 255, 240), Color3.fromRGB(255, 0, 200))
FX.glitchStep = accent(2.4, { 0.6, 1.6 }, function(character)
	local at = chest(character)
	if at then
		burst(at, {
			color = GLITCH,
			count = 12,
			size = 0.3,
			speed = NumberRange.new(2, 5),
			life = NumberRange.new(0.12, 0.3),
			spread = 180,
			light = 1,
		})
	end
end)

-- Goal Celebration: the landing kicks up a ring of dust, and a spray of gold off the chest with the shout.
FX.goalCelebration = accent(3.0, { 1.26 }, function(character)
	local sole = lowerSole(character)
	if sole then
		EmoteFx.thud(CFrame.new(sole), 4)
	end
	local at = chest(character)
	if at then
		burst(at, {
			color = GOLD,
			count = 16,
			size = 0.28,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.5, 0.9),
			spread = 70,
			gravity = 10,
			light = 0.8,
		})
	end
end)

-- The Smiling Lord: a glint off the brim as the hat is touched.
FX.smilingLord = accent(4.8, { 0.3 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0.4, 0.7, -0.3)).Position, {
			color = GOLD,
			count = 4,
			size = 0.5,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.3, 0.5),
			spread = 180,
			light = 1,
		})
	end
end)

-- Excuse Me, Sir, LOOK UP: a glint of sky on the upturned face.
FX.excuseMeSirUp = accent(2.8, { 0.75 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0, 0.9, -0.4)).Position, {
			color = ColorSequence.new(Color3.fromRGB(255, 250, 235)),
			count = 3,
			size = 0.9,
			speed = NumberRange.new(0.2, 0.5),
			life = NumberRange.new(0.5, 0.8),
			spread = 180,
			light = 1,
		})
	end
end)

-- Animatronic Welcome: the stage robot's eyes lit, a pale gold shine.
FX.animatronicWelcome = function(character, preview)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nothing
	end
	local parts: { BasePart } = {}
	for _, side in ipairs({ -0.2, 0.2 }) do
		local part = Create("Part", {
			Name = "EmoteEyes",
			Size = Vector3.new(0.14, 0.14, 0.05),
			Shape = Enum.PartType.Block,
			Color = Color3.fromRGB(255, 236, 170),
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
		Create("PointLight", { Color = Color3.fromRGB(255, 230, 160), Range = 5, Brightness = 1.5, Parent = parts[1] })
	end
	return function()
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end
end

-- Low Battery's CHARGE: the battery fills back up in jumps with each jolt, sparks off the body, and green.
local SPARK = ColorSequence.new(Color3.fromRGB(255, 250, 200), Color3.fromRGB(120, 210, 255))
FX.lowBatteryCharge = function(character, preview)
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gui, fill = battery(head)
	fill.Size = UDim2.fromScale(0.06, 0.68)
	fill.BackgroundColor3 = Color3.fromRGB(205, 40, 40)
	local gone = false
	local function zap(at: number, to: number, color: Color3)
		task.delay(at, function()
			if gone or not head.Parent then
				return
			end
			fill.Visible = true
			TweenService
				:Create(fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(to, 0.68), BackgroundColor3 = color })
				:Play()
			local torso = character:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				burst(torso.Position, {
					color = SPARK,
					count = 10,
					size = 0.3,
					speed = NumberRange.new(4, 8),
					life = NumberRange.new(0.15, 0.35),
					spread = 180,
					light = 1,
				})
			end
		end)
	end
	zap(0.15, 0.3, Color3.fromRGB(230, 170, 40))
	zap(0.62, 0.6, Color3.fromRGB(200, 210, 60))
	zap(1.6, 0.84, Color3.fromRGB(110, 200, 110))
	return function()
		gone = true
		gui:Destroy()
	end
end

-- The poses' accents (S11) -------------------------------------------------------------------------------------

-- Impossible Lean: the dust swept back off the floor from under the feet as the body tips (0.95 s).
FX.impossibleLean = accent(4.2, { 0.95 }, function(character)
	local sole = lowerSole(character)
	if sole then
		EmoteFx.thud(CFrame.new(sole), 2.2)
	end
end)

-- It's You: the point lands with a white crack of light off the fingertip (0.24 s).
local CRACK = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 220, 255))
FX.itsYou = accent(2.6, { 0.24 }, function(character)
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		burst((arm.CFrame * CFrame.new(0, -1.2, 0)).Position, {
			color = CRACK,
			count = 14,
			size = 0.35,
			speed = NumberRange.new(6, 11),
			life = NumberRange.new(0.12, 0.28),
			spread = 180,
			light = 1,
		})
	end
end)

-- Deducing: a faint spark of a thought by the temple on each tap of the thumb (1.1 s and 3.1 s of the loop).
local THOUGHT = ColorSequence.new(Color3.fromRGB(200, 225, 255))
FX.deducing = accent(4.0, { 1.1, 3.1 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0.55, 0.45, -0.2)).Position, {
			color = THOUGHT,
			count = 5,
			size = 0.18,
			speed = NumberRange.new(0.6, 1.4),
			life = NumberRange.new(0.6, 1.0),
			spread = 60,
			gravity = -1.5,
			light = 0.8,
		})
	end
end)

-- Reaper's Cackle: a breath of black ink off the shoulders with each burst of the laugh, rising.
local INK_RISE = ColorSequence.new(Color3.fromRGB(20, 18, 24), Color3.fromRGB(60, 20, 30))
FX.reapersCackle = accent(1.6, { 0.0, 0.4, 0.8, 1.2 }, function(character)
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		burst((torso.CFrame * CFrame.new(0, 1.1, 0)).Position, {
			color = INK_RISE,
			count = 6,
			size = 0.45,
			speed = NumberRange.new(1, 2.5),
			life = NumberRange.new(0.6, 1.0),
			spread = 70,
			gravity = -3,
			light = 0,
		})
	end
end)

-- Final Breakdown: a red light from below the face comes up as the laugh is held in; it flares as he is thrown
-- back (2.25 s) with a ring of dark dust out across the floor and black ink pouring up off him while he laughs;
-- everything sinks away as he folds over (4.2 s). Under reduced motion there is no flare.
FX.finalBreakdown = function(character, preview)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not head or not head:IsA("BasePart") or not root then
		return nothing
	end
	local calm = Motion.isReduced()
	local gone = false
	local function over()
		return gone
	end
	local under =
		Create("Attachment", { Name = "EmoteUnderLight", Position = Vector3.new(0, -1.2, -0.9), Parent = head })
	under:SetAttribute("DGEmote", true)
	local light = Create("PointLight", {
		Color = CRIMSON,
		Range = 9,
		Brightness = 0,
		Shadows = false,
		Parent = under,
	}) :: PointLight
	TweenService:Create(light, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Brightness = 2.2 }):Play()
	local pour = Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = INK_RISE,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, 2, 0),
		LightEmission = 0,
		Rate = 0,
		Parent = under,
	}) :: ParticleEmitter
	after(head, over, 2.25, function()
		if not calm then
			light.Brightness = 7
			TweenService:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Brightness = 3 }):Play()
		end
		local sole = lowerSole(character)
		if sole then
			EmoteFx.thud(CFrame.new(sole), 6)
		end
		pour.Rate = if calm then 8 else 24
	end)
	after(head, over, 4.2, function()
		pour.Rate = 0
		TweenService:Create(light, TweenInfo.new(1.0), { Brightness = 0 }):Play()
	end)
	return function()
		gone = true
		under:Destroy()
	end
end

-- Menacing Pose's other two poses (NEXT POSE): the same signs rising round them.
FX.menacingPose2 = function(character, preview, phase)
	return FX.menacingPose(character, preview, phase)
end
FX.menacingPose3 = FX.menacingPose2

-- Bye Bye Bye (Puppet Pop): the band dance it as marionettes; the same strings as Puppet Dance.
FX.puppetPop = function(character, preview, phase)
	return FX.puppetDance(character, preview, phase)
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
	appleBite = 1,
	puppetDance = 1,
	writeAir = 2,
	aceCrouch = 2,
	twoLeggedBop = 1,
	ratDance = 1,
	bunnyEars = 1,
	jackpotShuffle = 1,
	boatAura = 1,
	officeParty = 1,
	glitchStep = 1,
	goalCelebration = 1,
	smilingLord = 1,
	excuseMeSirUp = 1,
	animatronicWelcome = 1,
	puppetPop = 1,
	menacingPose2 = 1,
	menacingPose3 = 1,
	lowBatteryCharge = 1,
	impossibleLean = 1,
	itsYou = 1,
	deducing = 1,
	reapersCackle = 1,
	finalBreakdown = 3,
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
function EmoteFx.play(character: Model, clip: string, preview: boolean?, phase: number?): () -> ()
	local fx = FX[clip]
	if not fx then
		return nothing
	end
	if not preview and EmoteFx.rung(clip) < (RUNG[clip] or 1) then
		return nothing
	end
	return fx(character, preview == true, phase)
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
	-- (Roblox's own smoke before the Core set is imported: the dances' step dust needs it from the start)
	local texture = Assets.texture("Smoke")
	if texture == "" then
		texture = Assets.texture("InkDrop")
	end
	if texture == "" then
		texture = "rbxasset://textures/particles/smoke_main.dds"
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
