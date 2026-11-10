-- Walrider (art/refs/deaths/walrider.md, 19.5 s): FIRST PERSON, the camera is the victim's eyes; only their own bloody
-- hands are seen of them. Face down on a pale concrete floor pushing up; up on their feet before a steel double door
-- behind a hazard stripe; the doors part on soldiers in black and an old man in a wheelchair in a white tiled room;
-- a staggering walk at them, hands swinging into view; the shot (a warm flash), hit in slow motion, the red closing
-- in; down on the floor, tilted, a grey swarm boiling up at the left; on the back, the soldiers firing again and
-- again; dark; blood over the lens, a soldier standing over, white glare; black.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)

local CONCRETE = Color3.fromRGB(150, 164, 172)
local STEEL = Color3.fromRGB(70, 80, 88)
local BLOOD = Color3.fromRGB(110, 8, 10)
local BLACK = Color3.fromRGB(20, 20, 22)

local VOLLEY = { 15.55, 15.8, 15.95, 16.15, 16.3, 16.5, 16.62, 16.8, 16.95, 17.1 }

local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * math.clamp(u, 0, 1)
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The set of parts (before it was modelled): only when the Scenes import is missing.
local function standIn(ctx)
	-- the lab: a pale concrete floor with yellow lines, the hazard stripe, the steel double door, the tiled room beyond
	ctx:part({
		size = Vector3.new(20, 1, 26),
		at = Vector3.new(0, -0.5, 5),
		color = CONCRETE,
		material = Enum.Material.Concrete,
	})
	ctx:part({ size = Vector3.new(20, 1, 26), at = Vector3.new(0, 13.5, 5), color = Color3.fromRGB(60, 66, 70) })
	for _, x in ipairs({ -10.5, 10.5 }) do
		ctx:part({
			size = Vector3.new(1, 14, 26),
			at = Vector3.new(x, 6.5, 5),
			color = Color3.fromRGB(96, 106, 112),
			material = Enum.Material.Concrete,
		})
	end
	ctx:part({ size = Vector3.new(20, 14, 1), at = Vector3.new(0, 6.5, 18.5), color = Color3.fromRGB(80, 88, 94) })
	-- the wall with the door (at z = -2), the door frame
	for _, x in ipairs({ -6.75, 6.75 }) do
		ctx:part({
			size = Vector3.new(6.5, 14, 1.2),
			at = Vector3.new(x, 6.5, -2),
			color = Color3.fromRGB(88, 98, 104),
			material = Enum.Material.Concrete,
		})
	end
	ctx:part({
		size = Vector3.new(7, 5, 1.2),
		at = Vector3.new(0, 11.5, -2),
		color = Color3.fromRGB(88, 98, 104),
		material = Enum.Material.Concrete,
	})
	-- yellow floor lines and the black-and-yellow hazard stripe before the door
	for _, x in ipairs({ -4.5, 4.5 }) do
		ctx:part({
			size = Vector3.new(0.25, 0.04, 20),
			at = Vector3.new(x, 0.02, 8),
			color = Color3.fromRGB(230, 190, 40),
		})
	end
	for k = 0, 13 do
		ctx:part({
			size = Vector3.new(0.5, 0.05, 1.1),
			at = Vector3.new(-3.25 + k * 0.5, 0.03, -0.9),
			color = if k % 2 == 0 then Color3.fromRGB(240, 196, 30) else BLACK,
			rot = Vector3.new(0, 30, 0),
		})
	end
	-- water drops on the floor where they lie
	for k = 1, 8 do
		ctx:part({
			size = Vector3.new(0.18, 0.02, 0.4),
			at = Vector3.new(-0.6 + (k % 4) * 0.35, 0.02, 7.2 - k * 0.3),
			color = Color3.fromRGB(200, 214, 224),
			material = Enum.Material.Glass,
			alpha = 0.3,
		})
	end
	-- the white tiled room beyond, blood on its floor
	ctx:part({
		size = Vector3.new(16, 1, 16),
		at = Vector3.new(0, -0.5, -10.6),
		color = Color3.fromRGB(226, 228, 230),
		material = Enum.Material.CeramicTiles,
	})
	ctx:part({
		size = Vector3.new(16, 12, 1),
		at = Vector3.new(0, 6, -18.6),
		color = Color3.fromRGB(220, 224, 226),
		material = Enum.Material.CeramicTiles,
	})
	for _, x in ipairs({ -8.5, 8.5 }) do
		ctx:part({
			size = Vector3.new(1, 12, 16),
			at = Vector3.new(x, 6, -10.6),
			color = Color3.fromRGB(220, 224, 226),
			material = Enum.Material.CeramicTiles,
		})
	end
	for k = 1, 7 do
		ctx:part({
			size = Vector3.new(1.2 + (k % 3) * 0.8, 0.03, 0.8 + (k % 2)),
			at = Vector3.new(-3 + k, 0.02, -5 - (k % 4) * 1.5),
			color = BLOOD,
			rot = Vector3.new(0, k * 37, 0),
		})
	end
	ctx:light(Vector3.new(0, 11, -10), Color3.fromRGB(235, 240, 255), 26, 2.2, true)
	ctx:light(Vector3.new(0, 12, 6), Color3.fromRGB(170, 190, 210), 26, 0.9)
	ctx:part({
		size = Vector3.new(4, 0.2, 0.6),
		at = Vector3.new(0, 12.9, -10),
		color = Color3.fromRGB(240, 246, 255),
		glow = true,
	})
end

local function build(ctx)
	-- (the lab, modelled: art/scripts/maps/venues/scenes/walrider.py; its lamps and tubes light it)
	if not ctx:set() then
		standIn(ctx)
	end
	-- the steel double door's leaves (on their track in front of the modelled frame)
	local doorZ = if ctx.built then -1.55 else -2
	local doorL = ctx:part({
		size = Vector3.new(3.5, 9, 0.5),
		at = Vector3.new(-1.75, 4.5, doorZ),
		color = STEEL,
		material = Enum.Material.Metal,
	})
	local doorR = ctx:part({
		size = Vector3.new(3.5, 9, 0.5),
		at = Vector3.new(1.75, 4.5, doorZ),
		color = STEEL,
		material = Enum.Material.Metal,
	})
	-- the men in the doorway: soldiers in black (helmets, rifles), the old man in a wheelchair among them
	local soldiers = {}
	local marks =
		{ Vector3.new(-3.2, 0, -7.5), Vector3.new(-1.4, 0, -9.6), Vector3.new(2.6, 0, -6.6), Vector3.new(3.6, 0, -9.0) }
	for i, at in ipairs(marks) do
		-- (each its own clip: its own idle, its own raise, its own shots: soldier 3 fires the first)
		-- (in their marketplace tactical gear and helmets, Cast; the carbine modelled, props_scenes)
		local s = ctx:actor("cast:soldier", CFrame.lookAt(at, Vector3.new(0, 0, 6)), "sceneWalriderSoldier" .. i)
		if s then
			local rifle = ctx:wear(s, "rifle")
			table.insert(soldiers, { model = s, rifle = rifle, i = i })
		end
	end
	-- the old man's wheelchair (modelled; its pivot at its lowest point, the wheels on the floor), facing the victim;
	-- the parts are its stand-in before the import
	local chair = ctx:place("wheelchair", CFrame.new(0.4, 0, -10.2) * CFrame.Angles(0, math.pi, 0))
	local seatY = if chair then 1.07 else 1.2 -- (the model's seat is 0.13 lower than the stand-in's)
	ctx:actor(
		"cast:doctor",
		CFrame.lookAt(Vector3.new(0.4, seatY, -10.2), Vector3.new(0.4, seatY, 6)),
		"sceneWalriderSeated"
	)
	for _, w in
		ipairs(if chair
			then {}
			else {
				{ size = Vector3.new(2.2, 0.3, 2.0), at = Vector3.new(0.4, 2.0, -10.2) },
				{ size = Vector3.new(2.2, 2.4, 0.3), at = Vector3.new(0.4, 3.3, -11.2) },
			})
	do
		ctx:part({ size = w.size, at = w.at, color = Color3.fromRGB(40, 44, 48), material = Enum.Material.Metal })
	end
	for _, x in ipairs(if chair then {} else { -0.85, 1.65 }) do
		ctx:part({
			size = Vector3.new(0.25, 2.6, 2.6),
			at = Vector3.new(x, 1.3, -10.2),
			color = Color3.fromRGB(30, 30, 32),
			shape = "Cylinder",
			material = Enum.Material.Metal,
		})
	end

	-- the victim's own hands: sleeves in their suit's colour, bare bloody hands
	local skin = Color3.fromRGB(214, 180, 150)
	local sleeve = Color3.fromRGB(40, 40, 46)
	if ctx.victim then
		local who = game:GetService("Players"):GetPlayerByUserId(ctx.victim)
		local character = who and who.Character
		local head = character and character:FindFirstChild("Head")
		local arm = character and character:FindFirstChild("Right Arm")
		if head and head:IsA("BasePart") then
			skin = head.Color
		end
		if arm and arm:IsA("BasePart") then
			sleeve = arm.Color
		end
	end
	local hands = {}
	for _, side in ipairs({ -1, 1 }) do
		local arm = ctx:part({ size = Vector3.new(0.75, 0.75, 2.6), color = sleeve, cast = false })
		local hand = ctx:part({ size = Vector3.new(0.7, 0.45, 0.85), color = skin, cast = false })
		local fingers = ctx:part({ size = Vector3.new(0.7, 0.2, 0.55), color = skin, cast = false })
		local gore = ctx:part({ size = Vector3.new(0.72, 0.47, 0.6), color = BLOOD, alpha = 0.25, cast = false })
		hands[side] = { arm = arm, hand = hand, fingers = fingers, gore = gore }
	end
	local function place(side: number, cam: CFrame, offset: Vector3, pitch: number, spread: number)
		local h = hands[side]
		local base = cam
			* CFrame.new(offset.X * side, offset.Y, offset.Z)
			* CFrame.Angles(math.rad(pitch), math.rad(-side * spread), 0)
		h.arm.CFrame = base * CFrame.new(0, 0, 1.3)
		h.hand.CFrame = base * CFrame.new(0, 0, -0.35)
		h.fingers.CFrame = base * CFrame.new(0, 0, -0.95) * CFrame.Angles(math.rad(10), 0, 0)
		h.gore.CFrame = base * CFrame.new(0, 0.01, -0.5)
	end
	local function hide(side: number)
		local h = hands[side]
		for _, p in pairs(h) do
			p.CFrame = CFrame.new(0, -5000, 0)
		end
	end

	-- the eyes: keyed by the sheet
	local function eyes(t: number): (CFrame, number)
		local pos, pitch, yaw, roll, fov = Vector3.new(0, 0.7, 7.5), -70, 0, 0, 70
		if t < 2.25 then
			pos = Vector3.new(0, 0.75 + 0.15 * math.sin(t * 3), 7.5)
			pitch = -72 + 6 * math.sin(t * 2.2)
		elseif t < 3.0 then
			local u = smooth((t - 2.25) / 0.75)
			pos = Vector3.new(0, lerp(0.8, 4.8, u), lerp(7.5, 7.0, u))
			pitch = lerp(-60, -4, u)
		elseif t < 7.25 then
			local u = (t - 3.0) / 4.25
			local step = math.sin(t * 5.2)
			pos = Vector3.new(0.25 * step, 4.8 + 0.12 * math.abs(step), lerp(7.0, 3.2, u))
			pitch, roll = -4, 3 * step
		elseif t < 8.5 then
			local u = smooth((t - 7.25) / 1.25) -- (slow: the hit in slow motion)
			pos = Vector3.new(lerp(0, 0.5, u), lerp(4.8, 4.3, u), lerp(3.2, 3.7, u))
			pitch, yaw, roll = lerp(-4, 12, u), lerp(0, 10, u), lerp(0, 30, u)
		elseif t < 9.4 then
			local u = smooth((t - 8.5) / 0.9)
			pos = Vector3.new(lerp(0.5, 0.9, u), lerp(4.3, 0.8, u), lerp(3.7, 4.2, u))
			pitch, yaw, roll = lerp(12, 4, u), lerp(10, -8, u), lerp(30, 28, u)
		elseif t < 15.4 then
			local u = smooth((t - 9.4) / 6)
			pos = Vector3.new(0.9, 0.8, 4.2)
			pitch, yaw, roll = lerp(4, 2, u), -8, lerp(28, 18, u)
		elseif t < 17.4 then
			pos = Vector3.new(0.6, 0.9, 4.6)
			pitch, yaw, roll = 14, -4, 6
		elseif t < 17.7 then
			pos = Vector3.new(0.6, 0.9, 4.6)
			pitch = 70
		else
			pos = Vector3.new(0.6, 0.9, 4.6)
			pitch, yaw, roll = 62, 0, -4
		end
		-- (every shot of the volley jolts the view for a moment)
		for _, v in ipairs(VOLLEY) do
			if t >= v and t < v + 0.12 then
				local k = 1 - (t - v) / 0.12
				pitch += 3.5 * k
				yaw += (if math.floor(v * 10) % 2 == 0 then 2.5 else -2.5) * k
				break
			end
		end
		local look = CFrame.new(pos)
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
		return look, fov
	end
	ctx:camera(0, 19.5, eyes)
	-- the hands, in the eyes' frame
	ctx:during(0, 19.5, function(t)
		local cam = workspace.CurrentCamera.CFrame
		if t < 2.25 then
			local push = math.sin(t * 2.6)
			place(-1, cam, Vector3.new(0.95, -0.9, -2.0 - 0.15 * push), 20, 12)
			place(1, cam, Vector3.new(0.95, -0.95, -2.1 + 0.15 * push), 22, 12)
		elseif t < 3.5 then
			hide(-1)
			place(1, cam, Vector3.new(1.1, -1.1 - (t - 2.25) * 0.4, -1.8), 30, 8)
		elseif t < 7.25 then
			local swing = math.sin(t * 2.6)
			if swing > 0 then
				place(1, cam, Vector3.new(1.0, -0.8 + 0.3 * swing, -2.0), 10 + 20 * swing, 10)
				hide(-1)
			else
				place(-1, cam, Vector3.new(1.0, -0.8 - 0.3 * swing, -2.0), 10 - 20 * swing, 10)
				hide(1)
			end
		elseif t < 8.5 then
			place(1, cam, Vector3.new(0.9, -0.2 + (t - 7.25) * 0.4, -2.2), 40, 4)
			hide(-1)
		elseif t < 12.5 then
			place(-1, cam, Vector3.new(1.4, -1.0, -2.0), 5, 30)
			place(1, cam, Vector3.new(1.0, -1.1, -2.2), 0, 18)
		elseif t >= 15.4 and t < 17.4 then
			place(1, cam, Vector3.new(0.7, -0.5 + 0.15 * math.sin(t * 9), -2.4), 30, 6)
			hide(-1)
		else
			hide(-1)
			hide(1)
		end
	end)
	-- the doors part
	ctx:at(3.0, function()
		ctx:tween(doorL, 0.6, { CFrame = doorL.CFrame * CFrame.new(-3.4, 0, 0) })
		ctx:tween(doorR, 0.6, { CFrame = doorR.CFrame * CFrame.new(3.4, 0, 0) })
	end)
	-- a muzzle flash at a soldier's rifle (and its light on the room)
	local function fire(s, strength: number)
		local rifle = s.rifle
		if not rifle then
			return
		end
		local tip = ctx:pointOf(rifle, "rifle", "muzzle")
		Vfx.Emit.burst(tip, {
			tex = "VfxFlare",
			color = Color3.fromRGB(255, 236, 190),
			size = { { 0, 0.4 }, { 0.25, 2.6 * strength }, { 1, 0 } },
			life = 0.09,
			rot = { 0, 360 },
			bright = 2.5,
			z = 2,
		}, 1)
		Vfx.Light.flash(tip, Color3.fromRGB(255, 220, 160), 30 * strength, 5 * strength, 0.1)
		Vfx.Emit.burst(tip, {
			tex = "VfxChunk",
			grid = 2,
			fps = 0,
			startRandom = true,
			color = Color3.fromRGB(20, 18, 18),
			size = { { 0, 0.08 }, { 1, 0.05 } },
			life = { 0.4, 0.8 },
			speed = { 10, 18 },
			spread = 25,
			dir = Enum.NormalId.Front,
		}, 4)
	end
	ctx:at(7.28, function()
		if soldiers[3] then
			fire(soldiers[3], 1.6)
		end
		Cinema.flash(Color3.fromRGB(255, 236, 200), 0.75, 0.25)
	end)
	-- the red closing in from the edges, from the hit on
	local vignette: Frame? = nil
	ctx:at(7.7, function()
		local layer = ctx:layer(2)
		local v = Instance.new("Frame")
		v.BackgroundColor3 = Color3.fromRGB(110, 10, 8)
		v.BorderSizePixel = 0
		v.Size = UDim2.fromScale(1, 1)
		v.BackgroundTransparency = 0
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.25, 0.75),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.75, 0.75),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		g.Parent = v
		v.Parent = layer
		local v2 = v:Clone()
		v2.UIGradient.Rotation = 90
		v2.Parent = layer
		vignette = layer
	end)
	-- the swarm boiling up at the left of the view (grey static, laced with white streaks)
	ctx:at(8.6, function()
		local at = Vector3.new(-1.4, 1.4, 1.6)
		local swarm = SceneDeaths.emit(ctx, at, Vector3.new(3, 4, 3), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = { { 0, Color3.fromRGB(200, 200, 206) }, { 1, Color3.fromRGB(70, 70, 76) } },
			size = { { 0, 2 }, { 1, 5 } },
			alpha = { { 0, 0.3 }, { 0.6, 0.5 }, { 1, 1 } },
			life = { 0.8, 1.4 },
			speed = { 1, 3 },
			spread = 180,
			rot = { 0, 360 },
			spin = { -120, 120 },
			light = 0.1,
			lit = 0.6,
			rate = 40,
		})
		swarm:Emit(20)
		ctx:during(8.6, 15.4, function(t)
			if math.floor(t * 7) % 2 == 0 and math.random() < 0.3 then
				local from =
					ctx:world(at + Vector3.new(math.random() * 2 - 1, math.random() * 3, math.random() * 2 - 1))
				Vfx.Beams.bolt(
					from,
					from + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1),
					0.15,
					{
						color = Color3.new(1, 1, 1),
						width = 0.08,
						bright = 2,
						pieces = 5,
					}
				)
			end
		end)
		ctx:at(15.4, function()
			swarm.Enabled = false
		end)
	end)
	-- 15.5-17.25 the soldiers firing again and again; every shot jolts the view
	for i, t in ipairs(VOLLEY) do
		ctx:at(t, function()
			local s = soldiers[(i % #soldiers) + 1]
			if s then
				fire(s, 1)
			end
		end)
	end
	-- 17.5 dark; 17.75 blood over the lens, a white glare, a soldier standing over
	local dark: Frame? = nil
	ctx:at(17.45, function()
		local layer = ctx:layer(4)
		local d = Instance.new("Frame")
		d.BackgroundColor3 = Color3.new(0, 0, 0)
		d.BorderSizePixel = 0
		d.Size = UDim2.fromScale(1, 1)
		d.Parent = layer
		dark = layer
		if soldiers[1] then
			soldiers[1].model:PivotTo(
				ctx.origin
					* CFrame.lookAt(Vector3.new(0.6, 0.2, 3.2), Vector3.new(0.6, 0.2, 6))
					* CFrame.new(0, 3, 0)
					* CFrame.Angles(math.rad(-28), 0, 0)
			)
		end
	end)
	ctx:at(17.75, function()
		if dark then
			dark:Destroy()
		end
		local layer = ctx:layer(4)
		local glare = Instance.new("Frame")
		glare.BackgroundColor3 = Color3.fromRGB(235, 236, 240)
		glare.BorderSizePixel = 0
		glare.Size = UDim2.fromScale(1, 1)
		glare.BackgroundTransparency = 0.45
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = glare
		glare.Parent = layer
		local rng = Random.new(41)
		for k = 1, 46 do
			local drop = Instance.new("Frame")
			drop.BorderSizePixel = 0
			drop.BackgroundColor3 = if k % 4 == 0 then Color3.fromRGB(190, 20, 18) else Color3.fromRGB(120, 6, 8)
			drop.AnchorPoint = Vector2.new(0.5, 0.5)
			drop.Position = UDim2.fromScale(rng:NextNumber(0.05, 0.75), rng:NextNumber(0.05, 0.85))
			local long = k % 3 == 0
			drop.Size = if long then UDim2.fromScale(rng:NextNumber(0.1, 0.3), 0.012) else UDim2.fromScale(0.02, 0.035)
			drop.Rotation = rng:NextNumber(-40, 40)
			drop.BackgroundTransparency = rng:NextNumber(0.05, 0.35)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = drop
			drop.Parent = layer
		end
		ctx:tween(glare, 1.5, { BackgroundTransparency = 0.9 })
		ctx:atNow(19.2, function()
			local black = Instance.new("Frame")
			black.BackgroundColor3 = Color3.new(0, 0, 0)
			black.BackgroundTransparency = 1
			black.BorderSizePixel = 0
			black.Size = UDim2.fromScale(1, 1)
			black.ZIndex = 5
			black.Parent = layer
			ctx:tween(black, 0.3, { BackgroundTransparency = 0 })
		end)
	end)
	ctx:grade(0, nil, { Saturation = -0.25, Contrast = 0.15, TintColor = Color3.fromRGB(214, 226, 236) }, 0.1)
	ctx:grade(7.7, nil, { Saturation = -0.2, TintColor = Color3.fromRGB(255, 200, 190) }, 0.5)
	local _ = vignette
end

return { length = 19.5, build = build }
