-- The first effects, written before the accent passes: Diavolo's chip and pen, Apple Bite, the puppets, Write
-- in the Air, Ace's crouch and L's chair. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Cinema = require(script.Parent.Parent.Parent.Presentation.Cinema)
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)
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
-- On the new kit (stage 4b third batch, Pilot.on.chipAndPen; false = the old build). One sentence: a villain's crisp bitten in the
-- dark, a gold star on the lips and crumbs thrown, then the desk sinking in a roll of dust (motif: crumbs, salt, dust). The five moments:
--   gather    6.85 to 7.05 s  specks of gold drawn in to the lips
--   hit       7.05 s          the bite: a gold star (Fresh.tap, light on the face), crumbs thrown forward and up
--   body      7.05 to 7.6 s   the crumbs tumble and fall
--   break-up  8.95 s          the desk goes down in a roll of dust along the floor (Fresh.dustKick)
--   residue   7.1 to 9 s, 9.5 s  grains of salt hanging in the light; a thin puff of dust where the desk stood
local CHIP_GOLD = Palette.pair(Color3.fromRGB(240, 190, 90), Color3.fromRGB(255, 236, 190))
local CHIP_LEAD = 0.2
FX.chipAndPen = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if preview or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local fresh = Pilot.on.chipAndPen
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
		if fresh then
			-- (the star and the light come from the tap that gathered just before; here the crisp breaks into crumbs, and a few
			-- grains of salt hang in the light a second or two: the residue)
			Vfx.Emit.burst(out, {
				{
					{
						tex = "VfxChunk",
						grid = 2,
						fps = 0,
						startRandom = true,
						color = { { 0, Color3.fromRGB(255, 220, 130) }, { 1, Color3.fromRGB(214, 158, 64) } },
						light = 0.1,
						lit = 0.7,
						size = { { 0, 0.1 }, { 0.15, 0.26 }, { 0.8, 0.2 }, { 1, 0 } },
						alpha = { { 0, 0.9 }, { 0.15, 0 }, { 0.8, 0 }, { 1, 1 } },
						life = { 0.6, 1.0 },
						speed = { 5, 10 },
						spread = 55,
						accel = Vector3.new(0, -30, 0),
						rot = { 0, 360 },
						spin = { -400, 400 },
					},
					24,
				},
				{
					{
						tex = "VfxSparks",
						ramp = CHIP_GOLD,
						size = { { 0, 0.34 }, { 1, 0.08 } },
						alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.75, 0.3 }, { 1, 1 } },
						life = { 1.3, 2.0 },
						speed = { 1, 3 },
						spread = 70,
						accel = Vector3.new(0, -2.5, 0),
						drag = 2,
						rot = { 0, 90 },
						bright = 1.5,
					},
					if calm then 4 else 8,
				},
			})
			return
		end
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
	if fresh and not calm then
		-- (the gather: specks drawn in to the lips as a gold star blooms on the bite and the light comes up on the face)
		at(7.05 - CHIP_LEAD, function()
			local lips = head.CFrame * CFrame.new(0, -0.25, -0.6)
			Fresh.tap(
				lips.Position,
				{ ramp = CHIP_GOLD, scale = 0.9, gather = true, lite = true, sparks = 6, lead = CHIP_LEAD }
			)
		end)
	end
	at(7.05, function()
		crunch()
		if not calm and not fresh then
			flare.Brightness = 6
			TweenService:Create(flare, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
		end
	end)
	-- the dust round the desk as it goes down
	local desk = CFrame.new(floor) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -0.4)
	at(8.95 - (if fresh then 0.04 else 0), function()
		if fresh then
			Fresh.dustKick(desk, { ramp = Palette.WORLD.dust, scale = 1.5, lead = 0.04 })
			return
		end
		EmoteFx.thud(desk, 7)
	end)
	at(9.5 - (if fresh then 0.12 else 0), function()
		if fresh then
			Fresh.smokePuff(
				desk.Position + Vector3.new(0, 0.6, 0),
				{ ramp = Palette.WORLD.dust, scale = 0.5, rise = 1.2, lead = 0.12 }
			)
			return
		end
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
-- On the new kit (stage 4b third batch, Pilot.on.writeAir; false = the old build). One sentence: a god writing a name in the air in
-- pale gold light, the line hanging in little stars and the full stop landing as a bright star (motif: written light, a sparkler's
-- sparks; the aura is the emote's own, unchanged). The five moments:
--   gather    2.1 to 2.3 s    specks drawn in to the fingertip before the full stop (the 0.1 s gather before the line is gone: fourth batch)
--   hit       0.4 s           the line starts; 2.3 s the full stop: a white-hot star, sparks thrown and the light up (Fresh.tap)
--   body      0.4 to 1.95 s   the fingertip's chain of stars and its spitting sparks, a warm light on the finger
--   break-up  1.95 to 2.4 s   the stars fade out one by one as they age
--   residue   2.3 to 4 s      the last stars of the line and the full stop's sparks hanging
local WRITE = Palette.pair(Color3.fromRGB(255, 226, 170), Color3.fromRGB(255, 250, 236))
FX.writeAir = function(character, preview)
	local arm = character:FindFirstChild("Right Arm")
	if preview or not arm or not arm:IsA("BasePart") then
		return nothing
	end
	local calm = Motion.isReduced()
	local fresh = Pilot.on.writeAir
	local gone = false
	local function over()
		return gone
	end
	local tip = Create("Attachment", { Name = "EmoteWriting", Position = Vector3.new(0, -1.1, 0), Parent = arm })
	tip:SetAttribute("DGEmote", true)
	local pale = Color3.fromRGB(255, 240, 214)
	local glow = Vfx.Tex.id("VfxGlow")
	local line: ParticleEmitter
	local spatter: ParticleEmitter? = nil
	if fresh then
		-- (the written line: a chain of small four-point stars hanging where the fingertip was, each growing in and fading out)
		line = Vfx.Emit.make(tip, {
			name = "Writing",
			tex = "VfxGlint",
			ramp = WRITE,
			size = { { 0, 0 }, { 0.2, 0.34 }, { 1, 0.1 } },
			alpha = { { 0, 0.3 }, { 0.2, 0 }, { 0.65, 0.2 }, { 1, 1 } },
			life = 2.0,
			speed = 0,
			rot = { 0, 90 },
			rate = 70,
			bright = 1.8,
		})
		line.Enabled = false
	else
		line = Create("ParticleEmitter", {
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
		spatter = Create("ParticleEmitter", {
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
	end
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
	-- (fourth batch: the gather tap at 0.1 s is gone, a second try at the emitter budget: the level-2 aura has the emitters of the
	-- first nine, so the written line, its sparks and the full stop's own star are what is left of the six an accent may have)
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
	-- (the full stop: the new kit's star and sparks come a hair early so the star lands on 2.3 s)
	after(arm, over, 2.3 - (if fresh then 0.2 else 0), function()
		if fresh then
			if not calm then
				-- (the star carries no light of its own now: the finger's own lamp flares with it, as the old build's did)
				Fresh.tap(
					tip.WorldPosition,
					{ ramp = WRITE, scale = 1.0, gather = true, lite = true, sparks = 10, light = false, lead = 0.2 }
				)
				after(arm, over, 0.2, function()
					light.Brightness = 5
					TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
				end)
			end
			after(arm, over, 0.2, function()
				line:Emit(4)
			end)
			return
		end
		line:Emit(4)
		if calm then
			return
		end
		if spatter then
			spatter:Emit(14)
		end
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
-- On the new kit (stage 4b third batch, Pilot.on.aceCrouch and Pilot.on.chairPerch, one flag each, both wear this build; false = the old
-- build). The lamp (Cinema.spotlight) and its shaft are unchanged. One sentence: the interview-room lamp clicks on over a still
-- body, a ring of cold light opens on the floor and dust turns in the shaft over a low cold haze (motif: dust, cold light). The
-- five moments:
--   gather    0.0 to 0.12 s  specks drawn in to the lamp
--   hit       0.12 s         the lamp's white-hot star (Fresh.glint) and a ring of cold light on the floor (Fresh.tap, flat)
--   body      0.12 s on      motes of dust turning in the shaft, a thin haze pooled on the floor with a dark layer under it
--   break-up  the loops end with the emote (gone at once, as the old dust was)
--   residue   the motes hang in the shaft the whole time it is held
local COLD = Palette.pair(Color3.fromRGB(196, 212, 232), Color3.fromRGB(236, 243, 255))
local function interviewRoom(character: Model, preview: boolean, fresh: boolean): () -> ()
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
	if fresh then
		local calm = Motion.isReduced()
		-- (the dust fills a still box of air round him, not one that follows the body; the haze lies on the floor under it)
		local air = Vfx.Emit.point(root.Position, Vector3.new(5, 5, 5))
		local low =
			Vfx.Emit.point(floorUnder(root.Position, character) + Vector3.new(0, 0.3, 0), Vector3.new(5, 0.2, 5))
		local motes = Fresh.Small.loop(air, {
			{
				tex = "VfxAshFlakes",
				ramp = COLD,
				size = { { 0, 0.14 }, { 1, 0.1 } },
				alpha = { { 0, 1 }, { 0.25, 0.25 }, { 0.75, 0.3 }, { 1, 1 } },
				life = { 3, 5 },
				speed = { 0.1, 0.35 },
				spread = 180,
				accel = Vector3.new(0, -0.05, 0),
				rot = { 0, 360 },
				spin = { -20, 20 },
				shape = Enum.ParticleEmitterShape.Box,
				light = 0.4,
				lit = 0.5,
				bright = 1.2,
				rate = if calm then 2 else 5,
			},
		})
		local haze = Fresh.Small.loop(low, {
			{
				tex = "VfxMist",
				ramp = COLD,
				size = { { 0, 3.5 }, { 1, 5.5 } },
				alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.7, 0.3 }, { 1, 1 } },
				life = { 3, 4.5 },
				speed = { 0.1, 0.3 },
				accel = Vector3.new(0, 0.2, 0),
				rot = { 0, 360 },
				shape = Enum.ParticleEmitterShape.Box,
				light = 0.3,
				lit = 0.5,
				rate = if calm then 0.5 else 0.8,
			},
			{
				-- (the dark layer under the haze: laid over, never added)
				tex = "VfxMist",
				ramp = Fresh.Small.shadow(COLD),
				size = { { 0, 3 }, { 1, 5 } },
				alpha = { { 0, 1 }, { 0.25, 0.65 }, { 0.8, 0.75 }, { 1, 1 } },
				life = { 3, 4.5 },
				speed = { 0.1, 0.3 },
				shape = Enum.ParticleEmitterShape.Box,
				light = 0,
				lit = 0.2,
				z = -1,
				rate = if calm then 0.3 else 0.5,
			},
		})
		local stopIgnition = nothing
		if not calm then
			-- (the lamp: the one that Cinema.spotlight just made, nearest to him; the star lands as the shaft fills)
			local lamp = root.Position + Vector3.new(0, 10, 0)
			local best = math.huge
			for _, rig in ipairs(workspace.CurrentCamera:GetChildren()) do
				if rig.Name == "CinemaSpotlight" and rig:IsA("BasePart") then
					local d = (rig.Position - root.Position).Magnitude
					if d < best then
						best = d
						lamp = rig.Position
					end
				end
			end
			local floorAt = floorUnder(root.Position, character) + Vector3.new(0, 0.08, 0)
			local a = Fresh.glint(lamp, { ramp = COLD, scale = 1.6, lead = 0.12 })
			local b = Fresh.tap(
				CFrame.new(floorAt),
				{ ramp = COLD, scale = 1.5, flat = true, sparks = 3, light = false, lead = 0.12 }
			)
			stopIgnition = function()
				a()
				b()
			end
		end
		return function()
			stopIgnition()
			removeLight()
			endShaft(0.5)
			-- (gone at once with its owner, as the old dust was)
			motes.destroy()
			haze.destroy()
			air:Destroy()
			low:Destroy()
		end
	end
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

FX.aceCrouch = function(character, preview)
	return interviewRoom(character, preview, Pilot.on.aceCrouch)
end

-- Chair Perch: L's interview room, the same cold lamp and drifting dust as his crouch.
FX.chairPerch = function(character, preview)
	return interviewRoom(character, preview, Pilot.on.chairPerch)
end

-- Bye Bye Bye (Puppet Pop): the band dance it as marionettes; the same strings as Puppet Dance.
FX.puppetPop = function(character, preview, phase)
	return FX.puppetDance(character, preview, phase)
end

-- The fourth batch, on the new kit (stage 4b): Apple Bite and the puppets below keep their idea, colour and beat, each behind its
-- own flag in Vfx/Pilot (false = the old build above, which stays as it was). Penned is an accent: 60 particles, 2 big sprites,
-- 6 emitters, 1 light.
local flag = Common.flag
local throwing = Common.throwing

-- Apple Bite: the crunch (0.93 s) sprays juice and flecks of the apple's white flesh out of the mouth, falling, with a few chips
-- of the red skin. The five moments: gather none (a bite), hit 0.93 s a small cream-white star at the lips with its sparks of
-- juice (Fresh.tap), body red skin chips thrown out along the face and falling (Fresh.flecks, shards), break-up they thin out,
-- residue none (a bite).
local FLESH_RAMP = Palette.pair(Color3.fromRGB(250, 240, 214), Color3.fromRGB(255, 252, 242))
local SKIN_RAMP = Palette.pair(Color3.fromRGB(170, 24, 32), Color3.fromRGB(255, 170, 170))
local function appleBiteFresh(character: Model, preview: boolean): () -> ()
	local head = character:FindFirstChild("Head")
	if preview or not head or not head:IsA("BasePart") then
		return nothing
	end
	local gone = false
	local lead = 0.1
	after(
		head,
		function()
			return gone
		end,
		0.93 - lead,
		function()
			local mouth = (head.CFrame * CFrame.new(0, -0.3, -0.75)).Position
			local way = head.CFrame:VectorToWorldSpace(Vector3.new(0, 0.5, -1)).Unit
			Fresh.tap(mouth, { ramp = FLESH_RAMP, scale = 0.45, lite = true, sparks = 9, light = false, lead = lead })
			Fresh.flecks(throwing(mouth, way), {
				tex = "VfxShards",
				ramp = SKIN_RAMP,
				scale = 0.4,
				count = 5,
				fall = 26,
				lead = lead,
			})
		end
	)
	return function()
		gone = true
	end
end
FX.appleBite = flag("appleBite", appleBiteFresh, FX.appleBite)

-- Puppet Dance and Bye Bye Bye: the marionette's strings (the old build's beams, unchanged) and now the dust they shake loose,
-- pale specks of it coming down off the strings above the dancer (one loop emitter on a holder that follows the root). Puppet Pop
-- calls Puppet Dance, so one flag covers both.
local STRING_RAMP = Palette.pair(Color3.fromRGB(226, 220, 204), Color3.fromRGB(255, 252, 240))
local puppetOld: Common.Fx = FX.puppetDance
local function puppetFresh(character: Model, preview: boolean, phase: number?): () -> ()
	local stopOld = puppetOld(character, preview, phase)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") or Motion.isReduced() then
		return stopOld
	end
	local holder = Vfx.Emit.point(root.Position + Vector3.new(0, 5, 0), Vector3.new(3.4, 0.2, 1.4))
	local loop = Fresh.Small.loop(holder, {
		{
			tex = "VfxSparks",
			ramp = STRING_RAMP,
			size = { { 0, 0.26 }, { 1, 0.08 } },
			alpha = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.4 }, { 1, 1 } },
			life = { 1.8, 2.6 },
			speed = { 0.1, 0.5 },
			accel = Vector3.new(0, -0.6, 0),
			spread = 180,
			rot = { 0, 360 },
			rate = 5,
			shape = Enum.ParticleEmitterShape.Box,
			bright = 2.2,
		},
	})
	local follow = Vfx.Clock.every(function()
		if not root.Parent then
			return false
		end
		holder.CFrame = CFrame.new(root.Position + Vector3.new(0, 5, 0))
		return true
	end)
	return function()
		stopOld()
		follow()
		loop.stop()
		task.delay(2.6, function()
			loop.destroy()
			holder:Destroy()
		end)
	end
end
FX.puppetDance = flag("puppetDance", puppetFresh, puppetOld)

return FX
