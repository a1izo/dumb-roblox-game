--!strict
-- What the new recipes share: the ramp a caller gave (or the world's pale one), the dark layer's colours, the light on the
-- beat (rises fast, falls three times slower, no shadows), the gather that draws specks in, sizes that suit a sheet that is
-- really there or the old picture it stands in for, and a few small helpers. Nothing here changes how an old recipe plays.

local Clock = require(script.Parent.Parent.Clock)
local Emit = require(script.Parent.Parent.Emit)
local Light = require(script.Parent.Parent.Light)
local Palette = require(script.Parent.Parent.Palette)
local Tex = require(script.Parent.Parent.Tex)
local Motion = require(script.Parent.Parent.Parent.Parent.UI.Core.Motion)

local Common = {}

export type Ramp = Palette.Ramp

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- The ramp a recipe wears: the caller's, else the world's pale grey.
function Common.ramp(options: { [string]: any }): Ramp
	return options.ramp or Palette.WORLD.pale
end

-- The ramp with a white-hot start: white at birth, the ramp's core as the body, its body as the edge (the layer that has to
-- be the brightest thing on the screen).
function Common.hotter(ramp: Ramp): Ramp
	return { WHITE, ramp[1], ramp[2] }
end

-- The dark layer's ramp: the ramp's edge pushed toward black, three steps (laid over the scene, never added).
function Common.shadow(ramp: Ramp): Ramp
	local edge = ramp[3]
	return { edge:Lerp(BLACK, 0.35), edge:Lerp(BLACK, 0.55), edge:Lerp(BLACK, 0.8) }
end

-- True under Reduce motion (no spins, no tumbling).
function Common.still(): boolean
	return Motion.isReduced()
end

-- A size over a particle's life for a flipbook: `flat` when the sheet's own picture is in the place (its frames already grow
-- and erode), `grown` for the old picture that stands in until the Fx import (one still image has to be grown by hand).
function Common.size(texture: string, flat: number, grown: { { number } }): { { number } }
	if Tex.real(texture) then
		return { { 0, flat }, { 1, flat * 1.06 } }
	end
	return grown
end

-- The shape of a fade that arrives and leaves softly: transparency 1 at birth and death, `solid` between. (A long-lived
-- particle never starts solid: it would pop in.)
function Common.soft(solid: number, inAt: number?, outAt: number?): { { number } }
	return { { 0, 1 }, { inAt or 0.12, solid }, { outAt or 0.7, solid + (1 - solid) * 0.25 }, { 1, 1 } }
end

-- A light on the beat at `at`: it rises over `rise` seconds and falls over three times that, casts no shadow, and goes.
function Common.beat(at: Vector3, color: Color3, range: number, brightness: number, rise: number?)
	local up = rise or 0.05
	local holder = Emit.point(at)
	local _, release = Light.hold(holder, color, range, brightness, up)
	Clock.after(up + 0.03, function()
		release(up * 3)
	end)
	Clock.after(up * 4 + 0.3, function()
		holder:Destroy()
	end)
end

-- The gather: `count` specks drawn in from a sphere of `radius` studs to `at`, arriving as the hit lands.
function Common.gather(at: Vector3, ramp: Ramp, radius: number, lead: number, count: number, size: number?)
	local life = math.max(0.12, lead * 0.9)
	local grain = size or 0.5
	Emit.burst(at, {
		{
			{
				tex = "VfxSparks",
				ramp = Common.hotter(ramp),
				size = { { 0, grain }, { 1, grain * 0.25 } },
				alpha = { { 0, 1 }, { 0.2, 0.15 }, { 0.85, 0.2 }, { 1, 1 } },
				life = life,
				speed = radius / life,
				shape = Enum.ParticleEmitterShape.Sphere,
				shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				shapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				face = "along",
				bright = 1.5,
				z = 1,
			},
			count,
		},
	}, nil, Vector3.new(radius * 2, radius * 2, radius * 2))
end

-- The point of a CFrame or Vector3.
function Common.position(at: CFrame | Vector3): Vector3
	return if typeof(at) == "CFrame" then at.Position else at
end

-- A CFrame at a point or CFrame (a point is upright).
function Common.frame(at: CFrame | Vector3): CFrame
	return if typeof(at) == "CFrame" then at else CFrame.new(at)
end

return Common
