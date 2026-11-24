-- The helpers the emote effects share (EmoteFx/init and the family modules beside this one): the body and floor
-- finders, the accent timer (`accent`, `onBeats`), the particle sprays (`burst`, `pieces`, `glint`), the signs
-- and the footfall dust. Code moved here unchanged from the old one-file Controllers/EmoteFx.luau (ticket
-- V2.1, 2026-11-17). `EmoteFx` is the one public table: it is made here so every family can call EmoteFx.thud;
-- init.luau fills in the rest of it and returns it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)

local EmoteFx = {}

-- (phase: seconds into the clip the emote started at here, for a loop that joined the shared beat)
export type Fx = (character: Model, preview: boolean, phase: number?) -> () -> ()

local function nothing() end

-- The floor under a point (or 3 studs under it when nothing is found), ignoring characters' own parts.
local function floorUnder(at: Vector3, character: Model): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

-- This player's own body: the screen's moments (a shake, a flash, an impact frame, the grade leaning toward the
-- effect's colour) are for their own screen only.
local function mine(character: Model): boolean
	local me = Players.LocalPlayer
	return me ~= nil and me.Character == character
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

local CRIMSON = Color3.fromRGB(163, 25, 47)

-- Runs `fn` `seconds` after the start, unless the effect was cleared by then or the body went.
local function after(root: Instance, gone: () -> boolean, seconds: number, fn: () -> ())
	task.delay(seconds, function()
		if not gone() and root.Parent then
			fn()
		end
	end)
end

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
-- (one burst light at a time: a dance's accents land on every beat, and a light each would flicker the room)
local lastBurstLight = 0
local function hotOf(sequence: ColorSequence): Color3
	local c = sequence.Keypoints[1].Value
	return c:Lerp(Color3.new(1, 1, 1), 0.55)
end

local function burst(at: Vector3, spec: Burst)
	-- (the VFX kit's: specks that glow hot as they are born and shrink as they fly; streaks among them when they fly
	-- fast; a star at the heart of a bright one. 2026-11-14, the user: "make the vfx of the emotes 100x better": every
	-- burst now has a heart (a soft white-hot bloom that swells and is gone in a fifth of a second), throws its light on
	-- what is round it, rings out when it is fast, and leaves a few slow embers drifting up after it: the layers the
	-- references' hits have, on every emote that uses it)
	local accel = Vector3.new(0, -(spec.gravity or 0), 0)
	local spread = spec.spread or 60
	local hot = hotOf(spec.color)
	local list: { any } = {
		{
			{
				tex = "VfxEmber",
				color = spec.color,
				size = { { 0, spec.size * 1.15 }, { 0.6, spec.size * 0.8 }, { 1, 0 } },
				life = { spec.life.Min, spec.life.Max },
				speed = { spec.speed.Min, spec.speed.Max },
				spread = spread,
				dir = spec.direction,
				accel = accel,
				drag = 1.5,
				rot = { 0, 360 },
				light = math.max(spec.light or 0.5, 0.6),
				bright = 1.3,
			},
			spec.count,
		},
	}
	if spec.speed.Max >= 6 then
		table.insert(list, {
			{
				tex = "VfxStreak",
				color = spec.color,
				size = { { 0, spec.size * 0.9 }, { 1, spec.size * 0.25 } },
				squash = -1.8,
				life = { spec.life.Min * 0.8, spec.life.Max * 0.8 },
				speed = { spec.speed.Min * 1.2, spec.speed.Max * 1.2 },
				spread = spread,
				dir = spec.direction,
				accel = accel,
				drag = 2,
				face = "along",
				light = 1,
				bright = 1.3,
			},
			math.max(2, math.floor(spec.count / 2)),
		})
	end
	if (spec.light or 0.5) >= 0.8 then
		table.insert(list, {
			{
				tex = "VfxFlare",
				color = spec.color,
				size = { { 0, 0 }, { 0.25, spec.size * 7 }, { 1, 0 } },
				life = 0.3,
				rot = { 0, 360 },
				spin = { -60, 60 },
				bright = 1.2,
			},
			1,
		})
	end
	-- the heart: a bloom that swells fast and is gone
	table.insert(list, {
		{
			tex = "VfxGlow",
			color = { { 0, Color3.new(1, 1, 1) }, { 0.4, hot }, { 1, spec.color.Keypoints[1].Value } },
			size = { { 0, spec.size * 1.5 }, { 0.3, spec.size * 6 }, { 1, spec.size * 7 } },
			alpha = { { 0, 0.15 }, { 0.4, 0.55 }, { 1, 1 } },
			life = 0.22,
			speed = 0.01,
			light = 1,
			bright = 1.4,
			z = 0.5,
		},
		1,
	})
	-- the afterglow: a few embers left drifting up, slow, after the rest has gone
	if spec.count >= 4 then
		table.insert(list, {
			{
				tex = "VfxEmber",
				color = { { 0, hot }, { 1, spec.color.Keypoints[#spec.color.Keypoints].Value } },
				size = { { 0, spec.size * 0.5 }, { 0.5, spec.size * 0.4 }, { 1, 0 } },
				alpha = { { 0, 0.2 }, { 0.8, 0.4 }, { 1, 1 } },
				life = { spec.life.Max * 1.6, spec.life.Max * 2.6 },
				speed = { 0.4, 1.4 },
				spread = 180,
				accel = Vector3.new(0, 1.2, 0),
				drag = 1.2,
				light = 1,
				bright = 1.1,
			},
			math.max(2, math.floor(spec.count / 4)),
		})
	end
	Vfx.Emit.burst(at, list)
	-- its light on the floor, the body and what stands near (one at a time)
	local now = os.clock()
	if spec.count >= 6 and (spec.light or 0.5) >= 0.5 and now - lastBurstLight > 0.12 then
		lastBurstLight = now
		Vfx.Light.flash(at, hot, 6 + spec.size * 14, 1.2 + (spec.light or 0.5), 0.28)
	end
	-- a ring for a fast one, turned to the lens
	local camera = workspace.CurrentCamera
	if spec.speed.Max >= 8 and spec.count >= 8 and camera then
		local face = CFrame.lookAt(at, camera.CFrame.Position) * CFrame.Angles(math.rad(-90), 0, 0)
		Vfx.Beams.wave(face, spec.size * 0.6, spec.size * 7, 0.3, {
			tex = "VfxRingBand",
			color = hot,
			width = spec.size * 0.6,
			light = 1,
			bright = 1.3,
		})
	end
end

-- Bits of something solid thrown from a point (crumbs, shavings): broken chunks of its colour, lit by the scene,
-- tumbling and falling, a dusting of finer specks with them.
local function pieces(at: Vector3, color: Color3, count: number, size: number, speed: number, up: Vector3?)
	local cf = if up then CFrame.lookAt(at, at + up) * CFrame.Angles(math.rad(-90), 0, 0) else CFrame.new(at)
	Vfx.Emit.burst(cf, {
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = { { 0, color }, { 1, color:Lerp(Color3.new(0, 0, 0), 0.25) } },
				light = 0,
				lit = 0.85,
				size = { { 0, size }, { 1, size * 0.7 } },
				life = { 0.5, 0.9 },
				speed = { speed * 0.5, speed },
				spread = 60,
				accel = Vector3.new(0, -32, 0),
				rot = { 0, 360 },
				spin = { -400, 400 },
			},
			count,
		},
		{
			{
				tex = "VfxEmber",
				color = color,
				light = 0,
				lit = 0.8,
				size = { { 0, size * 0.35 }, { 1, 0 } },
				life = { 0.4, 0.7 },
				speed = { speed * 0.4, speed * 0.9 },
				spread = 70,
				accel = Vector3.new(0, -26, 0),
			},
			math.ceil(count / 2),
		},
		{
			-- (a little dust knocked off with them, of their own colour, hanging a moment)
			{
				tex = "VfxDust",
				grid = 4,
				mode = "OneShot",
				color = color:Lerp(Color3.fromRGB(150, 148, 146), 0.5),
				light = 0,
				lit = 0.7,
				size = { { 0, size * 1.2 }, { 1, size * 3.2 } },
				alpha = { { 0, 0.35 }, { 0.6, 0.6 }, { 1, 1 } },
				life = { 0.5, 0.8 },
				speed = { speed * 0.15, speed * 0.35 },
				spread = 80,
				drag = 3,
				rot = { 0, 360 },
				spin = { -30, 30 },
			},
			math.max(2, math.ceil(count / 4)),
		},
	})
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

-- (stage 4b fourth batch) The new kit's build or the old one, by the pilot's flag AT CALL TIME (a play test flips it): the old
-- build stays exactly as it was and `FX.x = flag("x", fresh, FX.x)` is written after it.
local function flag(name: string, fresh: Fx, old: Fx?): Fx
	local original: Fx = old or nothing
	return function(character, preview, phase)
		local on = (Pilot.on :: any)[name]
		return (if on then fresh else original)(character, preview, phase)
	end
end

-- Like `accent`, for the new kit: each beat is started `lead` seconds early (the recipes wait that long for their own hit),
-- and `make` is told the lead it really got (a beat at 0 s cannot start before the clip).
local function beats(length: number, times: { number }, lead: number, make: (character: Model, lead: number) -> ()): Fx
	return function(character, preview, phase)
		local root = character:FindFirstChild("HumanoidRootPart")
		if preview or not root then
			return nothing
		end
		local early: { number } = {}
		local given: { [number]: number } = {}
		for _, at in ipairs(times) do
			local l = math.min(lead, at)
			table.insert(early, at - l)
			given[at - l] = l
		end
		local gone = false
		onBeats(
			root,
			function()
				return gone
			end,
			length,
			early,
			phase,
			function(at)
				make(character, given[at] or lead)
			end
		)
		return function()
			gone = true
		end
	end
end

-- Where the lower sole is, as a frame on the floor facing the way the body faces (its up the world's).
local function soleFrame(character: Model): CFrame?
	local sole = lowerSole(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not sole or not root or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(sole, sole + look)
end

-- A frame at `at` whose UP points along `dir` (what the scatter recipe throws along).
local function throwing(at: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-3 or math.abs(dir.Unit.Y) > 0.99 then
		-- (straight up or down: a look along the world's up has no side to turn about)
		return if dir.Y < 0 then CFrame.new(at) * CFrame.Angles(math.pi, 0, 0) else CFrame.new(at)
	end
	return CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-90), 0, 0)
end

local function chest(character: Model): Vector3?
	local torso = character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso.Position else nil
end

local GOLD = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(230, 160, 40))

local PAPER = ColorSequence.new(Color3.fromRGB(245, 243, 236))

local THOUGHT = ColorSequence.new(Color3.fromRGB(200, 225, 255))

-- Every other emote's accent (the shop overhaul's B7, the owner's Q21: every emote an effect of its own, scaled
-- by its tier): one small touch for everyone's emotes and the Scrawl ones, a contact beat for the duos, footfalls
-- for the strolls; each timed to its clip's own moments (art/scripts/check_anims.py's numbers: the hand's reach,
-- a sole coming down, the head at its lowest). Greys, bone and light: colour stays earned (docs/vfx.md).
local GLINT = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 220, 240))

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
		-- (2026-11-14: the star that blooms and closes, turning, as anime draws a catch of light; then its sparks)
		Vfx.Recipes.twinkle(at, { color = Color3.new(1, 1, 1), scale = (size or 0.28) / 0.28 * 0.55 })
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

return {
	EmoteFx = EmoteFx,
	CRIMSON = CRIMSON,
	GLINT = GLINT,
	GOLD = GOLD,
	PAPER = PAPER,
	THOUGHT = THOUGHT,
	accent = accent,
	after = after,
	beats = beats,
	burst = burst,
	flag = flag,
	soleFrame = soleFrame,
	throwing = throwing,
	chest = chest,
	floatSign = floatSign,
	floorUnder = floorUnder,
	glint = glint,
	hand = hand,
	lowerSole = lowerSole,
	mine = mine,
	nothing = nothing,
	onBeats = onBeats,
	onHead = onHead,
	pieces = pieces,
	signLabel = signLabel,
	stepDust = stepDust,
}
