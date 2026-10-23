-- The emote pack's effects round a character while its emote plays (EmoteController starts them and clears
-- them when the emote ends; each returns a function that clears it away): a beam of light from above for
-- New World, signs rising round Menacing Pose, a battery running down over Low Battery's head, red eyes
-- for Reaper's Eyes. Everything is made on this client only, and what is put on the body is marked "DGEmote"
-- (a copy of the body leaves it out). A preview (the shop's copy in its 3D view)
-- gets only what a 3D view can show: no lights, no billboards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteInfo = require(Shared:WaitForChild("EmoteInfo"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local EmotePolicy = require(Shared:WaitForChild("EmotePolicy"))

local LocomotionController = require(script.Parent.Parent.Anim.LocomotionController)
local Cinema = require(script.Parent.Parent.Presentation.Cinema)
local Stage = require(script.Parent.Parent.Presentation.Stage)
local FxKit = require(script.Parent.Parent.Presentation.FxKit)
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
	-- (the FX kit) the fist closes at 3.42 s: a ring of light over the floor, spikes of light off the fist
	local over = false
	task.delay(3.42, function()
		local arm = character:FindFirstChild("Right Arm")
		if over or not root.Parent then
			return
		end
		FxKit.shape(
			"ring",
			CFrame.new(floor + Vector3.new(0, 0.08, 0)),
			{ size = 18, seconds = 0.6, color = warm, transparency = 0.3 }
		)
		if arm and arm:IsA("BasePart") then
			local fist = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
			FxKit.shape(
				"spikes",
				CFrame.new(fist),
				{ size = 3.6, seconds = 0.3, color = warm, transparency = 0.2, spin = 40 }
			)
			FxKit.light(fist, warm, 20, 5, 0.7)
		end
	end)
	return function()
		over = true
		removeLight()
		TweenService:Create(column, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		-- (on a timer, not the tween's Completed: a throttled client can miss that and leave the column)
		task.delay(0.55, function()
			column:Destroy()
		end)
	end
end

-- A manga sign (ゴ, ド...) in a billboard by the body: its colour and its outline, how big, and where it starts
-- (studs from the root, in the camera's frame).
type Sign = { text: string, colour: Color3, stroke: Color3, size: number, at: Vector3, tilt: number }

local function signLabel(root: BasePart, sign: Sign): (BillboardGui, TextLabel)
	local gui = Create("BillboardGui", {
		Name = "EmoteSign",
		Adornee = root,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(sign.size, sign.size),
		StudsOffset = sign.at,
		Parent = root,
	}) :: BillboardGui
	gui:SetAttribute("DGEmote", true)
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = sign.text,
		TextScaled = true,
		FontFace = Font.fromEnum(Enum.Font.GothamBlack),
		TextColor3 = sign.colour,
		TextStrokeColor3 = sign.stroke,
		TextStrokeTransparency = 0.15,
		Rotation = sign.tilt,
		Parent = gui,
	}) :: TextLabel
	label:SetAttribute("KeepFont", true)
	return gui, label
end

-- Menacing Pose: the sign of menace (ゴ) rising and fading round the body, one after another, a different
-- arrangement and colour for each of the three poses (NEXT POSE; the owner's Q33): violet by turns on either side;
-- bone white stacked in a column up the right; near-black outlined in white, in an arc behind the head.
type Menace = {
	colour: Color3,
	stroke: Color3,
	size: number,
	every: number,
	place: (Random, number) -> (Vector3, number),
}

local MENACES: { [string]: Menace } = {
	menacingPose = {
		colour = Color3.fromRGB(150, 92, 205),
		stroke = Color3.fromRGB(20, 8, 30),
		size = 1.8,
		every = 0.45,
		place = function(random: Random, _: number): (Vector3, number)
			local side = if random:NextNumber() < 0.5 then -1 else 1
			local at =
				Vector3.new(side * random:NextNumber(1.6, 2.8), random:NextNumber(0, 2), random:NextNumber(-0.8, 0.8))
			return at, side * random:NextNumber(4, 14)
		end,
	},
	menacingPose2 = {
		colour = Color3.fromRGB(236, 230, 214),
		stroke = Color3.fromRGB(12, 12, 14),
		size = 1.5,
		every = 0.3,
		place = function(random: Random, k: number): (Vector3, number)
			return Vector3.new(2.3 + random:NextNumber(-0.15, 0.15), -0.6 + (k % 4) * 0.9, 0), random:NextNumber(-6, 6)
		end,
	},
	menacingPose3 = {
		colour = Color3.fromRGB(26, 22, 30),
		stroke = Color3.fromRGB(236, 230, 214),
		size = 2.2,
		every = 0.5,
		place = function(random: Random, k: number): (Vector3, number)
			local a = math.rad(-70 + (k % 5) * 35 + random:NextNumber(-6, 6))
			return Vector3.new(3.2 * math.sin(a), 2.0 + 1.6 * math.cos(a), -1.5), math.deg(a) * 0.4
		end,
	},
}

local function menace(kind: Menace): Fx
	return function(character, preview)
		local root = character:FindFirstChild("HumanoidRootPart")
		if preview or not root or not root:IsA("BasePart") then
			return nothing
		end
		local going = true
		local random = Random.new()
		task.spawn(function()
			task.wait(0.3)
			local k = 0
			while going and root.Parent do
				local start, tilt = kind.place(random, k)
				k += 1
				local gui, label = signLabel(root, {
					text = "ゴ",
					colour = kind.colour,
					stroke = kind.stroke,
					size = kind.size,
					at = start,
					tilt = tilt,
				})
				local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				TweenService:Create(gui, info, { StudsOffset = start + Vector3.new(0, 1.4, 0) }):Play()
				TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(1.7, function()
					gui:Destroy()
				end)
				task.wait(kind.every)
			end
		end)
		return function()
			going = false
		end
	end
end

FX.menacingPose = menace(MENACES.menacingPose)

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

-- Just As Planned, timed to the clip (art/scripts/emotes/poses.py): a pool of crimson light spreads across the
-- floor round him and embers drift up off it; the eye catches red at the stare (2.05 s) and at the last look
-- (7.75 s); a red light comes up under the face with the grin (3.55 s); the laugh (4.95 s) bursts a ring of light
-- out across the floor with a spray of embers and a pulse of the light; it all dies down as he comes to rest
-- (8.4 s). Under reduced motion there is no burst and no pulse.
local CRIMSON = Color3.fromRGB(163, 25, 47)
local EMBERS = ColorSequence.new(Color3.fromRGB(255, 92, 70), Color3.fromRGB(70, 62, 62))
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- A flat disc `d` studs across (a cylinder lying on the floor).
local function disc(d: number): Vector3
	return Vector3.new(0.04, d, d)
end

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

	-- the pool of crimson light on the floor, tinting it
	local floor = floorUnder(root.Position, character)
	local pool = keep(Create("Part", {
		Name = "EmotePlanGlow",
		Shape = Enum.PartType.Cylinder,
		Size = disc(0.2),
		CFrame = CFrame.new(floor + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = CRIMSON,
		Material = Enum.Material.Neon,
		Transparency = 0.84,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart)
	local tint = Create("PointLight", { Color = CRIMSON, Range = 9, Brightness = 0, Shadows = false, Parent = pool })
	tween(pool, 1.3, { Size = disc(8.5) }, Enum.EasingStyle.Quart)
	tween(tint, 1.3, { Brightness = 1.2 })

	-- embers drifting up off it the whole time
	local motes = keep(Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = EMBERS,
		LightEmission = 0.7,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.05) }),
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

	-- the laugh: a ring of light bursts out across the floor, the pool flares, the light pulses
	at(4.95, function()
		tween(pool, 0.35, { Size = disc(11.5) }, Enum.EasingStyle.Back)
		at(0.45, function()
			tween(pool, 1.2, { Size = disc(9) })
		end)
		if calm then
			return
		end
		below.Brightness = 6
		tween(below, 0.9, { Brightness = 2.6 })
		-- (the FX kit: a crimson shockwave dome and a ring running out over the floor)
		FxKit.shape("dome", CFrame.new(floor), { size = 13, seconds = 0.55, color = CRIMSON, transparency = 0.55 })
		FxKit.shape("ring", CFrame.new(floor + Vector3.new(0, 0.08, 0)), {
			size = 22,
			seconds = 0.7,
			color = CRIMSON,
			transparency = 0.25,
		})
		FxKit.light(head.Position, CRIMSON, 18, 4, 0.6)
		local ring = keep(Create("Part", {
			Name = "EmotePlanRing",
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
			Texture = SPARKLE,
			Color = EMBERS,
			LightEmission = 0.8,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.05) }),
			Lifetime = NumberRange.new(0.6, 1.0),
			Speed = NumberRange.new(9, 15),
			Drag = 3,
			Acceleration = Vector3.new(0, 2, 0),
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

	-- it all dies down as he comes to rest
	at(8.4, function()
		motes.Rate = 0
		tween(below, 0.6, { Brightness = 0 })
		tween(tint, 0.8, { Brightness = 0 })
		tween(pool, 0.8, { Size = disc(0.2), Transparency = 1 }, Enum.EasingStyle.Quart)
	end)

	return function()
		gone = true
		for _, instance in ipairs(made) do
			instance:Destroy()
		end
	end
end

-- Diavolo's Potato Chip, timed to the clip (art/scripts/emotes/props.py): at the bite (7.05 s) the crisp bursts
-- into glittering crumbs and a warm light flares on the face (no flare under reduced motion); as he stands, a
-- low cloud of grey dust rises round the desk (8.95 s) as it all sinks into the floor (EmoteMeta `sink`, 9.1 s),
-- and settles (9.5 s).
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
	-- the dust round the desk as it goes down
	local desk = CFrame.new(floor) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -0.4)
	at(8.95, function()
		EmoteFx.thud(desk, 7)
	end)
	at(9.5, function()
		EmoteFx.thud(desk, 5)
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

-- Write in the Air, timed to the clip (art/scripts/emotes/older.py): the fingertip writes a line of pale light
-- that hangs where it was written and fades (0.4 to 1.95 s: the name, then its underline), as a sparkler would,
-- a warm light on the finger as it writes; the full stop (2.3 s) flares the light with a burst of sparks.
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
	local tip = Create("Attachment", { Name = "EmoteWriting", Position = Vector3.new(0, -1.1, 0), Parent = arm })
	tip:SetAttribute("DGEmote", true)
	local pale = Color3.fromRGB(255, 240, 214)
	local glow = textureOr("SoulGlow", SPARKLE)
	local line = Create("ParticleEmitter", {
		Name = "Writing",
		Texture = glow,
		Color = ColorSequence.new(pale),
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
		Color = ColorSequence.new(pale, Color3.fromRGB(255, 196, 120)),
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
		Color = Color3.fromRGB(255, 226, 180),
		Range = 6,
		Brightness = 0,
		Shadows = false,
		Parent = tip,
	}) :: PointLight
	after(arm, over, 0.4, function()
		line.Enabled = true
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 1.4 }):Play()
	end)
	after(arm, over, 1.95, function()
		line.Enabled = false
	end)
	after(arm, over, 2.3, function()
		line:Emit(4)
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

-- It's You (the owner's Q33): the point lands (0.24 s) with a white crack of light off the fingertip, manga speed
-- lines flash out behind the body, and ドドド stands beside it while the point is held (to 2.0 s).
local CRACK = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 220, 255))
local SPEED_LINES = 22

-- Speed lines: thin white strokes radiating from the body, behind it, the middle left clear.
local function speedLines(root: BasePart): BillboardGui
	local gui = Create("BillboardGui", {
		Name = "EmoteSpeedLines",
		Adornee = root,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 80,
		Size = UDim2.fromScale(16, 16),
		StudsOffset = Vector3.new(0, 0.6, -3),
		Parent = root,
	}) :: BillboardGui
	gui:SetAttribute("DGEmote", true)
	local random = Random.new()
	for k = 1, SPEED_LINES do
		local a = (k + random:NextNumber(-0.3, 0.3)) / SPEED_LINES * math.pi * 2
		local inner, length = random:NextNumber(0.2, 0.26), random:NextNumber(0.12, 0.22)
		local middle = inner + length / 2
		Create("Frame", {
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + middle * math.cos(a), 0.5 + middle * math.sin(a)),
			Size = UDim2.new(length, 0, 0, random:NextInteger(2, 4)),
			Rotation = math.deg(a),
			BackgroundColor3 = Color3.fromRGB(245, 245, 240),
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	return gui
end

FX.itsYou = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	local arm = character:FindFirstChild("Right Arm")
	if preview or not root or not root:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local gone = false
	local function over()
		return gone
	end
	local made: { Instance } = {}
	after(root, over, 0.24, function()
		burst((arm.CFrame * CFrame.new(0, -1.2, 0)).Position, {
			color = CRACK,
			count = 14,
			size = 0.35,
			speed = NumberRange.new(6, 11),
			life = NumberRange.new(0.12, 0.28),
			spread = 180,
			light = 1,
		})
		if not calm then
			local lines = speedLines(root)
			table.insert(made, lines)
			for _, line in ipairs(lines:GetChildren()) do
				TweenService:Create(line, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
					:Play()
			end
		end
		-- ドドド down the left of the body, one after another
		for k = 0, 2 do
			after(root, over, 0.08 * k, function()
				local gui, label = signLabel(root, {
					text = "ド",
					colour = Color3.fromRGB(236, 230, 214),
					stroke = Color3.fromRGB(12, 12, 14),
					size = 1.7 - 0.2 * k,
					at = Vector3.new(-2.6 - 0.35 * k, 1.8 - 1.2 * k, 0),
					tilt = -10 + 6 * k,
				})
				table.insert(made, gui)
				label.TextTransparency = 1
				TweenService:Create(label, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
				after(root, over, 1.76 - 0.08 * k, function()
					TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
						:Play()
				end)
			end)
		end
	end)
	return function()
		gone = true
		for _, item in ipairs(made) do
			item:Destroy()
		end
	end
end

-- Nah, I'd Win (the owner's Q33, and their reference of 2026-10-22): Gojo's line in a manga speech bubble up to the
-- right of the head, popping up on the pose (0.3 s) and held while the emote lasts; it faces the camera and is seen
-- by everyone near, in a case too. The bubble is a picture (the Core set's SpeechNah, art/scripts/textures.py:
-- a hand-drawn balloon, its tail down towards the head, NAH, I'D WIN. in italic brush capitals); before that is
-- imported, a plain white card with the words.
local BUBBLE_SIZE = 2.9 -- studs (the picture is square, the balloon taller than wide inside it)
FX.nahIdWin = function(character, preview)
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gui = Create("BillboardGui", {
		Name = "EmoteBubble",
		Adornee = head,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 60,
		Size = UDim2.fromScale(BUBBLE_SIZE, BUBBLE_SIZE),
		StudsOffset = Vector3.new(2.0, 1.6, 0),
		Parent = head,
	}) :: BillboardGui
	gui:SetAttribute("DGEmote", true)
	local holder = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	local picture = Assets.texture("SpeechNah")
	if picture ~= "" then
		Create("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = picture,
			ScaleType = Enum.ScaleType.Fit,
			Parent = holder,
		})
	else
		local card = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.62, 0.8),
			BackgroundColor3 = Color3.fromRGB(250, 250, 248),
			BorderSizePixel = 0,
			Parent = holder,
		})
		Create("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = 3, Parent = card })
		local words = Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Text = "NAH, I'D WIN.",
			TextScaled = true,
			FontFace = Font.fromEnum(Enum.Font.GothamBlack),
			TextColor3 = Color3.fromRGB(10, 10, 12),
			Parent = card,
		}) :: TextLabel
		words:SetAttribute("KeepFont", true)
	end
	local gone = false
	task.delay(0.3, function()
		if gone then
			return
		end
		if Motion.isReduced() then
			holder.Size = UDim2.fromScale(1, 1)
		else
			TweenService:Create(
				holder,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.fromScale(1, 1) }
			):Play()
		end
	end)
	return function()
		gone = true
		gui:Destroy()
	end
end

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

-- Reaper's Cackle: a breath of dark smoke off the shoulders with each burst of the laugh, rising.
local SMOKE_RISE = ColorSequence.new(Color3.fromRGB(46, 44, 48), Color3.fromRGB(96, 92, 96))
FX.reapersCackle = accent(1.6, { 0.0, 0.4, 0.8, 1.2 }, function(character)
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		burst((torso.CFrame * CFrame.new(0, 1.1, 0)).Position, {
			color = SMOKE_RISE,
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
-- back (2.25 s) with a ring of dark dust out across the floor and dark smoke pouring up off him while he laughs;
-- everything dies away as he folds over (4.2 s). Under reduced motion there is no flare.
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
		Texture = textureOr("Smoke", "rbxasset://textures/particles/smoke_main.dds"),
		Color = SMOKE_RISE,
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
			local ground = floorUnder(sole, character)
			FxKit.rocks(ground, 3.2, 12)
			FxKit.shape("ring", CFrame.new(ground + Vector3.new(0, 0.06, 0)), {
				size = 13,
				seconds = 0.5,
				color = Color3.fromRGB(214, 210, 198),
				transparency = 0.4,
			})
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

-- The prop emotes' accents (S12) -------------------------------------------------------------------------------

-- Pre-Dawn Bonk: chips of wood off the bat and dust at the feet with each knock; the last one from on high
-- cracks with a warm flash of dawn and a ring of dust.
local WOOD = ColorSequence.new(Color3.fromRGB(170, 120, 70), Color3.fromRGB(110, 76, 44))
FX.preDawnBonk = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root then
		return nothing
	end
	local gone = false
	local function over()
		return gone
	end
	local function knock(big: boolean)
		local arm = character:FindFirstChild("Right Arm")
		if arm and arm:IsA("BasePart") then
			burst((arm.CFrame * CFrame.new(0, -1.0, -1.6)).Position, {
				color = WOOD,
				count = if big then 18 else 8,
				size = 0.22,
				speed = NumberRange.new(4, 8),
				life = NumberRange.new(0.3, 0.6),
				spread = 80,
				gravity = 24,
				light = 0,
			})
		end
		local sole = lowerSole(character)
		if sole then
			EmoteFx.thud(CFrame.new(sole), if big then 5 else 1.4)
		end
	end
	for _, t in ipairs({ 0.75, 1.25, 1.75 }) do
		after(root, over, t, function()
			knock(false)
		end)
	end
	after(root, over, 2.55, function()
		knock(true)
		if Motion.isReduced() then
			return
		end
		local ground = floorUnder((root :: BasePart).Position + (root :: BasePart).CFrame.LookVector * 1.6, character)
		FxKit.rocks(ground, 1.8, 9)
		FxKit.shape("dome", CFrame.new(ground), {
			size = 5,
			seconds = 0.35,
			color = Color3.fromRGB(168, 150, 120),
			material = Enum.Material.ForceField,
			transparency = 0.3,
		})
		local glow = Create("PointLight", {
			Color = Color3.fromRGB(255, 170, 90),
			Range = 14,
			Brightness = 5,
			Shadows = false,
			Parent = root,
		}) :: PointLight
		TweenService:Create(glow, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		task.delay(1.0, function()
			glow:Destroy()
		end)
	end)
	return function()
		gone = true
	end
end

-- Blindfold Lift: blue motes drifting round him while the blindfold is on (Infinity, idling).
local INFINITY = ColorSequence.new(Color3.fromRGB(170, 220, 255), Color3.fromRGB(90, 160, 255))
FX.blindfoldLift = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local at = Create("Attachment", { Name = "EmoteInfinity", Parent = root })
	at:SetAttribute("DGEmote", true)
	Create("ParticleEmitter", {
		Texture = SPARKLE,
		Color = INFINITY,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1.2, 2.0),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = if Motion.isReduced() then 3 else 8,
		Parent = at,
	})
	return function()
		at:Destroy()
	end
end

-- LIFT: as the blindfold goes up (0.9 s) the eyes light blue, a cold blue light comes up on him and the motes
-- burst out into a sphere round him (Infinity).
FX.blindfoldLiftUp = function(character, preview)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") or not root then
		return nothing
	end
	local gone = false
	local parts: { BasePart } = {}
	after(
		head,
		function()
			return gone
		end,
		0.9,
		function()
			for _, side in ipairs({ -0.2, 0.2 }) do
				local part = Create("Part", {
					Name = "EmoteEyes",
					Size = Vector3.new(0.2, 0.12, 0.06),
					Color = Color3.fromRGB(110, 200, 255),
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
			if preview then
				return
			end
			Create("PointLight", {
				Color = Color3.fromRGB(120, 190, 255),
				Range = 10,
				Brightness = if Motion.isReduced() then 1.5 else 4,
				Shadows = false,
				Parent = parts[1],
			})
			local torso = character:FindFirstChild("Torso")
			if torso and torso:IsA("BasePart") then
				burst(torso.Position, {
					color = INFINITY,
					count = if Motion.isReduced() then 10 else 30,
					size = 0.18,
					speed = NumberRange.new(5, 7),
					life = NumberRange.new(0.5, 0.8),
					spread = 180,
					light = 1,
				})
			end
		end
	)
	return function()
		gone = true
		for _, part in ipairs(parts) do
			part:Destroy()
		end
	end
end

-- Chair Perch: L's interview room, the same cold lamp and drifting dust as his crouch.
FX.chairPerch = function(character, preview, phase)
	return FX.aceCrouch(character, preview, phase)
end

-- The towers: a glint off each cube or die as it is set down; when one comes down, a puff of dust off the floor
-- and a scatter of sparkles.
local SUGAR = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 236, 255))
local function towerFx(at: { number }, base: Vector3, step: number, topple: number?): Fx
	return function(character, preview)
		local root = character:FindFirstChild("HumanoidRootPart")
		if preview or not root or not root:IsA("BasePart") then
			return nothing
		end
		local gone = false
		local function over()
			return gone
		end
		local floor = floorUnder(root.Position, character)
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local foot = CFrame.new(floor) * CFrame.Angles(0, yaw, 0) * CFrame.new(base)
		for k, t in ipairs(at) do
			after(root, over, t + 0.1, function()
				burst((foot * CFrame.new(0, step * (k - 0.5), 0)).Position, {
					color = SUGAR,
					count = 4,
					size = 0.25,
					speed = NumberRange.new(0.5, 1.5),
					life = NumberRange.new(0.25, 0.45),
					spread = 180,
					light = 1,
				})
			end)
		end
		if topple then
			after(root, over, topple + 0.3, function()
				EmoteFx.thud(foot, 3)
				burst((foot * CFrame.new(0, 0.4, 0)).Position, {
					color = SUGAR,
					count = 14,
					size = 0.2,
					speed = NumberRange.new(2, 4),
					life = NumberRange.new(0.4, 0.7),
					spread = 120,
					gravity = 6,
					light = 1,
				})
			end)
		end
		return function()
			gone = true
		end
	end
end
FX.sugarTower = towerFx({ 1.0, 1.8, 2.6, 3.4, 4.6 }, Vector3.new(1.45, 0, -0.7), 0.42)
FX.sugarTowerAdd = towerFx({ 1.3 }, Vector3.new(1.45, 2.1, -0.7), 0.42)
FX.sugarTowerTopple = towerFx({ 1.3 }, Vector3.new(1.45, 2.1, -0.7), 0.42, 1.6)
FX.diceTower = towerFx({ 0.9, 1.6, 2.3, 3.0, 3.7, 4.6 }, Vector3.new(-0.05, 0, -1.35), 0.42)
FX.diceTowerAdd = towerFx({ 1.3 }, Vector3.new(-0.05, 2.52, -1.35), 0.42)
FX.diceTowerTopple = towerFx({ 1.3 }, Vector3.new(-0.05, 2.52, -1.35), 0.42, 1.6)

-- Strawberry on Top: a soft pink sparkle off the strawberry as it is picked and as it is eaten, a warm light on it.
local PINK = ColorSequence.new(Color3.fromRGB(255, 190, 210), Color3.fromRGB(255, 120, 150))
FX.strawberryOnTop = accent(4.0, { 1.0, 2.8 }, function(character)
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		burst((arm.CFrame * CFrame.new(0, -1.15, -0.12)).Position, {
			color = PINK,
			count = 10,
			size = 0.2,
			speed = NumberRange.new(1, 2.5),
			life = NumberRange.new(0.4, 0.8),
			spread = 180,
			gravity = -1,
			light = 1,
		})
	end
end)

-- Two-Finger Grip: the phone's screen lights the face.
FX.twoFingerGrip = function(character, preview)
	local arm = character:FindFirstChild("Right Arm")
	if preview or not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local at = Create("Attachment", { Name = "EmoteScreen", Position = Vector3.new(0, -1.6, -0.3), Parent = arm })
	at:SetAttribute("DGEmote", true)
	Create("PointLight", {
		Color = Color3.fromRGB(200, 225, 255),
		Range = 5,
		Brightness = 1.6,
		Shadows = false,
		Parent = at,
	})
	return function()
		at:Destroy()
	end
end

-- Furious Scribbling: shavings of paper scratched up off the page by the pen, and on the Manual's open page the
-- name being written, stroke by stroke, line by line (the page the game writes on: ManualBook.page).
local SHAVINGS = ColorSequence.new(Color3.fromRGB(236, 226, 200), Color3.fromRGB(200, 186, 150))
-- The Death's Manual held in the hand (a rigged book among the emote's props).
local function heldManual(character: Model): Model?
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Model") and item.Name == "EmoteProp" and item:GetAttribute("ManualScale") ~= nil then
			return item
		end
	end
	return nil
end

local function scribbleOn(character: Model, gone: () -> boolean, strokes: number, every: number, red: boolean?)
	task.spawn(function()
		local book: Model? = nil
		for _ = 1, 20 do
			book = heldManual(character)
			if book or gone() then
				break
			end
			task.wait(0.05)
		end
		if not book or gone() then
			return
		end
		local sheet = ManualBook.page(book)
		local rule = ManualBook.rule(book)
		if not sheet or not rule then
			return
		end
		local gui = Create("SurfaceGui", {
			Name = "EmoteScribble",
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 60,
			LightInfluence = 0.6,
			Parent = sheet,
		}) :: SurfaceGui
		local random = Random.new(7)
		for k = 0, strokes - 1 do
			if gone() or not gui.Parent then
				return
			end
			local row = math.floor(k / 4) % rule.count
			local col = k % 4
			local y = (rule.first + rule.pitch * row) / rule.size.Y
			local x0 = rule.margin / rule.size.X
			local w = (1 - 2 * x0) / 4
			Create("Frame", {
				BackgroundColor3 = if red then Color3.fromRGB(180, 20, 30) else Color3.fromRGB(14, 12, 16),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(x0 + w * col, y),
				Size = UDim2.new(w * random:NextNumber(0.55, 0.95), 0, 0, if red then 6 else 3),
				Rotation = random:NextNumber(-3, 3),
				Parent = gui,
			})
			task.wait(every)
		end
	end)
end

FX.furiousScribbling = function(character, preview)
	local arm = character:FindFirstChild("Right Arm")
	if not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local gone = false
	local function over()
		return gone
	end
	scribbleOn(character, over, 60, 0.2)
	if not preview then
		onBeats(arm, over, 2.4, { 0.4, 1.2, 2.0 }, nil, function()
			burst((arm.CFrame * CFrame.new(0, -1.6, -0.3)).Position, {
				color = SHAVINGS,
				count = 4,
				size = 0.12,
				speed = NumberRange.new(1, 2.5),
				life = NumberRange.new(0.3, 0.5),
				spread = 80,
				gravity = 10,
				light = 0,
			})
		end)
	end
	return function()
		gone = true
	end
end

-- WRITE IT: the name written huge in red, the slash flaring red across the page with a spray of red sparks.
FX.furiousScribblingSlash = function(character, preview)
	local arm = character:FindFirstChild("Right Arm")
	if not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local gone = false
	local function over()
		return gone
	end
	scribbleOn(character, over, 4, 0.18, true)
	after(arm, over, 1.2, function()
		if preview then
			return
		end
		local tip = (arm.CFrame * CFrame.new(0, -1.6, -0.3)).Position
		burst(tip, {
			color = ColorSequence.new(CRIMSON),
			count = if Motion.isReduced() then 6 else 16,
			size = 0.18,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(0.3, 0.6),
			spread = 120,
			gravity = 12,
			light = 0.6,
		})
		if not Motion.isReduced() then
			local flare = Create("Part", {
				Name = "EmoteFlare",
				Size = Vector3.new(0.2, 0.2, 0.2),
				CFrame = CFrame.new(tip),
				Transparency = 1,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = workspace.CurrentCamera,
			}) :: BasePart
			local light =
				Create("PointLight", { Color = CRIMSON, Range = 9, Brightness = 6, Parent = flare }) :: PointLight
			TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
			task.delay(0.7, function()
				flare:Destroy()
			end)
		end
	end)
	return function()
		gone = true
	end
end

-- TOSS: the apple is taken at the top of its flight by an unseen death god, in a puff of black feathers.
local FEATHERS = ColorSequence.new(Color3.fromRGB(16, 14, 18), Color3.fromRGB(40, 36, 44))
FX.appleTossThrow = accent(2.0, { 1.15 }, function(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- (where the apple's flight peaks: thrown 7 studs up off the raised hand)
		burst((root.CFrame * CFrame.new(1.4, 8.5, -0.6)).Position, {
			color = FEATHERS,
			count = 12,
			size = 0.45,
			speed = NumberRange.new(1, 3),
			life = NumberRange.new(0.8, 1.3),
			spread = 180,
			gravity = 2,
			light = 0,
		})
	end
end)

-- Chocolate Snap: crumbs of chocolate off each bite.
local CHOC = ColorSequence.new(Color3.fromRGB(70, 40, 26), Color3.fromRGB(110, 70, 44))
FX.chocolateSnap = accent(3.2, { 0.75, 1.95 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		burst((head.CFrame * CFrame.new(0.2, -0.3, -0.7)).Position, {
			color = CHOC,
			count = 10,
			size = 0.14,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(0.4, 0.7),
			spread = 70,
			gravity = 20,
			light = 0,
		})
	end
end)

-- Forty Seconds: at forty (3.45 s) a red pulse rings out from him, a heartbeat.
FX.fortySeconds = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local gone = false
	after(
		root,
		function()
			return gone
		end,
		3.45,
		function()
			local floor = floorUnder(root.Position, character)
			local ring = Create("Part", {
				Name = "EmotePulse",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.05, 1, 1),
				CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = CRIMSON,
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = workspace.CurrentCamera,
			}) :: BasePart
			local info = TweenInfo.new(if Motion.isReduced() then 0.6 else 0.9, Enum.EasingStyle.Quad)
			TweenService:Create(ring, info, { Size = Vector3.new(0.05, 14, 14), Transparency = 1 }):Play()
			task.delay(1.0, function()
				ring:Destroy()
			end)
		end
	)
	return function()
		gone = true
	end
end

-- Menacing Pose's other two poses (NEXT POSE): their own signs (MENACES above).
FX.menacingPose2 = menace(MENACES.menacingPose2)
FX.menacingPose3 = menace(MENACES.menacingPose3)

-- Bye Bye Bye (Puppet Pop): the band dance it as marionettes; the same strings as Puppet Dance.
FX.puppetPop = function(character, preview, phase)
	return FX.puppetDance(character, preview, phase)
end

-- The Long Climb (Subaru's endless stair, after JJS's "Aura monster": the owner's Q24/Q38): a dark step with
-- glowing green edges forms under each foot as it comes down and fades behind; a giant green-lit image of the
-- climber's head and shoulders looms over them from behind, grinning (EmoteMedia FACES `manicGrin`; their own
-- face until that picture is in); green light falls like rain round them. Green is this emote's own colour. Seen
-- by everyone, in a case too; on low graphics only the steps, under reduced motion no rain and a still image.
local CLIMB_GREEN = Color3.fromRGB(64, 255, 118)
local CLIMB_DARK = Color3.fromRGB(9, 13, 10)
local STEP_SIZE = Vector3.new(3.8, 0.4, 1.7)
local STEP_EDGE = 0.09
local STEP_LIT = 0.7 -- seconds a step stays fully lit before it fades
local STEP_FADE = 1.5
local STEP_POOL = 8
local IMAGE_SCALE = 4
local IMAGE_BEHIND = 7.5 -- studs behind the climber
local IMAGE_SUNK = 1.5 -- studs of its body below the floor
local IMAGE_LEAN = math.rad(-12) -- leaning over them
local IMAGE_ALPHA = 0.62 -- its parts' transparency at full strength
local IMAGE_IN, IMAGE_OUT = 0.9, 0.6
local RAIN_UP = 18 -- studs above the climber the rain starts

type ClimbStep = { parts: { BasePart }, offsets: { CFrame }, base: { number }, tweens: { Tween } }

local function climbPart(name: string, size: Vector3, colour: Color3, material: Enum.Material): BasePart
	return Create("Part", {
		Name = name,
		Size = size,
		Color = colour,
		Material = material,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace.CurrentCamera,
	}) :: BasePart
end

-- A tread with its four edges.
local function climbStep(): ClimbStep
	local x, y, z = STEP_SIZE.X / 2, STEP_SIZE.Y / 2, STEP_SIZE.Z / 2
	local across = Vector3.new(STEP_SIZE.X + STEP_EDGE, STEP_EDGE, STEP_EDGE)
	local along = Vector3.new(STEP_EDGE, STEP_EDGE, STEP_SIZE.Z)
	return {
		parts = {
			climbPart("ClimbStep", STEP_SIZE, CLIMB_DARK, Enum.Material.SmoothPlastic),
			climbPart("ClimbEdge", across, CLIMB_GREEN, Enum.Material.Neon),
			climbPart("ClimbEdge", across, CLIMB_GREEN, Enum.Material.Neon),
			climbPart("ClimbEdge", along, CLIMB_GREEN, Enum.Material.Neon),
			climbPart("ClimbEdge", along, CLIMB_GREEN, Enum.Material.Neon),
		},
		offsets = {
			CFrame.identity,
			CFrame.new(0, y, -z),
			CFrame.new(0, y, z),
			CFrame.new(x, y, 0),
			CFrame.new(-x, y, 0),
		},
		base = { 0.04, 0, 0.2, 0.1, 0.1 }, -- (the front edge brightest, the back one dimmest)
		tweens = {},
	}
end

-- Lays a step (rising the last few tenths to its place) and lets it fade.
local function layStep(step: ClimbStep, at: CFrame)
	for _, tween in ipairs(step.tweens) do
		tween:Cancel()
	end
	table.clear(step.tweens)
	local rise = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fade = TweenInfo.new(STEP_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, STEP_LIT)
	for i, part in ipairs(step.parts) do
		local goal = at * step.offsets[i]
		part.CFrame = goal * CFrame.new(0, -0.3, 0)
		part.Transparency = step.base[i]
		local up = TweenService:Create(part, rise, { CFrame = goal })
		local out = TweenService:Create(part, fade, { Transparency = 1 })
		up:Play()
		out:Play()
		table.insert(step.tweens, up)
		table.insert(step.tweens, out)
	end
end

-- The giant image: a copy of the climber's head, torso and arms with what they wear there (hair, a mask, a coat's
-- collar: so it is them; no hats, no legs), scaled up. Returns it, its parts, where each sits from the torso's
-- bottom middle, and for what the head wears its place on the head (it tips with the head). Nil when the body
-- cannot be copied.
local function climbImage(character: Model): (Model?, { BasePart }, { CFrame }, { [number]: CFrame })
	local copy = Stage.copyOf(character)
	local torso = if copy then copy:FindFirstChild("Torso") else nil
	if not copy or not torso or not torso:IsA("BasePart") then
		if copy then
			copy:Destroy()
		end
		return nil, {}, {}, {}
	end
	-- (nobody's body: no tags or marks a character's code would find, no neck it would die without)
	for _, tag in ipairs(copy:GetTags()) do
		copy:RemoveTag(tag)
	end
	for name in pairs(copy:GetAttributes()) do
		copy:SetAttribute(name, nil)
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
	end
	local keep = { Head = true, Torso = true, ["Right Arm"] = true, ["Left Arm"] = true }
	-- What it wears on the kept parts, and where on them (read before the joints go): a hat would sit on the giant
	-- head like a lid, so hats stay off, and the game's own hat cosmetic is not an accessory. Once the owner's grin
	-- is set (EmoteMedia), a mask or other face accessory comes off too, or it would hide the grin.
	local grin = EmoteMedia.face("manicGrin")
	local worn: { { handle: BasePart, on: string, offset: CFrame } } = {}
	for _, child in ipairs(copy:GetChildren()) do
		local handle = if child:IsA("Accessory") then child:FindFirstChild("Handle") else nil
		local off = child:IsA("Accessory")
			and (
				child.AccessoryType == Enum.AccessoryType.Hat
				or (grin and child.AccessoryType == Enum.AccessoryType.Face)
			)
		if handle and handle:IsA("BasePart") and not off then
			for _, joint in ipairs(handle:GetDescendants()) do
				if joint:IsA("JointInstance") then
					local other = if joint.Part0 == handle then joint.Part1 else joint.Part0
					if other and keep[other.Name] and other.Parent == copy then
						table.insert(
							worn,
							{ handle = handle, on = other.Name, offset = other.CFrame:ToObjectSpace(handle.CFrame) }
						)
						break
					end
				end
			end
		end
	end
	local kept: { [Instance]: boolean } = {}
	for _, entry in ipairs(worn) do
		kept[entry.handle.Parent :: Instance] = true
	end
	for _, child in ipairs(copy:GetChildren()) do
		if
			(child:IsA("BasePart") and not keep[child.Name])
			or (child:IsA("Accessory") and not kept[child])
			or child:IsA("CharacterMesh")
			or child:IsA("Tool")
			or (child:IsA("Model") and child ~= copy)
		then
			child:Destroy()
		end
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("Attachment") then
			item:Destroy()
		end
	end
	local k = IMAGE_SCALE
	local tSize = torso.Size * k
	local parts: { BasePart } = {}
	local places: { CFrame } = {}
	local onHead: { [number]: CFrame } = {}
	local placeOf: { [string]: CFrame } = {}
	for _, name in ipairs({ "Torso", "Head", "Right Arm", "Left Arm" }) do
		local part = copy:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local size = part.Size * k
			part.Size = size
			part.Anchored = true
			part.CastShadow = false
			for _, mesh in ipairs(part:GetChildren()) do
				if mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.FileMesh then
					mesh.Scale *= k
					mesh.Offset *= k
				end
			end
			-- (standing straight, the arms at its sides: the pose of the moment would freeze mid-swing)
			local at = if name == "Head"
				then Vector3.new(0, tSize.Y + size.Y / 2, 0)
				elseif name == "Right Arm" then Vector3.new((tSize.X + size.X) / 2, tSize.Y / 2, 0)
				elseif name == "Left Arm" then Vector3.new(-(tSize.X + size.X) / 2, tSize.Y / 2, 0)
				else Vector3.new(0, tSize.Y / 2, 0)
			table.insert(parts, part)
			table.insert(places, CFrame.new(at))
			placeOf[name] = CFrame.new(at)
		end
	end
	for _, entry in ipairs(worn) do
		local handle, on = entry.handle, placeOf[entry.on]
		if on then
			handle.Size *= k
			handle.Anchored = true
			handle.CastShadow = false
			for _, mesh in ipairs(handle:GetChildren()) do
				if mesh:IsA("SpecialMesh") then
					mesh.Scale *= k
					mesh.Offset *= k
				end
			end
			local offset = CFrame.new(entry.offset.Position * k) * entry.offset.Rotation
			table.insert(parts, handle)
			table.insert(places, on * offset)
			if entry.on == "Head" then
				onHead[#parts] = offset
			end
		end
	end
	local head = copy:FindFirstChild("Head")
	local face = if head then head:FindFirstChild("face") else nil
	local painted = if head then head:GetAttribute("LHeadTexture") else nil
	if head and head:IsA("MeshPart") and type(painted) == "string" and face and face:IsA("Decal") then
		-- (an avatar's own painted head, Services/DynamicHeads: the grin alone on a plain head once it is set, else
		-- the painted face alone; never the two faces at once)
		if grin then
			head.TextureID = ""
			face.Texture = grin
		else
			face:Destroy()
		end
	elseif face and face:IsA("Decal") and grin then
		face.Texture = grin
	elseif face and face:IsA("Decal") and next(onHead) and face.Texture == "rbxasset://textures/face.png" then
		-- (Roblox's plain smile under a mask or hair the head wears: hidden on the body, it would show through the
		-- see-through image)
		face:Destroy()
	end
	copy.Name = "ClimbImage"
	return copy, parts, places, onHead
end

local function climbRain(at: Vector3): BasePart
	local holder = climbPart("ClimbRain", Vector3.new(34, 0.5, 34), CLIMB_GREEN, Enum.Material.SmoothPlastic)
	holder.CFrame = CFrame.new(at + Vector3.new(0, RAIN_UP, 0))
	local texture = Assets.texture("RainStreak")
	Create("ParticleEmitter", {
		Texture = if texture ~= "" then texture else "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(CLIMB_GREEN),
		LightEmission = 0.9,
		LightInfluence = 0.1,
		Size = NumberSequence.new(0.14),
		Squash = NumberSequence.new(7),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(0.15, 0.4),
			NumberSequenceKeypoint.new(1, 0.65),
		}),
		Lifetime = NumberRange.new(0.48, 0.52),
		Rate = 110,
		Speed = NumberRange.new(40, 44),
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		SpreadAngle = Vector2.new(1, 1),
		Parent = holder,
	})
	return holder
end

FX.theLongClimb = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local low = Governor.low("emoteFx")
	local calm = Motion.isReduced()
	local gone = false
	local steps: { ClimbStep } = {}
	local nextStep = 1

	local function heading(): Vector3
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	end

	-- a green light on the newest step
	local glow: BasePart? = nil
	if not low then
		glow = climbPart("ClimbGlow", Vector3.new(0.2, 0.2, 0.2), CLIMB_GREEN, Enum.Material.SmoothPlastic)
		Create("PointLight", { Color = CLIMB_GREEN, Range = 8, Brightness = 1.6, Shadows = false, Parent = glow })
	end
	local footfall = LocomotionController.Footfall:Connect(function(who: Model)
		local sole = if who == character and not gone then lowerSole(character) else nil
		if not sole then
			return
		end
		local way = heading()
		local floor = floorUnder(sole, character)
		local middle = Vector3.new(root.Position.X, floor.Y, root.Position.Z) + way * (sole - root.Position):Dot(way)
		local step = steps[nextStep]
		if not step then
			step = climbStep()
			steps[nextStep] = step
		end
		nextStep = nextStep % STEP_POOL + 1
		layStep(step, CFrame.lookAt(middle, middle + way) * CFrame.new(0, 0.03 - STEP_SIZE.Y / 2, 0))
		if not low then
			FxKit.shape("ring", CFrame.new(middle + Vector3.new(0, 0.06, 0)), {
				size = 4.6,
				seconds = 0.35,
				color = CLIMB_GREEN,
				transparency = 0.35,
			})
		end
		if glow then
			glow.CFrame = CFrame.new(middle + Vector3.new(0, 0.6, 0))
		end
	end)

	-- the image behind, and the rain
	local image, parts, places, onHead = nil, {}, {}, {}
	if not low then
		image, parts, places, onHead = climbImage(character)
	end
	local highlight: Highlight? = nil
	local face: Decal? = nil
	local rain = if image and not calm then climbRain(root.Position) else nil
	if image then
		-- (under the camera, with the climb's other parts: as a body with a Humanoid, Roblox keeps its torso solid,
		-- and in the world the climber's own walk met it as a wall and turned back at once; 2026-10-23)
		image.Parent = workspace.CurrentCamera
		highlight = Create("Highlight", {
			Adornee = image,
			FillColor = CLIMB_GREEN,
			OutlineColor = CLIMB_GREEN,
			FillTransparency = 1,
			OutlineTransparency = 1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Parent = image,
		}) :: Highlight
		local head = image:FindFirstChild("Head")
		if head then
			Create("PointLight", { Color = CLIMB_GREEN, Range = 20, Brightness = 1.4, Shadows = false, Parent = head })
			local decal = head:FindFirstChild("face")
			face = if decal and decal:IsA("Decal") then decal else nil
		end
	end
	local strength, fadeTo, fadeTime = 0, 1, IMAGE_IN -- 0 unseen .. 1 at full
	local base: CFrame? = nil
	local t0, last = os.clock(), os.clock()
	local render = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if not root.Parent then
			return
		end
		if rain then
			rain.CFrame = CFrame.new(root.Position + Vector3.new(0, RAIN_UP, 0))
		end
		if not image then
			return
		end
		local move = dt / fadeTime
		strength = if fadeTo > strength then math.min(strength + move, fadeTo) else math.max(strength - move, fadeTo)
		local way = heading()
		local spot = floorUnder(root.Position, character) - way * IMAGE_BEHIND
		local goal = CFrame.lookAt(spot, spot + way) * CFrame.new(0, -IMAGE_SUNK, 0)
		-- (it follows a beat behind, swinging round after a turn)
		base = if base then base:Lerp(goal, 1 - math.exp(-dt * 3.5)) else goal
		local t = now - t0
		local sway = if calm
			then CFrame.identity
			else CFrame.new(0, 0.35 * math.sin(t * 1.1), 0) * CFrame.Angles(
				0,
				0,
				math.rad(3.5) * math.sin(t * 0.8)
			)
		local frame = (base :: CFrame) * sway * CFrame.Angles(IMAGE_LEAN, 0, 0)
		local cframes = table.create(#parts)
		local headAt: CFrame? = nil
		for i, part in ipairs(parts) do
			local place = frame * places[i]
			if part.Name == "Head" and part.Parent == image then
				if not calm then
					-- (the head tipped slowly to one side and back: the grin's madness)
					place *= CFrame.Angles(0, 0, math.rad(9) * math.sin(t * 0.55))
				end
				headAt = place
			elseif onHead[i] and headAt then
				-- (what the head wears tips with it)
				place = headAt * onHead[i]
			end
			cframes[i] = place
			part.Transparency = 1 - (1 - IMAGE_ALPHA) * strength
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		if face then
			face.Transparency = 1 - 0.9 * strength
		end
		if highlight then
			highlight.FillTransparency = 1 - 0.4 * strength
			highlight.OutlineTransparency = 1 - 0.85 * strength
		end
	end)

	return function()
		if gone then
			return
		end
		gone = true
		footfall:Disconnect()
		if glow then
			glow:Destroy()
		end
		-- the image fades out on its own clock, the rain stops falling, the steps go dark
		fadeTo, fadeTime = 0, IMAGE_OUT
		local emitter = if rain then rain:FindFirstChildOfClass("ParticleEmitter") else nil
		if emitter then
			emitter.Enabled = false
		end
		task.delay(IMAGE_OUT + 0.1, function()
			render:Disconnect()
			if image then
				image:Destroy()
			end
			if rain then
				rain:Destroy()
			end
		end)
		for _, step in ipairs(steps) do
			for _, tween in ipairs(step.tweens) do
				tween:Cancel()
			end
			for _, part in ipairs(step.parts) do
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
			task.delay(0.5, function()
				for _, part in ipairs(step.parts) do
					part:Destroy()
				end
			end)
		end
	end
end

-- Every other emote's accent (the shop overhaul's B7, the owner's Q21: every emote an effect of its own, scaled
-- by its tier): one small touch for everyone's emotes and the Scrawl ones, a contact beat for the duos, footfalls
-- for the strolls; each timed to its clip's own moments (art/scripts/check_anims.py's numbers: the hand's reach,
-- a sole coming down, the head at its lowest). Greys, bone and light: colour stays earned (docs/vfx.md).
local GLINT = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 220, 240))
local CRUMBS = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(222, 170, 80))
local STEEL = ColorSequence.new(Color3.fromRGB(230, 232, 238), Color3.fromRGB(150, 156, 166))
local SPORES = ColorSequence.new(Color3.fromRGB(236, 230, 210), Color3.fromRGB(200, 192, 170))
local BREATH = ColorSequence.new(Color3.fromRGB(226, 226, 230))

-- The end of an arm (its fist), a little further down than the arm's own end.
local function hand(character: Model, side: string): Vector3?
	local arm = character:FindFirstChild(side .. " Arm")
	return if arm and arm:IsA("BasePart") then (arm.CFrame * CFrame.new(0, -1.1, 0)).Position else nil
end

-- A point on the head (studs from its middle, in its own frame: -z is the face).
local function onHead(character: Model, offset: Vector3): Vector3?
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then (head.CFrame * CFrame.new(offset)).Position else nil
end

-- A small white glint (a catch of light), `count` sparks.
local function glint(at: Vector3?, count: number?, size: number?)
	if at then
		burst(at, {
			color = GLINT,
			count = count or 4,
			size = size or 0.28,
			speed = NumberRange.new(0.5, 1.6),
			life = NumberRange.new(0.18, 0.32),
			spread = 180,
			light = 1,
		})
	end
end

-- A sign (?, !) that floats up off the head and fades.
local function floatSign(character: Model, text: string, side: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local start = Vector3.new(0.9 * side, 3.2, 0)
	local gui, label = signLabel(root, {
		text = text,
		colour = Color3.fromRGB(236, 230, 214),
		stroke = Color3.fromRGB(12, 12, 14),
		size = 1.1,
		at = start,
		tilt = 10 * side,
	})
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffset = start + Vector3.new(0, 0.8, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		gui:Destroy()
	end)
end

-- Everyone's emotes ---------------------------------------------------------------------------------------------

-- Wave: the waving hand catches the light at each turn of the wave.
FX.wave = accent(2.4, { 0.63, 0.93, 1.2 }, function(character)
	glint(hand(character, "Right"), 3, 0.22)
end)
-- Point: a small crack of light off the fingertip as the arm comes out.
FX.point = accent(1.6, { 0.55 }, function(character)
	glint(hand(character, "Left"), 6, 0.26)
end)
-- Cheer: scraps of paper thrown up at the top of the jump.
FX.cheer = accent(2.2, { 0.73 }, function(character)
	local at = onHead(character, Vector3.new(0, 1.4, 0))
	if at then
		burst(at, {
			color = PAPER,
			count = 10,
			size = 0.28,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(1.0, 1.5),
			spread = 70,
			gravity = 4,
			light = 0,
		})
	end
end)
-- Laugh: a little breath of laughter from the mouth with each burst.
FX.laugh = accent(1.2, { 0.37 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.2, -0.7))
	if at then
		burst(at, {
			color = BREATH,
			count = 3,
			size = 0.3,
			speed = NumberRange.new(0.6, 1.2),
			life = NumberRange.new(0.35, 0.55),
			spread = 30,
			gravity = -1,
			light = 0,
			direction = Enum.NormalId.Front,
		})
	end
end)
-- Dance: dust under each step.
FX.dance = accent(1.6, { 0.13, 0.67, 0.9, 1.23 }, function(character)
	stepDust(character, 0.8)
end)
-- Salute: a glint off the hand as it snaps to the brow.
FX.salute = accent(2.0, { 0.77 }, function(character)
	glint(hand(character, "Right"), 4, 0.24)
end)
-- Bow: a breath of dust round the feet at the bottom of the bow.
FX.bow = accent(2.6, { 1.33 }, function(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		EmoteFx.thud(CFrame.new(floorUnder(root.Position, character)), 2.4)
	end
end)
-- Shrug: a question mark floats up off the head as the shoulders come up.
FX.shrug = accent(2.0, { 1.0 }, function(character)
	floatSign(character, "?", 1)
end)
-- Facepalm: a little star of light where the palm meets the face.
FX.facepalm = accent(2.4, { 0.73 }, function(character)
	glint(onHead(character, Vector3.new(0, 0.1, -0.7)), 6, 0.3)
end)
-- High Five and Handshake: the hands meet with a burst of light (a duo's contact beat).
FX.highFive = accent(2.0, { 0.73 }, function(character)
	local at = hand(character, "Right")
	if at then
		burst(at, {
			color = GLINT,
			count = 12,
			size = 0.32,
			speed = NumberRange.new(4, 8),
			life = NumberRange.new(0.15, 0.3),
			spread = 180,
			light = 1,
		})
	end
end)
FX.handshake = accent(2.4, { 1.0 }, function(character)
	glint(hand(character, "Right"), 5, 0.24)
end)

-- Scrawl ---------------------------------------------------------------------------------------------------------

-- Bounce Pump: dust on every other beat of the bounce (16 beats to the loop).
FX.bouncePump = accent(6.4865, { 0, 0.81, 1.62, 2.43, 3.24, 4.05, 4.86, 5.68 }, function(character)
	stepDust(character, 1.0)
end)
-- Potato Chip: crumbs off the bite.
FX.chip = accent(3.4, { 1.4 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.25, -0.65))
	if at then
		burst(at, {
			color = CRUMBS,
			count = 8,
			size = 0.22,
			speed = NumberRange.new(2, 4),
			life = NumberRange.new(0.4, 0.7),
			spread = 60,
			gravity = 18,
			light = 0.4,
		})
	end
end)
-- Coin Flip: the coin flashes at the top of its toss, and again as it is slapped down.
FX.coinFlip = accent(3.0, { 0.95, 1.55 }, function(character, at)
	local fist = hand(character, if at < 1.5 then "Right" else "Left")
	if fist then
		burst(fist + Vector3.new(0, if at < 1.5 then 3.0 else 0.2, 0), {
			color = GOLD,
			count = 4,
			size = 0.3,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.2, 0.35),
			spread = 180,
			light = 1,
		})
	end
end)
-- Dance 2 and Dance 3: dust under the steps.
FX.dance2 = accent(2.1667, { 0.7, 1.73 }, function(character)
	stepDust(character, 0.9)
end)
FX.dance3 = accent(1.6, { 0.4, 1.2 }, function(character)
	stepDust(character, 0.9)
end)
-- Foot Scratch: dust kicked up by the scratching foot.
FX.footScratch = accent(2.0, { 0.5, 1.5 }, function(character)
	stepDust(character, 0.6)
end)
-- Hair Twirl: a few motes of light off the twirling fingers.
FX.hairTwirl = accent(2.4, { 0.93 }, function(character)
	glint(hand(character, "Right"), 3, 0.18)
end)
-- Jawline Check: the anime "ting" of light down the jaw at the flick.
FX.jawlineCheck = accent(3.2, { 1.8 }, function(character)
	glint(onHead(character, Vector3.new(0.35, -0.45, -0.45)), 7, 0.36)
end)
-- Take the L: dust under the hops.
FX.takeTheL = accent(1.6, { 0.33, 1.13 }, function(character)
	stepDust(character, 0.9)
end)
-- The Classic: dust under each step of the routine.
FX.theClassic = accent(6.0, { 0.5, 1.1, 1.7, 2.33, 3.73, 4.3, 4.8 }, function(character)
	stepDust(character, 0.9)
end)
-- The Eyebrow: a glint off the raised brow.
FX.theEyebrow = accent(3.4, { 0.8 }, function(character)
	glint(onHead(character, Vector3.new(0.3, 0.3, -0.62)), 4, 0.26)
end)
-- Think: a faint spark of an idea by the temple now and then.
FX.think = accent(4.0, { 0.63, 2.6 }, function(character)
	local at = onHead(character, Vector3.new(0.6, 0.5, -0.2))
	if at then
		burst(at, {
			color = THOUGHT,
			count = 4,
			size = 0.16,
			speed = NumberRange.new(0.6, 1.2),
			life = NumberRange.new(0.3, 0.5),
			spread = 60,
			light = 1,
		})
	end
end)
-- Two Weeks' Notice: the resignation thrown up in a scatter of paper.
FX.twoWeeksNotice = accent(3.2, { 2.23 }, function(character)
	local at = onHead(character, Vector3.new(0, 1.6, 0))
	if at then
		burst(at, {
			color = PAPER,
			count = 12,
			size = 0.36,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(1.2, 1.8),
			spread = 75,
			gravity = 3,
			light = 0,
		})
	end
end)

-- Penned ---------------------------------------------------------------------------------------------------------

-- Apple Toss: the apple catches the light as it leaves the hand, and as it is caught.
FX.appleToss = accent(3.6, { 0.5, 2.9 }, function(character)
	glint(hand(character, "Right"), 4, 0.26)
end)
-- Excuse Me, Sir: a polite little cough into the air before the look up.
FX.excuseMeSir = accent(1.6, { 0.4 }, function(character)
	local at = onHead(character, Vector3.new(0, -0.25, -0.7))
	if at then
		burst(at, {
			color = BREATH,
			count = 2,
			size = 0.25,
			speed = NumberRange.new(0.5, 1),
			life = NumberRange.new(0.3, 0.5),
			spread = 25,
			gravity = -1,
			light = 0,
			direction = Enum.NormalId.Front,
		})
	end
end)

-- The duos and the strolls (Sealed and up) -----------------------------------------------------------------------

-- Cuffed Together: the chain clinks taut with a spark of steel at the cuff.
FX.cuffedLead = accent(2.0, { 0.3 }, function(character)
	local at = hand(character, "Left")
	if at then
		burst(at, {
			color = STEEL,
			count = 5,
			size = 0.2,
			speed = NumberRange.new(2, 4),
			life = NumberRange.new(0.15, 0.3),
			spread = 120,
			gravity = 10,
			light = 1,
		})
	end
end)

-- Match Point: the ball pocks off the racket with a puff of white each time it is hit (DuoController's strokes
-- call this; the ready loop itself is still).
function EmoteFx.pock(character: Model)
	if Governor.low("emoteFx") then
		return
	end
	local at = hand(character, "Right")
	if at then
		burst(at + (character:GetPivot().LookVector * 1.4), {
			color = GLINT,
			count = 8,
			size = 0.3,
			speed = NumberRange.new(5, 9),
			life = NumberRange.new(0.12, 0.25),
			spread = 140,
			light = 1,
		})
	end
end
FX.matchPointServe = function()
	return nothing
end

-- The strolls on the move: each footfall of the walk (LocomotionController.Footfall) leaves its own mark.
local function strollSteps(make: (character: Model) -> ()): Fx
	return function(character, preview)
		if preview then
			return nothing
		end
		local connection = LocomotionController.Footfall:Connect(function(who: Model)
			if who == character then
				make(character)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end
end
-- Griddy: dust kicked up off each landing heel.
FX.griddy = strollSteps(function(character)
	stepDust(character, 1.2)
end)
-- Parade March: a crisp little stamp of dust under each step.
FX.paradeMarch = strollSteps(function(character)
	stepDust(character, 1.5)
end)
-- Mushroom Stroll: pale spores puffing up where each foot comes down.
FX.mushroomStroll = strollSteps(function(character)
	local sole = lowerSole(character)
	if sole then
		burst(sole + Vector3.new(0, 0.2, 0), {
			color = SPORES,
			count = 5,
			size = 0.16,
			speed = NumberRange.new(0.6, 1.4),
			life = NumberRange.new(0.8, 1.3),
			spread = 50,
			gravity = -0.6,
			light = 0.3,
		})
	end
end)
-- Not My Problem: a lazy scuff of dust behind each dragging step.
FX.notMyProblem = strollSteps(function(character)
	stepDust(character, 0.6)
end)

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
	preDawnBonk = 2,
	blindfoldLift = 2,
	blindfoldLiftUp = 2,
	chairPerch = 2,
	sugarTower = 2,
	sugarTowerAdd = 2,
	sugarTowerTopple = 2,
	diceTower = 2,
	diceTowerAdd = 2,
	diceTowerTopple = 2,
	strawberryOnTop = 2,
	twoFingerGrip = 1,
	furiousScribbling = 1,
	furiousScribblingSlash = 1,
	appleTossThrow = 1,
	chocolateSnap = 1,
	fortySeconds = 1,
	impossibleLean = 1,
	itsYou = 1,
	deducing = 1,
	reapersCackle = 1,
	finalBreakdown = 3,
	theLongClimb = 1,
	nahIdWin = 1,
}

-- How strong an emote's effects may be here, now: its own rung (Shared/EmoteInfo; in a case too, Shared/
-- EmotePolicy), at most one small accent on low graphics (World/Governor).
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
	if size >= 2.5 then
		FxKit.shape("ring", at + Vector3.new(0, 0.05, 0), {
			size = size * 2.4,
			seconds = 0.4,
			color = Color3.fromRGB(150, 146, 140),
			material = Enum.Material.ForceField,
			transparency = 0.2,
		})
	end
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

-- The wisp: every emote begins and ends in a little breath of pale grey dust round the feet, rising and gone
-- (the Core set's smoke, else Roblox's own; nothing on low graphics or under reduced motion).
function EmoteFx.wisp(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or Governor.low("emoteFx") or Motion.isReduced() then
		return
	end
	local at = Create("Attachment", { Name = "EmoteWisp", Position = Vector3.new(0, -2.6, 0), Parent = root })
	at:SetAttribute("DGEmote", true)
	local emitter = Create("ParticleEmitter", {
		Texture = textureOr("Smoke", "rbxasset://textures/particles/smoke_main.dds"),
		Color = ColorSequence.new(Color3.fromRGB(168, 166, 170)),
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
