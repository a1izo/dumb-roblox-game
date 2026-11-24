-- The four Godhood showpieces (New World, Reaper's Eyes, Just As Planned, Final Breakdown): each a private
-- cutscene of light round the body. Moved unchanged from the old one-file Controllers/EmoteFx.luau (V2.1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Cinema = require(script.Parent.Parent.Parent.Presentation.Cinema)
local FxKit = require(script.Parent.Parent.Parent.Presentation.FxKit)
local Vfx = require(script.Parent.Parent.Parent.Presentation.Vfx)
local Fresh = require(script.Parent.Parent.Parent.Presentation.Vfx.Fresh)
local Palette = require(script.Parent.Parent.Parent.Presentation.Vfx.Palette)
local Pilot = require(script.Parent.Parent.Parent.Presentation.Vfx.Pilot)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local LightingController = require(script.Parent.Parent.Parent.World.LightingController)

local Common = require(script.Parent.Shared)
local nothing = Common.nothing
local floorUnder = Common.floorUnder
local mine = Common.mine
local CRIMSON = Common.CRIMSON
local after = Common.after
local lowerSole = Common.lowerSole

type Fx = Common.Fx

local FX: { [string]: Fx } = {}

-- A steady layer laid flat on the floor (a sigil, a pool of light) on `point`: one long particle at a time
-- crossfading into the next, `solid` its strongest transparency. Returns set(size) (every particle at once) and stop.
local function floorLayer(
	point: BasePart,
	spec: { [string]: any },
	size: number,
	solid: number
): ((number) -> (), () -> ())
	spec.life = 4
	spec.rate = 1 / 3.8
	spec.alpha = { { 0, 1 }, { 0.05, solid }, { 0.95, solid }, { 1, 1 } }
	spec.speed = 0.001
	spec.face = "flat"
	spec.size = size
	local e, stop = Vfx.Emit.hold(point, spec)
	e:Emit(1)
	return function(s: number)
		e.Size = NumberSequence.new(math.max(s, 0.01))
	end, stop
end

local GOLD = Color3.fromRGB(255, 222, 140)
local BLOOD = Color3.fromRGB(150, 12, 24)
local BLOOD_HOT = Color3.fromRGB(255, 70, 70)

-- New World: a hard light from above and a pale column of it standing round the body.
-- On the new kit (stage 4b, Pilot.on.newWorld; false = the old build below). One sentence: a god's page-storm, the notebook's
-- pages burning into light as the fist closes (motif: paper and pages, cold gold light). The five moments, by the clip's beat:
--   gather    0.0 to 3.4 s  the column pours down, the sigil opens, the pages spiral up round him (the old build, kept)
--   hit       3.42 s        the fist closes: a heavy gold blow with a white core at it (Fresh.impact), the ring out over the floor
--   body      3.42 s on     the column flares wide, the dark layer under the blow, the pages thrown out
--   break-up  3.5 to 4.2 s  the pages go out in one scatter of burning paper at the middle (Fresh.scatter), not seven twinkles
--   residue   to 6 s        gold ash drifting down the column and the impact's thread of smoke; the sigil holds
FX.newWorld = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not root or not root:IsA("BasePart") then
		return nothing
	end
	local fresh = Pilot.on.newWorld
	local ramp = Palette.emote("newWorld") :: Palette.Ramp
	local own = mine(character)
	local calm = Motion.isReduced()
	local warm = Color3.fromRGB(255, 244, 214)
	local removeLight = Cinema.spotlight(character, warm)
	local floor = floorUnder(root.Position, character)
	local base = Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 0.06, 0)))
	local over = false
	local stops: { () -> () } = {}
	-- the column of light pouring down on him: a white core in a gold glow, its streaks falling
	local top = floor + Vector3.new(0, 70, 0)
	local columns = {}
	for k, layer in ipairs({
		{ width = 2.2, color = Color3.new(1, 1, 1), bright = 1.4, speed = -30, repeats = 26 },
		{ width = 6, color = GOLD, bright = 0.75, speed = -18, repeats = 40 },
		{ width = 12, color = GOLD, bright = 0.3, speed = -10, repeats = 55 },
	}) do
		local beam, stop = Vfx.Beams.line(top, floor, {
			tex = "VfxColumn",
			color = layer.color,
			width = 0.01,
			bright = layer.bright,
			speed = layer.speed,
			repeats = layer.repeats,
			z = k,
		})
		table.insert(columns, { beam = beam, width = layer.width })
		table.insert(stops, function()
			stop(0.6)
		end)
		Vfx.Clock.tween(1.1 + 0.1 * k, Vfx.Ease.outCubic, function(u)
			beam.Width0, beam.Width1 = layer.width * u, layer.width * u
		end)
	end
	-- light falling through it
	local motesAt = Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 14, 0)), Vector3.new(4, 0.1, 4))
	local _, stopMotes = Vfx.Emit.hold(motesAt, {
		tex = if fresh then "VfxAshFlakes" else "VfxEmber",
		color = { { 0, Color3.new(1, 1, 1) }, { 1, GOLD } },
		size = if fresh then { { 0, 0.5 }, { 1, 0.3 } } else { { 0, 0.16 }, { 1, 0 } },
		alpha = if fresh then { { 0, 1 }, { 0.15, 0.15 }, { 0.8, 0.3 }, { 1, 1 } } else nil,
		life = { 2.2, 3.2 },
		rate = if fresh then 10 else 18,
		speed = { 2, 4 },
		dir = Enum.NormalId.Bottom,
		spread = 8,
		shape = Enum.ParticleEmitterShape.Box,
		bright = 1.4,
	})
	-- the sigil on the floor opening and turning, a glow under it
	local setSigil, stopSigil = floorLayer(
		base,
		{ tex = "VfxCircle", color = GOLD, light = 0.6, bright = 1.15, spin = if calm then 0 else 9 },
		0.5,
		0.15
	)
	local _, stopGlow = floorLayer(base, { tex = "VfxGlow", color = warm, light = 0.6, bright = 0.7 }, 16, 0.55)
	Vfx.Clock.tween(1.3, Vfx.Ease.outQuart, function(u)
		setSigil(0.5 + 13.5 * u)
	end)
	-- pages of the notebook spiralling up round him
	local pages = {}
	for k = 1, 7 do
		local page = Vfx.Shape.part("page", "VfxPage")
		page.Anchored = true
		page.CanCollide = false
		page.CanQuery = false
		page.CanTouch = false
		page.CastShadow = false
		page.Material = Enum.Material.SmoothPlastic
		page.Size = page.Size * 1.15
		page.Transparency = 1
		page.Parent = Vfx.Emit.folder()
		table.insert(
			pages,
			{ part = page, phase = k / 7 * math.pi * 2, radius = 3.1 + (k % 3) * 0.55, lift = (k - 1) / 7 }
		)
	end
	local began = Vfx.Clock.now()
	table.insert(
		stops,
		Vfx.Clock.every(function(_, now)
			if over or not root.Parent then
				return false
			end
			local t = now - began
			local middle = Vector3.new(root.Position.X, floor.Y, root.Position.Z)
			for _, p in ipairs(pages) do
				if not p.flying then
					local a = p.phase + t * 1.1
					local y = 0.6 + ((p.lift + t / 3.4) % 1) * 6.2
					local pos = middle + Vector3.new(math.cos(a) * p.radius, y, math.sin(a) * p.radius)
					local face = CFrame.lookAt(pos, Vector3.new(middle.X, pos.Y, middle.Z))
					p.part.CFrame = face
						* CFrame.Angles(math.sin(t * 3 + p.phase) * 0.35, 0, math.sin(t * 2.3 + p.phase) * 0.25)
					p.part.Transparency = math.max(0, 1 - t / 0.8)
				end
			end
			return true
		end)
	)
	-- the fist closes (3.42 s): a burst of light at it, the column flares, the pages scatter and burn into light
	table.insert(
		stops,
		Vfx.Clock.after(3.42, function()
			if over or not root.Parent then
				return
			end
			local arm = character:FindFirstChild("Right Arm")
			local fist = if arm and arm:IsA("BasePart")
				then (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
				else root.Position + Vector3.new(0, 3, 0)
			if fresh then
				Fresh.impact(
					CFrame.new(fist),
					{ style = "heavy", ramp = ramp, scale = 1.05, shake = own, flash = own, lead = 0.02 }
				)
			else
				Vfx.Recipes.impact(CFrame.new(fist), { color = GOLD, scale = 1.15, shake = own, flash = own })
			end
			if not fresh then
				Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.1, 0)), 1, 24, 0.7, {
					tex = "VfxRingBand",
					color = warm,
					width = 2.2,
					light = 0.6,
					bright = 1.1,
				})
			end
			Vfx.Rim.glow(character, warm, 2.2, { fill = 0.25 })
			if own and not calm then
				Vfx.Screen.impact({ character }, 0.08)
			end
			for _, c in ipairs(columns) do
				Vfx.Clock.tween(0.6, Vfx.Ease.outQuad, function(u)
					local w = c.width * (1.8 - 0.8 * u)
					c.beam.Width0, c.beam.Width1 = w, w
				end)
			end
			Vfx.Clock.tween(0.7, Vfx.Ease.outQuad, function(u)
				setSigil(14 + 4 * math.sin(u * math.pi))
			end)
			if fresh then
				-- the pages go out as one scatter of burning paper at the middle of the ring
				Fresh.scatter(
					CFrame.new(root.Position + Vector3.new(0, 1.5, 0)),
					{ kind = "paper", ramp = ramp, scale = 1.3, count = 14, flash = false, lead = 0.1 }
				)
			end
			for _, p in ipairs(pages) do
				p.flying = true
				local from = p.part.CFrame
				local out = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
				out = if out.Magnitude > 0.01 then out.Unit else Vector3.xAxis
				Vfx.Clock.tween(0.7, Vfx.Ease.outCubic, function(u)
					p.part.CFrame = (from + out * 14 * u + Vector3.new(0, 3 * u, 0)) * CFrame.Angles(u * 4, u * 6, 0)
					p.part.Transparency = u
				end, function()
					if p.part.Parent then
						if not fresh then
							Vfx.Recipes.twinkle(p.part.Position, { color = GOLD, scale = 1.2 })
						end
						p.part:Destroy()
					end
				end)
			end
		end)
	)
	if own then
		LightingController.lean(0.55, GOLD, 0.2, 1.2)
	end
	return function()
		over = true
		removeLight()
		for _, stop in ipairs(stops) do
			stop()
		end
		stopMotes()
		stopSigil()
		stopGlow()
		for _, p in ipairs(pages) do
			if p.part.Parent then
				p.part:Destroy()
			end
		end
		Vfx.Clock.after(4.5, function()
			base:Destroy()
			motesAt:Destroy()
		end)
		if own then
			LightingController.unlean(1.2)
		end
	end
end

-- Reaper's Eyes: two red slivers of light on the face from when the head starts to turn.
-- On the new kit (stage 4b, Pilot.on.reapersEyes; false = the old build). One sentence: the eyes open red in the dark, a bank of red
-- mist rising round his feet (motif: cold light, smoke). Five moments by the clip (the hand comes away at 1.75 s):
--   gather    0.0 to 1.75 s  the hand over the eyes, nothing yet
--   hit       1.75 s         a white-hot four-point glint on each eye in red (Fresh.glint), a red ring out from the face, a red light
--   body      1.75 s on      a red glow held on each eye, the mist bank round the feet with a dark bank under it
--   break-up  at the end     the glows and the mist are switched off, they thin out by their own lives
--   residue   2 to 3 s after the last of the mist drifting off the floor
FX.reapersEyes = function(character, preview)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nothing
	end
	local own = mine(character)
	local fresh = Pilot.on.reapersEyes
	local ramp = Palette.emote("reapersEyes") :: Palette.Ramp
	local calm = Motion.isReduced()
	local parts: { BasePart } = {}
	local stops: { () -> () } = {}
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
			-- each eye: a red star flaring open as it lights, a red glow held on it
			local at = Create("Attachment", { Name = "EmoteEyeGlow", Parent = part })
			at:SetAttribute("DGEmote", true)
			if fresh then
				if side < 0 then
					-- (one glint between the eyes: two would put the effect over its emitter budget)
					Fresh.glint(
						head.Position + head.CFrame.LookVector * (head.Size.Z / 2 + 0.05),
						{ ramp = ramp, scale = 1.6, lead = 0.04 }
					)
				end
			else
				local flare = Vfx.Emit.make(at, {
					tex = "VfxFlare",
					color = BLOOD_HOT,
					size = { { 0, 0 }, { 0.25, 2.4 }, { 1, 0 } },
					life = 0.55,
					rot = { 0, 45 },
					spin = { 60, 120 },
					locked = true,
					bright = 1.5,
					z = 1,
				})
				flare:Emit(1)
			end
			local _, stopGlow = Vfx.Emit.hold(at, {
				tex = "VfxGlow",
				color = BLOOD_HOT,
				size = 0.9,
				life = 4,
				rate = 1 / 3.8,
				alpha = { { 0, 1 }, { 0.05, 0.25 }, { 0.95, 0.25 }, { 1, 1 } },
				locked = true,
				bright = 1.2,
				z = 0.8,
			})
			table.insert(stops, stopGlow)
		end
		if preview then
			return
		end
		Create("PointLight", {
			Color = Color3.fromRGB(255, 40, 40),
			Range = 8,
			Brightness = 4,
			Parent = parts[1],
		})
		-- a red pulse rolling out from the eyes, red smoke rising round the feet, the world going red round him
		Vfx.Emit.burst(head.Position, {
			tex = if fresh then "VfxShock" else "VfxRing",
			color = BLOOD_HOT,
			size = { { 0, 1 }, { 1, 16 } },
			alpha = { { 0, 0.1 }, { 0.6, 0.5 }, { 1, 1 } },
			life = 0.55,
			light = 0.5,
			bright = 1.1,
		}, 1)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local ground = Vfx.Emit.point(
				CFrame.new(floorUnder(root.Position, character) + Vector3.new(0, 0.2, 0)),
				Vector3.new(5, 0.1, 5)
			)
			if fresh then
				-- (a bank of red mist lying round the feet, a dark bank under it: Fresh.mist)
				local bank = Fresh.mist(ground.Position, { ramp = ramp, size = 5 })
				table.insert(stops, function()
					bank.stop()
					Vfx.Clock.after(3, function()
						bank.destroy()
						ground:Destroy()
					end)
				end)
			else
				local _, stopSmoke = Vfx.Emit.hold(ground, {
					tex = "VfxSmoke",
					grid = 8,
					mode = "OneShot",
					color = BLOOD,
					light = 0,
					lit = 0.3,
					size = { { 0, 1.2 }, { 1, 3.2 } },
					alpha = { { 0, 0.6 }, { 0.5, 0.55 }, { 1, 1 } },
					life = { 1.6, 2.4 },
					rate = 4,
					speed = { 0.6, 1.4 },
					shape = Enum.ParticleEmitterShape.Box,
					rot = { 0, 360 },
					spin = { -20, 20 },
				})
				table.insert(stops, function()
					stopSmoke()
					Vfx.Clock.after(2.6, function()
						ground:Destroy()
					end)
				end)
			end
		end
		if own and not calm then
			Vfx.Screen.punch(-4, 0.6)
			Vfx.Screen.shake(0.6, 0.4)
			LightingController.lean(0.4, BLOOD, 0.15, 0.4)
		end
	end)
	return function()
		gone = true
		for _, stop in ipairs(stops) do
			stop()
		end
		for _, part in ipairs(parts) do
			part:Destroy()
		end
		if own then
			LightingController.unlean(1)
		end
	end
end

-- Just As Planned, timed to the clip (art/scripts/emotes/poses.py): a pool of crimson light spreads across the
-- floor round him and embers drift up off it; the eye catches red at the stare (2.05 s) and at the last look
-- (7.75 s); a red light comes up under the face with the grin (3.55 s); the laugh (4.95 s) bursts a ring of light
-- out across the floor with a spray of embers and a pulse of the light; it all dies down as he comes to rest
-- (8.4 s). Under reduced motion there is no burst and no pulse.

-- On the new kit (stage 4b, Pilot.on.justAsPlanned; false = the old build). One sentence: a villain's plan coming together, the room
-- going crimson with a floor of red light and ash (motif: ash and ember smoke). Five moments, by the clip's beats:
--   gather    0 to 4.95 s   the sigil and the pool of light open, ash rising off them, the eye catching red at the stare (2.05 s, Fresh.glint)
--   hit       4.95 s        the laugh: a heavy crimson blow on the floor with a white core (Fresh.impact), the ring out, the flame ring
--   body      4.95 to 6.9 s the sigil and pool flare then hold, the light under the face at its strongest, the flame ring rising
--   break-up  6.9 to 8.4 s  the light eases, the ash and smoke are switched off
--   residue   8.4 s on      the pool and sigil fade out; the impact's ash and thread of smoke drift on
local EMBERS = ColorSequence.new(Color3.fromRGB(255, 92, 70), Color3.fromRGB(70, 62, 62))

FX.justAsPlanned = function(character, preview)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if preview or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nothing
	end
	local own = mine(character)
	local fresh = Pilot.on.justAsPlanned
	local ramp = Palette.emote("justAsPlanned") :: Palette.Ramp
	local calm = Motion.isReduced()
	local gone = false
	local made: { Instance } = {}
	local stops: { () -> () } = {}
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

	-- the sigil and a pool of crimson light spreading over the floor, a red light in it
	local floor = floorUnder(root.Position, character)
	local base = keep(Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 0.05, 0)), Vector3.new(8, 0.1, 8)))
	local setSigil, stopSigil = floorLayer(
		base,
		{ tex = "VfxCircle", color = BLOOD_HOT, light = 0.5, bright = 1.2, spin = if calm then 0 else -7 },
		0.4,
		0.2
	)
	local setPool, stopPool =
		floorLayer(base, { tex = "VfxGlow", color = CRIMSON, light = 0.6, bright = 0.9 }, 0.4, 0.45)
	table.insert(stops, stopSigil)
	table.insert(stops, stopPool)
	Vfx.Clock.tween(1.3, Vfx.Ease.outQuart, function(u)
		setSigil(0.4 + 8.6 * u)
		setPool(0.4 + 10.6 * u)
	end)
	local tint = Create(
		"PointLight",
		{ Color = CRIMSON, Range = 12, Brightness = 0, Shadows = false, Enabled = not fresh, Parent = base }
	)
	tween(tint, 1.3, { Brightness = 1.2 })

	-- embers rising off it the whole time, dark smoke curling off its edge
	local motes = Vfx.Emit.make(base, {
		tex = if fresh then "VfxAshFlakes" else "VfxEmber",
		color = EMBERS,
		size = if fresh then { { 0, 0.5 }, { 1, 0.3 } } else { { 0, 0.2 }, { 1, 0.04 } },
		alpha = if fresh then { { 0, 1 }, { 0.15, 0.15 }, { 0.8, 0.3 }, { 1, 1 } } else nil,
		life = { 1.6, 2.6 },
		speed = { 0.6, 1.4 },
		accel = Vector3.new(0, 1.2, 0),
		rot = { 0, 360 },
		shape = Enum.ParticleEmitterShape.Box,
		light = 0.8,
		bright = 1.3,
	})
	local smoke = Vfx.Emit.make(base, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(46, 8, 14),
		light = 0,
		lit = 0.3,
		size = { { 0, 1.4 }, { 1, 3.6 } },
		alpha = { { 0, 0.55 }, { 0.5, 0.55 }, { 1, 1 } },
		life = { 2, 3 },
		speed = { 0.4, 1 },
		shape = Enum.ParticleEmitterShape.Box,
		rot = { 0, 360 },
		spin = { -15, 15 },
	})
	at(0.5, function()
		motes.Rate = 16
		smoke.Rate = 2.5
	end)

	-- the red glint in the eye, and a flash of red light with it
	local eye =
		keep(Create("Attachment", { Name = "EmoteGlint", Position = Vector3.new(0.22, 0.12, -0.62), Parent = head }))
	eye:SetAttribute("DGEmote", true)
	local glint = if fresh
		then nil
		else Vfx.Emit.make(eye, {
			tex = "VfxFlare",
			color = BLOOD_HOT,
			size = { { 0, 0.2 }, { 0.35, 1.6 }, { 1, 0 } },
			life = 0.5,
			rot = { 0, 45 },
			spin = 120,
			locked = true,
			bright = 1.5,
			z = 1,
		})
	local glow =
		Create("PointLight", { Color = CRIMSON, Range = 7, Brightness = 0, Shadows = false, Parent = eye }) :: PointLight
	local function catchRed()
		if glint then
			glint:Emit(1)
		else
			Fresh.glint(eye.WorldPosition, { ramp = ramp, scale = 0.9, lead = 0.04 })
		end
		if not calm then
			glow.Brightness = 5
			tween(glow, 0.5, { Brightness = 0 })
		end
	end
	at(2.05, catchRed)
	at(7.75, catchRed)

	-- the red light under the face from the grin on, and his edges lit red
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
		table.insert(stops, Vfx.Rim.glow(character, BLOOD_HOT, math.huge, { fill = 0.12, fadeIn = 0.8 }))
	end)

	-- the laugh: the sigil flares, a crimson blast out across the floor, a ring of fire bursting up round him
	at(4.95, function()
		Vfx.Clock.tween(0.45, Vfx.Ease.outBack, function(u)
			setSigil(9 + 3 * u)
			setPool(11 + 3 * u)
		end, function()
			Vfx.Clock.tween(1.2, Vfx.Ease.inOutSine, function(u)
				setSigil(12 - 2 * u)
				setPool(14 - 3 * u)
			end)
		end)
		if calm then
			return
		end
		below.Brightness = 6
		tween(below, 0.9, { Brightness = 2.6 })
		if fresh then
			Fresh.impact(
				CFrame.new(floor),
				{ style = "heavy", ramp = ramp, scale = 1.3, ground = true, shake = own, flash = own, lead = 0.02 }
			)
		else
			Vfx.Recipes.impact(
				CFrame.new(floor),
				{ color = CRIMSON, scale = 1.3, ground = true, shake = own, flash = own }
			)
			FxKit.shape("dome", CFrame.new(floor), { size = 13, seconds = 0.5, color = BLOOD_HOT, transparency = 0.6 })
		end
		Vfx.Beams.wave(CFrame.new(floor + Vector3.new(0, 0.1, 0)), 1, 22, 0.75, {
			tex = "VfxRingBand",
			color = BLOOD_HOT,
			width = 2,
			light = 0.5,
			bright = 1.1,
		})
		local ring = Vfx.Emit.point(CFrame.new(floor + Vector3.new(0, 0.3, 0)), Vector3.new(7, 0.1, 7))
		local fire = Vfx.Emit.make(ring, {
			tex = "VfxFlame",
			grid = 8,
			fps = 40,
			startRandom = true,
			color = { { 0, BLOOD_HOT }, { 0.4, CRIMSON }, { 1, Color3.fromRGB(30, 4, 8) } },
			size = { { 0, 2.2 }, { 0.4, 3.4 }, { 1, 1 } },
			alpha = { { 0, 0.7 }, { 0.15, 0.2 }, { 0.65, 0.45 }, { 1, 1 } },
			life = { 0.5, 0.85 },
			speed = { 6, 11 },
			spread = 10,
			face = "up",
			shape = Enum.ParticleEmitterShape.Cylinder,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			light = 0.35,
			bright = 1.2,
		})
		fire:Emit(28)
		Vfx.Clock.after(1.5, function()
			ring:Destroy()
		end)
		if not fresh then
			Vfx.Light.flash(head.Position, CRIMSON, 18, 4, 0.6)
		end
		if own then
			Vfx.Screen.impact({ character }, 0.09)
			LightingController.lean(0.6, BLOOD, 0.25, 0.3)
		end
	end)
	at(6.9, function()
		tween(below, 0.6, { Brightness = 0.8 })
	end)

	-- it all dies down as he comes to rest
	at(8.4, function()
		motes.Rate = 0
		smoke.Rate = 0
		tween(below, 0.6, { Brightness = 0 })
		tween(tint, 0.8, { Brightness = 0 })
		Vfx.Clock.tween(0.8, Vfx.Ease.inQuad, function(u)
			setSigil(10 * (1 - u))
			setPool(11 * (1 - u))
		end)
		if own then
			LightingController.unlean(1.2)
		end
	end)

	return function()
		gone = true
		for _, stop in ipairs(stops) do
			stop()
		end
		if own then
			LightingController.unlean(1)
		end
		local list = made
		Vfx.Clock.after(4.2, function()
			for _, instance in ipairs(list) do
				instance:Destroy()
			end
		end)
		under:Destroy()
		eye:Destroy()
	end
end

-- Final Breakdown: a red light from below the face comes up as the laugh is held in; it flares as he is thrown
-- back (2.25 s) with a ring of dark dust out across the floor and dark smoke pouring up off him while he laughs;
-- everything dies away as he folds over (4.2 s). Under reduced motion there is no flare.
-- On the new kit (stage 4b, Pilot.on.finalBreakdown; false = the old build). One sentence: a mind breaking, the floor taking the blow
-- as he is thrown back (motif: stone and ash, dark smoke). Five moments, by the clip:
--   gather    0 to 2.25 s    the red light under the face comes up, dark smoke begins to pour off him
--   hit       2.25 s         the floor takes it: a crimson slam with a white core, dust ring, cracks, a light on the beat (Fresh.slam)
--   body      2.25 to 4.2 s  the smoke pours harder, his edges lit red, the light easing from its flare
--   break-up  4.2 s          the smoke is switched off and the light fades over a second
--   residue   after          the slam's dust, scorch and ash settle on the floor
FX.finalBreakdown = function(character, preview)
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if preview or not head or not head:IsA("BasePart") or not root then
		return nothing
	end
	local own = mine(character)
	local fresh = Pilot.on.finalBreakdown
	local ramp = Palette.emote("finalBreakdown") :: Palette.Ramp
	local calm = Motion.isReduced()
	local gone = false
	local stops: { () -> () } = {}
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
	-- dark smoke pouring up off him while he laughs
	local torso = character:FindFirstChild("Torso")
	local pour = Vfx.Emit.make(if torso and torso:IsA("BasePart") then torso else under, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(26, 22, 24),
		light = 0,
		lit = 0.3,
		size = { { 0, 1.6 }, { 1, 4.4 } },
		alpha = { { 0, 0.5 }, { 0.5, 0.5 }, { 1, 1 } },
		life = { 1.4, 2.2 },
		speed = { 1.5, 3 },
		spread = 40,
		accel = Vector3.new(0, 2, 0),
		rot = { 0, 360 },
		spin = { -25, 25 },
		shape = Enum.ParticleEmitterShape.Box,
		z = -1,
	})
	pour:SetAttribute("DGEmote", true)
	after(head, over, 2.25, function()
		if not calm then
			light.Brightness = 7
			TweenService:Create(light, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Brightness = 3 }):Play()
		end
		local sole = lowerSole(character)
		if sole then
			-- thrown back: the floor takes the blow (a crimson slam: dust, smoke, cracks, bits of it thrown up)
			local ground = floorUnder(sole, character)
			if fresh then
				Fresh.slam(CFrame.new(ground), { ramp = ramp, scale = 1.4, shake = own, flash = own, lead = 0.02 })
			else
				Vfx.Recipes.slam(CFrame.new(ground), { color = CRIMSON, scale = 1.4, shake = own, flash = own })
				FxKit.rocks(ground, 3.2, 12)
			end
		end
		table.insert(stops, Vfx.Rim.glow(character, BLOOD_HOT, math.huge, { fill = 0.1, fadeIn = 0.3 }))
		if own and not calm then
			Vfx.Screen.impact({ character }, 0.08)
			LightingController.lean(0.5, BLOOD, 0.3, 0.3)
		end
		pour.Rate = if calm then 8 else 22
	end)
	after(head, over, 4.2, function()
		pour.Rate = 0
		TweenService:Create(light, TweenInfo.new(1.0), { Brightness = 0 }):Play()
		if own then
			LightingController.unlean(1.2)
		end
	end)
	return function()
		gone = true
		for _, stop in ipairs(stops) do
			stop()
		end
		if own then
			LightingController.unlean(1)
		end
		pour.Enabled = false
		task.delay(2.3, function()
			under:Destroy()
			pour:Destroy()
		end)
	end
end

return FX
