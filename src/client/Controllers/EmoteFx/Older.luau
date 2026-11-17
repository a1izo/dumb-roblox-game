-- The first effects, written before the accent passes: Diavolo's chip and pen, Apple Bite, the puppets, Write
-- in the Air, Ace's crouch and L's chair. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Cinema = require(script.Parent.Parent.Parent.Presentation.Cinema)
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)

local Common = require(script.Parent.Shared)
local EmoteFx = Common.EmoteFx
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local after = Common.after

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

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
	-- the crunch: a gold star at the lips, the crisp burst into tumbling crumbs, a glitter of salt hanging in the
	-- flare's light (the crumbs thrown forward and up out of the mouth)
	local function crunch()
		local out = head.CFrame * CFrame.new(0, -0.25, -0.6) * CFrame.Angles(math.rad(-65), 0, 0)
		local list: { any } = {
			{
				{
					tex = "VfxChunk",
					grid = 2,
					fps = 0,
					startRandom = true,
					color = { { 0, Color3.fromRGB(255, 220, 130) }, { 1, Color3.fromRGB(214, 158, 64) } },
					light = 0.1,
					lit = 0.7,
					size = { { 0, 0.26 }, { 1, 0.18 } },
					life = { 0.6, 1.0 },
					speed = { 5, 10 },
					spread = 55,
					accel = Vector3.new(0, -30, 0),
					rot = { 0, 360 },
					spin = { -400, 400 },
				},
				24,
			},
		}
		if not calm then
			table.insert(list, {
				{
					tex = "VfxFlare",
					color = Color3.fromRGB(255, 236, 190),
					size = { { 0, 0.4 }, { 0.2, 3.4 }, { 1, 0 } },
					life = 0.3,
					rot = { 0, 360 },
					bright = 1.5,
					z = 1,
				},
				1,
			})
			table.insert(list, {
				{
					tex = "VfxBurst",
					color = Color3.fromRGB(255, 214, 140),
					size = { { 0, 0.5 }, { 0.15, 3.2 }, { 1, 3.6 } },
					alpha = { { 0, 0 }, { 0.5, 0.25 }, { 1, 1 } },
					life = 0.25,
					light = 0.6,
					rot = { 0, 360 },
					bright = 1.1,
				},
				1,
			})
			table.insert(list, {
				{
					tex = "VfxFlare",
					color = Color3.new(1, 1, 1),
					size = { { 0, 0 }, { 0.2, 0.3 }, { 0.4, 0 }, { 0.6, 0.25 }, { 1, 0 } },
					life = { 0.7, 1.2 },
					speed = { 2, 5 },
					spread = 70,
					accel = Vector3.new(0, -4, 0),
					drag = 2,
					rot = { 0, 90 },
					bright = 1.5,
				},
				12,
			})
		end
		Vfx.Emit.burst(out, list)
	end
	local flare = Create("PointLight", {
		Color = Color3.fromRGB(255, 220, 160),
		Range = 10,
		Brightness = 0,
		Shadows = false,
		Parent = mouth,
	}) :: PointLight
	at(7.05, function()
		crunch()
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
	-- (thrown forward and a little up out of the mouth: drops of juice drawn out as they fly, flecks of the white
	-- flesh and a few of the red skin tumbling, a fine mist of juice catching the light)
	after(
		head,
		function()
			return gone
		end,
		0.93,
		function()
			local out = head.CFrame * CFrame.new(0, -0.3, -0.75) * CFrame.Angles(math.rad(-75), 0, 0)
			Vfx.Emit.burst(out, {
				{
					{
						tex = "VfxStreak",
						color = Color3.fromRGB(255, 246, 214),
						size = { { 0, 0.12 }, { 1, 0.05 } },
						squash = -1.4,
						alpha = { { 0, 0.1 }, { 1, 0.6 } },
						life = { 0.35, 0.6 },
						speed = { 5, 9 },
						spread = { 45, 30 },
						accel = Vector3.new(0, -30, 0),
						face = "along",
						light = 0.3,
						lit = 0.5,
						bright = 1.2,
					},
					16,
				},
				{
					{
						tex = "VfxChunk",
						grid = 2,
						fps = 0,
						startRandom = true,
						color = Color3.fromRGB(250, 240, 214),
						light = 0,
						lit = 0.8,
						size = { { 0, 0.16 }, { 1, 0.12 } },
						life = { 0.5, 0.8 },
						speed = { 4, 7 },
						spread = { 45, 30 },
						accel = Vector3.new(0, -30, 0),
						rot = { 0, 360 },
						spin = { -400, 400 },
					},
					8,
				},
				{
					{
						tex = "VfxChunk",
						grid = 2,
						fps = 0,
						startRandom = true,
						color = Color3.fromRGB(170, 24, 32),
						light = 0,
						lit = 0.8,
						size = { { 0, 0.12 }, { 1, 0.09 } },
						life = { 0.5, 0.8 },
						speed = { 4, 7 },
						spread = { 45, 30 },
						accel = Vector3.new(0, -30, 0),
						rot = { 0, 360 },
						spin = { -400, 400 },
					},
					4,
				},
				{
					{
						tex = "VfxGlow",
						color = Color3.fromRGB(255, 248, 230),
						size = { { 0, 0.3 }, { 1, 1.2 } },
						alpha = { { 0, 0.55 }, { 1, 1 } },
						life = 0.35,
						speed = { 1, 2 },
						spread = 30,
						light = 0.5,
						bright = 0.8,
					},
					3,
				},
			})
		end
	)
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
	local glow = Vfx.Tex.id("VfxGlow")
	local line = Create("ParticleEmitter", {
		Name = "Writing",
		Texture = glow,
		Color = ColorSequence.new(pale),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0.14) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.65, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Brightness = 1.6,
		Lifetime = NumberRange.new(2.4),
		Speed = NumberRange.new(0),
		Rate = 110,
		Enabled = false,
		Parent = tip,
	}) :: ParticleEmitter
	local spatter = Create("ParticleEmitter", {
		Name = "FullStop",
		Texture = Vfx.Tex.id("VfxEmber"),
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
	-- the sparkler's sparks spitting off the tip while it writes
	local sparks = Vfx.Emit.make(tip, {
		name = "WritingSparks",
		tex = "VfxStreak",
		color = { { 0, Color3.new(1, 1, 1) }, { 0.5, pale }, { 1, Color3.fromRGB(255, 180, 110) } },
		size = { { 0, 0.16 }, { 1, 0.04 } },
		squash = -1.6,
		life = { 0.18, 0.4 },
		speed = { 3, 7 },
		spread = 180,
		accel = Vector3.new(0, -14, 0),
		drag = 2,
		face = "along",
		bright = 1.5,
	})
	sparks.Enabled = false
	after(arm, over, 0.4, function()
		line.Enabled = true
		if not calm then
			sparks.Rate = 40
			sparks.Enabled = true
		end
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 1.4 }):Play()
	end)
	after(arm, over, 1.95, function()
		line.Enabled = false
		sparks.Enabled = false
	end)
	after(arm, over, 2.3, function()
		line:Emit(4)
		if calm then
			return
		end
		spatter:Emit(14)
		Vfx.Recipes.twinkle(tip.WorldPosition, { color = pale, scale = 1.3 })
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
	-- the lamp's shaft of light down through the dusty air
	local _, endShaft = Vfx.Beams.line(root.Position + Vector3.new(0, 14, 0), root.Position - Vector3.new(0, 3, 0), {
		tex = "VfxColumn",
		color = Color3.fromRGB(196, 212, 232),
		width = 6.5,
		width1 = 9,
		bright = 0.22,
		light = 1,
		speed = -0.6,
		repeats = 9,
	})
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
		Texture = Vfx.Tex.id("VfxEmber"),
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
		endShaft(0.5)
		box:Destroy()
	end
end

-- Chair Perch: L's interview room, the same cold lamp and drifting dust as his crouch.
FX.chairPerch = function(character, preview, phase)
	return FX.aceCrouch(character, preview, phase)
end

-- Bye Bye Bye (Puppet Pop): the band dance it as marionettes; the same strings as Puppet Dance.
FX.puppetPop = function(character, preview, phase)
	return FX.puppetDance(character, preview, phase)
end

return FX
