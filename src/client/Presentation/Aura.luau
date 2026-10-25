-- The aura an emote wears (the owner, 2026-10-24: "make ALL of them extremely high quality ... look at Ink Game's
-- vfx"; rebuilt on the VFX kit, Presentation/Vfx). Layered, in the aura's colour, and keeping its colour (the colour
-- layers are laid over more than added, so they never burn white; only small white hearts are added as light). By
-- level:
--   1  a steady glow behind the body; aura flames licking up off it (the battlegrounds aura: tongues of fire rising
--      round the body and burning out as they climb); specks rising; star flares on the limbs; a light;
--   2  and the ground: rings pulsing out from the feet, a glow on the floor, dark smoke swirling round the feet;
--      crescent wisps whirling round the body, smoke rising behind it;
--   3  and two beams of light spiralling up round it, a halo behind the head, lightning crackling over it, its edges
--      lit, and a shockwave rolling out across the floor every few seconds.
-- Everything is this client's own, marked "DGEmote" (a copy of the body leaves it out); emitters are named "DGAura" and
-- the ground holder "DGAuraGround" (checks count them). Nothing on low graphics; under reduced motion nothing spins,
-- and there are no beams, lightning or shockwaves.
--
--   local stop = Aura.start(character, { colour = c, accent = c2, level = 2 })   stop()

local Motion = require(script.Parent.Parent.UI.Core.Motion)
local Governor = require(script.Parent.Parent.World.Governor)
local Vfx = require(script.Parent.Vfx)

local Emit = Vfx.Emit
local Clock = Vfx.Clock
local Beams = Vfx.Beams
local Rim = Vfx.Rim

local Aura = {}

export type Spec = {
	colour: Color3, -- the aura's colour
	accent: Color3?, -- its flares, rings and lightning (a lighter one by default)
	level: number, -- 1 .. 3 (above)
	scale: number?, -- its size (1 for a body)
	ground: boolean?, -- its ground layer (from level 2; false: none, for one that floats or flies)
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function partOf(character: Model, ...: string): BasePart?
	for _, name in ipairs({ ... }) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- The floor under a point (or 3 studs under it), ignoring bodies and what the camera holds.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function floorUnder(at: Vector3, character: Model): Vector3
	params.FilterDescendantsInstances = { character, workspace.CurrentCamera }
	local hit = workspace:Raycast(at + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

-- One long-lived particle at a time, the next fading in as the last fades out: a steady layer (Vfx Recipes.flame).
local STEADY = 4
local function steady(spec: { [string]: any }, solid: number): { [string]: any }
	spec.life = STEADY
	spec.rate = 1 / (STEADY * 0.95)
	spec.alpha = { { 0, 1 }, { 0.05, solid }, { 0.95, solid }, { 1, 1 } }
	return spec
end

function Aura.start(character: Model, spec: Spec): () -> ()
	local root = partOf(character, "HumanoidRootPart")
	local torso = partOf(character, "Torso", "UpperTorso")
	if not root or not torso or Governor.low("emoteFx") then
		return function() end
	end
	local calm = Motion.isReduced()
	local level = math.clamp(spec.level, 1, 3)
	local k = spec.scale or 1
	local colour = spec.colour
	local accent = spec.accent or colour:Lerp(WHITE, 0.55)
	local deep = colour:Lerp(BLACK, 0.55)
	local made: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	local stops: { () -> () } = {}
	local function mark(item: Instance)
		item:SetAttribute("DGEmote", true)
		table.insert(made, item)
	end
	local function emit(parent: Instance, s: { [string]: any }, now: number?): ParticleEmitter
		s.name = "DGAura"
		local e = Emit.make(parent, s)
		mark(e)
		table.insert(emitters, e)
		if now and now > 0 then
			e:Emit(now)
		end
		return e
	end
	local function attach(parent: Instance, at: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "DGAura"
		a.Position = at
		a.Parent = parent
		mark(a)
		return a
	end

	-- 1: the steady glow, the aura's flames, the specks, the limbs' flares, a light
	local core = attach(torso, Vector3.zero)
	emit(
		core,
		steady({
			tex = "VfxGlow",
			color = colour,
			size = 7 * k,
			locked = true,
			light = 0.6,
			bright = 0.8,
			z = -1.5,
		}, 0.55),
		1
	)
	-- the aura's flames: tongues licking up off the body and the legs, the aura's colour through their middles, white
	-- at their roots, dark as they burn out (laid over more than added, so they keep their colour)
	local flames = {
		tex = "VfxFlame",
		grid = 8,
		fps = 40,
		startRandom = true,
		color = { { 0, accent }, { 0.35, colour }, { 0.8, deep }, { 1, deep:Lerp(BLACK, 0.5) } },
		size = { { 0, 2 * k }, { 0.4, 2.9 * k }, { 1, 1 * k } },
		alpha = { { 0, 1 }, { 0.12, 0.25 }, { 0.6, 0.4 }, { 1, 1 } },
		life = { 0.45, 0.75 },
		rate = 16,
		speed = { 3 * k, 5.5 * k },
		spread = 24,
		accel = Vector3.new(0, 5 * k, 0),
		drag = 1,
		rot = { -12, 12 },
		face = "up",
		light = 0.35,
		bright = 1.25,
		shape = Enum.ParticleEmitterShape.Box,
		z = 0.3,
	}
	emit(torso, flames)
	for _, name in ipairs({ "Right Leg", "Left Leg" }) do
		local leg = partOf(character, name)
		if leg then
			local legs = table.clone(flames)
			legs.rate = 7
			legs.size = { { 0, 1.6 * k }, { 0.4, 2.3 * k }, { 1, 0.8 * k } }
			emit(leg, legs)
		end
	end
	emit(torso, {
		tex = "VfxEmber",
		color = { { 0, WHITE }, { 0.4, accent }, { 1, colour } },
		size = { { 0, 0.18 * k }, { 1, 0 } },
		life = { 1, 1.6 },
		rate = 6,
		speed = { 1, 3 },
		spread = 40,
		accel = Vector3.new(0, 2.5, 0),
		drag = 1,
		bright = 1.3,
		shape = Enum.ParticleEmitterShape.Box,
	})
	for _, name in ipairs({ "Right Arm", "Left Arm", "Right Leg", "Left Leg" }) do
		local limb = partOf(character, name)
		if limb then
			emit(limb, {
				tex = "VfxFlare",
				color = { { 0, WHITE }, { 1, accent } },
				size = { { 0, 0 }, { 0.3, 1.1 * k }, { 1, 0 } },
				life = { 0.35, 0.6 },
				rate = 0.9,
				rot = { 0, 90 },
				spin = if calm then 0 else { -40, 40 },
				bright = 1.3,
				z = 0.6,
			})
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "DGAura"
	light.Color = colour
	light.Range = 10 * k
	light.Brightness = 0
	light.Shadows = false
	light.Parent = torso
	mark(light)
	Clock.tween(0.5, Vfx.Ease.outQuad, function(u)
		light.Brightness = 1.3 * u
	end)

	-- 2: the ground, the wisps, the smoke
	local ground: BasePart? = nil
	if level >= 2 then
		emit(torso, {
			tex = "VfxSlash",
			color = { { 0, accent }, { 1, colour } },
			size = { { 0, 2.6 * k }, { 1, 4 * k } },
			alpha = { { 0, 1 }, { 0.2, 0.4 }, { 1, 1 } },
			life = { 0.5, 0.8 },
			rate = 3,
			rot = { 0, 360 },
			spin = if calm then 0 else { -200, 200 },
			light = 0.55,
			bright = 1,
			z = 0.4,
		})
		emit(torso, {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = deep,
			light = 0,
			lit = 0.25,
			size = { { 0, 3 * k }, { 1, 6.5 * k } },
			alpha = { { 0, 0.85 }, { 0.3, 0.72 }, { 1, 1 } },
			life = { 1.8, 2.5 },
			rate = 1.5,
			speed = { 0.5, 1.1 },
			spin = { -15, 15 },
			rot = { 0, 360 },
			z = -2,
		})
		if spec.ground ~= false then
			local g = Emit.point(CFrame.new(floorUnder(root.Position, character) + Vector3.new(0, 0.08, 0)))
			g.Name = "DGAuraGround"
			mark(g)
			ground = g
			emit(g, {
				tex = "VfxRing",
				color = { { 0, accent }, { 1, colour } },
				size = { { 0, 2 * k }, { 1, 10 * k } },
				alpha = { { 0, 1 }, { 0.1, 0.35 }, { 1, 1 } },
				life = 1.4,
				rate = 0.9,
				speed = 0.001,
				face = "flat",
				light = 0.5,
				bright = 1,
			})
			emit(
				g,
				steady({
					tex = "VfxGlow",
					color = colour,
					size = 9 * k,
					speed = 0.001,
					face = "flat",
					light = 0.6,
					bright = 0.8,
				}, 0.55),
				1
			)
			emit(g, {
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = deep:Lerp(BLACK, 0.4),
				light = 0,
				lit = 0.3,
				size = { { 0, 1.4 * k }, { 1, 3.6 * k } },
				alpha = { { 0, 0.6 }, { 0.5, 0.55 }, { 1, 1 } },
				life = { 1.2, 1.8 },
				rate = 3,
				speed = { 2 * k, 4 * k },
				drag = 1.5,
				spread = { 85, 85 },
				rot = { 0, 360 },
				spin = if calm then 0 else { -60, 60 },
			})
		end
	end

	-- 3: the spiral beams, the halo, the lightning, the edge, the shockwaves
	local beamEnds: { { low: Attachment, high: Attachment, turn: number } } = {}
	if level >= 3 then
		local head = partOf(character, "Head")
		if head then
			local back = attach(head, Vector3.new(0, 0.15, 0.7))
			emit(
				back,
				steady({
					tex = "VfxRing",
					color = accent,
					size = 2 * k,
					locked = true,
					spin = if calm then 0 else 25,
					light = 0.8,
					bright = 1.1,
					z = -1,
				}, 0.4),
				1
			)
		end
		if ground and not calm then
			for i, curve in ipairs({ 4.5, -4.5 }) do
				local low = attach(ground, Vector3.zero)
				local high = attach(ground, Vector3.new(0, 7.5 * k, 0))
				local beam = Beams.make(low, high, {
					tex = "VfxColumn",
					color = ColorSequence.new(colour, accent),
					width = 0.35 * k,
					width1 = 0.9 * k,
					bright = 1,
					light = 0.8,
					speed = 1.4,
					repeats = 4,
					segments = 40,
					alpha = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.15, 0.35),
						NumberSequenceKeypoint.new(0.85, 0.4),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}, ground)
				beam.CurveSize0 = curve * k
				beam.CurveSize1 = -curve * k
				beam.Name = "DGAura"
				mark(beam)
				table.insert(beamEnds, { low = low, high = high, turn = (i - 1) * math.pi })
			end
		end
		table.insert(stops, Rim.glow(character, accent, math.huge, { fill = 0.1, fadeIn = 0.4 }))
		if not calm then
			-- lightning over the body now and then, and a shockwave across the floor every few seconds
			local rng = Random.new()
			local nextBolt, nextWave = Clock.now() + 0.4, Clock.now() + 1.2
			table.insert(
				stops,
				Clock.every(function(_, now)
					if not torso.Parent then
						return false
					end
					if now >= nextBolt then
						nextBolt = now + rng:NextNumber(0.5, 1.2)
						local from = torso.Position
							+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 2), rng:NextNumber(-1, 1)) * k
						local to = from
							+ Vector3.new(
									rng:NextNumber(-2.5, 2.5),
									rng:NextNumber(-1, 2.5),
									rng:NextNumber(-2.5, 2.5)
								)
								* k
						Beams.bolt(from, to, 0.14, {
							color = accent,
							width = 0.4 * k,
							bright = 1.6,
							jag = 0.5 * k,
							pieces = 6,
							rate = 30,
						})
					end
					if ground and now >= nextWave then
						nextWave = now + 2.4
						Beams.wave(ground.CFrame, 1 * k, 8 * k, 0.6, {
							tex = "VfxRingBand",
							color = accent,
							width = 1.2 * k,
							light = 0.6,
							bright = 1,
						})
					end
					return true
				end)
			)
		end
	end

	-- The ground follows the feet (a beat behind on the floor's height); the beams turn round the body.
	local spin = 0
	local sinceFloor = 1
	local floorY = if ground then ground.Position.Y else 0
	table.insert(
		stops,
		Clock.every(function(dt)
			if not root.Parent then
				return false
			end
			if ground then
				sinceFloor += dt
				if sinceFloor > 0.12 then
					sinceFloor = 0
					floorY = floorUnder(root.Position, character).Y + 0.08
				end
				ground.CFrame = CFrame.new(root.Position.X, floorY, root.Position.Z)
			end
			spin += dt * 1.3
			for _, ends in ipairs(beamEnds) do
				local a = spin + ends.turn
				ends.low.Position = Vector3.new(math.cos(a) * 1.4 * k, 0.2, math.sin(a) * 1.4 * k)
				ends.high.Position = Vector3.new(math.cos(a + 2.2) * 1.2 * k, 7.5 * k, math.sin(a + 2.2) * 1.2 * k)
			end
			return true
		end)
	)

	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		for _, stop in ipairs(stops) do
			stop()
		end
		for _, item in ipairs(emitters) do
			item.Enabled = false
		end
		local from = light.Brightness
		Clock.tween(0.4, Vfx.Ease.outQuad, function(u)
			light.Brightness = from * (1 - u)
		end)
		for _, item in ipairs(made) do
			if item:IsA("Beam") then
				item.Enabled = false
			end
		end
		-- (the longest life, the smoke's, is 2.5 s: everything has faded by then)
		Clock.after(2.6, function()
			for _, item in ipairs(made) do
				item:Destroy()
			end
		end)
	end
end

return Aura
