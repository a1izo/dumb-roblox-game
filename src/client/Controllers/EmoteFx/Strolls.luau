-- The strolls: The Long Climb (the escalator, the giant image, the rain), and the footfall marks of Griddy and
-- Mushroom Stroll. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local LocomotionController = require(script.Parent.Parent.Parent.Anim.LocomotionController)
local Stage = require(script.Parent.Parent.Parent.Presentation.Stage)
local FxKit = require(script.Parent.Parent.Parent.Presentation.FxKit)
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.Parent.World.Governor)

local Common = require(script.Parent.Shared)
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local burst = Common.burst
local lowerSole = Common.lowerSole
local stepDust = Common.stepDust

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

-- The Long Climb (Subaru's endless stair, after JJS's "Aura monster": the owner's Q24/Q38): an escalator of dark
-- steps with glowing green edges under the climber, going down as fast as they climb, so they climb it for ever and
-- never rise (the owner, 2026-10-24): the step under their feet is always at the floor, the ones ahead come down to
-- meet them, the ones behind sink into the floor. Over their shoulders from behind looms a green-lit image of their
-- head and shoulders, grinning (EmoteMedia FACES `manicGrin`; their own face until that picture is in), and green
-- light falls round them like rain. Green is this emote's own colour. Seen by everyone, in a case too, so the image
-- is no bigger than a body and a half (2026-10-24: "imagine if everyone in the server had it"); on low graphics only
-- the steps, under reduced motion no rain and a still image.
local CLIMB_GREEN = Color3.fromRGB(64, 255, 118)
local CLIMB_DARK = Color3.fromRGB(9, 13, 10)
local STEP_RUN = 1.55 -- studs from one step's nosing to the next
local STEP_RISE = 0.42
local STEP_WIDTH = 3.6
local STEP_THICK = 0.16
local STEP_EDGE = 0.08
local FLIGHT_BEHIND, FLIGHT_AHEAD = 2, 4 -- the steps shown behind the one under the feet, and ahead of it
local IMAGE_SCALE = 1.55
local IMAGE_BEHIND = 2.6 -- studs behind the climber
local IMAGE_SUNK = -0.9 -- studs of its body below the floor (under nought: its torso's bottom over the floor)
local IMAGE_LEAN = math.rad(-14) -- leaning over them
local IMAGE_ALPHA = 0.6 -- its parts' transparency at full strength
local IMAGE_IN, IMAGE_OUT = 0.9, 0.6
local RAIN_UP = 10 -- studs above the climber the rain starts

type ClimbStep = { parts: { BasePart }, offsets: { CFrame }, base: { number } }

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

-- One step of the flight, placed by the middle of its tread's top: the tread, the riser down from its back edge to
-- the step behind, the lit nosing along that edge and its two lit sides.
local function climbStep(): ClimbStep
	local half = STEP_RUN / 2
	local side = STEP_WIDTH / 2
	return {
		parts = {
			climbPart(
				"ClimbTread",
				Vector3.new(STEP_WIDTH, STEP_THICK, STEP_RUN),
				CLIMB_DARK,
				Enum.Material.SmoothPlastic
			),
			climbPart("ClimbRiser", Vector3.new(STEP_WIDTH, STEP_RISE, 0.06), CLIMB_DARK, Enum.Material.SmoothPlastic),
			climbPart(
				"ClimbEdge",
				Vector3.new(STEP_WIDTH + STEP_EDGE, STEP_EDGE, STEP_EDGE),
				CLIMB_GREEN,
				Enum.Material.Neon
			),
			climbPart("ClimbEdge", Vector3.new(STEP_EDGE, STEP_EDGE, STEP_RUN), CLIMB_GREEN, Enum.Material.Neon),
			climbPart("ClimbEdge", Vector3.new(STEP_EDGE, STEP_EDGE, STEP_RUN), CLIMB_GREEN, Enum.Material.Neon),
		},
		-- (the climb faces -Z: a step's back edge is at +Z)
		offsets = {
			CFrame.new(0, -STEP_THICK / 2, 0),
			CFrame.new(0, -STEP_RISE / 2, half),
			CFrame.new(0, 0, half),
			CFrame.new(side, 0, 0),
			CFrame.new(-side, 0, 0),
		},
		base = { 0.06, 0.2, 0, 0.25, 0.25 }, -- (the nosing brightest)
	}
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
	local holder = climbPart("ClimbRain", Vector3.new(14, 0.5, 14), CLIMB_GREEN, Enum.Material.SmoothPlastic)
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
		Lifetime = NumberRange.new(0.36, 0.4),
		Rate = 40,
		Speed = NumberRange.new(26, 29),
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

	local function heading(): Vector3
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		return if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	end

	-- The escalator: a step every STEP_RUN along the way they face, the tread at the middle of the flight under
	-- their feet. As they walk the treads keep their place on the ground (no foot slides on one) and sink by the
	-- slope, so the next one has come down to the floor by the time they reach it; behind, the sunk ones go under
	-- the floor and fade, and each comes round again at the top.
	local steps: { ClimbStep } = {}
	for i = 1, FLIGHT_BEHIND + FLIGHT_AHEAD + 1 do
		steps[i] = climbStep()
	end
	local flightParts: { BasePart } = {}
	for _, step in ipairs(steps) do
		for _, part in ipairs(step.parts) do
			table.insert(flightParts, part)
		end
	end
	local walked = 0
	local lastAt = root.Position
	local flight = 0 -- 0 .. 1: the flight coming up as it begins, going as it ends

	-- a green light on the step under the feet
	local glow: BasePart? = nil
	if not low then
		glow = climbPart("ClimbGlow", Vector3.new(0.2, 0.2, 0.2), CLIMB_GREEN, Enum.Material.SmoothPlastic)
		Create("PointLight", { Color = CLIMB_GREEN, Range = 8, Brightness = 1.4, Shadows = false, Parent = glow })
	end
	-- On the new kit (stage 4b second batch, Pilot.on.theLongClimb; false = the old build). One sentence: the endless stair
	-- lighting up under the climber, green light rising off every step and a green mist trailing behind (motif: cold green
	-- light, rain, mist). The five moments, by the clip (it begins at 0, the flight comes up in 0.3 s, the image in 0.9 s):
	--   gather    0.0 to 0.3 s  specks of green drawn in to the first step, a ring on the floor
	--   hit       0.3 s         a column of light standing out of the floor (Fresh.pillar), a white-hot base, a green light
	--   body      0.3 s on      green motes rising off the feet and a bank of green mist trailing, a dark bank under it; each
	--                           footfall a green star and ring on its step (Fresh.tap)
	--   break-up  at the end    the loops are let go, the last motes and mist thin out by their own lives
	--   residue   1.3 s on      the column's scorch and one glowing mark where it stood
	local fresh = Pilot.on.theLongClimb and not low
	local ramp = Palette.pair(CLIMB_GREEN, Color3.fromRGB(170, 255, 200))
	local cancelPillar: (() -> ())? = nil
	local feet: Part? = nil
	local loop: { stop: () -> (), destroy: () -> () }? = nil
	if fresh then
		if not calm then
			cancelPillar = Fresh.pillar(
				CFrame.new(floorUnder(root.Position, character)),
				{ ramp = ramp, height = 11, radius = 1.3, seconds = 1.0, lead = 0.3 }
			)
		end
		local shade = Fresh.Small.shadow(ramp)
		local hot = Fresh.Small.hotter(ramp)
		feet = Vfx.Emit.point(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), Vector3.new(5, 0.1, 5))
		local holder = feet :: Part
		Vfx.Clock.every(function(): boolean?
			if gone or not root.Parent then
				return false
			end
			holder.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0))
			return true
		end)
		loop = Fresh.Small.loop(holder, {
			{
				-- (a low bank of green mist trailing behind the climber, lit from within)
				tex = "VfxMist",
				ramp = ramp,
				size = { { 0, 2.6 }, { 1, 3.8 } },
				alpha = { { 0, 1 }, { 0.25, 0.4 }, { 0.75, 0.5 }, { 1, 1 } },
				life = { 3, 4 },
				speed = { 0.2, 0.8 },
				spread = 180,
				rot = { 0, 360 },
				rate = 1.4,
				light = 0.5,
				lit = 0.4,
			},
			{
				-- (the dark bank under it: laid over, never added)
				tex = "VfxMist",
				ramp = shade,
				size = { { 0, 2.8 }, { 1, 4 } },
				alpha = { { 0, 1 }, { 0.3, 0.6 }, { 0.75, 0.7 }, { 1, 1 } },
				life = { 3.5, 4.5 },
				speed = { 0.1, 0.5 },
				spread = 180,
				rot = { 0, 360 },
				rate = 0.9,
				light = 0,
				lit = 0.1,
				z = -1,
			},
			{
				-- (green light rising off the steps in motes)
				tex = "VfxSparks",
				ramp = hot,
				size = { { 0, 0.35 }, { 1, 0.1 } },
				alpha = { { 0, 1 }, { 0.12, 0.1 }, { 0.75, 0.3 }, { 1, 1 } },
				life = { 1.2, 2 },
				speed = { 0.8, 2.4 },
				spread = 40,
				accel = Vector3.new(0, 1.4, 0),
				drag = 0.8,
				rot = { 0, 360 },
				rate = 9,
				bright = 1.3,
			},
		})
	end
	local footfall = LocomotionController.Footfall:Connect(function(who: Model)
		local sole = if who == character and not gone and not low then lowerSole(character) else nil
		if sole then
			local floor = floorUnder(sole, character)
			if fresh then
				Fresh.tap(
					CFrame.new(Vector3.new(sole.X, floor.Y + 0.08, sole.Z)),
					{ ramp = ramp, scale = 0.9, flat = true, sparks = 4, lead = 0.04 }
				)
			else
				FxKit.shape("ring", CFrame.new(Vector3.new(sole.X, floor.Y + 0.06, sole.Z)), {
					size = 2.6,
					seconds = 0.3,
					color = CLIMB_GREEN,
					transparency = 0.45,
				})
			end
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
			Create("PointLight", { Color = CLIMB_GREEN, Range = 9, Brightness = 0.9, Shadows = false, Parent = head })
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
		local way = heading()
		local floor = floorUnder(root.Position, character)
		-- the escalator
		flight = if gone then math.max(0, flight - dt / 0.4) else math.min(1, flight + dt / 0.3)
		local moved = root.Position - lastAt
		lastAt = root.Position
		walked = (walked + math.max(0, moved:Dot(way))) % STEP_RUN
		local frame = CFrame.lookAt(floor, floor + way)
		local slope = STEP_RISE / STEP_RUN
		local cframes = table.create(#flightParts)
		local k = 0
		for i, step in ipairs(steps) do
			-- (along the way: behind is +Z here, ahead -Z; the tread under the feet at nought)
			local ahead = (i - 1 - FLIGHT_BEHIND) * STEP_RUN - walked + STEP_RUN / 2
			local height = ahead * slope
			-- behind and under the floor it fades; at the top it fades in; all of it comes and goes with the flight
			local seen = math.clamp(1 + height / STEP_RISE, 0, 1)
				* math.clamp((FLIGHT_AHEAD + 0.5) - ahead / STEP_RUN, 0, 1)
				* flight
			local at = frame * CFrame.new(0, height, -ahead)
			for j, part in ipairs(step.parts) do
				k += 1
				cframes[k] = at * step.offsets[j]
				part.Transparency = 1 - (1 - step.base[j]) * seen
			end
		end
		workspace:BulkMoveTo(flightParts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		if glow then
			glow.CFrame = CFrame.new(floor + Vector3.new(0, 0.6, 0))
		end
		if rain then
			rain.CFrame = CFrame.new(root.Position + Vector3.new(0, RAIN_UP, 0))
		end
		if not image then
			return
		end
		local move = dt / fadeTime
		strength = if fadeTo > strength then math.min(strength + move, fadeTo) else math.max(strength - move, fadeTo)
		local spot = floor - way * IMAGE_BEHIND
		local goal = CFrame.lookAt(spot, spot + way) * CFrame.new(0, -IMAGE_SUNK, 0)
		-- (it follows a beat behind, swinging round after a turn)
		base = if base then base:Lerp(goal, 1 - math.exp(-dt * 3.5)) else goal
		local t = now - t0
		local sway = if calm
			then CFrame.identity
			else CFrame.new(0, 0.18 * math.sin(t * 1.1), 0) * CFrame.Angles(
				0,
				0,
				math.rad(3.5) * math.sin(t * 0.8)
			)
		local at = (base :: CFrame) * sway * CFrame.Angles(IMAGE_LEAN, 0, 0)
		local imageFrames = table.create(#parts)
		local headAt: CFrame? = nil
		for i, part in ipairs(parts) do
			local place = at * places[i]
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
			imageFrames[i] = place
			part.Transparency = 1 - (1 - IMAGE_ALPHA) * strength
		end
		workspace:BulkMoveTo(parts, imageFrames, Enum.BulkMoveMode.FireCFrameChanged)
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
		if cancelPillar then
			cancelPillar()
		end
		if loop and feet then
			-- (the mist and motes make no more; the last of them thin out on their own before the holder goes)
			local mine, holder = loop, feet
			mine.stop()
			task.delay(4.7, function()
				mine.destroy()
				holder:Destroy()
			end)
		end
		-- the image fades out on its own clock, the rain stops falling, the flight goes down into the floor
		fadeTo, fadeTime = 0, IMAGE_OUT
		local emitter = if rain then rain:FindFirstChildOfClass("ParticleEmitter") else nil
		if emitter then
			emitter.Enabled = false
		end
		task.delay(math.max(IMAGE_OUT, 0.4) + 0.1, function()
			render:Disconnect()
			if image then
				image:Destroy()
			end
			if rain then
				rain:Destroy()
			end
			for _, part in ipairs(flightParts) do
				part:Destroy()
			end
		end)
	end
end

local SPORES = ColorSequence.new(Color3.fromRGB(236, 230, 210), Color3.fromRGB(200, 192, 170))

-- The strolls on the move: each footfall of the walk (LocomotionController.Footfall) leaves its own mark; the old mark
-- (or the new kit's when its flag is on: never faster than one mark every 0.25 s, never on low graphics or under
-- Reduce motion, like the old dust): `fresh(character, sole)` makes the mark.
local function strollFresh(
	on: () -> boolean,
	old: (character: Model) -> (),
	fresh: (character: Model, sole: Vector3) -> ()
): Fx
	return function(character, preview)
		if preview then
			return nothing
		end
		local last = 0
		local connection = LocomotionController.Footfall:Connect(function(who: Model)
			if who ~= character then
				return
			end
			if not on() then
				old(character)
				return
			end
			local now = os.clock()
			local sole = lowerSole(character)
			if sole and now - last >= 0.25 and not Governor.low("emoteFx") and not Motion.isReduced() then
				last = now
				fresh(character, sole)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end
end

-- Griddy: dust kicked up off each landing heel.
-- On the new kit (stage 4b second batch, Pilot.on.griddy; false = the old build). One sentence: a dance step that kicks the
-- floor, dust thrown back off each landing heel in a low roll with a scuff of sparks (motif: stone and dust). Each step,
-- by the footfall (a heel plant every 0.3 to 0.5 s of the walk):
--   gather    the 0.04 s before the heel lands (the call comes with the footfall, so the hit is at once)
--   hit       the landing: a flat ring on the floor and a scuff of white-hot sparks off the heel (Fresh.stepDust)
--   body      a low roll of dust thrown back along the floor, lit from above, rolling and slowing
--   break-up  the roll thins as it runs out
--   residue   a trail of the last of the dust behind a walker, 2 s long
local DUST_RAMP = Palette.WORLD.dust
FX.griddy = strollFresh(function()
	return Pilot.on.griddy
end, function(character)
	stepDust(character, 1.2)
end, function(character, sole)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local heading = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	heading = if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 0, -1)
	local floor = floorUnder(sole, character)
	local at = CFrame.lookAt(
		Vector3.new(sole.X, floor.Y + 0.08, sole.Z),
		Vector3.new(sole.X, floor.Y + 0.08, sole.Z) + heading
	)
	Fresh.stepDust(at, { ramp = DUST_RAMP, scale = 1 })
end)
-- Mushroom Stroll: pale spores puffing up where each foot comes down.
-- On the new kit (stage 4b second batch, Pilot.on.mushroomStroll; false = the old build). One sentence: each foot puffs up a
-- little cloud of pale spores that rise and wander off (motif: spores, soft pale light). Each step, by the footfall:
--   gather    none (the foot is already down)
--   hit       the landing: a small white-hot glint on the cap of the puff and a soft light on the floor (Fresh.spores)
--   body      the cream puff swelling and rising, the dark layer under it, the spores lifting off in all directions
--   break-up  the puff thins away over 2 s
--   residue   the last spores drifting up, 1.4 to 2.2 s
local SPORE_RAMP = Palette.pair(Color3.fromRGB(236, 230, 210), Color3.fromRGB(255, 252, 238))
FX.mushroomStroll = strollFresh(function()
	return Pilot.on.mushroomStroll
end, function(character)
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
end, function(_, sole)
	Fresh.spores(sole + Vector3.new(0, 0.25, 0), { ramp = SPORE_RAMP, scale = 1 })
end)

return FX
