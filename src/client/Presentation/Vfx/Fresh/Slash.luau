--!strict
-- Slash (the plan's V2.5, against art/refs/vfx/slash.toml): a crescent born full size on the hit frame, turning for a few
-- frames, thinning into streaks, then into specks.
--
--   gather   the body is the gather (the ref has no effect before the swing): a few specks drawn to the start of the arc
--   hit      a white-hot band, the coloured band outside it, a faint ring behind (the shock), a dark base under it all
--   body     the crescent thins into three streaks along the swing, and a dark smear of wind laid over
--   residue  two or three specks left hanging, under a second
--
-- `at` is the centre of the swing; its right and up are the plane the blade is drawn on (the camera sees that plane's face).
-- `angle` turns the blade in that plane (degrees); the blade sweeps toward the direction the angle points.

local Emit = require(script.Parent.Parent.Emit)
local Moment = require(script.Parent.Parent.Moment)
local Palette = require(script.Parent.Parent.Palette)
local Screen = require(script.Parent.Parent.Screen)
local Shape = require(script.Parent.Parent.Shape)
local C = require(script.Parent.Common)

local Slash = {}

export type Options = {
	ramp: Palette.Ramp?,
	scale: number?,
	angle: number?, -- degrees the blade is turned in its plane (-30 by default)
	floor: boolean?, -- also a blade of light lying on the floor (the Fx import's VfxSlashArc)
	shake: boolean?,
	lead: number?,
}

function Slash.slash(at: CFrame, options: Options?): () -> ()
	local o = options or {}
	local ramp = C.ramp(o)
	local hot, shade = C.hotter(ramp), C.shadow(ramp)
	local s = o.scale or 1
	local angle = o.angle or -30
	local lead = o.lead or 0.18
	local pos = at.Position
	-- (the swing's direction in the blade's plane, and a frame that looks along it for the streaks)
	local rad = math.rad(angle)
	local swing = (at.RightVector * math.cos(rad) + at.UpVector * math.sin(rad)).Unit
	local along = CFrame.lookAt(pos, pos + swing)
	return Moment.play(at, {
		lead = lead,
		gather = function()
			C.gather(pos - swing * 3.2 * s, ramp, 1.4 * s, lead, 5, 0.4 * s)
		end,
		hit = function()
			local core, band, base = 7.5 * s, 8.5 * s, 9.5 * s
			Emit.burst(at, {
				{
					{
						tex = "VfxSlashA",
						ramp = hot,
						size = C.size("VfxSlashA", core, { { 0, core * 0.6 }, { 0.2, core }, { 1, core * 1.05 } }),
						alpha = { { 0, 0 }, { 0.55, 0.05 }, { 1, 1 } },
						life = 0.6,
						rot = { angle, angle },
						bright = 2.3,
						z = 3,
					},
					1,
				},
				{
					{
						tex = "VfxSlashB",
						ramp = ramp,
						size = C.size("VfxSlashB", band, { { 0, band * 0.6 }, { 0.2, band }, { 1, band * 1.08 } }),
						alpha = { { 0, 0 }, { 0.5, 0.15 }, { 1, 1 } },
						life = 0.65,
						rot = { angle, angle },
						bright = 1.05,
						z = 2,
					},
					1,
				},
				{
					{
						-- (the dark base under the bright band: laid over, so the cut reads on a lit floor)
						tex = "VfxSlashB",
						ramp = shade,
						size = C.size("VfxSlashB", base, { { 0, base * 0.6 }, { 0.2, base }, { 1, base * 1.1 } }),
						alpha = { { 0, 1 }, { 0.1, 0.35 }, { 0.6, 0.5 }, { 1, 1 } },
						life = 0.7,
						rot = { angle, angle },
						light = 0,
						z = 1,
					},
					1,
				},
				{
					{
						tex = "VfxShock",
						ramp = ramp,
						size = C.size("VfxShock", 6 * s, { { 0, 2 * s }, { 0.5, 5 * s }, { 1, 6 * s } }),
						alpha = { { 0, 0.55 }, { 0.6, 0.7 }, { 1, 1 } },
						life = 0.6,
						bright = 0.8,
					},
					1,
				},
			})
			C.beat(pos, ramp[1], 14 * s, 2.4 * s)
			if o.shake then
				Screen.shakeAt(pos, 0.6 * s, 0.25)
			end
			if o.floor then
				local flat = CFrame.fromMatrix(pos, at.RightVector, at.UpVector)
				Shape.grow("slashArc", flat * CFrame.Angles(0, math.rad(angle), 0), {
					size = 8 * s,
					seconds = 0.12,
					fade = 0.3,
					color = ramp[1],
					transparency = 0.45,
					spin = if C.still() then 0 else 25,
				})
			end
		end,
		body = function()
			Emit.burst(along, {
				{
					{
						-- (the crescent thinning into streaks, like the wind lines a swing leaves)
						tex = "VfxStreak",
						ramp = ramp,
						size = { { 0, 0.55 * s }, { 1, 0.25 * s } },
						alpha = { { 0, 0.2 }, { 0.6, 0.45 }, { 1, 1 } },
						life = { 0.35, 0.6 },
						speed = { 8 * s, 16 * s },
						spread = 5,
						dir = Enum.NormalId.Front,
						face = "along",
						bright = 1.1,
					},
					3,
				},
				{
					{
						tex = "VfxSparks",
						ramp = hot,
						size = { { 0, 0.4 * s }, { 1, 0.1 * s } },
						alpha = { { 0, 0 }, { 0.7, 0.3 }, { 1, 1 } },
						life = { 0.4, 0.8 },
						speed = { 3 * s, 9 * s },
						spread = 180,
						drag = 2,
						face = "along",
						bright = 1.4,
					},
					6,
				},
				{
					{
						tex = "VfxMist",
						ramp = shade,
						size = { { 0, 5 * s }, { 1, 7 * s } },
						alpha = { { 0, 1 }, { 0.2, 0.7 }, { 0.6, 0.8 }, { 1, 1 } },
						life = 0.9,
						speed = { 1, 3 },
						spread = 20,
						dir = Enum.NormalId.Front,
						light = 0,
						z = -1,
					},
					1,
				},
			})
		end,
		residue = function()
			Emit.burst(pos + swing * 1.5 * s, {
				tex = "VfxAshFlakes",
				ramp = ramp,
				size = { { 0, 0.25 * s }, { 1, 0.15 * s } },
				alpha = { { 0, 1 }, { 0.15, 0.2 }, { 0.7, 0.4 }, { 1, 1 } },
				life = { 1.2, 1.6 },
				speed = { 0.5, 1.5 },
				spread = 180,
				accel = swing * 1.2 + Vector3.new(0, 0.4, 0),
				drag = 1.2,
				light = 0,
				lit = 0.5,
			}, 3)
		end,
	})
end

return Slash
