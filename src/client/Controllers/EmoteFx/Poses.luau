-- The poses: Menacing Pose and its five other poses, Low Battery and its charge, and the poses' accents (S11:
-- Impossible Lean, It's You, Nah, I'd Win, Deducing, Reaper's Cackle). Moved unchanged from the old one-file
-- Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)

local Common = require(script.Parent.Shared)
local EmoteFx = Common.EmoteFx
local nothing = Common.nothing
local mine = Common.mine
local signLabel = Common.signLabel
local after = Common.after
local burst = Common.burst
local lowerSole = Common.lowerSole
local accent = Common.accent
local THOUGHT = Common.THOUGHT

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

-- Menacing Pose: the sign of menace (ゴ) rising and fading round the body, one after another, a different
-- arrangement and colour for each of the three poses (NEXT POSE; the owner's Q33): violet by turns on either side;
-- bone white stacked in a column up the right; near-black outlined in white, in an arc behind the head.
type Menace = {
	colour: Color3,
	stroke: Color3,
	size: number,
	every: number,
	place: (Random, number) -> (Vector3, number),
	fresh: boolean?, -- wears the new kit's menace (the pilot, V3.2: only the first pose; Pilot.on.menacing)
	pose: string?, -- (fourth batch) the other poses wear it behind Pilot.on.menacingPoses, in the colours of this clip (Vfx/Palette.emote)
}

local MENACES: { [string]: Menace } = {
	menacingPose = {
		fresh = true,
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
		pose = "menacingPose2",
		colour = Color3.fromRGB(236, 230, 214),
		stroke = Color3.fromRGB(12, 12, 14),
		size = 1.5,
		every = 0.3,
		place = function(random: Random, k: number): (Vector3, number)
			return Vector3.new(2.3 + random:NextNumber(-0.15, 0.15), -0.6 + (k % 4) * 0.9, 0), random:NextNumber(-6, 6)
		end,
	},
	menacingPose3 = {
		pose = "menacingPose3",
		colour = Color3.fromRGB(26, 22, 30),
		stroke = Color3.fromRGB(236, 230, 214),
		size = 2.2,
		every = 0.5,
		place = function(random: Random, k: number): (Vector3, number)
			local a = math.rad(-70 + (k % 5) * 35 + random:NextNumber(-6, 6))
			return Vector3.new(3.2 * math.sin(a), 2.0 + 1.6 * math.cos(a), -1.5), math.deg(a) * 0.4
		end,
	},
	-- (4: DIO thrown back, the signs bursting up out of him in a crown, blood red on black)
	menacingPose4 = {
		pose = "menacingPose4",
		colour = Color3.fromRGB(196, 24, 44),
		stroke = Color3.fromRGB(10, 4, 6),
		size = 2.0,
		every = 0.28,
		place = function(random: Random, k: number): (Vector3, number)
			local a = math.rad(-60 + (k % 6) * 24 + random:NextNumber(-5, 5))
			return Vector3.new(2.6 * math.sin(a), 3.0 + 0.9 * math.cos(a), -0.4), math.deg(a) * 0.6
		end,
	},
	-- (5: Jotaro's point, the signs in a line down his pointing side, steel blue)
	menacingPose5 = {
		pose = "menacingPose5",
		colour = Color3.fromRGB(120, 170, 232),
		stroke = Color3.fromRGB(8, 14, 30),
		size = 1.6,
		every = 0.26,
		place = function(random: Random, k: number): (Vector3, number)
			return Vector3.new(-2.4 - (k % 3) * 0.5, 2.4 - (k % 4) * 0.8, -0.8 + random:NextNumber(-0.2, 0.2)),
				random:NextNumber(-10, 4)
		end,
	},
	-- (6: Kira side-on, the signs drifting up behind the raised hand, a dull gold)
	menacingPose6 = {
		pose = "menacingPose6",
		colour = Color3.fromRGB(214, 180, 96),
		stroke = Color3.fromRGB(30, 18, 6),
		size = 1.7,
		every = 0.4,
		place = function(random: Random, _: number): (Vector3, number)
			return Vector3.new(random:NextNumber(1.4, 2.6), random:NextNumber(1.2, 3.0), random:NextNumber(0.4, 1.2)),
				random:NextNumber(-14, -2)
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
		local calm = Motion.isReduced()
		-- The first pose's menace on the new kit (the pilot V3.2; Pilot.on.menacing = false brings the old haze back). The
		-- idea: the room's pressure. Specks draw in to the chest, a small violet-white star is let go as the first sign
		-- lands, and a violet bank of fog climbs off the floor round the body until the pose ends. The five moments, a
		-- loop's (art/refs/vfx/aura.toml), built in Fresh/Menace:
		--   gather   0.0 s, specks drawn in to the chest (the reference's close-up before the power-up)
		--   hit      0.55 s, the release: a small star, a white-hot glint, a flat ring on the floor, sparks, one light
		--   body     from 0.6 s, the violet bank (a dark bank under it, motes in it) and one soft light, the signs in it
		--   break-up the bank thins away as the emitters stop when the pose ends (no cut)
		--   residue  the motes and the last of the fog drift 3 to 4 s after
		-- (this replaces the old haze and ember emitters only; the aura and the signs are untouched, AURAS' colours kept)
		-- (fourth batch: the other five poses wear the same bank in their own colours, behind Pilot.on.menacingPoses)
		local useFresh = (if kind.pose ~= nil then Pilot.on.menacingPoses else kind.fresh == true and Pilot.on.menacing)
			and not Vfx.quiet()
		local haze: Attachment? = nil
		local bank: { stop: () -> (), destroy: () -> () }? = nil
		if useFresh then
			bank = Fresh.menace(root.Position + Vector3.new(0, 0.6, 0), {
				ramp = Palette.emote(kind.pose or "menacingPose") :: Palette.Ramp,
				floor = 3.4,
				lean = Pilot.on.aura2,
			})
		else
			haze = Create("Attachment", { Name = "EmoteMenace", Position = Vector3.new(0, -0.5, 0.6), Parent = root })
			haze:SetAttribute("DGEmote", true)
		end
		-- the menace in the air: a haze of the signs' colour rising off the body and specks of it drifting up
		if not calm and haze then
			Vfx.Emit.make(haze, {
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = kind.colour:Lerp(Color3.new(0, 0, 0), 0.45),
				light = 0.15,
				lit = 0.3,
				size = { { 0, 2.2 }, { 1, 4.4 } },
				alpha = { { 0, 1 }, { 0.25, 0.72 }, { 0.6, 0.78 }, { 1, 1 } },
				life = { 1.6, 2.4 },
				speed = { 1.2, 2.4 },
				spread = 25,
				accel = Vector3.new(0, 0.6, 0),
				rot = { 0, 360 },
				spin = { -20, 20 },
				rate = 5,
				shape = Enum.ParticleEmitterShape.Box,
				z = -2,
			})
			Vfx.Emit.make(haze, {
				tex = "VfxEmber",
				color = kind.colour:Lerp(Color3.new(1, 1, 1), 0.3),
				size = { { 0, 0.14 }, { 1, 0 } },
				life = { 1.2, 2 },
				speed = { 1.5, 3 },
				spread = 30,
				accel = Vector3.new(0, 1.5, 0),
				bright = 1.3,
				rate = 8,
				shape = Enum.ParticleEmitterShape.Box,
			})
		end
		-- (each sign pops in a size too big and snaps down, shudders while it hangs, and rises away fading)
		local shaking: { TextLabel } = {}
		local stopShake = if calm
			then function() end
			else Vfx.Clock.every(function()
				for _, label in ipairs(shaking) do
					if label.Parent then
						label.Position = UDim2.fromOffset(random:NextInteger(-2, 2), random:NextInteger(-2, 2))
					end
				end
				return going or #shaking > 0
			end)
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
				table.insert(shaking, label)
				if not calm then
					gui.Size = UDim2.fromScale(kind.size * 1.5, kind.size * 1.5)
					TweenService:Create(
						gui,
						TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Size = UDim2.fromScale(kind.size, kind.size) }
					):Play()
				end
				local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				TweenService:Create(gui, info, { StudsOffset = start + Vector3.new(0, 1.4, 0) }):Play()
				TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(1.7, function()
					local i = table.find(shaking, label)
					if i then
						table.remove(shaking, i)
					end
					gui:Destroy()
				end)
				task.wait(kind.every)
			end
		end)
		return function()
			going = false
			if haze then
				haze:Destroy()
			end
			if bank then
				bank.stop()
			end
			task.delay(1.8, stopShake)
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
	local calm = Motion.isReduced()
	task.delay(2.7, function()
		local k = 0
		while going and gui.Parent do
			fill.Visible = not fill.Visible
			k += 1
			-- (empty: a fizzle of sparks off the battery now and then, and a thread of smoke)
			if not calm and fill.Visible and k % 3 == 1 then
				local at = (head.CFrame * CFrame.new(0, 1.8, 0)).Position
				Vfx.Emit.burst(at, {
					{
						{
							tex = "VfxStreak",
							color = { { 0, Color3.new(1, 1, 1) }, { 1, Color3.fromRGB(255, 120, 90) } },
							size = { { 0, 0.14 }, { 1, 0.03 } },
							squash = -1.8,
							life = { 0.12, 0.25 },
							speed = { 5, 9 },
							spread = 180,
							accel = Vector3.new(0, -20, 0),
							face = "along",
							bright = 1.5,
						},
						5,
					},
					{
						{
							tex = "VfxWisp",
							grid = 4,
							mode = "OneShot",
							color = Color3.fromRGB(150, 148, 152),
							light = 0,
							lit = 0.5,
							size = 1.2,
							alpha = { { 0, 0.3 }, { 0.7, 0.5 }, { 1, 1 } },
							life = 1.2,
							face = "up",
						},
						1,
					},
				})
			end
			task.wait(0.35)
		end
	end)
	return function()
		going = false
		gui:Destroy()
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
				if not Motion.isReduced() then
					-- (crackling arcs over the body, its edges lit blue-white, a snap of light)
					local cf = torso.CFrame
					for _, ends in ipairs({
						{ Vector3.new(-1.2, 1.6, -0.3), Vector3.new(0.9, -1.4, -0.4) },
						{ Vector3.new(1.1, 1.2, 0.2), Vector3.new(-0.8, -2.2, 0.3) },
						{ Vector3.new(0, 2.4, -0.2), Vector3.new(1.4, -0.4, -0.5) },
					}) do
						Vfx.Beams.bolt((cf * CFrame.new(ends[1])).Position, (cf * CFrame.new(ends[2])).Position, 0.22, {
							color = Color3.fromRGB(200, 230, 255),
							width = 0.45,
							bright = 1.6,
							light = 1,
							pieces = 6,
							jag = 0.45,
							rate = 30,
						})
					end
					Vfx.Rim.glow(
						character,
						Color3.fromRGB(170, 215, 255),
						0.05,
						{ fill = 0.25, fadeIn = 0.03, fadeOut = 0.3 }
					)
					Vfx.Light.flash(torso.Position, Color3.fromRGB(170, 215, 255), 12, 3, 0.25)
				end
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
	local own = mine(character)
	after(root, over, 0.24, function()
		local tip = (arm.CFrame * CFrame.new(0, -1.2, 0)).Position
		burst(tip, {
			color = CRACK,
			count = 14,
			size = 0.35,
			speed = NumberRange.new(6, 11),
			life = NumberRange.new(0.12, 0.28),
			spread = 180,
			light = 1,
		})
		if not calm then
			Vfx.Recipes.impact(CFrame.new(tip), { color = Color3.fromRGB(235, 240, 255), scale = 0.4, shake = own })
			if own then
				Vfx.Screen.punch(4, 0.25)
			end
		end
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
local INFINITY_BLUE = ColorSequence.new(Color3.fromRGB(170, 220, 255), Color3.fromRGB(90, 160, 255))
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
	local shimmer: Attachment? = nil
	task.delay(0.3, function()
		if gone then
			return
		end
		if Motion.isReduced() then
			holder.Size = UDim2.fromScale(1, 1)
		else
			-- (a white burst behind the bubble as it pops; Infinity's blue specks round him while he holds it)
			Vfx.Emit.burst((head.CFrame * CFrame.new(2.0, 1.6, 0)).Position, {
				tex = "VfxBurst",
				color = Color3.fromRGB(240, 246, 255),
				size = { { 0, 0.5 }, { 0.15, 4.4 }, { 1, 5 } },
				alpha = { { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } },
				life = 0.3,
				light = 0.5,
				rot = { 0, 360 },
				bright = 1.1,
				z = -1,
			}, 1)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local at = Create("Attachment", { Name = "EmoteInfinity", Parent = root }) :: Attachment
				at:SetAttribute("DGEmote", true)
				Vfx.Emit.make(at, {
					tex = "VfxEmber",
					color = INFINITY_BLUE,
					size = { { 0, 0 }, { 0.2, 0.13 }, { 1, 0 } },
					life = { 1.2, 2 },
					speed = { 0.3, 0.8 },
					spread = 180,
					bright = 1.4,
					rate = 9,
					shape = Enum.ParticleEmitterShape.Sphere,
					shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				})
				shimmer = at
			end
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
		if shimmer then
			shimmer:Destroy()
		end
	end
end

-- Deducing: a faint spark of a thought by the temple on each tap of the thumb (1.1 s and 3.1 s of the loop).

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

-- Menacing Pose's other five poses (NEXT POSE): their own signs (MENACES above).
FX.menacingPose2 = menace(MENACES.menacingPose2)
FX.menacingPose3 = menace(MENACES.menacingPose3)
FX.menacingPose4 = menace(MENACES.menacingPose4)
FX.menacingPose5 = menace(MENACES.menacingPose5)
FX.menacingPose6 = menace(MENACES.menacingPose6)

-- The fourth batch, on the new kit (stage 4b): the Penned poses below keep their idea, colour and beat, each behind its own flag in
-- Vfx/Pilot (false = the old build above, which stays as it was). Penned is an accent: 60 particles, 2 big sprites, 6 emitters, 1 light.
local flag = Common.flag
local beats = Common.beats
local soleFrame = Common.soleFrame

-- Low Battery's fizzle on the new kit: a few white-hot sparks and a thread of smoke where the battery is empty, now and then.
local FIZZLE_RAMP = Palette.pair(Color3.fromRGB(255, 150, 100), Color3.fromRGB(255, 244, 224))
local function lowBatteryFresh(character: Model, preview: boolean): () -> ()
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
	local calm = Motion.isReduced()
	task.delay(2.7, function()
		local k = 0
		while going and gui.Parent do
			fill.Visible = not fill.Visible
			k += 1
			-- (empty: a fizzle every third blink, a short spit of sparks off the battery and a grey thread of smoke)
			if not calm and fill.Visible and k % 3 == 1 then
				local at = (head.CFrame * CFrame.new(0, 1.8, 0)).Position
				Fresh.tap(at, { ramp = FIZZLE_RAMP, scale = 0.45, lite = true, sparks = 5, light = false, lead = 0.03 })
				Fresh.breath(at, { ramp = Palette.WORLD.smoke, scale = 0.7, lead = 0.03 })
			end
			task.wait(0.35)
		end
	end)
	return function()
		going = false
		gui:Destroy()
	end
end
FX.lowBattery = flag("lowBattery", lowBatteryFresh, FX.lowBattery)

-- Low Battery's CHARGE on the new kit: each jolt is a blue-white star and sparks at the chest and one crackling arc over the
-- body, its edges lit blue-white; the battery fills in jumps as before.
local CHARGE_RAMP = Palette.pair(Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 250, 220))
local function lowBatteryChargeFresh(character: Model, preview: boolean): () -> ()
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gui, fill = battery(head)
	fill.Size = UDim2.fromScale(0.06, 0.68)
	fill.BackgroundColor3 = Color3.fromRGB(205, 40, 40)
	local gone = false
	local function zap(at: number, to: number, color: Color3, last: boolean?)
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
				-- (a star and sparks at the chest on each jolt, its light on the last only; the crackling arcs of the old build are
				-- gone, three jolts of them were 20 emitters, and the body's blue-white edge lighting stays)
				Fresh.tap(
					torso.Position,
					{ ramp = CHARGE_RAMP, scale = 0.9, lite = true, sparks = 8, light = last == true, lead = 0.04 }
				)
				if not Motion.isReduced() then
					Vfx.Rim.glow(
						character,
						Color3.fromRGB(170, 215, 255),
						0.05,
						{ fill = 0.25, fadeIn = 0.03, fadeOut = 0.3 }
					)
				end
			end
		end)
	end
	zap(0.15, 0.3, Color3.fromRGB(230, 170, 40))
	zap(0.62, 0.6, Color3.fromRGB(200, 210, 60))
	zap(1.6, 0.84, Color3.fromRGB(110, 200, 110), true)
	return function()
		gone = true
		gui:Destroy()
	end
end
FX.lowBatteryCharge = flag("lowBattery", lowBatteryChargeFresh, FX.lowBatteryCharge)

-- Impossible Lean: the dust swept back off the floor from under the feet as the body tips (0.95 s), a low roll, a flat ring
-- and a scuff of sparks.
FX.impossibleLean = flag(
	"impossibleLean",
	beats(4.2, { 0.95 }, 0.06, function(character, lead)
		local at = soleFrame(character)
		local root = character:FindFirstChild("HumanoidRootPart")
		if at and root and root:IsA("BasePart") then
			Fresh.stepDust(at, { scale = 1.3, dir = -root.CFrame.LookVector, lead = lead })
		end
	end),
	FX.impossibleLean
)

-- It's You: the point lands (0.24 s) with a white crack of light off the fingertip (a sharp impact star, small), speed lines flash
-- out behind the body and ドドド stands beside it while the point is held; the speed lines and the signs are the old build's.
local CRACK_RAMP = Palette.pair(Color3.fromRGB(200, 220, 255), Color3.fromRGB(255, 255, 255))
local itsYouOld: Common.Fx = FX.itsYou
local function itsYouFresh(character: Model, preview: boolean): () -> ()
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
	local own = mine(character)
	local lead = 0.1
	after(root, over, 0.24 - lead, function()
		local tip = (arm.CFrame * CFrame.new(0, -1.2, 0)).Position
		Fresh.tap(tip, { ramp = CRACK_RAMP, scale = 2, sparks = 14, gather = true, lead = lead })
		after(root, over, lead, function()
			if own and not calm then
				Vfx.Screen.punch(4, 0.25)
			end
			if not calm then
				local lines = speedLines(root)
				table.insert(made, lines)
				for _, line in ipairs(lines:GetChildren()) do
					TweenService:Create(line, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
						:Play()
				end
			end
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
						TweenService
							:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 })
							:Play()
					end)
				end)
			end
		end)
	end)
	return function()
		gone = true
		for _, item in ipairs(made) do
			item:Destroy()
		end
	end
end
FX.itsYou = flag("itsYou", itsYouFresh, itsYouOld)

-- Deducing: a faint spark of a thought by the temple on each tap of the thumb (1.1 s and 3.1 s of the loop), a small cold star.
local THOUGHT_RAMP = Palette.pair(Color3.fromRGB(180, 215, 255), Color3.fromRGB(240, 248, 255))
FX.deducing = flag(
	"deducing",
	beats(4.0, { 1.1, 3.1 }, 0.1, function(character, lead)
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			Fresh.glint(
				(head.CFrame * CFrame.new(0.55, 0.45, -0.2)).Position,
				{ ramp = THOUGHT_RAMP, scale = 0.5, lead = lead }
			)
		end
	end),
	FX.deducing
)

-- Reaper's Cackle: a breath of dark smoke off the shoulders with each burst of the laugh, rising (Fresh.breath, dark smoke, no
-- second dark layer: a burst comes every 0.4 s).
local CACKLE_SMOKE = Palette.WORLD.smoke
FX.reapersCackle = flag(
	"reapersCackle",
	beats(1.6, { 0.0, 0.4, 0.8, 1.2 }, 0.08, function(character, lead)
		local torso = character:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			Fresh.breath(
				(torso.CFrame * CFrame.new(0, 1.1, 0)).Position,
				{ ramp = CACKLE_SMOKE, scale = 1.6, dark = false, lead = lead }
			)
		end
	end),
	FX.reapersCackle
)

return FX
