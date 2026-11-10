-- Walrider (art/refs/deaths/walrider.md, 19.5 s), redone 2026-11-10 to the ending watched at 0.5 s a frame (the user:
-- "the camera shots, the hands - they should be the hands of the player who dies, the movement, the vfx, when you die
-- by falling, basically everything"). FIRST PERSON the whole way: the camera is the victim's eyes, and the only thing
-- seen of them is their own arms (the dead player's arm colours in the match suit's sleeves, their skin on the hands,
-- bloodied). Face down on the pale floor pushing up (0-1.5); rising, the yellow line and the hazard stripe swinging
-- through the view (2-3.3); the doors already parting on the lit white room: the soldiers and the old man in the
-- wheelchair, blood on the tiles (3.5); the staggering walk at them, a hand swinging into view each step (4-7); the
-- shot: the room flashes warm, the view jolts (7.3); the left hand flung up across the frame, slow (8); falling over
-- onto the back: the view rolls, the wall and the doorway tilt, a red haze closes in, the grey swarm boils up at the
-- upper left (8.5-11.5); lying at floor level, the doorway at the right, the soldiers coming in (12-15); the view rolls
-- straight up to the ceiling (15.5); the right hand reaching up at the light, the volley (shots jolt the view, debris
-- falling) (16-17.3); dark, a soldier standing over (17.5); blood over the lens under a white glare (18); black.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Suit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Suit"))

local CONCRETE = Color3.fromRGB(150, 164, 172)
local STEEL = Color3.fromRGB(70, 80, 88)
local BLOOD = Color3.fromRGB(110, 8, 10)
local BLACK = Color3.fromRGB(20, 20, 22)

local SHOT = 7.28 -- the first shot (soldier 3's clip fires then)
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

-- One of the victim's own arms for the first-person view: a copy of the player's arm part (their colour), the match
-- suit's sleeve and cuff and their skin on the hand (as every player wears it in a case), blood over the fingers and
-- the back of the hand. A model pivoted every frame: its pivot is the arm's middle, its -Y the hand's way.
local function ownArm(ctx, side: number, character: Model?, skin: Color3): Model
	local name = if side < 0 then "Left Arm" else "Right Arm"
	local source = character and character:FindFirstChild(name)
	local arm: BasePart
	if source and source:IsA("BasePart") then
		arm = source:Clone()
		for _, item in ipairs(arm:GetChildren()) do
			if not item:IsA("SpecialMesh") then
				item:Destroy()
			end
		end
	else
		arm = Instance.new("Part")
		arm.Size = Vector3.new(1, 2, 1)
		arm.Color = Color3.fromRGB(40, 40, 46)
	end
	arm.Name = name
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CanTouch = false
	arm.CastShadow = false
	arm.CFrame = CFrame.new(0, -5000, 0)
	local model = Instance.new("Model")
	model.Name = "OwnArm" .. name
	arm.Parent = model
	for _, list in ipairs({ Suit.cloth(arm), Suit.hand(arm, skin) }) do
		for _, piece in ipairs(list) do
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CastShadow = false
			piece.Parent = model
		end
	end
	-- blood: over the fingers' end, the back of the hand and up the cuff, in patches
	for k, spec in ipairs({
		{ Vector3.new(0.72, 0.22, 0.72), Vector3.new(0, -0.95, 0) },
		{ Vector3.new(0.5, 0.18, 0.74), Vector3.new(0.12, -0.78, 0) },
		{ Vector3.new(0.74, 0.1, 0.46), Vector3.new(0, -0.62, -0.14) },
	}) do
		local gore = Instance.new("Part")
		gore.Name = "Blood" .. k
		gore.Size = spec[1] * arm.Size.X
		gore.Color = BLOOD
		gore.Material = Enum.Material.SmoothPlastic
		gore.Transparency = 0.15
		gore.Anchored = true
		gore.CanCollide = false
		gore.CanQuery = false
		gore.CastShadow = false
		gore.CFrame = arm.CFrame * CFrame.new(spec[2] * (arm.Size.Y / 2))
		gore.Parent = model
	end
	model.PrimaryPart = arm
	model.Parent = ctx.stage.folder
	return model
end

local function build(ctx)
	if not ctx:set() then
		standIn(ctx)
	end
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

	-- the men in the doorway: soldiers in their marketplace tactical gear (Cast), the carbines modelled; the old doctor
	-- in his wheelchair among them. After the shot they come in.
	local soldiers = {}
	local marks =
		{ Vector3.new(-3.2, 0, -7.5), Vector3.new(-1.4, 0, -9.6), Vector3.new(2.6, 0, -6.6), Vector3.new(3.6, 0, -9.0) }
	for i, at in ipairs(marks) do
		local s = ctx:actor("cast:soldier", CFrame.lookAt(at, Vector3.new(0, 0, 6)), "sceneWalriderSoldier" .. i)
		if s then
			local rifle = ctx:wear(s, "rifle")
			table.insert(soldiers, { model = s, rifle = rifle, i = i, from = at })
		end
	end
	local chair = ctx:place("wheelchair", CFrame.new(0.4, 0, -10.2) * CFrame.Angles(0, math.pi, 0))
	local seatY = if chair then 1.07 else 1.2
	ctx:actor(
		"cast:doctor",
		CFrame.lookAt(Vector3.new(0.4, seatY, -10.2), Vector3.new(0.4, seatY, 6)),
		"sceneWalriderSeated"
	)
	if not chair then
		for _, w in ipairs({
			{ size = Vector3.new(2.2, 0.3, 2.0), at = Vector3.new(0.4, 2.0, -10.2) },
			{ size = Vector3.new(2.2, 2.4, 0.3), at = Vector3.new(0.4, 3.3, -11.2) },
		}) do
			ctx:part({ size = w.size, at = w.at, color = Color3.fromRGB(40, 44, 48), material = Enum.Material.Metal })
		end
		for _, x in ipairs({ -0.85, 1.65 }) do
			ctx:part({
				size = Vector3.new(0.25, 2.6, 2.6),
				at = Vector3.new(x, 1.3, -10.2),
				color = Color3.fromRGB(30, 30, 32),
				shape = "Cylinder",
				material = Enum.Material.Metal,
			})
		end
	end
	-- the soldiers walk in after the shot (12-15), a slow advance with a step's bob
	ctx:during(12.0, 15.2, function(t)
		local u = smooth((t - 12.0) / 3.2)
		for _, s in ipairs(soldiers) do
			local from = s.from
			local to = from + Vector3.new(0, 0, 5.5 + (s.i % 2) * 1.2)
			local at = from:Lerp(to, u)
			local bob = math.abs(math.sin(t * 5.5 + s.i)) * 0.12 * (1 - u)
			local pivot = s.model:GetPivot()
			local floor = ctx:world(at + Vector3.new(0, bob, 0))
			s.model:PivotTo(CFrame.new(floor.X, pivot.Position.Y, floor.Z) * pivot.Rotation)
		end
	end)

	-- the victim's own arms (their arm colours, the suit's sleeves, their skin, blood)
	local skin = Color3.fromRGB(214, 180, 150)
	local character: Model? = nil
	if ctx.victim then
		local who = Players:GetPlayerByUserId(ctx.victim)
		character = who and who.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			skin = head.Color
		end
	end
	local arms = { [-1] = ownArm(ctx, -1, character, skin), [1] = ownArm(ctx, 1, character, skin) }
	-- an arm in the eyes' frame: `at` from the lens (x to the right, y up, z back: negative is ahead), its hand
	-- pointing `pitch` degrees down from straight ahead and `spread` degrees out to its side, turned `roll`
	local function place(side: number, cam: CFrame, at: Vector3, pitch: number, spread: number, roll: number?)
		local hand = cam
			* CFrame.new(at.X, at.Y, at.Z)
			* CFrame.Angles(0, math.rad(-side * spread), math.rad(roll or 0))
			* CFrame.Angles(math.rad(-90 + pitch), 0, 0)
		-- (the arm's pivot is its middle; the hand is at its -Y end, one stud down: the pivot sits a stud back up the
		-- arm from where the hand is)
		arms[side]:PivotTo(hand * CFrame.new(0, 1.0, 0))
	end
	local function hide(side: number)
		arms[side]:PivotTo(CFrame.new(0, -5000, 0))
	end

	-- the eyes: keyed to the ending (pos in scene space; pitch down is negative, roll in degrees)
	local function eyes(t: number): (CFrame, number)
		local pos, pitch, yaw, roll, fov = Vector3.new(0, 0.7, 7.5), -70, 0, 0, 72
		if t < 1.6 then
			-- face down over the floor, pushing: the view rocks with each push and rolls a little
			local push = math.sin(t * 2.4)
			pos = Vector3.new(0.1 * push, 0.9 + 0.2 * math.max(0, push), 7.5)
			pitch, yaw, roll = -74 + 8 * push, 4 * push, -6 + 5 * push
		elseif t < 3.3 then
			-- rising: the head comes up and swings, the floor's line and the stripe sweep through, the door rises in
			local u = smooth((t - 1.6) / 1.7)
			local sway = math.sin(u * math.pi) * 18
			pos = Vector3.new(0.2 * math.sin(u * 6), lerp(1.1, 4.7, u), lerp(7.5, 6.9, u))
			pitch, yaw, roll = lerp(-68, -6, u), lerp(6, 0, u) + sway * 0.3, lerp(-6, 0, u) + sway
		elseif t < SHOT then
			-- the staggering walk at the door: heavy steps, the view bobbing and rolling with each
			local u = (t - 3.3) / (SHOT - 3.3)
			local step = math.sin(t * 4.6)
			pos = Vector3.new(0.3 * step, 4.7 + 0.14 * math.abs(step), lerp(6.9, 3.0, u))
			pitch, yaw, roll = -5 + 2 * step, 3 * math.sin(t * 2.3), 4 * step
		elseif t < 8.6 then
			-- hit: the view jolts back and tilts, slowed right down
			local u = smooth((t - SHOT) / 1.3)
			pos = Vector3.new(lerp(0.1, 0.6, u), lerp(4.7, 4.4, u), lerp(3.0, 3.6, u))
			pitch, yaw, roll = lerp(-5, 10, u), lerp(0, 8, u), lerp(2, 38, u)
		elseif t < 11.6 then
			-- the fall onto the back: a drop with a bounce, rolling over until the wall and the doorway top the frame
			local u = (t - 8.6) / 3.0
			local drop = smooth(math.min(1, u * 1.6))
			local bounce = math.exp(-u * 6) * math.sin(u * 22) * 0.3
			pos = Vector3.new(lerp(0.6, 1.0, drop), lerp(4.4, 0.9, drop) + bounce, lerp(3.6, 4.3, drop))
			pitch, yaw, roll = lerp(10, 26, drop), lerp(8, -14, drop), lerp(38, 72, smooth(u))
		elseif t < 15.3 then
			-- lying on the back at floor level: the doorway at the right, the view settling, barely moving
			local u = smooth((t - 11.6) / 3.7)
			pos = Vector3.new(1.0, 0.9, 4.3)
			pitch, yaw, roll = lerp(26, 20, u), lerp(-14, -18, u), lerp(72, 66, u)
		elseif t < 16.0 then
			-- the view rolls over to look straight up at the ceiling arch
			local u = smooth((t - 15.3) / 0.7)
			pos = Vector3.new(1.0, 0.9, 4.3)
			pitch, yaw, roll = lerp(20, 84, u), lerp(-18, 0, u), lerp(66, 0, u)
		elseif t < 17.5 then
			pos = Vector3.new(1.0, 0.9, 4.3)
			pitch, yaw, roll = 82 + 2 * math.sin(t * 3), 0, 2 * math.sin(t * 2)
		else
			pos = Vector3.new(1.0, 0.9, 4.3)
			pitch, yaw, roll = 78, 0, -3
		end
		-- (every shot of the volley jolts the view for a moment)
		for _, v in ipairs(VOLLEY) do
			if t >= v and t < v + 0.14 then
				local k = 1 - (t - v) / 0.14
				pitch += 4 * k
				yaw += (if math.floor(v * 10) % 2 == 0 then 3 else -3) * k
				break
			end
		end
		local look = CFrame.new(pos)
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.Angles(math.rad(pitch), 0, math.rad(roll))
		return look, fov
	end
	ctx:camera(0, 19.5, eyes)

	-- the arms, in the eyes' frame
	ctx:during(0, 19.5, function(t)
		local cam = workspace.CurrentCamera.CFrame
		if t < 1.6 then
			-- both hands flat on the floor ahead, pushing: each comes up a little in turn
			local push = math.sin(t * 2.4)
			place(-1, cam, Vector3.new(-1.05, -0.55 + 0.25 * math.max(0, push), -2.1), 58, 10, -8)
			place(1, cam, Vector3.new(1.05, -0.55 + 0.25 * math.max(0, -push), -2.2), 56, 10, 8)
		elseif t < 3.3 then
			-- rising: the right hand pushes off and drops out of the frame, the left is gone
			local u = (t - 1.6) / 1.7
			hide(-1)
			place(1, cam, Vector3.new(1.0, -0.6 - u * 1.2, -2.0), 40 - 20 * u, 8)
		elseif t < SHOT then
			-- the walk: a hand swings up into the frame with each step, reaching for the door
			local swing = math.sin(t * 4.6)
			if swing > 0 then
				place(1, cam, Vector3.new(1.15, -1.0 + 0.45 * swing, -2.1), 8 + 14 * swing, 12, 6)
				hide(-1)
			else
				place(-1, cam, Vector3.new(-1.15, -1.0 - 0.45 * swing, -2.1), 8 - 14 * swing, 12, -6)
				hide(1)
			end
		elseif t < 8.6 then
			-- the left hand flung up across the frame, close, the fingers spread
			local u = smooth((t - SHOT) / 0.6)
			place(
				-1,
				cam,
				Vector3.new(lerp(-1.2, -0.45, u), lerp(-0.9, 0.3, u), lerp(-2.2, -1.5, u)),
				lerp(10, 55, u),
				20,
				lerp(-6, -24, u)
			)
			hide(1)
		elseif t < 11.6 then
			-- falling: the left hand sinks away below, the right comes up at the edge
			local u = smooth((t - 8.6) / 1.5)
			place(-1, cam, Vector3.new(lerp(-0.45, -1.4, u), lerp(0.3, -1.2, u), -1.8), 40, 24, -20)
			place(1, cam, Vector3.new(1.5, lerp(-1.4, -0.9, u), -2.0), 10, 30, 12)
		elseif t < 15.3 then
			-- lying: the right arm across the low left of the view, still
			place(1, cam, Vector3.new(1.3, -1.1, -2.0), 4, 34, 14)
			hide(-1)
		elseif t < 17.5 then
			-- the right hand reaching up at the light, shaking
			local u = smooth((t - 15.3) / 0.8)
			place(
				1,
				cam,
				Vector3.new(lerp(1.3, 0.6, u), lerp(-1.1, -0.35, u) + 0.06 * math.sin(t * 11), lerp(-2.0, -2.5, u)),
				lerp(4, 30, u),
				6,
				4 * math.sin(t * 7)
			)
			hide(-1)
		else
			hide(-1)
			hide(1)
		end
	end)

	-- the doors part while the victim is still rising (they stand open by the time they are on their feet)
	ctx:at(2.3, function()
		ctx:tween(doorL, 0.8, { CFrame = doorL.CFrame * CFrame.new(-3.4, 0, 0) })
		ctx:tween(doorR, 0.8, { CFrame = doorR.CFrame * CFrame.new(3.4, 0, 0) })
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
	ctx:at(SHOT, function()
		if soldiers[3] then
			fire(soldiers[3], 1.6)
		end
		Cinema.flash(Color3.fromRGB(255, 236, 200), 0.75, 0.25)
		Cinema.still(Color3.fromRGB(255, 200, 160), 0.12)
	end)
	-- the red closing in from the edges, from the hit on (a soft red-brown haze, deeper as they lie there)
	ctx:at(7.6, function()
		local layer = ctx:layer(2)
		local v = Instance.new("Frame")
		v.BackgroundColor3 = Color3.fromRGB(96, 12, 8)
		v.BorderSizePixel = 0
		v.Size = UDim2.fromScale(1, 1)
		v.BackgroundTransparency = 0.2
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.3, 0.85),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.7, 0.85),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		g.Parent = v
		v.Parent = layer
		local v2 = v:Clone()
		v2.UIGradient.Rotation = 90
		v2.Parent = layer
		ctx:tween(v, 4, { BackgroundTransparency = 0.05 })
		ctx:tween(v2, 4, { BackgroundTransparency = 0.05 })
	end)
	-- the swarm boiling up at the upper left of the fallen view (grey static laced with white streaks), 8.5-12
	ctx:at(8.5, function()
		-- (placed where the eyes will look from the floor: up and to the left of the lying view)
		local at = Vector3.new(-1.8, 2.6, 2.2)
		local swarm = SceneDeaths.emit(ctx, at, Vector3.new(2.5, 3, 2.5), {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = { { 0, Color3.fromRGB(205, 205, 210) }, { 1, Color3.fromRGB(60, 60, 66) } },
			size = { { 0, 1.5 }, { 1, 4.5 } },
			alpha = { { 0, 0.35 }, { 0.6, 0.55 }, { 1, 1 } },
			life = { 0.7, 1.3 },
			speed = { 1, 3 },
			spread = 180,
			rot = { 0, 360 },
			spin = { -140, 140 },
			light = 0.1,
			lit = 0.6,
			rate = 50,
		})
		swarm:Emit(24)
		ctx:during(8.5, 12.0, function(t)
			if math.floor(t * 8) % 2 == 0 and math.random() < 0.35 then
				local from =
					ctx:world(at + Vector3.new(math.random() * 2 - 1, math.random() * 2.5, math.random() * 2 - 1))
				Vfx.Beams.bolt(
					from,
					from + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1),
					0.14,
					{ color = Color3.new(1, 1, 1), width = 0.07, bright = 2, pieces = 5 }
				)
			end
		end)
		ctx:at(12.0, function()
			swarm.Enabled = false
		end)
	end)
	-- 15.5-17.3 the volley from the doorway: every shot jolts the view; grit and debris rain from the ceiling
	for i, t in ipairs(VOLLEY) do
		ctx:at(t, function()
			local s = soldiers[(i % #soldiers) + 1]
			if s then
				fire(s, 1)
			end
			Vfx.Emit.burst(ctx:world(Vector3.new(1.0, 10.5, 4.3)), {
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = Color3.fromRGB(26, 24, 24),
				size = { { 0, 0.12 }, { 1, 0.08 } },
				life = { 0.5, 0.9 },
				speed = { 2, 6 },
				spread = 60,
				accel = Vector3.new(0, -30, 0),
				dir = Enum.NormalId.Bottom,
			}, 6)
		end)
	end
	-- 17.45 dark; 17.75 blood over the lens, a white glare, a soldier standing over
	local dark: Frame? = nil
	ctx:at(17.45, function()
		local layer = ctx:layer(4)
		local d = Instance.new("Frame")
		d.BackgroundColor3 = Color3.new(0, 0, 0)
		d.BorderSizePixel = 0
		d.Size = UDim2.fromScale(1, 1)
		d.BackgroundTransparency = 0.35
		d.Parent = layer
		dark = layer
		if soldiers[1] then
			soldiers[1].model:PivotTo(
				ctx.origin
					* CFrame.lookAt(Vector3.new(1.0, 0.2, 3.0), Vector3.new(1.0, 0.2, 6))
					* CFrame.new(0, 3, 0)
					* CFrame.Angles(math.rad(-30), 0, 0)
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
	ctx:grade(7.6, nil, { Saturation = -0.15, TintColor = Color3.fromRGB(255, 196, 184) }, 0.6)
end

return { length = 19.5, build = build }
