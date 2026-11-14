-- Walrider (art/refs/deaths/walrider.md, 21.5 s), reworked 2026-11-12 to the user's notes. FIRST PERSON the whole
-- way: the camera is the victim's eyes, and all that is seen of them is their own arm, the dead player's, coming in
-- from the edge of the frame as a game's view arm does. Face down on the floor pushing up, both hands (0-1.6); rising,
-- the trail of blood they dragged and the hazard stripe swinging through, the doors parting on the lit white room
-- (1.6-3.3); the staggering walk at the door, only the right hand out ahead (3.3-5.4); they see the soldiers and back
-- up a step or two, the hand coming up (5.4-7.3); the front soldier, the only one who raises his rifle, fires ONCE
-- (7.3); about eight seconds of slow motion, still standing: the hand comes up red from the wound, reaches out at him
-- (7.7-15.2); then he empties the rifle into them (15.3-16.4); only then they fall, onto their back (16.6-17.9);
-- lying there, the swarm boiling up at the edge; blood landing on the lens and running; the picture fades to black.
-- The soldiers never walk in: each is at his own business in the doorway (their clips, scene_actors.py), and none of
-- them comes to stand over the body (2026-11-14, the user: "fix the soldier appearing on top of you at the end").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Suit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Suit"))
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Splat = require(script.Parent.Splat)

local CONCRETE = Color3.fromRGB(150, 164, 172)
local STEEL = Color3.fromRGB(70, 80, 88)
local BLOOD = Color3.fromRGB(110, 8, 10)
local BLACK = Color3.fromRGB(20, 20, 22)

local WALK = 3.3 -- on their feet: the walk at the door begins
local DOORS = WALK + 1.0 -- the doors part a second into the walk (2026-11-14, the user: "not immediately")
local SEEN = 5.4 -- they see the soldiers and stop
local SHOT = 7.3 -- the one shot (soldier 3's clip fires then)
local SLOW_FROM, SLOW_TO = 7.7, 15.2 -- the slow motion, still standing
-- the shot, then the volley (soldier 3's clip recoils on each: scene_actors.py VOLLEY)
local VOLLEY = { SHOT, 15.3, 15.42, 15.53, 15.66, 15.78, 15.9, 16.03, 16.15, 16.28, 16.4 }
local FALL = 16.6 -- only now do they fall
local DARK = 19.6 -- the blood lands on the lens
local FADE = 20.2 -- the picture goes down to black from here (2026-11-14: "make the screen fade to black")
local LENGTH = 21.5

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

-- The victim's own right arm (the left too, for the push off the floor) for the first-person view, as a game's view
-- arm: it starts at the shoulder (below and behind the lens, out of the picture) and runs to the hand, so it always
-- comes in from the edge of the frame, attached (2026-11-12, the user: "you made it look like its detached"). It is
-- the dead player's own arm (2026-11-12, "the hand of the players avatar that died"): their arm part and colour; the
-- match suit's sleeve and their skin on the hand when they wear the suit (in a case), else their avatar's own shirt
-- (a Humanoid in the holder draws it). Blood on the hand and the cuff, more of it after the shot.
local function ownArm(ctx, side: number, character: Model?, skin: Color3): (Model, { BasePart })
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
		arm.Color = skin
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
	local bloody = {}
	local suited = character ~= nil and character:FindFirstChild("LHandRight", true) ~= nil
	if suited or not character then
		for _, list in ipairs({ Suit.cloth(arm), Suit.hand(arm, skin) }) do
			for _, piece in ipairs(list) do
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CastShadow = false
				piece.Parent = model
				if piece.Name == "Hand" or piece.Name == "Cuff" then
					table.insert(bloody, piece)
				end
			end
		end
	else
		-- their own avatar: the shirt and the body colours drawn on the arm by a Humanoid in the holder
		local humanoid = Instance.new("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.Parent = model
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("BodyColors") then
				item:Clone().Parent = model
			end
		end
		table.insert(bloody, arm)
	end
	model.PrimaryPart = arm
	model.Parent = ctx.stage.folder
	return model, bloody
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
	-- in his wheelchair among them. They stay where they stand, each at his own business (their clips); only soldier 3,
	-- the front one at the right, raises his rifle and fires.
	local soldiers = {}
	local marks =
		{ Vector3.new(-3.2, 0, -7.5), Vector3.new(-1.4, 0, -9.6), Vector3.new(2.6, 0, -6.6), Vector3.new(3.6, 0, -9.0) }
	local faces =
		{ Vector3.new(-1.4, 0, -9.6), Vector3.new(-3.2, 0, -7.5), Vector3.new(0, 0, 6), Vector3.new(0.4, 0, -10.2) }
	for i, at in ipairs(marks) do
		local s = ctx:actor("cast:soldier", CFrame.lookAt(at, faces[i]), "sceneWalriderSoldier" .. i)
		if s then
			local rifle = ctx:wear(s, "rifle")
			soldiers[i] = { model = s, rifle = rifle, i = i, from = at }
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
	local shooter = soldiers[3]

	-- the victim's own arms
	local skin = Color3.fromRGB(214, 180, 150)
	local character: Model? = nil
	local who = if ctx.victim then Players:GetPlayerByUserId(ctx.victim) else Players.LocalPlayer
	character = who and who.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		skin = head.Color
	end
	local arms, bloody = {}, {}
	arms[-1], bloody[-1] = ownArm(ctx, -1, character, skin)
	arms[1], bloody[1] = ownArm(ctx, 1, character, skin)
	local function bleed(share: number)
		for _, side in ipairs({ -1, 1 }) do
			for _, p in ipairs(bloody[side]) do
				local base = p:GetAttribute("Clean") or p.Color
				p:SetAttribute("Clean", base)
				p.Color = (base :: Color3):Lerp(BLOOD, share)
			end
		end
	end
	bleed(0.35)
	-- an arm in the eyes' frame: its hand ON `hand` (lens frame: x right, y up, z back, so ahead is negative), the arm
	-- running back from it toward its shoulder (side * 0.95 right, 1.35 down, 0.3 ahead: past the bottom corner of
	-- the picture, so the arm always comes in from the frame's edge), the palm turned `roll` degrees. Lying face down
	-- the shoulders are under and behind the lens instead (PRONE).
	local SHOULDER = Vector3.new(0.95, -1.35, -0.3)
	local PRONE = Vector3.new(1.0, -1.4, 0.2)
	local function place(side: number, cam: CFrame, hand: Vector3, roll: number?, prone: boolean?)
		local anchor = if prone then PRONE else SHOULDER
		local shoulder = Vector3.new(side * anchor.X, anchor.Y, anchor.Z)
		local way = (hand - shoulder).Unit
		local length = arms[side].PrimaryPart.Size.Y
		local middle = hand - way * (length / 2)
		local local_ = CFrame.lookAt(middle, middle + way) * CFrame.Angles(math.rad(90), 0, 0)
		arms[side]:PivotTo(cam * local_ * CFrame.Angles(0, math.rad(roll or 0), 0))
	end
	local function hide(side: number)
		arms[side]:PivotTo(CFrame.new(0, -5000, 0))
	end

	-- the eyes (pos in scene space; pitch down is negative, roll in degrees)
	local function eyes(t: number): (CFrame, number)
		local pos, pitch, yaw, roll, fov = Vector3.new(0, 0.7, 7.5), -70, 0, 0, 72
		if t < 1.6 then
			-- face down over the floor, pushing: the view rocks with each push and rolls a little
			local push = math.sin(t * 2.4)
			pos = Vector3.new(0.1 * push, 0.9 + 0.2 * math.max(0, push), 7.5)
			pitch, yaw, roll = -74 + 8 * push, 4 * push, -6 + 5 * push
		elseif t < 3.3 then
			-- rising: the head comes up and swings, the floor's trail and the stripe sweep through, the door rises in
			local u = smooth((t - 1.6) / 1.7)
			local sway = math.sin(u * math.pi) * 18
			pos = Vector3.new(0.2 * math.sin(u * 6), lerp(1.1, 4.7, u), lerp(7.5, 6.9, u))
			pitch, yaw, roll = lerp(-68, -6, u), lerp(6, 0, u) + sway * 0.3, lerp(-6, 0, u) + sway
		elseif t < SEEN then
			-- the staggering walk at the door: heavy steps, the view bobbing and rolling with each
			local u = (t - 3.3) / (SEEN - 3.3)
			local step = math.sin(t * 4.6)
			pos = Vector3.new(0.3 * step, 4.7 + 0.14 * math.abs(step), lerp(6.9, 4.3, u))
			pitch, yaw, roll = -5 + 2 * step, 3 * math.sin(t * 2.3), 4 * step
		elseif t < SHOT then
			-- he sees them: stops dead, then backs up two short steps, the head lifting
			local u = smooth((t - SEEN) / 1.0)
			local step = math.abs(math.sin(math.clamp((t - SEEN) / 1.0, 0, 1) * math.pi * 2)) * 0.08
			pos = Vector3.new(lerp(0.1, -0.1, u), 4.75 - step, lerp(4.3, 5.2, u))
			pitch, yaw, roll = lerp(-4, 1, u), lerp(1, -2, u) + math.sin(t * 9) * 0.4, lerp(2, -2, u)
		elseif t < SLOW_FROM then
			-- hit: the view jolts back
			local u = smooth((t - SHOT) / (SLOW_FROM - SHOT))
			pos = Vector3.new(lerp(-0.1, 0.1, u), lerp(4.75, 4.65, u), lerp(5.2, 5.55, u))
			pitch, yaw, roll = lerp(1, 7, u), lerp(-2, 4, u), lerp(-2, 7, u)
		elseif t < SLOW_TO then
			-- SLOW MOTION, still standing: the view drifts on, unsteady; down to the hand (9-11.5), back up at the man
			-- with the rifle (12.5-15), the knees going a little, the edges closing in
			local u = (t - SLOW_FROM) / (SLOW_TO - SLOW_FROM)
			local look = smooth((t - 8.8) / 1.4) - smooth((t - 11.4) / 1.6)
			pos = Vector3.new(0.1 + 0.12 * math.sin(t * 0.7), lerp(4.65, 4.4, u) + 0.03 * math.sin(t * 1.1), 5.55)
			pitch = lerp(7, 0, smooth(u * 2)) - 34 * look + 1.5 * math.sin(t * 0.8)
			yaw = lerp(4, 7, u) + 2 * math.sin(t * 0.5) - 8 * look
			roll = 7 + 5 * math.sin(t * 0.45) + 3 * u
			fov = lerp(72, 62, smooth(u * 1.5))
		elseif t < FALL then
			-- the volley: the view held up on them, every round jolting it
			pos = Vector3.new(0.2, 4.4, 5.6)
			pitch, yaw, roll, fov = 1, 6, 11, 62
		elseif t < 17.9 then
			-- the fall, at last: backward onto the floor, a drop with a bounce, the view going over to the ceiling
			local u = (t - FALL) / (17.9 - FALL)
			local drop = smooth(math.min(1, u * 1.35))
			local bounce = math.exp(-u * 6) * math.sin(u * 20) * 0.25 * drop
			pos = Vector3.new(lerp(0.2, 0.7, drop), lerp(4.4, 0.9, drop) + bounce, lerp(5.6, 6.9, drop))
			pitch, yaw, roll = lerp(1, 58, drop), lerp(6, -12, drop), lerp(11, 24, smooth(u))
			fov = lerp(62, 72, drop)
		elseif t < DARK then
			-- lying on the back: the vault's light above, the doorway at the top of the view, barely moving
			local u = smooth((t - 17.9) / (DARK - 17.9))
			pos = Vector3.new(0.7, 0.9, 6.9)
			pitch, yaw, roll = lerp(58, 52, u), lerp(-12, -8, u), lerp(24, 18, u)
		else
			pos = Vector3.new(0.7, 0.9, 6.9)
			pitch, yaw, roll = 70, 0, -3
		end
		-- (the first shot and every round of the volley jolt the view)
		for _, v in ipairs(VOLLEY) do
			if t >= v and t < v + 0.12 then
				local k = 1 - (t - v) / 0.12
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
	ctx:camera(0, LENGTH, eyes)

	-- the arms in the eyes' frame: both on the floor pushing up; after that only the right one (2026-11-12, the user:
	-- "when walking, only the right hand should be visible")
	ctx:during(0, LENGTH, function(t)
		local cam = workspace.CurrentCamera.CFrame
		if t < 1.6 then
			-- both hands flat on the floor either side, just under the lens (the floor is a stud off), pushing
			local push = math.sin(t * 2.4)
			place(-1, cam, Vector3.new(-0.78, -0.5 + 0.08 * math.max(0, push), -0.82), -10, true)
			place(1, cam, Vector3.new(0.78, -0.5 + 0.08 * math.max(0, -push), -0.85), 10, true)
		elseif t < 3.3 then
			-- rising: the right hand pushes off and drops away under the frame
			local u = smooth((t - 1.6) / 1.7)
			hide(-1)
			place(1, cam, Vector3.new(0.8, lerp(-0.5, -2.0, u), lerp(-0.85, -1.1, u)), 10, true)
		elseif t < SEEN then
			-- the walk: the right hand out ahead, reaching for the door, swaying with each step
			local step = math.sin(t * 4.6)
			local reach = smooth((t - 3.3) / 0.8)
			place(
				1,
				cam,
				Vector3.new(0.62 + 0.08 * step, lerp(-1.9, -0.72, reach) + 0.07 * math.abs(step), -2.2),
				-8 + 6 * step
			)
		elseif t < SHOT then
			-- seen them: the hand comes up between, palm out, shaking
			local u = smooth((t - SEEN) / 0.6)
			place(
				1,
				cam,
				Vector3.new(lerp(0.62, 0.42, u), lerp(-0.72, -0.42, u) + 0.02 * math.sin(t * 23), -2.15),
				lerp(-8, -70, u)
			)
		elseif t < 8.8 then
			-- the shot: the hand drops away to the wound
			local u = smooth((t - SHOT) / 0.6)
			place(1, cam, Vector3.new(lerp(0.42, 0.35, u), lerp(-0.42, -2.3, u), lerp(-2.15, -1.6, u)), -70)
		elseif t < 11.6 then
			-- slow: the hand comes up from the wound into the view, palm up, red, turning; then sinks
			local up = smooth((t - 8.8) / 1.4) * (1 - smooth((t - 10.8) / 0.8))
			place(
				1,
				cam,
				Vector3.new(0.4, lerp(-2.3, -0.55, up) + 0.015 * math.sin(t * 2), lerp(-1.6, -1.95, up)),
				lerp(-70, -165, up) + 6 * math.sin(t * 0.9)
			)
		elseif t < SLOW_TO then
			-- slow: reaching out at the man with the rifle, trembling, the arm heavy
			local u = smooth((t - 11.6) / 2.4)
			place(
				1,
				cam,
				Vector3.new(lerp(0.4, 0.5, u), lerp(-2.1, -0.85, u) + 0.02 * math.sin(t * 6), -2.2),
				lerp(-120, -20, u)
			)
		elseif t < FALL then
			-- the volley: the arm jerked with every round
			local kick = 0
			for _, v in ipairs(VOLLEY) do
				if t >= v and t < v + 0.1 then
					kick = 1 - (t - v) / 0.1
				end
			end
			place(1, cam, Vector3.new(0.5 + 0.12 * kick, -0.85 - 0.25 * kick, -2.2), -20 + 25 * kick)
		elseif t < 17.9 then
			-- falling: the arm flung up and out of the frame
			local u = smooth((t - FALL) / 0.7)
			place(1, cam, Vector3.new(lerp(0.5, 1.9, u), lerp(-0.85, 0.3, u), lerp(-2.2, -1.6, u)), lerp(-20, 40, u))
		elseif t < 19.3 then
			-- on the floor: the hand lifts toward the light above, weakly, and falls back
			local u = smooth((t - 18.2) / 0.7) * (1 - smooth((t - 18.95) / 0.35))
			place(1, cam, Vector3.new(0.55, lerp(-2.3, -0.6, u) + 0.03 * math.sin(t * 9), lerp(-1.5, -2.0, u)), -150)
		else
			hide(1)
		end
		if t >= SEEN then
			hide(-1)
		end
	end)

	-- the doors stay shut while the victim gets up and for the first second of the walk at them; then they part: a
	-- crack of the white room's light first, a jolt as they unlatch, and they slide (heavy: slow to start)
	ctx:at(DOORS, function()
		Sfx.play("realmMetal1", { pitch = 0.6, volume = 1.0 })
		Vfx.Screen.shake(0.35, 0.25)
		ctx:tween(doorL, 0.14, { CFrame = doorL.CFrame * CFrame.new(-0.12, 0, 0) }, Enum.EasingStyle.Quad)
		ctx:tween(doorR, 0.14, { CFrame = doorR.CFrame * CFrame.new(0.12, 0, 0) }, Enum.EasingStyle.Quad)
		local openL, openR = doorL.CFrame * CFrame.new(-3.4, 0, 0), doorR.CFrame * CFrame.new(3.4, 0, 0)
		ctx:atNow(DOORS + 0.2, function()
			ctx:tween(doorL, 0.8, { CFrame = openL }, Enum.EasingStyle.Cubic)
			ctx:tween(doorR, 0.8, { CFrame = openR }, Enum.EasingStyle.Cubic)
			Cinema.flash(Color3.fromRGB(236, 242, 255), 0.22, 0.9)
		end)
	end)
	-- a muzzle flash at the front soldier's rifle (its light on the room), smoke off the muzzle, the casing
	local function fire(strength: number, slow: boolean)
		local rifle = shooter and shooter.rifle
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
			tex = "VfxSmoke",
			color = Color3.fromRGB(200, 200, 204),
			size = { { 0, 0.3 }, { 1, if slow then 2.4 else 1.2 } },
			alpha = { { 0, 0.55 }, { 1, 1 } },
			life = if slow then { 6, 7.5 } else { 0.8, 1.2 },
			speed = if slow then { 0.1, 0.3 } else { 1, 2.5 },
			spread = 30,
			rot = { 0, 360 },
			spin = if slow then { -8, 8 } else { -60, 60 },
			lit = 0.8,
		}, if slow then 4 else 2)
		Vfx.Emit.burst(tip, {
			tex = "VfxChunk",
			color = Color3.fromRGB(196, 160, 70),
			size = { { 0, 0.07 }, { 1, 0.06 } },
			life = if slow then { 6, 7 } else { 0.5, 0.8 },
			speed = if slow then { 0.4, 0.6 } else { 5, 8 },
			spread = 20,
			accel = if slow then Vector3.new(0, -0.15, 0) else Vector3.new(0, -30, 0),
			rot = { 0, 360 },
			spin = if slow then { -40, 40 } else { -600, 600 },
			lit = 1,
		}, 1)
	end
	-- the hit on the view: the picture jolts red, and now and then blood lands at the edge of the lens (`splat`: where
	-- and how big; they fade before the next, so the view never fills until the end)
	local lens = ctx:layer(3)
	local function hit(strength: number, splat: { number }?)
		Cinema.flash(Color3.fromRGB(150, 10, 8), 0.45 * strength, 0.18)
		Vfx.Screen.shake(0.9 * strength, 0.2)
		if splat then
			Splat.screen(lens, {
				at = Vector2.new(splat[1], splat[2]),
				size = splat[3],
				seed = math.floor(splat[1] * 977 + splat[2] * 131),
				hold = splat[4] or 0.7,
				fade = 0.8,
				drips = if splat[3] > 0.3 then 2 else 0,
				alpha = 0.12,
			})
		end
	end
	ctx:at(SHOT, function()
		fire(1.6, true)
		hit(1.2, { 0.14, 0.78, 0.46, 2.6 })
		Cinema.flash(Color3.fromRGB(255, 236, 200), 0.75, 0.25)
		Cinema.still(Color3.fromRGB(255, 200, 160), 0.12)
		bleed(0.75)
	end)
	-- the slow motion (2026-11-12, the user: "a little slowmo scene of about 8 seconds"): the world drained and dim,
	-- dust hanging in the air, a slow heartbeat, the red closing in from the edges
	local undoGrade: (() -> ())? = nil
	ctx:at(SLOW_FROM, function()
		undoGrade = Cinema.tint({ Saturation = -0.55, Contrast = 0.2, TintColor = Color3.fromRGB(226, 214, 214) }, 0.6)
		SceneDeaths.emit(ctx, Vector3.new(0, 4.5, 1.5), Vector3.new(8, 5, 8), {
			tex = "VfxDust",
			color = Color3.fromRGB(230, 230, 236),
			size = { { 0, 0.04 }, { 0.5, 0.07 }, { 1, 0.03 } },
			alpha = { { 0, 1 }, { 0.3, 0.4 }, { 0.7, 0.4 }, { 1, 1 } },
			life = { 6, 8 },
			speed = { 0.02, 0.08 },
			spread = 180,
			lit = 1,
			rate = 12,
		}, SLOW_FROM, SLOW_TO):Emit(40)
	end)
	for k = 0, 6 do
		ctx:at(SLOW_FROM + 0.5 + k * 1.1, function()
			Sfx.play("heartbeat", { pitch = 0.62, volume = 1.1 })
		end)
	end
	ctx:at(SLOW_TO, function()
		if undoGrade then
			undoGrade()
		end
	end)
	-- the red closing in from the edges, from the hit on (a soft red-brown haze, deeper as it goes)
	ctx:at(7.6, function()
		local layer = ctx:layer(2)
		local v = Instance.new("Frame")
		v.BackgroundColor3 = Color3.fromRGB(96, 12, 8)
		v.BorderSizePixel = 0
		v.Size = UDim2.fromScale(1, 1)
		v.BackgroundTransparency = 0.45
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
		ctx:tween(v, 8, { BackgroundTransparency = 0.15 })
		ctx:tween(v2, 8, { BackgroundTransparency = 0.15 })
		ctx:atNow(FALL, function()
			ctx:tween(v, 1.5, { BackgroundTransparency = 0 })
			ctx:tween(v2, 1.5, { BackgroundTransparency = 0 })
		end)
	end)
	-- the volley: the front man empties his rifle; every round jolts the view and sprays red at its edge
	for i, t in ipairs(VOLLEY) do
		if i > 1 then
			ctx:at(t, function()
				fire(1, false)
				-- (a splat on the second, fifth, eighth and last rounds, each at another edge)
				local where = ({
					[2] = { 0.9, 0.24, 0.26 },
					[5] = { 0.08, 0.3, 0.3 },
					[8] = { 0.82, 0.8, 0.34 },
					[11] = { 0.3, 0.9, 0.28 },
				})[i]
				hit(0.8, where)
				bleed(math.min(1, 0.75 + i * 0.03))
			end)
		end
	end
	-- the swarm boiling up at the upper left of the fallen view (grey static laced with white streaks)
	ctx:at(17.6, function()
		local at = Vector3.new(-1.6, 2.6, 5.4)
		local swarm = SceneDeaths.emit(ctx, at, Vector3.new(2.5, 3, 2.5), {
			tex = "VfxSmoke",
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
		ctx:during(17.6, DARK, function(t)
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
		ctx:at(DARK, function()
			swarm.Enabled = false
		end)
	end)
	-- the end (2026-11-14, the user: "fix the soldier appearing on top of you at the end, make the screen fade to black
	-- and make those on screen blood splatters way more high quality"): nobody comes to stand over the body. The view
	-- dims as the eyes go; blood lands on the lens, one heavy splat and then others round it, each thrown on, creeping
	-- and running down; the ceiling's light blooms pale through it; and the picture goes down to black, slowly, and
	-- stays black.
	ctx:at(DARK, function()
		local layer = ctx:layer(4)
		local dim = Instance.new("Frame")
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BorderSizePixel = 0
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundTransparency = 1
		dim.Parent = layer
		ctx:tween(dim, 0.5, { BackgroundTransparency = 0.5 })
		local glare = Instance.new("Frame")
		glare.BackgroundColor3 = Color3.fromRGB(235, 236, 240)
		glare.BorderSizePixel = 0
		glare.Size = UDim2.fromScale(1, 1)
		glare.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = glare
		glare.Parent = layer
		ctx:tween(glare, 0.35, { BackgroundTransparency = 0.6 })
		ctx:atNow(DARK + 0.4, function()
			ctx:tween(glare, 1.2, { BackgroundTransparency = 1 })
		end)
		-- the blood: the heavy one first, then the rest in their own time (none on a beat), each its own picture, size
		-- and turn; they stay to the end and go down with the picture
		for _, spec in ipairs({
			{ 0.0, 0.34, 0.42, 0.78, 3, 3 },
			{ 0.11, 0.72, 0.3, 0.5, 1, 2 },
			{ 0.19, 0.58, 0.76, 0.44, 4, 1 },
			{ 0.3, 0.12, 0.74, 0.36, 2, 2 },
			{ 0.36, 0.88, 0.68, 0.3, 1, 1 },
			{ 0.47, 0.5, 0.14, 0.26, 2, 0 },
			{ 0.55, 0.16, 0.16, 0.32, 4, 1 },
		}) do
			ctx:atNow(DARK + spec[1], function()
				Splat.screen(layer, {
					at = Vector2.new(spec[2], spec[3]),
					size = spec[4],
					image = spec[5],
					seed = math.floor(spec[2] * 1000 + spec[3] * 77),
					drips = spec[6],
					hold = 10,
					alpha = 0.04,
					z = 2,
				})
				Vfx.Screen.shake(0.25, 0.12)
			end)
		end
		ctx:atNow(FADE, function()
			local black = Instance.new("Frame")
			black.BackgroundColor3 = Color3.new(0, 0, 0)
			black.BackgroundTransparency = 1
			black.BorderSizePixel = 0
			black.Size = UDim2.fromScale(1, 1)
			black.ZIndex = 20
			black.Parent = layer
			ctx:tween(black, LENGTH - FADE - 0.35, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
		end)
	end)
	ctx:grade(0, nil, { Saturation = -0.25, Contrast = 0.15, TintColor = Color3.fromRGB(214, 226, 236) }, 0.1)
	ctx:grade(FALL, nil, { Saturation = -0.15, TintColor = Color3.fromRGB(255, 196, 184) }, 0.6)
end

return { length = LENGTH, build = build }
