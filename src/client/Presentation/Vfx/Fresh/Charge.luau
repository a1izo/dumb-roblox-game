--!strict
-- Charge (the plan's V2.5): specks drawn in round a dark heart, wisps curling in, a core that pulses and a light that climbs
-- slowly, held until release() (the hit: a blown-out burst, sparks thrown, a dark puff, flakes and a thread of smoke) or
-- cancel() (it fades with no hit). The point is static; a moving hand is the caller's to follow (the pilot decides how).

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Light = require(script.Parent.Parent.Light)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local C = require(script.Parent.Common)

local Charge = {}

export type ChargeOptions = {
	ramp: Palette.Ramp?,
	scale: number?,
	radius: number?, -- studs the specks are drawn in from
}

export type Charge = {
	release: () -> (), -- let it go: the hit
	cancel: () -> (), -- let it fade with no hit
}

-- A charge at `at` that gathers and holds until it is released or cancelled.
function Charge.charge(at: CFrame | Vector3, options: ChargeOptions?): Charge
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local radius = o.radius or 2.4 * s
	local frame = C.frame(at)
	local pos = frame.Position
	local holder = Emit.point(frame, Vector3.new(radius * 2, radius * 2, radius * 2))
	local inward = {
		shape = Enum.ParticleEmitterShape.Sphere,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		shapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
	}
	local specs: { { [string]: any } } = {
		{
			-- specks drawn in
			tex = "VfxSparks",
			ramp = hot,
			size = { { 0, 0.45 * s }, { 1, 0.1 * s } },
			alpha = { { 0, 1 }, { 0.2, 0.15 }, { 0.85, 0.2 }, { 1, 1 } },
			life = 0.55,
			speed = radius / 0.55,
			shape = inward.shape,
			shapeStyle = inward.shapeStyle,
			shapeInOut = inward.shapeInOut,
			face = "along",
			rate = 22,
			bright = 1.5,
			z = 1,
		},
		{
			-- the dark heart: laid over, at the middle
			tex = "VfxMist",
			ramp = shade,
			size = { { 0, 1.2 * s }, { 1, 1.6 * s } },
			alpha = { { 0, 1 }, { 0.3, 0.7 }, { 0.8, 0.75 }, { 1, 1 } },
			life = 1.8,
			rate = 1.6,
			light = 0,
			z = -1,
		},
		{
			-- wisps curling in
			tex = "VfxEnergyWisp",
			ramp = ramp,
			size = { { 0, 0.9 * s }, { 1, 0.25 * s } },
			alpha = { { 0, 1 }, { 0.25, 0.3 }, { 0.8, 0.4 }, { 1, 1 } },
			life = 1.2,
			speed = radius * 0.5,
			shape = inward.shape,
			shapeStyle = inward.shapeStyle,
			shapeInOut = inward.shapeInOut,
			spin = if C.still() then 0 else { -180, 180 },
			rate = 4,
		},
		{
			-- the core pulsing
			tex = "VfxGlint",
			ramp = hot,
			size = C.size("VfxGlint", 1.6 * s, { { 0, 0 }, { 0.35, 1.6 * s }, { 1, 0 } }),
			alpha = { { 0, 0 }, { 0.5, 0.1 }, { 1, 1 } },
			life = 0.55,
			rot = { -15, 15 },
			rate = 1.8,
			bright = 2.3,
			z = 2,
		},
	}
	local made: { ParticleEmitter } = {}
	local releaseLight: ((number?) -> ())? = nil
	local done = false
	Moment.play(pos, {
		lead = 0,
		gather = function()
			for _, spec in ipairs(specs) do
				table.insert(made, Emit.make(holder, spec))
			end
			local _, release = Light.hold(holder, ramp[2], radius * 4, 1.4, 1.2)
			releaseLight = release
		end,
	})
	local function end_(fade: number)
		done = true
		for _, e in ipairs(made) do
			e.Enabled = false
		end
		if releaseLight then
			releaseLight(fade)
		end
		Clock.after(2.6, function()
			holder:Destroy()
		end)
	end
	return {
		release = function()
			if done then
				return
			end
			end_(0.25)
			Moment.play(pos, {
				lead = 0,
				hit = function()
					Emit.burst(frame, {
						{
							{
								tex = "VfxImpactC",
								ramp = hot,
								size = C.size(
									"VfxImpactC",
									5.4 * s,
									{ { 0, 2.5 * s }, { 0.2, 5.4 * s }, { 1, 6 * s } }
								),
								alpha = { { 0, 0 }, { 0.55, 0.1 }, { 1, 1 } },
								life = 0.6,
								rot = { 0, 360 },
								bright = 2.3,
								z = 2,
							},
							1,
						},
						{
							{
								tex = "VfxShock",
								ramp = ramp,
								size = C.size("VfxShock", 5 * s, { { 0, 1.5 * s }, { 0.5, 4.5 * s }, { 1, 5 * s } }),
								alpha = { { 0, 0.2 }, { 0.6, 0.4 }, { 1, 1 } },
								life = 0.55,
								bright = 1.1,
								z = 1,
							},
							1,
						},
					})
					C.beat(pos, ramp[1], 14 * s, 3 * s, 0.04)
				end,
				body = function()
					Emit.burst(frame, {
						{
							{
								tex = "VfxSparks",
								ramp = hot,
								size = { { 0, 0.6 * s }, { 1, 0.12 * s } },
								alpha = { { 0, 1 }, { 0.08, 0 }, { 0.7, 0.2 }, { 1, 1 } },
								life = { 0.35, 0.75 },
								speed = { 14 * s, 34 * s },
								drag = 3,
								spread = 180,
								face = "along",
								bright = 1.5,
							},
							12,
						},
						{
							{
								tex = "VfxSmokePuff",
								ramp = shade,
								size = C.size("VfxSmokePuff", 4.5 * s, { { 0, 1.5 * s }, { 1, 5 * s } }),
								alpha = { { 0, 1 }, { 0.15, 0.5 }, { 0.7, 0.65 }, { 1, 1 } },
								life = { 2.1, 2.4 },
								accel = Vector3.new(0, 1, 0),
								light = 0,
								lit = 0.2,
								z = -1,
							},
							1,
						},
					})
				end,
				residue = function()
					Emit.burst(frame, {
						{
							{
								tex = "VfxAshFlakes",
								ramp = hot,
								size = { { 0, 0.3 * s }, { 1, 0.22 * s } },
								alpha = { { 0, 1 }, { 0.15, 0.1 }, { 0.7, 0.3 }, { 1, 1 } },
								life = { 2, 3 },
								speed = { 0.5, 2 },
								spread = 180,
								accel = Vector3.new(0, 0.5, 0),
								drag = 1.2,
								light = 0,
								lit = 0.6,
							},
							4,
						},
						{
							{
								tex = "VfxSmokePlume",
								ramp = shade,
								size = { { 0, 0.6 * s }, { 1, 1.5 * s } },
								alpha = { { 0, 1 }, { 0.2, 0.65 }, { 1, 1 } },
								life = 2.5,
								speed = 0.6,
								accel = Vector3.new(0, 1.3, 0),
								light = 0,
								lit = 0.2,
							},
							1,
						},
					})
				end,
			})
		end,
		cancel = function()
			if not done then
				end_(0.35)
			end
		end,
	}
end

return Charge
