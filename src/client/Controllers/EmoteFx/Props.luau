-- The prop emotes' accents (S12): the bat, the blindfold, the towers, the strawberry, the phone, the Manual,
-- the apple toss, the chocolate, the forty seconds. Moved unchanged from the old one-file
-- Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local Create = require(Shared:WaitForChild("Create"))
local FxKit = require(script.Parent.Parent.Parent.Presentation.FxKit)
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)

local Common = require(script.Parent.Shared)
local EmoteFx = Common.EmoteFx
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local mine = Common.mine
local CRIMSON = Common.CRIMSON
local after = Common.after
local onBeats = Common.onBeats
local burst = Common.burst
local pieces = Common.pieces
local lowerSole = Common.lowerSole
local accent = Common.accent

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

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
	-- (motes on the skin of a sphere round him, a faint blue field breathing, now and then a thin ring of it
	-- passing out through the air)
	local calm = Motion.isReduced()
	Vfx.Emit.make(at, {
		tex = "VfxEmber",
		color = INFINITY,
		size = { { 0, 0 }, { 0.2, 0.14 }, { 1, 0 } },
		life = { 1.2, 2.0 },
		speed = { 0.3, 0.8 },
		spread = 180,
		bright = 1.4,
		rate = if calm then 3 else 10,
		shape = Enum.ParticleEmitterShape.Sphere,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	Vfx.Emit.make(at, {
		tex = "VfxGlow",
		color = Color3.fromRGB(120, 180, 255),
		size = { { 0, 6 }, { 0.5, 7 }, { 1, 6 } },
		alpha = { { 0, 1 }, { 0.3, 0.86 }, { 0.7, 0.86 }, { 1, 1 } },
		life = 3,
		rate = 0.7,
		locked = true,
		light = 0.6,
		bright = 0.7,
		z = -1,
	})
	if not calm then
		Vfx.Emit.make(at, {
			tex = "VfxRing",
			color = Color3.fromRGB(170, 215, 255),
			size = { { 0, 2 }, { 1, 8 } },
			alpha = { { 0, 0.8 }, { 0.4, 0.7 }, { 1, 1 } },
			life = 1.2,
			rate = 0.6,
			locked = true,
			light = 0.8,
			bright = 0.9,
		})
	end
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
				if not Motion.isReduced() then
					-- (Infinity unveiled: a star in each eye, a sphere of pale blue opening round him and fading, a ring
					-- of it out along the floor, his edges lit blue a moment)
					local cold = Color3.fromRGB(140, 200, 255)
					for _, eye in ipairs(parts) do
						Vfx.Emit.burst(eye.Position, {
							tex = "VfxFlare",
							color = Color3.fromRGB(200, 235, 255),
							size = { { 0, 0.2 }, { 0.25, 2.4 }, { 1, 0 } },
							life = 0.45,
							rot = { 0, 45 },
							spin = 90,
							bright = 1.6,
						}, 1)
					end
					Vfx.Shape.grow("sphere", CFrame.new(torso.Position), {
						size = 11,
						from = 0.2,
						seconds = 0.45,
						fade = 0.5,
						color = cold,
						material = Enum.Material.ForceField,
						transparency = 0.1,
					})
					local floor = floorUnder(torso.Position, character)
					Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.1, 0)), 1, 14, 0.6, {
						tex = "VfxRingBand",
						color = cold,
						width = 1.4,
						light = 0.7,
						bright = 1.1,
					})
					Vfx.Rim.glow(character, cold, 0.8, { fill = 0.1, fadeIn = 0.15, fadeOut = 0.8 })
					Vfx.Light.flash(torso.Position, cold, 18, 3, 0.5)
				end
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
	-- (the screen's own cold glow in the dark)
	Vfx.Emit
		.make(at, {
			tex = "VfxGlow",
			color = Color3.fromRGB(190, 215, 255),
			size = 1.6,
			alpha = { { 0, 1 }, { 0.05, 0.55 }, { 0.95, 0.55 }, { 1, 1 } },
			life = 4,
			rate = 1 / 3.8,
			locked = true,
			light = 1,
			bright = 0.7,
		})
		:Emit(1)
	return function()
		at:Destroy()
	end
end

-- Furious Scribbling: shavings of paper scratched up off the page by the pen, and on the Manual's open page the
-- name being written, stroke by stroke, line by line (the page the game writes on: ManualBook.page).
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
			pieces((arm.CFrame * CFrame.new(0, -1.6, -0.3)).Position, Color3.fromRGB(236, 226, 200), 4, 0.1, 2.5)
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
			-- (the stroke itself: a red slash flaring across the page, a star at the pen)
			Vfx.Emit.burst(CFrame.lookAt(tip, tip + arm.CFrame.LookVector), {
				{
					{
						tex = "VfxSlash",
						color = { { 0, Color3.fromRGB(255, 120, 120) }, { 1, CRIMSON } },
						size = { { 0, 1.2 }, { 0.2, 3.2 }, { 1, 3.6 } },
						alpha = { { 0, 0 }, { 0.5, 0.25 }, { 1, 1 } },
						life = 0.28,
						rot = { -30, -10 },
						light = 0.5,
						bright = 1.3,
						z = 1,
					},
					1,
				},
				{
					{
						tex = "VfxFlare",
						color = Color3.fromRGB(255, 200, 200),
						size = { { 0, 0.3 }, { 0.25, 2.2 }, { 1, 0 } },
						life = 0.22,
						rot = { 0, 360 },
						bright = 1.5,
						z = 1.2,
					},
					1,
				},
			})
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
		local peak = (root.CFrame * CFrame.new(1.4, 8.5, -0.6)).Position
		Vfx.Emit.burst(peak, {
			{
				{
					tex = "VfxFeather",
					color = FEATHERS,
					light = 0,
					lit = 0.6,
					size = { { 0, 0.45 }, { 1, 0.38 } },
					alpha = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
					life = { 1.2, 2 },
					speed = { 2, 5 },
					spread = 180,
					accel = Vector3.new(0, -3, 0),
					drag = 2.5,
					rot = { 0, 360 },
					spin = { -200, 200 },
				},
				14,
			},
			{
				{
					tex = "VfxSmoke",
					grid = 8,
					mode = "OneShot",
					color = Color3.fromRGB(16, 14, 18),
					light = 0,
					lit = 0.3,
					size = { { 0, 1 }, { 1, 2.8 } },
					alpha = { { 0, 0.35 }, { 0.6, 0.55 }, { 1, 1 } },
					life = { 0.7, 1.1 },
					speed = { 1.5, 3.5 },
					drag = 3,
					spread = 180,
					rot = { 0, 360 },
					spin = { -40, 40 },
				},
				5,
			},
		})
	end
end)

-- Chocolate Snap: crumbs of chocolate off each bite.
FX.chocolateSnap = accent(3.2, { 0.75, 1.95 }, function(character)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		pieces(
			(head.CFrame * CFrame.new(0.2, -0.3, -0.7)).Position,
			Color3.fromRGB(96, 58, 36),
			10,
			0.16,
			6,
			head.CFrame.LookVector
		)
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
			-- (a heartbeat: two red pulses out across the floor, lub and dub, a red glow under him beating with them,
			-- the light throbbing; his own screen kicks with each beat)
			local floor = floorUnder(root.Position, character)
			local calm = Motion.isReduced()
			local own = mine(character)
			for k, beat in ipairs({ 0, 0.28 }) do
				Vfx.Clock.after(beat, function()
					local strength = if k == 1 then 1 else 0.7
					Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.08, 0)), 0.8, 14 * strength, 0.9, {
						tex = "VfxRingBand",
						color = Color3.fromRGB(230, 50, 64),
						width = 1.6 * strength,
						light = 0.6,
						bright = 1.2,
					})
					Vfx.Emit.burst(CFrame.new(floor + Vector3.new(0, 0.06, 0)), {
						tex = "VfxGlow",
						color = CRIMSON,
						size = { { 0, 3 }, { 0.2, 8 * strength }, { 1, 9 * strength } },
						alpha = { { 0, 0.2 }, { 1, 1 } },
						life = 0.6,
						speed = 0.001,
						face = "flat",
						light = 0.7,
						bright = 0.9,
					}, 1)
					Vfx.Light.flash(floor + Vector3.new(0, 2, 0), CRIMSON, 16, 3 * strength, 0.4)
					if own and not calm then
						Vfx.Screen.punch(2.5 * strength, 0.2)
					end
				end)
			end
		end
	)
	return function()
		gone = true
	end
end

return FX
